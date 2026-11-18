import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// Both UI libraries are required for feature views.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';

import '../models/market_snapshot.dart';
import 'market_instrument_data.dart';
import 'market_instrument_events.dart';
import 'market_instrument_fundamentals.dart';
import 'market_instrument_options.dart';
import 'market_instrument_ownership.dart';
import 'market_instrument_price.dart';
import 'market_layout.dart';
import 'market_news_widgets.dart';

export 'market_instrument_data_fields.dart'
    show MarketDataFields, MarketDataRecords, marketFieldLabel;
export 'market_instrument_price.dart'
    show
        MarketHistoryRange,
        filterMarketHistoryCandles,
        marketHistoryRangeLabel;

enum _InstrumentSection {
  overview('Overview', Icons.dashboard_outlined),
  history('History', Icons.show_chart_outlined),
  options('Options', Icons.account_tree_outlined),
  actions('Dividends & splits', Icons.payments_outlined),
  analyst('Analysts', Icons.analytics_outlined),
  ownership('Ownership', Icons.people_outline),
  news('News', Icons.newspaper_outlined),
  sources('Data sources', Icons.storage_outlined);

  const _InstrumentSection(this.label, this.icon);
  final String label;
  final IconData icon;
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
  _InstrumentSection _section = _InstrumentSection.overview;
  UiPriceChartType _chartType = UiPriceChartType.candles;
  MarketHistoryRange _range = MarketHistoryRange.twoMonths;
  bool _appliedThemeDefaults = false;
  late Future<InstrumentRow> _detail = _load();

  Future<InstrumentRow> _load() =>
      widget.repository.detail(widget.instrument.symbol);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedThemeDefaults) return;
    final theme = AppThemeController.maybeOf(context);
    if (theme == null) return;
    _appliedThemeDefaults = true;
    _chartType = theme.preferredPriceChartType;
    _range = MarketHistoryRange.values.firstWhere(
      (range) => marketHistoryRangeLabel(range) == theme.chartRange,
      orElse: () => MarketHistoryRange.twoMonths,
    );
  }

  @override
  void didUpdateWidget(covariant MarketInstrumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.instrument.symbol != widget.instrument.symbol ||
        oldWidget.repository != widget.repository) {
      _section = _InstrumentSection.overview;
      _detail = _load();
    }
  }

  void _readArticle(MarketArticle article, MarketSnapshot snapshot) {
    final onArticle = widget.onArticle;
    if (onArticle != null) {
      onArticle(article);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Market News')),
          body: UiPage(
            child: MarketArticleView(
              article: article,
              snapshot: snapshot,
              onArticle: (next) => _readArticle(next, snapshot),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<InstrumentRow>(
    future: _detail,
    builder: (context, result) {
      if (result.connectionState != ConnectionState.done) {
        return UiSkeleton.market(tab: 3);
      }
      if (result.hasError || !result.hasData) {
        return UiEmptyState(
          icon: Icons.error_outline,
          title: 'Instrument details unavailable',
          message: 'Could not load detailed information for this instrument.',
          actionLabel: 'Retry',
          onActionPressed: () => setState(() => _detail = _load()),
        );
      }
      final data = InstrumentDetailData(widget.instrument, result.data!);
      final content = _sectionContent(data);
      return LayoutBuilder(
        builder: (context, constraints) {
          final theme = context.ui;
          final compact = constraints.maxWidth < 600;
          final inset = context.sp(
            compact ? theme.spacing.sm : theme.spacing.md,
          );
          final tabs = Padding(
            padding: EdgeInsets.fromLTRB(inset, inset, inset, 0),
            child: _InstrumentNavigation(
              section: _section,
              onChanged: (section) => setState(() => _section = section),
            ),
          );
          final body = Padding(
            padding: EdgeInsets.all(inset),
            child: KeyedSubtree(key: ValueKey(_section), child: content),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tabs,
              if (constraints.hasBoundedHeight)
                Expanded(
                  child: SingleChildScrollView(
                    key: PageStorageKey((data.instrument.symbol, _section)),
                    primary: false,
                    child: body,
                  ),
                )
              else
                body,
            ],
          );
        },
      );
    },
  );

  Widget _sectionContent(InstrumentDetailData data) {
    final chart = InstrumentPriceChart(
      data: data,
      range: _range,
      chartType: _chartType,
      onRangeChanged: (range) => setState(() => _range = range),
      onChartTypeChanged: (type) => setState(() => _chartType = type),
    );
    return switch (_section) {
      _InstrumentSection.overview => _InstrumentOverview(
        data: data,
        chart: chart,
      ),
      _InstrumentSection.history => Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            chart,
            if (data.candles.isNotEmpty) ...[
              UiGap.v(context.ui.spacing.md),
              InstrumentHistoryCards(data: data, range: _range),
            ],
          ],
        ),
      ),
      _InstrumentSection.options => InstrumentOptions(data: data),
      _InstrumentSection.actions => InstrumentCorporateActions(data: data),
      _InstrumentSection.analyst => InstrumentAnalystCards(data: data),
      _InstrumentSection.ownership => InstrumentOwnership(data: data),
      _InstrumentSection.news => _InstrumentNews(
        data: data,
        snapshot: widget.snapshot,
        onArticle: _readArticle,
      ),
      _InstrumentSection.sources => InstrumentDataSources(data: data),
    };
  }
}

class _InstrumentNavigation extends StatelessWidget {
  const _InstrumentNavigation({required this.section, required this.onChanged});
  final _InstrumentSection section;
  final ValueChanged<_InstrumentSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final scroll = ScrollConfiguration.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ScrollConfiguration(
        behavior: scroll.copyWith(
          dragDevices: {...scroll.dragDevices, PointerDeviceKind.mouse},
        ),
        child: UiToggleGroup<_InstrumentSection>(
          key: const ValueKey('instrument-section-toggle'),
          semanticLabel: 'Ticker section',
          value: section,
          options: [
            for (final item in _InstrumentSection.values)
              UiOption(value: item, label: item.label, icon: item.icon),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _InstrumentOverview extends StatelessWidget {
  const _InstrumentOverview({required this.data, required this.chart});
  final InstrumentDetailData data;
  final Widget chart;

  @override
  Widget build(BuildContext context) {
    final spacing = context.ui.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InstrumentQuoteCard(data: data),
        UiGap.v(spacing.md),
        MarketTwoPanel(
          primary: chart,
          secondary: InstrumentQuoteStats(data: data),
        ),
        UiGap.v(spacing.md),
        InstrumentFundamentals(data: data),
      ],
    );
  }
}

class _InstrumentNews extends StatelessWidget {
  const _InstrumentNews({
    required this.data,
    required this.snapshot,
    required this.onArticle,
  });

  final InstrumentDetailData data;
  final MarketSnapshot? snapshot;
  final void Function(MarketArticle, MarketSnapshot) onArticle;

  @override
  Widget build(BuildContext context) {
    final articles = instrumentRows(data.raw['news'])
        .where((row) => instrumentText(row['title']) != null)
        .map(MarketArticle.fromJson)
        .toList();
    if (articles.isEmpty) {
      return const UiCard(
        title: 'Company news',
        child: UiEmptyState(
          icon: Icons.newspaper_outlined,
          title: 'No company news in this snapshot',
        ),
      );
    }
    final market =
        snapshot ??
        MarketSnapshot(instruments: [data.instrument], articles: articles);
    return UiCardGrid(
      minTileWidth: context.sz(285),
      largeColumns: 3,
      children: [
        for (final article in articles)
          MarketNewsCard(
            article: article,
            snapshot: market,
            onTap: () => onArticle(article, market),
          ),
      ],
    );
  }
}
