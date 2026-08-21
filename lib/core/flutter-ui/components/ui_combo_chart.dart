import 'package:flutter/material.dart';

import 'ui_chart_base.dart';
import 'ui_common.dart';

/// Combo chart: mixed bar + line/area series on one plot. Series keep the
/// [UiChartSeries.type] you give them.
class UiComboChart extends StatelessWidget {
  const UiComboChart({
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
