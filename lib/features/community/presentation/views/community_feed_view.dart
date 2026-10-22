import 'package:tradex/core/navigation/feature_location_scope.dart';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/presentation/widgets/community_live_space_card.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_widgets.dart';

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

  static const List<String> _subTabs = <String>[
    'For you',
    'Live Spaces',
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
    widget.repository.addListener(_onDataChanged);
  }

  static const _routeTabs = [
    'for-you',
    'live',
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
    _forYouScrollController.dispose();
    _subTabController.removeListener(_routeSubTab);
    _subTabController.dispose();
    widget.repository.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() => setState(() {});

  Future<void> _refresh() async {
    await widget.repository.fetchFromSupabase();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.repository.refreshError != null)
          UiCallout(
            title: 'Community could not refresh',
            message: widget.repository.refreshError!,
            intent: UiIntent.warning,
          ),
        // Full width top bar tab toggle spanning across the centered panel
        _buildTopBar(context, theme, isMobile),

        // Sub-Tab Content Views (feeds centered at maxWidth 700px beneath the bar)
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            physics: context.uiRes.isDesktop
                ? const NeverScrollableScrollPhysics()
                : null,
            children: <Widget>[
              // Tab 0: For you
              _CommunityKeepAliveTab(child: _buildForYouTab()),
              // Tab 1: Live Spaces
              _CommunityKeepAliveTab(child: _buildLiveSpacesTab()),
              // Tab 2: Following
              _CommunityKeepAliveTab(child: _buildFollowingTab()),
              // Tab 3: Signals & Setups
              _CommunityKeepAliveTab(child: _buildSignalsTab()),
              // Tab 4: Market News
              _CommunityKeepAliveTab(child: _buildNewsTab()),
              // Tab 5: Crypto
              _CommunityKeepAliveTab(child: _buildCryptoTab()),
              // Tab 6: Equities
              _CommunityKeepAliveTab(child: _buildEquitiesTab()),
            ],
          ),
        ),
      ],
    );
  }

  /// Top bar container holding the floating capsule pill bar,
  /// moved outside the feed scroll view so posts never scroll over it.
  Widget _buildTopBar(BuildContext context, UiTheme theme, bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
        context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
        context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
        context.sp(theme.spacing.xs),
      ),
      child: _buildFloatingBar(context, theme, isMobile),
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
                  icon: Icons.podcasts_rounded,
                  size: UiSize.xs,
                  tooltip: 'Live Spaces',
                  onPressed: () {
                    _subTabController.animateTo(1);
                  },
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

  // ---------------------------------------------------------------------------
  // Tab 0: For you
  // ---------------------------------------------------------------------------

  Widget _buildForYouTab({double? topPadding}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final posts = _filter(widget.repository.forYouPosts);
    final double effectiveTop = topPadding ?? context.sp(theme.spacing.sm);

    final liveRooms = widget.repository.liveRooms;
    final LiveAudioRoom? featuredRoom = liveRooms.isNotEmpty
        ? liveRooms.first
        : null;

    final Widget liveSpaceBanner = featuredRoom == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(
                isMobile ? theme.spacing.sm : theme.spacing.md,
              ),
              vertical: context.sp(theme.spacing.xxs),
            ),
            child: InkWell(
              onTap: () {
                CommunityLiveRoomSheet.show(
                  context,
                  roomId: featuredRoom.id,
                  roomTitle: featuredRoom.title,
                  hostName: featuredRoom.host.displayName,
                  listenerCount: featuredRoom.listenerCount,
                  pinnedSetup: featuredRoom.pinnedSetup,
                  repository: widget.repository,
                );
              },
              borderRadius: BorderRadius.circular(theme.radii.md),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.sm),
                  vertical: context.sp(theme.spacing.xs),
                ),
                decoration: BoxDecoration(
                  color: theme.colors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(theme.radii.md),
                  border: Border.all(
                    color: theme.colors.danger.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: context.sp(theme.spacing.xs),
                      runSpacing: context.sp(theme.spacing.xs),
                      children: [
                        UiBadge(
                          label: 'AUDIO PREVIEW',
                          intent: UiIntent.danger,
                          size: UiSize.xs,
                        ),
                        UiBadge(
                          label: '${featuredRoom.listenerCount} listening',
                          icon: Icons.headphones_rounded,
                          size: UiSize.xs,
                        ),
                      ],
                    ),
                    UiGap.v(theme.spacing.xs),
                    Text(
                      '${featuredRoom.title} · ${featuredRoom.host.displayName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.bodyStrong,
                    ),
                  ],
                ),
              ),
            ),
          );

    final Widget composeHeader = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        liveSpaceBanner,
        if (!isMobile)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.md),
              vertical: context.sp(theme.spacing.xs),
            ),
            child: CommunityComposerCard(
              author: widget.currentUser,
              repository: widget.repository,
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
              onTap: () {
                _forYouScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                );
                setState(() => _newPostsCount = 0);
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

  // ---------------------------------------------------------------------------
  // Tab 1: Live Audio Spaces
  // ---------------------------------------------------------------------------

  Widget _buildLiveSpacesTab({double? topPadding}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final liveRooms = widget.repository.liveRooms;
    final upcomingRooms = widget.repository.upcomingRooms;
    final double effectiveTop = topPadding ?? context.sp(theme.spacing.sm);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(700)),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            effectiveTop,
            context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            context.sp(theme.spacing.xl),
          ),
          children: <Widget>[
            // Header Hero Banner with Host Space button
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              decoration: BoxDecoration(
                color: theme.colors.surface,
                borderRadius: BorderRadius.circular(theme.radii.lg),
                border: Border.all(color: theme.colors.border),
                gradient: LinearGradient(
                  colors: <Color>[
                    theme.colors.surface,
                    theme.colors.danger.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                        decoration: BoxDecoration(
                          color: theme.colors.danger.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.podcasts_rounded,
                          color: theme.colors.danger,
                          size: context.sz(20),
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Live Audio Spaces & Floors',
                              style: context.uiText.heading.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: context.fs(16),
                              ),
                            ),
                            Text(
                              'Voice your market thesis, break down live order flow, or listen in on institutional setups.',
                              style: context.uiText.caption.copyWith(
                                color: theme.colors.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  UiButton(
                    label: 'Host a Live Space',
                    leadingIcon: Icons.podcasts_rounded,
                    variant: UiVariant.solid,
                    intent: UiIntent.primary,
                    expandOnMobile: true,
                    onPressed: () {
                      CommunityHostLiveSpaceDialog.show(
                        context,
                        repository: widget.repository,
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.md)),

            // HAPPENING NOW Section
            Row(
              children: <Widget>[
                Container(
                  width: context.sz(8),
                  height: context.sz(8),
                  decoration: BoxDecoration(
                    color: theme.colors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Text(
                  'HAPPENING NOW (${liveRooms.length})',
                  style: context.uiText.label.copyWith(
                    color: theme.colors.danger,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),

            if (liveRooms.isEmpty)
              UiEmptyState(
                icon: Icons.podcasts_rounded,
                title: 'No active spaces right now',
                message:
                    'Start your own live trading floor to discuss the market with peers.',
                actionLabel: 'Host Space',
                onActionPressed: () => CommunityHostLiveSpaceDialog.show(
                  context,
                  repository: widget.repository,
                ),
              )
            else
              ...liveRooms.map((room) => _buildLiveRoomCard(room)),

            SizedBox(height: context.sp(theme.spacing.md)),

            // SCHEDULED SPACES Section
            Row(
              children: <Widget>[
                Icon(
                  Icons.schedule_rounded,
                  size: context.sz(14),
                  color: theme.colors.foregroundMuted,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Text(
                  'SCHEDULED SPACES (${upcomingRooms.length})',
                  style: context.uiText.label.copyWith(
                    color: theme.colors.foregroundMuted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),

            if (upcomingRooms.isEmpty)
              UiEmptyState(
                icon: Icons.event_available_rounded,
                title: 'No upcoming scheduled spaces',
                message:
                    'Schedule a session in advance so traders can set reminders.',
                actionLabel: 'Schedule a Space',
                onActionPressed: () => CommunityHostLiveSpaceDialog.show(
                  context,
                  repository: widget.repository,
                ),
              )
            else
              ...upcomingRooms.map((room) => _buildUpcomingRoomCard(room)),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveRoomCard(LiveAudioRoom room) => Padding(
    padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.sm)),
    child: CommunityLiveSpaceCard(room: room, repository: widget.repository),
  );

  Widget _buildUpcomingRoomCard(LiveAudioRoom room) => _buildLiveRoomCard(room);

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
                    if (item.summary != null) ...<Widget>[
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      Text(
                        item.summary!,
                        style: context.uiText.body.copyWith(
                          color: theme.colors.foregroundMuted,
                          height: 1.4,
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
