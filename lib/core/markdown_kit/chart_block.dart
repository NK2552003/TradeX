import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Renders a fenced ` ```chart ` (or ` ```pie `, ` ```donut `, ` ```candle `,
/// ` ```waterfall `, ` ```barlist `, ` ```kpi `, ` ```spark `) code block
/// using the TraderHub reusable component library ([UiCard], [UiAreaChart],
/// [UiBarChart], [UiLineChart], [UiComboChart], [UiDonutChart],
/// [UiCandleChart], [UiWaterfallChart], [UiSparkChart], [UiBarList],
/// [UiMetricCard], [UiCardGrid], [UiBadge], and [UiCallout]).
class ChartBlock extends StatelessWidget {
  const ChartBlock({super.key, required this.spec, this.defaultType});

  final String spec;
  final String? defaultType;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Map<String, dynamic>? data = _parseSpec(spec, defaultType);

    if (data == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
        child: const UiCallout(
          title: 'Chart unavailable',
          message: "Couldn't parse this chart specification.",
          intent: UiIntent.warning,
          icon: Icons.insert_chart_outlined,
        ),
      );
    }

    final String rawType =
        (data['type'] as String? ?? defaultType ?? _inferType(data))
            .toLowerCase()
            .trim();
    final String? title = _nonEmpty(data['title']?.toString());
    final String? subtitle = _nonEmpty(data['subtitle']?.toString());
    final String? metricValue = _nonEmpty(
      (data['value'] ?? data['metricValue'])?.toString(),
    );
    final String? metricChange = _nonEmpty(
      (data['change'] ?? data['delta'] ?? data['metricChange'])?.toString(),
    );
    final bool? isPositive = data['isPositive'] is bool
        ? data['isPositive'] as bool
        : (data['isBullish'] is bool
              ? data['isBullish'] as bool
              : (metricChange != null
                    ? !metricChange.trimLeft().startsWith('-')
                    : null));

    if (rawType == 'kpi' ||
        rawType == 'metrics' ||
        rawType == 'stats' ||
        data['metrics'] is List) {
      final Widget? kpiGrid = _buildMetricsGrid(context, data);
      if (kpiGrid != null) {
        if (title == null && subtitle == null) {
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.xs),
            ),
            child: kpiGrid,
          );
        }
        return Padding(
          padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
          child: UiCard(
            title: title,
            subtitle: subtitle,
            trailing: const UiBadge(
              label: 'METRICS',
              intent: UiIntent.primary,
              size: UiSize.xs,
            ),
            child: kpiGrid,
          ),
        );
      }
    }

    Widget? chartBody;
    String badgeLabel = rawType.toUpperCase();

    if (rawType == 'candle' ||
        rawType == 'candles' ||
        rawType == 'ohlc' ||
        data['candles'] is List) {
      badgeLabel = 'OHLC';
      chartBody = _buildCandleChart(context, data);
    } else if (rawType == 'waterfall' || data['steps'] is List) {
      badgeLabel = 'WATERFALL';
      chartBody = _buildWaterfallChart(context, data);
    } else if (rawType == 'barlist' ||
        rawType == 'ranking' ||
        rawType == 'leaderboard') {
      badgeLabel = 'RANKING';
      chartBody = _buildBarList(context, data);
    } else if (rawType == 'pie' ||
        rawType == 'donut' ||
        data['slices'] is List) {
      badgeLabel = 'ALLOCATION';
      chartBody = _buildDonutChart(context, data);
    } else if (rawType == 'spark' || rawType == 'sparkline') {
      badgeLabel = 'TREND';
      chartBody = _buildSparkChart(context, data);
    } else {
      chartBody = _buildCartesianChart(context, data, rawType);
    }

    if (chartBody == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
        child: const UiCallout(
          title: 'Incomplete chart data',
          message:
              'Provide "labels" and "series" (or "candles", "slices", "items", or "steps").',
          intent: UiIntent.warning,
          icon: Icons.insert_chart_outlined,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: UiCard(
        title: title ?? 'Chart',
        subtitle: subtitle,
        trailing: UiBadge(
          label: badgeLabel,
          intent: UiIntent.primary,
          size: UiSize.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (metricValue != null || metricChange != null) ...<Widget>[
              Wrap(
                spacing: context.sp(theme.spacing.sm),
                runSpacing: context.sp(theme.spacing.xs),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (metricValue != null)
                    Text(
                      metricValue,
                      style: context.uiText.heading.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (metricChange != null)
                    UiBadge(
                      label: metricChange,
                      intent: isPositive == null
                          ? UiIntent.neutral
                          : (isPositive ? UiIntent.bullish : UiIntent.bearish),
                      size: UiSize.xs,
                    ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
            ],
            chartBody,
          ],
        ),
      ),
    );
  }

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _inferType(Map<String, dynamic> data) {
    if (data['candles'] is List) return 'candle';
    if (data['steps'] is List) return 'waterfall';
    if (data['slices'] is List) return 'donut';
    if (data['metrics'] is List) return 'kpi';
    if (data['items'] is List && data['series'] == null) return 'barlist';
    return 'bar';
  }

  static Map<String, dynamic>? _parseSpec(String raw, String? defaultType) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      final dynamic decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) {
        return <String, dynamic>{
          'type': ?defaultType,
          'items': decoded,
        };
      }
    } catch (_) {
      // Fall back to lightweight key:value or CSV line parsing below.
    }

    // Parse simple YAML/CSV-like chart specs:
    // title: Revenue
    // type: bar
    // Q1: 120
    // Q2: 145
    final List<String> lines = trimmed
        .split('\n')
        .map((String l) => l.trim())
        .where((String l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    if (lines.isEmpty) return null;

    String? title;
    String? subtitle;
    String? type = defaultType;
    final List<String> labels = <String>[];
    final List<double> values = <double>[];

    for (final String line in lines) {
      final int colon = line.indexOf(':');
      if (colon > 0) {
        final String k = line.substring(0, colon).trim();
        final String v = line.substring(colon + 1).trim();
        final String kLower = k.toLowerCase();
        if (kLower == 'title') {
          title = v;
          continue;
        }
        if (kLower == 'subtitle') {
          subtitle = v;
          continue;
        }
        if (kLower == 'type') {
          type = v;
          continue;
        }
        final double? numVal = _parseNumber(v);
        if (numVal != null) {
          labels.add(k);
          values.add(numVal);
          continue;
        }
      }
      final List<String> csv = line.split(',');
      if (csv.length >= 2) {
        final double? numVal = _parseNumber(csv[1]);
        if (numVal != null) {
          labels.add(csv[0].trim());
          values.add(numVal);
        }
      }
    }

    if (labels.isEmpty || values.isEmpty) return null;
    return <String, dynamic>{
      'type': ?type,
      'title': ?title,
      'subtitle': ?subtitle,
      'labels': labels,
      'series': <Map<String, dynamic>>[
        <String, dynamic>{'name': title ?? 'Value', 'data': values},
      ],
    };
  }

  static double? _parseNumber(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is! String) return null;
    final String cleaned = raw.replaceAll(RegExp(r'[\$,%\s,]'), '').trim();
    return double.tryParse(cleaned);
  }

  static ({
    List<String> labels,
    List<({String name, List<double> values, String? type})> series,
  })
  _extractSeries(Map<String, dynamic> data) {
    final List<String> labels =
        (data['labels'] as List?)?.map((dynamic e) => e.toString()).toList() ??
        <String>[];
    final List<({String name, List<double> values, String? type})> series =
        <({String name, List<double> values, String? type})>[];

    final dynamic seriesRaw = data['series'];
    if (seriesRaw is List) {
      for (int i = 0; i < seriesRaw.length; i++) {
        final dynamic entry = seriesRaw[i];
        if (entry is Map) {
          final List<double> vals =
              ((entry['data'] ?? entry['values']) as List?)
                  ?.map((dynamic e) => _parseNumber(e) ?? 0.0)
                  .toList() ??
              const <double>[];
          series.add((
            name: entry['name']?.toString() ?? 'Series ${i + 1}',
            values: vals,
            type: entry['type']?.toString(),
          ));
        } else if (entry is num) {
          // Flat numeric list inside `series`.
          if (series.isEmpty) {
            series.add((
              name: data['title']?.toString() ?? 'Value',
              values: seriesRaw
                  .map((dynamic e) => _parseNumber(e) ?? 0.0)
                  .toList(),
              type: null,
            ));
          }
          break;
        }
      }
    }

    // Support top-level `data` or `values` array when `series` is omitted.
    if (series.isEmpty) {
      final dynamic rawData = data['data'] ?? data['values'] ?? data['items'];
      if (rawData is List && rawData.isNotEmpty) {
        if (rawData.first is num || rawData.first is String) {
          final List<double> vals = rawData
              .map((dynamic e) => _parseNumber(e) ?? 0.0)
              .toList();
          if (labels.isEmpty) {
            for (int i = 0; i < vals.length; i++) {
              labels.add('${i + 1}');
            }
          }
          series.add((
            name: data['title']?.toString() ?? 'Value',
            values: vals,
            type: null,
          ));
        } else if (rawData.first is Map) {
          final List<double> vals = <double>[];
          for (int i = 0; i < rawData.length; i++) {
            final Map<dynamic, dynamic> item =
                rawData[i] as Map<dynamic, dynamic>;
            final String lbl =
                (item['label'] ?? item['name'] ?? item['x'] ?? '${i + 1}')
                    .toString();
            if (labels.length <= i) labels.add(lbl);
            vals.add(
              _parseNumber(item['value'] ?? item['y'] ?? item['val']) ?? 0.0,
            );
          }
          series.add((
            name: data['title']?.toString() ?? 'Value',
            values: vals,
            type: null,
          ));
        }
      }
    }

    if (labels.isEmpty && series.isNotEmpty) {
      for (int i = 0; i < series.first.values.length; i++) {
        labels.add('${i + 1}');
      }
    }

    return (labels: labels, series: series);
  }

  static List<UiChartThreshold> _extractThresholds(Map<String, dynamic> data) {
    final dynamic raw = data['thresholds'];
    if (raw is! List) return const <UiChartThreshold>[];
    final List<UiChartThreshold> out = <UiChartThreshold>[];
    for (final dynamic item in raw) {
      if (item is Map) {
        final double? value = _parseNumber(item['value'] ?? item['price']);
        if (value == null) continue;
        out.add(
          UiChartThreshold(
            value: value,
            label: (item['label'] ?? value.toStringAsFixed(1)).toString(),
          ),
        );
      }
    }
    return out;
  }

  Widget? _buildCartesianChart(
    BuildContext context,
    Map<String, dynamic> data,
    String rawType,
  ) {
    final extracted = _extractSeries(data);
    final List<String> labels = extracted.labels;
    final series = extracted.series;
    if (labels.isEmpty || series.isEmpty) return null;

    final List<UiChartPoint> points = <UiChartPoint>[
      for (int i = 0; i < labels.length; i++)
        UiChartPoint(
          label: labels[i],
          values: <double>[
            for (final s in series) i < s.values.length ? s.values[i] : 0.0,
          ],
        ),
    ];

    final bool stacked = data['stacked'] == true;
    final double height =
        _parseNumber(data['height'])?.clamp(140.0, 420.0) ?? 220.0;
    final List<UiChartThreshold> thresholds = _extractThresholds(data);

    UiChartSeriesType resolveSeriesType(String? itemType) {
      final String t = (itemType ?? rawType).toLowerCase();
      if (t == 'line') return UiChartSeriesType.line;
      if (t == 'area') return UiChartSeriesType.area;
      return UiChartSeriesType.bar;
    }

    final List<UiChartSeries> uiSeries = <UiChartSeries>[
      for (int i = 0; i < series.length; i++)
        UiChartSeries(
          name: series[i].name,
          type: rawType == 'combo'
              ? (series[i].type != null
                    ? resolveSeriesType(series[i].type)
                    : (i == 0 ? UiChartSeriesType.bar : UiChartSeriesType.line))
              : resolveSeriesType(series[i].type),
          showDots: rawType == 'line',
        ),
    ];

    if (rawType == 'area') {
      return UiAreaChart(
        data: points,
        series: uiSeries,
        height: height,
        stacked: stacked,
        glow: true,
        thresholds: thresholds,
      );
    }
    if (rawType == 'line') {
      return UiLineChart(
        data: points,
        series: uiSeries,
        height: height,
        stacked: stacked,
        glow: true,
        thresholds: thresholds,
      );
    }
    if (rawType == 'combo') {
      return UiComboChart(
        data: points,
        series: uiSeries,
        height: height,
        stacked: stacked,
        thresholds: thresholds,
      );
    }
    return UiBarChart(
      data: points,
      series: uiSeries,
      height: height,
      stacked: stacked,
      thresholds: thresholds,
    );
  }

  Widget? _buildDonutChart(BuildContext context, Map<String, dynamic> data) {
    final List<UiDonutSlice> slices = <UiDonutSlice>[];
    final dynamic rawSlices = data['slices'] ?? data['items'];
    if (rawSlices is List) {
      for (int i = 0; i < rawSlices.length; i++) {
        final dynamic item = rawSlices[i];
        if (item is Map) {
          final double? val = _parseNumber(item['value'] ?? item['val']);
          if (val == null) continue;
          slices.add(
            UiDonutSlice(
              label: (item['label'] ?? item['name'] ?? 'Item ${i + 1}')
                  .toString(),
              value: val.abs(),
            ),
          );
        }
      }
    }
    if (slices.isEmpty) {
      final extracted = _extractSeries(data);
      if (extracted.labels.isNotEmpty && extracted.series.isNotEmpty) {
        final first = extracted.series.first;
        for (
          int i = 0;
          i < extracted.labels.length && i < first.values.length;
          i++
        ) {
          slices.add(
            UiDonutSlice(
              label: extracted.labels[i],
              value: first.values[i].abs(),
            ),
          );
        }
      }
    }
    if (slices.isEmpty) return null;

    final String? centerLabel = _nonEmpty(
      (data['centerLabel'] ?? data['total'] ?? data['value'])?.toString(),
    );
    return UiDonutChart(
      slices: slices,
      centerLabel: centerLabel,
      showLegend: true,
    );
  }

  Widget? _buildCandleChart(BuildContext context, Map<String, dynamic> data) {
    final dynamic rawCandles = data['candles'] ?? data['data'] ?? data['items'];
    if (rawCandles is! List || rawCandles.isEmpty) return null;

    final List<UiCandle> candles = <UiCandle>[];
    final DateTime now = DateTime.now();
    for (int i = 0; i < rawCandles.length; i++) {
      final dynamic item = rawCandles[i];
      if (item is! Map) continue;
      final double? open = _parseNumber(item['open'] ?? item['o']);
      final double? high = _parseNumber(item['high'] ?? item['h']);
      final double? low = _parseNumber(item['low'] ?? item['l']);
      final double? close = _parseNumber(item['close'] ?? item['c']);
      if (open == null || high == null || low == null || close == null) {
        continue;
      }
      final double volume = _parseNumber(item['volume'] ?? item['v']) ?? 0.0;
      final DateTime time =
          DateTime.tryParse(
            (item['time'] ?? item['date'] ?? '').toString(),
          ) ??
          now.subtract(Duration(days: rawCandles.length - i));
      candles.add(
        UiCandle(
          time: time,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
        ),
      );
    }
    if (candles.isEmpty) return null;

    final List<UiPriceLine> priceLines = <UiPriceLine>[];
    final dynamic rawLines = data['priceLines'] ?? data['thresholds'];
    if (rawLines is List) {
      for (final dynamic item in rawLines) {
        if (item is Map) {
          final double? price = _parseNumber(item['price'] ?? item['value']);
          if (price == null) continue;
          final String intentStr =
              (item['intent'] ?? 'primary').toString().toLowerCase();
          final UiIntent intent = intentStr == 'bullish' || intentStr == 'success'
              ? UiIntent.bullish
              : (intentStr == 'bearish' || intentStr == 'danger'
                    ? UiIntent.bearish
                    : (intentStr == 'warning'
                          ? UiIntent.warning
                          : UiIntent.primary));
          priceLines.add(
            UiPriceLine(
              price: price,
              label: (item['label'] ?? 'Level').toString(),
              intent: intent,
            ),
          );
        }
      }
    }

    final List<UiCandleOverlay> overlays = <UiCandleOverlay>[];
    if (candles.length >= 5 && data['sma'] != false) {
      overlays.add(UiCandleOverlay.sma(candles, 5));
    }

    return UiCandleChart(
      candles: candles,
      overlays: overlays,
      priceLines: priceLines,
      showVolume: candles.any((UiCandle c) => c.volume > 0),
      height: _parseNumber(data['height'])?.clamp(160.0, 420.0) ?? 240.0,
    );
  }

  Widget? _buildWaterfallChart(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final List<UiWaterfallStep> steps = <UiWaterfallStep>[];
    final dynamic rawSteps = data['steps'] ?? data['items'];
    if (rawSteps is List) {
      for (int i = 0; i < rawSteps.length; i++) {
        final dynamic item = rawSteps[i];
        if (item is Map) {
          final double? val = _parseNumber(item['value'] ?? item['val']);
          if (val == null) continue;
          steps.add(
            UiWaterfallStep(
              label: (item['label'] ?? item['name'] ?? 'Step ${i + 1}')
                  .toString(),
              value: val,
              isTotal: item['isTotal'] == true || item['total'] == true,
            ),
          );
        }
      }
    }
    if (steps.isEmpty) {
      final extracted = _extractSeries(data);
      if (extracted.labels.isNotEmpty && extracted.series.isNotEmpty) {
        final first = extracted.series.first;
        for (
          int i = 0;
          i < extracted.labels.length && i < first.values.length;
          i++
        ) {
          steps.add(
            UiWaterfallStep(
              label: extracted.labels[i],
              value: first.values[i],
              isTotal: i == 0 || i == extracted.labels.length - 1,
            ),
          );
        }
      }
    }
    if (steps.isEmpty) return null;
    return UiWaterfallChart(
      steps: steps,
      height: _parseNumber(data['height'])?.clamp(120.0, 320.0) ?? 160.0,
    );
  }

  Widget? _buildBarList(BuildContext context, Map<String, dynamic> data) {
    final List<UiBarListItem> items = <UiBarListItem>[];
    final dynamic rawItems = data['items'] ?? data['bars'];
    if (rawItems is List) {
      for (int i = 0; i < rawItems.length; i++) {
        final dynamic item = rawItems[i];
        if (item is Map) {
          final double? val = _parseNumber(item['value'] ?? item['val']);
          if (val == null) continue;
          items.add(
            UiBarListItem(
              label: (item['label'] ?? item['name'] ?? 'Item ${i + 1}')
                  .toString(),
              value: val,
              displayValue: _nonEmpty(item['displayValue']?.toString()),
              percentage: _parseNumber(item['percentage']),
            ),
          );
        }
      }
    }
    if (items.isEmpty) {
      final extracted = _extractSeries(data);
      if (extracted.labels.isNotEmpty && extracted.series.isNotEmpty) {
        final first = extracted.series.first;
        for (
          int i = 0;
          i < extracted.labels.length && i < first.values.length;
          i++
        ) {
          items.add(
            UiBarListItem(
              label: extracted.labels[i],
              value: first.values[i],
            ),
          );
        }
      }
    }
    if (items.isEmpty) return null;
    return UiBarList(items: items);
  }

  Widget? _buildSparkChart(BuildContext context, Map<String, dynamic> data) {
    final extracted = _extractSeries(data);
    if (extracted.series.isEmpty || extracted.series.first.values.isEmpty) {
      return null;
    }
    final List<double> values = extracted.series.first.values;
    final bool bullish = values.length < 2 || values.last >= values.first;
    return UiSparkChart(
      values: values,
      labels: extracted.labels,
      filled: true,
      height: _parseNumber(data['height'])?.clamp(40.0, 140.0) ?? 64.0,
      color: bullish ? context.uiColors.bullish : context.uiColors.bearish,
    );
  }

  Widget? _buildMetricsGrid(BuildContext context, Map<String, dynamic> data) {
    final dynamic rawMetrics = data['metrics'] ?? data['items'];
    final List<Widget> cards = <Widget>[];
    if (rawMetrics is List) {
      for (final dynamic item in rawMetrics) {
        if (item is! Map) continue;
        final String label =
            (item['label'] ?? item['title'] ?? item['name'] ?? '').toString();
        final String value = (item['value'] ?? item['val'] ?? '').toString();
        if (label.isEmpty && value.isEmpty) continue;
        final String? change = _nonEmpty(
          (item['change'] ?? item['delta'])?.toString(),
        );
        final bool? isPositive = item['isPositive'] is bool
            ? item['isPositive'] as bool
            : (change != null ? !change.trimLeft().startsWith('-') : null);
        final List<double>? spark = (item['sparkline'] as List?)
            ?.map((dynamic e) => _parseNumber(e) ?? 0.0)
            .toList();
        cards.add(
          UiMetricCard(
            label: label,
            value: value,
            change: change,
            isPositive: isPositive,
            subtitle: _nonEmpty(
              (item['subtitle'] ?? item['caption'])?.toString(),
            ),
            sparkline: spark,
          ),
        );
      }
    }
    if (cards.isEmpty) {
      final extracted = _extractSeries(data);
      if (extracted.labels.isNotEmpty && extracted.series.isNotEmpty) {
        final first = extracted.series.first;
        for (
          int i = 0;
          i < extracted.labels.length && i < first.values.length;
          i++
        ) {
          final double v = first.values[i];
          cards.add(
            UiMetricCard(
              label: extracted.labels[i],
              value: v == v.roundToDouble()
                  ? v.toInt().toString()
                  : v.toStringAsFixed(2),
            ),
          );
        }
      }
    }
    if (cards.isEmpty) return null;
    return UiCardGrid(minTileWidth: 180, children: cards);
  }
}
