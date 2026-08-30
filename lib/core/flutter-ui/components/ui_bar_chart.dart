import 'package:flutter/material.dart';

import 'ui_chart_base.dart';
import 'ui_common.dart';

/// Bar chart. Named configuration of [UiChart] with bar series.
class UiBarChart extends StatelessWidget {
  const UiBarChart({
    super.key,
    required this.data,
    required this.series,
    this.height,
    this.showGrid = true,
    this.showAxisLabels = true,
    this.showLegend = true,
    this.valueFormatter,
    this.interactive = true,
    this.toggleableLegend = true,
    this.stacked = false,
    this.glow = false,
    this.thresholds = const <UiChartThreshold>[],
  });

  final List<UiChartPoint> data;
  final List<UiChartSeries> series;
  final double? height;
  final bool showGrid;
  final bool showAxisLabels;
  final bool showLegend;
  final UiValueFormatter? valueFormatter;
  final bool interactive;
  final bool toggleableLegend;
  final bool stacked;
  final bool glow;
  final List<UiChartThreshold> thresholds;

  @override
  Widget build(BuildContext context) => UiChart(
    data: data,
    series: series
        .map(
          (UiChartSeries s) => UiChartSeries(
            name: s.name,
            color: s.color,
            type: UiChartSeriesType.bar,
            axis: s.axis,
          ),
        )
        .toList(),
    height: height,
    showGrid: showGrid,
    showAxisLabels: showAxisLabels,
    showLegend: showLegend,
    valueFormatter: valueFormatter,
    curved: false,
    interactive: interactive,
    toggleableLegend: toggleableLegend,
    stacked: stacked,
    glow: glow,
    thresholds: thresholds,
  );
}
