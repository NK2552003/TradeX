import 'package:alphajournal/core/navigation/feature_location_scope.dart';
import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart' hide CommunityPostCard;
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_widgets.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_side_sheet.dart';

/// The central Home Feed view of the community platform, modeled on Twitter/X.
class CommunityFeedView extends StatefulWidget {
  const CommunityFeedView({
    super.key,
    required this.repository,
    required this.currentUser,
    this.onPostTap,
    this.onAuthorTap,
    this.onCompose,
    this.onOpenRef,
    this.onTagTap,
    this.searchQuery,
  });

  final CommunityRepository repository;
  final CommunityAuthor currentUser;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final ValueChanged<String>? onTagTap;
  final String? searchQuery;

  /// Called when the compact mobile compose trigger is tapped.
  /// On desktop/tablet the full [CommunityComposerCard] is rendered inline
  /// instead; this callback is only invoked from the mobile compact row.
  final VoidCallback? onCompose;

  @override
  State<CommunityFeedView> createState() => _CommunityFeedViewState();
}

class _CommunityFeedViewState extends State<CommunityFeedView>
    with SingleTickerProviderStateMixin {
  late TabController _subTabController;
  late final ScrollController _forYouScrollController = ScrollController();
  int _newPostsCount = 0;
  final List<CommunityAuthor> _newPostAuthors = <CommunityAuthor>[];
  final Set<String> _seenPostIds = <String>{};
  bool _initializedSeenPosts = false;

  static const List<String> _subTabs = <String>[
    'For you',
    'Following',
    'Signals & Setups',
    'Market News',
    'Crypto',
    'Equities',
  ];

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: _subTabs.length, vsync: this);
    _subTabController.addListener(_routeSubTab);
    _forYouScrollController.addListener(_onFeedScroll);
    final initial = widget.repository.forYouPosts;
    if (initial.isNotEmpty) {
      _seenPostIds.addAll(initial.map((p) => p.id));
      _initializedSeenPosts = true;
    }
    widget.repository.addListener(_onDataChanged);
  }

  void _onFeedScroll() {
    if (!_forYouScrollController.hasClients) return;
    final pos = _forYouScrollController.position;
    if (pos.pixels <= 16 && _newPostsCount > 0) {
      setState(() {
        _newPostsCount = 0;
        _newPostAuthors.clear();
        _seenPostIds.addAll(widget.repository.forYouPosts.map((p) => p.id));
      });
    }
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      unawaited(widget.repository.loadMorePosts());
    }
  }

  static const _routeTabs = [
    'for-you',
    'following',
    'signals',
    'news',
    'crypto',
    'equities',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final index = FeatureLocationScope.maybeOf(
      context,
    )?.selection('community_feed', _routeTabs);
    if (index != null && index != _subTabController.index) {
      _subTabController.index = index;
    }
  }

  void _routeSubTab() {
    if (!mounted || _subTabController.indexIsChanging) return;
    final route = FeatureLocationScope.maybeOf(context);
    final selected = route?.selection('community_feed', _routeTabs);
    if (route != null &&
        selected != null &&
        selected != _subTabController.index) {
      route.select('community_feed', _routeTabs[_subTabController.index]);
    }
  }

  @override
  void dispose() {
    _forYouScrollController.removeListener(_onFeedScroll);
    _forYouScrollController.dispose();
    _subTabController.removeListener(_routeSubTab);
    _subTabController.dispose();
    widget.repository.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    final List<CommunityPost> current = widget.repository.forYouPosts;
    if (!_initializedSeenPosts) {
      if (current.isNotEmpty) {
        _seenPostIds.addAll(current.map((p) => p.id));
        _initializedSeenPosts = true;
      }
      if (mounted) setState(() {});
      return;
    }

    final List<CommunityPost> arrived = current
        .where(
          (p) =>
              p.isPublic &&
              !_seenPostIds.contains(p.id) &&
              p.author.id != widget.currentUser.id,
        )
        .toList();

    if (arrived.isNotEmpty) {
      for (final p in arrived) {
        _seenPostIds.add(p.id);
        if (!_newPostAuthors.any((a) => a.id == p.author.id)) {
          _newPostAuthors.insert(0, p.author);
        }
      }
      if (_newPostAuthors.length > 5) {
        _newPostAuthors.removeRange(5, _newPostAuthors.length);
      }
      _newPostsCount += arrived.length;
    } else {
      // Track any newly created local posts by current user as already seen.
      for (final p in current) {
        if (p.author.id == widget.currentUser.id) {
          _seenPostIds.add(p.id);
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    try {
      await widget.repository.fetchFromSupabase();
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

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;

    return CommunityFloatingTabShell(
      banner: widget.repository.refreshError != null
          ? UiCallout(
              title: 'Community could not refresh',
              message: widget.repository.refreshError!,
              intent: UiIntent.warning,
            )
          : null,
      tabBar: _buildFloatingBar(context, theme, isMobile),
      body: TabBarView(
        controller: _subTabController,
        physics: context.uiRes.isDesktop
            ? const NeverScrollableScrollPhysics()
            : null,
        children: <Widget>[
          // Tab 0: For you
          _CommunityKeepAliveTab(child: _buildForYouTab()),
          // Tab 1: Following
          _CommunityKeepAliveTab(child: _buildFollowingTab()),
          // Tab 2: Signals & Setups
          _CommunityKeepAliveTab(child: _buildSignalsTab()),
          // Tab 3: Market News
          _CommunityKeepAliveTab(child: _buildNewsTab()),
          // Tab 4: Crypto
          _CommunityKeepAliveTab(child: _buildCryptoTab()),
          // Tab 5: Equities
          _CommunityKeepAliveTab(child: _buildEquitiesTab()),
        ],
      ),
    );
  }

  /// Floating capsule bar with frosted glass, hairline border, soft glow indicator,
  /// and trailing tab customizer button.
  Widget _buildFloatingBar(BuildContext context, UiTheme theme, bool isMobile) {
    return Container(
      height: context.sz(44),
      decoration: BoxDecoration(
        borderRadius: context.radius(theme.radii.pill),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: context.radius(theme.radii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colors.surface.withValues(alpha: 0.88),
              borderRadius: context.radius(theme.radii.pill),
              border: Border.all(
                color: theme.colors.border.withValues(alpha: 0.7),
                width: theme.borders.hairline,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TabBar(
                    controller: _subTabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: EdgeInsets.zero,
                    labelPadding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.sm),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    splashBorderRadius: context.radius(theme.radii.pill),
                    overlayColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.transparent;
                      }
                      if (states.contains(WidgetState.hovered)) {
                        return theme.colors.primary.withValues(alpha: 0.08);
                      }
                      return null;
                    }),
                    indicator: BoxDecoration(
                      color: theme.colors.primary.withValues(alpha: 0.16),
                      borderRadius: context.radius(theme.radii.pill),
                      border: Border.all(
                        color: theme.colors.primary.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colors.primary.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    dividerColor: Colors.transparent,
                    labelColor: theme.colors.primary,
                    unselectedLabelColor: theme.colors.foregroundMuted,
                    labelStyle: context.uiText.bodyStrong.copyWith(
                      fontSize: context.fs(isMobile ? 12.5 : 13.5),
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: context.uiText.body.copyWith(
                      fontSize: context.fs(isMobile ? 12.5 : 13.5),
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: _subTabs.map((label) {
                      return Tab(
                        height: context.sz(34),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(label),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Container(
                  height: context.sz(18),
                  width: theme.borders.hairline,
                  color: theme.colors.border.withValues(alpha: 0.6),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                ),
                UiIconButton(
                  icon: Icons.add_rounded,
                  size: UiSize.xs,
                  tooltip: 'Customize Feed Tabs',
                  onPressed: () {
                    CommunityFeedCustomizerDialog.show(
                      context,
                      repository: widget.repository,
                    );
                  },
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<CommunityPost> _filter(List<CommunityPost> raw) {
    final q = widget.searchQuery?.trim().toLowerCase();
    if (q == null || q.isEmpty) return raw;
    return raw.where((p) {
      return p.body.toLowerCase().contains(q) ||
          p.tickers.any((t) => t.toLowerCase().contains(q)) ||
          p.tags.any((t) => t.toLowerCase().contains(q)) ||
          p.author.displayName.toLowerCase().contains(q) ||
          p.author.handle.toLowerCase().contains(q);
    }).toList();
  }

  void _openComposerWithQuote(BuildContext context, CommunityPost post) {
    final isMobile = context.uiRes.isMobile;
    if (isMobile) {
      final UiTheme theme = context.ui;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: theme.colors.overlay,
        builder: (BuildContext ctx) => CommunityDensityScope(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: SingleChildScrollView(
              child: CommunityComposerCard(
                author: widget.currentUser,
                repository: widget.repository,
                quotedPost: post,
                isDrawerTile: true,
                onPostCreated: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ),
      );
    } else {
      showSettingsSideSheet<void>(
        context,
        title: 'Quote Post',
        subtitle: 'Share your perspective on this post',
        desktopWidthRatio: 0.52,
        maxWidth: 720,
        minDesktopWidth: 540,
        scrollable: true,
        child: CommunityComposerCard(
          author: widget.currentUser,
          repository: widget.repository,
          quotedPost: post,
          onPostCreated: () => Navigator.of(context).pop(),
        ),
      );
    }
  }

  void _openComposer(
    BuildContext context, [
    ComposerMode mode = ComposerMode.post,
  ]) {
    final isMobile = context.uiRes.isMobile;
    if (isMobile) {
      if (widget.onCompose != null && mode == ComposerMode.post) {
        widget.onCompose!();
      } else {
        final UiTheme theme = context.ui;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: theme.colors.overlay,
          builder: (BuildContext ctx) => CommunityDensityScope(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: SingleChildScrollView(
                child: CommunityComposerCard(
                  author: widget.currentUser,
                  repository: widget.repository,
                  initialMode: mode,
                  isDrawerTile: true,
                  onPostCreated: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ),
        );
      }
    } else {
      showSettingsSideSheet<void>(
        context,
        title: 'Create Post',
        subtitle: 'Share your thesis, trade setup, or questions with traders',
        desktopWidthRatio: 0.52,
        maxWidth: 720,
        minDesktopWidth: 540,
        scrollable: true,
        child: CommunityComposerCard(
          author: widget.currentUser,
          repository: widget.repository,
          initialMode: mode,
          onPostCreated: () => Navigator.of(context).pop(),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Tab 0: For you
  // ---------------------------------------------------------------------------

  Widget _buildForYouTab({double? topPadding}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final posts = _filter(widget.repository.forYouPosts);
    final double effectiveTop = topPadding ?? context.sp(theme.spacing.sm);

    const Widget liveSpaceBanner = SizedBox.shrink();

    final Widget composeHeader = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        liveSpaceBanner,
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(
              isMobile ? theme.spacing.sm : theme.spacing.md,
            ),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: CommunityComposerTriggerCard(
            onTap: (ComposerMode mode) => _openComposer(context, mode),
          ),
        ),
      ],
    );

    final Widget feedList = CommunityFeedList(
      controller: _forYouScrollController,
      posts: posts,
      header: composeHeader,
      repository: widget.repository,
      currentUser: widget.currentUser,
      isLoading: widget.repository.isLoading,
      showAdvertisements: true,
      padding: EdgeInsets.only(
        top: effectiveTop,
        left: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
        right: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
        bottom: context.sp(theme.spacing.xl),
      ),
      onPostTap: widget.onPostTap,
      onLike: (id) => widget.repository.toggleLike(id),
      onRepost: (id) => widget.repository.toggleRepost(id),
      onBookmark: (id) => widget.repository.toggleBookmark(id),
      onAuthorTap: widget.onAuthorTap,
      onOpenRef: widget.onOpenRef,
      onTagTap: widget.onTagTap,
      onQuote: (post) => _openComposerWithQuote(context, post),
      onRefresh: _refresh,
    );

    final Widget content = Stack(
      children: <Widget>[
        feedList,
        if (_newPostsCount > 0)
          Positioned(
            top: effectiveTop + context.sp(theme.spacing.xs),
            left: 0,
            right: 0,
            child: CommunityNewPostsPill(
              count: _newPostsCount,
              authors: _newPostAuthors,
              onTap: () {
                setState(() {
                  _newPostsCount = 0;
                  _newPostAuthors.clear();
                  _seenPostIds.addAll(
                    widget.repository.forYouPosts.map((p) => p.id),
                  );
                });
                if (_forYouScrollController.hasClients) {
                  _forYouScrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutCubic,
                  );
                }
                unawaited(_refresh());
              },
            ),
          ),
      ],
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(700)),
        child: content,
      ),
    );
  }

  Widget _buildFollowingTab({double? topPadding}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final posts = _filter(widget.repository.followingPosts);
    final double effectiveTop = topPadding ?? context.sp(theme.spacing.sm);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(700)),
        child: CommunityFeedList(
          posts: posts,
          repository: widget.repository,
          currentUser: widget.currentUser,
          padding: EdgeInsets.only(
            top: effectiveTop,
            left: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            right: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            bottom: context.sp(theme.spacing.xl),
          ),
          onPostTap: widget.onPostTap,
          onLike: (id) => widget.repository.toggleLike(id),
          onRepost: (id) => widget.repository.toggleRepost(id),
          onBookmark: (id) => widget.repository.toggleBookmark(id),
          onAuthorTap: widget.onAuthorTap,
          onOpenRef: widget.onOpenRef,
          onTagTap: widget.onTagTap,
          onQuote: (post) => _openComposerWithQuote(context, post),
          onRefresh: _refresh,
          emptyState: const CommunityEmptyState(
            icon: Icons.person_add_outlined,
            title: 'No posts yet',
            message:
                'Follow other traders to see their setups and execution notes here.',
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Signals & Setups
  // ---------------------------------------------------------------------------

  Widget _buildSignalsTab({double? topPadding}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final posts = _filter(widget.repository.signalPosts);
    final double effectiveTop = topPadding ?? context.sp(theme.spacing.sm);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(700)),
        child: CommunityFeedList(
          posts: posts,
          repository: widget.repository,
          currentUser: widget.currentUser,
          padding: EdgeInsets.only(
            top: effectiveTop,
            left: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            right: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            bottom: context.sp(theme.spacing.xl),
          ),
          onPostTap: widget.onPostTap,
          onLike: (id) => widget.repository.toggleLike(id),
          onRepost: (id) => widget.repository.toggleRepost(id),
          onBookmark: (id) => widget.repository.toggleBookmark(id),
          onAuthorTap: widget.onAuthorTap,
          onOpenRef: widget.onOpenRef,
          onTagTap: widget.onTagTap,
          onQuote: (post) => _openComposerWithQuote(context, post),
          onRefresh: _refresh,
          emptyState: const CommunityEmptyState(
            icon: Icons.candlestick_chart_rounded,
            title: 'No trade signals found',
            message:
                'Published trades with entry, exit and stop levels will appear here.',
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Market News
  // ---------------------------------------------------------------------------

  Widget _buildNewsTab({double? topPadding}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final news = widget.repository.news;
    final double effectiveTop = topPadding ?? context.sp(theme.spacing.sm);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(700)),
        child: UiLazyList(
          padding: EdgeInsets.only(
            top: effectiveTop,
            left: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            right: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            bottom: context.sp(theme.spacing.xl),
          ),
          itemCount: news.length,
          itemBuilder: (BuildContext context, int index) {
            final item = news[index];
            final sentimentIntent = item.sentimentScore > 0.3
                ? UiIntent.success
                : (item.sentimentScore < -0.2
                      ? UiIntent.danger
                      : UiIntent.info);

            return Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: UiCard(
                padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        UiBadge(
                          label: item.category,
                          intent: sentimentIntent,
                          variant: UiBadgeVariant.solid,
                          size: UiSize.xs,
                        ),
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        Expanded(
                          child: Text(
                            '${item.source} · ${AppTokens.relativeTime(item.publishedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.caption.copyWith(
                              color: theme.colors.foregroundSubtle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    Text(
                      item.headline,
                      style: context.uiText.heading.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.summary != null &&
                        item.summary!.trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      Text(
                        item.summary!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.body.copyWith(
                          color: theme.colors.foregroundMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (item.relatedTickers.isNotEmpty) ...<Widget>[
                      SizedBox(height: context.sp(theme.spacing.sm)),
                      Wrap(
                        spacing: context.sp(theme.spacing.xs),
                        children: item.relatedTickers.map((t) {
                          return UiBadge(
                            label: '\$$t',
                            intent: UiIntent.primary,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Crypto
  // ---------------------------------------------------------------------------

  Widget _buildCryptoTab({double? topPadding}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final cryptoTickers = <String>{'BTC', 'ETH', 'SOL', 'DOGE', 'USDINR'};
    final posts = widget.repository.forYouPosts.where((p) {
      return p.tickers.any((t) => cryptoTickers.contains(t.toUpperCase())) ||
          p.tags.any((tag) => tag.toLowerCase().contains('crypto'));
    }).toList();
    final double effectiveTop = topPadding ?? context.sp(theme.spacing.sm);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(700)),
        child: CommunityFeedList(
          posts: posts,
          repository: widget.repository,
          currentUser: widget.currentUser,
          padding: EdgeInsets.only(
            top: effectiveTop,
            left: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            right: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            bottom: context.sp(theme.spacing.xl),
          ),
          onPostTap: widget.onPostTap,
          onLike: (id) => widget.repository.toggleLike(id),
          onRepost: (id) => widget.repository.toggleRepost(id),
          onBookmark: (id) => widget.repository.toggleBookmark(id),
          onAuthorTap: widget.onAuthorTap,
          onOpenRef: widget.onOpenRef,
          onTagTap: widget.onTagTap,
          onQuote: (post) => _openComposerWithQuote(context, post),
          onRefresh: _refresh,
          emptyState: const CommunityEmptyState(
            icon: Icons.currency_bitcoin_rounded,
            title: 'No crypto setups found',
            message:
                'Posts referencing \$BTC, \$ETH, or crypto setups will appear here.',
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 5: Equities
  // ---------------------------------------------------------------------------

  Widget _buildEquitiesTab({double? topPadding}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final posts = widget.repository.forYouPosts.where((p) {
      return p.tickers.any(
        (t) => !{'BTC', 'ETH', 'SOL', 'DOGE'}.contains(t.toUpperCase()),
      );
    }).toList();
    final double effectiveTop = topPadding ?? context.sp(theme.spacing.sm);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(700)),
        child: CommunityFeedList(
          posts: posts,
          repository: widget.repository,
          currentUser: widget.currentUser,
          padding: EdgeInsets.only(
            top: effectiveTop,
            left: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            right: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            bottom: context.sp(theme.spacing.xl),
          ),
          onPostTap: widget.onPostTap,
          onLike: (id) => widget.repository.toggleLike(id),
          onRepost: (id) => widget.repository.toggleRepost(id),
          onBookmark: (id) => widget.repository.toggleBookmark(id),
          onAuthorTap: widget.onAuthorTap,
          onOpenRef: widget.onOpenRef,
          onTagTap: widget.onTagTap,
          onQuote: (post) => _openComposerWithQuote(context, post),
          onRefresh: _refresh,
          emptyState: const CommunityEmptyState(
            icon: Icons.show_chart_rounded,
            title: 'No equities setups found',
            message: 'Posts tagged with equity tickers will appear here.',
          ),
        ),
      ),
    );
  }
}

/// Helper wrapper that preserves scroll position and widget state across sub-tabs.
class _CommunityKeepAliveTab extends StatefulWidget {
  const _CommunityKeepAliveTab({required this.child});
  final Widget child;

  @override
  State<_CommunityKeepAliveTab> createState() => _CommunityKeepAliveTabState();
}

class _CommunityKeepAliveTabState extends State<_CommunityKeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
