import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_hashtag_page.dart';
import 'package:tradex/features/community/presentation/views/community_search_page.dart';
import 'package:tradex/features/community/presentation/widgets/community_widgets.dart';

/// Explore & News view — trending market topics, market wire headlines, and category filters.
class CommunityExploreView extends StatefulWidget {
  const CommunityExploreView({
    super.key,
    required this.repository,
    this.onPostTap,
    this.onAuthorTap,
  });

  final CommunityRepository repository;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;

  @override
  State<CommunityExploreView> createState() => _CommunityExploreViewState();
}

class _CommunityExploreViewState extends State<CommunityExploreView> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static const List<String> _categories = <String>[
    'All',
    'Crypto',
    'Equities',
    'Options',
    'Macro',
    'Education',
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
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
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

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Search Field
          UiSearchField(
            value: _searchQuery,
            hintText: 'Explore topics, market trends, breaking signals...',
            onChanged: (String q) => setState(() => _searchQuery = q),
            onSubmitted: (String q) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CommunitySearchPage(
                    repository: widget.repository,
                    initialQuery: q,
                    onAuthorTap: widget.onAuthorTap,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),

          // Category Chips Row
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return UiBadge(
                label: cat,
                intent: isSelected ? UiIntent.primary : UiIntent.neutral,
                variant: isSelected
                    ? UiBadgeVariant.solid
                    : UiBadgeVariant.soft,
                size: UiSize.sm,
                onTap: () => setState(() => _selectedCategory = cat),
              );
            }).toList(),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Section 1: Trending in Markets
          UiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Trending in Markets',
                  style: context.uiText.heading.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                for (
                  int i = 0;
                  i < widget.repository.trending.length;
                  i++
                ) ...<Widget>[
                  if (i > 0)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.sp(theme.spacing.xs),
                      ),
                      child: UiDivider(),
                    ),
                  _trendRow(context, widget.repository.trending[i]),
                ],
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Section 2: Market Wire Headlines
          UiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.newspaper_rounded,
                      size: context.sz(16),
                      color: theme.colors.primary,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      'Market Wire',
                      style: context.uiText.heading.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                for (
                  int i = 0;
                  i < widget.repository.news.length;
                  i++
                ) ...<Widget>[
                  if (i > 0)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.sp(theme.spacing.xs),
                      ),
                      child: UiDivider(),
                    ),
                  _newsItem(context, widget.repository.news[i]),
                ],
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Section 3: Matching Community Posts
          Text(
            'Explore Posts (${filteredPosts.length})',
            style: context.uiText.heading.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),

          if (filteredPosts.isEmpty)
            Padding(
              padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
              child: UiEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matching posts found',
                message:
                    'Try exploring other categories or clearing your search.',
              ),
            )
          else
            CommunityPostGrid(
              posts: filteredPosts,
              onPostTap: widget.onPostTap,
              onLike: (id) => widget.repository.toggleLike(id),
              onRepost: (id) => widget.repository.toggleRepost(id),
              onBookmark: (id) => widget.repository.toggleBookmark(id),
              onAuthorTap: widget.onAuthorTap,
            ),
        ],
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

  Widget _newsItem(BuildContext context, CommunityNewsItem item) {
    final UiTheme theme = context.ui;
    final sentimentIntent = item.sentimentScore > 0.3
        ? UiIntent.success
        : (item.sentimentScore < -0.2 ? UiIntent.danger : UiIntent.info);

    return InkWell(
      onTap: () {
        CommunityArticleSheet.show(
          context,
          article: item,
        );
      },
      borderRadius: context.radius(theme.radii.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xxs)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              item.headline,
              style: context.uiText.bodyStrong.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item.summary != null) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                item.summary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
            SizedBox(height: context.sp(theme.spacing.xs)),
            Row(
              children: <Widget>[
                UiBadge(
                  label: item.category,
                  intent: sentimentIntent,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  child: Text(
                    '${item.source} · ${AppTokens.relativeTime(item.publishedAt)}',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundSubtle,
                      fontSize: context.fs(11),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
