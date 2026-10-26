import 'package:flutter/material.dart';

import 'ui_chart_base.dart';
import 'ui_common.dart';

/// Line chart. A thin, named configuration of [UiChart] — no painting code is
/// duplicated, so a change to the shared painter updates every chart type.
class UiLineChart extends StatelessWidget {
  UiLineChart({
    super.key,
    List<UiChartPoint>? data,
    List<dynamic>? dataPoints,
    List<UiChartSeries>? series,
    this.height,
    this.showGrid = true,
    this.showAxisLabels = true,
    this.showLegend = true,
    this.valueFormatter,
    this.curved = true,
    this.interactive = true,
    this.toggleableLegend = true,
    this.stacked = false,
    this.glow = false,
    this.thresholds = const <UiChartThreshold>[],
  }) : data = data ?? _mapDataPoints(dataPoints),
       series = series ?? const <UiChartSeries>[UiChartSeries(name: 'Value')];

  final List<UiChartPoint> data;

  /// Series names/colors. Any [UiChartSeries.type] is forced to line here.
  final List<UiChartSeries> series;

  static List<UiChartPoint> _mapDataPoints(List<dynamic>? points) {
    if (points == null) return const <UiChartPoint>[];
    final List<UiChartPoint> result = <UiChartPoint>[];
    for (int i = 0; i < points.length; i++) {
      final dynamic p = points[i];
      if (p is UiChartPoint) {
        result.add(p);
      } else if (p is num) {
        result.add(UiChartPoint(label: '$i', values: <double>[p.toDouble()]));
      } else if (p is Map<String, dynamic>) {
        final String label = p['label']?.toString() ?? '$i';
        final List<double> vals = <double>[];
        if (p['values'] is List) {
          for (final dynamic v in p['values'] as List) {
            if (v is num) vals.add(v.toDouble());
          }
        } else if (p['value'] is num) {
          vals.add((p['value'] as num).toDouble());
        } else if (p['y'] is num) {
          vals.add((p['y'] as num).toDouble());
        }
        result.add(
          UiChartPoint(
            label: label,
            values: vals.isEmpty ? const <double>[0.0] : vals,
          ),
        );
      }
    }
    return result;
  }

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
  final List<UiChartThreshold> thresholds;

  @override
  Widget build(BuildContext context) => UiChart(
    data: data,
    series: series
        .map(
          (UiChartSeries s) => UiChartSeries(
            name: s.name,
            color: s.color,
            type: UiChartSeriesType.line,
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
