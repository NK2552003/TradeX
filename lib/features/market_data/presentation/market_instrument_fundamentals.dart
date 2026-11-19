import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import 'market_instrument_contact.dart';
import 'market_instrument_data.dart';
import 'market_instrument_data_fields.dart';
import 'market_visuals.dart';

class InstrumentFundamentals extends StatelessWidget {
  const InstrumentFundamentals({super.key, required this.data});
  final InstrumentDetailData data;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final metrics = [
      (
        key: 'market_cap',
        label: 'Market cap',
        icon: Icons.pie_chart_outline,
        format: data.formatCapital,
      ),
      (
        key: 'pe_ratio',
        label: 'P/E',
        icon: Icons.balance_outlined,
        format: _multiple,
      ),
      (
        key: 'eps',
        label: 'Earnings per share',
        icon: Icons.payments_outlined,
        format: _price,
      ),
      (
        key: 'shares_outstanding',
        label: 'Shares outstanding',
        icon: Icons.stacked_bar_chart_outlined,
        format: instrumentCount,
      ),
    ];
    final metricCards = [
      for (final metric in metrics)
        if (instrumentNumber(summary[metric.key]) != null)
          UiMetricCard(
            label: metric.label,
            icon: metric.icon,
            value: metric.format(summary[metric.key]),
          ),
    ];
    final description =
        instrumentText(summary['description']) ??
        instrumentText(summary['longBusinessSummary']);
    final industry = instrumentText(summary['industry']);
    final secondaryMetrics = [
      (key: 'forward_pe', label: 'Forward P/E', format: _multiple),
      (key: 'peg_ratio', label: 'PEG ratio', format: _multiple),
      (key: 'beta', label: 'Beta', format: _multiple),
      (key: 'avg_volume', label: 'Average volume', format: instrumentCount),
      (key: 'fifty_day_average', label: '50-day average', format: _price),
      (
        key: 'two_hundred_day_average',
        label: '200-day average',
        format: _price,
      ),
    ];
    final secondaryStats = [
      for (final metric in secondaryMetrics)
        if (instrumentNumber(summary[metric.key]) != null)
          UiStat(
            label: metric.label,
            value: metric.format(summary[metric.key]),
          ),
    ];
    final extraPreviews = _fundamentalPreviews(summary);
    final remaining = Map<String, dynamic>.of(summary)
      ..removeWhere(
        (key, value) =>
            value == null ||
            const {
              'name',
              'ticker',
              'market',
              'exchange',
              'currency',
              'description',
              'longBusinessSummary',
              'industry',
              'sector',
              'fifty_two_week_low',
              'fifty_two_week_high',
            }.contains(key) ||
            InstrumentContact.fields.contains(key) ||
            extraPreviews.any((group) => group.stats.containsKey(key)) ||
            metrics.any((metric) => metric.key == key) ||
            secondaryMetrics.any((metric) => metric.key == key),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (metricCards.isNotEmpty) ...[
          UiCardGrid(minTileWidth: context.sz(152), children: metricCards),
          UiGap.v(context.ui.spacing.md),
        ],
        if (secondaryStats.isNotEmpty) ...[
          UiCard(
            title: 'Trading and valuation',
            leading: const Icon(Icons.insights_outlined),
            child: UiStatStrip(stats: secondaryStats, minCellWidth: 135),
          ),
          UiGap.v(context.ui.spacing.md),
        ],
        if (description != null || industry != null) ...[
          UiCard(
            title: 'About the company',
            subtitle: industry,
            leading: const Icon(Icons.business_outlined),
            child: description == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: context.sz(770)),
                      child: Text(
                        description,
                        style: context.uiText.body.copyWith(height: 1.55),
                      ),
                    ),
                  ),
          ),
          UiGap.v(context.ui.spacing.md),
        ],
        if (InstrumentContact.fields.any(
          (field) => instrumentText(summary[field]) != null,
        )) ...[
          InstrumentContact(summary: summary),
          UiGap.v(context.ui.spacing.md),
        ],
        if (extraPreviews.any((group) => group.stats.isNotEmpty)) ...[
          UiCardGrid(
            minTileWidth: context.sz(310),
            largeColumns: 2,
            equalHeight: true,
            children: [
              for (final group in extraPreviews)
                if (group.stats.isNotEmpty)
                  UiCard(
                    title: group.title,
                    leading: Icon(group.icon),
                    child: UiStatStrip(
                      stats: group.stats.values.toList(),
                      minCellWidth: 122,
                    ),
                  ),
            ],
          ),
          UiGap.v(context.ui.spacing.md),
        ],
        if (remaining.isNotEmpty)
          UiCard(
            child: UiAccordion(
              items: [
                UiAccordionItem(
                  title: 'More fundamentals',
                  content: MarketDataFields(data: remaining),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _multiple(Object? value) =>
      '${instrumentNumber(value)?.toStringAsFixed(2)}×';
  String _price(Object? value) => data.formatPrice(instrumentNumber(value));

  List<({String title, IconData icon, Map<String, UiStat> stats})>
  _fundamentalPreviews(InstrumentRow summary) {
    MapEntry<String, UiStat>? metric(
      String key,
      String label,
      String Function(double) format,
    ) {
      final number = instrumentNumber(summary[key]);
      return number == null
          ? null
          : MapEntry(key, UiStat(label: label, value: format(number)));
    }

    final recommendation = instrumentText(summary['recommendation']);
    final updated = DateTime.tryParse('${summary['updated_at']}');
    final yield = summary['dividend_yield'];
    return [
      (
        title: 'Financial health',
        icon: Icons.account_balance_wallet_outlined,
        stats: Map.fromEntries([
          ?metric('total_cash', 'Total cash', data.formatCapital),
          ?metric('total_debt', 'Total debt', data.formatCapital),
          ?metric('free_cashflow', 'Free cash flow', data.formatCapital),
          ?metric('total_revenue', 'Total revenue', data.formatCapital),
          ?metric('profit_margins', 'Profit margin', _fractionPercent),
          ?metric('revenue_growth', 'Revenue growth', _fractionPercent),
          ?metric('earnings_growth', 'Earnings growth', _fractionPercent),
        ]),
      ),
      (
        title: 'Price target',
        icon: Icons.track_changes_outlined,
        stats: Map.fromEntries([
          ?metric('target_mean_price', 'Mean target', data.formatPrice),
          if (recommendation != null)
            MapEntry(
              'recommendation',
              UiStat(
                label: 'Analyst rating',
                value: marketFieldLabel(recommendation),
              ),
            ),
          ?metric('number_of_analyst_opinions', 'Analysts', instrumentCount),
        ]),
      ),
      (
        title: 'Shares and yield',
        icon: Icons.donut_large_outlined,
        stats: Map.fromEntries([
          ?metric('float_shares', 'Public float', instrumentCount),
          ?metric('short_ratio', 'Days to cover', (v) => v.toStringAsFixed(2)),
          ?metric('held_percent_insiders', 'Insider stake', _fractionPercent),
          ?metric(
            'held_percent_institutions',
            'Institutional stake',
            _fractionPercent,
          ),
          if (yield is num || instrumentText(yield) != null)
            MapEntry(
              'dividend_yield',
              UiStat(
                label: 'Dividend yield',
                // Historical snapshots store the upstream value without units.
                value: instrumentNumber(yield) == 0 ? '0%' : '$yield',
              ),
            ),
        ]),
      ),
      (
        title: 'Company facts',
        icon: Icons.business_outlined,
        stats: Map.fromEntries([
          ?metric('employees', 'Employees', instrumentCount),
          if (updated != null)
            MapEntry(
              'updated_at',
              UiStat(label: 'Snapshot date', value: instrumentDate(updated)),
            ),
        ]),
      ),
    ];
  }

  String _fractionPercent(double value) => instrumentPercent(value, scale: 100);
}

class InstrumentQuoteStats extends StatelessWidget {
  const InstrumentQuoteStats({super.key, required this.data});
  final InstrumentDetailData data;

  @override
  Widget build(BuildContext context) {
    final session = data.lastCandle;
    final quote = data.quoteStatistics;
    final quoteStats = [
      if (data.previousClose case final price?)
        UiStat(label: 'Previous close', value: data.formatPrice(price)),
      if (instrumentNumber(quote['day_high']) case final high?)
        UiStat(label: 'Day high', value: data.formatPrice(high)),
      if (instrumentNumber(quote['day_low']) case final low?)
        UiStat(label: 'Day low', value: data.formatPrice(low)),
      if (instrumentNumber(quote['volume']) case final volume?)
        UiStat(label: 'Volume', value: instrumentCount(volume)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarketFundamentalVisuals(data: data),
        if (quoteStats.isNotEmpty) ...[
          UiGap.v(context.ui.spacing.md),
          UiCard(
            title: 'Quote statistics',
            child: UiStatStrip(minCellWidth: 112, stats: quoteStats),
          ),
        ],
        if (session != null) ...[
          UiGap.v(context.ui.spacing.md),
          UiCard(
            title: 'Latest historical session',
            subtitle: instrumentDate(session.time),
            child: UiStatStrip(
              minCellWidth: 112,
              stats: [
                UiStat(label: 'Open', value: data.formatPrice(session.open)),
                UiStat(label: 'High', value: data.formatPrice(session.high)),
                UiStat(label: 'Low', value: data.formatPrice(session.low)),
                UiStat(label: 'Volume', value: instrumentCount(session.volume)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class InstrumentDataSources extends StatelessWidget {
  const InstrumentDataSources({super.key, required this.data});
  final InstrumentDetailData data;

  @override
  Widget build(BuildContext context) {
    final raw = data.raw;
    final snapshot = instrumentMap(raw['snapshot']);
    final source =
        instrumentText(snapshot['source']) ??
        instrumentText(raw['data_source']);
    final counts = {
      'Price history': data.candles.length,
      'Options': data.chains.length,
      'Dividends & splits':
          instrumentRows(data.actions['dividends']).length +
          instrumentRows(data.actions['splits']).length,
      'Analyst ratings': data.recommendations.length,
      'Ownership': data.holders.values.fold(
        0,
        (count, rows) => count + instrumentRows(rows).length,
      ),
      'Company news': instrumentRows(raw['news']).length,
    };
    final availability = instrumentMap(raw['availability']);
    final chartMetadata = Map<String, dynamic>.of(data.chart)..remove('data');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          title: 'Snapshot & availability',
          leading: const Icon(Icons.storage_outlined),
          child: UiStatStrip(
            stats: [
              if (source != null)
                UiStat(
                  label: 'Source',
                  value: switch (source) {
                    'supabase_live' => 'Market database',
                    'yahoo' => 'Yahoo Finance',
                    _ => source,
                  },
                ),
              if (raw['fetched_at'] case final fetchedAt?)
                UiStat(
                  label: 'Snapshot date',
                  value: instrumentDate(fetchedAt),
                ),
              UiStat(
                label: 'Sections with data',
                value:
                    '${counts.values.where((count) => count > 0).length} of ${counts.length}',
              ),
            ],
          ),
        ),
        UiGap.v(context.ui.spacing.md),
        UiCardGrid(
          minTileWidth: context.sz(220),
          largeColumns: 3,
          children: [
            for (final section in counts.entries)
              UiMetricCard(
                label: section.key,
                value: section.value == 0
                    ? 'Unavailable'
                    : '${uiGrouped(section.value, decimals: 0)} records',
                icon: section.value == 0
                    ? Icons.remove_circle_outline
                    : Icons.check_circle_outline,
                intent: section.value == 0
                    ? UiIntent.neutral
                    : UiIntent.success,
              ),
          ],
        ),
        if (data.quote.isNotEmpty ||
            availability.isNotEmpty ||
            chartMetadata.isNotEmpty ||
            snapshot.isNotEmpty) ...[
          UiGap.v(context.ui.spacing.md),
          UiCard(
            child: UiAccordion(
              items: [
                if (data.quote.isNotEmpty)
                  UiAccordionItem(
                    title: 'Quote fields',
                    content: MarketDataFields(data: data.quote),
                  ),
                if (availability.isNotEmpty)
                  UiAccordionItem(
                    title: 'Provider coverage',
                    content: MarketDataFields(data: availability),
                  ),
                if (chartMetadata.isNotEmpty)
                  UiAccordionItem(
                    title: 'History metadata',
                    content: MarketDataFields(data: chartMetadata),
                  ),
                if (snapshot.isNotEmpty)
                  UiAccordionItem(
                    title: 'Snapshot metadata',
                    content: MarketDataFields(data: snapshot),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
