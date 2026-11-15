import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../models/trader_skill.dart';
import '../models/workspace.dart';
import 'trader_skill_picker.dart';

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
    this.enabled = true,
    this.busy = false,
    this.attaching = false,
    this.canResearch = true,
    this.onStop,
    this.onVoice,
    this.onConnectWorkspace,
    this.voiceActive = false,
    this.compactHeight = false,
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
  final CopilotPromptMode mode;
  final bool enabled, busy, attaching, canResearch, voiceActive;
  final bool compactHeight;
  final VoidCallback? onStop, onVoice, onConnectWorkspace;

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
              UiGap.v(
                widget.compactHeight ? theme.spacing.xs : theme.spacing.sm,
              ),
            ],
            UiCard(
              key: const ValueKey('copilot-composer-surface'),
              variant: UiCardVariant.elevated,
              borderRadius: context.radius(theme.radii.xl),
              padding: EdgeInsets.all(
                context.sp(
                  widget.compactHeight ? theme.spacing.sm : theme.spacing.md,
                ),
              ),
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
                  if (widget.attachments.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(theme.spacing.xs),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (
                              var i = 0;
                              i < widget.attachments.length;
                              i++
                            ) ...[
                              if (i > 0) UiGap.h(theme.spacing.xs),
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
                          ],
                        ),
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
                        minLines: widget.compactHeight ? 1 : 2,
                        maxLines: widget.compactHeight ? 2 : (compact ? 4 : 6),
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
            UiGap.v(theme.spacing.xs),
            Row(
              children: [
                if (!compact)
                  Expanded(
                    child: Text(
                      'Enter or Ctrl/Cmd + Enter to send · Voice ready',
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
