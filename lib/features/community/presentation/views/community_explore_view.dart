import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart'
    show marketFieldLabel;
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_hashtag_page.dart';
import 'package:tradex/features/community/presentation/widgets/community_widgets.dart';

/// Explore & News view — trending market topics, market wire headlines, and category filters.
class CommunityExploreView extends StatefulWidget {
  const CommunityExploreView({
    super.key,
    required this.repository,
    this.onPostTap,
    this.onAuthorTap,
    this.onOpenRef,
    this.searchQuery,
  });

  final CommunityRepository repository;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final String? searchQuery;

  @override
  State<CommunityExploreView> createState() => _CommunityExploreViewState();
}

class _CommunityExploreViewState extends State<CommunityExploreView> {
  final String _searchQuery = '';
  String _selectedCategory = 'All';

  String get _effectiveQuery => (widget.searchQuery?.trim().isNotEmpty ?? false)
      ? widget.searchQuery!.trim()
      : _searchQuery;

  List<String> get _categories => [
    'All',
    ...widget.repository.newsByCategory.keys,
  ];

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;

    final filteredPosts = widget.repository.forYouPosts.where((p) {
      if (_effectiveQuery.isNotEmpty) {
        final q = _effectiveQuery.toLowerCase();
        if (!p.body.toLowerCase().contains(q) &&
            !p.tickers.any((t) => t.toLowerCase().contains(q)) &&
            !p.tags.any((t) => t.toLowerCase().contains(q))) {
          return false;
        }
      }
      if (_selectedCategory != 'All') {
        final cat = _selectedCategory.toLowerCase();
        return p.tags.any((t) => t.toLowerCase().contains(cat)) ||
            p.body.toLowerCase().contains(cat);
      }
      return true;
    }).toList();

    final groups = widget.repository.newsByCategory;
    final wire = <String, List<CommunityNewsItem>>{
      for (final entry in groups.entries)
        if (_selectedCategory == 'All' || _selectedCategory == entry.key)
          entry.key: entry.value
              .where(
                (item) =>
                    _effectiveQuery.isEmpty ||
                    '${item.headline} ${item.summary} ${item.relatedTickers.join(' ')}'
                        .toLowerCase()
                        .contains(_effectiveQuery.toLowerCase()),
              )
              .toList(),
    };
    return UiLazyList(
      key: ValueKey('$_selectedCategory/$_effectiveQuery'),
      maxWidth: context.sz(700),
      padding: EdgeInsets.all(
        context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
      ),
      itemCount: filteredPosts.length,
      headerBuilder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: [
              for (final cat in _categories)
                UiBadge(
                  label: marketFieldLabel(cat),
                  intent: _selectedCategory == cat
                      ? UiIntent.primary
                      : UiIntent.neutral,
                  variant: _selectedCategory == cat
                      ? UiBadgeVariant.solid
                      : UiBadgeVariant.soft,
                  onTap: () => setState(() => _selectedCategory = cat),
                ),
            ],
          ),
          UiGap.v(theme.spacing.md),
          UiCard(
            title: 'Trending in Markets',
            child: Column(
              children: [
                for (final trend in widget.repository.trending.take(6))
                  _trendRow(context, trend),
              ],
            ),
          ),
          UiGap.v(theme.spacing.md),
          Text('Market Wire', style: context.uiText.heading),
          UiGap.v(theme.spacing.sm),
          if (wire.isEmpty)
            UiCallout(
              title:
                  widget.repository.marketDataError ?? 'Market news is loading',
              message:
                  'Category headlines will appear when the market snapshot is ready.',
              intent: UiIntent.info,
            ),
          for (final entry in wire.entries.where(
            (e) => e.value.isNotEmpty,
          )) ...[
            UiDeferred(
              estimatedHeight: 380,
              builder: (_) => UiCard(
                key: ValueKey('wire-category-${entry.key}'),
                title: marketFieldLabel(entry.key),
                trailing: UiButton(
                  label: 'View all',
                  variant: UiVariant.ghost,
                  onPressed: () => _viewAll(entry.key, entry.value),
                ),
                child: _newsItem(context, entry.value.first),
              ),
            ),
            UiGap.v(theme.spacing.md),
          ],
          if (wire.isNotEmpty && wire.values.every((rows) => rows.isEmpty))
            const UiEmptyState(title: 'No matching headlines'),
          Text(
            'Explore Posts (${filteredPosts.length})',
            style: context.uiText.heading,
          ),
          UiGap.v(theme.spacing.sm),
          if (filteredPosts.isEmpty)
            const CommunityEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching posts found',
              message:
                  'Try exploring other categories or clearing your search.',
            ),
        ],
      ),
      itemBuilder: (_, index) {
        final post = filteredPosts[index];
        return Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
          child: CommunityPostCard(
            key: ValueKey(post.id),
            post: post,
            variant: CommunityPostCardVariant.boxed,
            onTap: () => widget.onPostTap?.call(post),
            onLike: () => widget.repository.toggleLike(post.id),
            onRepost: () => widget.repository.toggleRepost(post.id),
            onBookmark: () => widget.repository.toggleBookmark(post.id),
            onAuthorTap: widget.onAuthorTap,
            onOpenRef: widget.onOpenRef,
          ),
        );
      },
    );
  }

  void _viewAll(String category, List<CommunityNewsItem> items) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityMarketWirePage(
          category: category,
          items: items,
          snapshot: widget.repository.marketSnapshot,
        ),
      ),
    );
  }

  Widget _trendRow(BuildContext context, CommunityTrendItem item) {
    final UiTheme theme = context.ui;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityHashtagPage(
              tag: item.topic,
              repository: widget.repository,
              onAuthorTap: widget.onAuthorTap,
              onOpenRef: widget.onOpenRef,
            ),
          ),
        );
      },
      borderRadius: context.radius(theme.radii.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xxs)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.category,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                      fontSize: context.fs(11),
                    ),
                  ),
                  Text(
                    item.topic,
                    style: context.uiText.bodyStrong.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.postCount != null)
                    Text(
                      item.postCount!,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                        fontSize: context.fs(11),
                      ),
                    ),
                ],
              ),
            ),
            UiIconButton(
              icon: Icons.arrow_forward_ios_rounded,
              size: UiSize.xs,
              tooltip: 'Explore topic',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommunityHashtagPage(
                      tag: item.topic,
                      repository: widget.repository,
                      onAuthorTap: widget.onAuthorTap,
                      onOpenRef: widget.onOpenRef,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _newsItem(BuildContext context, CommunityNewsItem item) =>
      MarketNewsCard(
        article: communityMarketArticle(item),
        snapshot:
            widget.repository.marketSnapshot ??
            const MarketSnapshot(instruments: [], articles: []),
        row: true,
        onTap: () => CommunityArticleSheet.show(
          context,
          article: item,
          snapshot: widget.repository.marketSnapshot,
        ),
      );
}

/// A category-specific feed: only visible rows are built, with automatic batches.
class CommunityMarketWirePage extends StatelessWidget {
  const CommunityMarketWirePage({
    super.key,
    required this.category,
    required this.items,
    this.snapshot,
  });
  final String category;
  final List<CommunityNewsItem> items;
  final MarketSnapshot? snapshot;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
            child: Row(
              children: [
                UiIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back to Explore',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                UiGap.h(context.ui.spacing.sm),
                Expanded(
                  child: Text(
                    marketFieldLabel(category),
                    style: context.uiText.heading,
                  ),
                ),
                UiBadge(label: '${items.length} articles'),
              ],
            ),
          ),
          Expanded(
            child: UiLazyList(
              itemCount: items.length,
              maxWidth: context.sz(900),
              padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
              itemBuilder: (_, index) => MarketNewsCard(
                article: communityMarketArticle(items[index]),
                snapshot:
                    snapshot ??
                    const MarketSnapshot(instruments: [], articles: []),
                row: true,
                onTap: () => CommunityArticleSheet.show(
                  context,
                  article: items[index],
                  snapshot: snapshot,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
