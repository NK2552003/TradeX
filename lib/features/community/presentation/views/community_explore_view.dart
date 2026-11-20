import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart' hide CommunityPostCard;
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/views/community_hashtag_page.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_follow_button.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_widgets.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';
import 'package:alphajournal/features/market_data/presentation/market_instrument_view.dart'
    show marketFieldLabel;
import 'package:alphajournal/features/market_data/presentation/market_news_widgets.dart';
import 'package:alphajournal/features/notes/data/notes_repository.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_side_sheet.dart';
import 'package:alphajournal/features/strategies/data/strategies_repository.dart';

/// One Explore category tab (X-style), mapped to real posts, trends and wire news.
class ExploreTabSpec {
  const ExploreTabSpec(this.id, this.label, {this.keywords, this.wireKeys});

  final String id;
  final String label;

  /// Word-prefix keywords used to match posts/trends; null = no filtering.
  final List<String>? keywords;

  /// Substrings matched against market-wire category keys.
  final List<String>? wireKeys;

  RegExp? get pattern => keywords == null
      ? null
      : RegExp('\\b(${keywords!.join('|')})', caseSensitive: false);
}

const List<ExploreTabSpec> kExploreTabs = <ExploreTabSpec>[
  ExploreTabSpec('for_you', 'For You'),
  ExploreTabSpec('trending', 'Trending'),
  ExploreTabSpec('news', 'News', wireKeys: <String>['']),
  ExploreTabSpec(
    'stocks',
    'Stocks',
    keywords: <String>[
      'stock',
      'equit',
      'nifty',
      'sensex',
      'nse',
      'bse',
      'earnings',
      'nasdaq',
      'nyse',
      'ipo',
      'dividend',
      'technology',
      'business',
    ],
    wireKeys: <String>['stock', 'equit', 'india', 'us_', 'earnings'],
  ),
  ExploreTabSpec(
    'crypto',
    'Crypto',
    keywords: <String>[
      'crypto',
      'btc',
      'eth',
      'bitcoin',
      'ethereum',
      'sol',
      'defi',
      'altcoin',
    ],
    wireKeys: <String>['crypto'],
  ),
  ExploreTabSpec(
    'options',
    'Options',
    keywords: <String>[
      'option',
      'calls?',
      'puts?',
      'theta',
      'gamma',
      'delta',
      'expiry',
      'straddle',
      'strangle',
      'iv',
    ],
  ),
  ExploreTabSpec(
    'forex',
    'Forex',
    keywords: <String>[
      'forex',
      'fx',
      'usd',
      'eur',
      'gbp',
      'jpy',
      'inr',
      'currenc',
      'dollar',
    ],
    wireKeys: <String>['forex', 'currenc', 'fx'],
  ),
  ExploreTabSpec(
    'futures',
    'Futures',
    keywords: <String>[
      'future',
      'commodit',
      'gold',
      'crude',
      'oil',
      'silver',
      'es',
      'nq',
    ],
    wireKeys: <String>['commod', 'futur'],
  ),
  ExploreTabSpec(
    'strategies',
    'Strategies',
    keywords: <String>[
      'strateg',
      'setup',
      'playbook',
      'backtest',
      'swing',
      'breakout',
      'scalp',
      'signal',
    ],
  ),
];

/// X-style Explore: search bar, scrollable category tabs, trends, who-to-follow
/// and trending posts. Tab selection and per-tab scroll position are preserved.
class CommunityExploreView extends StatefulWidget {
  const CommunityExploreView({
    super.key,
    required this.repository,
    this.onPostTap,
    this.onAuthorTap,
    this.onOpenRef,
    this.onTagTap,
    this.onSearchTap,
    this.searchQuery,
  });

  final CommunityRepository repository;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final ValueChanged<String>? onTagTap;

  /// Invoked when the search bar is tapped (opens the community search page).
  final VoidCallback? onSearchTap;
  final String? searchQuery;

  @override
  State<CommunityExploreView> createState() => _CommunityExploreViewState();
}

class _CommunityExploreViewState extends State<CommunityExploreView> {
  int _tab = 0;
  final Set<int> _built = <int>{0};
  final Map<int, ScrollController> _controllers = <int, ScrollController>{};
  final Map<String, int> _visiblePostLimitByTab = <String, int>{};
  static const int _initialVisiblePosts = 3;

  List<AppStrategy> _publicStrategies = const <AppStrategy>[];
  List<AppNote> _publicNotes = const <AppNote>[];
  List<AppTrade> _publicEntries = const <AppTrade>[];
  bool _loadingPublicRecords = true;

  String get _query => widget.searchQuery?.trim() ?? '';

  ScrollController _controller(int i) =>
      _controllers.putIfAbsent(i, () => ScrollController());

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onDataChanged);
    _loadPublicRecords();
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onDataChanged);
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    try {
      await Future.wait([
        widget.repository.fetchFromSupabase(),
        _loadPublicRecords(),
      ]);
    } catch (e) {
      if (mounted) {
        UiToast.error(context, title: 'Refresh failed', message: '$e');
      }
      return;
    }
    if (mounted && widget.repository.refreshError != null) {
      UiToast.error(
        context,
        title: 'Refresh failed',
        message: widget.repository.refreshError!,
      );
    }
  }

  Future<void> _loadPublicRecords() async {
    try {
      final strategies = await StrategiesRepositoryScope.repository
          .fetchPublicStrategies();
      final notes = await NotesRepositoryScope.repository.fetchPublicNotes();
      final entries = await JournalRepositoryScope.repository
          .fetchPublicEntries();
      if (mounted) {
        setState(() {
          _publicStrategies = strategies;
          _publicNotes = notes;
          _publicEntries = entries;
          _loadingPublicRecords = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPublicRecords = false);
    }
  }

  // ---------------------------------------------------------------- data

  /// Real trends from the repository; derived from post hashtags/tickers when
  /// the repository has none.
  List<CommunityTrendItem> get _allTrends {
    final repoTrends = widget.repository.trending;
    if (repoTrends.isNotEmpty) return repoTrends;
    final counts = <String, int>{};
    for (final p in widget.repository.forYouPosts) {
      for (final t in p.tags) {
        final k = t.startsWith('#') ? t : '#$t';
        counts[k] = (counts[k] ?? 0) + 1;
      }
      for (final t in p.tickers) {
        final k = t.startsWith('\$') ? t : '\$$t';
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in sorted.take(20))
        CommunityTrendItem(
          id: 'derived-${e.key}',
          topic: e.key,
          category: 'Trending',
          postCount: '${e.value} ${e.value == 1 ? 'post' : 'posts'}',
        ),
    ];
  }

  bool _matchesQuery(String text) =>
      _query.isEmpty || text.toLowerCase().contains(_query.toLowerCase());

  List<CommunityTrendItem> _trendsFor(ExploreTabSpec spec) {
    final pattern = spec.pattern;
    return _allTrends.where((t) {
      if (!_matchesQuery('${t.topic} ${t.category}')) return false;
      return pattern == null || pattern.hasMatch('${t.topic} ${t.category}');
    }).toList();
  }

  List<CommunityPost> _postsFor(ExploreTabSpec spec) {
    final pattern = spec.pattern;
    return widget.repository.forYouPosts.where((p) {
      if (!_matchesQuery(
        '${p.body} ${p.tags.join(' ')} ${p.tickers.join(' ')}',
      )) {
        return false;
      }
      if (pattern == null) return true;
      return pattern.hasMatch(
        '${p.tags.join(' ')} ${p.tickers.join(' ')} ${p.body}',
      );
    }).toList();
  }

  Map<String, List<CommunityNewsItem>> _wireFor(ExploreTabSpec spec) {
    final keys = spec.wireKeys;
    if (keys == null) return const {};
    return {
      for (final e in widget.repository.newsByCategory.entries)
        if (keys.any((k) => e.key.toLowerCase().contains(k)))
          e.key: e.value
              .where(
                (i) => _matchesQuery(
                  '${i.headline} ${i.summary} ${i.relatedTickers.join(' ')}',
                ),
              )
              .toList(),
    }..removeWhere((_, v) => v.isEmpty);
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        final Widget pillBar = CommunityPillTabBar(
          key: const ValueKey('explore-category-tabs'),
          tabs: [for (final t in kExploreTabs) t.label],
          selectedIndex: _tab,
          onChanged: (i) => setState(() {
            _tab = i;
            _built.add(i);
          }),
        );
        final Widget tabBody = IndexedStack(
          index: _tab,
          children: [
            for (var i = 0; i < kExploreTabs.length; i++)
              _built.contains(i)
                  ? _tabBody(context, i, wide)
                  : const SizedBox.shrink(),
          ],
        );
        if (!wide) {
          return CommunityFloatingTabShell(
            tabBar: pillBar,
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.sz(680)),
                child: tabBody,
              ),
            ),
          );
        }
        final column = CommunityFloatingTabShell(
          tabBar: pillBar,
          body: tabBody,
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.sz(680)),
                child: column,
              ),
            ),
            UiGap.h(theme.spacing.md),
            SizedBox(
              width: context.sz(320),
              child: ListView(
                key: const ValueKey('explore-right-rail'),
                padding: EdgeInsets.symmetric(
                  vertical: context.sp(theme.spacing.sm),
                ),
                children: [
                  if (widget.repository.isLoading &&
                      widget.repository.forYouPosts.isEmpty) ...[
                    _skeletons(context, theme),
                  ] else ...[
                    _trendsCard(context, theme, _trendsFor(kExploreTabs[0])),
                    UiGap.v(theme.spacing.md),
                    _whoToFollowCard(context, theme),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tabBody(BuildContext context, int index, bool wide) {
    final theme = context.ui;
    final spec = kExploreTabs[index];
    final repo = widget.repository;
    final isForYou = spec.id == 'for_you';
    final isTrending = spec.id == 'trending';
    final isStrategies = spec.id == 'strategies';
    final trends = _trendsFor(spec);
    final posts = isTrending ? const <CommunityPost>[] : _postsFor(spec);
    final wire = _wireFor(spec);
    final loading =
        (repo.isLoading && repo.forYouPosts.isEmpty) ||
        (_loadingPublicRecords &&
            repo.forYouPosts.isEmpty &&
            trends.isEmpty &&
            wire.isEmpty);
    final hasError = repo.refreshError != null && repo.forYouPosts.isEmpty;

    Widget header(BuildContext _) {
      if (loading) return _skeletons(context, theme);
      if (hasError) {
        return UiEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          message: repo.refreshError,
          actionLabel: 'Retry',
          onActionPressed: _refresh,
        );
      }
      final children = <Widget>[];
      if (isForYou && !wide) {
        children
          ..add(_trendsCard(context, theme, trends, limit: 5))
          ..add(UiGap.v(theme.spacing.md))
          ..add(_whoToFollowCard(context, theme))
          ..add(UiGap.v(theme.spacing.md));
      } else if (isForYou && wide) {
        // Trends and who-to-follow live in the right rail on wide screens.
      } else if (isTrending) {
        children.add(_trendsCard(context, theme, trends, title: 'Trending'));
        if (trends.isEmpty) {
          children.add(
            const UiEmptyState(
              title: 'Nothing is trending yet',
              message: 'Trends appear as traders post hashtags and tickers.',
              icon: Icons.trending_up_rounded,
            ),
          );
        }
      } else {
        if (trends.isNotEmpty) {
          children
            ..add(_trendsCard(context, theme, trends, title: spec.label))
            ..add(UiGap.v(theme.spacing.md));
        }
        for (final entry in wire.entries) {
          children
            ..add(
              UiDeferred(
                estimatedHeight: 380,
                builder: (_) => UiCard(
                  key: ValueKey('wire-category-${entry.key}'),
                  title: marketFieldLabel(entry.key),
                  trailing: UiButton(
                    label: 'View all',
                    variant: UiVariant.ghost,
                    size: UiSize.sm,
                    onPressed: () => _viewAll(entry.key, entry.value),
                  ),
                  child: _newsItem(context, entry.value.first),
                ),
              ),
            )
            ..add(UiGap.v(theme.spacing.md));
        }
        if (isStrategies) {
          children
            ..add(_buildPublicRecordsSection(context, theme))
            ..add(UiGap.v(theme.spacing.md));
        }
      }
      if (!isTrending) {
        if (posts.isNotEmpty) {
          children.add(
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: Text(
                isForYou ? 'Trending posts' : '${spec.label} posts',
                style: context.uiText.heading,
              ),
            ),
          );
        } else if (spec.id != 'news' &&
            !(isStrategies &&
                (_publicStrategies.isNotEmpty ||
                    _publicNotes.isNotEmpty ||
                    _publicEntries.isNotEmpty)) &&
            trends.isEmpty &&
            wire.isEmpty) {
          children.add(
            UiEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No ${spec.label.toLowerCase()} posts yet',
              message: 'Try another category or clear your search.',
            ),
          );
        } else if (spec.id == 'news' && wire.isEmpty) {
          children.add(
            UiEmptyState(
              icon: Icons.newspaper_rounded,
              title: repo.marketDataError ?? 'No headlines available',
              message: 'Market news will appear when the snapshot is ready.',
            ),
          );
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    final int visibleLimit =
        _visiblePostLimitByTab[spec.id] ?? _initialVisiblePosts;
    final int visibleCount = loading || hasError
        ? 0
        : (posts.length < visibleLimit ? posts.length : visibleLimit);
    final bool hasMorePosts =
        !loading && !hasError && posts.length > visibleCount;
    final int remainingCount = posts.length - visibleCount;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: UiLazyList(
        key: PageStorageKey<String>('explore-list-${spec.id}-$_query'),
        controller: _controller(index),
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        itemCount: visibleCount + (hasMorePosts ? 1 : 0),
        headerBuilder: header,
        itemBuilder: (_, i) {
          if (hasMorePosts && i == visibleCount) {
            return Padding(
              padding: EdgeInsets.only(
                top: context.sp(theme.spacing.xs),
                bottom: context.sp(theme.spacing.md),
              ),
              child: UiButton(
                label: 'Show more ($remainingCount more)',
                leadingIcon: Icons.expand_more_rounded,
                variant: UiVariant.outline,
                size: UiSize.md,
                expand: true,
                onPressed: () {
                  setState(() {
                    _visiblePostLimitByTab[spec.id] = visibleCount + 5;
                  });
                },
              ),
            );
          }
          final post = posts[i];
          return Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            child: CommunityPostCard(
              key: ValueKey('explore-${spec.id}-${post.id}'),
              post: post,
              variant: CommunityPostCardVariant.boxed,
              onTap: () => widget.onPostTap?.call(post),
              onLike: () => repo.toggleLike(post.id),
              onRepost: () => repo.toggleRepost(post.id),
              onBookmark: () => repo.toggleBookmark(post.id),
              onAuthorTap: widget.onAuthorTap,
              onOpenRef: widget.onOpenRef,
              onTagTap: widget.onTagTap,
            ),
          );
        },
      ),
    );
  }

  Widget _skeletons(BuildContext context, UiTheme theme) => Column(
    key: const ValueKey('explore-loading'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      UiSkeleton.card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UiSkeleton.heading(width: 140),
            UiGap.v(theme.spacing.md),
            for (var i = 0; i < 4; i++) ...[
              UiSkeleton.text(width: 110, height: 11),
              UiGap.v(theme.spacing.xxs),
              UiSkeleton.text(width: 180, height: 15),
              UiGap.v(theme.spacing.sm),
            ],
          ],
        ),
      ),
      UiGap.v(theme.spacing.md),
      for (var i = 0; i < 3; i++) ...[
        UiSkeleton.card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UiSkeleton.avatar(size: 36),
                  UiGap.h(theme.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UiSkeleton.text(width: 130, height: 13),
                        UiGap.v(theme.spacing.xxs),
                        UiSkeleton.text(width: 90, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
              UiGap.v(theme.spacing.sm),
              UiSkeleton.text(width: double.infinity, height: 13),
              UiGap.v(theme.spacing.xs),
              UiSkeleton.text(width: 240, height: 13),
            ],
          ),
        ),
        UiGap.v(theme.spacing.sm),
      ],
    ],
  );

  // ------------------------------------------------------------- trends

  Widget _trendsCard(
    BuildContext context,
    UiTheme theme,
    List<CommunityTrendItem> trends, {
    int? limit,
    String title = 'Trends for you',
  }) {
    if (trends.isEmpty) return const SizedBox.shrink();
    final shown = limit == null ? trends : trends.take(limit).toList();
    return UiCard(
      key: ValueKey('explore-trends-$title'),
      title: title,
      trailing: limit != null && trends.length > limit
          ? UiButton(
              key: const ValueKey('explore-trends-show-more'),
              label: 'Show more',
              variant: UiVariant.link,
              size: UiSize.sm,
              onPressed: () => setState(() {
                _tab = 1;
                _built.add(1);
              }),
            )
          : null,
      child: Wrap(
        spacing: context.sp(theme.spacing.sm),
        runSpacing: context.sp(theme.spacing.sm),
        children: <Widget>[
          for (final CommunityTrendItem item in shown)
            _ExploreTrendTag(item: item, onTap: () => _openTopic(item.topic)),
        ],
      ),
    );
  }

  // ------------------------------------------------------ who to follow

  Widget _whoToFollowCard(BuildContext context, UiTheme theme) {
    final authors = widget.repository.suggestedTraders
        .where((a) => a.id != widget.repository.currentAuthor.id)
        .take(3)
        .toList();
    if (authors.isEmpty) return const SizedBox.shrink();
    return UiCard(
      key: const ValueKey('explore-who-to-follow'),
      title: 'Who to follow',
      child: Column(
        children: [
          for (final a in authors)
            InkWell(
              key: ValueKey('explore-author-${a.id}'),
              onTap: () => widget.onAuthorTap?.call(a),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: context.sp(theme.spacing.xs),
                ),
                child: Row(
                  children: [
                    UiAvatar(
                      name: a.displayName,
                      imageUrl: a.avatarUrl,
                      size: UiSize.md,
                    ),
                    UiGap.h(theme.spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  a.displayName,
                                  style: context.uiText.bodyStrong,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (a.verified) ...[
                                UiGap.h(theme.spacing.xxs),
                                Icon(
                                  Icons.verified_rounded,
                                  size: context.sz(16),
                                  color: theme.colors.primary,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '@${a.handle}',
                            style: context.uiText.caption.copyWith(
                              color: theme.colors.foregroundMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    CommunityFollowButton(
                      repository: widget.repository,
                      authorId: a.id,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPublicRecordsSection(BuildContext context, UiTheme theme) {
    if (_loadingPublicRecords) {
      return const UiSkeleton(height: 120);
    }
    if (_publicStrategies.isEmpty &&
        _publicNotes.isEmpty &&
        _publicEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    return UiCard(
      title: 'Community Playbooks, Research & Trade Logs',
      subtitle:
          'Public trading systems, research notes, and trade logs shared by community traders',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final entry in _publicEntries.take(3)) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: context.sp(theme.spacing.xs),
              ),
              child: UiCard(
                variant: UiCardVariant.outlined,
                onTap: () {
                  widget.onOpenRef?.call(
                    AppLinkRef(
                      kind: AppLinkKind.journal,
                      id: entry.id,
                      title: entry.displayTitle,
                      isPublicContext: true,
                    ),
                  );
                },
                child: Row(
                  children: <Widget>[
                    Icon(
                      entry.outcome == AppOutcome.win
                          ? Icons.trending_up_rounded
                          : (entry.outcome == AppOutcome.loss
                                ? Icons.trending_down_rounded
                                : Icons.schedule_rounded),
                      color: entry.outcome == AppOutcome.win
                          ? theme.colors.success
                          : (entry.outcome == AppOutcome.loss
                                ? theme.colors.danger
                                : theme.colors.warning),
                      size: context.sz(24),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            entry.displayTitle,
                            style: context.uiText.bodyStrong,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: <Widget>[
                              UiBadge(
                                label: entry.side.name.toUpperCase(),
                                intent: entry.side == AppSide.long
                                    ? UiIntent.success
                                    : UiIntent.danger,
                                variant: UiBadgeVariant.soft,
                              ),
                              const SizedBox(width: 6),
                              UiBadge(
                                label: entry.outcome.name.toUpperCase(),
                                intent: entry.outcome == AppOutcome.win
                                    ? UiIntent.success
                                    : (entry.outcome == AppOutcome.loss
                                          ? UiIntent.danger
                                          : UiIntent.warning),
                                variant: UiBadgeVariant.soft,
                              ),
                              if (entry.pnl != 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '${entry.pnl >= 0 ? '+' : ''}₹${entry.pnl.toStringAsFixed(2)}',
                                  style: context.uiText.caption.copyWith(
                                    color: entry.pnl >= 0
                                        ? theme.colors.success
                                        : theme.colors.danger,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const UiBadge(
                      label: 'Public',
                      intent: UiIntent.success,
                      variant: UiBadgeVariant.soft,
                    ),
                  ],
                ),
              ),
            ),
          ],
          for (final strategy in _publicStrategies.take(4)) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: context.sp(theme.spacing.xs),
              ),
              child: UiCard(
                variant: UiCardVariant.outlined,
                onTap: () {
                  widget.onOpenRef?.call(
                    AppLinkRef(
                      kind: AppLinkKind.strategy,
                      id: strategy.id,
                      title: strategy.name,
                      isPublicContext: true,
                    ),
                  );
                },
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.psychology_outlined,
                      color: theme.colors.primary,
                      size: context.sz(24),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strategy.name.isNotEmpty
                                ? strategy.name
                                : 'Untitled Playbook',
                            style: context.uiText.bodyStrong,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: <Widget>[
                              const UiBadge(
                                label: 'Strategy',
                                intent: UiIntent.primary,
                                variant: UiBadgeVariant.soft,
                              ),
                              const SizedBox(width: 6),
                              if (strategy.winRate > 0)
                                Text(
                                  'Win: ${strategy.winRate.toStringAsFixed(1)}%',
                                  style: context.uiText.caption.copyWith(
                                    color: theme.colors.success,
                                  ),
                                ),
                              if (strategy.avgR != 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  'Avg R: ${strategy.avgR > 0 ? '+' : ''}${strategy.avgR.toStringAsFixed(2)}R',
                                  style: context.uiText.caption.copyWith(
                                    color: theme.colors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const UiBadge(
                      label: 'Public',
                      intent: UiIntent.success,
                      variant: UiBadgeVariant.soft,
                    ),
                  ],
                ),
              ),
            ),
          ],
          for (final note in _publicNotes.take(4)) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: context.sp(theme.spacing.xs),
              ),
              child: UiCard(
                variant: UiCardVariant.outlined,
                onTap: () {
                  widget.onOpenRef?.call(
                    AppLinkRef(
                      kind: AppLinkKind.note,
                      id: note.id,
                      title: note.title,
                      isPublicContext: true,
                    ),
                  );
                },
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.article_outlined,
                      color: theme.colors.info,
                      size: context.sz(24),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            note.title.isNotEmpty
                                ? note.title
                                : 'Untitled Research Note',
                            style: context.uiText.bodyStrong,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: <Widget>[
                              UiBadge(
                                label: note.noteType.label,
                                intent: UiIntent.info,
                                variant: UiBadgeVariant.soft,
                              ),
                              const SizedBox(width: 6),
                              if (note.wordCount > 0)
                                Text(
                                  '${note.wordCount} words',
                                  style: context.uiText.caption.copyWith(
                                    color: theme.colors.foregroundMuted,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const UiBadge(
                      label: 'Public',
                      intent: UiIntent.success,
                      variant: UiBadgeVariant.soft,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _viewAll(String category, List<CommunityNewsItem> items) {
    _openExplorePanel(
      title: marketFieldLabel(category),
      page: CommunityMarketWirePage(
        category: category,
        items: items,
        snapshot: widget.repository.marketSnapshot,
      ),
    );
  }

  void _openExplorePanel({required String title, required Widget page}) {
    if (context.uiRes.isDesktop) {
      showSettingsSideSheet<void>(
        context,
        title: title,
        desktopWidthRatio: 0.48,
        minDesktopWidth: 540,
        maxWidth: 760,
        child: LayoutBuilder(
          builder: (panelContext, constraints) => MediaQuery(
            data: MediaQuery.of(
              panelContext,
            ).copyWith(size: Size(constraints.maxWidth, constraints.maxHeight)),
            child: page,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openTopic(String topic) => _openExplorePanel(
    title: topic,
    page: CommunityHashtagPage(
      tag: topic,
      repository: widget.repository,
      currentUser: widget.repository.currentAuthor,
      onPostTap: widget.onPostTap,
      onAuthorTap: widget.onAuthorTap,
      onOpenRef: widget.onOpenRef,
      onTagTap: widget.onTagTap,
    ),
  );

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

class _ExploreTrendTag extends StatelessWidget {
  const _ExploreTrendTag({required this.item, required this.onTap});

  final CommunityTrendItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isTicker = item.topic.trimLeft().startsWith(r'$');
    final String postLabel = switch (item.postCount?.trim()) {
      null || '' => 'Open trend',
      final String value when value.contains('post') => value,
      final String value => '$value posts',
    };
    final String category = item.category.toLowerCase().contains('trending')
        ? item.category
        : '${item.category} · Trending';

    return UiBadge(
      key: ValueKey('explore-trend-${item.id}'),
      label: item.topic,
      icon: isTicker ? Icons.candlestick_chart_rounded : Icons.tag_rounded,
      trailingIcon: Icons.arrow_outward_rounded,
      intent: isTicker ? UiIntent.primary : UiIntent.info,
      variant: UiBadgeVariant.soft,
      size: UiSize.md,
      tooltip: '$category · $postLabel',
      onTap: onTap,
    );
  }
}

/// A category-specific feed: only visible rows are built, with automatic batches.
class CommunityMarketWirePage extends StatelessWidget {
  const CommunityMarketWirePage({
    super.key,
    required this.category,
    required this.items,
    this.snapshot,
    this.showHeader = true,
  });
  final String category;
  final List<CommunityNewsItem> items;
  final MarketSnapshot? snapshot;
  final bool showHeader;

  List<CommunityNewsItem> _deduplicatedItems() {
    final seen = <String>{};
    final result = <CommunityNewsItem>[];
    for (final item in items) {
      final key = item.headline.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      result.add(item);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _deduplicatedItems();
    return Scaffold(
      body: SafeArea(
        top: showHeader,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader)
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
                    UiBadge(label: '${visibleItems.length} articles'),
                  ],
                ),
              ),
            Expanded(
              child: UiLazyList(
                itemCount: visibleItems.length,
                maxWidth: context.sz(900),
                padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
                itemBuilder: (_, index) => MarketNewsCard(
                  article: communityMarketArticle(visibleItems[index]),
                  snapshot:
                      snapshot ??
                      const MarketSnapshot(instruments: [], articles: []),
                  row: true,
                  onTap: () => CommunityArticleSheet.show(
                    context,
                    article: visibleItems[index],
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
}
