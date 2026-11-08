part of 'copilot_composer.dart';

class _ComposerActions extends StatelessWidget {
  const _ComposerActions({
    required this.config,
    required this.compact,
    required this.editable,
    required this.submitting,
    required this.canSend,
    required this.onSend,
    required this.onPaste,
    required this.onCopy,
    required this.onPrompt,
  });
  final CopilotComposer config;
  final bool compact, editable, submitting, canSend;
  final VoidCallback onSend, onPaste, onCopy, onPrompt;
  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: [
              UiIconButton(
                icon: Icons.add,
                tooltip: 'Attach files',
                variant: UiVariant.outline,
                size: UiSize.sm,
                onPressed: editable && !config.attaching
                    ? config.onAttach
                    : null,
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
                    size: UiSize.sm,
                    rounded: true,
                    onPressed: () {},
                  ),
                ),
              UiDropdownMenu(
                semanticLabel: 'Composer actions',
                actions: [
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
                  size: UiSize.sm,
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
            onPressed: config.onStop,
          )
        else if (config.controller.text.trim().isEmpty &&
            config.attachments.isEmpty)
          UiButton(
            label: config.voiceActive ? 'End voice call' : 'Start voice call',
            icon: Icons.graphic_eq,
            iconOnly: true,
            rounded: true,
            variant: UiVariant.solid,
            onPressed: config.onVoice,
          )
        else
          UiButton(
            label: 'Send message',
            icon: Icons.arrow_upward,
            iconOnly: true,
            rounded: true,
            variant: UiVariant.solid,
            onPressed: canSend ? onSend : null,
          ),
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
