import 'dart:async';
import 'package:flutter/services.dart';
import 'package:tradex/core/linking/link_graph.dart';
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
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

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
    this.onOpenRecord,
    this.onNavigateToMessages,
    this.onOpenThread,
    this.onStartDirectMessage,
    this.onOpenRef,
    this.initialTabIndex = 0,
    this.onTabChanged,
    this.embedInScaffold = true,
    this.repository,
    this.searchQuery,
    this.openRequest,
  });

  final UserRole userRole;
  final AppTrader? currentTrader;
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;
  final VoidCallback? onNavigateToMessages;
  final void Function(String)? onOpenThread;
  final void Function(AppTrader)? onStartDirectMessage;

  /// Opens a linked Writing-Desk record (note / journal / strategy) in its own
  /// destination when a post attachment is tapped. Supplied by the app shell.
  final void Function(AppLinkRef ref)? onOpenRef;

  /// Which tab to show on first render. Driven by the global sidebar sub-item
  /// selection (0 = Feed, 1 = Explore, 2 = Network, 3 = My Profile, 4 = Bookmarks).
  final int initialTabIndex;
  final ValueChanged<int>? onTabChanged;

  /// When true, CommunityRootScreen is embedded inside AppShell, so it avoids
  /// rendering duplicate app bars and bottom navigation bars on mobile.
  final bool embedInScaffold;

  /// Optional shared reactive repository. If not provided, an internal
  /// repository will be created and managed by this screen.
  final CommunityRepository? repository;

  /// Search query passed down from the global top header.
  final String? searchQuery;

  /// Link request to open a specific post.
  final ValueChanged<AppLinkRef>? onOpenRecord;
  final AppLinkOpenRequest? openRequest;

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
  final List<_CommunitySubpageEntry> _subpageStack = [];
  String? _activePostId;
  int? _lastHandledRequestSeq;
  int _desktopPanelDepth = 0;

  final ScrollController _desktopSidebarController = ScrollController();
  final ScrollController _tabletSidebarController = ScrollController();

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _ownsRepo = widget.repository == null;
    _repo = widget.repository ?? CommunityRepository();
    _repo.addListener(_onRepoChanged);
    _repo.updateCurrentAuthor(_currentAuthor);
    unawaited(_repo.loadMarketData());
    _tabController = TabController(
      length: _hubTabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _hubTabs.length - 1),
    );
    _mobileNavIndex = _tabController.index.clamp(0, _mobileNavTabs.length - 1);
    // Rebuild on tab change so FAB / badges stay current.
    _tabController.addListener(_onTabChanged);

    if (widget.openRequest != null) {
      _applyRequest(widget.openRequest!);
    }
  }

  @override
  void didUpdateWidget(covariant CommunityRootScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _repo.updateCurrentAuthor(_currentAuthor);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      final int idx = widget.initialTabIndex.clamp(0, _hubTabs.length - 1);
      _subpageStack.clear();
      _activeSubpage = null;
      _activePostId = null;
      if (_tabController.index != idx) {
        _tabController.animateTo(idx);
      }
      _mobileNavIndex = idx.clamp(0, _mobileNavTabs.length - 1);
    }
    if (widget.openRequest != null &&
        widget.openRequest != oldWidget.openRequest &&
        widget.openRequest!.seq != _lastHandledRequestSeq &&
        widget.openRequest!.id != _activePostId) {
      _applyRequest(widget.openRequest!);
    }
  }

  void _applyRequest(AppLinkOpenRequest request) {
    _lastHandledRequestSeq = request.seq;
    if (_activePostId == request.id &&
        _activeSubpage is CommunityPostDetailView) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_activePostId == request.id &&
          _activeSubpage is CommunityPostDetailView) {
        return;
      }
      CommunityPost? post = _repo.loadPostById(request.id);
      post ??= await _repo.fetchPostById(request.id);
      if (post != null && mounted) {
        _openPostDetail(post);
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging &&
        _tabController.index != widget.initialTabIndex) {
      widget.onTabChanged?.call(_tabController.index);
    }
    if (mounted) {
      setState(() {
        _subpageStack.clear();
        _activeSubpage = null;
        _activePostId = null;
        _mobileNavIndex = _tabController.index.clamp(
          0,
          _mobileNavTabs.length - 1,
        );
      });
    }
  }

  void _onRepoChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _desktopSidebarController.dispose();
    _tabletSidebarController.dispose();
    _repo.removeListener(_onRepoChanged);
    if (_ownsRepo) {
      _repo.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Current-user helper
  // -------------------------------------------------------------------------

  static String _monthName(int month) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  CommunityAuthor get _currentAuthor {
    final trader = widget.currentTrader;
    final int myPosts = _repo.postsForAuthor(trader?.id ?? '').length;
    final String? joined = trader?.createdAt != null
        ? 'Joined ${_monthName(trader!.createdAt!.month)} ${trader.createdAt!.year}'
        : null;

    double? winRate = trader?.winRate;
    if (winRate == null) {
      try {
        final journalStats = JournalRepositoryScope.repository.stats;
        if (journalStats.total > 0) {
          winRate = journalStats.winRate * 100;
        }
      } catch (_) {}
    }

    return CommunityAuthor(
      id: trader?.id ?? '',
      handle: trader?.handle ?? '',
      displayName: (trader?.displayName?.isNotEmpty ?? false)
          ? trader!.displayName!
          : (trader?.handle ?? ''),
      userRole: widget.userRole,
      avatarUrl: trader?.avatarUrl,
      bio: trader?.bio,
      verified: trader?.verified ?? false,
      tier: trader?.tier ?? AppTier.free,
      followers: trader?.followers ?? 0,
      following: trader?.following ?? 0,
      winRate: winRate,
      tradingStyle: trader?.tradingStyle ?? trader?.topStrategy,
      primaryMarket: trader?.primaryMarket,
      location: trader?.location,
      website: trader?.website,
      avgHoldDuration: trader?.avgHoldDuration,
      riskMantra: trader?.riskMantra,
      joinedDate: joined,
      postsCount: myPosts > 0 ? myPosts : (trader?.postsCount ?? 0),
    );
  }

  // -------------------------------------------------------------------------
  // Navigation helpers
  // -------------------------------------------------------------------------

  void _openSubpage({
    required Widget page,
    required String title,
    bool forceInline = false,
  }) {
    if (context.uiRes.isDesktop && !forceInline && _activeSubpage == null) {
      _desktopPanelDepth++;
      unawaited(
        showSettingsSideSheet<void>(
          context,
          title: title,
          desktopWidthRatio: 0.48,
          minDesktopWidth: 540,
          maxWidth: 760,
          child: LayoutBuilder(
            builder: (panelContext, constraints) => MediaQuery(
              data: MediaQuery.of(panelContext).copyWith(
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
              child: page,
            ),
          ),
        ).whenComplete(() => _desktopPanelDepth--),
      );
      return;
    }
    _subpageStack.add(_CommunitySubpageEntry(page: page, title: title));
    setState(() => _activeSubpage = page);
    widget.onSubpageChanged?.call(title, null, _closeSubpage);
  }

  void _closeSubpage() {
    if (_desktopPanelDepth > 0) {
      Navigator.of(context, rootNavigator: true).maybePop();
      return;
    }
    if (_subpageStack.isNotEmpty) {
      _subpageStack.removeLast();
    }
    if (_subpageStack.isNotEmpty) {
      final prev = _subpageStack.last;
      _activePostId = prev.page is CommunityPostDetailView
          ? (prev.page as CommunityPostDetailView).post.id
          : null;
      setState(() => _activeSubpage = prev.page);
      widget.onSubpageChanged?.call(prev.title, null, _closeSubpage);
    } else {
      _activePostId = null;
      setState(() => _activeSubpage = null);
      widget.onSubpageChanged?.call(null, null, null);
    }
  }

  void _handleTagTap(String tag) {
    final String trimmed = tag.trim();
    if (trimmed.startsWith(r'$')) {
      final String symbol = trimmed.substring(1).trim().toUpperCase();
      if (symbol.isNotEmpty && widget.onOpenRef != null) {
        widget.onOpenRef!(
          AppLinkRef(kind: AppLinkKind.ticker, id: symbol, title: symbol),
        );
        return;
      }
    }
    if (trimmed.startsWith('tradex://') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      final AppLinkRef? target = AppDeepLink.tryParseUrl(trimmed);
      if (target != null) {
        if (target.kind == AppLinkKind.communityPost) {
          final CommunityPost? post = _repo.loadPostById(target.id);
          if (post != null) {
            _openPostDetail(post);
            return;
          }
        }
        if (widget.onOpenRef != null) {
          widget.onOpenRef!(target.copyWith(isPublicContext: true));
          return;
        }
      }
      Clipboard.setData(ClipboardData(text: trimmed));
      UiToast.info(context, title: 'Link Copied', message: trimmed);
      return;
    }
    if (trimmed.startsWith('@')) {
      final String cleanHandle = trimmed.substring(1).trim().toLowerCase();
      for (final CommunityAuthor a in _repo.suggestedTraders) {
        if (a.handle.toLowerCase() == cleanHandle) {
          _openAuthorProfile(a);
          return;
        }
      }
      if (_currentAuthor.handle.toLowerCase() == cleanHandle) {
        _openAuthorProfile(_currentAuthor);
        return;
      }
      final List<CommunityPost> matchingPosts = _repo.postsForAuthor(
        cleanHandle,
      );
      if (matchingPosts.isNotEmpty) {
        _openAuthorProfile(matchingPosts.first.author);
        return;
      }
    }
    _openHashtagPage(trimmed);
  }

  void _openPostDetail(CommunityPost post) {
    if (!post.isPublic && post.author.id != _currentAuthor.id) {
      UiToast.error(
        context,
        title: 'Post unavailable',
        message: 'The post is private or was removed.',
      );
      return;
    }
    if (_activePostId == post.id && _activeSubpage is CommunityPostDetailView) {
      return;
    }
    _activePostId = post.id;
    if (widget.openRequest != null && widget.openRequest!.id == post.id) {
      _lastHandledRequestSeq = widget.openRequest!.seq;
    }

    // Dismiss any active desktop side sheet so the full desktop view is displayed cleanly
    if (_desktopPanelDepth > 0) {
      Navigator.of(context, rootNavigator: true).maybePop();
    }

    widget.onOpenRecord?.call(
      AppLinkRef(
        kind: AppLinkKind.communityPost,
        id: post.id,
        title: 'Post',
        isPublicContext: true,
      ),
    );
    _openSubpage(
      title: 'Post',
      page: CommunityPostDetailView(
        post: post,
        repository: _repo,
        currentUser: _currentAuthor,
        onAuthorTap: _openAuthorProfile,
        onStartDirectMessage: widget.onStartDirectMessage,
        onBack: _closeSubpage,
        showHeader: !widget.embedInScaffold,
        onOpenRef: widget.onOpenRef,
        onTagTap: _handleTagTap,
        onPostTap: _openPostDetail,
      ),
      forceInline: true,
    );
  }

  bool _isMe(CommunityAuthor author) {
    final ownIds = <String>{_currentAuthor.id, _repo.currentAuthor.id}
      ..remove('');
    if (author.id.isNotEmpty && ownIds.contains(author.id)) return true;
    final handle = author.handle.toLowerCase().replaceFirst('@', '').trim();
    if (handle.isEmpty) return false;
    return <String>{_currentAuthor.handle, _repo.currentAuthor.handle}
        .map((value) => value.toLowerCase().replaceFirst('@', '').trim())
        .where((value) => value.isNotEmpty)
        .contains(handle);
  }

  void _openAuthorProfile(CommunityAuthor author) {
    final bool isMe = _isMe(author);
    _openSubpage(
      title: author.displayName,
      page: CommunityProfileView(
        author: author,
        repository: _repo,
        isCurrentUser: isMe,
        showHeader: !widget.embedInScaffold,
        onBack: _closeSubpage,
        onPostTap: _openPostDetail,
        onOpenRef: widget.onOpenRef,
        onDirectMessage: widget.onStartDirectMessage,
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

  void _openNewsPage() {
    _openSubpage(
      title: 'Market Wire',
      page: CommunityMarketWirePage(
        category: 'Market Wire',
        items: _repo.news,
        snapshot: _repo.marketSnapshot,
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
        onTagTap: _handleTagTap,
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
        onHashtagTap: _handleTagTap,
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
    showSettingsSideSheet<void>(
      context,
      title: 'Muted & Blocked Accounts',
      subtitle: 'Review restricted and muted trader profiles',
      desktopWidthRatio: 0.44,
      maxWidth: 620,
      minDesktopWidth: 460,
      child: CommunityModerationListPage(repository: _repo, isEmbedded: true),
    );
  }

  // -------------------------------------------------------------------------
  // Mobile compose
  // -------------------------------------------------------------------------

  void _showComposer({ComposerMode initialMode = ComposerMode.post}) {
    if (context.uiRes.isMobile) {
      _showMobileComposer(initialMode: initialMode);
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
          author: _currentAuthor,
          repository: _repo,
          initialMode: initialMode,
          onPostCreated: () => Navigator.of(context).pop(),
        ),
      );
    }
  }

  void _showMobileComposer({ComposerMode initialMode = ComposerMode.post}) {
    final UiTheme theme = context.ui;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: theme.colors.overlay,
      builder: (BuildContext ctx) => CommunityDensityScope(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            child: CommunityComposerCard(
              author: _currentAuthor,
              repository: _repo,
              initialMode: initialMode,
              isDrawerTile: true,
              onPostCreated: () => Navigator.of(ctx).pop(),
            ),
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
              : (r.isTablet
                    ? _buildTabletLayout(context)
                    : _buildDesktopLayout(context));

          final bool isMobile = r.isMobile;
          final bool onFeedTab = _tabController.index == 0;
          final double safeBottom = MediaQuery.paddingOf(context).bottom;
          // In AppShell, MediaQuery.paddingOf(context).bottom already includes the
          // floating dock clearance (~76px). Position the dock just above it.
          final double floatingBottom = isMobile
              ? (widget.embedInScaffold || safeBottom > 50
                    ? (safeBottom + context.sp(theme.spacing.xs))
                    : (context.sz(74) + safeBottom))
              : context.sp(theme.spacing.lg);
          final double floatingRight = isMobile
              ? context.sp(theme.spacing.md)
              : context.sp(theme.spacing.lg);

          return Stack(
            children: <Widget>[
              if (!isMobile && !widget.embedInScaffold)
                Column(
                  children: [
                    _buildTopTabBar(context, showIcons: r.isTablet),
                    Expanded(child: layout),
                  ],
                )
              else
                layout,
              Positioned(
                right: floatingRight,
                bottom: floatingBottom,
                child: CommunityAiFloatingBar(
                  repository: _repo,
                  onCompose: _showComposer,
                  showCompose: isMobile && onFeedTab,
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
      onCompose: _showComposer,
      onOpenRef: widget.onOpenRef,
      onTagTap: _handleTagTap,
      searchQuery: widget.searchQuery,
    ),
    // 1 — Explore
    CommunityExploreView(
      repository: _repo,
      onPostTap: _openPostDetail,
      onAuthorTap: _openAuthorProfile,
      onOpenRef: widget.onOpenRef,
      onTagTap: _handleTagTap,
      searchQuery: widget.searchQuery,
    ),
    // 2 — Network
    CommunityFollowView(
      repository: _repo,
      onAuthorTap: _openAuthorProfile,
      searchQuery: widget.searchQuery,
    ),
    // 3 — My Profile
    CommunityProfileView(
      author: _currentAuthor,
      repository: _repo,
      isCurrentUser: true,
      onBack: null,
      onPostTap: _openPostDetail,
      onOpenRef: widget.onOpenRef,
    ),
    // 4 — Bookmarks (tablet/desktop only; not in mobile bottom nav)
    CommunityBookmarksView(
      repository: _repo,
      currentUser: _currentAuthor,
      onPostTap: _openPostDetail,
      onAuthorTap: _openAuthorProfile,
      onOpenRef: widget.onOpenRef,
      onTagTap: _handleTagTap,
    ),
  ];

  // =========================================================================
  // MOBILE LAYOUT  (< 600 px)
  // =========================================================================

  Widget _buildMobileLayout(BuildContext context) {
    final UiTheme theme = context.ui;

    if (widget.embedInScaffold) {
      return TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: _buildTabPages(),
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
      // Combined dock in root stack handles both AI and Compose
      floatingActionButton: null,
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
                // Feed column (Twitter/X style: max 700px).
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: context.sz(700)),
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: _buildTabPages(),
                      ),
                    ),
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
                      controller: _tabletSidebarController,
                      child: SingleChildScrollView(
                        controller: _tabletSidebarController,
                        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                        child: CommunitySidebar(
                          repository: _repo,
                          onFollow: (author) => _repo.toggleFollow(author.id),
                          onAuthorTap: _openAuthorProfile,
                          onShowMore: _openNetworkPage,
                          onNewsShowMore: _openNewsPage,
                          onExplore: () => _tabController.animateTo(1),
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
          // Panel 1: Centered Panel (takes all remaining space, hosting full-width top bar and centered 700px cards)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: theme.colors.border.withValues(alpha: 0.6),
                    width: theme.borders.hairline,
                  ),
                ),
              ),
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: _buildTabPages(),
              ),
            ),
          ),

          // Panel 2: Right-side Container (docked firmly to the right side of the screen)
          SizedBox(
            width: context.sz(340),
            child: Scrollbar(
              controller: _desktopSidebarController,
              child: SingleChildScrollView(
                controller: _desktopSidebarController,
                padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                child: CommunitySidebar(
                  repository: _repo,
                  onFollow: (author) => _repo.toggleFollow(author.id),
                  onAuthorTap: _openAuthorProfile,
                  onShowMore: _openNetworkPage,
                  onNewsShowMore: _openNewsPage,
                  onExplore: () => _tabController.animateTo(1),
                  onPostTap: _openPostDetail,
                  onSearchTap: _openSearchPage,
                  onSearchSubmitted: (q) => _openHashtagPage(
                    q.startsWith('\$') || q.startsWith('#') ? q : '\$$q',
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
  Widget _buildTopTabBar(BuildContext context, {required bool showIcons}) =>
      UiTabs(
        items: [
          for (final tab in _hubTabs)
            UiTabItem(label: tab.label, icon: showIcons ? tab.icon : null),
        ],
        index: _tabController.index,
        onChanged: _tabController.animateTo,
        scrollable: true,
        showPanel: false,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UiIconButton(
              icon: Icons.search_rounded,
              size: UiSize.xs,
              tooltip: 'Search alphajournal',
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
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class _CommunityTab {
  const _CommunityTab({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

class _CommunitySubpageEntry {
  const _CommunitySubpageEntry({required this.page, required this.title});
  final Widget page;
  final String title;
}
