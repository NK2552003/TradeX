import 'package:tradex/core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/messages/presentation/overlays/share_to_conversation_dialog.dart';
import 'market_screeners_view.dart';
import 'market_catalogue_view.dart';
import 'market_overview_view.dart';
import 'market_coverage_view.dart';
import 'yahoo_market_ribbon.dart';

class MarketRootScreen extends StatefulWidget {
  const MarketRootScreen({
    super.key,
    this.repository,
    this.destination = 'market',
    this.onNavigate,
    this.onSubpageChanged,
    this.openRequest,
    this.searchQuery = '',
  });
  final AssetMarketRepository? repository;
  final String destination;
  final ValueChanged<String>? onNavigate;
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;
  final AppLinkOpenRequest? openRequest;
  final String searchQuery;
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
  bool _newsExhausted = false;
  int _newsTotal = 0;
  String _topic = 'all';
  MarketArticle? _article;
  MarketInstrument? _instrument;
  final Set<String> _likedArticles = {};
  final List<(MarketArticle?, MarketInstrument?)> _history = [];
  @override
  void initState() {
    super.initState();
    _restoreLikes();
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

  Future<void> _loadMoreNews(MarketSnapshot snapshot) async {
    if (_loadingMore) return;
    _loadingMore = true;
    try {
      if (_repo.usesDatabase &&
          !_newsExhausted &&
          _newsLimit >= snapshot.articles.length) {
        final more = await _repo.loadMoreNews(
          offset: snapshot.articles.length,
          limit: 20,
        );
        if (more.isEmpty) {
          _newsExhausted = true;
        } else {
          final seen = snapshot.articles
              .map((a) => a.link.isEmpty ? a.title : a.link)
              .toSet();
          for (final a in more) {
            final key = a.link.isEmpty ? a.title : a.link;
            if (seen.add(key)) {
              snapshot.articles.add(a);
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _newsLimit += 20;
        });
      }
    } finally {
      _loadingMore = false;
    }
  }

  bool _loadOnScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical ||
        notification.metrics.extentAfter > 500 ||
        _loadingMore ||
        _article != null ||
        _instrument != null ||
        _tab != 1 ||
        (_newsLimit >= _newsTotal && (!_repo.usesDatabase || _newsExhausted))) {
      return false;
    }
    _loadingMore = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadingMore = false;
      if (!mounted) return;
      _future.then((snap) {
        if (mounted) _loadMoreNews(snap);
      });
    });
    return false;
  }

  void _changeTab(int index) {
    setState(() {
      _tab = index;
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

  String get _likesKey =>
      'market_intelligence_likes:${SupabaseConfig.client?.auth.currentUser?.id ?? 'guest'}';

  Future<void> _restoreLikes() async {
    try {
      final saved =
          (await SharedPreferences.getInstance()).getStringList(_likesKey) ??
          const <String>[];
      if (mounted) setState(() => _likedArticles.addAll(saved));
    } catch (_) {
      // The in-memory likes remain usable when local storage is unavailable.
    }
  }

  void _toggleLike(MarketArticle article) {
    setState(() {
      final key = article.link.isEmpty ? article.title : article.link;
      if (!_likedArticles.add(key)) _likedArticles.remove(key);
    });
    _saveLikes();
  }

  Future<void> _saveLikes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_likesKey, _likedArticles.toList());
    } catch (_) {
      // The visible selection still works for this session.
    }
  }

  bool _isLiked(MarketArticle article) => _likedArticles.contains(
    article.link.isEmpty ? article.title : article.link,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<MarketSnapshot>(
    future: _future,
    builder: (context, result) {
      if (result.hasError) {
        return UiEmptyState(
          title: 'Market assets unavailable',
          message: 'Unable to load market data snapshot',
          actionLabel: 'Try again',
          onActionPressed: () =>
              setState(() => _future = _repo.snapshot(refresh: true)),
        );
      }
      if (!result.hasData) {
        return UiSkeleton.market(tab: _tab);
      }
      final snapshot = result.data!;
      final dossier =
          _instrument ??
          _history.reversed
              .map((entry) => entry.$2)
              .whereType<MarketInstrument>()
              .firstOrNull;
      final query = widget.searchQuery.trim().toLowerCase();
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
          snapshot: query.isEmpty ? snapshot : filtered,
          onInstrument: _openInstrument,
          onArticle: _openArticle,
          onSection: _changeTab,
        ),
        1 => MarketNewsView(
          snapshot: filtered,
          onArticle: _openArticle,
          onInstrument: _openInstrument,
          isLiked: _isLiked,
          onLike: _toggleLike,
          onTopicSelected: (t) async {
            setState(() {
              _topic = t;
              _newsLimit = 20;
            });
            if (t != 'all') {
              final loaded = await _repo.loadTopic(t);
              if (mounted && loaded.isNotEmpty) {
                setState(() {
                  snapshot.topics[t] = loaded;
                });
              }
            }
          },
          selectedTopic: _topic,
          limit: _newsLimit,
          pageSize: 10,
          onMore: () => _loadMoreNews(snapshot),
        ),
        2 => MarketMoversView(
          snapshot: filtered,
          onInstrument: _openInstrument,
        ),
        3 => MarketCatalogueView(
          quotes: instruments,
          onInstrument: _openInstrument,
          repository: _repo,
          searchQuery: widget.searchQuery,
          totalCount: (snapshot.manifest['quote_count'] as num?)?.toInt(),
        ),
        5 => MarketCoverageView(
          snapshot: snapshot,
          repository: _repo,
        onInstrument: _openInstrument,
          searchQuery: widget.searchQuery,
        ),
        _ => MarketScreenersView(
          snapshot: filtered,
          onInstrument: _openInstrument,
          repository: _repo,
        ),
      };
      return Padding(
        padding: EdgeInsets.fromLTRB(
          context.sp(context.ui.spacing.md),
          context.sp(context.ui.spacing.sm),
          context.sp(context.ui.spacing.md),
          context.sp(context.ui.spacing.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_article == null && _instrument == null) ...[
              if (_tab == 0) ...[
                UiCard(
                  variant: UiCardVariant.surface,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(context.ui.spacing.md),
                    vertical: context.sp(context.ui.spacing.sm),
                  ),
                  child: LayoutBuilder(
                    builder: (context, headerBox) => Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            context.sp(context.ui.spacing.xs),
                          ),
                          decoration: BoxDecoration(
                            color: context.ui.colors.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: context.radius(context.ui.radii.sm),
                          ),
                          child: Icon(
                            Icons.insights,
                            size: context.sz(20),
                            color: context.ui.colors.primary,
                          ),
                        ),
                        UiGap.h(context.ui.spacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Market Intelligence',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.uiText.title.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  UiGap.h(context.ui.spacing.xs),
                                  UiBadge(
                                    label: snapshot.manifest['data_source'] ==
                                            'supabase_live'
                                        ? 'LIVE DATABASE'
                                        : 'SNAPSHOT',
                                    variant: UiBadgeVariant.soft,
                                    intent: snapshot.manifest['data_source'] ==
                                            'supabase_live'
                                        ? UiIntent.success
                                        : UiIntent.primary,
                                    size: UiSize.xs,
                                  ),
                                ],
                              ),
                              UiGap.v(context.ui.spacing.xxs),
                              Text(
                                snapshot.manifest['data_source'] ==
                                        'supabase_live'
                                    ? 'Live Database · ${snapshot.instruments.length} Quotes & Analytics'
                                    : 'Snapshot ${marketSnapshotDate(snapshot.manifest)} · Analytics & Research',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.uiText.caption.copyWith(
                                  color: context.ui.colors.foregroundMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (headerBox.maxWidth >= 550) ...[
                          Text(
                            'Analytics only · Not investment advice',
                            style: context.uiText.caption.copyWith(
                              color: context.ui.colors.foregroundSubtle,
                              fontSize: context.fs(11),
                            ),
                          ),
                          UiGap.h(context.ui.spacing.sm),
                        ],
                        UiIconButton(
                          icon: Icons.refresh,
                          tooltip: 'Reload market assets',
                          intent: UiIntent.neutral,
                          onPressed: () => setState(
                            () => _future = _repo.snapshot(refresh: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                UiGap.v(context.ui.spacing.sm),
              ],

              // Real-Time Yahoo Finance Analytics Ribbon across all market sections
              YahooMarketRibbon(
                instruments: snapshot.instruments,
                onSelectInstrument: _openInstrument,
              ),
              UiGap.v(context.ui.spacing.sm),
              if (!(context.uiRes.isDesktop && widget.onNavigate != null)) ...[
                UiTabs(
                  items: const [
                    UiTabItem(
                      label: 'Overview',
                      icon: Icons.dashboard_outlined,
                    ),
                    UiTabItem(label: 'News', icon: Icons.newspaper_outlined),
                    UiTabItem(
                      label: 'Movers',
                      icon: Icons.trending_up_outlined,
                    ),
                    UiTabItem(
                      label: 'Instruments',
                      icon: Icons.show_chart_outlined,
                    ),
                    UiTabItem(
                      label: 'Screeners',
                      icon: Icons.filter_alt_outlined,
                    ),
                    UiTabItem(label: 'Coverage', icon: Icons.dataset_outlined),
                  ],
                  index: _tab,
                  scrollable: true,
                  onChanged: _changeTab,
                ),
                UiGap.v(context.ui.spacing.sm),
              ],
              if (_tab == 1 && !context.uiRes.isDesktop) ...[
                UiSelect<String>(
                  value: _topic,
                  options: [
                    const UiOption(label: 'All topics', value: 'all'),
                    for (final topic in snapshot.topics.keys)
                      UiOption(label: topicDisplayLabel(topic), value: topic),
                  ],
                  onChanged: (value) async {
                    setState(() {
                      _topic = value;
                      _newsLimit = 20;
                    });
                    if (value != 'all') {
                      final loaded = await _repo.loadTopic(value);
                      if (mounted && loaded.isNotEmpty) {
                        setState(() {
                          snapshot.topics[value] = loaded;
                        });
                      }
                    }
                  },
                ),
                UiGap.v(context.ui.spacing.sm),
              ],
            ] else if (widget.onSubpageChanged == null) ...[
              UiCard(
                variant: UiCardVariant.ghost,
                borderless: true,
                padding: EdgeInsets.symmetric(
                  vertical: context.sp(context.ui.spacing.sm),
                  horizontal: context.sp(context.ui.spacing.md),
                ),
                child: Row(
                  children: [
                    UiButton(
                      label: 'Back',
                      leadingIcon: Icons.arrow_back,
                      variant: UiVariant.ghost,
                      size: UiSize.sm,
                      onPressed: _back,
                    ),
                    UiGap.h(context.ui.spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _instrument?.symbol ??
                                _article?.title ??
                                'Detail view',
                            style: context.uiText.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_instrument != null)
                            Text(
                              _instrument!.name,
                              style: context.uiText.caption.copyWith(
                                color: context.ui.colors.foregroundMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (_history.isNotEmpty)
                      UiBadge(
                        label: '${_history.length + 1}',
                        variant: UiBadgeVariant.outline,
                      ),
                    if (_instrument != null) ...[
                      UiGap.h(context.ui.spacing.xs),
                      UiIconButton(
                        icon: Icons.ios_share_rounded,
                        size: UiSize.sm,
                        tooltip: 'Share ${_instrument!.symbol}',
                        onPressed: () {
                          final inst = _instrument!;
                          ShareToConversationDialog.showShareMenu(
                            context,
                            reference: AppLinkRef(
                              id: inst.symbol,
                              kind: AppLinkKind.ticker,
                              title: '${inst.symbol} — ${inst.name}',
                              subtitle:
                                  'Live quotes, charts & fundamentals on alphajournal Markets',
                              icon: Icons.candlestick_chart_outlined,
                              isPublicContext: true,
                            ),
                            isPublic: true,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              UiGap.v(context.ui.spacing.sm),
            ],
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
                        child: section(),
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
                    MarketArticleView(
                      article: _article!,
                      snapshot: snapshot,
                      onArticle: _openArticle,
                      onInstrument: _openInstrument,
                      isLiked: _isLiked(_article!),
                      onLike: () => _toggleLike(_article!),
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
