import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';
import 'market_layout.dart';
import 'market_visuals.dart';

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

enum MarketHistoryRange { day, week, twoWeeks, month, twoMonths }

String marketHistoryRangeLabel(MarketHistoryRange range) => switch (range) {
  MarketHistoryRange.day => '1D',
  MarketHistoryRange.week => '1W',
  MarketHistoryRange.twoWeeks => '2W',
  MarketHistoryRange.month => '1M',
  MarketHistoryRange.twoMonths => '2M',
};

/// Slices chronologically sorted candles to match the 2-month CI/CD window
/// (`1D`, `1W`, `2W`, `1M`, `2M`).
List<UiCandle> filterMarketHistoryCandles(
  List<UiCandle> candles,
  MarketHistoryRange range,
) {
  if (candles.isEmpty) return const <UiCandle>[];
  final sorted = List<UiCandle>.from(candles)
    ..sort((a, b) => a.time.compareTo(b.time));
  final DateTime latest = sorted.last.time;
  final DateTime latestDay = DateTime(latest.year, latest.month, latest.day);
  final DateTime cutoff = switch (range) {
    MarketHistoryRange.day => latestDay,
    MarketHistoryRange.week => latestDay.subtract(const Duration(days: 6)),
    MarketHistoryRange.twoWeeks => latestDay.subtract(const Duration(days: 13)),
    MarketHistoryRange.month => latestDay.subtract(const Duration(days: 29)),
    MarketHistoryRange.twoMonths => latestDay.subtract(const Duration(days: 59)),
  };
  final filtered = sorted.where((c) {
    final day = DateTime(c.time.year, c.time.month, c.time.day);
    return !day.isBefore(cutoff);
  }).toList();
  return filtered.isNotEmpty ? filtered : <UiCandle>[sorted.last];
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
  MarketHistoryRange _historyRange = MarketHistoryRange.twoMonths;
  bool _appliedThemeDefaults = false;
  late final Future<Map<String, dynamic>> _future = widget.repository.detail(
    widget.instrument.symbol,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedThemeDefaults) return;
    final themeCtrl = AppThemeController.maybeOf(context);
    if (themeCtrl == null) return;
    _appliedThemeDefaults = true;
    _historyRange = switch (themeCtrl.chartRange) {
      '1D' => MarketHistoryRange.day,
      '1W' => MarketHistoryRange.week,
      '1M' => MarketHistoryRange.month,
      '1Y' || 'ALL' => MarketHistoryRange.twoMonths,
      _ => MarketHistoryRange.twoMonths,
    };
    _chartMode = switch (themeCtrl.preferredPriceChartType) {
      UiPriceChartType.candles => 0,
      UiPriceChartType.hollow => 1,
      UiPriceChartType.line => 2,
      UiPriceChartType.area => 3,
    };
  }

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
        return const UiEmptyState(
          icon: Icons.error_outline,
          title: 'Instrument details unavailable',
          message: 'Could not load detailed information for this instrument.',
        );
      }
      if (!snapshot.hasData) {
        return UiSkeleton.market(tab: 3);
      }
      final detail = snapshot.data!;
      final summary = detail['summary'] as Map? ?? {};
      final chart = detail['chart'] as Map? ?? {};
      final options = detail['options'] as Map? ?? {};
      final actions = detail['dividends_and_splits'] as Map? ?? {};
      final holders = detail['holders'] as Map? ?? {};
      final sections = <UiAccordionItem>[
        UiAccordionItem(
          title: 'Quote & fundamentals',
          leading: const Icon(Icons.show_chart_outlined),
          initiallyOpen: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if ('${summary['description'] ?? ''}'.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
                  decoration: BoxDecoration(
                    color: context.ui.colors.foreground.withValues(alpha: 0.03),
                    borderRadius: context.radius(context.ui.radii.md),
                    border: Border.all(
                      color: context.ui.colors.border,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${summary['description'] ?? ''}',
                    style: context.uiText.body.copyWith(height: 1.5),
                  ),
                ),
                UiGap.v(context.ui.spacing.md),
              ],
              Text('Current quote', style: context.uiText.bodyStrong),
              UiGap.v(context.ui.spacing.sm),
              MarketDataFields(data: detail['quote'] as Map? ?? {}),
              UiGap.v(context.ui.spacing.md),
              const UiDivider(),
              UiGap.v(context.ui.spacing.sm),
              Text('Fundamentals', style: context.uiText.bodyStrong),
              UiGap.v(context.ui.spacing.sm),
              MarketDataFields(data: Map.from(summary)..remove('description')),
            ],
          ),
        ),
        UiAccordionItem(
          title: 'Company news',
          leading: const Icon(Icons.newspaper_outlined),
          content: Column(
            children: [
              if ((detail['news'] as List? ?? []).isEmpty)
                const UiEmptyState(
                  icon: Icons.newspaper_outlined,
                  title: 'No company news in this snapshot',
                )
              else
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
                      return Column(
                        children: [
                          MarketNewsCard(
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
                          ),
                          const UiDivider(),
                        ],
                      );
                    },
                  ),
            ],
          ),
        ),
        UiAccordionItem(
          title: 'Price history',
          leading: const Icon(Icons.history),
          content: MarketDataRecords(rows: chart['data'] as List? ?? []),
        ),
        UiAccordionItem(
          title: 'Options chains',
          leading: const Icon(Icons.account_tree_outlined),
          content: Column(
            children: [
              if ((options['chains'] as Map? ?? {}).isNotEmpty) ...[
                MarketOptionsInterest(chains: options['chains'] as Map),
                UiGap.v(context.ui.spacing.md),
              ],
              if ((options['chains'] as Map? ?? {}).isEmpty)
                const UiEmptyState(
                  icon: Icons.account_tree_outlined,
                  title: 'No options available',
                )
              else
                UiAccordion(
                  items: [
                    for (final expiry
                        in (options['chains'] as Map? ?? {}).entries)
                      UiAccordionItem(
                        title: '${expiry.key}',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final side
                                in (expiry.value as Map).entries) ...[
                              Text(
                                marketFieldLabel('${side.key}'),
                                style: context.uiText.bodyStrong,
                              ),
                              UiGap.v(context.ui.spacing.sm),
                              MarketDataRecords(
                                rows: side.value as List? ?? [],
                              ),
                              UiGap.v(context.ui.spacing.md),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        UiAccordionItem(
          title: 'Dividends & splits',
          leading: const Icon(Icons.payments_outlined),
          content: Column(
            children: [
              if ((actions['dividends'] as List? ?? []).isNotEmpty) ...[
                MarketDividendHistory(dividends: actions['dividends'] as List),
                UiGap.v(context.ui.spacing.md),
              ],
              if (actions.isEmpty)
                const UiEmptyState(
                  icon: Icons.payments_outlined,
                  title: 'No dividend or split data',
                )
              else
                for (final item in actions.entries) ...[
                  Text(
                    marketFieldLabel('${item.key}'),
                    style: context.uiText.bodyStrong,
                  ),
                  MarketDataRecords(rows: item.value as List? ?? []),
                  const UiDivider(),
                ],
            ],
          ),
        ),
        UiAccordionItem(
          title: 'Analyst recommendations',
          leading: const Icon(Icons.analytics_outlined),
          content: MarketDataRecords(
            rows: detail['recommendations'] as List? ?? [],
          ),
        ),
        UiAccordionItem(
          title: 'Ownership & holders',
          leading: const Icon(Icons.people_outline),
          content: Column(
            children: [
              if ((holders['institutional_holders'] as List? ?? [])
                  .isNotEmpty) ...[
                MarketInstitutionalHolders(
                  holders: holders['institutional_holders'] as List,
                ),
                UiGap.v(context.ui.spacing.md),
              ],
              if (holders.isEmpty)
                const UiEmptyState(
                  icon: Icons.people_outline,
                  title: 'No ownership data',
                )
              else
                for (final item in holders.entries) ...[
                  Text(
                    marketFieldLabel('${item.key}'),
                    style: context.uiText.bodyStrong,
                  ),
                  MarketDataRecords(rows: item.value as List? ?? []),
                  const UiDivider(),
                ],
            ],
          ),
        ),
        UiAccordionItem(
          title: 'Snapshot & availability',
          leading: const Icon(Icons.info_outline),
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
      final List<UiCandle> allCandles =
          (chart['data'] as List? ?? const <dynamic>[]).isNotEmpty
          ? (assetCandles(chart['data'] as List)
              ..sort((a, b) => a.time.compareTo(b.time)))
          : <UiCandle>[];
      final List<UiCandle> candles = filterMarketHistoryCandles(
        allCandles,
        _historyRange,
      );
      final bool hasChart = allCandles.isNotEmpty;
      final UiCandle? latest = hasChart ? allCandles.last : null;
      final double price = inst.price != 0 ? inst.price : (latest?.close ?? 0);
      final UiIntent plIntent = AppTokens.plIntent(inst.changePercent);
      String px(double? v) => v == null || !v.isFinite
          ? 'Quote unavailable'
          : '${inst.currency} ${v.toStringAsFixed(2)}';
      final List<UiStat> stats = <UiStat>[
        if (latest != null) UiStat(label: 'Open', value: px(latest.open)),
        if (latest != null) UiStat(label: 'High', value: px(latest.high)),
        if (latest != null) UiStat(label: 'Low', value: px(latest.low)),
        if (inst.previousClose != null)
          UiStat(label: 'Prev close', value: px(inst.previousClose)),
        if (latest != null)
          UiStat(label: 'Volume', value: AppTokens.count(latest.volume)),
      ];
      return MarketTwoPanel(
        secondaryFirstOnMobile: true,
        primary: UiCard(
          accentColor: plIntent.color(context),
          child: LayoutBuilder(
            builder: (context, box) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chart Controls Header
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: context.sp(context.ui.spacing.sm),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.show_chart,
                              size: context.sz(16),
                              color: context.ui.colors.foregroundMuted,
                            ),
                            UiGap.h(context.ui.spacing.xs),
                            Text(
                              'Price history',
                              style: context.uiText.subheading,
                            ),
                          ],
                        ),
                        if (hasChart)
                          Text(
                            '${candles.length} ${candles.length == 1 ? 'data point' : 'data points'} · ${marketHistoryRangeLabel(_historyRange)}',
                            style: context.uiText.caption.copyWith(
                              color: context.ui.colors.foregroundMuted,
                            ),
                          ),
                      ],
                    ),
                    if (hasChart)
                      Wrap(
                        spacing: context.sp(context.ui.spacing.sm),
                        runSpacing: context.sp(context.ui.spacing.xs),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          UiToggleGroup<MarketHistoryRange>(
                            key: const ValueKey<String>(
                              'market-history-range-toggle',
                            ),
                            value: _historyRange,
                            size: UiSize.sm,
                            onChanged: (value) =>
                                setState(() => _historyRange = value),
                            options: [
                              for (final range in MarketHistoryRange.values)
                                UiOption(
                                  label: marketHistoryRangeLabel(range),
                                  value: range,
                                ),
                            ],
                          ),
                          UiToggleGroup<int>(
                            value: _chartMode,
                            size: UiSize.sm,
                            onChanged: (value) =>
                                setState(() => _chartMode = value),
                            options: const [
                              UiOption(
                                label: 'Candles',
                                value: 0,
                                icon: Icons.candlestick_chart,
                              ),
                              UiOption(
                                label: 'Bars',
                                value: 1,
                                icon: Icons.candlestick_chart_outlined,
                              ),
                              UiOption(
                                label: 'Line',
                                value: 2,
                                icon: Icons.show_chart,
                              ),
                              UiOption(
                                label: 'Area',
                                value: 3,
                                icon: Icons.area_chart_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
                UiGap.v(context.ui.spacing.md),

                // Chart Display
                if (!hasChart)
                  const UiEmptyState(
                    icon: Icons.show_chart,
                    title: 'No price history in this snapshot',
                    message:
                        'Historical price data is not available for this instrument.',
                  )
                else if (_chartMode == 0 || _chartMode == 1)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: box.maxWidth < 600 ? context.sz(16) : 0,
                    ),
                    child: UiCandleChart(
                      candles: candles,
                      type: _chartMode == 1
                          ? UiPriceChartType.hollow
                          : UiPriceChartType.candles,
                      height: box.maxWidth < 600 ? 240 : 360,
                    ),
                  )
                else
                  UiAreaChart(
                    height: box.maxWidth < 600 ? 240 : 360,
                    showLegend: false,
                    fillOpacity: _chartMode == 2 ? 0.0 : null,
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
                        fillOpacity: _chartMode == 2 ? 0.0 : null,
                      ),
                    ],
                  ),
                UiGap.v(context.ui.spacing.lg),

                // Research Sections
                const UiDivider(),
                UiGap.v(context.ui.spacing.md),
                if (box.maxWidth < 600)
                  UiAccordion(allowMultiple: true, items: sections)
                else ...[
                  UiTabs(
                    items: [
                      for (final section in sections)
                        UiTabItem(
                          label: section.title,
                          icon: (section.leading as Icon?)?.icon,
                        ),
                    ],
                    index: _section,
                    scrollable: true,
                    onChanged: (value) => setState(() => _section = value),
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
        secondary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quote Snapshot Card
            UiCard(
              accentColor: plIntent.color(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UiBadge(
                        label: 'Snapshot Quote',
                        icon: Icons.circle,
                        intent: UiIntent.success,
                        variant: UiBadgeVariant.soft,
                        size: UiSize.xs,
                      ),
                      const Spacer(),
                      if (inst.market.isNotEmpty)
                        UiBadge(
                          label: inst.market,
                          variant: UiBadgeVariant.outline,
                          size: UiSize.xs,
                        ),
                    ],
                  ),
                  UiGap.v(context.ui.spacing.md),
                  Text(inst.symbol, style: context.uiText.display),
                  if (inst.name.trim().isNotEmpty &&
                      inst.name.trim().toUpperCase() !=
                          inst.symbol.trim().toUpperCase()) ...[
                    UiGap.v(context.ui.spacing.xxs),
                    Text(
                      inst.name,
                      style: context.uiText.body.copyWith(
                        color: context.ui.colors.foregroundMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  UiGap.v(context.ui.spacing.md),
                  Wrap(
                    spacing: context.sp(context.ui.spacing.sm),
                    runSpacing: context.sp(context.ui.spacing.xs),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(px(price), style: context.uiText.heading),
                      if (inst.price.isFinite)
                        UiBadge(
                          label: AppTokens.signedPercent(inst.changePercent),
                          intent: plIntent,
                          icon: AppTokens.plIcon(inst.changePercent),
                        ),
                    ],
                  ),
                  UiGap.v(context.ui.spacing.sm),
                  Text(
                    () {
                      final raw =
                          '${detail['quote']?['updated_at'] ?? inst.updatedAt?.toIso8601String() ?? ''}'
                              .trim();
                      final parsed = DateTime.tryParse(raw)?.toUtc();
                      if (parsed != null) {
                        final y = parsed.year.toString().padLeft(4, '0');
                        final m = parsed.month.toString().padLeft(2, '0');
                        final d = parsed.day.toString().padLeft(2, '0');
                        final hh = parsed.hour.toString().padLeft(2, '0');
                        final mm = parsed.minute.toString().padLeft(2, '0');
                        return 'Updated: $y-$m-$d · $hh:$mm UTC';
                      }
                      return 'Updated: ${raw.isEmpty ? 'Unavailable' : raw}';
                    }(),
                    style: context.uiText.caption.copyWith(
                      color: context.ui.colors.foregroundMuted,
                    ),
                  ),
                  if (stats.isNotEmpty) ...[
                    const UiDivider(),
                    UiStatStrip(stats: stats),
                  ],
                ],
              ),
            ),
            UiGap.v(context.ui.spacing.md),

            MarketFundamentalVisuals(instrument: inst, detail: detail),
            UiGap.v(context.ui.spacing.md),

            // About Company
            if ('${summary['description'] ?? ''}'.isNotEmpty)
              UiCard(
                title: 'About',
                leading: const Icon(Icons.business_outlined),
                child: Text(
                  '${summary['description']}',
                  style: context.uiText.body.copyWith(
                    height: 1.5,
                    color: context.ui.colors.foregroundMuted,
                  ),
                ),
              ),
            UiGap.v(context.ui.spacing.md),

            // Research Sections Summary
            UiCard(
              title: 'Research sections',
              leading: const Icon(Icons.auto_awesome_outlined),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var idx = 0; idx < sections.length; idx++) ...[
                    if (idx > 0) UiGap.v(context.ui.spacing.xxs),
                    UiButton(
                      label: sections[idx].title,
                      leadingIcon: (sections[idx].leading as Icon?)?.icon,
                      trailingIcon: Icons.chevron_right_rounded,
                      alignment: Alignment.centerLeft,
                      expand: true,
                      selected: _section == idx,
                      variant: _section == idx
                          ? UiVariant.soft
                          : UiVariant.ghost,
                      onPressed: () => setState(() => _section = idx),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
