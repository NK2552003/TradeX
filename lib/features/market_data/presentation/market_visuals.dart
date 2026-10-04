import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../models/market_snapshot.dart';

/// Charted summaries derived only from values present in the asset snapshot.
class MarketDistributionCard extends StatelessWidget {
  const MarketDistributionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.values,
    this.maxItems = 6,
  });

  final String title, subtitle;
  final Map<String, num> values;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final ranked = values.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = ranked.take(maxItems).toList();
    final other = ranked.skip(maxItems).fold<num>(0, (sum, e) => sum + e.value);
    final total = ranked.fold<num>(0, (sum, e) => sum + e.value);
    return UiCard(
      title: title,
      subtitle: subtitle,
      child: ranked.isEmpty
          ? const UiEmptyState(title: 'No data in this snapshot')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiDonutChart(
                  size: 160,
                  centerLabel: '$total',
                  slices: [
                    for (final entry in shown)
                      UiDonutSlice(
                        label: entry.key,
                        value: entry.value.toDouble(),
                      ),
                    if (other > 0)
                      UiDonutSlice(label: 'Other', value: other.toDouble()),
                  ],
                ),
                UiGap.v(context.ui.spacing.md),
                UiBarList(
                  items: [
                    for (final entry in shown)
                      UiBarListItem(
                        label: entry.key,
                        value: entry.value,
                        percentage: total == 0 ? 0 : entry.value / total,
                      ),
                    if (other > 0)
                      UiBarListItem(
                        label: 'Other',
                        value: other,
                        percentage: other / total,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class MarketChangeDistribution extends StatelessWidget {
  const MarketChangeDistribution({super.key, required this.instruments});
  final List<MarketInstrument> instruments;

  @override
  Widget build(BuildContext context) {
    final bins = <String, int>{
      '< -5%': 0,
      '-5 to -2%': 0,
      '-2 to 0%': 0,
      '0 to 2%': 0,
      '2 to 5%': 0,
      '> 5%': 0,
    };
    for (final q in instruments) {
      final v = q.changePercent;
      final key = v < -5
          ? '< -5%'
          : v < -2
          ? '-5 to -2%'
          : v < 0
          ? '-2 to 0%'
          : v < 2
          ? '0 to 2%'
          : v < 5
          ? '2 to 5%'
          : '> 5%';
      bins[key] = bins[key]! + 1;
    }
    return UiCard(
      title: 'Daily change distribution',
      subtitle: '${instruments.length} quoted instruments · percentage change',
      child: instruments.isEmpty
          ? const UiEmptyState(title: 'No quotes in this snapshot')
          : UiBarChart(
              height: 230,
              showLegend: false,
              data: [
                for (final entry in bins.entries)
                  UiChartPoint(
                    label: entry.key,
                    values: [entry.value.toDouble()],
                  ),
              ],
              series: [
                UiChartSeries(
                  name: 'Instruments',
                  color: context.ui.colors.primary,
                ),
              ],
            ),
    );
  }
}

class MarketFundamentalVisuals extends StatelessWidget {
  const MarketFundamentalVisuals({
    super.key,
    required this.instrument,
    required this.detail,
  });
  final MarketInstrument instrument;
  final Map<String, dynamic> detail;

  @override
  Widget build(BuildContext context) {
    final summary = detail['summary'] as Map? ?? {};
    double? number(String key) => (summary[key] as num?)?.toDouble();
    final low = number('fifty_two_week_low');
    final high = number('fifty_two_week_high');
    final price = instrument.price;
    final validRange = low != null && high != null && high > low;
    final recs = (detail['recommendations'] as List? ?? const [])
        .whereType<Map>();
    final recent = recs.firstOrNull;
    final opinions = <String, num>{
      if (recent != null) 'Strong buy': (recent['strongBuy'] as num?) ?? 0,
      if (recent != null) 'Buy': (recent['buy'] as num?) ?? 0,
      if (recent != null) 'Hold': (recent['hold'] as num?) ?? 0,
      if (recent != null) 'Sell': (recent['sell'] as num?) ?? 0,
      if (recent != null) 'Strong sell': (recent['strongSell'] as num?) ?? 0,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          title: '52-week position',
          subtitle: 'Recorded low, current quote, and high',
          child: validRange
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UiProgressBar(
                      value: ((price - low) / (high - low)).clamp(0.0, 1.0),
                      label:
                          '${instrument.currency} ${price.toStringAsFixed(2)}',
                    ),
                    UiGap.v(context.ui.spacing.sm),
                    UiStatStrip(
                      stats: [
                        UiStat(label: '52w low', value: low.toStringAsFixed(2)),
                        UiStat(
                          label: '52w high',
                          value: high.toStringAsFixed(2),
                        ),
                        if (number('fifty_day_average') != null)
                          UiStat(
                            label: '50d average',
                            value: number(
                              'fifty_day_average',
                            )!.toStringAsFixed(2),
                          ),
                      ],
                    ),
                  ],
                )
              : const UiEmptyState(title: '52-week range unavailable'),
        ),
        if (opinions.values.any((v) => v > 0)) ...[
          UiGap.v(context.ui.spacing.md),
          MarketDistributionCard(
            title: 'Analyst recommendations',
            subtitle: 'Most recent available reporting period',
            values: opinions,
          ),
        ],
      ],
    );
  }
}

class MarketOptionsInterest extends StatelessWidget {
  const MarketOptionsInterest({super.key, required this.chains});
  final Map chains;

  @override
  Widget build(BuildContext context) {
    final points = <UiChartPoint>[];
    for (final expiry in chains.entries.take(8)) {
      final sides = expiry.value as Map? ?? {};
      double total(String side) =>
          (sides[side] as List? ?? const []).whereType<Map>().fold<double>(
            0,
            (sum, row) =>
                sum + ((row['openInterest'] as num?)?.toDouble() ?? 0),
          );
      points.add(
        UiChartPoint(
          label: '${expiry.key}',
          values: [total('calls'), total('puts')],
        ),
      );
    }
    if (points.isEmpty) return const SizedBox.shrink();
    return UiCard(
      title: 'Options open interest',
      subtitle: 'Calls and puts across the first ${points.length} expirations',
      child: UiBarChart(
        data: points,
        series: [
          UiChartSeries(name: 'Calls', color: context.ui.colors.success),
          UiChartSeries(name: 'Puts', color: context.ui.colors.danger),
        ],
        height: 240,
      ),
    );
  }
}

class MarketDividendHistory extends StatelessWidget {
  const MarketDividendHistory({super.key, required this.dividends});
  final List dividends;

  @override
  Widget build(BuildContext context) {
    final recent = dividends
        .whereType<Map>()
        .toList()
        .reversed
        .take(12)
        .toList()
        .reversed;
    if (recent.isEmpty) return const SizedBox.shrink();
    return UiCard(
      title: 'Dividend history',
      subtitle: 'Last ${recent.length} recorded payments',
      child: UiBarChart(
        height: 220,
        showLegend: false,
        data: [
          for (final row in recent)
            UiChartPoint(
              label: '${row['date']}'.split('T').first,
              values: [(row['amount'] as num? ?? 0).toDouble()],
            ),
        ],
        series: [
          UiChartSeries(name: 'Dividend', color: context.ui.colors.primary),
        ],
      ),
    );
  }
}

class MarketInstitutionalHolders extends StatelessWidget {
  const MarketInstitutionalHolders({super.key, required this.holders});
  final List holders;

  @override
  Widget build(BuildContext context) {
    final rows =
        holders.whereType<Map>().where((r) => r['Holder'] != null).toList()
          ..sort(
            (a, b) => ((b['pctHeld'] as num?) ?? 0).compareTo(
              (a['pctHeld'] as num?) ?? 0,
            ),
          );
    if (rows.isEmpty) return const SizedBox.shrink();
    return UiCard(
      title: 'Institutional ownership',
      subtitle: 'Largest disclosed holders',
      child: UiBarList(
        items: [
          for (final row in rows.take(8))
            UiBarListItem(
              label: '${row['Holder']}',
              value: ((row['pctHeld'] as num?) ?? 0) * 100,
              percentage: ((row['pctHeld'] as num?)?.toDouble() ?? 0).clamp(
                0,
                1,
              ),
            ),
        ],
      ),
    );
  }
}

class MarketRelatedMoves extends StatelessWidget {
  const MarketRelatedMoves({super.key, required this.instruments});
  final List<MarketInstrument> instruments;

  @override
  Widget build(BuildContext context) {
    if (instruments.isEmpty) return const SizedBox.shrink();
    return UiCard(
      title: 'Related quote moves',
      subtitle:
          'Snapshot change for mentioned instruments; no causal attribution',
      child: UiBarChart(
        data: [
          for (final q in instruments.take(8))
            UiChartPoint(label: q.symbol, values: [q.changePercent]),
        ],
        series: [
          UiChartSeries(name: 'Change %', color: context.ui.colors.primary),
        ],
        height: 220,
        showLegend: false,
      ),
    );
  }
}
