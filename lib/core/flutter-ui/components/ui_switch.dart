import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_common.dart';

/// On/off switch with optional label + description.
class UiSwitch extends StatelessWidget {
  const UiSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.description,
    this.enabled = true,
    this.activeColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? description;
  final bool enabled;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final double w = context.sz(theme.sizes.switchWidth);
    final double h = context.sz(theme.sizes.switchHeight);
    final double knob = h - context.sz(4);
    final Color onColor = activeColor ?? c.primary;

    final Widget track = UiInteractive(
      enabled: enabled && onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      semanticLabel: label,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        curve: theme.motion.curve,
        width: w,
        height: h,
        padding: EdgeInsets.all(ctx.sz(2)),
        decoration: BoxDecoration(
          color: !enabled
              ? c.disabledBackground
              : value
                  ? onColor
                  : c.borderStrong,
          borderRadius: ctx.radius(theme.radii.pill),
        ),
        foregroundDecoration: s.focused
            ? uiFocusRing(ctx, ctx.radius(theme.radii.pill))
            : null,
        child: AnimatedAlign(
          duration: theme.motion.fast,
          curve: theme.motion.curve,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knob,
            height: knob,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface,
              boxShadow: theme.shadows.sm,
            ),
          ),
        ),
      ),
    );

    if (label == null) return track;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label!,
                style: context.uiText.body.copyWith(
                  color: enabled ? c.foreground : c.disabledForeground,
                ),
              ),
              if (description != null)
                Text(
                  description!,
                  style: context.uiText.caption
                      .copyWith(color: c.foregroundMuted),
                ),
            ],
          ),
        ),
        SizedBox(width: context.sp(theme.spacing.md)),
        track,
      ],
    );
  }
}
