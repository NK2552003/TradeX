import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'market_screeners_view.dart';
import 'market_catalogue_view.dart';
import 'market_layout.dart';
import 'market_overview_view.dart';
import 'market_coverage_view.dart';

class MarketRootScreen extends StatefulWidget {
  const MarketRootScreen({
    super.key,
    this.repository,
    this.destination = 'market',
    this.onNavigate,
    this.onSubpageChanged,
    this.openRequest,
  });
  final AssetMarketRepository? repository;
  final String destination;
  final ValueChanged<String>? onNavigate;
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;
  final AppLinkOpenRequest? openRequest;
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
  int _tab = 0, _newsLimit = 20;
  bool _loadingMore = false;
  int _newsTotal = 0;
  String _query = '', _topic = 'all';
  MarketArticle? _article;
  MarketInstrument? _instrument;
  final List<(MarketArticle?, MarketInstrument?)> _history = [];
  @override
  void initState() {
    super.initState();
    _sync();
    if (widget.openRequest != null) {
      _applyRequest(widget.openRequest!);
    }
  }

  void _sync() {
    _tab = _routes.contains(widget.destination)
        ? _routes.indexOf(widget.destination)
        : 0;
  }

  void _applyRequest(AppLinkOpenRequest request) {
    if (request.kind != AppLinkKind.ticker) return;
    final String symbol = request.id.toUpperCase();
    _future.then((MarketSnapshot snapshot) {
      if (!mounted) return;
      MarketInstrument? found = snapshot.instruments
          .where((i) => i.symbol.toUpperCase() == symbol)
          .firstOrNull;
      found ??= MarketInstrument.fromJson(
        <String, dynamic>{'ticker': symbol, 'price': 0.0, 'change_pct': 0.0},
        <String, dynamic>{'name': symbol},
      );
      _openInstrument(found);
    });
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
    if (widget.openRequest != null &&
        widget.openRequest != oldWidget.openRequest) {
      _applyRequest(widget.openRequest!);
    }
  }

  bool _loadOnScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.extentAfter > 500 ||
        _loadingMore ||
        _article != null ||
        _instrument != null ||
        _tab != 1 ||
        _newsLimit >= _newsTotal) {
      return false;
    }
    _loadingMore = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadingMore = false;
      if (mounted) {
        setState(() {
          if (_tab == 1) _newsLimit += 20;
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
          onInstrument: _openInstrument,
          onTopicSelected: (t) => setState(() {
            _topic = t;
            _newsLimit = 20;
          }),
          limit: _newsLimit,
          onMore: () => setState(() => _newsLimit += 20),
        ),
        2 => MarketMoversView(
          snapshot: filtered,
          onInstrument: _openInstrument,
        ),
        3 => MarketCatalogueView(
          quotes: instruments,
          onInstrument: _openInstrument,
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
        child: UiCard(
          hoverLift: false,
          padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
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
                if (_tab == 1)
                  LayoutBuilder(
                    builder: (context, box) {
                      final searchField = UiInput.search(
                        value: _query,
                        hintText: 'Search news, companies, symbols...',
                        onChanged: (value) => setState(() => _query = value),
                        onClear: () => setState(() => _query = ''),
                      );
                      final topicSelect = UiSelect<String>(
                        value: _topic,
                        options: [
                          const UiOption(label: 'All topics', value: 'all'),
                          for (final topic in snapshot.topics.keys)
                            UiOption(
                              label: topicDisplayLabel(topic),
                              value: topic,
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _topic = value;
                          _newsLimit = 20;
                        }),
                      );
                      if (box.maxWidth >= 600) {
                        return Row(
                          children: [
                            Expanded(child: searchField),
                            UiGap.h(context.ui.spacing.sm),
                            SizedBox(width: 220, child: topicSelect),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          searchField,
                          UiGap.v(context.ui.spacing.xs),
                          topicSelect,
                        ],
                      );
                    },
                  )
                else if (_tab != 0 && _tab != 5)
                  UiInput.search(
                    value: _query,
                    hintText: 'Search news, companies, symbols...',
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () => setState(() => _query = ''),
                  ),
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
                            child: MarketTwoPanel.pane(section()),
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
                          onInstrument: _openInstrument,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
