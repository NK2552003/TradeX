import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../models/workspace.dart';

part 'copilot_composer_actions.dart';

enum CopilotPromptMode { auto, search, research }

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
    this.profileId,
    this.attachments = const [],
    this.enabled = true,
    this.busy = false,
    this.attaching = false,
    this.canResearch = true,
    this.onStop,
    this.onVoice,
    this.voiceActive = false,
    this.compactHeight = false,
  });
  final TextEditingController controller;
  final Future<void> Function() onSend;
  final VoidCallback? onAttach;
  final ValueChanged<int> onRemoveAttachment;
  final ValueChanged<CopilotPromptMode> onModeChanged;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onNewConversation;
  final List<Specialist> profiles;
  final String? profileId;
  final List<String> attachments;
  final CopilotPromptMode mode;
  final bool enabled, busy, attaching, canResearch, voiceActive;
  final bool compactHeight;
  final VoidCallback? onStop, onVoice;

  @override
  State<CopilotComposer> createState() => _CopilotComposerState();
}

class _CopilotComposerState extends State<CopilotComposer> {
  final _focus = FocusNode();
  bool _submitting = false;
  bool get _editable => !widget.busy && !_submitting;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_editable ||
        !widget.enabled ||
        widget.attaching ||
        (widget.controller.text.trim().isEmpty && widget.attachments.isEmpty)) {
      return;
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
            UiGap.v(theme.spacing.sm),
            UiCard(
              key: const ValueKey('copilot-composer-surface'),
              variant: UiCardVariant.elevated,
              borderRadius: context.radius(theme.radii.xl),
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.attachments.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(theme.spacing.xs),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Wrap(
                          spacing: context.sp(theme.spacing.xs),
                          runSpacing: context.sp(theme.spacing.xs),
                          children: [
                            for (var i = 0; i < widget.attachments.length; i++)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      box.maxWidth -
                                      context.sp(theme.spacing.xl),
                                ),
                                child: UiButton(
                                  label: widget.attachments[i],
                                  icon: Icons.attach_file,
                                  trailingIcon: Icons.close,
                                  tooltip: 'Remove ${widget.attachments[i]}',
                                  variant: UiVariant.soft,
                                  size: UiSize.xs,
                                  rounded: true,
                                  onPressed: _editable
                                      ? () => widget.onRemoveAttachment(i)
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Shortcuts(
                    shortcuts: const {
                      SingleActivator(LogicalKeyboardKey.enter):
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
                            ? 'Ask anything, or add a file…'
                            : 'Ask anything, paste your notes, or add a file…',
                        minLines: widget.compactHeight ? 1 : 2,
                        maxLines: widget.compactHeight ? 2 : (compact ? 4 : 6),
                        maxLength: 24000,
                        variant: UiInputVariant.ghost,
                        readOnly: !_editable,
                      ),
                    ),
                  ),
                  if (value.text == '/' && _editable)
                    Wrap(
                      children: [
                        for (final prompt in const [
                          'Summarize these notes',
                          'Compare these ideas',
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
                  _ComposerActions(
                    config: widget,
                    compact: compact,
                    editable: _editable,
                    submitting: _submitting,
                    canSend: canSend,
                    onSend: _send,
                    onPaste: _paste,
                    onCopy: _copy,
                    onPrompt: () => _prompt('/'),
                  ),
                ],
              ),
            ),
            UiGap.v(theme.spacing.xs),
            Row(
              children: [
                if (!compact)
                  Expanded(
                    child: Text(
                      'Ctrl/Cmd + Enter to send',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    '${value.text.characters.length} chars / $words words',
                    textAlign: TextAlign.right,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundSubtle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
