import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';

String marketFieldLabel(String key) {
  final value = key
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ');
  return value.isEmpty
      ? value
      : '${value[0].toUpperCase()}${value.substring(1)}';
}

class MarketDataFields extends StatelessWidget {
  const MarketDataFields({super.key, required this.data});
  final Map data;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final nested = data.entries
          .where((e) => e.value is Map || e.value is List)
          .toList();
      if (data.isEmpty) {
        return const UiEmptyState(title: 'No data in this snapshot');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: context.sp(context.ui.spacing.md),
            runSpacing: context.sp(context.ui.spacing.sm),
            children: [
              for (final entry in data.entries.where(
                (e) => e.value is! Map && e.value is! List,
              ))
                SizedBox(
                  width: constraints.maxWidth.clamp(0, context.sz(220)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marketFieldLabel('${entry.key}'),
                        style: context.uiText.caption.copyWith(
                          color: context.ui.colors.foregroundMuted,
                        ),
                      ),
                      Text('${entry.value ?? '—'}', style: context.uiText.body),
                    ],
                  ),
                ),
            ],
          ),
          if (nested.isNotEmpty)
            UiAccordion(
              allowMultiple: true,
              items: [
                for (final entry in nested)
                  UiAccordionItem(
                    title: marketFieldLabel('${entry.key}'),
                    content: entry.value is Map
                        ? MarketDataFields(data: entry.value as Map)
                        : MarketDataRecords(rows: entry.value as List),
                  ),
              ],
            ),
        ],
      );
    },
  );
}

class MarketDataRecords extends StatelessWidget {
  const MarketDataRecords({super.key, required this.rows});
  final List rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const UiEmptyState(title: 'No data in this snapshot');
    }
    final records = rows.map((r) => r is Map ? r : {'value': r}).toList();
    final keys = <String>{
      for (final row in records)
        for (final key in row.keys)
          if (row[key] is! Map && row[key] is! List) '$key',
    }.take(5).toList();
    return UiTable<Map>(
      rows: records,
      pageSize: 10,
      stackOnMobile: true,
      expandableWhen: (_) => true,
      expandedBuilder: (c, row) => MarketDataFields(data: row),
      columns: [
        for (final key in keys)
          UiTableColumn(
            header: marketFieldLabel(key),
            cell: (c, row) => Text(
              '${row[key] ?? '—'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class MarketInstrumentView extends StatefulWidget {
  const MarketInstrumentView({
    super.key,
    required this.instrument,
    required this.repository,
    this.snapshot,
    this.onArticle,
  });
  final MarketInstrument instrument;
  final AssetMarketRepository repository;
  final MarketSnapshot? snapshot;
  final ValueChanged<MarketArticle>? onArticle;
  @override
  State<MarketInstrumentView> createState() => _MarketInstrumentViewState();
}

class _MarketInstrumentViewState extends State<MarketInstrumentView> {
  int _section = 0;
  late final Future<Map<String, dynamic>> _future = widget.repository.detail(
    widget.instrument.symbol,
  );
  void _readArticle(MarketArticle article, MarketSnapshot market) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Market News')),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
              child: MarketArticleView(
                article: article,
                snapshot: market,
                onArticle: (next) => _readArticle(next, market),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const UiEmptyState(title: 'Instrument details unavailable');
      }
      if (!snapshot.hasData) return const UiSkeleton(height: 200);
      final detail = snapshot.data!;
      final summary = detail['summary'] as Map? ?? {};
      final chart = detail['chart'] as Map? ?? {};
      final options = detail['options'] as Map? ?? {};
      final actions = detail['dividends_and_splits'] as Map? ?? {};
      final holders = detail['holders'] as Map? ?? {};
      final sections = <UiAccordionItem>[
        UiAccordionItem(
          title: 'Quote & fundamentals',
          initiallyOpen: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${summary['description'] ?? ''}',
                style: context.uiText.body,
              ),
              UiGap.v(context.ui.spacing.md),
              MarketDataFields(data: detail['quote'] as Map? ?? {}),
              UiGap.v(context.ui.spacing.md),
              MarketDataFields(data: Map.from(summary)..remove('description')),
            ],
          ),
        ),
        UiAccordionItem(
          title: 'Company news',
          content: Column(
            children: [
              for (final raw in (detail['news'] as List? ?? []))
                Builder(
                  builder: (context) {
                    final article = MarketArticle.fromJson(
                      Map<String, dynamic>.from(raw as Map),
                    );
                    final market =
                        widget.snapshot ??
                        MarketSnapshot(
                          instruments: [widget.instrument],
                          articles: [article],
                        );
                    return MarketNewsCard(
                      article: article,
                      snapshot: market,
                      row: true,
                      onTap: () {
                        if (widget.onArticle != null) {
                          widget.onArticle!(article);
                        } else {
                          _readArticle(article, market);
                        }
                      },
                    );
                  },
                ),
              if ((detail['news'] as List? ?? []).isEmpty)
                const UiEmptyState(title: 'No company news in this snapshot'),
            ],
          ),
        ),
        UiAccordionItem(
          title: 'Price history',
          content: MarketDataRecords(rows: chart['data'] as List? ?? []),
        ),
        UiAccordionItem(
          title: 'Options chains',
          content: Column(
            children: [
              if ((options['chains'] as Map? ?? {}).isEmpty)
                const UiEmptyState(title: 'No options available'),
              for (final expiry
                  in (options['chains'] as Map? ?? {}).entries) ...[
                Text('${expiry.key}', style: context.uiText.bodyStrong),
                for (final side in (expiry.value as Map).entries) ...[
                  Text(
                    marketFieldLabel('${side.key}'),
                    style: context.uiText.bodyStrong,
                  ),
                  MarketDataRecords(rows: side.value as List? ?? []),
                ],
              ],
            ],
          ),
        ),
        UiAccordionItem(
          title: 'Dividends & splits',
          content: Column(
            children: [
              for (final item in actions.entries) ...[
                Text(
                  marketFieldLabel('${item.key}'),
                  style: context.uiText.bodyStrong,
                ),
                MarketDataRecords(rows: item.value as List? ?? []),
              ],
            ],
          ),
        ),
        UiAccordionItem(
          title: 'Analyst recommendations',
          content: MarketDataRecords(
            rows: detail['recommendations'] as List? ?? [],
          ),
        ),
        UiAccordionItem(
          title: 'Ownership & holders',
          content: Column(
            children: [
              for (final item in holders.entries) ...[
                Text(
                  marketFieldLabel('${item.key}'),
                  style: context.uiText.bodyStrong,
                ),
                MarketDataRecords(rows: item.value as List? ?? []),
              ],
            ],
          ),
        ),
        UiAccordionItem(
          title: 'Snapshot & availability',
          content: MarketDataFields(
            data: {
              'chart_metadata': {
                for (final entry in chart.entries)
                  if (entry.key != 'data') entry.key: entry.value,
              },
              for (final entry in detail.entries)
                if (![
                  'summary',
                  'quote',
                  'chart',
                  'options',
                  'news',
                  'holders',
                  'recommendations',
                  'dividends_and_splits',
                ].contains(entry.key))
                  entry.key: entry.value,
            },
          ),
        ),
      ];
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${summary['name'] ?? widget.instrument.name}',
              style: context.uiText.heading,
            ),
            UiGap.v(context.ui.spacing.sm),
            Wrap(
              spacing: context.sp(context.ui.spacing.sm),
              runSpacing: context.sp(context.ui.spacing.xs),
              children: [
                UiBadge(label: widget.instrument.symbol),
                UiBadge(label: widget.instrument.currency),
                UiBadge(
                  label: detail['data_source'] == 'mock'
                      ? 'Sample data'
                      : 'Market snapshot',
                ),
              ],
            ),
            UiGap.v(context.ui.spacing.sm),
            Text(
              'Quote updated: ${detail['quote']?['updated_at'] ?? widget.instrument.updatedAt?.toIso8601String() ?? 'Unavailable'}',
              style: context.uiText.caption,
            ),
            UiGap.v(context.ui.spacing.md),
            Text(
              '${summary['description'] ?? ''}',
              style: context.uiText.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            UiGap.v(context.ui.spacing.md),
            if ((chart['data'] as List? ?? []).isNotEmpty)
              UiCard(
                child: UiCandleChart(
                  candles: assetCandles(chart['data'] as List),
                  height: context.uiRes.isMobile ? 220 : 340,
                ),
              ),
            UiGap.v(context.ui.spacing.md),
            if (context.uiRes.isMobile)
              UiAccordion(allowMultiple: true, items: sections)
            else ...[
              UiTabs(
                items: [
                  for (final section in sections)
                    UiTabItem(label: section.title),
                ],
                index: _section,
                scrollable: true,
                onChanged: (i) => setState(() => _section = i),
              ),
              UiGap.v(context.ui.spacing.md),
              UiCard(
                title: sections[_section].title,
                child: sections[_section].content,
              ),
            ],
          ],
        ),
      );
    },
  );
}
