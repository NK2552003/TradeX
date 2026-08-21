import 'package:flutter/material.dart';
import 'package:quiet_dock/quiet_dock.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../brand/app_logo.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

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
    this.trader,
    this.tier = AppTier.free,
    this.onSearch,
    this.onNotifications,
    this.onSettings,
    this.onAi,
    this.unreadNotifications = 0,
    this.primaryAction,
    this.mobilePrimaryItems,
    this.mobileMoreItems = const <AppNavItem>[],
    this.userMenuItems = const <AppNavItem>[],
    this.workspaceName,
    this.tierLabel,
    this.onLogout,
  });

  final List<AppNavSection> sections;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final Widget child;
  final AppTrader? trader;
  final AppTier tier;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;
  final VoidCallback? onAi;
  final int unreadNotifications;
  final Widget? primaryAction;
  final List<AppNavItem>? mobilePrimaryItems;
  final List<AppNavItem> mobileMoreItems;
  final List<AppNavItem> userMenuItems;
  final String? workspaceName;
  final String? tierLabel;
  final VoidCallback? onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _collapsed = false;
  bool _navigationForward = true;

  List<AppNavItem> get _flatItems =>
      widget.sections.expand((AppNavSection s) => s.items).toList();

  void _toggleDesktopSidebar() {
    setState(() => _collapsed = !_collapsed);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      final List<AppNavItem> items =
          widget.mobilePrimaryItems ?? _flatItems.take(4).toList();
      final int previous = items.indexWhere(
        (AppNavItem item) => item.id == oldWidget.selectedId,
      );
      final int next = items.indexWhere(
        (AppNavItem item) => item.id == widget.selectedId,
      );
      _navigationForward = previous < 0 || next < 0 || next >= previous;
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiResponsive r = context.uiRes;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final bool keyboardVisible = mediaQuery.viewInsets.bottom > 0;

    final Widget contentSurface = Container(
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
              color: theme.colors.surface,
              borderRadius: context.radius(theme.radii.xl),
              border: Border.all(
                color: theme.colors.border,
                width: theme.borders.hairline,
              ),
            ),
      clipBehavior: r.isMobile ? Clip.none : Clip.antiAlias,
      child: AnimatedSwitcher(
        duration: theme.motion.normal,
        switchInCurve: theme.motion.curve,
        switchOutCurve: theme.motion.curve,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final Animation<Offset> position = Tween<Offset>(
            begin: Offset(_navigationForward ? 0.08 : -0.08, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: position, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<String>('page_${widget.selectedId}'),
          child: widget.child,
        ),
      ),
    );

    final Widget topBar = AppTopBar(
      trader: widget.trader,
      tier: widget.tier,
      onSearch: widget.onSearch,
      onNotifications: widget.onNotifications,
      onSettings: widget.onSettings,
      onAi: widget.onAi,
      unread: widget.unreadNotifications,
      showLogo: r.isMobile,
      selectedId: widget.selectedId,
      sections: widget.sections,
      leading: r.isMobile
          ? null
          : UiIconButton(
              icon: _collapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
              size: UiSize.sm,
              tooltip: 'Toggle sidebar',
              onPressed: _toggleDesktopSidebar,
            ),
    );

    final Widget workspace = Column(
      children: <Widget>[
        topBar,
        Expanded(child: contentSurface),
      ],
    );

    if (r.isMobile) {
      // QuietDockScaffold intentionally extends its body beneath the floating
      // dock. Reserve the complete dock footprint here so every page (even a
      // page with its own ScrollView) receives safe layout constraints.
      const double dockHeight = 56;
      const double dockMargin = 16;
      final double dockClearance = keyboardVisible
          ? mediaQuery.padding.bottom
          : dockHeight +
                dockMargin +
                mediaQuery.padding.bottom +
                context.sp(theme.spacing.xs);
      // Publish the clearance as a safe inset instead of shrinking the whole
      // workspace. SafeArea-aware pages keep their controls above the dock,
      // while their background still paints beneath the floating glass bar.
      final Widget dockSafeContent = MediaQuery(
        data: mediaQuery.copyWith(
          padding: mediaQuery.padding.copyWith(bottom: dockClearance),
        ),
        child: contentSurface,
      );

      final List<AppNavItem> destinations =
          (widget.mobilePrimaryItems ?? _flatItems.take(4).toList())
              .take(4)
              .toList();
      int selectedIndex = destinations.indexWhere(
        (AppNavItem item) => item.id == widget.selectedId,
      );
      if (selectedIndex < 0 && widget.selectedId.startsWith('settings')) {
        selectedIndex = destinations.indexWhere(
          (AppNavItem item) => item.id == 'settings',
        );
      }
      final int initialIndex = selectedIndex < 0 ? 0 : selectedIndex;
      AppNavItem? activeMoreItem;
      for (final AppNavItem item in widget.mobileMoreItems) {
        if (item.id == widget.selectedId) {
          activeMoreItem = item;
          break;
        }
      }
      final bool moreRouteSelected = activeMoreItem != null;
      final Widget dockScaffold = QuietDockScaffold(
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
        initialIndex: initialIndex,
        onDestinationSelected: (int index) {
          if (index >= 0 && index < destinations.length) {
            widget.onSelect(destinations[index].id);
          }
        },
        centerAction: QuietDockCenterAction(
          semanticLabel: 'More tools',
          icon: Icons.grid_view_rounded,
          closeIcon: moreRouteSelected
              ? (activeMoreItem.selectedIcon ?? activeMoreItem.icon)
              : Icons.close_rounded,
          columns: 3,
          items: widget.mobileMoreItems
              .map(
                (AppNavItem item) => QuickGridItem(
                  icon: item.icon,
                  label: item.label,
                  onTap: () => widget.onSelect(item.id),
                ),
              )
              .toList(),
        ),
        centerActionActive: moreRouteSelected,
        swipeEnabled: true,
        lazy: true,
        keepAlive: false,
        useRail: false,
        backgroundColor: theme.colors.background,
        pageBuilder: (BuildContext context, int index) => dockSafeContent,
        theme: QuietDockTheme(
          background: keyboardVisible
              ? Colors.transparent
              : theme.colors.surface.withValues(alpha: 0.9),
          borderColor: keyboardVisible
              ? Colors.transparent
              : theme.colors.border,
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
              : Colors.black.withValues(alpha: 0.24),
          height: keyboardVisible ? 0 : dockHeight,
          margin: keyboardVisible ? 0 : dockMargin,
          iconSize: keyboardVisible ? 0 : 22,
          frosted: !keyboardVisible,
          showLabels: false,
        ),
      );
      Widget dockLayer = dockScaffold;

      // The selected More destination owns the center slot. Keep the dock's
      // original hit target underneath so tapping it reopens the chooser, and
      // add a small arrow overlay to communicate that it can be changed.
      if (moreRouteSelected && !keyboardVisible) {
        const double centerSlotSize = 56;
        dockLayer = Stack(
          fit: StackFit.expand,
          children: <Widget>[
            dockScaffold,
            Positioned(
              left: (mediaQuery.size.width - centerSlotSize) / 2,
              bottom: mediaQuery.padding.bottom + dockMargin,
              width: centerSlotSize,
              height: dockHeight,
              child: IgnorePointer(
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: context.sz(11),
                        color: theme.colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      // The header is intentionally outside QuietDockScaffold's PageView so
      // only screen content participates in destination swipe transitions.
      final Widget mobileShell = Column(
        children: <Widget>[
          topBar,
          Expanded(child: dockLayer),
        ],
      );
      return ColoredBox(
        key: const ValueKey<String>('app-mobile-shell-background'),
        color: theme.colors.background,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double keyboardTop =
                mediaQuery.size.height - mediaQuery.viewInsets.bottom;
            final double visibleHeight = keyboardVisible
                ? constraints.maxHeight.clamp(0.0, keyboardTop)
                : constraints.maxHeight;
            return MediaQuery(
              // The shell height already excludes the keyboard. Prevent the
              // nested dock Scaffold from applying the inset a second time.
              data: mediaQuery.copyWith(viewInsets: EdgeInsets.zero),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(height: visibleHeight, child: mobileShell),
              ),
            );
          },
        ),
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
      footer: widget.primaryAction,
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
            onNavigate: widget.onSelect,
            onUserLogout: widget.onLogout,
            userMenuItems: widget.userMenuItems,
          )
        : ClipRect(
            child: AnimatedContainer(
              duration: theme.motion.normal,
              curve: theme.motion.curve,
              width: _collapsed ? 0 : context.sz(244),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: context.sz(244),
                maxWidth: context.sz(244),
                child: expandedSidebar,
              ),
            ),
          );

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: Row(
        children: <Widget>[
          adaptiveSidebar,
          Expanded(child: workspace),
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
  });

  final bool collapsed;
  final String workspaceName;
  final String tierLabel;

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
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    tierLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundSubtle,
                      fontSize: 11.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return collapsed
        ? UiTooltip(message: '$workspaceName ($tierLabel)', child: tile)
        : tile;
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
                            ? 'TradeX Pro Terminal'
                            : 'TradeX Desk')),
              tierLabel:
                  tierLabel ??
                  (trader?.tier == AppTier.enterprise
                      ? 'Enterprise Admin'
                      : (trader?.tier == AppTier.premium
                            ? 'Active Trader'
                            : 'Standard')),
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
                              fontSize: 11.0,
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
            AppNavUserTile(
              trader:
                  trader ??
                  const AppTrader(
                    id: 'u1',
                    handle: 'nitish@tradex.ai',
                    displayName: 'Nitish Kumar',
                    tier: AppTier.premium,
                  ),
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
    final String name = trader.displayName ?? 'Nitish Kumar';
    final String email = trader.handle.contains('@')
        ? trader.handle
        : '${trader.handle}@tradex.ai';

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
                      style: ctx.uiText.bodyStrong.copyWith(fontSize: 13.0),
                    ),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ctx.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                        fontSize: 11.0,
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
        if (onUpgrade != null)
          UiMenuItem(
            label: 'Upgrade to Pro',
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

    return collapsed ? UiTooltip(message: '$name ($email)', child: menu) : menu;
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
    final bool selectedSubItem =
        widget.item.subItems?.any(
          (AppNavItem item) => item.id == widget.selectedId,
        ) ??
        false;
    if (oldWidget.selectedId != widget.selectedId &&
        selectedSubItem &&
        !_expanded) {
      _expanded = true;
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
        if (hasSubItems && !widget.collapsed) {
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
            Icon(
              _isSelected
                  ? (widget.item.selectedIcon ?? widget.item.icon)
                  : widget.item.icon,
              size: ctx.sz(17),
              color: _isSelected
                  ? theme.colors.primary
                  : theme.colors.foregroundMuted,
            ),
            if (!widget.collapsed) ...<Widget>[
              SizedBox(width: ctx.sp(theme.spacing.sm + 1)),
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ctx.uiText.body.copyWith(
                    fontSize: 13.0,
                    color: _isSelected
                        ? theme.colors.foreground
                        : theme.colors.foregroundMuted,
                    fontWeight: _isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.item.tierLocked)
                Icon(
                  Icons.lock_outline,
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
                    width: 1.2,
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
                                  sub.id == widget.selectedId;
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
                                child: Text(
                                  sub.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ctx.uiText.body.copyWith(
                                    fontSize: 13.0,
                                    color: subSelected
                                        ? theme.colors.foreground
                                        : theme.colors.foregroundMuted,
                                    fontWeight: subSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
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

/// Top app bar: search, notifications, avatar and tier chip.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    this.trader,
    this.tier = AppTier.free,
    this.onSearch,
    this.onNotifications,
    this.onSettings,
    this.onAi,
    this.unread = 0,
    this.leading,
    this.showLogo = false,
    this.title,
    this.selectedId,
    this.sections,
  });

  final AppTrader? trader;
  final AppTier tier;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;
  final VoidCallback? onAi;
  final int unread;
  final Widget? leading;
  final bool showLogo;
  final String? title;
  final String? selectedId;
  final List<AppNavSection>? sections;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    final bool isCompactHeader =
        isMobile ||
        context.uiRes.isTablet ||
        context.uiRes.width < context.sz(1180);

    String sectionTitle = 'Terminal';
    String pageTitle = 'Dashboard';

    if (sections != null && selectedId != null) {
      for (final s in sections!) {
        for (final item in s.items) {
          if (item.id == selectedId) {
            sectionTitle = s.title ?? 'Terminal';
            pageTitle = item.label;
          } else if (item.subItems != null) {
            for (final sub in item.subItems!) {
              if (sub.id == selectedId) {
                sectionTitle = item.label;
                pageTitle = sub.label;
              }
            }
          }
        }
      }
    }

    final Widget breadcrumbWidget = (sections != null && selectedId != null)
        ? (isMobile
              ? Text(
                  pageTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.label.copyWith(
                    color: theme.colors.foreground,
                    decoration: TextDecoration.none,
                    decorationColor: Colors.transparent,
                  ),
                )
              : UiBreadcrumbs(
                  crumbs: <UiCrumb>[
                    UiCrumb(label: sectionTitle),
                    UiCrumb(label: pageTitle),
                  ],
                ))
        : (title != null
              ? Text(title!, style: context.uiText.subheading)
              : const SizedBox.shrink());

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: isMobile
            ? EdgeInsets.all(context.sp(theme.spacing.sm))
            : EdgeInsets.fromLTRB(
                0,
                context.sp(theme.spacing.xs),
                context.sp(theme.spacing.xs + 3),
                context.sp(theme.spacing.xs),
              ),
        child: Container(
          key: const ValueKey<String>('app-header-surface'),
          height: context.sz(isMobile ? 56 : 50),
          padding: isMobile
              ? EdgeInsets.all(context.sp(theme.spacing.sm))
              : EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.md)),
          decoration: BoxDecoration(
            color: theme.colors.surface.withValues(alpha: 0.94),
            borderRadius: context.radius(theme.radii.xl),
            border: Border.all(
              color: theme.colors.border,
              width: theme.borders.hairline,
            ),
            boxShadow: theme.shadows.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Left: Hamburger toggle + divider + breadcrumbs
              ?leading,
              if (leading != null) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.xs)),
                Container(
                  width: 1,
                  height: context.sz(16),
                  color: theme.colors.border.withValues(alpha: 0.6),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
              ],
              if (showLogo) ...<Widget>[
                const AppLogoMark(size: 16, rounded: false),
                SizedBox(width: context.sp(theme.spacing.sm)),
              ],
              Expanded(
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedSwitcher(
                      duration: theme.motion.fast,
                      switchInCurve: theme.motion.curve,
                      switchOutCurve: theme.motion.curve,
                      child: KeyedSubtree(
                        key: ValueKey<String>(selectedId ?? pageTitle),
                        child: breadcrumbWidget,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              SizedBox(
                width: context.sz(isCompactHeader ? 116 : 560),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    // Center-Right: Search Command Pill (Desktop)
                    if (!isCompactHeader) ...<Widget>[
                      UiInteractive(
                        onTap: onSearch,
                        builder: (BuildContext ctx, UiInteractiveState s) =>
                            AnimatedContainer(
                              duration: theme.motion.fast,
                              width: ctx.sz(250),
                              height: ctx.sz(32),
                              padding: EdgeInsets.symmetric(
                                horizontal: ctx.sp(theme.spacing.sm),
                              ),
                              decoration: BoxDecoration(
                                color: s.hovered
                                    ? theme.colors.surfaceHover
                                    : theme.colors.background.withValues(
                                        alpha: 0.7,
                                      ),
                                borderRadius: ctx.radius(theme.radii.md),
                                border: Border.all(
                                  color: s.hovered
                                      ? theme.colors.borderStrong
                                      : theme.colors.border,
                                  width: theme.borders.hairline,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    size: ctx.sz(15),
                                    color: theme.colors.foregroundSubtle,
                                  ),
                                  SizedBox(width: ctx.sp(theme.spacing.xs)),
                                  Expanded(
                                    child: Text(
                                      'Search symbols, orders...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: ctx.uiText.caption.copyWith(
                                        color: theme.colors.foregroundSubtle,
                                        fontSize: 12.0,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5.0,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colors.surface,
                                      borderRadius: ctx.radius(theme.radii.sm),
                                      border: Border.all(
                                        color: theme.colors.border,
                                        width: theme.borders.hairline,
                                      ),
                                    ),
                                    child: Text(
                                      '⌘K',
                                      style: ctx.uiText.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colors.foregroundMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.sm)),

                      // Market Live Status Pill
                      Container(
                        height: context.sz(28),
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(theme.spacing.sm),
                        ),
                        decoration: BoxDecoration(
                          color: theme.colors.bullish.withValues(alpha: 0.08),
                          borderRadius: context.radius(theme.radii.pill),
                          border: Border.all(
                            color: theme.colors.bullish.withValues(alpha: 0.3),
                            width: theme.borders.hairline,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.5,
                              height: 6.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colors.bullish,
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            Text(
                              'NSE/BSE LIVE',
                              style: context.uiText.caption.copyWith(
                                color: theme.colors.bullish,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.0,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.sm)),

                      // Vertical subtle separator
                      Container(
                        width: 1,
                        height: context.sz(18),
                        color: theme.colors.border.withValues(alpha: 0.6),
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                    ],

                    // Search Icon on Mobile
                    if (isCompactHeader)
                      UiIconButton(
                        icon: Icons.search_rounded,
                        size: UiSize.sm,
                        tooltip: 'Search',
                        onPressed: onSearch,
                      ),

                    // Notifications Icon with perfectly positioned badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        UiIconButton(
                          icon: Icons.notifications_none_rounded,
                          size: UiSize.sm,
                          tooltip: 'Notifications',
                          onPressed: onNotifications,
                        ),
                        if (unread > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: context.sz(7),
                              height: context.sz(7),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colors.bearish,
                                border: Border.all(
                                  color: theme.colors.surface,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: context.sp(theme.spacing.xxs)),

                    if (isMobile)
                      UiIconButton(
                        icon: Icons.auto_awesome_rounded,
                        size: UiSize.sm,
                        tooltip: 'AI Assistant',
                        onPressed: onAi,
                      )
                    else
                      UiIconButton(
                        icon: Icons.settings_outlined,
                        size: UiSize.sm,
                        tooltip: 'Settings',
                        onPressed: onSettings,
                      ),
                  ],
                ),
              ),
            ],
          ),
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
