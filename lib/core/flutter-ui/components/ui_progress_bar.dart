import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Linear progress bar (goal completion, order fill %).
class UiProgressBar extends StatelessWidget {
  const UiProgressBar({
    super.key,
    required this.value,
    this.label,
    this.showValue = true,
    this.intent = UiIntent.primary,
    this.thickness,
    this.valueFormatter,
  });

  /// 0..1
  final double value;
  final String? label;
  final bool showValue;
  final UiIntent intent;
  final double? thickness;
  final UiValueFormatter? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final double t = value.clamp(0, 1);
    final double h = context.sz(thickness ?? theme.sizes.trackThickness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null || showValue)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
            child: Row(
              children: <Widget>[
                if (label != null)
                  Expanded(
                    child: Text(
                      label!,
                      // Ellipsis without a line cap still wraps first and then
                      // clips against the row height; the cap is what makes it
                      // truncate on one line instead.
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.label.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ),
                if (showValue) ...<Widget>[
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Flexible(
                    child: Text(
                      valueFormatter?.call(t * 100) ??
                          '${(t * 100).toStringAsFixed(0)}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: context.uiText.numeric.copyWith(
                        color: theme.colors.foreground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ClipRRect(
          borderRadius: context.radius(theme.radii.pill),
          child: SizedBox(
            height: h,
            child: Stack(
              children: <Widget>[
                Container(color: theme.colors.surfaceMuted),
                FractionallySizedBox(
                  widthFactor: t,
                  child: AnimatedContainer(
                    duration: theme.motion.normal,
                    curve: theme.motion.curve,
                    color: intent.color(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
