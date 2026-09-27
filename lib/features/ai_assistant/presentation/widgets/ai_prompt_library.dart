import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_design.dart';

/// Grouped library of starter prompts. Each map key is a section title; the
/// values are the prompts under it. Tapping a chip sends it straight into the
/// active conversation. All prompt text is supplied by the caller.
class AiPromptLibrary extends StatelessWidget {
  const AiPromptLibrary({
    super.key,
    required this.library,
    required this.onSelect,
  });

  final Map<String, List<AppAiPrompt>> library;
  final ValueChanged<AppAiPrompt> onSelect;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<String> sections = library.keys.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int s = 0; s < sections.length; s++) ...<Widget>[
          if (s > 0) SizedBox(height: context.sp(theme.spacing.sm)),
          AiSectionHeader(title: sections[s]),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              for (final AppAiPrompt p in library[sections[s]]!)
                UiBadge(
                  label: p.label,
                  icon: p.icon ?? Icons.bolt_outlined,
                  intent: UiIntent.primary,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.md,
                  onTap: () => onSelect(p),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
