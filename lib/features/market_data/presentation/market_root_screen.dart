import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_movers_panel.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart';

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
    'market_news',
    'market_movers',
    'market_instruments',
    'market_screeners',
  ];
  late final AssetMarketRepository _repo =
      widget.repository ?? AssetMarketRepository();
  late Future<MarketSnapshot> _future = _repo.snapshot();
  int _tab = 0, _newsLimit = 20, _instrumentLimit = 100;
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
      final filtered = MarketSnapshot(
        instruments: instruments,
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
        0 => MarketNewsView(
          snapshot: filtered,
          onArticle: _openArticle,
          limit: _newsLimit,
          onMore: () => setState(() => _newsLimit += 20),
        ),
        1 => UiCardGrid(
          intrinsicHeight: true,
          desktopColumns: 2,
          largeColumns: 2,
          children: [
            MarketMoversList(
              title: 'Top gainers',
              quotes: filtered.gainers,
              onTap: _openInstrument,
              limit: 50,
            ),
            MarketMoversList(
              title: 'Top losers',
              quotes: filtered.losers,
              onTap: _openInstrument,
              limit: 50,
            ),
          ],
        ),
        2 => Column(
          children: [
            for (final quote in instruments.take(_instrumentLimit)) ...[
              MarketQuoteRow(quote: quote, onTap: () => _openInstrument(quote)),
              const UiDivider(spacing: 0),
            ],
            if (instruments.length > _instrumentLimit)
              UiButton(
                label: 'More instruments',
                variant: UiVariant.outline,
                onPressed: () => setState(() => _instrumentLimit += 100),
              ),
          ],
        ),
        _ => UiCardGrid(
          intrinsicHeight: true,
          desktopColumns: 2,
          largeColumns: 2,
          children: [
            MarketMoversList(
              title: 'Trending tickers',
              quotes: filtered.trending,
              onTap: _openInstrument,
              limit: 50,
            ),
            MarketMoversList(
              title: 'Most active',
              quotes: filtered.mostActive,
              onTap: _openInstrument,
              limit: 50,
            ),
            MarketMoversList(
              title: 'Top gainers',
              quotes: filtered.gainers,
              onTap: _openInstrument,
              limit: 50,
            ),
            MarketMoversList(
              title: 'Top losers',
              quotes: filtered.losers,
              onTap: _openInstrument,
              limit: 50,
            ),
          ],
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
                  UiTabItem(label: 'News'),
                  UiTabItem(label: 'Movers'),
                  UiTabItem(label: 'Instruments'),
                  UiTabItem(label: 'Screeners'),
                ],
                index: _tab,
                scrollable: true,
                onChanged: (index) {
                  setState(() {
                    _tab = index;
                    _query = '';
                  });
                  widget.onNavigate?.call(_routes[index]);
                },
              ),
              UiGap.v(context.ui.spacing.sm),
              UiInput.search(
                value: _query,
                hintText: 'Search news, companies, symbols...',
                onChanged: (value) => setState(() => _query = value),
                onClear: () => setState(() => _query = ''),
              ),
              if (_tab == 0) ...[
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
              child: _instrument != null
                  ? MarketInstrumentView(
                      key: ValueKey(_instrument!.symbol),
                      instrument: _instrument!,
                      repository: _repo,
                      snapshot: snapshot,
                      onArticle: _openArticle,
                    )
                  : SingleChildScrollView(
                      child: _article != null
                          ? MarketArticleView(
                              article: _article!,
                              snapshot: snapshot,
                              onArticle: _openArticle,
                            )
                          : section(),
                    ),
            ),
          ],
        ),
      );
    },
  );
}
