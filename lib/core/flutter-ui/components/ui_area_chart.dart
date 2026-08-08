import 'package:flutter/material.dart';

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
      );
}
