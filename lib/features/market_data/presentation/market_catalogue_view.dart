import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../data/asset_market_repository.dart';
import '../models/market_snapshot.dart';
import 'market_movers_panel.dart';
import 'market_layout.dart';
import 'market_visuals.dart';

class MarketQuoteResults extends StatefulWidget {
  const MarketQuoteResults({
    super.key,
    required this.quotes,
    required this.onInstrument,
    this.mobilePageSize = 20,
    this.showMobileSort = true,
  });
  final List<MarketInstrument> quotes;
  final ValueChanged<MarketInstrument> onInstrument;
  final int mobilePageSize;
  final bool showMobileSort;
  @override
  State<MarketQuoteResults> createState() => _MarketQuoteResultsState();
}

class _MarketQuoteResultsState extends State<MarketQuoteResults> {
  int _page = 0;
  String _sort = 'default';

  @override
  void didUpdateWidget(covariant MarketQuoteResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quotes.length != widget.quotes.length ||
        oldWidget.quotes.firstOrNull?.symbol !=
            widget.quotes.firstOrNull?.symbol) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (widget.quotes.isEmpty) {
        return const UiEmptyState(
          icon: Icons.search_off,
          title: 'No matching instruments',
          message: 'Try another company or symbol.',
        );
      }
      if (box.maxWidth < 600) {
        final quotes = [...widget.quotes];
        if (_sort == 'symbol') {
          quotes.sort((a, b) => a.symbol.compareTo(b.symbol));
        }
        if (_sort == 'change') {
          quotes.sort((a, b) => b.changePercent.compareTo(a.changePercent));
        }
        final count = (quotes.length / widget.mobilePageSize).ceil();
        final page = _page.clamp(0, count - 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showMobileSort) ...[
              UiSelect<String>(
                value: _sort,
                options: const [
                  UiOption(label: 'Default order', value: 'default'),
                  UiOption(label: 'Symbol A–Z', value: 'symbol'),
                  UiOption(label: 'Highest change', value: 'change'),
                ],
                onChanged: (value) => setState(() {
                  _sort = value;
                  _page = 0;
                }),
              ),
              UiGap.v(context.ui.spacing.sm),
            ],
            for (final quote
                in quotes
                    .skip(page * widget.mobilePageSize)
                    .take(widget.mobilePageSize)) ...[
              MarketQuoteRow(
                quote: quote,
                onTap: () => widget.onInstrument(quote),
              ),
              const UiDivider(spacing: 0),
            ],
            if (count > 1)
              UiPagination(
                page: page,
                pageCount: count,
                onPageChanged: (value) => setState(() => _page = value),
              ),
          ],
        );
      }
      return UiTable<MarketInstrument>(
        rows: widget.quotes,
        pageSize: 30,
        density: UiDensity.compact,
        onRowTap: widget.onInstrument,
        columns: [
          UiTableColumn(
            header: 'Instrument',
            flex: 3,
            cell: (c, q) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.symbol, style: c.uiText.bodyStrong),
                Text(
                  q.name,
                  style: c.uiText.caption.copyWith(
                    color: c.ui.colors.foregroundMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            compare: (a, b) => a.symbol.compareTo(b.symbol),
          ),
          UiTableColumn(
            header: 'Market',
            cell: (c, q) => q.market.isNotEmpty
                ? UiBadge(
                    label: q.market,
                    variant: UiBadgeVariant.outline,
                    size: UiSize.xs,
                  )
                : const SizedBox.shrink(),
            compare: (a, b) => a.market.compareTo(b.market),
          ),
          UiTableColumn(
            header: 'Price',
            numeric: true,
            flex: 2,
            cell: (c, q) => Text(
              '${q.currency} ${q.price.toStringAsFixed(2)}',
              style: c.uiText.bodyStrong,
            ),
            compare: (a, b) => a.price.compareTo(b.price),
          ),
          UiTableColumn(
            header: 'Change %',
            numeric: true,
            flex: 2,
            cell: (c, q) => UiBadge(
              label: AppTokens.signedPercent(q.changePercent),
              intent: AppTokens.plIntent(q.changePercent),
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
            ),
            compare: (a, b) => a.changePercent.compareTo(b.changePercent),
          ),
          if (box.maxWidth >= 800)
            UiTableColumn(
              header: 'Volume',
              numeric: true,
              cell: (c, q) =>
                  Text(AppTokens.count(q.volume), style: c.uiText.body),
              compare: (a, b) => a.volume.compareTo(b.volume),
            ),
          if (box.maxWidth >= 1000)
            UiTableColumn(
              header: 'Trend',
              numeric: false,
              cell: (c, q) => q.spark.isNotEmpty
                  ? SizedBox(
                      width: c.sz(64),
                      height: c.sz(24),
                      child: UiSparkChart(
                        data: q.spark,
                        color: AppTokens.plIntent(q.changePercent).color(c),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      );
    },
  );
}

class MarketCatalogueView extends StatefulWidget {
  const MarketCatalogueView({
    super.key,
    required this.quotes,
    required this.onInstrument,
    this.repository,
    this.searchQuery = '',
    this.totalCount,
  });
  final List<MarketInstrument> quotes;
  final ValueChanged<MarketInstrument> onInstrument;
  final AssetMarketRepository? repository;
  final String searchQuery;
  final int? totalCount;

  @override
  State<MarketCatalogueView> createState() => _MarketCatalogueViewState();
}

class _MarketCatalogueViewState extends State<MarketCatalogueView> {
  int _page = 0;
  String _sort = 'rank';
  Future<MarketPageResult<MarketInstrument>>? _pageFuture;

  bool get _isLazyDatabase => widget.repository?.usesDatabase ?? false;

  @override
  void initState() {
    super.initState();
    if (_isLazyDatabase) {
      _loadPage();
    }
  }

  @override
  void didUpdateWidget(covariant MarketCatalogueView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isLazyDatabase &&
        (oldWidget.searchQuery != widget.searchQuery ||
            oldWidget.repository != widget.repository)) {
      _page = 0;
      _loadPage();
    }
  }

  void _loadPage() {
    _pageFuture = widget.repository!.loadInstrumentsPage(
      page: _page,
      pageSize: 30,
      query: widget.searchQuery,
      sort: _sort,
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<MarketInstrument> visibleQuotes, {
    int? totalItems,
    bool loading = false,
  }) {
    final markets = <String, int>{};
    for (final q in visibleQuotes) {
      final label = q.market.isEmpty ? 'Unspecified' : q.market;
      markets.update(label, (n) => n + 1, ifAbsent: () => 1);
    }
    final advancing = visibleQuotes.where((q) => q.changePercent > 0).length;
    final declining = visibleQuotes.where((q) => q.changePercent < 0).length;
    final displayTotal = totalItems ?? widget.totalCount ?? visibleQuotes.length;
    final pageCount = ((totalItems ?? 0) / 30).ceil();

    return MarketTwoPanel(
      primary: UiCard(
        accentColor: context.ui.colors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
                  decoration: BoxDecoration(
                    color: context.ui.colors.primary.withValues(alpha: 0.12),
                    borderRadius: context.radius(context.ui.radii.md),
                  ),
                  child: Icon(
                    Icons.format_list_bulleted,
                    color: context.ui.colors.primary,
                    size: context.sz(20),
                  ),
                ),
                UiGap.h(context.ui.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Instruments', style: context.uiText.title),
                      Text(
                        '$displayTotal quotes · ${markets.length} market${markets.length == 1 ? '' : 's'}',
                        style: context.uiText.caption.copyWith(
                          color: context.ui.colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                UiBadge(
                  label: '$displayTotal',
                  variant: UiBadgeVariant.soft,
                  intent: UiIntent.primary,
                ),
              ],
            ),
            UiGap.v(context.ui.spacing.md),
            UiStatStrip(
              stats: [
                UiStat(
                  label: 'Advancing',
                  value: '$advancing',
                  intent: UiIntent.success,
                ),
                UiStat(
                  label: 'Declining',
                  value: '$declining',
                  intent: UiIntent.danger,
                ),
                UiStat(label: 'Markets', value: '${markets.length}'),
              ],
            ),
            if (_isLazyDatabase) ...[
              UiGap.v(context.ui.spacing.sm),
              UiSelect<String>(
                value: _sort,
                options: const [
                  UiOption(label: 'Rank (Market Cap)', value: 'rank'),
                  UiOption(label: 'Symbol A–Z', value: 'symbol'),
                  UiOption(label: 'Top Gainers', value: 'change'),
                  UiOption(label: 'Most Active', value: 'volume'),
                ],
                onChanged: (value) {
                  setState(() {
                    _sort = value;
                    _page = 0;
                    _loadPage();
                  });
                },
              ),
            ],
            const UiDivider(),
            if (loading)
              UiSkeleton.table(rows: 8, columns: 4)
            else ...[
              MarketQuoteResults(
                quotes: visibleQuotes,
                onInstrument: widget.onInstrument,
                mobilePageSize: _isLazyDatabase ? 30 : 20,
                showMobileSort: !_isLazyDatabase,
              ),
              if (_isLazyDatabase && pageCount > 1) ...[
                UiGap.v(context.ui.spacing.sm),
                UiPagination(
                  page: _page.clamp(0, pageCount - 1),
                  pageCount: pageCount,
                  onPageChanged: (next) {
                    setState(() {
                      _page = next;
                      _loadPage();
                    });
                  },
                ),
              ],
            ],
          ],
        ),
      ),
      secondary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MarketChangeDistribution(instruments: visibleQuotes),
          UiGap.v(context.ui.spacing.md),
          // Market Composition Donut
          UiCard(
            title: 'Market composition',
            subtitle: 'Instruments by market type',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (markets.isNotEmpty)
                  UiDonutChart(
                    size: 180,
                    centerLabel: '${visibleQuotes.length}',
                    slices: [
                      for (final market in markets.entries)
                        UiDonutSlice(
                          label: market.key,
                          value: market.value.toDouble(),
                        ),
                    ],
                  ),
                UiGap.v(context.ui.spacing.md),
                UiBarList(
                  items: [
                    for (final market in markets.entries)
                      UiBarListItem(
                        label: market.key,
                        value: market.value.toDouble(),
                        percentage:
                            market.value /
                            (markets.values.reduce((a, b) => a > b ? a : b) +
                                1),
                      ),
                  ],
                ),
              ],
            ),
          ),
          UiGap.v(context.ui.spacing.md),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLazyDatabase) {
      return _buildContent(context, widget.quotes);
    }
    return FutureBuilder<MarketPageResult<MarketInstrument>>(
      future: _pageFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return UiEmptyState(
            title: 'Could not load instruments',
            actionLabel: 'Retry',
            onActionPressed: () => setState(_loadPage),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return _buildContent(context, const [], loading: true);
        }
        final result = snap.data!;
        return _buildContent(
          context,
          result.items,
          totalItems: result.totalCount,
        );
      },
    );
  }
}

class MarketMoversView extends StatelessWidget {
  const MarketMoversView({
    super.key,
    required this.snapshot,
    required this.onInstrument,
  });
  final MarketSnapshot snapshot;
  final ValueChanged<MarketInstrument> onInstrument;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Strip
        UiCard(
          variant: UiCardVariant.surface,
          padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
          child: UiStatStrip(
            stats: [
              UiStat(
                label: 'Top gainers',
                value: '${snapshot.gainers.length}',
                intent: UiIntent.success,
              ),
              UiStat(
                label: 'Top losers',
                value: '${snapshot.losers.length}',
                intent: UiIntent.danger,
              ),
              UiStat(
                label: 'Best gain',
                value: snapshot.gainers.isNotEmpty
                    ? '+${snapshot.gainers.first.changePercent.toStringAsFixed(2)}%'
                    : '—',
                intent: UiIntent.success,
              ),
              UiStat(
                label: 'Worst loss',
                value: snapshot.losers.isNotEmpty
                    ? '${snapshot.losers.first.changePercent.toStringAsFixed(2)}%'
                    : '—',
                intent: UiIntent.danger,
              ),
            ],
          ),
        ),
        UiGap.v(context.ui.spacing.md),

        // Gainers and Losers side by side
        Expanded(
          child: MarketTwoPanel(
            equal: true,
            primary: UiCard(
              accentColor: context.ui.colors.success,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(
                          context.sp(context.ui.spacing.sm),
                        ),
                        decoration: BoxDecoration(
                          color: context.ui.colors.success.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: context.radius(context.ui.radii.md),
                        ),
                        child: Icon(
                          Icons.trending_up,
                          color: context.ui.colors.success,
                          size: context.sz(20),
                        ),
                      ),
                      UiGap.h(context.ui.spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Top gainers', style: context.uiText.title),
                            Text(
                              '${snapshot.gainers.length} advancing instruments',
                              style: context.uiText.caption.copyWith(
                                color: context.ui.colors.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const UiDivider(),
                  MarketQuoteResults(
                    quotes: snapshot.gainers,
                    onInstrument: onInstrument,
                  ),
                ],
              ),
            ),
            secondary: UiCard(
              accentColor: context.ui.colors.danger,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(
                          context.sp(context.ui.spacing.sm),
                        ),
                        decoration: BoxDecoration(
                          color: context.ui.colors.danger.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: context.radius(context.ui.radii.md),
                        ),
                        child: Icon(
                          Icons.trending_down,
                          color: context.ui.colors.danger,
                          size: context.sz(20),
                        ),
                      ),
                      UiGap.h(context.ui.spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Top losers', style: context.uiText.title),
                            Text(
                              '${snapshot.losers.length} declining instruments',
                              style: context.uiText.caption.copyWith(
                                color: context.ui.colors.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const UiDivider(),
                  MarketQuoteResults(
                    quotes: snapshot.losers,
                    onInstrument: onInstrument,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
