import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';
import 'market_layout.dart';

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
  int _chartMode = 0;
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
      final MarketInstrument inst = widget.instrument;
      final List<UiCandle> candles =
          (chart['data'] as List? ?? const <dynamic>[]).isNotEmpty
          ? assetCandles(chart['data'] as List)
          : <UiCandle>[];
      final bool hasChart = candles.isNotEmpty;
      final UiCandle? latest = hasChart ? candles.last : null;
      final double price = inst.price != 0 ? inst.price : (latest?.close ?? 0);
      final UiIntent plIntent = AppTokens.plIntent(inst.changePercent);
      String px(double? v) =>
          v == null ? '—' : '${inst.currency} ${v.toStringAsFixed(2)}';
      final List<UiStat> stats = <UiStat>[
        if (latest != null) UiStat(label: 'Open', value: px(latest.open)),
        if (latest != null) UiStat(label: 'High', value: px(latest.high)),
        if (latest != null) UiStat(label: 'Low', value: px(latest.low)),
        if (inst.previousClose != null)
          UiStat(label: 'Prev close', value: px(inst.previousClose)),
        if (latest != null)
          UiStat(label: 'Volume', value: AppTokens.count(latest.volume)),
      ];
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MarketPageHeading(
              title: '${summary['name'] ?? inst.name}',
              description: '${inst.symbol} · Instrument research',
              action: UiBadge(
                label: detail['data_source'] == 'mock'
                    ? 'Sample data'
                    : 'Market snapshot',
                variant: UiBadgeVariant.outline,
              ),
            ),
            MarketTwoPanel(
              secondaryFirstOnMobile: true,
              primary: UiCard(
                title: 'Price & research',
                child: LayoutBuilder(
                  builder: (context, box) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: context.sp(context.ui.spacing.md),
                        runSpacing: context.sp(context.ui.spacing.sm),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Price history',
                            style: context.uiText.subheading,
                          ),
                          if (hasChart)
                            UiToggleGroup<int>(
                              value: _chartMode,
                              onChanged: (value) =>
                                  setState(() => _chartMode = value),
                              options: const [
                                UiOption(label: 'Candles', value: 0),
                                UiOption(label: 'Line', value: 1),
                              ],
                            ),
                        ],
                      ),
                      UiGap.v(context.ui.spacing.md),
                      if (!hasChart)
                        const UiEmptyState(
                          title: 'No price history in this snapshot',
                        )
                      else if (_chartMode == 0)
                        UiCandleChart(
                          candles: candles,
                          height: box.maxWidth < 600 ? 220 : 340,
                        )
                      else
                        UiAreaChart(
                          height: box.maxWidth < 600 ? 220 : 340,
                          showLegend: false,
                          data: [
                            for (final candle in candles)
                              UiChartPoint(
                                label:
                                    '${candle.time.year}-${candle.time.month}-${candle.time.day}',
                                values: [candle.close],
                              ),
                          ],
                          series: [
                            UiChartSeries(
                              name: 'Close',
                              type: UiChartSeriesType.area,
                              color: plIntent.color(context),
                            ),
                          ],
                        ),
                      UiGap.v(context.ui.spacing.lg),
                      if (box.maxWidth < 600)
                        UiAccordion(allowMultiple: true, items: sections)
                      else ...[
                        UiTabs(
                          items: [
                            for (final section in sections)
                              UiTabItem(label: section.title),
                          ],
                          index: _section,
                          scrollable: true,
                          onChanged: (value) =>
                              setState(() => _section = value),
                        ),
                        UiGap.v(context.ui.spacing.md),
                        Text(
                          sections[_section].title,
                          style: context.uiText.subheading,
                        ),
                        UiGap.v(context.ui.spacing.md),
                        sections[_section].content,
                      ],
                    ],
                  ),
                ),
              ),
              secondary: UiCard(
                title: 'Quote snapshot',
                subtitle: inst.symbol,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(px(price), style: context.uiText.title),
                    UiGap.v(context.ui.spacing.sm),
                    Wrap(
                      spacing: context.sp(context.ui.spacing.sm),
                      children: [
                        UiBadge(
                          label: AppTokens.signedPercent(inst.changePercent),
                          intent: plIntent,
                          icon: AppTokens.plIcon(inst.changePercent),
                        ),
                        if (inst.market.isNotEmpty)
                          UiBadge(
                            label: inst.market,
                            variant: UiBadgeVariant.outline,
                          ),
                      ],
                    ),
                    UiGap.v(context.ui.spacing.md),
                    Text(
                      'Quote updated: ${detail['quote']?['updated_at'] ?? inst.updatedAt?.toIso8601String() ?? 'Unavailable'}',
                      style: context.uiText.caption,
                    ),
                    if (stats.isNotEmpty) ...[
                      const UiDivider(),
                      UiStatStrip(stats: stats),
                    ],
                    if ('${summary['description'] ?? ''}'.isNotEmpty) ...[
                      const UiDivider(),
                      UiCard(
                        title: 'About the company',
                        collapsible: true,
                        initiallyExpanded: false,
                        variant: UiCardVariant.ghost,
                        padding: EdgeInsets.zero,
                        child: Text(
                          '${summary['description']}',
                          style: context.uiText.body,
                        ),
                      ),
                    ],
                    const UiDivider(),
                    Text('Research sections', style: context.uiText.bodyStrong),
                    UiGap.v(context.ui.spacing.sm),
                    Text(
                      'Fundamentals · Company news · Price history · Options · Dividends · Analysts · Ownership · Data availability',
                      style: context.uiText.caption,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
