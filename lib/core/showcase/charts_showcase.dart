import 'package:flutter/material.dart';

import '../flutter-ui/flutter_ui.dart';
import 'state_gallery.dart';

/// Batch — charts, market visualizations and data-dense components.
/// Every gallery renders the component across its full state matrix
/// (intents, sizes, density, gradients/glow, thresholds, stacked/grouped
/// series, legends, tooltips and loading/empty/error/partial/full data).
const int kChartsGalleryCount = 17;

class ChartsShowcaseSection extends StatefulWidget {
  const ChartsShowcaseSection({super.key, required this.startIndex});

  final int startIndex;

  @override
  State<ChartsShowcaseSection> createState() => _ChartsShowcaseSectionState();
}

class _ChartsShowcaseSectionState extends State<ChartsShowcaseSection> {
  String? _selectedNode = 'aapl';

  @override
  Widget build(BuildContext context) {
    final double gap = context.sp(context.ui.spacing.lg);
    final int i = widget.startIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiShowcaseSection(
          title: 'Charts',
          subtitle:
              'Trading visualizations — line/area/bar/combo charts, sparks, '
              'donuts, candles, graphs, trackers and progress indicators, '
              'each across gradient, threshold, stacked and data-state '
              'combinations.',
        ),
        SizedBox(height: gap),
        _AreaChartGallery(index: i),
        SizedBox(height: gap),
        _LineChartGallery(index: i + 1),
        SizedBox(height: gap),
        _BarChartGallery(index: i + 2),
        SizedBox(height: gap),
        _ComboChartGallery(index: i + 3),
        SizedBox(height: gap),
        _SparkChartGallery(index: i + 4),
        SizedBox(height: gap),
        _DonutChartGallery(index: i + 5),
        SizedBox(height: gap),
        _CandleChartGallery(index: i + 6),
        SizedBox(height: gap),
        _GraphCanvasGallery(
          index: i + 7,
          selected: _selectedNode,
          onSelect: (String? id) => setState(() => _selectedNode = id),
        ),
        SizedBox(height: gap),
        _TrackerGallery(index: i + 8),
        SizedBox(height: gap),
        _CategoryBarGallery(index: i + 9),
        SizedBox(height: gap),
        _BarListGallery(index: i + 10),
        SizedBox(height: gap),
        _ProgressBarGallery(index: i + 11),
        SizedBox(height: gap),
        _ProgressCircleGallery(index: i + 12),
        SizedBox(height: gap),
        _MetricCardGallery(index: i + 13),
        SizedBox(height: gap),
        _TableGallery(index: i + 14),
        SizedBox(height: gap),
        _MarqueeGallery(index: i + 15),
        SizedBox(height: gap),
        _SkeletonGallery(index: i + 16),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiAreaChart
// ---------------------------------------------------------------------------

class _AreaChartGallery extends StatelessWidget {
  const _AreaChartGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiAreaChart',
      description:
          'Filled area series with gradient glow, stacking, thresholds and '
          'legend toggling.',
      tags: const <String>['chart', 'trend', 'responsive'],
      minCaseWidth: 420,
      codeSnippet:
          "UiAreaChart(\n  data: equityCurve,\n  series: [UiChartSeries(name: 'Equity')],\n"
          "  glow: true,\n  thresholds: [UiChartThreshold(value: 10000, label: 'Target')],\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'single series',
          fill: true,
          builder: (BuildContext _) => UiAreaChart(
            data: _equityCurve,
            series: const <UiChartSeries>[
              UiChartSeries(name: 'Equity', type: UiChartSeriesType.area),
            ],
          ),
        ),
        UiStateCase(
          'glow + thresholds',
          fill: true,
          builder: (BuildContext _) => UiAreaChart(
            data: _equityCurve,
            series: const <UiChartSeries>[
              UiChartSeries(name: 'Equity', type: UiChartSeriesType.area),
            ],
            glow: true,
            thresholds: const <UiChartThreshold>[
              UiChartThreshold(value: 10800, label: 'Target'),
              UiChartThreshold(value: 9800, label: 'Stop', dashed: true),
            ],
          ),
        ),
        UiStateCase(
          'stacked, two series',
          fill: true,
          builder: (BuildContext _) => UiAreaChart(
            data: _multiSeries,
            series: const <UiChartSeries>[
              UiChartSeries(name: 'Longs', type: UiChartSeriesType.area),
              UiChartSeries(name: 'Shorts', type: UiChartSeriesType.area),
            ],
            stacked: true,
          ),
        ),
        UiStateCase(
          'no grid / axis / legend',
          builder: (BuildContext _) => UiAreaChart(
            data: _equityCurve,
            series: const <UiChartSeries>[UiChartSeries(name: 'Equity')],
            showGrid: false,
            showAxisLabels: false,
            showLegend: false,
            height: 120,
          ),
        ),
        UiStateCase(
          'straight lines (curved: false)',
          builder: (BuildContext _) => UiAreaChart(
            data: _equityCurve,
            series: const <UiChartSeries>[UiChartSeries(name: 'Equity')],
            curved: false,
            height: 140,
          ),
        ),
        UiStateCase(
          'custom value formatter',
          builder: (BuildContext _) => UiAreaChart(
            data: _equityCurve,
            series: const <UiChartSeries>[UiChartSeries(name: 'Equity')],
            valueFormatter: (num v) => '\$${v.toStringAsFixed(0)}',
            height: 140,
          ),
        ),
        UiStateCase(
          'not interactive, no legend toggle',
          builder: (BuildContext _) => UiAreaChart(
            data: _equityCurve,
            series: const <UiChartSeries>[UiChartSeries(name: 'Equity')],
            interactive: false,
            toggleableLegend: false,
            height: 140,
          ),
        ),
        UiStateCase(
          'empty data',
          builder: (BuildContext _) => const UiAreaChart(
            data: <UiChartPoint>[],
            series: <UiChartSeries>[UiChartSeries(name: 'Equity')],
            height: 140,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiLineChart
// ---------------------------------------------------------------------------

class _LineChartGallery extends StatelessWidget {
  const _LineChartGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiLineChart',
      description:
          'Multi-series line chart with crosshair tooltip, glow strokes and '
          'threshold overlays.',
      tags: const <String>['chart', 'price', 'crosshair'],
      minCaseWidth: 420,
      codeSnippet:
          "UiLineChart(\n  data: priceSeries,\n  series: [UiChartSeries(name: 'AAPL'), UiChartSeries(name: 'SPY')],\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'multi-series with legend',
          fill: true,
          builder: (BuildContext _) => UiLineChart(
            data: _multiSeries,
            series: const <UiChartSeries>[
              UiChartSeries(name: 'AAPL'),
              UiChartSeries(name: 'MSFT'),
            ],
          ),
        ),
        UiStateCase(
          'glow + thresholds',
          fill: true,
          builder: (BuildContext _) => UiLineChart(
            data: _equityCurve,
            series: const <UiChartSeries>[UiChartSeries(name: 'PnL')],
            glow: true,
            thresholds: const <UiChartThreshold>[
              UiChartThreshold(value: 10500, label: 'Alert', dashed: true),
            ],
          ),
        ),
        UiStateCase(
          'stacked line series',
          builder: (BuildContext _) => UiLineChart(
            data: _multiSeries,
            series: const <UiChartSeries>[
              UiChartSeries(name: 'Longs'),
              UiChartSeries(name: 'Shorts'),
            ],
            stacked: true,
            height: 140,
          ),
        ),
        UiStateCase(
          'straight (uncurved)',
          builder: (BuildContext _) => UiLineChart(
            data: _equityCurve,
            series: const <UiChartSeries>[UiChartSeries(name: 'Equity')],
            curved: false,
            height: 140,
          ),
        ),
        UiStateCase(
          'minimal, no interaction',
          builder: (BuildContext _) => UiLineChart(
            data: _equityCurve,
            series: const <UiChartSeries>[UiChartSeries(name: 'Equity')],
            showGrid: false,
            showAxisLabels: false,
            showLegend: false,
            interactive: false,
            height: 100,
          ),
        ),
        UiStateCase(
          'single data point',
          builder: (BuildContext _) => UiLineChart(
            data: <UiChartPoint>[_equityCurve.first],
            series: const <UiChartSeries>[UiChartSeries(name: 'Equity')],
            height: 120,
          ),
        ),
        UiStateCase(
          'empty data',
          builder: (BuildContext _) => const UiLineChart(
            data: <UiChartPoint>[],
            series: <UiChartSeries>[UiChartSeries(name: 'Equity')],
            height: 120,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiBarChart
// ---------------------------------------------------------------------------

class _BarChartGallery extends StatelessWidget {
  const _BarChartGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiBarChart',
      description:
          'Grouped and stacked bar series with thresholds — monthly PnL and '
          'volume style visualizations.',
      tags: const <String>['chart', 'volume', 'pnl'],
      minCaseWidth: 420,
      codeSnippet:
          "UiBarChart(\n  data: monthlyPnl,\n  series: [UiChartSeries(name: 'PnL')],\n  stacked: false,\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'single series',
          fill: true,
          builder: (BuildContext _) => UiBarChart(
            data: _monthlyPnl,
            series: const <UiChartSeries>[UiChartSeries(name: 'PnL')],
          ),
        ),
        UiStateCase(
          'grouped, two series',
          fill: true,
          builder: (BuildContext _) => UiBarChart(
            data: _multiSeries,
            series: const <UiChartSeries>[
              UiChartSeries(name: 'Wins'),
              UiChartSeries(name: 'Losses'),
            ],
          ),
        ),
        UiStateCase(
          'stacked, two series',
          fill: true,
          builder: (BuildContext _) => UiBarChart(
            data: _multiSeries,
            series: const <UiChartSeries>[
              UiChartSeries(name: 'Wins'),
              UiChartSeries(name: 'Losses'),
            ],
            stacked: true,
          ),
        ),
        UiStateCase(
          'with threshold line',
          builder: (BuildContext _) => UiBarChart(
            data: _monthlyPnl,
            series: const <UiChartSeries>[UiChartSeries(name: 'PnL')],
            thresholds: const <UiChartThreshold>[
              UiChartThreshold(value: 0, label: 'Breakeven', dashed: false),
            ],
            height: 140,
          ),
        ),
        UiStateCase(
          'glow bars',
          builder: (BuildContext _) => UiBarChart(
            data: _monthlyPnl,
            series: const <UiChartSeries>[UiChartSeries(name: 'PnL')],
            glow: true,
            height: 140,
          ),
        ),
        UiStateCase(
          'minimal',
          builder: (BuildContext _) => UiBarChart(
            data: _monthlyPnl,
            series: const <UiChartSeries>[UiChartSeries(name: 'PnL')],
            showGrid: false,
            showAxisLabels: false,
            showLegend: false,
            height: 100,
          ),
        ),
        UiStateCase(
          'empty data',
          builder: (BuildContext _) => const UiBarChart(
            data: <UiChartPoint>[],
            series: <UiChartSeries>[UiChartSeries(name: 'PnL')],
            height: 120,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiComboChart
// ---------------------------------------------------------------------------

class _ComboChartGallery extends StatelessWidget {
  const _ComboChartGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiComboChart',
      description:
          'Mixed bar + line series on one plot — price bars with an overlaid '
          'moving-average style line.',
      tags: const <String>['chart', 'mixed'],
      minCaseWidth: 420,
      codeSnippet:
          "UiComboChart(\n  data: volumeAndPrice,\n  series: [\n    UiChartSeries(name: 'Volume', type: UiChartSeriesType.bar),\n"
          "    UiChartSeries(name: 'Price', type: UiChartSeriesType.line, axis: UiChartAxis.right),\n  ],\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'bar + line, dual axis',
          fill: true,
          builder: (BuildContext _) => UiComboChart(
            data: _volumePrice,
            series: const <UiChartSeries>[
              UiChartSeries(name: 'Volume', type: UiChartSeriesType.bar),
              UiChartSeries(
                name: 'Price',
                type: UiChartSeriesType.line,
                axis: UiChartAxis.right,
              ),
            ],
          ),
        ),
        UiStateCase(
          'bar + area, glow',
          fill: true,
          builder: (BuildContext _) => UiComboChart(
            data: _volumePrice,
            series: const <UiChartSeries>[
              UiChartSeries(name: 'Volume', type: UiChartSeriesType.bar),
              UiChartSeries(name: 'Trend', type: UiChartSeriesType.area),
            ],
            glow: true,
          ),
        ),
        UiStateCase(
          'stacked bars + line',
          builder: (BuildContext _) => UiComboChart(
            data: _multiSeries,
            series: const <UiChartSeries>[
              UiChartSeries(name: 'Longs', type: UiChartSeriesType.bar),
              UiChartSeries(name: 'Shorts', type: UiChartSeriesType.bar),
            ],
            stacked: true,
            height: 140,
          ),
        ),
        UiStateCase(
          'with threshold',
          builder: (BuildContext _) => UiComboChart(
            data: _volumePrice,
            series: const <UiChartSeries>[
              UiChartSeries(name: 'Volume', type: UiChartSeriesType.bar),
              UiChartSeries(name: 'Price', type: UiChartSeriesType.line),
            ],
            thresholds: const <UiChartThreshold>[
              UiChartThreshold(value: 200, label: 'Avg vol'),
            ],
            height: 140,
          ),
        ),
        UiStateCase(
          'empty data',
          builder: (BuildContext _) => const UiComboChart(
            data: <UiChartPoint>[],
            series: <UiChartSeries>[
              UiChartSeries(name: 'Volume', type: UiChartSeriesType.bar),
            ],
            height: 120,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiSparkChart
// ---------------------------------------------------------------------------

class _SparkChartGallery extends StatelessWidget {
  const _SparkChartGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiStateGallery(
      index: index,
      name: 'UiSparkChart',
      description:
          'Compact inline sparkline — no axes/grid/legend. Used in tables, '
          'metric cards and list rows.',
      tags: const <String>['chart', 'inline', 'compact'],
      minCaseWidth: 220,
      codeSnippet:
          "UiSparkChart(values: [1,3,2,5,4,7], filled: true, color: theme.colors.bullish)",
      cases: <UiStateCase>[
        UiStateCase(
          'line',
          builder: (BuildContext _) => UiSparkChart(values: _sparkValues),
        ),
        UiStateCase(
          'filled (area)',
          builder: (BuildContext _) =>
              UiSparkChart(values: _sparkValues, filled: true),
        ),
        UiStateCase(
          'bullish tint',
          builder: (BuildContext _) => UiSparkChart(
            values: _sparkValues,
            filled: true,
            color: theme.colors.bullish,
          ),
        ),
        UiStateCase(
          'bearish tint',
          builder: (BuildContext _) => UiSparkChart(
            values: _sparkValuesDown,
            filled: true,
            color: theme.colors.bearish,
          ),
        ),
        UiStateCase(
          'straight (uncurved)',
          builder: (BuildContext _) =>
              UiSparkChart(values: _sparkValues, curved: false),
        ),
        UiStateCase(
          'tall variant',
          builder: (BuildContext _) =>
              UiSparkChart(values: _sparkValues, height: 60),
        ),
        UiStateCase(
          'with labels',
          builder: (BuildContext _) => UiSparkChart(
            values: _sparkValues,
            labels: const <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'],
          ),
        ),
        UiStateCase(
          'single value',
          builder: (BuildContext _) => const UiSparkChart(values: <double>[5]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiDonutChart
// ---------------------------------------------------------------------------

class _DonutChartGallery extends StatelessWidget {
  const _DonutChartGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiStateGallery(
      index: index,
      name: 'UiDonutChart',
      description:
          'Allocation / sentiment donut with center content and responsive '
          'legend placement.',
      tags: const <String>['chart', 'allocation'],
      minCaseWidth: 320,
      codeSnippet:
          "UiDonutChart(\n  slices: allocation,\n  center: Text('\$42K'),\n  valueFormatter: (v) => '\${v.toStringAsFixed(0)}%',\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'default with legend',
          span: 2,
          builder: (BuildContext _) => UiDonutChart(slices: _allocation),
        ),
        UiStateCase(
          'with center content',
          span: 2,
          builder: (BuildContext _) => UiDonutChart(
            slices: _allocation,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('\$42.3K', style: context.uiText.bodyStrong),
                Text('Portfolio', style: context.uiText.caption),
              ],
            ),
          ),
        ),
        UiStateCase(
          'no legend',
          builder: (BuildContext _) => UiDonutChart(
            slices: _allocation,
            showLegend: false,
          ),
        ),
        UiStateCase(
          'thin ring, large',
          builder: (BuildContext _) => UiDonutChart(
            slices: _allocation,
            size: 220,
            thickness: 10,
            showLegend: false,
          ),
        ),
        UiStateCase(
          'thick ring, small',
          builder: (BuildContext _) => UiDonutChart(
            slices: _allocation,
            size: 120,
            thickness: 34,
            showLegend: false,
          ),
        ),
        UiStateCase(
          'custom colors',
          builder: (BuildContext _) => UiDonutChart(
            slices: <UiDonutSlice>[
              UiDonutSlice(
                  label: 'Wins', value: 68, color: theme.colors.bullish),
              UiDonutSlice(
                  label: 'Losses', value: 32, color: theme.colors.bearish),
            ],
          ),
        ),
        UiStateCase(
          'single slice',
          builder: (BuildContext _) => const UiDonutChart(
            slices: <UiDonutSlice>[UiDonutSlice(label: 'Cash', value: 100)],
          ),
        ),
        UiStateCase(
          'empty (all zero)',
          builder: (BuildContext _) => const UiDonutChart(
            slices: <UiDonutSlice>[],
            showLegend: false,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiCandleChart
// ---------------------------------------------------------------------------

class _CandleChartGallery extends StatelessWidget {
  const _CandleChartGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiCandleChart',
      description:
          'OHLCV price chart with volume pane, moving-average overlays, '
          'price lines and trade markers.',
      tags: const <String>['chart', 'price', 'ohlc'],
      minCaseWidth: 460,
      codeSnippet:
          "UiCandleChart(\n  candles: candles,\n  overlays: [UiCandleOverlay.sma(candles, 20)],\n  priceLines: [UiPriceLine(price: 231, label: 'Entry')],\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'candles + volume',
          fill: true,
          builder: (BuildContext _) => UiCandleChart(candles: _candles),
        ),
        UiStateCase(
          'with MA overlays + price lines + markers',
          fill: true,
          builder: (BuildContext _) => UiCandleChart(
            candles: _candles,
            overlays: <UiCandleOverlay>[
              UiCandleOverlay.sma(_candles, 8),
              UiCandleOverlay.sma(_candles, 20),
            ],
            priceLines: const <UiPriceLine>[
              UiPriceLine(price: 231, label: 'Entry', intent: UiIntent.primary),
              UiPriceLine(
                  price: 219, label: 'Stop', intent: UiIntent.bearish),
            ],
            markers: const <UiCandleMarker>[
              UiCandleMarker(index: 6, label: 'Buy', intent: UiIntent.bullish),
              UiCandleMarker(
                  index: 18,
                  label: 'Sell',
                  intent: UiIntent.bearish,
                  above: false),
            ],
          ),
        ),
        UiStateCase(
          'hollow candles',
          fill: true,
          builder: (BuildContext _) => UiCandleChart(
            candles: _candles,
            type: UiPriceChartType.hollow,
          ),
        ),
        UiStateCase(
          'line price type',
          builder: (BuildContext _) => UiCandleChart(
            candles: _candles,
            type: UiPriceChartType.line,
            showVolume: false,
            height: 160,
          ),
        ),
        UiStateCase(
          'area price type',
          builder: (BuildContext _) => UiCandleChart(
            candles: _candles,
            type: UiPriceChartType.area,
            showVolume: false,
            height: 160,
          ),
        ),
        UiStateCase(
          'no volume / no grid / not interactive',
          builder: (BuildContext _) => UiCandleChart(
            candles: _candles,
            showVolume: false,
            showGrid: false,
            interactive: false,
            height: 160,
          ),
        ),
        UiStateCase(
          'custom price formatter',
          builder: (BuildContext _) => UiCandleChart(
            candles: _candles,
            priceFormatter: (num v) => '\$${v.toStringAsFixed(2)}',
            height: 160,
          ),
        ),
        UiStateCase(
          'empty data',
          builder: (BuildContext _) =>
              const UiCandleChart(candles: <UiCandle>[], height: 140),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiGraphCanvas
// ---------------------------------------------------------------------------

class _GraphCanvasGallery extends StatelessWidget {
  const _GraphCanvasGallery({
    required this.index,
    required this.selected,
    required this.onSelect,
  });

  final int index;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiGraphCanvas',
      description:
          'Pannable / zoomable node-link canvas with a deterministic '
          'force-directed layout — trade journal relationships, strategy '
          'graphs.',
      tags: const <String>['chart', 'graph', 'interactive'],
      minCaseWidth: 420,
      codeSnippet:
          "UiGraphCanvas(\n  nodes: strategyNodes,\n  edges: strategyEdges,\n  selectedId: selected,\n  onSelect: (n) => setState(() => selected = n?.id),\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'interactive with selection',
          fill: true,
          builder: (BuildContext _) => UiGraphCanvas(
            nodes: _graphNodes,
            edges: _graphEdges,
            selectedId: selected,
            onSelect: (UiGraphNode? n) => onSelect(n?.id),
          ),
        ),
        UiStateCase(
          'legend',
          builder: (BuildContext _) => const UiGraphLegend(
            entries: <String, UiIntent>{
              'Strategy': UiIntent.primary,
              'Win': UiIntent.bullish,
              'Loss': UiIntent.bearish,
            },
          ),
        ),
        UiStateCase(
          'fast layout (fewer iterations)',
          builder: (BuildContext _) => UiGraphCanvas(
            nodes: _graphNodes,
            edges: _graphEdges,
            iterations: 40,
            height: 220,
          ),
        ),
        UiStateCase(
          'no edges',
          builder: (BuildContext _) => UiGraphCanvas(
            nodes: _graphNodes,
            edges: const <UiGraphEdge>[],
            height: 220,
          ),
        ),
        UiStateCase(
          'empty graph',
          builder: (BuildContext _) => const UiGraphCanvas(
            nodes: <UiGraphNode>[],
            edges: <UiGraphEdge>[],
            height: 160,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiTracker
// ---------------------------------------------------------------------------

class _TrackerGallery extends StatelessWidget {
  const _TrackerGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiStateGallery(
      background: theme.colors.surfaceMuted,
      index: index,
      name: 'UiTracker',
      description:
          'Uptime / streak tracker — daily trading streak or signal '
          'accuracy history.',
      tags: const <String>['chart', 'streak'],
      minCaseWidth: 320,
      codeSnippet:
          "UiTracker(blocks: [for (final d in days) UiTrackerBlock(intent: d.win ? UiIntent.bullish : UiIntent.bearish, tooltip: d.date)])",
      cases: <UiStateCase>[
        UiStateCase(
          'win/loss streak',
          fill: true,
          builder: (BuildContext _) => UiTracker(blocks: _trackerBlocks),
        ),
        UiStateCase(
          'tall variant',
          fill: true,
          builder: (BuildContext _) =>
              UiTracker(blocks: _trackerBlocks, height: 44),
        ),
        UiStateCase(
          'mixed intents',
          fill: true,
          builder: (BuildContext _) => UiTracker(
            blocks: <UiTrackerBlock>[
              const UiTrackerBlock(intent: UiIntent.bullish, tooltip: 'Win'),
              const UiTrackerBlock(intent: UiIntent.bearish, tooltip: 'Loss'),
              const UiTrackerBlock(intent: UiIntent.neutral, tooltip: 'Flat'),
              const UiTrackerBlock(intent: UiIntent.warning, tooltip: 'Late'),
              const UiTrackerBlock(intent: UiIntent.bullish, tooltip: 'Win'),
            ],
          ),
        ),
        UiStateCase(
          'empty',
          builder: (BuildContext _) =>
              const UiTracker(blocks: <UiTrackerBlock>[]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiCategoryBar
// ---------------------------------------------------------------------------

class _CategoryBarGallery extends StatelessWidget {
  const _CategoryBarGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiCategoryBar',
      description:
          'Stacked proportional bar for portfolio allocation or sentiment '
          'split, with an optional position marker.',
      tags: const <String>['chart', 'allocation'],
      minCaseWidth: 320,
      codeSnippet:
          "UiCategoryBar(segments: allocation, marker: 0.62)",
      cases: <UiStateCase>[
        UiStateCase(
          'with legend',
          span: 2,
          builder: (BuildContext _) => UiCategoryBar(segments: _segments),
        ),
        UiStateCase(
          'with marker',
          span: 2,
          builder: (BuildContext _) =>
              UiCategoryBar(segments: _segments, marker: 0.62),
        ),
        UiStateCase(
          'no legend',
          builder: (BuildContext _) =>
              UiCategoryBar(segments: _segments, showLegend: false),
        ),
        UiStateCase(
          'thin track',
          builder: (BuildContext _) => UiCategoryBar(
            segments: _segments,
            showLegend: false,
            thickness: 4,
          ),
        ),
        UiStateCase(
          'thick track',
          builder: (BuildContext _) => UiCategoryBar(
            segments: _segments,
            showLegend: false,
            thickness: 20,
          ),
        ),
        UiStateCase(
          'single segment',
          builder: (BuildContext _) => const UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(value: 100, label: 'Cash'),
            ],
          ),
        ),
        UiStateCase(
          'empty',
          builder: (BuildContext _) => const UiCategoryBar(
            segments: <UiCategorySegment>[],
            showLegend: false,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiBarList
// ---------------------------------------------------------------------------

class _BarListGallery extends StatelessWidget {
  const _BarListGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiBarList',
      description:
          'Horizontal ranked bars — top gainers, most-discussed tickers.',
      tags: const <String>['chart', 'ranked'],
      minCaseWidth: 320,
      codeSnippet:
          "UiBarList(items: topMovers, intent: UiIntent.bullish, valueFormatter: uiSignedPercent)",
      cases: <UiStateCase>[
        UiStateCase(
          'default',
          span: 2,
          builder: (BuildContext _) => UiBarList(items: _topMovers),
        ),
        UiStateCase(
          'bearish intent + custom formatter',
          span: 2,
          builder: (BuildContext _) => UiBarList(
            items: _topLosers,
            intent: UiIntent.bearish,
            valueFormatter: (num v) => uiSignedPercent(v),
          ),
        ),
        UiStateCase(
          'with icons + onTap',
          span: 2,
          builder: (BuildContext _) => UiBarList(
            items: <UiBarListItem>[
              UiBarListItem(
                  label: 'AAPL',
                  value: 4.2,
                  icon: Icons.apple,
                  onTap: () {}),
              UiBarListItem(
                  label: 'TSLA',
                  value: 3.1,
                  icon: Icons.electric_car,
                  onTap: () {}),
              UiBarListItem(
                  label: 'NVDA', value: 2.4, icon: Icons.memory, onTap: () {}),
            ],
          ),
        ),
        UiStateCase(
          'custom colors',
          span: 2,
          builder: (BuildContext _) => UiBarList(
            items: <UiBarListItem>[
              UiBarListItem(
                  label: 'Momentum',
                  value: 88,
                  color: context.uiColors.info),
              UiBarListItem(
                  label: 'Value', value: 52, color: context.uiColors.warning),
            ],
          ),
        ),
        UiStateCase(
          'empty',
          builder: (BuildContext _) => const UiBarList(items: <UiBarListItem>[]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiProgressBar
// ---------------------------------------------------------------------------

class _ProgressBarGallery extends StatelessWidget {
  const _ProgressBarGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiProgressBar',
      description:
          'Linear progress — goal completion, order fill percentage, across '
          'every intent and thickness.',
      tags: const <String>['chart', 'progress'],
      minCaseWidth: 260,
      codeSnippet:
          "UiProgressBar(value: 0.62, label: 'Order fill', intent: UiIntent.bullish)",
      cases: <UiStateCase>[
        for (final UiIntent intent in const <UiIntent>[
          UiIntent.primary,
          UiIntent.bullish,
          UiIntent.bearish,
          UiIntent.warning,
        ])
          UiStateCase(
            'intent · ${intent.name}',
            builder: (BuildContext _) => UiProgressBar(
              value: 0.62,
              label: 'Order fill',
              intent: intent,
            ),
          ),
        UiStateCase(
          'no value label',
          builder: (BuildContext _) =>
              const UiProgressBar(value: 0.4, label: 'Loading', showValue: false),
        ),
        UiStateCase(
          'no label, value only',
          builder: (BuildContext _) =>
              const UiProgressBar(value: 0.8, showValue: true),
        ),
        UiStateCase(
          'thin track',
          builder: (BuildContext _) =>
              const UiProgressBar(value: 0.5, thickness: 3),
        ),
        UiStateCase(
          'thick track',
          builder: (BuildContext _) =>
              const UiProgressBar(value: 0.5, thickness: 16),
        ),
        UiStateCase(
          'custom formatter',
          builder: (BuildContext _) => UiProgressBar(
            value: 0.735,
            label: 'Margin used',
            valueFormatter: (num v) => '\$${(v * 100).toStringAsFixed(0)}',
          ),
        ),
        UiStateCase(
          'complete (100%)',
          builder: (BuildContext _) =>
              const UiProgressBar(value: 1, label: 'Target', intent: UiIntent.bullish),
        ),
        UiStateCase(
          'empty (0%)',
          builder: (BuildContext _) =>
              const UiProgressBar(value: 0, label: 'Not started'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiProgressCircle
// ---------------------------------------------------------------------------

class _ProgressCircleGallery extends StatelessWidget {
  const _ProgressCircleGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiProgressCircle',
      description:
          'Circular progress ring with centered content — win rate, quota '
          'progress.',
      tags: const <String>['chart', 'progress', 'ring'],
      minCaseWidth: 200,
      codeSnippet:
          "UiProgressCircle(value: 0.68, intent: UiIntent.bullish, center: Text('68%'))",
      cases: <UiStateCase>[
        for (final UiIntent intent in const <UiIntent>[
          UiIntent.primary,
          UiIntent.bullish,
          UiIntent.bearish,
        ])
          UiStateCase(
            'intent · ${intent.name}',
            builder: (BuildContext _) =>
                UiProgressCircle(value: 0.68, intent: intent),
          ),
        UiStateCase(
          'custom center content',
          builder: (BuildContext _) => UiProgressCircle(
            value: 0.42,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.flag, size: context.sz(16)),
                Text('42%', style: context.uiText.caption),
              ],
            ),
          ),
        ),
        UiStateCase(
          'small',
          builder: (BuildContext _) =>
              const UiProgressCircle(value: 0.5, size: 56, thickness: 6),
        ),
        UiStateCase(
          'large',
          builder: (BuildContext _) =>
              const UiProgressCircle(value: 0.5, size: 140, thickness: 14),
        ),
        UiStateCase(
          'complete (100%)',
          builder: (BuildContext _) =>
              const UiProgressCircle(value: 1, intent: UiIntent.bullish),
        ),
        UiStateCase(
          'empty (0%)',
          builder: (BuildContext _) => const UiProgressCircle(value: 0),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiMetricCard
// ---------------------------------------------------------------------------

class _MetricCardGallery extends StatelessWidget {
  const _MetricCardGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiMetricCard',
      description:
          'KPI tile with delta and an optional embedded sparkline — used for '
          'portfolio stats.',
      tags: const <String>['chart', 'kpi', 'card'],
      minCaseWidth: 260,
      codeSnippet:
          "UiMetricCard(\n  label: 'Total Equity',\n  value: '\$128,420',\n  delta: 3.2,\n  chart: UiSparkChart(values: equity, filled: true),\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'positive delta + spark',
          builder: (BuildContext _) => UiMetricCard(
            label: 'Total Equity',
            value: '\$128,420',
            delta: 3.2,
            icon: Icons.account_balance_wallet,
            chart: UiSparkChart(
              values: _sparkValues,
              filled: true,
              color: context.uiColors.bullish,
            ),
          ),
        ),
        UiStateCase(
          'negative delta + spark',
          builder: (BuildContext _) => UiMetricCard(
            label: 'Open Drawdown',
            value: '-\$2,140',
            delta: -1.8,
            icon: Icons.trending_down,
            chart: UiSparkChart(
              values: _sparkValuesDown,
              filled: true,
              color: context.uiColors.bearish,
            ),
          ),
        ),
        UiStateCase(
          'no chart',
          builder: (BuildContext _) => const UiMetricCard(
            label: 'Win Rate',
            value: '64%',
            delta: 0.5,
            icon: Icons.percent,
          ),
        ),
        UiStateCase(
          'no delta, no icon',
          builder: (BuildContext _) => const UiMetricCard(
            label: 'Open Positions',
            value: '7',
          ),
        ),
        UiStateCase(
          'tappable',
          builder: (BuildContext _) => UiMetricCard(
            label: 'Buying Power',
            value: '\$41,200',
            delta: 0,
            onTap: () {},
          ),
        ),
        UiStateCase(
          'long label truncation',
          builder: (BuildContext _) => const UiMetricCard(
            label: 'Average Risk-Adjusted Return This Quarter',
            value: '1.84 Sharpe',
            delta: 2.1,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiTable
// ---------------------------------------------------------------------------

class _TableGallery extends StatelessWidget {
  const _TableGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiTable',
      description:
          'Responsive data table: sorting, pagination, selection, expandable '
          'rows, sticky header, loading/error/empty states and density.',
      tags: const <String>['table', 'data', 'responsive'],
      minCaseWidth: 480,
      codeSnippet:
          "UiTable<Position>(\n  columns: columns,\n  rows: positions,\n  selectable: true,\n  stickyHeader: true,\n  maxBodyHeight: 240,\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'default, sortable',
          fill: true,
          builder: (BuildContext _) => UiTable<_Position>(
            columns: _positionColumns,
            rows: _positions,
          ),
        ),
        UiStateCase(
          'selectable + footer',
          fill: true,
          builder: (BuildContext _) => UiTable<_Position>(
            columns: _positionColumns,
            rows: _positions,
            selectable: true,
            footer: Text(
              '${_positions.length} positions',
              style: context.uiText.caption,
            ),
          ),
        ),
        UiStateCase(
          'sticky header + max body height',
          fill: true,
          builder: (BuildContext _) => UiTable<_Position>(
            columns: _positionColumns,
            rows: _positions,
            stickyHeader: true,
            maxBodyHeight: 180,
          ),
        ),
        UiStateCase(
          'expandable rows',
          fill: true,
          builder: (BuildContext _) => UiTable<_Position>(
            columns: _positionColumns,
            rows: _positions,
            expandableWhen: (_Position p) => p.pnlPct.abs() > 1,
            expandedBuilder: (BuildContext ctx, _Position p) => Text(
              'Opened via ${p.symbol} momentum breakout strategy.',
              style: ctx.uiText.caption,
            ),
          ),
        ),
        UiStateCase(
          'paginated',
          fill: true,
          builder: (BuildContext _) => UiTable<_Position>(
            columns: _positionColumns,
            rows: _positions,
            pageSize: 2,
          ),
        ),
        UiStateCase(
          'compact density',
          fill: true,
          builder: (BuildContext _) => UiTable<_Position>(
            columns: _positionColumns,
            rows: _positions,
            density: UiDensity.compact,
          ),
        ),
        UiStateCase(
          'spacious density',
          fill: true,
          builder: (BuildContext _) => UiTable<_Position>(
            columns: _positionColumns,
            rows: _positions,
            density: UiDensity.spacious,
          ),
        ),
        UiStateCase(
          'stack on mobile',
          fill: true,
          builder: (BuildContext _) => UiTable<_Position>(
            columns: _positionColumns,
            rows: _positions,
            stackOnMobile: true,
          ),
        ),
        UiStateCase(
          'loading',
          fill: true,
          builder: (BuildContext _) => UiTable<_Position>(
            columns: _positionColumns,
            rows: const <_Position>[],
            loading: true,
          ),
        ),
        UiStateCase(
          'error',
          fill: true,
          builder: (BuildContext _) => UiTable<_Position>(
            columns: _positionColumns,
            rows: const <_Position>[],
            errorText: 'Failed to load positions. Pull to retry.',
          ),
        ),
        UiStateCase(
          'empty',
          fill: true,
          builder: (BuildContext _) => UiTable<_Position>(
            columns: _positionColumns,
            rows: const <_Position>[],
            emptyLabel: 'No open positions',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiMarquee
// ---------------------------------------------------------------------------

class _MarqueeGallery extends StatelessWidget {
  const _MarqueeGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiMarquee',
      description:
          'Continuously scrolling ticker tape for market movers.',
      tags: const <String>['chart', 'ticker'],
      minCaseWidth: 420,
      codeSnippet:
          "UiMarquee(speed: 40, children: [for (final t in tickers) UiBadge(label: t)])",
      cases: <UiStateCase>[
        UiStateCase(
          'default speed',
          fill: true,
          builder: (BuildContext _) => UiMarquee(children: _tickerChips(context)),
        ),
        UiStateCase(
          'fast',
          fill: true,
          builder: (BuildContext _) =>
              UiMarquee(speed: 120, children: _tickerChips(context)),
        ),
        UiStateCase(
          'paused',
          fill: true,
          builder: (BuildContext _) =>
              UiMarquee(paused: true, children: _tickerChips(context)),
        ),
        UiStateCase(
          'wide spacing',
          fill: true,
          builder: (BuildContext _) =>
              UiMarquee(spacing: 48, children: _tickerChips(context)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UiSkeleton
// ---------------------------------------------------------------------------

class _SkeletonGallery extends StatelessWidget {
  const _SkeletonGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiSkeleton',
      description:
          'Shimmer-free loading placeholder used across cards, tables and '
          'charts while data is in flight.',
      tags: const <String>['loading', 'placeholder'],
      minCaseWidth: 220,
      codeSnippet: "UiSkeleton(width: 120, height: 14)",
      cases: <UiStateCase>[
        UiStateCase(
          'text line',
          builder: (BuildContext _) =>
              const UiSkeleton(width: 140, height: 14),
        ),
        UiStateCase(
          'wide block',
          builder: (BuildContext _) =>
              const UiSkeleton(width: double.infinity, height: 14),
        ),
        UiStateCase(
          'circle avatar',
          builder: (BuildContext _) =>
              const UiSkeleton(width: 40, height: 40, circle: true),
        ),
        UiStateCase(
          'tall card placeholder',
          builder: (BuildContext _) =>
              const UiSkeleton(width: double.infinity, height: 96),
        ),
        UiStateCase(
          'metric card skeleton composition',
          span: 2,
          builder: (BuildContext _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const UiSkeleton(width: 20, height: 20, circle: true),
                  SizedBox(width: context.sp(context.ui.spacing.xs)),
                  const UiSkeleton(width: 90, height: 12),
                ],
              ),
              SizedBox(height: context.sp(context.ui.spacing.sm)),
              const UiSkeleton(width: 130, height: 22),
              SizedBox(height: context.sp(context.ui.spacing.sm)),
              const UiSkeleton(width: double.infinity, height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sample trading data
// ---------------------------------------------------------------------------

final List<UiChartPoint> _equityCurve = <UiChartPoint>[
  for (int i = 0; i < 24; i++)
    UiChartPoint(
      label: 'W$i',
      values: <double>[
        10000 + (i * 45) + (i % 5 == 0 ? -180 : 0) + (i % 3) * 60,
      ],
    ),
];

final List<UiChartPoint> _multiSeries = <UiChartPoint>[
  for (int i = 0; i < 12; i++)
    UiChartPoint(
      label: 'M$i',
      values: <double>[
        20 + (i % 4) * 6 + i * 0.8,
        14 + (i % 3) * 5,
      ],
    ),
];

final List<UiChartPoint> _monthlyPnl = <UiChartPoint>[
  const UiChartPoint(label: 'Jan', values: <double>[420]),
  const UiChartPoint(label: 'Feb', values: <double>[-180]),
  const UiChartPoint(label: 'Mar', values: <double>[860]),
  const UiChartPoint(label: 'Apr', values: <double>[-95]),
  const UiChartPoint(label: 'May', values: <double>[1210]),
  const UiChartPoint(label: 'Jun', values: <double>[340]),
  const UiChartPoint(label: 'Jul', values: <double>[-420]),
  const UiChartPoint(label: 'Aug', values: <double>[980]),
];

final List<UiChartPoint> _volumePrice = <UiChartPoint>[
  for (int i = 0; i < 14; i++)
    UiChartPoint(
      label: 'D$i',
      values: <double>[
        150 + (i % 5) * 40.0,
        220 + i * 1.4 + (i % 3) * 2,
      ],
    ),
];

final List<double> _sparkValues = <double>[4, 6, 5, 8, 7, 10, 9, 12, 11, 14];
final List<double> _sparkValuesDown = <double>[
  14,
  12,
  13,
  10,
  9,
  7,
  8,
  5,
  4,
  3,
];

const List<UiDonutSlice> _allocation = <UiDonutSlice>[
  UiDonutSlice(label: 'Equities', value: 52),
  UiDonutSlice(label: 'Options', value: 18),
  UiDonutSlice(label: 'Crypto', value: 12),
  UiDonutSlice(label: 'Cash', value: 18),
];

List<UiCandle> get _candles => <UiCandle>[
      for (int i = 0; i < 24; i++)
        UiCandle(
          time: DateTime(2024, 1, 1).add(Duration(days: i)),
          open: 220 + (i % 5) * 2 - (i % 3),
          high: 224 + (i % 5) * 2,
          low: 216 + (i % 4),
          close: 221 + (i % 6) * 1.6 - (i % 4) * 0.5,
          volume: 800 + (i % 6) * 120,
        ),
    ];

const List<UiGraphNode> _graphNodes = <UiGraphNode>[
  UiGraphNode(id: 'aapl', label: 'AAPL', intent: UiIntent.primary, weight: 2),
  UiGraphNode(id: 'breakout', label: 'Breakout', intent: UiIntent.bullish),
  UiGraphNode(id: 'earnings', label: 'Earnings', intent: UiIntent.warning),
  UiGraphNode(id: 'tsla', label: 'TSLA', intent: UiIntent.primary, weight: 1.5),
  UiGraphNode(id: 'reversal', label: 'Reversal', intent: UiIntent.bearish),
  UiGraphNode(id: 'journal1', label: 'Journal #12', intent: UiIntent.neutral),
];

const List<UiGraphEdge> _graphEdges = <UiGraphEdge>[
  UiGraphEdge(from: 'aapl', to: 'breakout', label: 'setup'),
  UiGraphEdge(from: 'aapl', to: 'earnings'),
  UiGraphEdge(from: 'tsla', to: 'reversal', strength: 1.6),
  UiGraphEdge(from: 'breakout', to: 'journal1'),
  UiGraphEdge(from: 'reversal', to: 'journal1'),
];

List<UiTrackerBlock> get _trackerBlocks => <UiTrackerBlock>[
      for (int i = 0; i < 30; i++)
        UiTrackerBlock(
          intent: i % 7 == 0
              ? UiIntent.neutral
              : (i % 3 == 0 ? UiIntent.bearish : UiIntent.bullish),
          tooltip: 'Day ${i + 1}',
        ),
    ];

const List<UiCategorySegment> _segments = <UiCategorySegment>[
  UiCategorySegment(value: 45, label: 'Bullish'),
  UiCategorySegment(value: 30, label: 'Neutral'),
  UiCategorySegment(value: 25, label: 'Bearish'),
];

const List<UiBarListItem> _topMovers = <UiBarListItem>[
  UiBarListItem(label: 'NVDA', value: 8.4),
  UiBarListItem(label: 'AMD', value: 6.1),
  UiBarListItem(label: 'TSLA', value: 4.9),
  UiBarListItem(label: 'AAPL', value: 2.3),
];

const List<UiBarListItem> _topLosers = <UiBarListItem>[
  UiBarListItem(label: 'PYPL', value: -5.6),
  UiBarListItem(label: 'SNAP', value: -4.2),
  UiBarListItem(label: 'INTC', value: -2.8),
];

class _Position {
  const _Position(this.symbol, this.qty, this.avgPrice, this.lastPrice);

  final String symbol;
  final int qty;
  final double avgPrice;
  final double lastPrice;

  double get pnlPct => (lastPrice - avgPrice) / avgPrice * 100;
}

final List<_Position> _positions = <_Position>[
  const _Position('AAPL', 120, 210.40, 227.10),
  const _Position('TSLA', 40, 265.10, 249.80),
  const _Position('NVDA', 80, 118.20, 131.55),
  const _Position('MSFT', 60, 402.10, 398.90),
  const _Position('AMD', 150, 142.00, 149.60),
];

List<UiTableColumn<_Position>> get _positionColumns => <UiTableColumn<_Position>>[
      UiTableColumn<_Position>(
        header: 'Symbol',
        cell: (BuildContext ctx, _Position p) => Text(
          p.symbol,
          style: ctx.uiText.bodyStrong,
        ),
        compare: (_Position a, _Position b) => a.symbol.compareTo(b.symbol),
      ),
      UiTableColumn<_Position>(
        header: 'Qty',
        numeric: true,
        cell: (BuildContext ctx, _Position p) => Text('${p.qty}'),
        compare: (_Position a, _Position b) => a.qty.compareTo(b.qty),
        hideBelow: UiTableVisibility.tabletUp,
      ),
      UiTableColumn<_Position>(
        header: 'Avg',
        numeric: true,
        cell: (BuildContext ctx, _Position p) =>
            Text(p.avgPrice.toStringAsFixed(2)),
        hideBelow: UiTableVisibility.desktopUp,
      ),
      UiTableColumn<_Position>(
        header: 'Last',
        numeric: true,
        cell: (BuildContext ctx, _Position p) =>
            Text(p.lastPrice.toStringAsFixed(2)),
        compare: (_Position a, _Position b) =>
            a.lastPrice.compareTo(b.lastPrice),
      ),
      UiTableColumn<_Position>(
        header: 'PnL %',
        numeric: true,
        cell: (BuildContext ctx, _Position p) => Text(
          uiSignedPercent(p.pnlPct),
          style: ctx.uiText.numeric.copyWith(
            color: p.pnlPct >= 0
                ? ctx.uiColors.bullish
                : ctx.uiColors.bearish,
          ),
        ),
        compare: (_Position a, _Position b) => a.pnlPct.compareTo(b.pnlPct),
      ),
    ];

List<Widget> _tickerChips(BuildContext context) => <UiBarListItem>[
      const UiBarListItem(label: 'AAPL', value: 1.2),
      const UiBarListItem(label: 'TSLA', value: -0.8),
      const UiBarListItem(label: 'NVDA', value: 3.4),
      const UiBarListItem(label: 'MSFT', value: 0.4),
      const UiBarListItem(label: 'AMD', value: -1.6),
    ]
        .map(
          (UiBarListItem t) => UiBadge(
            label: '${t.label} ${uiSignedPercent(t.value)}',
            variant: UiBadgeVariant.soft,
            intent: t.value >= 0 ? UiIntent.bullish : UiIntent.bearish,
          ),
        )
        .toList();
