import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Checkbox with tri-state support and optional label/description row.
class UiCheckbox extends StatelessWidget {
  const UiCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.description,
    this.indeterminate = false,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? description;
  final bool indeterminate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final double dim = context.sz(theme.sizes.checkbox);
    final bool active = value || indeterminate;

    return UiInteractive(
      enabled: enabled && onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      semanticLabel: label,
      builder: (BuildContext ctx, UiInteractiveState s) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AnimatedContainer(
            duration: theme.motion.fast,
            width: dim,
            height: dim,
            margin: EdgeInsets.only(top: ctx.sp(theme.spacing.xxs)),
            decoration: BoxDecoration(
              color: !enabled
                  ? c.disabledBackground
                  : active
                      ? c.primary
                      : c.surface,
              borderRadius: ctx.radius(theme.radii.sm),
              border: Border.all(
                color: !enabled
                    ? c.border
                    : active
                        ? c.primary
                        : (s.hovered ? c.borderStrong : c.border),
                width: theme.borders.thick,
              ),
            ),
            foregroundDecoration: s.focused
                ? uiFocusRing(ctx, ctx.radius(theme.radii.sm))
                : null,
            child: active
                ? Icon(
                    indeterminate ? Icons.remove : Icons.check,
                    size: dim * 0.8,
                    color: enabled ? c.onPrimary : c.disabledForeground,
                  )
                : null,
          ),
          if (label != null) ...<Widget>[
            SizedBox(width: ctx.sp(theme.spacing.sm)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label!,
                    style: ctx.uiText.body.copyWith(
                      color: enabled ? c.foreground : c.disabledForeground,
                    ),
                  ),
                  if (description != null)
                    Text(
                      description!,
                      style: ctx.uiText.caption
                          .copyWith(color: c.foregroundMuted),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
