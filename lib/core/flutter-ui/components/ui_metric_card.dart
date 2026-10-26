import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_badge.dart';
import 'ui_card.dart';
import 'ui_common.dart';
import 'ui_spark_chart.dart';

/// A metric with a clear reading order: label, value, change, then context.
/// Content determines its height, including at accessibility text sizes.
class UiMetricCard extends StatelessWidget {
  const UiMetricCard({
    super.key,
    String? label,
    String? title,
    required this.value,
    this.delta,
    this.change,
    this.isPositive,
    String? subtitle,
    String? caption,
    this.icon,
    this.chart,
    this.sparkline,
    this.intent,
    this.onTap,
  }) : label = title ?? label ?? '',
       subtitle = subtitle ?? caption;

  final String label;
  final String value;
  final num? delta;
  final String? change;
  final bool? isPositive;
  final String? subtitle;
  final IconData? icon;
  final Widget? chart;
  final List<double>? sparkline;
  final UiIntent? intent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final effectiveChange =
        change ?? (delta != null ? uiSignedPercent(delta!) : null);
    final positive = isPositive ?? (delta != null ? delta! >= 0 : null);
    final changeIntent = positive == null
        ? UiIntent.neutral
        : positive
        ? UiIntent.success
        : UiIntent.danger;
    final trend =
        chart ??
        (sparkline != null && sparkline!.length > 1
            ? UiSparkChart(
                data: sparkline!,
                color: (intent ?? UiIntent.primary).color(context),
              )
            : null);

    return UiCard(
      onTap: onTap,
      semanticLabel: '$label: $value',
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      minHeight: context.sz(144),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.uiText.label.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ),
              if (icon != null) ...[
                SizedBox(width: context.sp(theme.spacing.sm)),
                Icon(
                  icon,
                  size: context.sz(theme.sizes.iconSm),
                  color: (intent ?? UiIntent.neutral).color(context),
                ),
              ],
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(
            value,
            style: context.uiText.title.copyWith(
              color: theme.colors.foreground,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (effectiveChange != null) ...[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Align(
              alignment: Alignment.centerLeft,
              child: UiBadge(
                label: effectiveChange,
                intent: changeIntent,
                size: UiSize.xs,
              ),
            ),
          ],
          if (subtitle != null) ...[
            SizedBox(height: context.sp(theme.spacing.sm)),
            Text(
              subtitle!,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
          if (trend != null) ...[
            SizedBox(height: context.sp(theme.spacing.sm)),
            SizedBox(height: context.sz(32), child: trend),
          ],
        ],
      ),
    );
  }
}
