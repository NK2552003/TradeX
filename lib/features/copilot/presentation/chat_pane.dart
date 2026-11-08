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
import 'copilot_composer.dart';

class CopilotChatPane extends StatefulWidget {
  const CopilotChatPane({
    super.key,
    required this.controller,
    this.initialPrompt,
    this.onPage,
    this.onVoice,
    this.voiceActive = false,
  });
  final CopilotController controller;
  final String? initialPrompt;
  final ValueChanged<WorkspacePage>? onPage;
  final VoidCallback? onVoice;
  final bool voiceActive;
  @override
  State<CopilotChatPane> createState() => _CopilotChatPaneState();
}

class _CopilotChatPaneState extends State<CopilotChatPane> {
  final _composer = TextEditingController();
  final List<({String name, Json input})> _attachments = [];
  bool _attaching = false;
  CopilotPromptMode _mode = CopilotPromptMode.auto;
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
    if (_attaching || controller.generating) return;
    setState(() => _attaching = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: true,
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
      final additions = <({String name, Json input})>[];
      for (final file in picked.files) {
        if (_attachments.length + additions.length >= 4 ||
            file.size > 6000000) {
          throw const FormatException(
            'Attach up to four files, each under 6 MB.',
          );
        }
        final bytes = file.bytes ?? await file.xFile.readAsBytes();
        if (!mounted) return;
        if (bytes.length > 6000000) {
          throw const FormatException('Each file must be under 6 MB.');
        }
        final extension = file.extension?.toLowerCase();
        final Json input;
        if (['png', 'jpg', 'jpeg', 'webp'].contains(extension)) {
          final mime = extension == 'jpg' ? 'jpeg' : extension;
          input = {
            'type': 'input_image',
            'image_url': 'data:image/$mime;base64,${base64Encode(bytes)}',
          };
        } else if (extension == 'pdf') {
          input = {
            'type': 'input_file',
            'filename': file.name,
            'file_data': 'data:application/pdf;base64,${base64Encode(bytes)}',
          };
        } else {
          final text = utf8.decode(bytes);
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
        additions.add((name: file.name, input: input));
      }
      final totalBytes = utf8
          .encode(
            jsonEncode([
              ..._attachments.map((a) => a.input),
              ...additions.map((a) => a.input),
            ]),
          )
          .length;
      if (totalBytes > 11000000) {
        throw const FormatException(
          'These files exceed the combined upload limit. Attach fewer or smaller files.',
        );
      }
      setState(() => _attachments.addAll(additions));
    } catch (error) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Could not attach file',
          message: '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _send(String prompt) async {
    final attachments = _attachments.map((a) => a.input).toList();
    final accepted = await controller.sendPrompt(
      prompt,
      attachments: attachments,
      mode:
          controller.specialist?.research == true &&
              controller.workspace.settings['research'] == true
          ? _mode.name
          : 'auto',
    );
    if (!mounted) return;
    if (accepted) {
      _composer.clear();
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
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.pageContextId != null)
            Padding(
              padding: EdgeInsets.only(
                bottom: context.sp(context.ui.spacing.sm),
              ),
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
              composer: CopilotComposer(
                controller: _composer,
                compactHeight: constraints.maxHeight < 440,
                enabled:
                    controller.connected &&
                    !controller.voiceBusy &&
                    !controller.hasPendingReview &&
                    controller.workspace.settings['paused'] != true,
                busy: controller.generating || thread?.status == 'running',
                attaching: _attaching,
                attachments: _attachments.map((a) => a.name).toList(),
                profiles: controller.workspace.specialists,
                profileId: controller.specialist?.id,
                mode: _mode,
                canResearch:
                    controller.workspace.settings['research'] == true &&
                    controller.specialist?.research == true,
                onModeChanged: (mode) => setState(() => _mode = mode),
                onSelectProfile: (id) {
                  controller.newConversation(specialist: id);
                  setState(() => _mode = CopilotPromptMode.auto);
                },
                onNewConversation: () => controller.newConversation(),
                onSend: () => _send(
                  _composer.text.trim().isEmpty
                      ? 'Please review the attached files.'
                      : _composer.text.trim(),
                ),
                onAttach: _attach,
                onRemoveAttachment: (i) =>
                    setState(() => _attachments.removeAt(i)),
                onStop: controller.stop,
                onVoice: widget.onVoice,
                voiceActive: widget.voiceActive,
              ),
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
                              label: textOf(
                                file,
                                'filename',
                                'Download result',
                              ),
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
          if (controller.generating)
            Padding(
              padding: EdgeInsets.only(top: context.sp(context.ui.spacing.sm)),
              child: Text(
                controller.activity.isEmpty
                    ? 'Thinking…'
                    : textOf(
                        controller.activity.last,
                        'name',
                      ).replaceAll('_', ' '),
                textAlign: TextAlign.center,
                style: context.uiText.caption.copyWith(
                  color: context.ui.colors.foregroundSubtle,
                ),
              ),
            ),
        ],
      ),
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
      padding: EdgeInsets.symmetric(
        vertical: context.sp(context.ui.spacing.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'What can I help with?',
            textAlign: TextAlign.center,
            style: context.uiText.display.copyWith(
              fontSize: context.fs(context.uiRes.isMobile ? 28 : 36),
              height: 1.15,
              letterSpacing: -.8,
            ),
          ),
          UiGap.v(context.ui.spacing.sm),
          Text(
            'Bring a question, a chart, or a fresh idea.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(
              color: context.ui.colors.foregroundMuted,
            ),
          ),
          UiGap.v(context.ui.spacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: context.sp(context.ui.spacing.xs),
            children: [
              for (final prompt in const [
                'Review a setup',
                'Research the market',
                'Work with my notes',
              ])
                UiButton(
                  label: prompt,
                  variant: UiVariant.ghost,
                  size: UiSize.sm,
                  onPressed: () => onPrompt(prompt),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
