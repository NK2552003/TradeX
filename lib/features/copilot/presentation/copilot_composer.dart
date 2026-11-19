import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/markdown_kit/markdown_kit.dart';

import '../models/trader_skill.dart';
import '../models/workspace.dart';
import 'trader_skill_picker.dart';
import 'research_routing_hint.dart';

part 'copilot_composer_actions.dart';

enum CopilotPromptMode { auto, search, research }

enum CopilotSearchFocus {
  all('All sources', Icons.public_rounded),
  finance('Finance', Icons.show_chart_rounded),
  news('News', Icons.newspaper_outlined),
  filings('Filings', Icons.description_outlined),
  macro('Macro', Icons.account_balance_outlined),
  academic('Academic', Icons.school_outlined),
  workspace('Workspace', Icons.folder_copy_outlined);

  const CopilotSearchFocus(this.label, this.icon);
  final String label;
  final IconData icon;
}

class CopilotComposer extends StatefulWidget {
  const CopilotComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onModeChanged,
    required this.onSelectProfile,
    required this.onNewConversation,
    required this.profiles,
    required this.mode,
    this.focus = CopilotSearchFocus.all,
    this.onFocusChanged,
    this.profileId,
    this.attachments = const [],
    this.attachmentItems = const [],
    this.enabled = true,
    this.busy = false,
    this.attaching = false,
    this.canResearch = true,
    this.onStop,
    this.onVoice,
    this.onAttachImage,
    this.onTakePhoto,
    this.onAttachDropzone,
    this.onAttachUrl,
    this.onConnectWorkspace,
    this.voiceActive = false,
    this.compactHeight = false,
    this.onResearchFormats,
  });
  final TextEditingController controller;
  final Future<void> Function() onSend;
  final VoidCallback? onAttach;
  final ValueChanged<int> onRemoveAttachment;
  final ValueChanged<CopilotPromptMode> onModeChanged;
  final CopilotSearchFocus focus;
  final ValueChanged<CopilotSearchFocus>? onFocusChanged;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onNewConversation;
  final List<Specialist> profiles;
  final String? profileId;
  final List<String> attachments;
  final List<AppAiAttachment> attachmentItems;
  final CopilotPromptMode mode;
  final bool enabled, busy, attaching, canResearch, voiceActive;
  final bool compactHeight;
  final VoidCallback? onResearchFormats;
  final VoidCallback? onStop,
      onVoice,
      onAttachImage,
      onTakePhoto,
      onAttachDropzone,
      onAttachUrl,
      onConnectWorkspace;

  @override
  State<CopilotComposer> createState() => _CopilotComposerState();
}

class _CopilotComposerState extends State<CopilotComposer> {
  final _focus = FocusNode();
  final SpeechToText _speech = SpeechToText();
  bool _submitting = false;
  bool _dictating = false;
  String _dictationBase = '';

  bool get _editable => !widget.busy && !_submitting;

  @override
  void dispose() {
    if (_dictating) {
      _speech.stop();
    }
    _focus.dispose();
    super.dispose();
  }

  Future<void> _toggleDictation() async {
    if (!_editable || !widget.enabled) return;
    if (_dictating) {
      try {
        await _speech.stop();
      } catch (_) {}
      if (mounted) setState(() => _dictating = false);
      return;
    }
    try {
      final bool available = await _speech.initialize(
        onStatus: (String status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _dictating = false);
          }
        },
        onError: (err) {
          if (!mounted) return;
          setState(() => _dictating = false);
          final lower = err.errorMsg.toLowerCase();
          if (lower.contains('not-allowed') || lower.contains('permission')) {
            UiToast.warning(
              context,
              title: 'Microphone permission denied',
              message:
                  'Allow microphone access in your browser settings to dictate.',
            );
          } else if (lower.contains('audio-capture') ||
              lower.contains('no_microphone')) {
            UiToast.warning(
              context,
              title: 'No microphone detected',
              message: 'Connect a microphone and retry.',
            );
          } else {
            widget.onVoice?.call();
          }
        },
      );
      if (!available) {
        if (widget.onVoice != null) {
          widget.onVoice!();
          return;
        }
        if (mounted) {
          UiToast.info(
            context,
            title: 'Voice assistant ready',
            message: 'Speak naturally or use the live voice call panel.',
          );
        }
        return;
      }
      _dictationBase = widget.controller.text;
      if (mounted) setState(() => _dictating = true);
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (!mounted) return;
          final String spoken = result.recognizedWords.trim();
          if (spoken.isEmpty) return;
          final String next = _dictationBase.trimRight().isEmpty
              ? spoken
              : '${_dictationBase.trimRight()} $spoken';
          widget.controller.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
          if (result.finalResult && mounted) {
            setState(() => _dictating = false);
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _dictating = false);
      widget.onVoice?.call();
    }
  }

  Future<void> _send() async {
    if (!_editable ||
        !widget.enabled ||
        widget.attaching ||
        (widget.controller.text.trim().isEmpty && widget.attachments.isEmpty)) {
      return;
    }
    if (_dictating) {
      try {
        await _speech.stop();
      } catch (_) {}
      _dictating = false;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSend();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _paste() async {
    try {
      final content = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted || !_editable) return;
      final text = content?.text;
      if (text == null || text.isEmpty) {
        UiToast.info(
          context,
          title: 'Clipboard has no text',
          message: 'Use + to attach an image or document.',
        );
        return;
      }
      final value = widget.controller.value;
      final selection = value.selection.isValid
          ? value.selection
          : TextSelection.collapsed(offset: value.text.length);
      final next = value.text.replaceRange(
        selection.start,
        selection.end,
        text,
      );
      if (next.length > 24000) {
        UiToast.warning(
          context,
          title: 'Text is too long',
          message: 'Attach a text file for longer content.',
        );
        return;
      }
      widget.controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(
          offset: selection.start + text.length,
        ),
      );
      _focus.requestFocus();
    } catch (_) {
      if (mounted) {
        UiToast.warning(
          context,
          title: 'Use your paste shortcut',
          message: 'Your device did not grant clipboard access.',
        );
      }
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.controller.text));
    if (mounted) UiToast.success(context, title: 'Draft copied');
  }

  void _prompt(String text) {
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focus.requestFocus();
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: widget.controller,
    builder: (context, value, _) => LayoutBuilder(
      builder: (context, box) {
        final theme = context.ui;
        final compact = box.maxWidth < 470;
        final profile = widget.profiles
            .where((p) => p.id == widget.profileId)
            .firstOrNull;
        final canSend =
            _editable &&
            widget.enabled &&
            !widget.attaching &&
            (value.text.trim().isNotEmpty || widget.attachments.isNotEmpty);
        final words = value.text.trim().isEmpty
            ? 0
            : value.text.trim().split(RegExp(r'\s+')).length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.voiceActive) ...[
              Row(
                children: [
                  UiDropdownMenu(
                    semanticLabel: 'Conversation options',
                    actions: [
                      UiMenuItem(
                        label: 'New conversation',
                        icon: Icons.add_comment_outlined,
                        enabled: _editable && !widget.voiceActive,
                        onPressed: widget.onNewConversation,
                      ),
                      UiMenuItem(
                        label: 'Trader skills',
                        icon: Icons.bolt_outlined,
                        enabled: _editable,
                        onPressed: () async {
                          final skill = await pickTraderSkill(context);
                          if (mounted && skill != null) {
                            _prompt(
                              traderSkillDraft(skill, widget.controller.text),
                            );
                          }
                        },
                      ),
                      if (widget.onConnectWorkspace != null)
                        UiMenuItem(
                          label: 'Connect workspace data',
                          icon: Icons.hub_outlined,
                          enabled: _editable,
                          onPressed: widget.onConnectWorkspace!,
                        ),
                      if (widget.onVoice != null)
                        UiMenuItem(
                          label: widget.voiceActive
                              ? 'End live voice assistant'
                              : 'Start live voice assistant',
                          icon: Icons.graphic_eq_rounded,
                          onPressed: widget.onVoice!,
                        ),
                    ],
                    child: UiButton(
                      label: 'Copilot',
                      icon: Icons.more_horiz,
                      variant: UiVariant.outline,
                      size: UiSize.sm,
                      rounded: true,
                      onPressed: () {},
                    ),
                  ),
                  if (!compact &&
                      widget.onResearchFormats != null &&
                      !widget.compactHeight) ...[
                    UiGap.h(theme.spacing.xs),
                    ResearchRoutingHint(
                      controller: widget.controller,
                      onChoose: widget.onResearchFormats!,
                      enabled: _editable && widget.enabled,
                    ),
                  ],
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: UiDropdownMenu(
                        semanticLabel: 'Select a profile',
                        alignRight: true,
                        enabled: _editable && !widget.voiceActive,
                        actions: [
                          for (final item in widget.profiles)
                            UiMenuItem(
                              label: item.name,
                              description: item.role,
                              selected: item.id == widget.profileId,
                              onPressed: () => widget.onSelectProfile(item.id),
                            ),
                        ],
                        child: UiButton(
                          label: profile?.name ?? 'Select a profile',
                          trailingIcon: Icons.expand_more,
                          variant: UiVariant.outline,
                          size: UiSize.sm,
                          rounded: true,
                          onPressed: () {},
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              UiGap.v(theme.spacing.xs),
            ],
            UiCard(
              key: const ValueKey('copilot-composer-surface'),
              variant: UiCardVariant.elevated,
              borderRadius: context.radius(theme.radii.xl),
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_dictating)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(theme.spacing.xs),
                      ),
                      child: const UiBadge(
                        label: 'Listening for natural language…',
                        intent: UiIntent.success,
                        size: UiSize.xs,
                      ),
                    ),
                  if (widget.attachmentItems.isNotEmpty ||
                      widget.attachments.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(theme.spacing.xs),
                      ),
                      child: _ComposerAttachmentStrip(
                        items: widget.attachmentItems.isNotEmpty
                            ? widget.attachmentItems
                            : <AppAiAttachment>[
                                for (final String name in widget.attachments)
                                  AppAiAttachment(name: name),
                              ],
                        maxWidth: box.maxWidth - context.sp(theme.spacing.xl),
                        editable: _editable,
                        onRemove: widget.onRemoveAttachment,
                      ),
                    ),
                  Shortcuts(
                    shortcuts: const {
                      SingleActivator(LogicalKeyboardKey.enter):
                          ActivateIntent(),
                      SingleActivator(LogicalKeyboardKey.numpadEnter):
                          ActivateIntent(),
                      SingleActivator(LogicalKeyboardKey.enter, control: true):
                          ActivateIntent(),
                      SingleActivator(LogicalKeyboardKey.enter, meta: true):
                          ActivateIntent(),
                    },
                    child: Actions(
                      actions: {
                        ActivateIntent: CallbackAction<ActivateIntent>(
                          onInvoke: (_) {
                            final composing = widget.controller.value.composing;
                            if (composing.isValid && !composing.isCollapsed) {
                              return null;
                            }
                            _send();
                            return null;
                          },
                        ),
                      },
                      child: UiInput.multiline(
                        controller: widget.controller,
                        focusNode: _focus,
                        onSubmitted: (_) => _send(),
                        semanticLabel: 'Message copilot',
                        hintText: compact
                            ? 'Ask a question or type / for skills…'
                            : 'Ask a question, attach a file, or type / for trader skills…',
                        minLines: 1,
                        maxLines: widget.compactHeight ? 2 : (compact ? 4 : 5),
                        maxLength: 24000,
                        variant: UiInputVariant.ghost,
                        readOnly: !widget.enabled || _submitting,
                      ),
                    ),
                  ),
                  if (_editable &&
                      RegExp(r'^/[a-zA-Z-]*$').hasMatch(value.text))
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(theme.spacing.xs),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final skill in TraderSkill.values.where(
                              (s) =>
                                  s.command.startsWith(
                                    value.text.toLowerCase(),
                                  ) ||
                                  '/${s.name}'.startsWith(
                                    value.text.toLowerCase(),
                                  ),
                            ))
                              UiButton(
                                label: skill.command,
                                tooltip: skill.description,
                                size: UiSize.xs,
                                variant: UiVariant.soft,
                                onPressed: () => _prompt('${skill.command} '),
                              ),
                            if (value.text == '/')
                              for (final prompt in const [
                                'Summarize these notes',
                                'Review my journal trades',
                                'Analyze my strategies',
                                'Draft a community post',
                                'Research this market',
                              ])
                                UiButton(
                                  label: prompt,
                                  size: UiSize.xs,
                                  variant: UiVariant.ghost,
                                  onPressed: () => _prompt('$prompt: '),
                                ),
                          ],
                        ),
                      ),
                    ),
                  _ComposerActions(
                    config: widget,
                    compact: compact,
                    editable: _editable,
                    submitting: _submitting,
                    dictating: _dictating,
                    canSend: canSend,
                    onSend: _send,
                    onPaste: _paste,
                    onCopy: _copy,
                    onPrompt: () => _prompt('/'),
                    onToggleDictation: _toggleDictation,
                  ),
                ],
              ),
            ),
            if (value.text.isNotEmpty) ...[
              UiGap.v(theme.spacing.xxs),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${value.text.characters.length} chars / $words words',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _ComposerAttachmentStrip extends StatelessWidget {
  const _ComposerAttachmentStrip({
    required this.items,
    required this.maxWidth,
    required this.editable,
    required this.onRemove,
  });

  final List<AppAiAttachment> items;
  final double maxWidth;
  final bool editable;
  final ValueChanged<int> onRemove;

  static IconData _iconFor(AppAiAttachmentKind kind) => switch (kind) {
    AppAiAttachmentKind.image => Icons.image_outlined,
    AppAiAttachmentKind.pdf => Icons.picture_as_pdf_outlined,
    AppAiAttachmentKind.code => Icons.code_rounded,
    AppAiAttachmentKind.data => Icons.table_chart_outlined,
    AppAiAttachmentKind.audio => Icons.audiotrack_outlined,
    AppAiAttachmentKind.workspace => Icons.hub_outlined,
    AppAiAttachmentKind.link => Icons.link_rounded,
    AppAiAttachmentKind.text => Icons.article_outlined,
    AppAiAttachmentKind.file => Icons.attach_file_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<String> imageUrls = items
        .where((AppAiAttachment a) => a.isImage && a.previewUrl != null)
        .map((AppAiAttachment a) => a.previewUrl!)
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) UiGap.h(theme.spacing.xs),
            if (items[i].isImage && items[i].previewUrl != null)
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  GestureDetector(
                    onTap: () => showUiLightbox(
                      context,
                      imageUrls: imageUrls,
                      initialIndex: imageUrls
                          .indexOf(items[i].previewUrl!)
                          .clamp(0, imageUrls.length - 1),
                      caption: items[i].name,
                    ),
                    child: Tooltip(
                      message: items[i].name,
                      child: Container(
                        width: context.sz(58),
                        height: context.sz(58),
                        decoration: BoxDecoration(
                          borderRadius: context.radius(theme.radii.md),
                          border: Border.all(
                            color: theme.colors.borderStrong,
                            width: theme.borders.hairline,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: UiRemoteImage(
                          url: items[i].previewUrl,
                          fit: BoxFit.cover,
                          semanticLabel: items[i].name,
                        ),
                      ),
                    ),
                  ),
                  if (editable)
                    Positioned(
                      top: -context.sz(4),
                      right: -context.sz(4),
                      child: UiInteractive(
                        tooltip: 'Remove ${items[i].name}',
                        onTap: () => onRemove(i),
                        builder: (BuildContext ctx, UiInteractiveState _) =>
                            Container(
                              width: ctx.sz(20),
                              height: ctx.sz(20),
                              decoration: BoxDecoration(
                                color: theme.colors.overlay,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colors.surface,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.close_rounded,
                                size: ctx.sz(12),
                                color: theme.colors.onPrimary,
                              ),
                            ),
                      ),
                    ),
                ],
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth > 120 ? maxWidth : 240,
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.xs),
                    vertical: context.sp(4),
                  ),
                  decoration: BoxDecoration(
                    color: theme.colors.surfaceMuted,
                    borderRadius: context.radius(theme.radii.pill),
                    border: Border.all(
                      color: theme.colors.border,
                      width: theme.borders.hairline,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (items[i].kind == AppAiAttachmentKind.link &&
                          items[i].previewUrl != null)
                        AppSiteLogo(
                          url: items[i].previewUrl,
                          label: items[i].name,
                          size: 16,
                        )
                      else
                        Icon(
                          _iconFor(items[i].kind),
                          size: context.sz(14),
                          color: theme.colors.primary,
                        ),
                      UiGap.h(theme.spacing.xxs),
                      Flexible(
                        child: Text(
                          items[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (items[i].subtitle != null) ...<Widget>[
                        UiGap.h(theme.spacing.xxs),
                        Text(
                          items[i].subtitle!,
                          maxLines: 1,
                          style: context.uiText.caption.copyWith(
                            fontSize: context.fs(10),
                            color: theme.colors.foregroundSubtle,
                          ),
                        ),
                      ],
                      if (editable) ...<Widget>[
                        UiGap.h(theme.spacing.xxs),
                        UiInteractive(
                          tooltip: 'Remove ${items[i].name}',
                          onTap: () => onRemove(i),
                          builder: (BuildContext ctx, UiInteractiveState _) =>
                              Icon(
                                Icons.close_rounded,
                                size: ctx.sz(14),
                                color: theme.colors.foregroundMuted,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
