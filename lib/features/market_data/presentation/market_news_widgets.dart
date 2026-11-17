import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tradex/core/ads/ad_config.dart';
import 'package:tradex/core/ads/ad_slot.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../models/market_snapshot.dart';
import 'market_instrument_view.dart' show marketFieldLabel;
import 'market_movers_panel.dart';
import 'market_layout.dart';
import 'market_visuals.dart';
import '../data/yahoo_finance_service.dart';

String topicDisplayLabel(String key) => switch (key) {
  'stock_market_general' => 'Markets & Economy',
  'magnificent_seven' => 'Tech & AI',
  'banks_and_financials' => 'Banks & Financials',
  'enterprise_cloud' => 'Enterprise Cloud',
  'pharma_and_biotech' => 'Pharma & Biotech',
  'clean_energy' => 'Clean Energy',
  'aerospace_and_defense' => 'Aerospace & Defense',
  'oil_and_gas' => 'Oil & Gas',
  'cybersecurity' => 'Cybersecurity',
  'housing' => 'Housing',
  'crypto' => 'Crypto',
  _ => marketFieldLabel(key),
};

class MarketArticleMeta extends StatelessWidget {
  const MarketArticleMeta({
    super.key,
    required this.article,
    required this.snapshot,
    this.onInstrument,
  });
  final MarketArticle article;
  final MarketSnapshot snapshot;
  final ValueChanged<MarketInstrument>? onInstrument;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: context.sp(context.ui.spacing.xs),
    runSpacing: context.sp(context.ui.spacing.xs),
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            size: context.sz(12),
            color: context.ui.colors.foregroundMuted,
          ),
          UiGap.h(context.ui.spacing.xs),
          Text(
            article.publishedAt != null
                ? AppTokens.relativeTime(article.publishedAt!)
                : 'Just now',
            style: context.uiText.caption.copyWith(
              color: context.ui.colors.foregroundMuted,
            ),
          ),
        ],
      ),
      if (article.publisher.isNotEmpty)
        UiBadge(
          label: article.publisher.length > 22
              ? '${article.publisher.substring(0, 21)}…'
              : article.publisher,
          variant: UiBadgeVariant.outline,
          size: UiSize.xs,
        ),
      if (article.isVideo)
        const UiBadge(
          label: 'Video',
          icon: Icons.play_circle_outline,
          size: UiSize.xs,
        ),
      for (final symbol in article.tickers.take(3))
        Builder(
          builder: (context) {
            final quote = snapshot.instruments
                .where((q) => q.symbol == symbol)
                .firstOrNull;
            if (quote != null) {
              final isPos = quote.changePercent >= 0;
              return onInstrument != null
                  ? UiButton(
                      label: '$symbol ${isPos ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
                      size: UiSize.xs,
                      variant: UiVariant.soft,
                      intent: isPos ? UiIntent.success : UiIntent.danger,
                      onPressed: () => onInstrument!(quote),
                    )
                  : UiBadge(
                      label: '$symbol ${isPos ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
                      size: UiSize.xs,
                      intent: isPos ? UiIntent.success : UiIntent.danger,
                      variant: UiBadgeVariant.soft,
                    );
            }
            return UiBadge(
              label: symbol,
              size: UiSize.xs,
              variant: UiBadgeVariant.soft,
            );
          },
        ),
    ],
  );
}

class MarketNewsCard extends StatelessWidget {
  const MarketNewsCard({
    super.key,
    required this.article,
    required this.snapshot,
    required this.onTap,
    this.featured = false,
    this.row = false,
    this.textOnly = false,
    this.onInstrument,
    this.isLiked = false,
    this.onLike,
  });
  final MarketArticle article;
  final MarketSnapshot snapshot;
  final VoidCallback onTap;
  final bool featured, row, textOnly;
  final ValueChanged<MarketInstrument>? onInstrument;
  final bool isLiked;
  final VoidCallback? onLike;

  Widget _fallbackBanner(BuildContext context) {
    final colors = context.ui.colors;
    final symbol = article.tickers.isNotEmpty ? article.tickers.first : '';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceMuted,
            colors.primary.withValues(alpha: 0.14),
          ],
        ),
      ),
      padding: EdgeInsets.all(context.sp(context.ui.spacing.xs)),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            bottom: -6,
            child: Icon(
              Icons.trending_up_rounded,
              size: context.sz(38),
              color: colors.primary.withValues(alpha: 0.15),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (symbol.isNotEmpty) ...[
                  UiBadge(
                    label: symbol,
                    size: UiSize.xs,
                    variant: UiBadgeVariant.outline,
                    intent: UiIntent.primary,
                  ),
                  UiGap.h(context.ui.spacing.xs),
                ],
                Expanded(
                  child: Text(
                    article.publisher.isNotEmpty
                        ? article.publisher
                        : 'Market News',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _image(BuildContext context) {
    final String? thumb = article.thumbnailUrl?.trim();
    return ClipRRect(
      borderRadius: context.radius(context.ui.radii.md),
      child: AspectRatio(
        aspectRatio: featured ? 16 / 10 : (row ? 4 / 3 : 16 / 9),
        child: (thumb != null && thumb.isNotEmpty)
            ? UiRemoteImage(
                url: thumb,
                semanticLabel: article.title,
                errorIcon: Icons.newspaper_outlined,
              )
            : _fallbackBanner(context),
      ),
    );
  }

  Widget _copy(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (featured && article.publisher.isNotEmpty) ...[
        Row(
          children: [
            Icon(
              Icons.newspaper_outlined,
              size: context.sz(14),
              color: context.ui.colors.primary,
            ),
            UiGap.h(context.ui.spacing.xs),
            Expanded(
              child: Text(
                article.publisher.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: context.ui.colors.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.xs),
      ],
      Text(
        article.title,
        maxLines: featured ? 3 : (textOnly ? 2 : 3),
        overflow: TextOverflow.ellipsis,
        style: featured
            ? context.uiText.heading
            : (textOnly ? context.uiText.body : context.uiText.bodyStrong),
      ),
      if (article.summary.trim().isNotEmpty) ...[
        UiGap.v(context.ui.spacing.xs),
        Text(
          article.summary.trim(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: (featured ? context.uiText.body : context.uiText.caption).copyWith(
            color: context.ui.colors.foregroundMuted,
            height: 1.35,
          ),
        ),
      ],
      UiGap.v(context.ui.spacing.sm),
      MarketArticleMeta(
        article: article,
        snapshot: snapshot,
        onInstrument: onInstrument,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (textOnly) {
      return InkWell(
        onTap: onTap,
        borderRadius: context.radius(context.ui.radii.md),
        child: Padding(
          padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
          child: _copy(context),
        ),
      );
    }

    return UiCard(
      onTap: onTap,
      variant: featured ? UiCardVariant.surface : UiCardVariant.ghost,
      borderless: !featured,
      hoverLift: featured,
      padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
      child: LayoutBuilder(
        builder: (context, box) {
          // Horizontal hero layout on desktop matching Image 3
          if (featured && box.maxWidth >= 600) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _image(context)),
                UiGap.h(context.ui.spacing.md),
                Expanded(flex: 6, child: _copy(context)),
              ],
            );
          }
          if (row && box.maxWidth >= 380) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: _copy(context)),
                UiGap.h(context.ui.spacing.lg),
                Expanded(child: _image(context)),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (featured || !row) ...[
                _image(context),
                UiGap.v(context.ui.spacing.md),
              ],
              _copy(context),
            ],
          );
        },
      ),
    );
  }
}

/// Watch Now Featured Video & Playlist Card matching Image 4.
class MarketWatchNowCard extends StatelessWidget {
  const MarketWatchNowCard({
    super.key,
    required this.videos,
    required this.onArticle,
    this.onInstrument,
    required this.snapshot,
  });

  final List<MarketArticle> videos;
  final ValueChanged<MarketArticle> onArticle;
  final ValueChanged<MarketInstrument>? onInstrument;
  final MarketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) return const SizedBox.shrink();

    final featured = videos.first;
    final playlist = videos.skip(1).take(4).toList();

    return UiCard(
      title: 'Watch Now',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'More Videos',
            style: context.uiText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: context.ui.colors.primary,
            ),
          ),
          UiGap.h(context.ui.spacing.xxs),
          Icon(
            Icons.chevron_right,
            size: context.sz(16),
            color: context.ui.colors.primary,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 650;

          final featuredWidget = MarketNewsCard(
            article: featured,
            snapshot: snapshot,
            featured: true,
            onTap: () => onArticle(featured),
            onInstrument: onInstrument,
          );

          final playlistWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < playlist.length; i++) ...[
                InkWell(
                  onTap: () => onArticle(playlist[i]),
                  borderRadius: context.radius(context.ui.radii.sm),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: context.sp(context.ui.spacing.xs),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          alignment: Alignment.bottomLeft,
                          children: [
                            ClipRRect(
                              borderRadius: context.radius(context.ui.radii.sm),
                              child: SizedBox(
                                width: context.sz(110),
                                height: context.sz(66),
                                child: UiRemoteImage(
                                  url: playlist[i].thumbnailUrl,
                                  semanticLabel: playlist[i].title,
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.all(4),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: i == 0 ? context.ui.colors.primary : Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                i == 0 ? 'Now playing' : '▶ 02:1${i + 2}',
                                style: context.uiText.caption.copyWith(
                                  fontSize: context.fs(9),
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        UiGap.h(context.ui.spacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playlist[i].title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.uiText.bodyStrong.copyWith(
                                  fontSize: context.fs(12),
                                ),
                              ),
                              UiGap.v(context.ui.spacing.xxs),
                              Text(
                                '${playlist[i].publisher} • ${AppTokens.relativeTime(playlist[i].publishedAt ?? DateTime.now())}',
                                style: context.uiText.caption.copyWith(
                                  color: context.ui.colors.foregroundMuted,
                                  fontSize: context.fs(10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < playlist.length - 1) const UiDivider(spacing: 0),
              ],
            ],
          );

          if (isNarrow) {
            return Column(
              children: [
                featuredWidget,
                UiGap.v(context.ui.spacing.md),
                const UiDivider(),
                UiGap.v(context.ui.spacing.sm),
                playlistWidget,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: featuredWidget),
              UiGap.h(context.ui.spacing.lg),
              Expanded(flex: 4, child: playlistWidget),
            ],
          );
        },
      ),
    );
  }
}

class MarketNewsView extends StatefulWidget {
  const MarketNewsView({
    super.key,
    required this.snapshot,
    required this.onArticle,
    this.limit = 20,
    this.pageSize = 10,
    this.onMore,
    this.onInstrument,
    this.onTopicSelected,
    this.selectedTopic = 'all',
    this.searchQuery = '',
    this.isLiked,
    this.onLike,
  });
  final MarketSnapshot snapshot;
  final ValueChanged<MarketArticle> onArticle;
  final int limit;
  final int pageSize;
  final VoidCallback? onMore;
  final ValueChanged<MarketInstrument>? onInstrument;
  final ValueChanged<String>? onTopicSelected;
  final String selectedTopic;
  final String searchQuery;
  final bool Function(MarketArticle)? isLiked;
  final ValueChanged<MarketArticle>? onLike;

  @override
  State<MarketNewsView> createState() => _MarketNewsViewState();
}

class _MarketNewsViewState extends State<MarketNewsView> {
  int _page = 0;
  List<MarketArticle> _liveArticles = [];

  @override
  void initState() {
    super.initState();
    _fetchLiveNews();
  }

  Future<void> _fetchLiveNews() async {
    try {
      final query = widget.selectedTopic == 'all'
          ? 'stock'
          : widget.selectedTopic;
      final live = await YahooFinanceService.instance.fetchLiveNews(
        query: query,
      );
      if (live.isNotEmpty && mounted) {
        setState(() {
          _liveArticles = live;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant MarketNewsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTopic != widget.selectedTopic) {
      _page = 0;
      _liveArticles = [];
      _fetchLiveNews();
    } else if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.pageSize != widget.pageSize) {
      _page = 0;
    }
    // Appending or refreshing articles must not undo a page selection.
  }

  @override
  Widget build(BuildContext context) {
    // Combine live fetched Yahoo Finance articles with snapshot baseline without duplication
    final seen = <String>{};
    final query = widget.searchQuery.trim().toLowerCase();
    final articles = [..._liveArticles, ...widget.snapshot.articles]
        .where(
          (a) =>
              (query.isEmpty ||
                  '${a.title} ${a.summary} ${a.tickers.join(' ')}'
                      .toLowerCase()
                      .contains(query)) &&
              seen.add(a.title.toLowerCase().trim()),
        )
        .toList();

    final publishers = <String, num>{};
    for (final article in articles) {
      final name = article.publisher.trim();
      if (name.isNotEmpty) {
        publishers.update(name, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    final pageSize = widget.pageSize;
    final count = (articles.length / pageSize).ceil();
    _page = count == 0 ? 0 : _page.clamp(0, count - 1);
    final page = _page;
    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, articles.length);
    final pageArticles =
        articles.isEmpty ? <MarketArticle>[] : articles.sublist(startIndex, endIndex);
    final int manifestNewsCount = widget.selectedTopic == 'all'
        ? (widget.snapshot.manifest['news_count'] as num? ?? 0).toInt()
        : 0;
    final int totalStories = manifestNewsCount > articles.length
        ? manifestNewsCount
        : articles.length;

    // Prepare popular editorial articles for right rail matching Image 3 from topics
    final popularArticles = (widget.snapshot.topics['popular'] ??
            widget.snapshot.topics['trending'] ??
            widget.snapshot.topics['stock_market_general'] ??
            const <MarketArticle>[])
        .where((a) => !pageArticles.contains(a))
        .take(6)
        .toList();

    // Prepare 3-column subgrid categories matching Image 3
    final subgridCategories = <(String title, MarketArticle lead, MarketArticle? secondary)>[];
    for (final entry in widget.snapshot.topics.entries.take(3)) {
      if (entry.value.isNotEmpty) {
        subgridCategories.add((
          topicDisplayLabel(entry.key),
          entry.value.first,
          entry.value.length > 1 ? entry.value[1] : null,
        ));
      }
    }

    return MarketTwoPanel(
          primary: UiCard(
            title: 'Market newsroom',
            subtitle: '${articles.length} stories',
            trailing: UiBadge(
              label: 'Real-time',
              icon: Icons.sensors,
              intent: UiIntent.success,
              variant: UiBadgeVariant.soft,
            ),
            padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (articles.isEmpty)
                  const UiEmptyState(
                    icon: Icons.newspaper_outlined,
                    title: 'No articles available',
                    message: 'Try another topic or search term.',
                  ),
                if (articles.isNotEmpty) ...[
                  if (page == 0) ...[
                    // Featured Hero Article on first page
                    MarketNewsCard(
                      article: pageArticles.first,
                      snapshot: widget.snapshot,
                      featured: true,
                      onInstrument: widget.onInstrument,
                      onTap: () => widget.onArticle(pageArticles.first),
                      isLiked: widget.isLiked?.call(pageArticles.first) ?? false,
                      onLike: widget.onLike == null
                          ? null
                          : () => widget.onLike!(pageArticles.first),
                    ),

                    // 3-Column Category Subgrid matching Image 3
                    if (subgridCategories.isNotEmpty) ...[
                      UiGap.v(context.ui.spacing.md),
                      const UiDivider(),
                      UiGap.v(context.ui.spacing.sm),
                      LayoutBuilder(
                        builder: (context, c) {
                          final isNarrow = c.maxWidth < 650;

                          Widget buildCol((String, MarketArticle, MarketArticle?) cat) => InkWell(
                            onTap: () => widget.onArticle(cat.$2),
                            borderRadius: context.radius(context.ui.radii.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        cat.$1,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.uiText.bodyStrong.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    UiGap.h(context.ui.spacing.xxs),
                                    Icon(
                                      Icons.chevron_right,
                                      size: context.sz(14),
                                      color: context.ui.colors.foregroundMuted,
                                    ),
                                  ],
                                ),
                                UiGap.v(context.ui.spacing.xs),
                                ClipRRect(
                                  borderRadius: context.radius(context.ui.radii.sm),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: UiRemoteImage(
                                      url: cat.$2.thumbnailUrl,
                                      semanticLabel: cat.$2.title,
                                    ),
                                  ),
                                ),
                                UiGap.v(context.ui.spacing.xs),
                                Text(
                                  cat.$2.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.uiText.bodyStrong,
                                ),
                                UiGap.v(context.ui.spacing.xxs),
                                Text(
                                  '${cat.$2.publisher} • ${AppTokens.relativeTime(cat.$2.publishedAt ?? DateTime.now())}',
                                  style: context.uiText.caption.copyWith(
                                    color: context.ui.colors.foregroundMuted,
                                    fontSize: context.fs(11),
                                  ),
                                ),
                                if (cat.$3 != null) ...[
                                  UiGap.v(context.ui.spacing.xs),
                                  const UiDivider(spacing: 0),
                                  UiGap.v(context.ui.spacing.xs),
                                  InkWell(
                                    onTap: () => widget.onArticle(cat.$3!),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: context.sz(6),
                                          height: context.sz(6),
                                          decoration: BoxDecoration(
                                            color: context.ui.colors.danger,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        UiGap.h(context.ui.spacing.xs),
                                        Expanded(
                                          child: Text(
                                            cat.$3!.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: context.uiText.caption.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                for (final cat in subgridCategories) ...[
                                  buildCol(cat),
                                  UiGap.v(context.ui.spacing.md),
                                ],
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < subgridCategories.length; i++) ...[
                                Expanded(child: buildCol(subgridCategories[i])),
                                if (i < subgridCategories.length - 1)
                                  UiGap.h(context.ui.spacing.md),
                              ],
                            ],
                          );
                        },
                      ),
                    ],

                    // Remaining stories on page 0
                    if (pageArticles.length > 1) ...[
                      UiGap.v(context.ui.spacing.md),
                      const UiDivider(),
                      UiGap.v(context.ui.spacing.md),
                      for (var i = 1; i < pageArticles.length; i++) ...[
                        MarketNewsCard(
                          article: pageArticles[i],
                          snapshot: widget.snapshot,
                          row: true,
                          onInstrument: widget.onInstrument,
                          onTap: () => widget.onArticle(pageArticles[i]),
                          isLiked: widget.isLiked?.call(pageArticles[i]) ?? false,
                          onLike: widget.onLike == null
                              ? null
                              : () => widget.onLike!(pageArticles[i]),
                        ),
                        if (i < pageArticles.length - 1) const UiDivider(),
                      ],
                    ],
                  ] else ...[
                    // Subsequent pages
                    for (var i = 0; i < pageArticles.length; i++) ...[
                      MarketNewsCard(
                        article: pageArticles[i],
                        snapshot: widget.snapshot,
                        row: true,
                        onInstrument: widget.onInstrument,
                        onTap: () => widget.onArticle(pageArticles[i]),
                        isLiked: widget.isLiked?.call(pageArticles[i]) ?? false,
                        onLike: widget.onLike == null
                            ? null
                            : () => widget.onLike!(pageArticles[i]),
                      ),
                      if (i < pageArticles.length - 1) const UiDivider(),
                    ],
                  ],
                ],
                if (count > 1) ...[
                  UiGap.v(context.ui.spacing.md),
                  const UiDivider(),
                  UiGap.v(context.ui.spacing.sm),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runAlignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: context.sp(context.ui.spacing.md),
                    runSpacing: context.sp(context.ui.spacing.sm),
                    children: [
                      Text(
                        'Showing ${startIndex + 1}–$endIndex of $totalStories stories · Page ${page + 1} of $count',
                        style: context.uiText.caption.copyWith(
                          color: context.ui.colors.foregroundMuted,
                        ),
                      ),
                      UiPagination(
                        page: page,
                        pageCount: count,
                        onPageChanged: (newPage) {
                          setState(() => _page = newPage);
                          if (newPage >= count - 1) {
                            widget.onMore?.call();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          secondary: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Popular Editorial Rail matching Image 3
              if (popularArticles.isNotEmpty) ...[
                UiCard(
                  title: 'Popular',
                  trailing: Icon(
                    Icons.chevron_right,
                    size: context.sz(18),
                    color: context.ui.colors.foregroundMuted,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < popularArticles.length; i++) ...[
                        InkWell(
                          onTap: () => widget.onArticle(popularArticles[i]),
                          borderRadius: context.radius(context.ui.radii.sm),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: context.sp(context.ui.spacing.xs),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  popularArticles[i].title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.uiText.bodyStrong.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                UiGap.v(context.ui.spacing.xxs),
                                Row(
                                  children: [
                                    if (popularArticles[i].publisher.isNotEmpty)
                                      Expanded(
                                        child: Text(
                                          popularArticles[i].publisher,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.uiText.caption.copyWith(
                                            color: context.ui.colors.foregroundMuted,
                                            fontSize: context.fs(11),
                                          ),
                                        ),
                                      )
                                    else
                                      const Spacer(),
                                    UiGap.h(context.ui.spacing.xs),
                                    for (final symbol in popularArticles[i].tickers.take(1))
                                      Builder(
                                        builder: (context) {
                                          final quote = widget.snapshot.instruments
                                              .where((q) => q.symbol == symbol)
                                              .firstOrNull;
                                          if (quote != null) {
                                            final isPos = quote.changePercent >= 0;
                                            return UiBadge(
                                              label:
                                                  '$symbol ${isPos ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
                                              intent: isPos
                                                  ? UiIntent.success
                                                  : UiIntent.danger,
                                              variant: UiBadgeVariant.soft,
                                              size: UiSize.xs,
                                            );
                                          }
                                          return UiBadge(
                                            label: symbol,
                                            size: UiSize.xs,
                                            variant: UiBadgeVariant.soft,
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (i < popularArticles.length - 1)
                          const UiDivider(spacing: 0),
                      ],
                    ],
                  ),
                ),
                UiGap.v(context.ui.spacing.md),
              ],

              // Video Content "Watch Now" Card matching Image 4
              if (widget.snapshot.videos.isNotEmpty) ...[
                MarketWatchNowCard(
                  videos: widget.snapshot.videos,
                  onArticle: widget.onArticle,
                  onInstrument: widget.onInstrument,
                  snapshot: widget.snapshot,
                ),
                UiGap.v(context.ui.spacing.md),
              ],

              // Topic Filters
              UiCard(
                title: 'Topics',
                subtitle: 'Browse by category',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UiButton(
                      label: 'All topics',
                      alignment: Alignment.centerLeft,
                      variant: widget.selectedTopic == 'all'
                          ? UiVariant.soft
                          : UiVariant.ghost,
                      intent: widget.selectedTopic == 'all'
                          ? UiIntent.primary
                          : UiIntent.neutral,
                      onPressed: widget.onTopicSelected == null
                          ? null
                          : () => widget.onTopicSelected!('all'),
                    ),
                    for (final topic in widget.snapshot.topics.entries)
                      UiButton(
                        label:
                            '${topicDisplayLabel(topic.key)} (${topic.value.length})',
                        alignment: Alignment.centerLeft,
                        variant: widget.selectedTopic == topic.key
                            ? UiVariant.soft
                            : UiVariant.ghost,
                        intent: widget.selectedTopic == topic.key
                            ? UiIntent.primary
                            : UiIntent.neutral,
                        onPressed: widget.onTopicSelected == null
                            ? null
                            : () => widget.onTopicSelected!(topic.key),
                      ),
                  ],
                ),
              ),
              UiGap.v(context.ui.spacing.md),

              // Trending Companies
              UiCard(
                title: 'Trending companies',
                subtitle: 'Most mentioned in news',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.snapshot.trending.isEmpty)
                      Text(
                        'No trending companies',
                        style: context.uiText.caption.copyWith(
                          color: context.ui.colors.foregroundMuted,
                        ),
                      )
                    else
                      for (final quote in widget.snapshot.trending.take(6)) ...[
                        MarketQuoteRow(
                          quote: quote,
                          onTap: () => widget.onInstrument?.call(quote),
                        ),
                        const UiDivider(spacing: 0),
                      ],
                  ],
                ),
              ),
              UiGap.v(context.ui.spacing.md),

              MarketDistributionCard(
                title: 'Coverage by publisher',
                subtitle:
                    '${articles.length} articles · ${widget.snapshot.videos.length} videos',
                values: publishers,
              ),
            ],
          ),
        );
  }
}

class MarketArticleView extends StatefulWidget {
  const MarketArticleView({
    super.key,
    required this.article,
    required this.snapshot,
    this.onArticle,
    this.onInstrument,
    this.isLiked = false,
    this.onLike,
  });
  final MarketArticle article;
  final MarketSnapshot snapshot;
  final ValueChanged<MarketArticle>? onArticle;
  final ValueChanged<MarketInstrument>? onInstrument;
  final bool isLiked;
  final VoidCallback? onLike;

  @override
  State<MarketArticleView> createState() => _MarketArticleViewState();
}

class _MarketArticleViewState extends State<MarketArticleView> {
  final Map<String, MarketInstrument> _liveQuotes = {};

  @override
  void initState() {
    super.initState();
    _initSeedQuotes();
    _fetchLiveQuotes();
  }

  @override
  void didUpdateWidget(covariant MarketArticleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.link != widget.article.link) {
      _liveQuotes.clear();
      _initSeedQuotes();
      _fetchLiveQuotes();
    }
  }

  void _initSeedQuotes() {
    for (final sym in widget.article.tickers) {
      final match = widget.snapshot.instruments
          .where((q) => q.symbol.toUpperCase() == sym.toUpperCase())
          .firstOrNull;
      if (match != null) {
        _liveQuotes[sym] = match;
      }
    }
  }

  Future<void> _fetchLiveQuotes() async {
    final missingTickers = widget.article.tickers
        .take(6)
        .where((sym) => !_liveQuotes.containsKey(sym))
        .toList();
    if (missingTickers.isEmpty) return;
    try {
      final quotes = await YahooFinanceService.instance.fetchQuotes(
        missingTickers,
      );
      if (!mounted || quotes.isEmpty) return;
      setState(() {
        for (final entry in quotes.entries) {
          final q = entry.value;
          _liveQuotes[entry.key] = MarketInstrument.fromJson(
            {
              'ticker': q.symbol,
              'name': q.name,
              'price': q.price,
              'change_pct': q.changePercent,
              'currency': 'USD',
            },
            {},
            history: q.spark,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _source(BuildContext context) async {
    final uri = Uri.tryParse(widget.article.link);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && context.mounted) {
      UiToast.show(
        context,
        title: 'Could not open source',
        intent: UiIntent.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final snapshot = widget.snapshot;
    final tickers = article.tickers;
    final relatedInstruments = <MarketInstrument>[];
    for (final sym in tickers) {
      if (_liveQuotes.containsKey(sym)) {
        relatedInstruments.add(_liveQuotes[sym]!);
      } else {
        final inSnap =
            snapshot.instruments.where((q) => q.symbol == sym).firstOrNull;
        if (inSnap != null) relatedInstruments.add(inSnap);
      }
    }
    final displayInstruments = relatedInstruments.isNotEmpty
        ? relatedInstruments
        : snapshot.trending.take(4).toList();

    return MarketTwoPanel(
      primary: UiCard(
        accentColor: context.ui.colors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Publisher Badge
            Row(
              children: [
                UiBadge(
                  label: 'News & Analysis',
                  icon: Icons.newspaper_outlined,
                  variant: UiBadgeVariant.soft,
                  intent: UiIntent.primary,
                ),
                const Spacer(),
                if (article.isVideo)
                  const UiBadge(
                    label: 'Video',
                    icon: Icons.play_circle_outline,
                    variant: UiBadgeVariant.outline,
                  ),
              ],
            ),
            UiGap.v(context.ui.spacing.lg),

            // Article Title
            Text(article.title, style: context.uiText.display),
            UiGap.v(context.ui.spacing.md),

            // Article Meta
            Wrap(
              spacing: context.sp(context.ui.spacing.sm),
              runSpacing: context.sp(context.ui.spacing.xs),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (article.publisher.isNotEmpty)
                  UiBadge(
                    label: article.publisher.length > 22
                        ? '${article.publisher.substring(0, 21)}…'
                        : article.publisher,
                    variant: UiBadgeVariant.soft,
                    intent: UiIntent.primary,
                    size: UiSize.xs,
                  ),
                Text(
                  article.publishedAt != null
                      ? AppTokens.relativeTime(article.publishedAt!)
                      : 'Unknown time',
                  style: context.uiText.caption.copyWith(
                    color: context.ui.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
            UiGap.v(context.ui.spacing.lg),

            // Featured Image
            ClipRRect(
              borderRadius: context.radius(context.ui.radii.lg),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: UiRemoteImage(
                  url: article.thumbnailUrl,
                  semanticLabel: article.title,
                ),
              ),
            ),
            UiGap.v(context.ui.spacing.lg),

            // Article Summary
            if (article.summary.isNotEmpty)
              Container(
                padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
                decoration: BoxDecoration(
                  color: context.ui.colors.foreground.withValues(alpha: 0.03),
                  borderRadius: context.radius(context.ui.radii.md),
                  border: Border.all(color: context.ui.colors.border, width: 1),
                ),
                child: Text(
                  article.summary,
                  style: context.uiText.body.copyWith(height: 1.6, fontSize: 16),
                ),
              )
            else
              const UiCallout(
                title: 'Summary unavailable',
                message: 'Read the full report at the original source.',
                intent: UiIntent.neutral,
              ),
            UiGap.v(context.ui.spacing.lg),

            // Related Tickers
            if (article.tickers.isNotEmpty) ...[
              Text('Related instruments', style: context.uiText.subheading),
              UiGap.v(context.ui.spacing.sm),
              Wrap(
                spacing: context.sp(context.ui.spacing.xs),
                runSpacing: context.sp(context.ui.spacing.xs),
                children: [
                  for (final symbol in article.tickers)
                    Builder(
                      builder: (context) {
                        final quote = _liveQuotes[symbol] ??
                            snapshot.instruments
                                .where((q) => q.symbol == symbol)
                                .firstOrNull;
                        return quote != null && widget.onInstrument != null
                            ? UiButton(
                                label: symbol,
                                size: UiSize.sm,
                                variant: UiVariant.soft,
                                onPressed: () => widget.onInstrument!(quote),
                              )
                            : UiBadge(
                                label: symbol,
                                variant: UiBadgeVariant.outline,
                              );
                      },
                    ),
                ],
              ),
              UiGap.v(context.ui.spacing.lg),
            ],

            // Read Original CTA
            UiButton(
              label: article.isVideo
                  ? 'Watch at source'
                  : 'Read original article',
              leadingIcon: Icons.open_in_new,
              intent: UiIntent.primary,
              onPressed: article.link.isEmpty ? null : () => _source(context),
            ),
            UiGap.v(context.ui.spacing.lg),
            AdSlot(
              placement: AdPlacement.articleFooter,
              contentReady:
                  article.publisher.trim().toLowerCase().contains(
                    'alphajournal',
                  ) &&
                  article.summary.trim().length >= 600,
              previewContentReady: true,
            ),
          ],
        ),
      ),
      secondary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (displayInstruments.isNotEmpty) ...[
            MarketRelatedMoves(
              instruments: displayInstruments,
              onInstrument: widget.onInstrument,
            ),
            UiGap.v(context.ui.spacing.md),
          ],
          // Related Quotes
          UiCard(
            title: 'Related instruments',
            subtitle: relatedInstruments.isNotEmpty
                ? 'Companies mentioned'
                : 'Trending instruments',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (displayInstruments.isEmpty)
                  Text(
                    'No linked quotes in this snapshot.',
                    style: context.uiText.caption.copyWith(
                      color: context.ui.colors.foregroundMuted,
                    ),
                  )
                else
                  for (final quote in displayInstruments) ...[
                    MarketQuoteRow(
                      quote: quote,
                      onTap: () => widget.onInstrument?.call(quote),
                    ),
                    const UiDivider(spacing: 0),
                  ],
              ],
            ),
          ),
          UiGap.v(context.ui.spacing.md),

          // More Stories
          UiCard(
            title: 'More stories',
            subtitle: 'Related coverage',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snapshot.articles
                    .where((a) => a.link != article.link)
                    .isEmpty)
                  Text(
                    'No more articles available.',
                    style: context.uiText.caption.copyWith(
                      color: context.ui.colors.foregroundMuted,
                    ),
                  )
                else
                  for (final related
                      in snapshot.articles
                          .where((a) => a.link != article.link)
                          .take(5)) ...[
                    MarketNewsCard(
                      article: related,
                      snapshot: snapshot,
                      textOnly: true,
                      onTap: () => widget.onArticle?.call(related),
                    ),
                    const UiDivider(),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
