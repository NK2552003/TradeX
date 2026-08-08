import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_common.dart';

/// Single icon toggle (bookmark, like, follow).
class UiToggle extends StatelessWidget {
  const UiToggle({
    super.key,
    required this.value,
    required this.icon,
    this.activeIcon,
    this.onChanged,
    this.label,
    this.activeIntent = UiIntent.primary,
    this.size = UiSize.md,
  });

  final bool value;
  final IconData icon;
  final IconData? activeIcon;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final UiIntent activeIntent;
  final UiSize size;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Color active = activeIntent.color(context);
    return UiInteractive(
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      semanticLabel: label,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        padding: EdgeInsets.symmetric(
          horizontal: ctx.sp(theme.spacing.sm),
          vertical: ctx.sp(theme.spacing.xs),
        ),
        decoration: BoxDecoration(
          color: value
              ? active.withValues(alpha: 0.12)
              : (s.hovered ? theme.colors.surfaceHover : Colors.transparent),
          borderRadius: ctx.radius(theme.radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              value ? (activeIcon ?? icon) : icon,
              size: size.icon(ctx),
              color: value ? active : theme.colors.foregroundMuted,
            ),
            if (label != null) ...<Widget>[
              SizedBox(width: ctx.sp(theme.spacing.xs)),
              Text(
                label!,
                style: ctx.uiText.label.copyWith(
                  color: value ? active : theme.colors.foregroundMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
