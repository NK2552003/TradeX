import 'package:flutter/material.dart';

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
    this.unreadNotifications = 0,
    this.primaryAction,
    this.mobileItemCount = 5,
  });

  final List<AppNavSection> sections;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final Widget child;
  final AppTrader? trader;
  final AppTier tier;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final int unreadNotifications;
  final Widget? primaryAction;
  final int mobileItemCount;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _collapsed = false;

  List<AppNavItem> get _flatItems =>
      widget.sections.expand((AppNavSection s) => s.items).toList();

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiResponsive r = context.uiRes;

    final Widget body = Column(
      children: <Widget>[
        AppTopBar(
          trader: widget.trader,
          tier: widget.tier,
          onSearch: widget.onSearch,
          onNotifications: widget.onNotifications,
          unread: widget.unreadNotifications,
          showLogo: r.isMobile,
          leading: r.isMobile
              ? null
              : UiIconButton(
                  icon: _collapsed ? Icons.menu_open : Icons.menu,
                  tooltip: 'Toggle sidebar',
                  onPressed: () => setState(() => _collapsed = !_collapsed),
                ),
        ),
        Expanded(child: widget.child),
      ],
    );

    if (r.isMobile) {
      return Scaffold(
        backgroundColor: theme.colors.background,
        body: body,
        floatingActionButton: widget.primaryAction,
        bottomNavigationBar: AppBottomDock(
          items: _flatItems.take(widget.mobileItemCount).toList(),
          selectedId: widget.selectedId,
          onSelect: widget.onSelect,
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: Row(
        children: <Widget>[
          AppSidebar(
            sections: widget.sections,
            selectedId: widget.selectedId,
            onSelect: widget.onSelect,
            collapsed: _collapsed || r.isTablet,
            footer: widget.primaryAction,
          ),
          Expanded(child: body),
        ],
      ),
    );
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
    this.footer,
  });

  final List<AppNavSection> sections;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final bool collapsed;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return AnimatedContainer(
      duration: theme.motion.normal,
      curve: theme.motion.curve,
      width: context.sz(collapsed ? 76 : 248),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          right: BorderSide(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
              child: collapsed
                  ? const AppLogoMark(size: 28)
                  : const AppWordmark(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final AppNavSection s in sections) ...<Widget>[
                      if (s.title != null && !collapsed)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.sp(theme.spacing.md),
                            context.sp(theme.spacing.md),
                            context.sp(theme.spacing.md),
                            context.sp(theme.spacing.xs),
                          ),
                          child: Text(
                            s.title!.toUpperCase(),
                            style: context.uiText.caption.copyWith(
                              color: theme.colors.foregroundSubtle,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      for (final AppNavItem i in s.items)
                        AppNavTile(
                          item: i,
                          selected: i.id == selectedId,
                          collapsed: collapsed,
                          onTap: () => onSelect(i.id),
                        ),
                      SizedBox(height: context.sp(theme.spacing.sm)),
                    ],
                  ],
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

/// A single sidebar entry.
class AppNavTile extends StatelessWidget {
  const AppNavTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    this.collapsed = false,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Widget tile = UiInteractive(
      onTap: onTap,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        margin: EdgeInsets.only(bottom: ctx.sp(theme.spacing.xxs)),
        padding: EdgeInsets.symmetric(
          horizontal: ctx.sp(theme.spacing.md),
          vertical: ctx.sp(theme.spacing.sm),
        ),
        decoration: BoxDecoration(
          color: selected
              ? theme.colors.primary.withValues(alpha: 0.14)
              : (s.hovered ? theme.colors.surfaceHover : Colors.transparent),
          borderRadius: ctx.radius(theme.radii.lg),
        ),
        child: Row(
          mainAxisAlignment: collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: <Widget>[
            Icon(
              selected ? (item.selectedIcon ?? item.icon) : item.icon,
              size: ctx.sz(theme.sizes.iconSm),
              color: selected
                  ? theme.colors.primary
                  : theme.colors.foregroundMuted,
            ),
            if (!collapsed) ...<Widget>[
              SizedBox(width: ctx.sp(theme.spacing.md)),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ctx.uiText.body.copyWith(
                    color: selected
                        ? theme.colors.foreground
                        : theme.colors.foregroundMuted,
                    fontWeight: selected ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (item.tierLocked)
                Icon(Icons.lock_outline,
                    size: ctx.sz(theme.sizes.iconSm),
                    color: theme.colors.foregroundSubtle)
              else if (item.badgeCount != null && item.badgeCount! > 0)
                UiBadge(
                  label: '${item.badgeCount}',
                  intent: UiIntent.primary,
                  filled: true,
                ),
            ],
          ],
        ),
      ),
    );

    return collapsed ? UiTooltip(message: item.label, child: tile) : tile;
  }
}

/// Mobile bottom dock.
class AppBottomDock extends StatelessWidget {
  const AppBottomDock({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
  });

  final List<AppNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          top: BorderSide(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            for (final AppNavItem i in items)
              Expanded(
                child: UiInteractive(
                  onTap: () => onSelect(i.id),
                  builder: (BuildContext ctx, UiInteractiveState s) => Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: ctx.sp(theme.spacing.sm),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            Icon(
                              i.id == selectedId
                                  ? (i.selectedIcon ?? i.icon)
                                  : i.icon,
                              size: ctx.sz(theme.sizes.iconMd),
                              color: i.id == selectedId
                                  ? theme.colors.primary
                                  : theme.colors.foregroundMuted,
                            ),
                            if ((i.badgeCount ?? 0) > 0)
                              Positioned(
                                right: -6,
                                top: -4,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ctx.sp(theme.spacing.xs),
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colors.primary,
                                    borderRadius:
                                        BorderRadius.circular(theme.radii.pill),
                                  ),
                                  child: Text(
                                    '${i.badgeCount}',
                                    style: ctx.uiText.caption.copyWith(
                                      color: theme.colors.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: ctx.sp(theme.spacing.xxs)),
                        Text(
                          i.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ctx.uiText.caption.copyWith(
                            color: i.id == selectedId
                                ? theme.colors.primary
                                : theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
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

/// Top app bar: search, notifications, avatar and tier chip.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    this.trader,
    this.tier = AppTier.free,
    this.onSearch,
    this.onNotifications,
    this.unread = 0,
    this.leading,
    this.showLogo = false,
    this.title,
  });

  final AppTrader? trader;
  final AppTier tier;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final int unread;
  final Widget? leading;
  final bool showLogo;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.lg),
        vertical: context.sp(theme.spacing.sm),
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
      child: SafeArea(
        bottom: false,
        child: Row(
          children: <Widget>[
            ?leading,
            if (showLogo) const AppWordmark(fontSize: 20),
            if (title != null)
              Padding(
                padding: EdgeInsets.only(left: context.sp(theme.spacing.sm)),
                child: Text(title!, style: context.uiText.subheading),
              ),
            const Spacer(),
            UiIconButton(
              icon: Icons.search,
              tooltip: 'Search',
              onPressed: onSearch,
            ),
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                UiIconButton(
                  icon: Icons.notifications_none,
                  tooltip: 'Notifications',
                  onPressed: onNotifications,
                ),
                if (unread > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: context.sz(8),
                      height: context.sz(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colors.bearish,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            if (!context.uiRes.isMobile && tier != AppTier.free) ...<Widget>[
              UiBadge(
                label: AppTokens.tierLabel(tier),
                intent: AppTokens.tierIntent(tier),
                icon: AppTokens.tierIcon(tier),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
            ],
            if (trader != null)
              UiAvatar(
                imageUrl: trader!.avatarUrl,
                name: trader!.displayName ?? trader!.handle,
                size: UiSize.sm,
                verified: trader!.verified,
              ),
          ],
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
            .where((AppCommandItem i) =>
                i.label.toLowerCase().contains(query.toLowerCase()))
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
                            Icon(filtered[i].icon,
                                size: ctx.sz(theme.sizes.iconSm),
                                color: theme.colors.foregroundMuted),
                            SizedBox(width: ctx.sp(theme.spacing.md)),
                            Expanded(
                              child: Text(filtered[i].label,
                                  style: ctx.uiText.body),
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
