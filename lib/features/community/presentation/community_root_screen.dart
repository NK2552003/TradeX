import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_bookmarks_view.dart';
import 'package:tradex/features/community/presentation/views/community_explore_view.dart';
import 'package:tradex/features/community/presentation/views/community_feed_view.dart';
import 'package:tradex/features/community/presentation/views/community_follow_view.dart';
import 'package:tradex/features/community/presentation/views/community_hashtag_page.dart';
import 'package:tradex/features/community/presentation/views/community_inbox_view.dart';
import 'package:tradex/features/community/presentation/views/community_moderation_list_page.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/community/presentation/views/community_profile_view.dart';
import 'package:tradex/features/community/presentation/views/community_search_page.dart';
import 'package:tradex/features/community/presentation/widgets/community_ai_assistant_dialog.dart';
import 'package:tradex/features/community/presentation/widgets/community_composer_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';
import 'package:tradex/features/community/presentation/widgets/community_sidebar_widgets.dart';

/// The signed-in community shell — three-tier responsive Twitter/X layout.
///
/// **Mobile** (< 600 px):
///   - Persistent bottom [NavigationBar] with 5 destinations (Feed, Explore,
///     Network, Notifications, Profile).
///   - Full-width feed column; swipe-to-switch disabled.
///   - FAB compose button on the Feed tab.
///
/// **Tablet** (600–904 px):
///   - Scrollable top tab bar with icon + label.
///   - Feed (flex 3) alongside a narrow 260 px sidebar (no Who-to-Follow).
///
/// **Desktop** (≥ 905 px):
///   - Text-only top tab bar with 6 tabs (includes Bookmarks).
///   - Centred feed column capped at 680 px.
///   - Sticky independently-scrollable 320 px sidebar on the right.
class CommunityRootScreen extends StatefulWidget {
  const CommunityRootScreen({
    super.key,
    this.userRole = UserRole.customer,
    this.currentTrader,
    this.onSubpageChanged,
    this.onOpenRef,
    this.initialTabIndex = 0,
    this.embedInScaffold = true,
    this.repository,
  });

  final UserRole userRole;
  final AppTrader? currentTrader;
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;

  /// Opens a linked Writing-Desk record (note / journal / strategy) in its own
  /// destination when a post attachment is tapped. Supplied by the app shell.
  final void Function(AppLinkRef ref)? onOpenRef;

  /// Which tab to show on first render. Driven by the global sidebar sub-item
  /// selection (0 = Feed, 1 = Explore, 2 = Network, 3 = My Profile, 4 = Bookmarks).
  final int initialTabIndex;

  /// When true, CommunityRootScreen is embedded inside AppShell, so it avoids
  /// rendering duplicate app bars and bottom navigation bars on mobile.
  final bool embedInScaffold;

  /// Optional shared reactive repository. If not provided, an internal
  /// repository will be created and managed by this screen.
  final CommunityRepository? repository;

  @override
  State<CommunityRootScreen> createState() => CommunityRootScreenState();
}

class CommunityRootScreenState extends State<CommunityRootScreen>
    with SingleTickerProviderStateMixin {
  // -------------------------------------------------------------------------
  // Tab definitions
  // -------------------------------------------------------------------------

  /// All five hub tabs — shared by tablet + desktop top tab bar.
  static const List<_CommunityTab> _hubTabs = <_CommunityTab>[
    _CommunityTab(label: 'Feed', icon: Icons.dynamic_feed_outlined),
    _CommunityTab(label: 'Explore', icon: Icons.explore_outlined),
    _CommunityTab(label: 'Network', icon: Icons.group_outlined),
    _CommunityTab(label: 'My Profile', icon: Icons.person_outline_rounded),
    _CommunityTab(label: 'Bookmarks', icon: Icons.bookmark_border_rounded),
  ];

  /// Four bottom-nav destinations on mobile — maps to tab indices 0–3.
  static const List<_CommunityTab> _mobileNavTabs = <_CommunityTab>[
    _CommunityTab(label: 'Feed', icon: Icons.dynamic_feed_outlined),
    _CommunityTab(label: 'Explore', icon: Icons.explore_outlined),
    _CommunityTab(label: 'Network', icon: Icons.group_outlined),
    _CommunityTab(label: 'Profile', icon: Icons.person_outline_rounded),
  ];

  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------

  late final CommunityRepository _repo;
  late final bool _ownsRepo;
  late TabController _tabController;

  /// Selected bottom-nav index on mobile (0–3), kept in sync with
  /// [_tabController] so [_buildTabPages] is the single source of truth.
  int _mobileNavIndex = 0;

  /// Active drill-in sub-page (post thread, profile, network page).
  Widget? _activeSubpage;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? CommunityRepository();
    _tabController = TabController(
      length: _hubTabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _hubTabs.length - 1),
    );
    // Rebuild on tab change so FAB / badges stay current.
    _tabController.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant CommunityRootScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      final int idx = widget.initialTabIndex.clamp(0, _hubTabs.length - 1);
      if (_tabController.index != idx) {
        _tabController.animateTo(idx);
      }
      _mobileNavIndex = idx.clamp(0, _mobileNavTabs.length - 1);
    }
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    if (_ownsRepo) {
      _repo.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Current-user helper
  // -------------------------------------------------------------------------

  CommunityAuthor get _currentAuthor => CommunityAuthor(
    id: widget.currentTrader?.id ?? 'usr_alex_vance',
    handle: widget.currentTrader?.handle ?? 'alextrades',
    displayName: widget.currentTrader?.displayName ?? 'Alex Vance',
    userRole: widget.userRole,
    avatarUrl: widget.currentTrader?.avatarUrl,
    verified: true,
    tier: widget.currentTrader?.tier ?? AppTier.premium,
    followers: widget.currentTrader?.followers ?? 12400,
    following: widget.currentTrader?.following ?? 234,
    winRate: 84.0,
    tradingStyle: 'Swing Trading',
    primaryMarket: 'Indian Equities & F&O',
    postsCount: 892,
  );

  // -------------------------------------------------------------------------
  // Navigation helpers
  // -------------------------------------------------------------------------

  void _openSubpage({required Widget page, required String title}) {
    setState(() => _activeSubpage = page);
    widget.onSubpageChanged?.call(title, null, _closeSubpage);
  }

  void _closeSubpage() {
    setState(() => _activeSubpage = null);
    widget.onSubpageChanged?.call(null, null, null);
  }

  void _openPostDetail(CommunityPost post) {
    _openSubpage(
      title: 'Post',
      page: CommunityPostDetailView(
        post: post,
        repository: _repo,
        currentUser: _currentAuthor,
        onAuthorTap: _openAuthorProfile,
        onBack: _closeSubpage,
        onOpenRef: widget.onOpenRef,
      ),
    );
  }

  void _openAuthorProfile(CommunityAuthor author) {
    final bool isMe = author.id == _currentAuthor.id;
    _openSubpage(
      title: author.displayName,
      page: CommunityProfileView(
        author: author,
        repository: _repo,
        isCurrentUser: isMe,
        onBack: _closeSubpage,
      ),
    );
  }

  void _openNetworkPage() {
    _openSubpage(
      title: 'Network',
      page: CommunityFollowView(
        repository: _repo,
        onAuthorTap: _openAuthorProfile,
      ),
    );
  }

  void _openHashtagPage(String tag) {
    _openSubpage(
      title: tag,
      page: CommunityHashtagPage(
        tag: tag,
        repository: _repo,
        currentUser: _currentAuthor,
        onPostTap: _openPostDetail,
        onAuthorTap: _openAuthorProfile,
        onBack: _closeSubpage,
        onOpenRef: widget.onOpenRef,
      ),
    );
  }

  void _openSearchPage() {
    _openSubpage(
      title: 'Search',
      page: CommunitySearchPage(
        repository: _repo,
        currentUser: _currentAuthor,
        onPostTap: _openPostDetail,
        onAuthorTap: _openAuthorProfile,
        onHashtagTap: _openHashtagPage,
        onBack: _closeSubpage,
        onOpenRef: widget.onOpenRef,
      ),
    );
  }

  void _openInboxView() {
    _openSubpage(
      title: 'Messages',
      page: CommunityInboxView(
        repository: _repo,
        currentUser: _currentAuthor,
        onBack: _closeSubpage,
      ),
    );
  }

  void _openModerationListPage() {
    _openSubpage(
      title: 'Safety & Moderation',
      page: CommunityModerationListPage(
        repository: _repo,
        onBack: _closeSubpage,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Mobile compose
  // -------------------------------------------------------------------------

  void _showMobileComposer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => CommunityDensityScope(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: CommunityComposerCard(
            author: _currentAuthor,
            repository: _repo,
            onPostCreated: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Root build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // One density scope rescales the entire section (embedded views + every
    // `setState`-swapped subpage). The [Builder] re-resolves `context` beneath
    // the scope so the shell's own chrome is compacted too.
    return CommunityDensityScope(
      child: Builder(
        builder: (BuildContext context) {
          if (_activeSubpage != null) return _activeSubpage!;

          final UiTheme theme = context.ui;
          final UiResponsive r = context.uiRes;
          final Widget layout = r.isMobile
              ? _buildMobileLayout(context)
              : (r.isTablet ? _buildTabletLayout(context) : _buildDesktopLayout(context));

          final bool isMobile = r.isMobile;
          final bool onFeedTab = _tabController.index == 0;
          final double safeBottom = MediaQuery.paddingOf(context).bottom;
          final double floatingBottom = isMobile
              ? (context.sz(86) + (onFeedTab ? context.sz(54) : 0) + safeBottom)
              : context.sp(theme.spacing.lg);

          return Stack(
            children: <Widget>[
              layout,
              Positioned(
                right: context.sp(theme.spacing.lg),
                bottom: floatingBottom,
                child: CommunityAiFloatingBar(
                  repository: _repo,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Tab page list
  // -------------------------------------------------------------------------

  List<Widget> _buildTabPages() => <Widget>[
    // 0 — Feed
    CommunityFeedView(
      repository: _repo,
      currentUser: _currentAuthor,
      onPostTap: _openPostDetail,
      onAuthorTap: _openAuthorProfile,
      onCompose: _showMobileComposer,
      onOpenRef: widget.onOpenRef,
    ),
    // 1 — Explore
    CommunityExploreView(
      repository: _repo,
      onPostTap: _openPostDetail,
      onAuthorTap: _openAuthorProfile,
      onOpenRef: widget.onOpenRef,
    ),
    // 2 — Network
    CommunityFollowView(repository: _repo, onAuthorTap: _openAuthorProfile),
    // 3 — My Profile
    CommunityProfileView(
      author: _currentAuthor,
      repository: _repo,
      isCurrentUser: true,
      onBack: null,
    ),
    // 4 — Bookmarks (tablet/desktop only; not in mobile bottom nav)
    CommunityBookmarksView(
      repository: _repo,
      currentUser: _currentAuthor,
      onPostTap: _openPostDetail,
      onAuthorTap: _openAuthorProfile,
      onOpenRef: widget.onOpenRef,
    ),
  ];

  // =========================================================================
  // MOBILE LAYOUT  (< 600 px)
  // =========================================================================

  Widget _buildMobileLayout(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool onFeedTab = _tabController.index == 0;

    if (widget.embedInScaffold) {
      return Stack(
        children: <Widget>[
          TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: _buildTabPages(),
          ),
          if (onFeedTab)
            Positioned(
              right: context.sp(theme.spacing.md),
              bottom: context.sz(86) + MediaQuery.paddingOf(context).bottom,
              child: FloatingActionButton.small(
                heroTag: 'community_mobile_compose_fab',
                onPressed: _showMobileComposer,
                backgroundColor: theme.colors.primary,
                child: Icon(
                  Icons.edit_rounded,
                  color: theme.colors.onPrimary,
                  size: context.sz(20),
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        backgroundColor: theme.colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: context.sp(theme.spacing.md),
        title: Row(
          children: <Widget>[
            UiAvatar(
              name: _currentAuthor.displayName,
              imageUrl: _currentAuthor.avatarUrl,
              size: UiSize.xs,
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Text(
              _mobileNavTabs[_mobileNavIndex].label,
              style: context.uiText.heading.copyWith(
                fontSize: context.fs(16),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          UiIconButton(
            icon: Icons.search_rounded,
            size: UiSize.xs,
            tooltip: 'Search',
            onPressed: _openSearchPage,
          ),
          UiIconButton(
            icon: Icons.mail_outline_rounded,
            size: UiSize.xs,
            tooltip: 'Messages',
            onPressed: _openInboxView,
          ),
          UiIconButton(
            icon: Icons.shield_outlined,
            size: UiSize.xs,
            tooltip: 'Moderation',
            onPressed: _openModerationListPage,
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(theme.borders.hairline),
          child: Container(
            color: theme.colors.border.withValues(alpha: 0.6),
            height: theme.borders.hairline,
          ),
        ),
      ),
      // FAB — only visible on the Feed tab.
      floatingActionButton: onFeedTab
          ? FloatingActionButton(
              onPressed: _showMobileComposer,
              backgroundColor: theme.colors.primary,
              child: Icon(Icons.edit_rounded, color: theme.colors.onPrimary),
            )
          : null,
      bottomNavigationBar: _buildBottomNavBar(theme),
      body: SafeArea(
        bottom: false, // bottom nav handles its own safe-area inset
        child: TabBarView(
          controller: _tabController,
          // Disable swipe — bottom nav is the primary gesture on mobile.
          physics: const NeverScrollableScrollPhysics(),
          children: _buildTabPages(),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(UiTheme theme) {
    return NavigationBar(
      selectedIndex: _mobileNavIndex,
      onDestinationSelected: (int i) {
        setState(() {
          _mobileNavIndex = i;
          _tabController.index = i;
        });
      },
      backgroundColor: theme.colors.surface,
      indicatorColor: theme.colors.primary.withValues(alpha: 0.12),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: _mobileNavTabs.map((_CommunityTab tab) {
        return NavigationDestination(icon: Icon(tab.icon), label: tab.label);
      }).toList(),
    );
  }

  // =========================================================================
  // TABLET LAYOUT  (600–904 px)
  // =========================================================================

  Widget _buildTabletLayout(BuildContext context) {
    final UiTheme theme = context.ui;

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: Column(
        children: <Widget>[
          _buildTopTabBar(context, showIcons: true),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Feed column.
                Expanded(
                  flex: 3,
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _buildTabPages(),
                  ),
                ),
                // Narrow sidebar — no Who-to-Follow to save horizontal space.
                SizedBox(
                  width: context.sz(260),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: theme.colors.border,
                          width: theme.borders.hairline,
                        ),
                      ),
                    ),
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                        child: CommunitySidebar(
                          repository: _repo,
                          onFollow: (author) => _repo.toggleFollow(author.id),
                          onShowMore: _openNetworkPage,
                          onPostTap: _openPostDetail,
                          onSearchTap: _openSearchPage,
                          onSearchSubmitted: (q) => _openHashtagPage(
                            q.startsWith('\$') || q.startsWith('#')
                                ? q
                                : '\$$q',
                          ),
                          showWhoToFollow: false,
                        ),
                      ),
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

  // =========================================================================
  // DESKTOP LAYOUT  (≥ 905 px)
  // =========================================================================

  Widget _buildDesktopLayout(BuildContext context) {
    final UiTheme theme = context.ui;

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Feed area — full width on desktop.
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: _buildTabPages(),
            ),
          ),

          // Right sidebar — sticky / independently scrollable.
          SizedBox(
            width: context.sz(320),
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                child: CommunitySidebar(
                    repository: _repo,
                    onFollow: (author) => _repo.toggleFollow(author.id),
                    onShowMore: _openNetworkPage,
                    onPostTap: _openPostDetail,
                    onSearchTap: _openSearchPage,
                    onSearchSubmitted: (q) => _openHashtagPage(
                      q.startsWith('\$') || q.startsWith('#')
                          ? q
                          : '\$$q',
                    ),
                    showWhoToFollow: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Shared top tab bar  (tablet + desktop)
  // =========================================================================

  /// [showIcons] — true on tablet (icon + label), false on desktop (text only).
  Widget _buildTopTabBar(BuildContext context, {required bool showIcons}) {
    final UiTheme theme = context.ui;
    final bool isDesktop = context.uiRes.isDesktop;

    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: isDesktop
            ? null
            : Border(
                bottom: BorderSide(
                  color: theme.colors.border,
                  width: theme.borders.hairline,
                ),
              ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TabBar(
              controller: _tabController,
              isScrollable: !isDesktop,
              tabAlignment:
                  isDesktop ? TabAlignment.fill : TabAlignment.start,
              splashBorderRadius: context.radius(theme.radii.sm),
              labelStyle: context.uiText.bodyStrong.copyWith(
                fontSize: context.fs(14),
              ),
              unselectedLabelStyle: context.uiText.body.copyWith(
                fontSize: context.fs(14),
                color: theme.colors.foregroundMuted,
              ),
              labelColor: theme.colors.primary,
              unselectedLabelColor: theme.colors.foregroundMuted,
              indicatorColor: theme.colors.primary,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              tabs: _hubTabs.map((_CommunityTab t) {
                if (showIcons) {
                  // Tablet: icon + label.
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(t.icon, size: context.sz(18)),
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        Text(t.label),
                      ],
                    ),
                  );
                }

                // Desktop: text label only.
                return Tab(
                  child: Text(t.label),
                );
              }).toList(),
            ),
          ),
          UiIconButton(
            icon: Icons.search_rounded,
            size: UiSize.xs,
            tooltip: 'Search TradeX',
            onPressed: _openSearchPage,
          ),
          UiIconButton(
            icon: Icons.mail_outline_rounded,
            size: UiSize.xs,
            tooltip: 'Direct Messages',
            onPressed: _openInboxView,
          ),
          UiIconButton(
            icon: Icons.shield_outlined,
            size: UiSize.xs,
            tooltip: 'Moderation & Safety',
            onPressed: _openModerationListPage,
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class _CommunityTab {
  const _CommunityTab({required this.label, required this.icon});
  final String label;
  final IconData icon;
}


