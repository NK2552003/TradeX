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
    this.fillOpacity = 0.35,
    this.showDots = false,
    this.lineGlow = false,
    this.baseline,
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
  final double fillOpacity;
  final bool showDots;
  final bool lineGlow;
  final double? baseline;

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
                gradientColors: s.gradientColors,
                fillOpacity: s.fillOpacity,
                strokeWidth: s.strokeWidth,
                showDots: s.showDots,
                lineGlow: s.lineGlow,
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
        fillOpacity: fillOpacity,
        showDots: showDots,
        lineGlow: lineGlow,
        baseline: baseline,
      );
}

/// Professional Level Area Chart Card with header metrics, timeframe selector,
/// and interactive options (Curved, Grid, Area Fill, Dots).
class UiAreaChartCard extends StatefulWidget {
  const UiAreaChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.data,
    required this.series,
    this.metricValue,
    this.metricChange,
    this.isBullish = true,
    this.height = 200,
    this.showControls = true,
    this.showMetrics = true,
    this.timeframes = const <String>['1D', '1W', '1M', '1Y', 'ALL'],
    this.initialTimeframe = '1M',
    this.onTimeframeChanged,
    this.valueFormatter,
  });

  final String title;
  final String? subtitle;
  final List<UiChartPoint> data;
  final List<UiChartSeries> series;
  final String? metricValue;
  final String? metricChange;
  final bool isBullish;
  final double height;
  final bool showControls;
  final bool showMetrics;
  final List<String> timeframes;
  final String initialTimeframe;
  final ValueChanged<String>? onTimeframeChanged;
  final UiValueFormatter? valueFormatter;

  @override
  State<UiAreaChartCard> createState() => _UiAreaChartCardState();
}

class _UiAreaChartCardState extends State<UiAreaChartCard> {
  late String _selectedTimeframe;
  bool _curved = true;
  bool _showGrid = true;
  bool _filled = true;
  bool _showDots = false;

  @override
  void initState() {
    super.initState();
    _selectedTimeframe = widget.initialTimeframe;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return UiCard(
      title: widget.title,
      subtitle: widget.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.showMetrics || widget.timeframes.isNotEmpty) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                if (widget.showMetrics && widget.metricValue != null)
                  Row(
                    children: <Widget>[
                      Text(
                        widget.metricValue!,
                        style: context.uiText.heading.copyWith(
                          fontSize: context.sp(20),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.metricChange != null) ...<Widget>[
                        SizedBox(width: context.sp(theme.spacing.sm)),
                        UiBadge(
                          label: widget.metricChange!,
                          intent: widget.isBullish
                              ? UiIntent.bullish
                              : UiIntent.bearish,
                        ),
                      ],
                    ],
                  ),
                if (widget.timeframes.isNotEmpty)
                  UiToggleGroup<String>(
                    value: _selectedTimeframe,
                    options: <UiToggleOption<String>>[
                      for (final String tf in widget.timeframes)
                        UiToggleOption<String>(value: tf, label: tf),
                    ],
                    onChanged: (String val) {
                      setState(() => _selectedTimeframe = val);
                      widget.onTimeframeChanged?.call(val);
                    },
                  ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
          ],
          if (widget.showControls) ...<Widget>[
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                _OptionChip(
                  label: _curved ? 'Smooth Curve' : 'Straight Line',
                  icon: Icons.show_chart,
                  active: _curved,
                  onTap: () => setState(() => _curved = !_curved),
                ),
                _OptionChip(
                  label: _filled ? 'Area Gradient' : 'Line Only',
                  icon: Icons.gradient,
                  active: _filled,
                  onTap: () => setState(() => _filled = !_filled),
                ),
                _OptionChip(
                  label: _showGrid ? 'Grid On' : 'Grid Off',
                  icon: Icons.grid_on,
                  active: _showGrid,
                  onTap: () => setState(() => _showGrid = !_showGrid),
                ),
                _OptionChip(
                  label: _showDots ? 'Data Dots' : 'Dots Off',
                  icon: Icons.bubble_chart,
                  active: _showDots,
                  onTap: () => setState(() => _showDots = !_showDots),
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
          ],
          UiAreaChart(
            data: widget.data,
            series: widget.series,
            height: widget.height,
            curved: _curved,
            showGrid: _showGrid,
            fillOpacity: _filled ? 0.35 : 0.0,
            showDots: _showDots,
            valueFormatter: widget.valueFormatter,
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return UiInteractive(
      onTap: onTap,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        padding: EdgeInsets.symmetric(
          horizontal: ctx.sp(theme.spacing.sm),
          vertical: ctx.sp(theme.spacing.xxs),
        ),
        decoration: BoxDecoration(
          color: active
              ? theme.colors.primary.withValues(alpha: 0.15)
              : (s.hovered ? theme.colors.surfaceMuted : theme.colors.surface),
          borderRadius: ctx.radius(theme.radii.sm),
          border: Border.all(
            color: active ? theme.colors.primary : theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: ctx.sp(12),
              color: active
                  ? theme.colors.primary
                  : theme.colors.foregroundSubtle,
            ),
            SizedBox(width: ctx.sp(theme.spacing.xxs)),
            Text(
              label,
              style: ctx.uiText.caption.copyWith(
                color: active
                    ? theme.colors.primary
                    : theme.colors.foregroundMuted,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                fontSize: ctx.sp(11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
