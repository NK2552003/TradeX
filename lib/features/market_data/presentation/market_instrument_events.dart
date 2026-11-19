import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import 'market_instrument_data.dart';
import 'market_instrument_data_fields.dart';
import 'market_visuals.dart';

class InstrumentAnalystCards extends StatelessWidget {
  const InstrumentAnalystCards({super.key, required this.data});
  final InstrumentDetailData data;
  static const _ratings = [
    (
      key: 'strongBuy',
      alternate: 'strong_buy',
      label: 'Strong buy',
      intent: UiIntent.success,
    ),
    (key: 'buy', alternate: 'buy', label: 'Buy', intent: UiIntent.primary),
    (key: 'hold', alternate: 'hold', label: 'Hold', intent: UiIntent.neutral),
    (key: 'sell', alternate: 'sell', label: 'Sell', intent: UiIntent.warning),
    (
      key: 'strongSell',
      alternate: 'strong_sell',
      label: 'Strong sell',
      intent: UiIntent.danger,
    ),
  ];

  double _count(InstrumentRow row, int index) {
    final rating = _ratings[index];
    final count =
        instrumentNumber(row[rating.key] ?? row[rating.alternate]) ?? 0;
    return count > 0 ? count : 0;
  }

  String _label(InstrumentRow row) {
    final raw = instrumentText(row['period']);
    if (raw == null) return 'Reported period';
    final months = int.tryParse(raw.replaceFirst(RegExp(r'm$'), ''));
    if (raw.endsWith('m') && months != null) {
      return months == 0 ? 'Current' : '${months.abs()} mo ago';
    }
    return instrumentDate(raw);
  }

  int _newestFirst(InstrumentRow a, InstrumentRow b) {
    final left = instrumentText(a['period']) ?? '';
    final right = instrumentText(b['period']) ?? '';
    final leftMonths = int.tryParse(left.replaceFirst(RegExp(r'm$'), ''));
    final rightMonths = int.tryParse(right.replaceFirst(RegExp(r'm$'), ''));
    if (left.endsWith('m') &&
        right.endsWith('m') &&
        leftMonths != null &&
        rightMonths != null) {
      return leftMonths.abs().compareTo(rightMonths.abs());
    }
    return right.compareTo(left);
  }

  @override
  Widget build(BuildContext context) {
    final rows = data.recommendations.where((row) {
      return _ratings.asMap().keys.any((index) => _count(row, index) > 0);
    }).toList()..sort(_newestFirst);
    if (rows.isEmpty) {
      return const UiCard(
        title: 'Analyst recommendations',
        child: UiEmptyState(
          icon: Icons.analytics_outlined,
          title: 'No analyst ratings in this snapshot',
        ),
      );
    }
    final latest = rows.first;
    final counts = [
      for (var i = 0; i < _ratings.length; i++) _count(latest, i),
    ];
    final recent = rows.take(8).toList().reversed;
    final colors = [
      for (final rating in _ratings) rating.intent.color(context),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          title: 'Analyst consensus',
          subtitle:
              '${_label(latest)} · ${instrumentCount(counts.fold<double>(0, (sum, value) => sum + value))} ratings',
          leading: const Icon(Icons.analytics_outlined),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiCategoryBar(
                thickness: 15,
                showLegend: false,
                segments: [
                  for (var i = 0; i < counts.length; i++)
                    if (counts[i] > 0)
                      UiCategorySegment(
                        label: _ratings[i].label,
                        value: counts[i],
                        color: colors[i],
                      ),
                ],
              ),
              UiGap.v(context.ui.spacing.sm),
              UiStatStrip(
                minCellWidth: 106,
                stats: [
                  for (var i = 0; i < counts.length; i++)
                    UiStat(
                      label: _ratings[i].label,
                      value: instrumentCount(counts[i]),
                      intent: _ratings[i].intent,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (rows.length > 1) ...[
          UiGap.v(context.ui.spacing.md),
          UiCard(
            title: 'Ratings over time',
            subtitle: 'Counts by reporting period',
            child: UiBarChart(
              stacked: true,
              height: 230,
              series: [
                for (var i = 0; i < counts.length; i++)
                  UiChartSeries(name: _ratings[i].label, color: colors[i]),
              ],
              data: [
                for (final row in recent)
                  UiChartPoint(
                    label: _label(row),
                    values: [
                      for (var i = 0; i < counts.length; i++) _count(row, i),
                    ],
                  ),
              ],
            ),
          ),
        ],
        if (rows.length > 8) ...[
          UiGap.v(context.ui.spacing.md),
          UiCard(
            title: 'All reporting periods',
            child: UiTable<InstrumentRow>(
              rows: rows,
              stackOnMobile: true,
              pageSize: 8,
              columns: [
                UiTableColumn(header: 'Period', valueGetter: _label),
                for (var i = 0; i < _ratings.length; i++)
                  UiTableColumn(
                    header: _ratings[i].label,
                    numeric: true,
                    valueGetter: (row) => instrumentCount(_count(row, i)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class InstrumentCorporateActions extends StatelessWidget {
  const InstrumentCorporateActions({super.key, required this.data});
  final InstrumentDetailData data;

  @override
  Widget build(BuildContext context) {
    final dividends = instrumentRows(data.actions['dividends'])
      ..sort(
        (a, b) =>
            instrumentDate(a['date']).compareTo(instrumentDate(b['date'])),
      );
    final splits = instrumentRows(data.actions['splits']);
    final events = [
      for (final row in dividends)
        (
          date: instrumentDate(row['date'] ?? row['ex_date']),
          dividend: true,
          row: row,
        ),
      for (final row in splits)
        (
          date: instrumentDate(row['date'] ?? row['split_date']),
          dividend: false,
          row: row,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    if (events.isEmpty) {
      return const UiCard(
        title: 'Dividends & splits',
        child: UiEmptyState(
          icon: Icons.payments_outlined,
          title: 'No dividend or split data',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dividends.any(
          (row) => instrumentNumber(row['amount']) != null,
        )) ...[
          MarketDividendHistory(
            dividends: [
              for (final row in dividends)
                if (instrumentNumber(row['amount']) case final amount?)
                  {...row, 'amount': amount},
            ],
          ),
          UiGap.v(context.ui.spacing.md),
        ],
        UiCard(
          title: 'Corporate actions',
          leading: const Icon(Icons.event_note_outlined),
          child: UiTimeline(
            items: [
              for (final event in events.take(8))
                UiTimelineItem(
                  title: event.dividend ? 'Cash dividend' : 'Stock split',
                  subtitle: event.dividend
                      ? '${data.formatPrice(instrumentNumber(event.row['amount']))} per share'
                      : _splitRatio(event.row['ratio']),
                  timestamp: event.date,
                  icon: event.dividend
                      ? Icons.payments_outlined
                      : Icons.call_split_rounded,
                  intent: event.dividend ? UiIntent.success : UiIntent.info,
                ),
            ],
          ),
        ),
        if (events.length > 8) ...[
          UiGap.v(context.ui.spacing.md),
          UiCard(
            child: UiAccordion(
              items: [
                if (dividends.isNotEmpty)
                  UiAccordionItem(
                    title: 'All dividends',
                    content: MarketDataRecords(
                      rows: dividends.reversed.toList(),
                    ),
                  ),
                if (splits.isNotEmpty)
                  UiAccordionItem(
                    title: 'All stock splits',
                    content: MarketDataRecords(rows: splits),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _splitRatio(Object? value) {
    final number = instrumentNumber(value);
    if (number == null || number <= 0) {
      return instrumentText(value) ?? 'Ratio unavailable';
    }
    return number < 1
        ? '1:${uiCompactNumber(1 / number)}'
        : '${uiCompactNumber(number)}:1';
  }
}
