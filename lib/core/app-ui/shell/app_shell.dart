import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quiet_dock/quiet_dock.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../../../features/calculators/ui/calculators_screen.dart';
import '../brand/app_logo.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../motion/page_transition.dart';
import '../theme/app_tokens.dart';
import 'app_quiet_dock.dart';

bool get _isNativeAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Adaptive application shell.
///
/// - phone: bottom dock + top app bar
/// - tablet: icon rail + top app bar
/// - desktop: full sidebar with sections, collapsible to icons
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.sections,
    required this.selectedId,
    required this.onSelect,
    required this.child,
    this.onExternalSelect,
    this.trader,
    this.tier = AppTier.free,
    this.onSearch,
    this.searchQuery,
    this.searchHint,
    this.onSearchChanged,
    this.searchTargetKey,
    this.headerActions = const <Widget>[],
    this.onNotifications,
    this.onSettings,
    this.onAi,
    this.unreadNotifications = 0,
    this.primaryAction,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onHelp,
    this.statusBadgeText = '',
    this.showStatusBadge = false,
    this.sidebarFooter,
    this.mobilePrimaryItems,
    this.mobileMoreItems = const <AppNavItem>[],
    this.userMenuItems = const <AppNavItem>[],
    this.workspaceName,
    this.tierLabel,
    this.onLogout,
    this.pageTitle,
    this.pageSectionTitle,
    this.pageIcon,
    this.onBack,
    this.pagePlaceholderBuilder,
    this.researchPanelBuilder,
    this.hideMobileTopBar = false,
  });

  final bool hideMobileTopBar;

  final List<AppNavSection> sections;
  final String selectedId;
  final ValueChanged<String> onSelect;

  /// Handles navigation that leaves the current application before the dock
  /// starts a local page transition.
  final bool Function(String)? onExternalSelect;
  final Widget child;

  /// Full-height companion panel, outside the page and its header. The builder
  /// receives a close callback and an overlay flag, so navigation can dismiss
  /// a temporary drawer while leaving a docked pane open.
  final Widget Function(BuildContext context, VoidCallback close, bool overlay)?
  researchPanelBuilder;
  final AppTrader? trader;
  final AppTier tier;
  final VoidCallback? onSearch;
  final String? searchQuery;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final GlobalKey? searchTargetKey;
  final List<Widget> headerActions;
  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;
  final VoidCallback? onAi;
  final VoidCallback? onHelp;
  final int unreadNotifications;
  final Widget? primaryAction;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String statusBadgeText;
  final bool showStatusBadge;
  final Widget? sidebarFooter;
  final List<AppNavItem>? mobilePrimaryItems;
  final List<AppNavItem> mobileMoreItems;
  final List<AppNavItem> userMenuItems;
  final String? workspaceName;
  final String? tierLabel;
  final VoidCallback? onLogout;
  final IconData? pageIcon;
  final VoidCallback? onBack;

  /// Breadcrumb leaf for a [selectedId] that no [sections] entry declares. The
  /// shell owns a few surfaces the sidebar never lists — search and the inbox
  /// live behind the top bar — and without this the crumb would keep naming the
  /// dashboard while a different page is on screen.
  final String? pageTitle;

  /// Breadcrumb root that goes with [pageTitle].
  final String? pageSectionTitle;

  /// Loading stand-in for a phone destination that is not the live one.
  ///
  /// The phone shell lets the reader swipe between dock destinations, so the
  /// [PageView] asks for pages either side of the current one. Handing it the
  /// live page again would show a second copy of the screen being dragged away;
  /// building the neighbour for real would defeat lazy loading. A skeleton
  /// shaped like the destination answers both: the swipe reveals the next screen
  /// arriving, and its widget tree is only built once the swipe commits.
  ///
  /// Defaults to a generic page skeleton.
  final Widget Function(BuildContext context, AppNavItem item)?
  pagePlaceholderBuilder;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _collapsed = false;
  bool _researchVisible = true;

  /// Two separate dock controllers: one for main workspace navigation, and
  /// one for the community sub-experience navigation. This prevents index
  /// cross-contamination and placeholder/skeleton flashes when toggling between
  /// the main dock and community dock.
  QuietDockController? _mainDockController;
  QuietDockController? _communityDockController;

  QuietDockController get _activeDockController {
    if (_isCommunityRoute) {
      return _communityDockController ??= QuietDockController(
        initialIndex: (_dockIndexFor(widget.selectedId) < 0)
            ? 0
            : _dockIndexFor(widget.selectedId),
      );
    }
    return _mainDockController ??= QuietDockController(
      initialIndex: (_dockIndexFor(widget.selectedId) < 0)
          ? 0
          : _dockIndexFor(widget.selectedId),
    );
  }

  bool _calculatorVisible = false;
  bool _hasEverOpenedCalculator = false;

  void _openCalculator() {
    if (widget.selectedId == 'calculators') return;
    setState(() {
      _calculatorVisible = true;
      _hasEverOpenedCalculator = true;
      _collapsed = true;
    });
  }

  void _closeCalculator() {
    setState(() {
      _calculatorVisible = false;
      _collapsed = false;
    });
  }

  void _toggleCalculator() {
    if (widget.selectedId == 'calculators') return;
    if (_calculatorVisible) {
      _closeCalculator();
    } else {
      _openCalculator();
    }
  }

  bool get _isCommunityRoute =>
      widget.selectedId == 'community' ||
      widget.selectedId.startsWith('community_');

  List<AppNavItem> get _flatItems =>
      widget.sections.expand((AppNavSection s) => s.items).toList();

  /// The (at most four) destinations the phone dock shows.
  List<AppNavItem> get _dockItems {
    if (_isCommunityRoute) {
      return const <AppNavItem>[
        AppNavItem(
          id: 'community_feed',
          label: 'Feed',
          icon: Icons.dynamic_feed_outlined,
          selectedIcon: Icons.dynamic_feed_rounded,
        ),
        AppNavItem(
          id: 'community_explore',
          label: 'Explore',
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore_rounded,
        ),
        AppNavItem(
          id: 'community_network',
          label: 'Network',
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_rounded,
        ),
        AppNavItem(
          id: 'community_profile',
          label: 'Profile',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
        ),
      ];
    }
    return (widget.mobilePrimaryItems ?? _flatItems.take(4).toList())
        .take(4)
        .toList();
  }

  /// Dock slot that owns [id], or -1 when no slot does.
  ///
  /// Every settings surface answers to the single `settings` slot: the sidebar
  /// lists them individually, the dock cannot.
  int _dockIndexFor(String id) {
    if (_isCommunityRoute) {
      if (id == 'community' || id == 'community_feed') return 0;
      if (id == 'community_explore') return 1;
      if (id == 'community_network') return 2;
      if (id == 'community_profile') return 3;
      return 0;
    }
    final List<AppNavItem> items = _dockItems;
    final int direct = items.indexWhere((AppNavItem item) => item.id == id);
    if (direct >= 0) return direct;
    if (id.startsWith('settings')) {
      return items.indexWhere((AppNavItem item) => item.id == 'settings');
    }
    return -1;
  }

  @override
  void initState() {
    super.initState();
    _initDockControllers();
  }

  void _initDockControllers() {
    final int mainIndex = !_isCommunityRoute
        ? _dockIndexFor(widget.selectedId)
        : 0;
    final int commIndex = _isCommunityRoute
        ? _dockIndexFor(widget.selectedId)
        : 0;
    _mainDockController ??= QuietDockController(
      initialIndex: mainIndex < 0 ? 0 : mainIndex,
    );
    _communityDockController ??= QuietDockController(
      initialIndex: commIndex < 0 ? 0 : commIndex,
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    _initDockControllers();
  }

  @override
  void dispose() {
    _mainDockController?.dispose();
    _communityDockController?.dispose();
    super.dispose();
  }

  void _toggleDesktopSidebar() {
    setState(() => _collapsed = !_collapsed);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      if (widget.selectedId == 'calculators' && _calculatorVisible) {
        _closeCalculator();
      }
      _syncDock();
    }
  }

  /// Slides the dock to whichever slot owns the new destination.
  void _syncDock() {
    final int index = _dockIndexFor(widget.selectedId);
    if (index < 0) return;
    if (_activeDockController.index != index) {
      _activeDockController.syncIndex(index);
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      _activeDockController.goToIndex(index);
    });
  }

  /// Loading stand-in for a dock slot that is not the live one.
  Widget _pagePlaceholder(BuildContext context, AppNavItem item) =>
      widget.pagePlaceholderBuilder?.call(context, item) ?? UiSkeleton.page();

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiResponsive r = context.uiRes;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final bool keyboardVisible = mediaQuery.viewInsets.bottom > 0;

    // One page slot: the chrome around a screen, plus the transition between
    // whatever two things occupy it. On a phone every dock slot builds its own,
    // so a slot can cross-fade its skeleton into the real screen independently
    // of its neighbours.
    Widget surface({required Widget child, required String childKey}) {
      final BorderRadius borderRadius = context.radius(theme.radii.xl);
      final Widget switcher = UiStaggeredPageTransition(
        child: KeyedSubtree(key: ValueKey<String>(childKey), child: child),
      );

      return Container(
        key: const ValueKey<String>('app-content-surface'),
        margin: r.isMobile
            ? EdgeInsets.zero
            : EdgeInsets.fromLTRB(
                0,
                0,
                context.sp(theme.spacing.xs + 3),
                context.sp(theme.spacing.xs + 3),
              ),
        decoration: r.isMobile
            ? null
            : BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: theme.colors.border,
                  width: theme.borders.hairline,
                ),
              ),
        child: r.isMobile
            ? switcher
            : ClipRRect(
                borderRadius: borderRadius,
                clipBehavior: Clip.antiAlias,
                child: switcher,
              ),
      );
    }

    final String surfaceKey = widget.child.key != null
        ? 'page_${widget.selectedId}_${widget.child.key}'
        : 'page_${widget.selectedId}';
    final Widget contentSurface = surface(
      child: widget.child,
      childKey: surfaceKey,
    );

    void openResearchOverlay() {
      UiDrawer.show<void>(
        context,
        title: 'Research desk',
        showHeader: false,
        contentPadding: EdgeInsets.zero,
        scrollable: false,
        child: Builder(
          builder: (overlayContext) => widget.researchPanelBuilder!(
            overlayContext,
            () => Navigator.of(overlayContext).pop(),
            true,
          ),
        ),
      );
    }

    Widget topBar({bool researchVisible = false, VoidCallback? onResearch}) =>
        AppTopBar(
          researchVisible: researchVisible,
          onResearch: onResearch,
          onCalculator: (r.isMobile || widget.selectedId == 'calculators')
              ? null
              : _toggleCalculator,
          calculatorVisible: _calculatorVisible,
          trader: widget.trader,
          tier: widget.tier,
          onSearch: widget.onSearch,
          searchQuery: widget.searchQuery,
          searchHint: widget.searchHint,
          onSearchChanged: widget.onSearchChanged,
          searchTargetKey: widget.searchTargetKey,
          headerActions: widget.headerActions,
          primaryAction: widget.primaryAction,
          primaryActionLabel: widget.primaryActionLabel,
          onPrimaryAction: widget.onPrimaryAction,
          onHelp: widget.onHelp,
          onLogout: widget.onLogout,
          statusBadgeText: widget.statusBadgeText,
          showStatusBadge: widget.showStatusBadge,
          onNotifications: widget.onNotifications,
          onSettings: widget.onSettings,
          onAi: widget.onAi,
          unread: widget.unreadNotifications,
          showLogo: false,
          title: widget.pageTitle,
          sectionTitle: widget.pageSectionTitle,
          selectedId: widget.selectedId,
          sections: widget.sections,
          mobilePrimaryItems: widget.mobilePrimaryItems,
          mobileMoreItems: widget.mobileMoreItems,
          pageIcon: widget.pageIcon,
          onBack: widget.onBack,
          leading: r.isMobile
              ? null
              : UiIconButton(
                  icon: _collapsed
                      ? Icons.menu_open_rounded
                      : Icons.notes_rounded,
                  size: UiSize.sm,
                  tooltip: 'Toggle sidebar',
                  onPressed: _toggleDesktopSidebar,
                ),
        );

    if (r.isMobile) {
      final AppMobileDockMetrics dockMetrics = AppMobileDockMetrics.of(context);
      final double dockHeight = dockMetrics.height;
      final double dockWidth = dockMetrics.dockWidth;
      final double dockMargin = _isNativeAndroid ? 8 : 16;
      final double mobileHeaderClearance = widget.hideMobileTopBar
          ? 0.0
          : (_isNativeAndroid ? 50.0 : 54.0);
      // Keep the real system bottom safe-area inset instead of inflating it
      // with the floating dock height so SafeArea pages never render a blank
      // dead band at the bottom of the screen. Provide top clearance for the
      // floating frosted-glass header so content starts cleanly beneath it and
      // scrolls smoothly behind it.
      final MediaQueryData dockSafeMedia = mediaQuery
          .removeViewInsets(removeBottom: true)
          .copyWith(
            padding: mediaQuery.padding.copyWith(
              top: mediaQuery.padding.top + mobileHeaderClearance,
              bottom: mediaQuery.padding.bottom,
            ),
          );
      final Widget dockSafeContent = MediaQuery(
        data: dockSafeMedia,
        child: contentSurface,
      );
      final List<AppNavItem> destinations = _dockItems;
      final int selectedIndex = _dockIndexFor(widget.selectedId);
      // A destination reached from the quick grid or the top bar owns no dock
      // slot, so the page the dock is already showing hosts it.
      final int activeIndex = selectedIndex < 0
          ? _activeDockController.index
          : selectedIndex;
      if (_activeDockController.index != activeIndex) {
        _activeDockController.syncIndex(activeIndex);
      }
      AppNavItem? activeMoreItem;
      for (final AppNavItem item in widget.mobileMoreItems) {
        if (item.id == widget.selectedId ||
            (item.subItems?.any((child) => child.id == widget.selectedId) ??
                false)) {
          activeMoreItem = item;
          break;
        }
      }
      final bool moreRouteSelected = activeMoreItem != null;
      final List<AppNavItem> quickGridNavItems =
          <AppNavItem>[
            if (_isCommunityRoute) ...<AppNavItem>[
              for (final AppNavItem item
                  in (widget.mobilePrimaryItems ?? const <AppNavItem>[]))
                if (item.id != 'community' && !item.id.startsWith('community_'))
                  item,
              const AppNavItem(
                id: 'community_bookmarks',
                label: 'Bookmarks',
                icon: Icons.bookmark_outline_rounded,
              ),
            ],
            ...widget.mobileMoreItems,
          ].fold<List<AppNavItem>>(<AppNavItem>[], (
            List<AppNavItem> acc,
            AppNavItem item,
          ) {
            if (acc.every((AppNavItem existing) => existing.id != item.id)) {
              acc.add(item);
            }
            return acc;
          });
      final Set<int> lockedDestinationIndices = <int>{
        for (int i = 0; i < destinations.length; i++)
          if (destinations[i].tierLocked) i,
      };
      final Set<int> lockedCenterIndices = <int>{
        for (int i = 0; i < quickGridNavItems.length; i++)
          if (quickGridNavItems[i].tierLocked) i,
      };
      final Widget dockScaffold = AppQuietDockScaffold(
        key: ValueKey<String>(
          'quiet_dock_${_isCommunityRoute ? "community" : "main"}',
        ),
        activeDestination: surfaceKey,
        destinations: destinations
            .map(
              (AppNavItem item) => QuietDockDestination(
                icon: item.icon,
                selectedIcon: item.selectedIcon ?? item.icon,
                label: item.label,
                tooltip: item.label,
              ),
            )
            .toList(),
        initialIndex: activeIndex,
        controller: _activeDockController,
        onDestinationTap: (index) =>
            widget.onExternalSelect?.call(destinations[index].id) ?? false,
        onDestinationSelected: (int index) {
          if (index >= 0 && index < destinations.length) {
            widget.onSelect(destinations[index].id);
          }
        },
        lockedDestinationIndices: lockedDestinationIndices,
        lockedCenterIndices: lockedCenterIndices,
        leftActionIcon: _isCommunityRoute
            ? Icons.edit_note_rounded
            : (widget.onSearch != null ? Icons.search_rounded : null),
        leftActionTooltip: _isCommunityRoute
            ? 'Writing Desk'
            : (widget.searchHint ?? 'Search'),
        onLeftActionPressed: _isCommunityRoute
            ? () => widget.onSelect('workspace')
            : widget.onSearch,
        centerAction: QuietDockCenterAction(
          semanticLabel: _isCommunityRoute ? 'Switch to App' : 'More tools',
          icon: _isCommunityRoute
              ? Icons.apps_rounded
              : Icons.grid_view_rounded,
          closeIcon: moreRouteSelected
              ? (activeMoreItem.selectedIcon ?? activeMoreItem.icon)
              : Icons.close_rounded,
          columns: 3,
          items: quickGridNavItems
              .map(
                (AppNavItem item) => QuickGridItem(
                  icon: item.selectedIcon ?? item.icon,
                  label: item.label,
                  onTap: () => widget.onSelect(item.id),
                ),
              )
              .toList(),
        ),
        centerActionActive: moreRouteSelected,
        swipeEnabled: false,
        lazy: true,
        keepAlive: false,
        backgroundColor: theme.colors.background,
        pageBuilder: (BuildContext context, int index) {
          // Only the live destination gets the real page. Handing the same
          // content to every slot is what made a swipe reveal a second copy of
          // the screen being dragged away; a skeleton reads as the next screen
          // arriving, and keeps the neighbour's widget tree unbuilt until the
          // swipe actually commits.
          if (index == activeIndex) return dockSafeContent;
          final AppNavItem item = destinations[index];
          return MediaQuery(
            data: dockSafeMedia,
            child: surface(
              child: _pagePlaceholder(context, item),
              childKey: 'placeholder_${item.id}',
            ),
          );
        },
        theme: QuietDockTheme(
          background: keyboardVisible
              ? Colors.transparent
              : theme.colors.surface.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.62 : 0.74,
                ),
          borderColor: keyboardVisible
              ? Colors.transparent
              : theme.colors.borderStrong.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.65 : 0.75,
                ),
          selectedColor: theme.colors.primary,
          unselectedColor: theme.colors.foregroundMuted,
          indicatorColor: keyboardVisible
              ? Colors.transparent
              : theme.colors.primary.withValues(alpha: 0.12),
          indicatorBorderColor: keyboardVisible
              ? Colors.transparent
              : theme.colors.primary.withValues(alpha: 0.3),
          shadowColor: keyboardVisible
              ? Colors.transparent
              : Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.36 : 0.10,
                ),
          width: keyboardVisible ? 0 : dockWidth,
          height: keyboardVisible ? 0 : dockHeight,
          margin: keyboardVisible ? 0 : dockMargin,
          iconSize: keyboardVisible ? 0 : dockMetrics.iconSize,
          blur: 18,
          frosted: !keyboardVisible,
          showLabels: false,
          pageDuration: theme.motion.normal,
        ),
      );
      // Float the mobile header above the full-bleed dock scaffold so page
      // content scrolls smoothly underneath its frosted-glass surface instead
      // of clipping against a solid opaque bar.
      final Widget mobileShell = Stack(
        children: <Widget>[
          Positioned.fill(child: dockScaffold),
          if (!widget.hideMobileTopBar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: topBar(
                onResearch: widget.researchPanelBuilder == null
                    ? null
                    : openResearchOverlay,
              ),
            ),
        ],
      );
      // Let Scaffold resize the workspace and consume the IME inset for its
      // body. The dock and its pages then share the same usable viewport.
      return Scaffold(
        key: const ValueKey<String>('app-mobile-shell-background'),
        backgroundColor: theme.colors.background,
        body: mobileShell,
      );
    }

    final Widget expandedSidebar = AppSidebar(
      sections: widget.sections,
      selectedId: widget.selectedId,
      onSelect: widget.onSelect,
      collapsed: false,
      trader: widget.trader,
      workspaceName: widget.workspaceName,
      tierLabel: widget.tierLabel,
      footer: widget.sidebarFooter,
      onNavigate: widget.onSelect,
      onUserLogout: widget.onLogout,
      userMenuItems: widget.userMenuItems,
    );

    final Widget adaptiveSidebar = r.isTablet
        ? AppSidebar(
            sections: widget.sections,
            selectedId: widget.selectedId,
            onSelect: widget.onSelect,
            collapsed: true,
            trader: widget.trader,
            workspaceName: widget.workspaceName,
            tierLabel: widget.tierLabel,
            footer: widget.sidebarFooter,
            onNavigate: widget.onSelect,
            onUserLogout: widget.onLogout,
            userMenuItems: widget.userMenuItems,
          )
        : ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              width: _collapsed ? 0 : context.sz(244),
              child: OverflowBox(
                alignment: Alignment.centerRight,
                minWidth: context.sz(244),
                maxWidth: context.sz(244),
                child: IgnorePointer(
                  ignoring: _collapsed,
                  child: expandedSidebar,
                ),
              ),
            ),
          );

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: <Widget>[
                adaptiveSidebar,
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final canDock = box.maxWidth >= 1080;
                      final hasResearch = widget.researchPanelBuilder != null;
                      final visible =
                          hasResearch && canDock && _researchVisible;
                      void closeResearch() =>
                          setState(() => _researchVisible = false);
                      final workspace = Column(
                        children: [
                          topBar(
                            researchVisible: visible,
                            onResearch: !hasResearch
                                ? null
                                : () {
                                    if (canDock) {
                                      setState(
                                        () => _researchVisible =
                                            !_researchVisible,
                                      );
                                    } else {
                                      openResearchOverlay();
                                    }
                                  },
                          ),
                          Expanded(
                            child: MediaQuery.removePadding(
                              context: context,
                              removeTop: true,
                              child: contentSurface,
                            ),
                          ),
                        ],
                      );
                      // Keep the primary branch mounted when Focus mode changes width.
                      return UiSplitPane(
                        key: const ValueKey('app-research-split'),
                        showDetail: visible,
                        initialRatio: .70,
                        minRatio: .64,
                        maxRatio: .74,
                        primary: workspace,
                        detail: visible
                            ? SafeArea(
                                left: false,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    0,
                                    context.sp(theme.spacing.xs),
                                    context.sp(theme.spacing.xs + 3),
                                    context.sp(theme.spacing.xs + 3),
                                  ),
                                  child: UiCard(
                                    key: const ValueKey('app-research-surface'),
                                    padding: EdgeInsets.zero,
                                    variant: UiCardVariant.elevated,
                                    child: ClipRRect(
                                      borderRadius: context.radius(
                                        theme.radii.xl,
                                      ),
                                      child: widget.researchPanelBuilder!(
                                        context,
                                        closeResearch,
                                        false,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
                if (!r.isMobile && widget.selectedId != 'calculators')
                  ClipRect(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                      width: _calculatorVisible
                          ? (context.sz(360) + context.sp(theme.spacing.xs + 3))
                          : 0,
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth:
                            context.sz(360) + context.sp(theme.spacing.xs + 3),
                        maxWidth:
                            context.sz(360) + context.sp(theme.spacing.xs + 3),
                        child: IgnorePointer(
                          ignoring: !_calculatorVisible,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              0,
                              context.sp(theme.spacing.xs),
                              context.sp(theme.spacing.xs + 3),
                              context.sp(theme.spacing.xs + 3),
                            ),
                            child: Container(
                              width: context.sz(360),
                              decoration: BoxDecoration(
                                color: theme.colors.surface,
                                borderRadius: context.radius(theme.radii.xl),
                                border: Border.all(
                                  color: theme.colors.border,
                                  width: theme.borders.hairline,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.16),
                                    blurRadius: 16,
                                    offset: const Offset(-2, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: context.radius(theme.radii.xl),
                                child: Column(
                                  children: <Widget>[
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: context.sp(
                                          theme.spacing.md,
                                        ),
                                        vertical: context.sp(theme.spacing.xs),
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colors.surface,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: theme.colors.border,
                                            width: theme.borders.hairline,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Icon(
                                            Icons.calculate_rounded,
                                            size: context.sz(18),
                                            color: theme.colors.primary,
                                          ),
                                          SizedBox(
                                            width: context.sp(theme.spacing.xs),
                                          ),
                                          Text(
                                            'Trading Calculator',
                                            style: context.uiText.bodyStrong
                                                .copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const Spacer(),
                                          UiIconButton(
                                            icon: Icons.close_rounded,
                                            size: UiSize.xs,
                                            tooltip: 'Close Calculator',
                                            onPressed: _closeCalculator,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: _hasEverOpenedCalculator
                                          ? const CalculatorsScreen(
                                              initiallyOpened: true,
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
}

/// Header workspace/team switcher tile inside sidebar.
class AppWorkspaceTile extends StatelessWidget {
  const AppWorkspaceTile({
    super.key,
    required this.collapsed,
    this.workspaceName = 'Acme Inc',
    this.tierLabel = 'Enterprise',
    this.switchItems = const <AppNavItem>[],
    this.onSelectSwitch,
  });

  final bool collapsed;
  final String workspaceName;
  final String tierLabel;
  final List<AppNavItem> switchItems;
  final ValueChanged<String>? onSelectSwitch;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Widget tile = Container(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed
            ? context.sp(theme.spacing.xxs)
            : context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xs + 1),
      ),
      decoration: collapsed
          ? null
          : BoxDecoration(
              color: theme.colors.surface.withValues(alpha: 0.6),
              borderRadius: context.radius(theme.radii.lg),
              border: Border.all(
                color: theme.colors.border.withValues(alpha: 0.6),
                width: theme.borders.hairline,
              ),
            ),
      child: Row(
        mainAxisAlignment: collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: <Widget>[
          AppLogoMark(size: context.sz(20), rounded: false),
          if (!collapsed) ...<Widget>[
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    workspaceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.bodyStrong.copyWith(
                      fontSize: context.fs(13.0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    tierLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundSubtle,
                      fontSize: context.fs(11.0),
                    ),
                  ),
                ],
              ),
            ),
            if (switchItems.isNotEmpty)
              Icon(
                Icons.swap_vert_rounded,
                size: context.sz(14),
                color: theme.colors.foregroundMuted,
              ),
          ],
        ],
      ),
    );

    final Widget interactiveTile =
        switchItems.isNotEmpty && onSelectSwitch != null
        ? UiDropdownMenu(
            actions: switchItems
                .map(
                  (AppNavItem item) => UiMenuItem(
                    label: item.label,
                    icon: item.selectedIcon ?? item.icon,
                    intent: item.label.contains('(Active)')
                        ? UiIntent.primary
                        : UiIntent.neutral,
                    onTap: () => onSelectSwitch!(item.id),
                  ),
                )
                .toList(),
            child: tile,
          )
        : tile;

    return collapsed
        ? UiTooltip(
            message: '$workspaceName ($tierLabel) · Switch Workspace',
            child: interactiveTile,
          )
        : interactiveTile;
  }
}

/// Desktop sidebar with grouped sections and collapse support.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.sections,
    required this.selectedId,
    required this.onSelect,
    this.collapsed = false,
    this.trader,
    this.workspaceName,
    this.tierLabel,
    this.footer,
    this.onUserLogout,
    this.onUserUpgrade,
    this.onNavigate,
    this.userMenuItems = const <AppNavItem>[],
  });

  final List<AppNavSection> sections;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final bool collapsed;
  final AppTrader? trader;
  final String? workspaceName;
  final String? tierLabel;
  final Widget? footer;
  final VoidCallback? onUserLogout;
  final VoidCallback? onUserUpgrade;
  final ValueChanged<String>? onNavigate;
  final List<AppNavItem> userMenuItems;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double collapsedWidth = context.uiRes.isTablet ? 76 : 64;
    return AnimatedContainer(
      duration: theme.motion.normal,
      curve: theme.motion.curve,
      width: context.sz(collapsed ? collapsedWidth : 244),
      decoration: BoxDecoration(color: theme.colors.background),
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(
          collapsed ? theme.spacing.xxs : theme.spacing.xs + 1,
        ),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppWorkspaceTile(
              collapsed: collapsed,
              workspaceName:
                  workspaceName ??
                  (trader?.tier == AppTier.enterprise
                      ? 'Institutional Desk'
                      : (trader?.tier == AppTier.premium
                            ? 'AlphaJournal Pro Terminal'
                            : 'AlphaJournal Desk')),
              tierLabel:
                  tierLabel ??
                  (trader?.tier == AppTier.enterprise
                      ? 'Enterprise Admin'
                      : (trader?.tier == AppTier.premium
                            ? 'Active Trader'
                            : 'Standard')),
              switchItems: userMenuItems
                  .where(
                    (AppNavItem i) =>
                        i.id.startsWith('switch_role_') ||
                        i.id == 'toggle_profile_mode',
                  )
                  .toList(),
              onSelectSwitch: onNavigate ?? onSelect,
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.xxs),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final AppNavSection s in sections) ...<Widget>[
                      if (collapsed && s != sections.first)
                        SizedBox(height: context.sp(theme.spacing.md)),
                      if (s.title != null && !collapsed)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.sp(theme.spacing.sm),
                            context.sp(theme.spacing.md),
                            context.sp(theme.spacing.sm),
                            context.sp(theme.spacing.xxs),
                          ),
                          child: Text(
                            s.title!.toUpperCase(),
                            style: context.uiText.caption.copyWith(
                              color: theme.colors.foregroundSubtle,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              fontSize: context.fs(11.0),
                            ),
                          ),
                        ),
                      for (final AppNavItem i in s.items)
                        AppNavTile(
                          item: i,
                          selectedId: selectedId,
                          collapsed: collapsed,
                          onSelect: onSelect,
                        ),
                      SizedBox(
                        height: context.sp(
                          collapsed ? theme.spacing.sm : theme.spacing.xs,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.xs),
                  vertical: context.sp(theme.spacing.xxs),
                ),
                child: footer!,
              ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            // No stand-in identity: a sidebar rendered before anyone is signed in
            // shows no user tile rather than a fictional account.
            if (trader case final AppTrader person)
              AppNavUserTile(
                trader: person,
                collapsed: collapsed,
                onLogout: onUserLogout,
                onUpgrade: onUserUpgrade,
                onNavigate: onNavigate,
                menuItems: userMenuItems,
              ),
          ],
        ),
      ),
    );
  }
}

/// User menu tile at sidebar bottom (NavUser equivalent).
class AppNavUserTile extends StatelessWidget {
  const AppNavUserTile({
    super.key,
    required this.trader,
    required this.collapsed,
    this.onLogout,
    this.onUpgrade,
    this.onNavigate,
    this.menuItems = const <AppNavItem>[],
  });

  final AppTrader trader;
  final bool collapsed;
  final VoidCallback? onLogout;
  final VoidCallback? onUpgrade;
  final ValueChanged<String>? onNavigate;
  final List<AppNavItem> menuItems;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    // Nothing is invented here. A profile that has not filled in a display name
    // is shown by the local part of its handle, and an account whose handle is
    // not an address simply has no secondary line.
    final String handle = trader.handle.trim();
    final String displayName = trader.displayName?.trim() ?? '';
    final String name = displayName.isNotEmpty
        ? displayName
        : (handle.contains('@') ? handle.split('@').first : handle);
    final String email = handle.contains('@') ? handle : '';

    /// The plan directly above the current one, or null on the top plan — which
    /// is how the upgrade entry knows both its label and whether to exist.
    final AppTier? nextTier = switch (trader.tier) {
      AppTier.free => AppTier.premium,
      AppTier.premium => AppTier.enterprise,
      AppTier.enterprise => null,
    };

    final Widget trigger = UiInteractive(
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        padding: EdgeInsets.symmetric(
          horizontal: collapsed
              ? ctx.sp(theme.spacing.xxs)
              : ctx.sp(theme.spacing.sm),
          vertical: ctx.sp(theme.spacing.xs),
        ),
        decoration: collapsed
            ? null
            : BoxDecoration(
                color: s.hovered
                    ? theme.colors.surfaceHover
                    : theme.colors.surface.withValues(alpha: 0.5),
                borderRadius: ctx.radius(theme.radii.lg),
                border: Border.all(
                  color: theme.colors.border.withValues(alpha: 0.5),
                  width: theme.borders.hairline,
                ),
              ),
        child: Row(
          mainAxisAlignment: collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: <Widget>[
            UiAvatar(imageUrl: trader.avatarUrl, name: name, size: UiSize.md),
            if (!collapsed) ...<Widget>[
              SizedBox(width: ctx.sp(theme.spacing.sm)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ctx.uiText.bodyStrong.copyWith(
                        fontSize: ctx.fs(13.0),
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ctx.uiText.caption.copyWith(
                          color: theme.colors.foregroundSubtle,
                          fontSize: ctx.fs(11.0),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.unfold_more_rounded,
                size: ctx.sz(14),
                color: theme.colors.foregroundMuted,
              ),
            ],
          ],
        ),
      ),
    );

    final Widget menu = UiDropdownMenu(
      actions: <UiMenuItem>[
        if (onUpgrade != null && nextTier != null)
          UiMenuItem(
            label: 'Upgrade to ${AppTokens.tierLabel(nextTier)}',
            icon: Icons.auto_awesome,
            intent: UiIntent.primary,
            onTap: onUpgrade,
          ),
        ...menuItems.map(
          (AppNavItem item) => UiMenuItem(
            label: item.label,
            icon: item.icon,
            onTap: () => onNavigate?.call(item.id),
          ),
        ),
        UiMenuItem(
          label: 'Log out',
          icon: Icons.logout_rounded,
          intent: UiIntent.danger,
          onTap: onLogout,
        ),
      ],
      child: trigger,
    );

    return collapsed
        ? UiTooltip(
            message: email.isEmpty ? name : '$name ($email)',
            child: menu,
          )
        : menu;
  }
}

/// A sidebar entry with sub-items (NavMain) and context menu (NavProjects) support.
class AppNavTile extends StatefulWidget {
  const AppNavTile({
    super.key,
    required this.item,
    required this.selectedId,
    required this.onSelect,
    this.collapsed = false,
  });

  final AppNavItem item;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final bool collapsed;

  @override
  State<AppNavTile> createState() => _AppNavTileState();
}

class _AppNavTileState extends State<AppNavTile> {
  bool _expanded = false;

  bool get _isSelected =>
      widget.item.id == widget.selectedId ||
      (widget.item.subItems?.any((sub) => sub.id == widget.selectedId) ??
          false);

  @override
  void initState() {
    super.initState();
    if (_isSelected && widget.item.subItems != null) {
      _expanded = true;
    }
  }

  @override
  void didUpdateWidget(AppNavTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      final bool selectedSubItem =
          widget.item.subItems?.any(
            (AppNavItem item) => item.id == widget.selectedId,
          ) ??
          false;
      final bool selectedParentWithSubs =
          widget.item.id == widget.selectedId &&
          (widget.item.subItems?.isNotEmpty ?? false);
      if ((selectedSubItem || selectedParentWithSubs) && !_expanded) {
        _expanded = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool hasSubItems =
        widget.item.subItems != null && widget.item.subItems!.isNotEmpty;
    final bool hasActions =
        widget.item.actionItems != null && widget.item.actionItems!.isNotEmpty;

    final Widget mainTile = UiInteractive(
      onTap: () {
        if (hasSubItems && !widget.collapsed && !widget.item.tierLocked) {
          setState(() => _expanded = !_expanded);
        }
        widget.onSelect(widget.item.id);
      },
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        margin: EdgeInsets.only(bottom: ctx.sp(theme.spacing.xxs)),
        padding: EdgeInsets.symmetric(
          horizontal: widget.collapsed
              ? ctx.sp(theme.spacing.xs)
              : ctx.sp(theme.spacing.sm),
          vertical: ctx.sp(theme.spacing.xs + 0.5),
        ),
        decoration: BoxDecoration(
          color: _isSelected
              ? theme.colors.primary.withValues(alpha: 0.12)
              : (s.hovered ? theme.colors.surfaceHover : Colors.transparent),
          borderRadius: ctx.radius(theme.radii.md),
          border: _isSelected
              ? Border.all(
                  color: theme.colors.primary.withValues(alpha: 0.25),
                  width: theme.borders.hairline,
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: widget.collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(
                  _isSelected
                      ? (widget.item.selectedIcon ?? widget.item.icon)
                      : widget.item.icon,
                  size: ctx.sz(17),
                  color: _isSelected
                      ? theme.colors.primary
                      : theme.colors.foregroundMuted,
                ),
                if (widget.collapsed && widget.item.tierLocked)
                  Positioned(
                    top: -4,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: theme.colors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colors.borderStrong,
                          width: theme.borders.hairline,
                        ),
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: ctx.sz(8),
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ),
              ],
            ),
            if (!widget.collapsed) ...<Widget>[
              SizedBox(width: ctx.sp(theme.spacing.sm + 1)),
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ctx.uiText.body.copyWith(
                    fontSize: ctx.fs(13.0),
                    color: _isSelected
                        ? theme.colors.foreground
                        : theme.colors.foregroundMuted,
                    fontWeight: _isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.item.tierLocked)
                Icon(
                  Icons.lock_outline_rounded,
                  size: ctx.sz(14),
                  color: theme.colors.foregroundSubtle,
                )
              else if (widget.item.badgeCount != null &&
                  widget.item.badgeCount! > 0)
                UiBadge(
                  label: '${widget.item.badgeCount}',
                  intent: UiIntent.primary,
                  filled: true,
                )
              else if (hasActions)
                UiDropdownMenu(
                  actions: widget.item.actionItems!
                      .map(
                        (act) => UiMenuItem(
                          label: act.label,
                          icon: act.icon,
                          intent: act.destructive
                              ? UiIntent.danger
                              : UiIntent.neutral,
                          onTap: act.onPressed,
                        ),
                      )
                      .toList(),
                  child: Padding(
                    padding: EdgeInsets.all(ctx.sp(theme.spacing.xxs)),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: ctx.sz(14),
                      color: theme.colors.foregroundSubtle,
                    ),
                  ),
                )
              else if (hasSubItems)
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0.0,
                  duration: theme.motion.fast,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: ctx.sz(14),
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
            ],
          ],
        ),
      ),
    );

    final Widget wrappedTile = widget.collapsed
        ? UiTooltip(message: widget.item.label, child: mainTile)
        : mainTile;

    if (!hasSubItems || widget.collapsed) {
      return wrappedTile;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        wrappedTile,
        if (_expanded)
          Padding(
            padding: EdgeInsets.only(
              left: context.sp(theme.spacing.sm),
              top: context.sp(theme.spacing.xxs),
              bottom: context.sp(theme.spacing.xxs),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: <Widget>[
                  Container(
                    width: theme.borders.thick,
                    margin: EdgeInsets.only(left: context.sp(theme.spacing.xs)),
                    color: theme.colors.border.withValues(alpha: 0.5),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final sub in widget.item.subItems!)
                          UiInteractive(
                            onTap: () => widget.onSelect(sub.id),
                            builder: (BuildContext ctx, UiInteractiveState s) {
                              final bool subSelected =
                                  sub.id == widget.selectedId ||
                                  (widget.item.id == widget.selectedId &&
                                      sub == widget.item.subItems!.first);
                              return AnimatedContainer(
                                duration: theme.motion.fast,
                                margin: EdgeInsets.only(
                                  bottom: ctx.sp(theme.spacing.xxs),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: ctx.sp(theme.spacing.sm),
                                  vertical: ctx.sp(theme.spacing.xs),
                                ),
                                decoration: BoxDecoration(
                                  color: subSelected
                                      ? theme.colors.primary.withValues(
                                          alpha: 0.12,
                                        )
                                      : (s.hovered
                                            ? theme.colors.surfaceHover
                                            : Colors.transparent),
                                  borderRadius: ctx.radius(theme.radii.md),
                                  border: subSelected
                                      ? Border.all(
                                          color: theme.colors.primary
                                              .withValues(alpha: 0.25),
                                          width: theme.borders.hairline,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        sub.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: ctx.uiText.body.copyWith(
                                          fontSize: ctx.fs(13.0),
                                          color: subSelected
                                              ? theme.colors.foreground
                                              : theme.colors.foregroundMuted,
                                          fontWeight: subSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (sub.tierLocked) ...<Widget>[
                                      SizedBox(
                                        width: ctx.sp(theme.spacing.xs),
                                      ),
                                      Icon(
                                        Icons.lock_outline_rounded,
                                        size: ctx.sz(13),
                                        color: theme.colors.foregroundSubtle,
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Top app bar: breadcrumb with Live badge, centered wide search, primary action, notifications, help and user avatar.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    this.trader,
    this.tier = AppTier.free,
    this.onSearch,
    this.searchQuery,
    this.searchHint,
    this.onSearchChanged,
    this.searchTargetKey,
    this.headerActions = const <Widget>[],
    this.primaryAction,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onNotifications,
    this.onSettings,
    this.onAi,
    this.onHelp,
    this.onLogout,
    this.unread = 0,
    this.leading,
    this.showLogo = false,
    this.title,
    this.sectionTitle,
    this.selectedId,
    this.sections,
    this.mobilePrimaryItems,
    this.mobileMoreItems,
    this.pageIcon,
    this.onBack,
    this.onResearch,
    this.researchVisible = false,
    this.onCalculator,
    this.calculatorVisible = false,
    this.statusBadgeText = '',
    this.showStatusBadge = false,
  });

  final AppTrader? trader;
  final AppTier tier;
  final VoidCallback? onSearch;
  final String? searchQuery;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final GlobalKey? searchTargetKey;
  final List<Widget> headerActions;
  final Widget? primaryAction;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;
  final VoidCallback? onAi;
  final VoidCallback? onHelp;
  final VoidCallback? onLogout;
  final int unread;
  final Widget? leading;
  final bool showLogo;
  final String? title;
  final String? sectionTitle;
  final String? selectedId;
  final List<AppNavSection>? sections;
  final List<AppNavItem>? mobilePrimaryItems;
  final List<AppNavItem>? mobileMoreItems;
  final IconData? pageIcon;
  final VoidCallback? onBack;
  final VoidCallback? onResearch;
  final bool researchVisible;
  final VoidCallback? onCalculator;
  final bool calculatorVisible;
  final String statusBadgeText;
  final bool showStatusBadge;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _buildHeader(context, constraints.maxWidth),
  );

  Widget _buildHeader(BuildContext context, double availableWidth) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    final bool compactAndroid = isMobile && _isNativeAndroid;
    final bool isCompactHeader =
        isMobile || context.uiRes.isTablet || availableWidth < context.sz(860);

    String sectionTitle = this.sectionTitle ?? 'Terminal';
    String pageTitle = title ?? 'Dashboard';

    IconData? activeIcon = pageIcon;

    if (title == null && sections != null && selectedId != null) {
      for (final s in sections!) {
        for (final item in s.items) {
          if (item.id == selectedId) {
            sectionTitle = s.title ?? 'Terminal';
            pageTitle = item.label;
            activeIcon ??= item.icon;
          } else if (item.subItems != null) {
            for (final sub in item.subItems!) {
              if (sub.id == selectedId) {
                sectionTitle = item.label;
                pageTitle = sub.label;
                activeIcon ??= sub.icon;
              }
            }
          }
        }
      }
    }

    if (activeIcon == null &&
        mobilePrimaryItems != null &&
        selectedId != null) {
      for (final item in mobilePrimaryItems!) {
        if (item.id == selectedId) {
          activeIcon = item.icon;
          break;
        }
      }
    }
    if (activeIcon == null && mobileMoreItems != null && selectedId != null) {
      for (final item in mobileMoreItems!) {
        if (item.id == selectedId) {
          activeIcon = item.icon;
          break;
        }
      }
    }
    if (activeIcon == null && selectedId != null) {
      activeIcon = switch (selectedId) {
        'overview' => Icons.dashboard_outlined,
        'search' => Icons.search_rounded,
        'notifications' => Icons.notifications_none_rounded,
        'ai_copilot' => Icons.auto_awesome_outlined,
        'settings' || 'settings_profile' => Icons.person_outline_rounded,
        'settings_security' => Icons.lock_outline_rounded,
        'settings_affiliate_perks' => Icons.handshake_outlined,
        'settings_billing' => Icons.credit_card_outlined,
        'settings_appearance' => Icons.palette_outlined,
        'settings_trading' => Icons.candlestick_chart_outlined,
        'settings_ai' => Icons.auto_awesome_outlined,
        'settings_privacy' => Icons.security_rounded,
        'settings_help' => Icons.help_outline_rounded,
        'settings_organization' => Icons.corporate_fare_rounded,
        'settings_desk_risk' => Icons.shield_outlined,
        'settings_affiliate' => Icons.handshake_outlined,
        _ => null,
      };
    }

    final bool showSearchInput = !isCompactHeader && onSearchChanged != null;
    final Widget titleWidget = Text(
      isMobile || sectionTitle.isEmpty
          ? pageTitle
          : '$sectionTitle / $pageTitle',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.uiText.bodyStrong.copyWith(
        inherit: false,
        color: theme.colors.foreground,
        decoration: TextDecoration.none,
      ),
    );
    final Widget headerRow = Row(
      children: <Widget>[
        if (leading != null) ...[leading!, UiGap.h(theme.spacing.xs)],
        if (onBack != null) ...[
          UiIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            size: UiSize.sm,
            onPressed: onBack,
          ),
          UiGap.h(theme.spacing.xs),
        ],
        Expanded(flex: 2, child: titleWidget),
        if (showStatusBadge && statusBadgeText.isNotEmpty)
          UiBadge(label: statusBadgeText, size: UiSize.xs),
        if (showSearchInput) ...[
          UiGap.h(theme.spacing.md),
          Expanded(
            flex: 3,
            child: UiInput.search(
              key: searchTargetKey,
              value: searchQuery ?? '',
              hintText: searchHint ?? 'Search...',
              size: UiSize.sm,
              onChanged: onSearchChanged,
              onClear: () => onSearchChanged?.call(''),
            ),
          ),
          UiGap.h(theme.spacing.sm),
        ] else if (onSearch != null && !isMobile)
          UiIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Search',
            size: UiSize.sm,
            onPressed: onSearch,
          ),
        if (onResearch != null)
          UiIconButton(
            icon: Icons.travel_explore_rounded,
            tooltip: 'Research desk',
            size: UiSize.sm,
            onPressed: onResearch,
          ),
        if (onCalculator != null)
          UiIconButton(
            icon: Icons.calculate_outlined,
            tooltip: 'Calculators',
            size: UiSize.sm,
            onPressed: onCalculator,
          ),
        ...headerActions,
        if (primaryAction != null)
          primaryAction!
        else if (onPrimaryAction != null && primaryActionLabel != null)
          UiButton(
            label: primaryActionLabel!,
            size: UiSize.sm,
            onPressed: onPrimaryAction,
          ),
        if (onNotifications != null)
          UiIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            badgeCount: unread > 0 ? unread : null,
            size: UiSize.sm,
            onPressed: onNotifications,
          ),
        if (onHelp != null || onAi != null)
          UiIconButton(
            icon: Icons.help_outline_rounded,
            tooltip: 'Help & Guides',
            size: UiSize.sm,
            onPressed: onHelp ?? onAi,
          ),
      ],
    );

    final EdgeInsets headerPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 14)
        : EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.xs),
          );
    final BorderRadius headerRadius = isMobile
        ? BorderRadius.circular(22)
        : context.radius(theme.radii.lg);
    final bool isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: isMobile
            ? EdgeInsets.fromLTRB(
                12,
                compactAndroid ? 6 : 8,
                12,
                0,
              )
            : EdgeInsets.fromLTRB(
                context.sp(theme.spacing.sm),
                context.sp(theme.spacing.xs),
                context.sp(theme.spacing.sm),
                context.sp(theme.spacing.xs),
              ),
        child: isMobile
            ? Container(
                key: const ValueKey<String>('app-header-surface'),
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: headerRadius,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.36 : 0.10,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: headerRadius,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colors.surface.withValues(
                          alpha: isDark ? 0.62 : 0.74,
                        ),
                        borderRadius: headerRadius,
                        border: Border.all(
                          color: theme.colors.borderStrong.withValues(
                            alpha: isDark ? 0.65 : 0.75,
                          ),
                          width: 1.2,
                        ),
                      ),
                      child: Padding(
                        padding: headerPadding,
                        child: headerRow,
                      ),
                    ),
                  ),
                ),
              )
            : UiCard(
                key: const ValueKey<String>('app-header-surface'),
                padding: headerPadding,
                borderRadius: headerRadius,
                child: headerRow,
              ),
      ),
    );
  }
}

/// Command palette overlay (desktop ⌘K, mobile full-screen search).
class AppCommandPalette extends StatelessWidget {
  const AppCommandPalette({
    super.key,
    required this.items,
    required this.query,
    this.onQueryChanged,
    this.onSelect,
  });

  final List<AppCommandItem> items;
  final String query;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<AppCommandItem>? onSelect;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AppCommandItem> filtered = query.isEmpty
        ? items
        : items
              .where(
                (AppCommandItem i) =>
                    i.label.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();

    return AppFadeIn(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(560)),
        child: UiCard(
          elevated: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiInput.search(
                value: query,
                autofocus: true,
                hintText: 'Search trades, strategies, traders…',
                onChanged: onQueryChanged,
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              if (filtered.isEmpty)
                const UiEmptyState(title: 'No matches', icon: Icons.search_off)
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: context.sz(320)),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (BuildContext _, int i) => UiInteractive(
                      onTap: () => onSelect?.call(filtered[i]),
                      builder: (BuildContext ctx, UiInteractiveState s) =>
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ctx.sp(theme.spacing.md),
                              vertical: ctx.sp(theme.spacing.sm),
                            ),
                            decoration: BoxDecoration(
                              color: s.hovered
                                  ? theme.colors.surfaceHover
                                  : Colors.transparent,
                              borderRadius: ctx.radius(theme.radii.md),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  filtered[i].icon,
                                  size: ctx.sz(theme.sizes.iconSm),
                                  color: theme.colors.foregroundMuted,
                                ),
                                SizedBox(width: ctx.sp(theme.spacing.md)),
                                Expanded(
                                  child: Text(
                                    filtered[i].label,
                                    style: ctx.uiText.body,
                                  ),
                                ),
                                if (filtered[i].hint != null)
                                  Text(
                                    filtered[i].hint!,
                                    style: ctx.uiText.caption.copyWith(
                                      color: theme.colors.foregroundSubtle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page scaffold used inside the shell: title, actions, responsive padding.
class AppPageBlock extends StatelessWidget {
  const AppPageBlock({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const <Widget>[],
    this.scrollable = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => UiPage(
    scrollable: scrollable,
    header: UiHeader(title: title, subtitle: subtitle, actions: actions),
    child: child,
  );
}
