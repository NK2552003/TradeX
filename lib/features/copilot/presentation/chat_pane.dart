import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../data/copilot_controller.dart';
import '../models/workspace.dart';
import 'review_card.dart';
import 'save_page_dialog.dart';

class CopilotChatPane extends StatefulWidget {
  const CopilotChatPane({
    super.key,
    required this.controller,
    this.initialPrompt,
    this.onPage,
  });
  final CopilotController controller;
  final String? initialPrompt;
  final ValueChanged<WorkspacePage>? onPage;
  @override
  State<CopilotChatPane> createState() => _CopilotChatPaneState();
}

class _CopilotChatPaneState extends State<CopilotChatPane> {
  final _composer = TextEditingController();
  final List<({String name, Json input})> _attachments = [];
  CopilotController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _composer.text = widget.initialPrompt ?? '';
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'pdf',
          'txt',
          'md',
          'csv',
        ],
      );
      if (!mounted || picked == null) return;
      final file = picked.files.single;
      if (_attachments.length >= 4 ||
          file.size > 6000000 ||
          file.bytes == null) {
        throw const FormatException(
          'Attach up to four files, each under 6 MB.',
        );
      }
      final extension = file.extension?.toLowerCase();
      final Json input;
      if (['png', 'jpg', 'jpeg', 'webp'].contains(extension)) {
        final mime = extension == 'jpg' ? 'jpeg' : extension;
        input = {
          'type': 'input_image',
          'image_url': 'data:image/$mime;base64,${base64Encode(file.bytes!)}',
        };
      } else if (extension == 'pdf') {
        input = {
          'type': 'input_file',
          'filename': file.name,
          'file_data':
              'data:application/pdf;base64,${base64Encode(file.bytes!)}',
        };
      } else {
        final text = utf8.decode(file.bytes!);
        if (text.length > 80000) {
          throw const FormatException(
            'Text attachments are limited to 80,000 characters.',
          );
        }
        input = {
          'type': 'input_text',
          'text': 'Attachment ${file.name}:\n$text',
        };
      }
      setState(() => _attachments.add((name: file.name, input: input)));
    } catch (error) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Could not attach file',
          message: '$error',
        );
      }
    }
  }

  Future<void> _send(String prompt) async {
    final attachments = _attachments.map((a) => a.input).toList();
    final accepted = await controller.sendPrompt(
      prompt,
      attachments: attachments,
    );
    if (!mounted) return;
    if (accepted) {
      setState(_attachments.clear);
    } else if (_composer.text.isEmpty) {
      _composer.text = prompt;
    }
  }

  Future<void> _download(Json artifact) async {
    try {
      final bytes = await controller.api.artifact(
        controller.activeThreadId!,
        artifact,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: textOf(artifact, 'filename', 'result.txt'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        UiToast.error(context, title: 'File unavailable', message: '$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = controller.activeThread;
    final messages = thread?.messages ?? <CopilotMessage>[];
    final approvals =
        thread?.approvals.where((a) => a['status'] == 'pending').toList() ?? [];
    final displayed = messages
        .map(
          (message) => AppAiMessage(
            id: message.id,
            role: message.isUser ? AppAiRole.user : AppAiRole.assistant,
            body: message.id == controller.streamingMessageId
                ? controller.streamingText
                : message.body,
            pending: message.status == 'streaming' && controller.generating,
            sources: message.sources.map((s) => textOf(s, 'url')).toList(),
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.pageContextId != null)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.sm)),
            child: UiBadge(
              label:
                  'Discussing: ${controller.workspace.pages.where((p) => p.id == controller.pageContextId).firstOrNull?.title ?? 'Page'}',
              icon: Icons.article_outlined,
              intent: UiIntent.neutral,
            ),
          ),
        if (controller.error != null)
          UiCallout(
            title: 'Could not finish',
            message: controller.error!,
            intent: UiIntent.warning,
            action: UiButton(
              label: 'Reconnect',
              size: UiSize.sm,
              variant: UiVariant.ghost,
              onPressed: () => controller.reload(),
            ),
          ),
        Expanded(
          child: AppAiChatBlock(
            key: ValueKey(
              controller.activeThreadId ?? 'new-${controller.specialist?.id}',
            ),
            messages: displayed,
            onSend: _send,
            onAttach: _attach,
            generating: controller.generating || thread?.status == 'running',
            onStop: controller.stop,
            canSend:
                controller.connected &&
                !controller.hasPendingReview &&
                controller.workspace.settings['paused'] != true,
            composerController: _composer,
            composerHint:
                'Ask ${controller.specialist?.name ?? 'your copilot'} anything…',
            emptyState: _Welcome(
              specialist: controller.specialist,
              onPrompt: (prompt) {
                _composer.text = prompt;
                _composer.selection = TextSelection.collapsed(
                  offset: prompt.length,
                );
              },
            ),
            messageBuilder: (context, message) {
              final model = messages.where((m) => m.id == message.id).first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppAiMessageBubble(
                    message: message,
                    minimal: true,
                    onCopy: () =>
                        Clipboard.setData(ClipboardData(text: message.body)),
                    onSourceTap: (url) {
                      final uri = Uri.tryParse(url);
                      if (uri != null &&
                          ['http', 'https'].contains(uri.scheme)) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    actionsBuilder: (_) => model.isUser
                        ? []
                        : [
                            UiButton(
                              label: 'Save page',
                              icon: Icons.add_to_drive_outlined,
                              size: UiSize.xs,
                              variant: UiVariant.ghost,
                              onPressed: message.body.isEmpty
                                  ? null
                                  : () => showSavePageDialog(
                                      context,
                                      controller,
                                      message.body,
                                    ),
                            ),
                            if (model.status == 'failed' ||
                                model.status == 'interrupted')
                              UiButton(
                                label: 'Continue',
                                size: UiSize.xs,
                                variant: UiVariant.ghost,
                                onPressed: controller.generating
                                    ? null
                                    : () => _send(
                                        'Continue the previous answer from where it stopped.',
                                      ),
                              ),
                          ],
                  ),
                  if (model.artifacts.isNotEmpty)
                    Wrap(
                      children: [
                        for (final file in model.artifacts)
                          UiButton(
                            label: textOf(file, 'filename', 'Download result'),
                            icon: Icons.download_outlined,
                            variant: UiVariant.outline,
                            size: UiSize.sm,
                            onPressed: () => _download(file),
                          ),
                      ],
                    ),
                  for (final receipt in thread?.approvals ?? <Json>[])
                    if (receipt['kind'] == 'propose_page' &&
                        receipt['status'] == 'approved' &&
                        receipt['messageId'] == model.id &&
                        receipt['result']?['id'] != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: UiButton(
                          label: 'Open saved page',
                          icon: Icons.description_outlined,
                          variant: UiVariant.soft,
                          size: UiSize.sm,
                          onPressed: () {
                            final page = controller.workspace.pages
                                .where((p) => p.id == receipt['result']['id'])
                                .firstOrNull;
                            if (page != null) widget.onPage?.call(page);
                          },
                        ),
                      ),
                  if (model.activity.isNotEmpty)
                    UiAccordion(
                      sections: [
                        UiAccordionSection(
                          title: 'Work log · ${model.activity.length} steps',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final item in model.activity)
                                Text(
                                  textOf(item, 'name').replaceAll('_', ' '),
                                  style: context.uiText.caption,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (model.id == messages.lastOrNull?.id)
                    for (final approval in approvals)
                      CopilotReviewCard(
                        controller: controller,
                        approval: approval,
                      ),
                ],
              );
            },
          ),
        ),
        if (_attachments.isNotEmpty)
          Wrap(
            spacing: context.sp(context.ui.spacing.xs),
            children: [
              for (final attachment in _attachments)
                UiButton(
                  label: attachment.name,
                  icon: Icons.close,
                  size: UiSize.xs,
                  variant: UiVariant.ghost,
                  onPressed: controller.generating
                      ? null
                      : () => setState(() => _attachments.remove(attachment)),
                ),
            ],
          ),
        Padding(
          padding: EdgeInsets.only(top: context.sp(context.ui.spacing.sm)),
          child: Text(
            controller.generating
                ? (controller.activity.isEmpty
                      ? 'Thinking…'
                      : textOf(
                          controller.activity.last,
                          'name',
                        ).replaceAll('_', ' '))
                : 'A little clarity goes a long way.',
            textAlign: TextAlign.center,
            style: context.uiText.caption.copyWith(
              color: context.ui.colors.foregroundSubtle,
            ),
          ),
        ),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({this.specialist, required this.onPrompt});
  final Specialist? specialist;
  final ValueChanged<String> onPrompt;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(540)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            UiBadge(
              label: specialist?.role ?? 'Your thinking partner',
              variant: UiBadgeVariant.soft,
              intent: UiIntent.neutral,
            ),
            UiGap.v(context.ui.spacing.lg),
            Text(
              'Less noise.\nMore perspective.',
              style: context.uiText.display.copyWith(
                letterSpacing: -1.4,
                height: 1.12,
              ),
            ),
            UiGap.v(context.ui.spacing.md),
            Text(
              'Research an idea, work through a decision,\nor turn a conversation into something useful.',
              style: context.uiText.body.copyWith(
                color: context.ui.colors.foregroundMuted,
                height: 1.6,
              ),
            ),
            UiGap.v(context.ui.spacing.xl),
            for (final prompt in [
              'What should I know before the market opens?',
              'Help me pressure-test a trading idea',
              'Turn my notes into a clear plan',
            ])
              UiButton(
                label: prompt,
                trailingIcon: Icons.north_east_rounded,
                variant: UiVariant.ghost,
                alignment: Alignment.centerLeft,
                onPressed: () => onPrompt(prompt),
              ),
          ],
        ),
      ),
    ),
  );
}
