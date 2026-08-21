import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_badge.dart';
import 'ui_card.dart';
import 'ui_chart_base.dart';
import 'ui_common.dart';

/// Area chart. Named configuration of [UiChart] with filled series.
class UiAreaChart extends StatelessWidget {
  const UiAreaChart({
    super.key,
    required this.data,
    required this.series,
    this.height,
    this.showGrid = true,
    this.showAxisLabels = true,
    this.showLegend = true,
    this.valueFormatter,
    this.curved = true,
    this.interactive = true,
    this.toggleableLegend = true,
    this.stacked = false,
    bool glow = false,
    bool? lineGlow,
    this.fillOpacity,
    this.gradientColors,
    this.showDots = false,
    this.thresholds = const <UiChartThreshold>[],
  }) : glow = lineGlow ?? glow;

  final List<UiChartPoint> data;
  final List<UiChartSeries> series;
  final double? height;
  final bool showGrid;
  final bool showAxisLabels;
  final bool showLegend;
  final UiValueFormatter? valueFormatter;
  final bool curved;
  final bool interactive;
  final bool toggleableLegend;
  final bool stacked;
  final bool glow;
  final double? fillOpacity;
  final List<Color>? gradientColors;
  final bool showDots;
  final List<UiChartThreshold> thresholds;

  @override
  Widget build(BuildContext context) => UiChart(
    data: data,
    series: series
        .map(
          (UiChartSeries s) => UiChartSeries(
            name: s.name,
            color: s.color,
            type: UiChartSeriesType.area,
            axis: s.axis,
          ),
        )
        .toList(),
    height: height,
    showGrid: showGrid,
    showAxisLabels: showAxisLabels,
    showLegend: showLegend,
    valueFormatter: valueFormatter,
    curved: curved,
    interactive: interactive,
    toggleableLegend: toggleableLegend,
    stacked: stacked,
    glow: glow,
    thresholds: thresholds,
  );
}

class UiAreaChartCard extends StatelessWidget {
  const UiAreaChartCard({
    super.key,
    required this.data,
    required this.series,
    this.title,
    this.subtitle,
    this.metricValue,
    this.metricChange,
    this.isBullish,
    this.initialTimeframe,
    this.timeframes,
    this.onTimeframeChanged,
    this.height,
    this.showGrid = true,
    this.showAxisLabels = true,
    this.showLegend = true,
    this.valueFormatter,
    this.curved = true,
    this.interactive = true,
    this.toggleableLegend = true,
    this.stacked = false,
    bool glow = false,
    bool? lineGlow,
    this.fillOpacity,
    this.gradientColors,
    this.showDots = false,
    this.thresholds = const <UiChartThreshold>[],
  }) : glow = lineGlow ?? glow;

  final List<UiChartPoint> data;
  final List<UiChartSeries> series;
  final String? title;
  final String? subtitle;
  final String? metricValue;
  final String? metricChange;
  final bool? isBullish;
  final String? initialTimeframe;
  final List<String>? timeframes;
  final ValueChanged<String>? onTimeframeChanged;
  final double? height;
  final bool showGrid;
  final bool showAxisLabels;
  final bool showLegend;
  final UiValueFormatter? valueFormatter;
  final bool curved;
  final bool interactive;
  final bool toggleableLegend;
  final bool stacked;
  final bool glow;
  final double? fillOpacity;
  final List<Color>? gradientColors;
  final bool showDots;
  final List<UiChartThreshold> thresholds;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Widget chart = UiAreaChart(
      data: data,
      series: series,
      height: height,
      showGrid: showGrid,
      showAxisLabels: showAxisLabels,
      showLegend: showLegend,
      valueFormatter: valueFormatter,
      curved: curved,
      interactive: interactive,
      toggleableLegend: toggleableLegend,
      stacked: stacked,
      glow: glow,
      fillOpacity: fillOpacity,
      gradientColors: gradientColors,
      showDots: showDots,
      thresholds: thresholds,
    );

    if (metricValue == null && metricChange == null) {
      return UiCard(title: title, subtitle: subtitle, child: chart);
    }

    return UiCard(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              if (metricValue != null)
                Flexible(
                  child: Text(
                    metricValue!,
                    style: context.uiText.heading,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (metricChange != null) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.sm)),
                UiBadge(
                  label: metricChange!,
                  intent: isBullish == false
                      ? UiIntent.danger
                      : UiIntent.success,
                ),
              ],
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          chart,
        ],
      ),
    );
  }
}
