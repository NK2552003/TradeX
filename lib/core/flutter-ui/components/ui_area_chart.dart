import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_badge.dart';
import 'ui_card.dart';
import 'ui_chart_base.dart';
import 'ui_common.dart';
import 'ui_toggle_group.dart';

/// Area chart. Named configuration of [UiChart] with filled series.
class UiAreaChart extends StatelessWidget {
  const UiAreaChart({
    super.key,
    this.data = const <UiChartPoint>[],
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
            type: s.type,
            axis: s.axis,
            lineGlow: s.lineGlow,
            fillOpacity: s.fillOpacity,
            gradientColors: s.gradientColors,
            showDots: s.showDots,
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

class UiAreaChartCard extends StatefulWidget {
  const UiAreaChartCard({
    super.key,
    this.data = const <UiChartPoint>[],
    required this.series,
    this.title,
    this.subtitle,
    String? metricValue,
    String? value,
    this.metricChange,
    this.isBullish,
    this.initialTimeframe,
    List<String>? timeframes,
    List<String>? timeframeOptions,
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
  })  : metricValue = value ?? metricValue,
        timeframes = timeframeOptions ?? timeframes,
        glow = lineGlow ?? glow;

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
  State<UiAreaChartCard> createState() => _UiAreaChartCardState();
}

class _UiAreaChartCardState extends State<UiAreaChartCard> {
  late String? _currentTimeframe =
      widget.initialTimeframe ?? widget.timeframes?.firstOrNull;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Widget chart = UiAreaChart(
      data: widget.data,
      series: widget.series,
      height: widget.height,
      showGrid: widget.showGrid,
      showAxisLabels: widget.showAxisLabels,
      showLegend: widget.showLegend,
      valueFormatter: widget.valueFormatter,
      curved: widget.curved,
      interactive: widget.interactive,
      toggleableLegend: widget.toggleableLegend,
      stacked: widget.stacked,
      glow: widget.glow,
      fillOpacity: widget.fillOpacity,
      gradientColors: widget.gradientColors,
      showDots: widget.showDots,
      thresholds: widget.thresholds,
    );

    final bool hasPills =
        widget.timeframes != null && widget.timeframes!.isNotEmpty;
    final Widget? switcher = hasPills
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: UiToggleGroup<String>(
              value: _currentTimeframe ?? widget.timeframes!.first,
              options: widget.timeframes!
                  .map((String t) => UiOption<String>(label: t, value: t))
                  .toList(),
              size: UiSize.sm,
              onChanged: (String val) {
                setState(() => _currentTimeframe = val);
                widget.onTimeframeChanged?.call(val);
              },
            ),
          )
        : null;

    if (widget.metricValue == null &&
        widget.metricChange == null &&
        !hasPills) {
      return UiCard(
        title: widget.title,
        subtitle: widget.subtitle,
        child: chart,
      );
    }

    return UiCard(
      title: widget.title,
      subtitle: widget.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.md),
            runSpacing: context.sp(theme.spacing.sm),
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  if (widget.metricValue != null)
                    Flexible(
                      child: Text(
                        widget.metricValue!,
                        style: context.uiText.heading,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (widget.metricChange != null) ...<Widget>[
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    UiBadge(
                      label: widget.metricChange!,
                      intent: widget.isBullish == false
                          ? UiIntent.danger
                          : UiIntent.success,
                    ),
                  ],
                ],
              ),
              ?switcher,
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          chart,
        ],
      ),
    );
  }
}
