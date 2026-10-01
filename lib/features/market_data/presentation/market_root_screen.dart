import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_movers_panel.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart';
import 'market_screeners_view.dart';
import 'market_overview_view.dart';
import 'market_coverage_view.dart';

class MarketRootScreen extends StatefulWidget {
  const MarketRootScreen({
    super.key,
    this.repository,
    this.destination = 'market',
    this.onNavigate,
    this.onSubpageChanged,
  });
  final AssetMarketRepository? repository;
  final String destination;
  final ValueChanged<String>? onNavigate;
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;
  @override
  State<MarketRootScreen> createState() => _MarketRootScreenState();
}

class _MarketRootScreenState extends State<MarketRootScreen> {
  static const _routes = [
    'market_overview',
    'market_news',
    'market_movers',
    'market_instruments',
    'market_screeners',
    'market_coverage',
  ];
  late final AssetMarketRepository _repo =
      widget.repository ?? AssetMarketRepository.shared;
  late Future<MarketSnapshot> _future = _repo.snapshot();
  int _tab = 0, _newsLimit = 20, _instrumentLimit = 100;
  bool _loadingMore = false;
  int _newsTotal = 0, _instrumentTotal = 0;
  String _query = '', _topic = 'all';
  MarketArticle? _article;
  MarketInstrument? _instrument;
  final List<(MarketArticle?, MarketInstrument?)> _history = [];
  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    _tab = _routes.contains(widget.destination)
        ? _routes.indexOf(widget.destination)
        : 0;
  }

  @override
  void didUpdateWidget(covariant MarketRootScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination) {
      _sync();
      _history.clear();
      _article = null;
      _instrument = null;
      widget.onSubpageChanged?.call(null, null, null);
    }
  }

  bool _loadOnScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.extentAfter > 500 ||
        _loadingMore ||
        _article != null ||
        _instrument != null ||
        (_tab != 1 && _tab != 3) ||
        (_tab == 1 && _newsLimit >= _newsTotal) ||
        (_tab == 3 && _instrumentLimit >= _instrumentTotal)) {
      return false;
    }
    _loadingMore = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadingMore = false;
      if (mounted) {
        setState(() {
          if (_tab == 1) {
            _newsLimit += 20;
          } else if (_tab == 3) {
            _instrumentLimit += 100;
          }
        });
      }
    });
    return false;
  }

  void _changeTab(int index) {
    setState(() {
      _tab = index;
      _query = '';
    });
    widget.onNavigate?.call(_routes[index]);
  }

  void _back() {
    setState(() {
      final previous = _history.isEmpty ? (null, null) : _history.removeLast();
      _article = previous.$1;
      _instrument = previous.$2;
    });
    widget.onSubpageChanged?.call(
      _article?.title ?? _instrument?.symbol,
      _article != null
          ? Icons.newspaper
          : (_instrument != null ? Icons.show_chart : null),
      _article != null || _instrument != null ? _back : null,
    );
  }

  void _openArticle(MarketArticle article) {
    setState(() {
      _history.add((_article, _instrument));
      _article = article;
      _instrument = null;
    });
    widget.onSubpageChanged?.call(article.title, Icons.newspaper, _back);
  }

  void _openInstrument(MarketInstrument quote) {
    setState(() {
      _history.add((_article, _instrument));
      _instrument = quote;
      _article = null;
    });
    widget.onSubpageChanged?.call(quote.symbol, Icons.show_chart, _back);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MarketSnapshot>(
    future: _future,
    builder: (context, result) {
      if (result.hasError) {
        return UiEmptyState(
          title: 'Market assets unavailable',
          actionLabel: 'Try again',
          onActionPressed: () =>
              setState(() => _future = _repo.snapshot(refresh: true)),
        );
      }
      if (!result.hasData) return const Center(child: UiSkeleton(height: 200));
      final snapshot = result.data!;
      final dossier =
          _instrument ??
          _history.reversed
              .map((entry) => entry.$2)
              .whereType<MarketInstrument>()
              .firstOrNull;
      final query = _query.trim().toLowerCase();
      final instruments = snapshot.instruments
          .where(
            (q) =>
                query.isEmpty ||
                '${q.symbol} ${q.name}'.toLowerCase().contains(query),
          )
          .toList();
      final articles =
          (_topic == 'all' ? snapshot.articles : snapshot.topics[_topic] ?? [])
              .where(
                (a) =>
                    query.isEmpty ||
                    '${a.title} ${a.summary} ${a.tickers.join(' ')}'
                        .toLowerCase()
                        .contains(query),
              )
              .toList();
      _newsTotal = articles.length;
      _instrumentTotal = instruments.length;
      final filtered = MarketSnapshot(
        manifest: snapshot.manifest,
        screenerPayloads: snapshot.screenerPayloads,
        instruments: instruments,
        screeners: {
          for (final entry in snapshot.screeners.entries)
            entry.key: entry.value
                .where(
                  (q) =>
                      query.isEmpty ||
                      '${q.symbol} ${q.name}'.toLowerCase().contains(query),
                )
                .toList(),
        },
        articles: articles,
        topics: {
          for (final topic in snapshot.topics.entries)
            topic.key: topic.value
                .where(
                  (a) =>
                      query.isEmpty ||
                      '${a.title} ${a.summary} ${a.tickers.join(' ')}'
                          .toLowerCase()
                          .contains(query),
                )
                .toList(),
        },
      );
      Widget section() => switch (_tab) {
        0 => MarketOverviewView(
          snapshot: snapshot,
          onInstrument: _openInstrument,
          onArticle: _openArticle,
          onSection: _changeTab,
        ),
        1 => MarketNewsView(
          snapshot: filtered,
          onArticle: _openArticle,
          limit: _newsLimit,
          onMore: () => setState(() => _newsLimit += 20),
        ),
        2 => UiCardGrid(
          intrinsicHeight: true,
          desktopColumns: 2,
          largeColumns: 2,
          children: [
            MarketMoversList(
              title: 'Top gainers',
              quotes: filtered.gainers,
              onTap: _openInstrument,
              limit: 100,
            ),
            MarketMoversList(
              title: 'Top losers',
              quotes: filtered.losers,
              onTap: _openInstrument,
              limit: 100,
            ),
          ],
        ),
        3 =>
          context.uiRes.isMobile
              ? Column(
                  children: [
                    for (final quote in instruments.take(_instrumentLimit)) ...[
                      UiDeferred(
                        key: ValueKey(quote.symbol),
                        estimatedHeight: 80,
                        builder: (_) => MarketQuoteRow(
                          quote: quote,
                          onTap: () => _openInstrument(quote),
                        ),
                      ),
                      const UiDivider(spacing: 0),
                    ],
                    if (instruments.length > _instrumentLimit)
                      UiButton(
                        label: 'More instruments',
                        variant: UiVariant.outline,
                        onPressed: () =>
                            setState(() => _instrumentLimit += 100),
                      ),
                  ],
                )
              : UiTable<MarketInstrument>(
                  rows: instruments,
                  pageSize: 30,
                  onRowTap: _openInstrument,
                  columns: [
                    UiTableColumn(
                      header: 'Symbol',
                      cell: (c, q) =>
                          Text(q.symbol, style: c.uiText.bodyStrong),
                      compare: (a, b) => a.symbol.compareTo(b.symbol),
                    ),
                    UiTableColumn(
                      header: 'Company',
                      flex: 2,
                      cell: (c, q) => Text(q.name),
                      compare: (a, b) => a.name.compareTo(b.name),
                    ),
                    UiTableColumn(
                      header: 'Market',
                      cell: (c, q) => Text(q.market),
                    ),
                    UiTableColumn(
                      header: 'Price',
                      numeric: true,
                      cell: (c, q) =>
                          Text('${q.currency} ${q.price.toStringAsFixed(2)}'),
                      compare: (a, b) => a.price.compareTo(b.price),
                    ),
                    UiTableColumn(
                      header: 'Change %',
                      numeric: true,
                      cell: (c, q) =>
                          Text('${q.changePercent.toStringAsFixed(2)}%'),
                      compare: (a, b) =>
                          a.changePercent.compareTo(b.changePercent),
                    ),
                  ],
                ),
        5 => MarketCoverageView(
          snapshot: snapshot,
          repository: _repo,
          onInstrument: _openInstrument,
        ),
        _ => MarketScreenersView(
          snapshot: filtered,
          onInstrument: _openInstrument,
        ),
      };
      return Padding(
        padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_article == null && _instrument == null) ...[
              UiTabs(
                items: const [
                  UiTabItem(label: 'Overview'),
                  UiTabItem(label: 'News'),
                  UiTabItem(label: 'Movers'),
                  UiTabItem(label: 'Instruments'),
                  UiTabItem(label: 'Screeners'),
                  UiTabItem(label: 'Data coverage'),
                ],
                index: _tab,
                scrollable: true,
                onChanged: _changeTab,
              ),
              UiGap.v(context.ui.spacing.sm),
              if (_tab != 0 && _tab != 5)
                UiInput.search(
                  value: _query,
                  hintText: 'Search news, companies, symbols...',
                  onChanged: (value) => setState(() => _query = value),
                  onClear: () => setState(() => _query = ''),
                ),
              if (_tab == 1) ...[
                UiGap.v(context.ui.spacing.xs),
                UiSelect<String>(
                  value: _topic,
                  options: [
                    const UiOption(label: 'All topics', value: 'all'),
                    for (final topic in snapshot.topics.keys)
                      UiOption(label: marketFieldLabel(topic), value: topic),
                  ],
                  onChanged: (value) => setState(() {
                    _topic = value;
                    _newsLimit = 20;
                  }),
                ),
              ],
              UiGap.v(context.ui.spacing.md),
            ] else if (widget.onSubpageChanged == null)
              Align(
                alignment: Alignment.centerLeft,
                child: UiButton(
                  label: 'Back',
                  leadingIcon: Icons.arrow_back,
                  variant: UiVariant.ghost,
                  onPressed: _back,
                ),
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Offstage(
                    offstage: _instrument != null || _article != null,
                    child: TickerMode(
                      enabled: _instrument == null && _article == null,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _loadOnScroll,
                        child: SingleChildScrollView(
                          key: PageStorageKey('market-section-$_tab'),
                          child: section(),
                        ),
                      ),
                    ),
                  ),
                  if (dossier != null)
                    Offstage(
                      offstage: _instrument == null,
                      child: MarketInstrumentView(
                        key: ValueKey(dossier.symbol),
                        instrument: dossier,
                        repository: _repo,
                        snapshot: snapshot,
                        onArticle: _openArticle,
                      ),
                    ),
                  if (_article != null)
                    SingleChildScrollView(
                      child: MarketArticleView(
                        article: _article!,
                        snapshot: snapshot,
                        onArticle: _openArticle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
