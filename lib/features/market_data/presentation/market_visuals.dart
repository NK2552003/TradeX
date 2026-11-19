import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import '../models/market_snapshot.dart';
import 'market_instrument_data.dart';

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
  const MarketChangeDistribution({
    super.key,
    required this.instruments,
    this.distribution,
  });
  final List<MarketInstrument> instruments;
  final Map<String, dynamic>? distribution;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final distBins = distribution?['bins'];
    final bool useGlobal = distBins is Map && distBins.isNotEmpty;

    final gainers = instruments.where((q) => q.changePercent > 0).toList();
    final losers = instruments.where((q) => q.changePercent < 0).toList();
    final int gainersCount = useGlobal
        ? (distribution!['gainers_count'] as num? ?? gainers.length).toInt()
        : gainers.length;
    final int losersCount = useGlobal
        ? (distribution!['losers_count'] as num? ?? losers.length).toInt()
        : losers.length;
    final int totalCount = useGlobal
        ? (distribution!['total'] as num? ?? instruments.length).toInt()
        : instruments.length;
    final double bestGain = useGlobal
        ? (distribution!['best_gain'] as num?)?.toDouble() ??
              (gainers.isEmpty
                  ? 0.0
                  : gainers
                        .map((q) => q.changePercent)
                        .reduce((a, b) => a > b ? a : b))
        : (gainers.isEmpty
              ? 0.0
              : gainers
                    .map((q) => q.changePercent)
                    .reduce((a, b) => a > b ? a : b));
    final double worstLoss = useGlobal
        ? (distribution!['worst_loss'] as num?)?.toDouble() ??
              (losers.isEmpty
                  ? 0.0
                  : losers
                        .map((q) => q.changePercent)
                        .reduce((a, b) => a < b ? a : b))
        : (losers.isEmpty
              ? 0.0
              : losers
                    .map((q) => q.changePercent)
                    .reduce((a, b) => a < b ? a : b));

    final bins = <String, int>{
      '< -5%': 0,
      '-5 to -2%': 0,
      '-2 to 0%': 0,
      '0 to 2%': 0,
      '2 to 5%': 0,
      '> 5%': 0,
    };
    if (useGlobal) {
      for (final key in bins.keys) {
        bins[key] = (distBins[key] as num? ?? 0).toInt();
      }
    } else {
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
    }

    Widget statItem(String label, String value, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
              fontWeight: FontWeight.w700,
              fontSize: context.fs(11),
              letterSpacing: 0.6,
            ),
          ),
          UiGap.v(theme.spacing.xxs),
          Text(
            value,
            style: context.uiText.title.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    Widget verticalDivider() {
      return Container(
        width: 1,
        height: context.sz(32),
        color: theme.colors.border.withValues(alpha: 0.4),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Stats Banner matching Image 1
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.sm),
          ),
          decoration: BoxDecoration(
            color: theme.colors.surfaceMuted,
            borderRadius: context.radius(theme.radii.sm),
            border: Border.all(
              color: theme.colors.border,
              width: theme.borders.hairline,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 540) {
                return Wrap(
                  alignment: WrapAlignment.spaceAround,
                  runAlignment: WrapAlignment.center,
                  spacing: context.sp(theme.spacing.sm),
                  runSpacing: context.sp(theme.spacing.xs),
                  children: [
                    statItem(
                      'TOP GAINERS',
                      '$gainersCount',
                      theme.colors.bullish,
                    ),
                    statItem(
                      'TOP LOSERS',
                      '$losersCount',
                      theme.colors.bearish,
                    ),
                    statItem(
                      'BEST GAIN',
                      '+${bestGain.toStringAsFixed(2)}%',
                      theme.colors.bullish,
                    ),
                    statItem(
                      'WORST LOSS',
                      '${worstLoss.toStringAsFixed(2)}%',
                      theme.colors.bearish,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: statItem(
                      'TOP GAINERS',
                      '$gainersCount',
                      theme.colors.bullish,
                    ),
                  ),
                  verticalDivider(),
                  Expanded(
                    child: statItem(
                      'TOP LOSERS',
                      '$losersCount',
                      theme.colors.bearish,
                    ),
                  ),
                  verticalDivider(),
                  Expanded(
                    child: statItem(
                      'BEST GAIN',
                      '+${bestGain.toStringAsFixed(2)}%',
                      theme.colors.bullish,
                    ),
                  ),
                  verticalDivider(),
                  Expanded(
                    child: statItem(
                      'WORST LOSS',
                      '${worstLoss.toStringAsFixed(2)}%',
                      theme.colors.bearish,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        UiGap.v(theme.spacing.sm),

        // Distribution Bar Chart Card
        UiCard(
          title: 'Daily change distribution',
          subtitle: '$totalCount quoted instruments · percentage change',
          child: totalCount == 0
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
                      color: theme.colors.foreground,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class MarketFundamentalVisuals extends StatelessWidget {
  const MarketFundamentalVisuals({super.key, required this.data});
  final InstrumentDetailData data;

  @override
  Widget build(BuildContext context) {
    final low = instrumentNumber(data.summary['fifty_two_week_low']);
    final high = instrumentNumber(data.summary['fifty_two_week_high']);
    final price = data.hasQuote ? data.price : null;
    return UiCard(
      title: '52-week position',
      leading: const Icon(Icons.straighten_outlined),
      child: low != null || high != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (low != null && high != null && high > low) ...[
                  UiRangeMeter(
                    min: low,
                    max: high,
                    showBounds: false,
                    valueFormatter: data.formatPrice,
                    markers: [
                      if (price != null)
                        UiRangeMarker(
                          value: price,
                          label: 'Quote',
                          strong: true,
                        ),
                    ],
                  ),
                  UiGap.v(context.ui.spacing.sm),
                ],
                UiStatStrip(
                  minCellWidth: 96,
                  stats: [
                    if (low != null)
                      UiStat(
                        label: '52-week low',
                        value: data.formatPrice(low),
                      ),
                    if (high != null)
                      UiStat(
                        label: '52-week high',
                        value: data.formatPrice(high),
                      ),
                  ],
                ),
              ],
            )
          : const UiEmptyState(
              title: '52-week range unavailable',
              compact: true,
            ),
    );
  }
}

class MarketOptionsInterest extends StatelessWidget {
  const MarketOptionsInterest({super.key, required this.chains});
  final InstrumentRow chains;

  @override
  Widget build(BuildContext context) {
    final points = <UiChartPoint>[];
    var hasOpenInterest = false;
    for (final expiry in chains.entries.take(8)) {
      final sides = instrumentMap(expiry.value);
      double total(String side) {
        var sum = 0.0;
        for (final row in instrumentRows(sides[side])) {
          final interest = instrumentNumber(row['openInterest']);
          if (interest != null && interest >= 0) {
            sum += interest;
            hasOpenInterest = true;
          }
        }
        return sum;
      }

      final expiryDate = DateTime.tryParse(expiry.key);
      points.add(
        UiChartPoint(
          label: expiryDate == null
              ? expiry.key
              : MaterialLocalizations.of(
                  context,
                ).formatShortMonthDay(expiryDate),
          values: [total('calls'), total('puts')],
        ),
      );
    }
    return UiCard(
      title: 'Options open interest',
      subtitle: points.length == 1
          ? 'Reported contracts for one expiration'
          : 'Reported contracts across ${points.length} expirations',
      child: !hasOpenInterest
          ? const UiEmptyState(
              title: 'Open interest unavailable',
              compact: true,
            )
          : UiBarChart(
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

class MarketRelatedMoves extends StatelessWidget {
  const MarketRelatedMoves({
    super.key,
    required this.instruments,
    this.onInstrument,
  });
  final List<MarketInstrument> instruments;
  final ValueChanged<MarketInstrument>? onInstrument;

  @override
  Widget build(BuildContext context) {
    if (instruments.isEmpty) return const SizedBox.shrink();
    final theme = context.ui;
    return UiCard(
      title: 'Related quote moves',
      subtitle:
          'Snapshot change for mentioned instruments; no causal attribution',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiBarChart(
            data: [
              for (final q in instruments.take(8))
                UiChartPoint(label: q.symbol, values: [q.changePercent]),
            ],
            series: [
              UiChartSeries(
                name: 'Change %',
                color: theme.colors.bullish,
                negativeColor: theme.colors.bearish,
              ),
            ],
            negativeColor: theme.colors.bearish,
            height: 180,
            showLegend: false,
          ),
          UiGap.v(theme.spacing.sm),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: [
              for (final q in instruments.take(8))
                InkWell(
                  onTap: () => onInstrument?.call(q),
                  borderRadius: context.radius(theme.radii.pill),
                  child: UiBadge(
                    label:
                        '${q.symbol} ${q.changePercent >= 0 ? '+' : ''}${q.changePercent.toStringAsFixed(2)}%',
                    intent: q.changePercent >= 0
                        ? UiIntent.success
                        : UiIntent.danger,
                    variant: UiBadgeVariant.soft,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
