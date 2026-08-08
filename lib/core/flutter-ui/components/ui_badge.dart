import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_common.dart';

/// Status / tag chip. Also covers price-change deltas used in market lists.
class UiBadge extends StatelessWidget {
  const UiBadge({
    super.key,
    required this.label,
    this.intent = UiIntent.neutral,
    this.size = UiSize.sm,
    this.icon,
    this.filled = false,
    this.onTap,
  });

  /// Convenience for "+2.43%" / "-1.10%" market deltas.
  factory UiBadge.delta(
    num percent, {
    Key? key,
    UiSize size = UiSize.sm,
    int decimals = 2,
  }) =>
      UiBadge(
        key: key,
        label: uiSignedPercent(percent, decimals: decimals),
        intent: percent >= 0 ? UiIntent.bullish : UiIntent.bearish,
        icon: percent >= 0 ? Icons.trending_up : Icons.trending_down,
        size: size,
      );

  final String label;
  final UiIntent intent;
  final UiSize size;
  final IconData? icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Color base = intent.color(context);
    final BorderRadius radius = context.radius(theme.radii.pill);
    final TextStyle textStyle =
        (size == UiSize.sm ? context.uiText.caption : context.uiText.label)
            .copyWith(
      color: filled ? theme.colors.onPrimary : base,
      fontWeight: FontWeight.w600,
    );

    final Widget chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xxs),
      ),
      decoration: BoxDecoration(
        color: filled ? base : base.withValues(alpha: 0.12),
        borderRadius: radius,
        border: Border.all(
          color: base.withValues(alpha: filled ? 0 : 0.3),
          width: theme.borders.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: size.icon(context) * 0.85, color: textStyle.color),
            SizedBox(width: context.sp(theme.spacing.xxs)),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );

    if (onTap == null) return chip;
    return UiInteractive(onTap: onTap, builder: (_, __) => chip);
  }
}
