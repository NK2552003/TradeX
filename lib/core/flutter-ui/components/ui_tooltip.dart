import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Themed tooltip wrapper (disabled on touch layouts where hover is absent).
class UiTooltip extends StatelessWidget {
  const UiTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    if (context.uiRes.isMobile) return child;
    return Tooltip(
      message: message,
      waitDuration: theme.motion.normal,
      textStyle: context.uiText.caption.copyWith(color: theme.colors.surface),
      decoration: BoxDecoration(
        color: theme.colors.foreground,
        borderRadius: context.radius(theme.radii.md),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: child,
    );
  }
}
