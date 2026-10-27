import 'package:flutter/material.dart';

import 'ui_chart_base.dart';
import 'ui_common.dart';

/// Combo chart: mixed bar + line/area series on one plot. Series keep the
/// [UiChartSeries.type] you give them.
class UiComboChart extends StatelessWidget {
  UiComboChart({
    super.key,
    this.data = const <UiChartPoint>[],
    List<UiChartSeries>? series,
    dynamic lineSeries,
    dynamic barSeries,
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
  }) : series = series ?? _combineSeries(lineSeries, barSeries);

  final List<UiChartPoint> data;
  final List<UiChartSeries> series;

  static List<UiChartSeries> _combineSeries(dynamic lines, dynamic bars) {
    final List<UiChartSeries> out = <UiChartSeries>[];
    void addOne(dynamic item, UiChartSeriesType fallbackType) {
      if (item is UiChartSeries) {
        out.add(item);
      } else if (item is String) {
        out.add(UiChartSeries(name: item, type: fallbackType));
      }
    }

    if (lines is Iterable) {
      for (final dynamic e in lines) {
        addOne(e, UiChartSeriesType.line);
      }
    } else if (lines != null) {
      addOne(lines, UiChartSeriesType.line);
    }
    if (bars is Iterable) {
      for (final dynamic e in bars) {
        addOne(e, UiChartSeriesType.bar);
      }
    } else if (bars != null) {
      addOne(bars, UiChartSeriesType.bar);
    }
    return out.isEmpty
        ? const <UiChartSeries>[UiChartSeries(name: 'Data')]
        : out;
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
    thresholds: thresholds,
  );
}
