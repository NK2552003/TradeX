import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../theme/app_tokens.dart';

/// Compact trend tile: a label, a headline value, an optional signed-change
/// chip and an inline area sparkline — one shared viz idiom for hero bands
/// across Market, AI and Messages. Values/changes are formatted through
/// [AppTokens] so every surface reads the same way.
///
/// A thin composition over [UiCard] + [UiAreaChart]; it adds no new painting.
class AppTrendTile extends StatelessWidget {
  const AppTrendTile({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.changeLabel,
    this.changeIsPercent = true,
    this.spark = const <double>[],
    this.intent,
    this.icon,
    this.onTap,
    this.sparkHeight,
  });

  final String label;
  final String value;

  /// Signed change driving the chip colour (and its text, unless
  /// [changeLabel] overrides). Positive → bullish, negative → bearish.
  final num? change;

  /// Pre-formatted change text, when the caller wants something other than the
  /// default signed percent / signed money.
  final String? changeLabel;
  final bool changeIsPercent;

  /// Sparkline samples (oldest → newest). Needs at least two to draw.
  final List<double> spark;

  /// Overrides the colour that would otherwise be derived from [change].
  final UiIntent? intent;
  final IconData? icon;
  final VoidCallback? onTap;
  final double? sparkHeight;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final num? ch = change;
    final UiIntent effIntent =
        intent ?? (ch != null ? AppTokens.plIntent(ch) : UiIntent.neutral);
    final Color accent = effIntent.color(context);
    final String? changeText =
        changeLabel ??
        (ch != null
            ? (changeIsPercent
                  ? AppTokens.signedPercent(ch)
                  : AppTokens.signedMoney(ch))
            : null);

    return UiCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: context.sz(theme.sizes.iconSm),
                  color: theme.colors.foregroundMuted,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.label.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.title.copyWith(
                    color: theme.colors.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (changeText != null) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.xs)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.xs),
                    vertical: context.sp(theme.spacing.xxs * 0.5),
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: context.radius(theme.radii.sm),
                  ),
                  child: Text(
                    changeText,
                    maxLines: 1,
                    style: context.uiText.caption.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (spark.length >= 2) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            SizedBox(
              height: context.sz(sparkHeight ?? 52),
              child: UiAreaChart(
                height: sparkHeight ?? 52,
                data: <UiChartPoint>[
                  for (final double v in spark)
                    UiChartPoint(label: '', values: <double>[v]),
                ],
                series: <UiChartSeries>[
                  UiChartSeries(
                    name: label,
                    type: UiChartSeriesType.area,
                    color: accent,
                  ),
                ],
                showGrid: false,
                showAxisLabels: false,
                showLegend: false,
                interactive: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
