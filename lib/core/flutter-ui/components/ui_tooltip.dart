import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

class UiTooltip extends StatelessWidget {
  const UiTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return child;
    final theme = context.ui;
    final bool mobile = context.uiRes.isMobile;

    return Tooltip(
      message: message,
      triggerMode: mobile ? TooltipTriggerMode.longPress : null,
      waitDuration: mobile ? Duration.zero : theme.motion.normal,
      textStyle: context.uiText.caption.copyWith(color: theme.colors.surface),
      decoration: BoxDecoration(
        color: theme.colors.foreground,
        borderRadius: context.radius(theme.radii.md),
        boxShadow: theme.shadows.md,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: child,
    );
  }
}
