import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';

/// Compact pill showing the copilot's current [AiPersona]. Tapping it opens the
/// persona picker. Sits in the chat header so the active analytical lens is
/// always visible.
class AiPersonaChip extends StatelessWidget {
  const AiPersonaChip({
    super.key,
    required this.persona,
    this.onTap,
    this.dense = false,
  });

  final AiPersona persona;
  final VoidCallback? onTap;

  /// Shows only the short label — used where horizontal space is tight.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return UiInteractive(
      onTap: onTap,
      builder: (BuildContext context, UiInteractiveState state) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.xxs),
          ),
          decoration: BoxDecoration(
            color: state.hovered ? colors.surfaceHover : colors.surfaceMuted,
            borderRadius: context.radius(theme.radii.pill),
            border: Border.all(
              color: colors.border,
              width: theme.borders.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                persona.icon,
                size: context.sz(theme.sizes.iconSm),
                color: colors.primary,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Text(
                dense ? persona.shortLabel : persona.label,
                style: context.uiText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.foreground,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Icon(
                Icons.expand_more_rounded,
                size: context.sz(theme.sizes.iconSm),
                color: colors.foregroundMuted,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Vertical list of selectable persona cards (icon, label, tagline). Used inside
/// the persona dialog and the desktop thread rail.
class AiPersonaSelector extends StatelessWidget {
  const AiPersonaSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AiPersona selected;
  final ValueChanged<AiPersona> onChanged;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final AiPersona p in AiPersona.values)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
            child: _PersonaRow(
              persona: p,
              selected: p == selected,
              onTap: () => onChanged(p),
            ),
          ),
      ],
    );
  }
}

class _PersonaRow extends StatelessWidget {
  const _PersonaRow({
    required this.persona,
    required this.selected,
    required this.onTap,
  });

  final AiPersona persona;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return UiCard(
      onTap: onTap,
      selected: selected,
      accentColor: selected ? colors.primary : null,
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Row(
        children: <Widget>[
          Container(
            width: context.sz(38),
            height: context.sz(38),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? colors.primary.withValues(alpha: 0.14)
                  : colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.md),
            ),
            child: Icon(
              persona.icon,
              size: context.sz(theme.sizes.iconMd),
              color: selected ? colors.primary : colors.foregroundMuted,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(persona.label, style: context.uiText.bodyStrong),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  persona.tagline,
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(
              Icons.check_circle_rounded,
              size: context.sz(theme.sizes.iconMd),
              color: colors.primary,
            ),
        ],
      ),
    );
  }
}
