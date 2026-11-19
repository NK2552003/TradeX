part of 'copilot_composer.dart';

class _ComposerActions extends StatelessWidget {
  const _ComposerActions({
    required this.config,
    required this.compact,
    required this.editable,
    required this.submitting,
    required this.dictating,
    required this.canSend,
    required this.onSend,
    required this.onPaste,
    required this.onCopy,
    required this.onPrompt,
    required this.onToggleDictation,
  });
  final CopilotComposer config;
  final bool compact, editable, submitting, dictating, canSend;
  final VoidCallback onSend, onPaste, onCopy, onPrompt, onToggleDictation;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final btnSize = compact ? UiSize.xs : UiSize.sm;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              UiIconButton(
                icon: Icons.add,
                tooltip: 'Attach files',
                variant: UiVariant.outline,
                size: btnSize,
                rounded: true,
                onPressed: editable && !config.attaching
                    ? config.onAttach
                    : null,
              ),
              if (!compact && config.onAttachImage != null)
                UiIconButton(
                  icon: Icons.add_photo_alternate_outlined,
                  tooltip: 'Attach image',
                  variant: UiVariant.outline,
                  size: btnSize,
                  rounded: true,
                  onPressed: editable && !config.attaching
                      ? config.onAttachImage
                      : null,
                ),
              if (!compact && config.onConnectWorkspace != null)
                UiButton(
                  label: 'Connect',
                  icon: Icons.hub_outlined,
                  rounded: true,
                  size: UiSize.sm,
                  variant: UiVariant.outline,
                  onPressed: editable ? config.onConnectWorkspace : null,
                ),
              if (!compact) ...[
                _ModeButton(
                  label: 'Search',
                  icon: Icons.language,
                  selected: config.mode == CopilotPromptMode.search,
                  onPressed: editable && config.canResearch
                      ? () => config.onModeChanged(
                          config.mode == CopilotPromptMode.search
                              ? CopilotPromptMode.auto
                              : CopilotPromptMode.search,
                        )
                      : null,
                ),
                _ModeButton(
                  label: 'Deep research',
                  icon: Icons.travel_explore,
                  selected: config.mode == CopilotPromptMode.research,
                  onPressed: editable && config.canResearch
                      ? () => config.onModeChanged(
                          config.mode == CopilotPromptMode.research
                              ? CopilotPromptMode.auto
                              : CopilotPromptMode.research,
                        )
                      : null,
                ),
              ] else
                UiDropdownMenu(
                  semanticLabel: 'Research mode',
                  enabled: editable,
                  actions: [
                    for (final mode in CopilotPromptMode.values)
                      UiMenuItem(
                        label: switch (mode) {
                          CopilotPromptMode.auto => 'Auto',
                          CopilotPromptMode.search => 'Search',
                          CopilotPromptMode.research => 'Deep research',
                        },
                        selected: config.mode == mode,
                        enabled:
                            mode == CopilotPromptMode.auto ||
                            config.canResearch,
                        onPressed: () => config.onModeChanged(mode),
                      ),
                  ],
                  child: UiButton(
                    label: switch (config.mode) {
                      CopilotPromptMode.auto => 'Auto',
                      CopilotPromptMode.search => 'Search',
                      CopilotPromptMode.research => 'Research',
                    },
                    icon: Icons.language,
                    variant: UiVariant.outline,
                    size: btnSize,
                    rounded: true,
                    onPressed: () {},
                  ),
                ),
              if (config.onFocusChanged != null && !config.compactHeight)
                UiDropdownMenu(
                  semanticLabel: 'Search focus',
                  enabled: editable,
                  actions: [
                    for (final focus in CopilotSearchFocus.values)
                      UiMenuItem(
                        label: focus.label,
                        icon: focus.icon,
                        selected: config.focus == focus,
                        onPressed: () => config.onFocusChanged!(focus),
                      ),
                  ],
                  child: UiButton(
                    label: config.focus == CopilotSearchFocus.all
                        ? 'Focus'
                        : config.focus.label,
                    icon: config.focus.icon,
                    variant: config.focus == CopilotSearchFocus.all
                        ? UiVariant.outline
                        : UiVariant.soft,
                    selected: config.focus != CopilotSearchFocus.all,
                    size: btnSize,
                    rounded: true,
                    onPressed: () {},
                  ),
                ),
              UiDropdownMenu(
                semanticLabel: 'Composer actions',
                actions: [
                  if (config.onAttachImage != null)
                    UiMenuItem(
                      label: 'Upload image / screenshot',
                      icon: Icons.add_photo_alternate_outlined,
                      enabled: editable && !config.attaching,
                      onPressed: config.onAttachImage!,
                    ),
                  if (config.onTakePhoto != null)
                    UiMenuItem(
                      label: 'Take photo',
                      icon: Icons.photo_camera_outlined,
                      enabled: editable && !config.attaching,
                      onPressed: config.onTakePhoto!,
                    ),
                  if (config.onAttachDropzone != null)
                    UiMenuItem(
                      label: 'Drop files or screenshots',
                      icon: Icons.cloud_upload_outlined,
                      enabled: editable && !config.attaching,
                      onPressed: config.onAttachDropzone!,
                    ),
                  if (config.onAttachUrl != null)
                    UiMenuItem(
                      label: 'Attach web link or image URL',
                      icon: Icons.add_link_rounded,
                      enabled: editable && !config.attaching,
                      onPressed: config.onAttachUrl!,
                    ),
                  if (config.onConnectWorkspace != null)
                    UiMenuItem(
                      label: 'Connect workspace (Notes, Journal, Strategy)',
                      icon: Icons.hub_outlined,
                      enabled: editable,
                      onPressed: config.onConnectWorkspace!,
                    ),
                  UiMenuItem(
                    label: dictating
                        ? 'Stop voice dictation'
                        : 'Voice dictation',
                    icon: dictating
                        ? Icons.mic_off_outlined
                        : Icons.mic_none_rounded,
                    enabled: editable,
                    onPressed: onToggleDictation,
                  ),
                  if (config.onVoice != null)
                    UiMenuItem(
                      label: config.voiceActive
                          ? 'End live voice assistant'
                          : 'Start live voice assistant',
                      icon: Icons.graphic_eq_rounded,
                      onPressed: config.onVoice!,
                    ),
                  UiMenuItem(
                    label: 'Paste text',
                    icon: Icons.content_paste,
                    enabled: editable,
                    onPressed: onPaste,
                  ),
                  UiMenuItem(
                    label: 'Copy draft',
                    icon: Icons.copy,
                    enabled: config.controller.text.isNotEmpty,
                    onPressed: onCopy,
                  ),
                  UiMenuItem(
                    label: 'Prompt library',
                    icon: Icons.bolt_outlined,
                    enabled: editable,
                    onPressed: onPrompt,
                  ),
                  UiMenuItem(
                    label: 'Clear text',
                    icon: Icons.clear_all,
                    enabled: editable && config.controller.text.isNotEmpty,
                    onPressed: config.controller.clear,
                  ),
                ],
                child: UiIconButton(
                  icon: Icons.more_horiz,
                  tooltip: 'Composer actions',
                  variant: UiVariant.outline,
                  size: btnSize,
                  rounded: true,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
        UiGap.h(theme.spacing.xs),
        if (config.busy || submitting)
          UiIconButton(
            icon: Icons.stop_rounded,
            tooltip: 'Stop response',
            variant: UiVariant.solid,
            size: btnSize,
            rounded: true,
            onPressed: config.onStop,
          )
        else ...[
          UiIconButton(
            key: const ValueKey('copilot-composer-voice-button'),
            icon: config.voiceActive
                ? Icons.graphic_eq_rounded
                : (dictating ? Icons.mic_rounded : Icons.mic_none_rounded),
            tooltip: config.voiceActive
                ? 'End voice call'
                : (config.onVoice != null
                      ? 'Start voice call'
                      : (dictating ? 'Stop voice input' : 'Voice input')),
            variant: (config.voiceActive || dictating)
                ? UiVariant.solid
                : UiVariant.outline,
            intent: config.voiceActive
                ? UiIntent.primary
                : (dictating ? UiIntent.success : null),
            size: btnSize,
            rounded: true,
            onPressed: config.onVoice ?? (editable ? onToggleDictation : null),
          ),
          UiGap.h(theme.spacing.xs),
          UiButton(
            label: 'Send message',
            icon: Icons.arrow_upward,
            iconOnly: true,
            rounded: true,
            size: btnSize,
            variant: UiVariant.solid,
            onPressed: canSend ? onSend : null,
          ),
        ],
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => UiButton(
    label: label,
    icon: icon,
    rounded: true,
    size: UiSize.sm,
    variant: selected ? UiVariant.soft : UiVariant.outline,
    selected: selected,
    onPressed: onPressed,
  );
}
