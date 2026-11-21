import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

class UiNavItem {
  const UiNavItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    this.count,
    this.dot = false,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData? activeIcon;

  /// Numeric badge; values above 99 render as "99+".
  final int? count;

  /// Small status dot instead of a count.
  final bool dot;
  final bool enabled;
  final VoidCallback? onTap;
}

enum UiNavStyle {
  /// Bottom bar on mobile, side rail from tablet up (default).
  adaptive,

  /// Always a bottom bar.
  bar,

  /// Always a vertical rail.
  rail,
}

/// Primary app navigation: bottom bar / side rail with badges, labels,
/// safe-area padding, optional floating action slot and header/footer slots.
class UiTabNavigation extends StatelessWidget {
  UiTabNavigation({
    super.key,
    List<UiNavItem>? items,
    int? index,
    int? selectedIndex,
    this.views,
    this.onChanged,
    this.style = UiNavStyle.adaptive,
    this.intent = UiIntent.primary,
    this.density = UiDensity.comfortable,
    this.showLabels = true,
    this.floating = false,
    this.header,
    this.footer,
    this.extendedRail = false,
    this.enabled = true,
  }) : index = selectedIndex ?? index ?? 0,
       items = items ?? _defaultItemsForViews(views);

  final List<UiNavItem> items;
  final int index;
  final List<Widget>? views;
  final ValueChanged<int>? onChanged;

  final UiNavStyle style;
  final UiIntent intent;
  final UiDensity density;
  final bool showLabels;

  /// Detached pill bar with shadow and margins (mobile bar only).
  final bool floating;

  /// Rail slots (logo, avatar, settings).
  final Widget? header;
  final Widget? footer;

  /// Rail shows labels next to icons.
  final bool extendedRail;
  final bool enabled;

  static List<UiNavItem> _defaultItemsForViews(List<Widget>? views) {
    if (views == null || views.isEmpty) return const <UiNavItem>[];
    return List<UiNavItem>.generate(
      views.length,
      (int i) => UiNavItem(label: 'Tab ${i + 1}', icon: Icons.tab_rounded),
    );
  }

  bool _isRail(BuildContext context) {
    switch (style) {
      case UiNavStyle.rail:
        return true;
      case UiNavStyle.bar:
        return false;
      case UiNavStyle.adaptive:
        return !context.uiRes.isMobile;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final bool isRail = _isRail(ctx);
        final bool hasBoundedHeight = constraints.hasBoundedHeight;
        final bool hasBoundedWidth = constraints.hasBoundedWidth;
        final Widget nav = isRail
            ? _buildRail(ctx, hasBoundedHeight: hasBoundedHeight)
            : _buildBar(ctx);

        if (views != null && views!.isNotEmpty) {
          final int safeIdx = index.clamp(0, views!.length - 1);
          final Widget currentView = views![safeIdx];
          if (isRail) {
            final Widget viewWidget = hasBoundedWidth
                ? Expanded(child: currentView)
                : currentView;
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: hasBoundedHeight
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
              children: <Widget>[nav, viewWidget],
            );
          } else {
            final Widget viewWidget = hasBoundedHeight
                ? Expanded(child: currentView)
                : currentView;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[viewWidget, nav],
            );
          }
        }
        return nav;
      },
    );
  }

  Widget _buildBar(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final EdgeInsets safe = MediaQuery.of(context).padding;

    final Widget row = Row(
      children: <Widget>[
        for (int i = 0; i < items.length; i++)
          Expanded(
            child: _NavButton(
              item: items[i],
              selected: i == index,
              intent: intent,
              density: density,
              showLabel: showLabels,
              vertical: true,
              enabled: enabled && items[i].enabled,
              onTap: () {
                items[i].onTap?.call();
                onChanged?.call(i);
              },
            ),
          ),
      ],
    );

    if (floating) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          context.sp(theme.spacing.lg),
          0,
          context.sp(theme.spacing.lg),
          context.sp(theme.spacing.lg) + safe.bottom,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: context.radius(theme.radii.pill),
            border: Border.all(color: c.border, width: theme.borders.hairline),
            boxShadow: theme.shadows.lg,
          ),
          child: row,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        top: context.sp(theme.spacing.xs),
        bottom: context.sp(theme.spacing.xs) + safe.bottom,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: c.border, width: theme.borders.hairline),
        ),
      ),
      child: row,
    );
  }

  Widget _buildRail(BuildContext context, {bool hasBoundedHeight = true}) {
    final theme = context.ui;
    final c = theme.colors;

    final Widget itemsList = SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.sm),
                vertical: context.sp(theme.spacing.xxs),
              ),
              child: _NavButton(
                item: items[i],
                selected: i == index,
                intent: intent,
                density: density,
                showLabel: showLabels,
                vertical: !extendedRail,
                enabled: enabled && items[i].enabled,
                onTap: () {
                  items[i].onTap?.call();
                  onChanged?.call(i);
                },
              ),
            ),
        ],
      ),
    );

    return Container(
      width: context.sz(extendedRail ? 220 : 76),
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.md)),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          right: BorderSide(color: c.border, width: theme.borders.hairline),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (header != null) ...<Widget>[
            Padding(
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              child: header!,
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
          ],
          if (hasBoundedHeight) Expanded(child: itemsList) else itemsList,
          if (footer != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            Padding(
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.intent,
    required this.density,
    required this.showLabel,
    required this.vertical,
    required this.enabled,
    required this.onTap,
  });

  final UiNavItem item;
  final bool selected;
  final UiIntent intent;
  final UiDensity density;
  final bool showLabel;
  final bool vertical;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final Color accent = intent.color(context);
    final BorderRadius radius = context.radius(theme.radii.md);

    return UiInteractive(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      selected: selected,
      semanticLabel: item.label,
      borderRadius: radius,
      builder: (BuildContext ctx, UiInteractiveState s) {
        final Color fg = !enabled
            ? c.disabledForeground
            : selected
            ? accent
            : (s.hovered ? c.foreground : c.foregroundMuted);

        final Widget icon = Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Icon(
              selected ? (item.activeIcon ?? item.icon) : item.icon,
              size: ctx.sz(theme.sizes.iconMd),
              color: fg,
            ),
            if (item.count != null && item.count! > 0)
              Positioned(
                right: -ctx.sz(8),
                top: -ctx.sz(6),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: ctx.sz(4)),
                  constraints: BoxConstraints(minWidth: ctx.sz(16)),
                  decoration: BoxDecoration(
                    color: c.destructive,
                    borderRadius: ctx.radius(theme.radii.pill),
                  ),
                  child: Text(
                    item.count! > 99 ? '99+' : '${item.count}',
                    textAlign: TextAlign.center,
                    style: ctx.uiText.caption.copyWith(
                      color: c.onDestructive,
                      fontSize: ctx.sz(10),
                      height: 1.4,
                    ),
                  ),
                ),
              )
            else if (item.dot)
              Positioned(
                right: -ctx.sz(2),
                top: -ctx.sz(2),
                child: Container(
                  width: ctx.sz(7),
                  height: ctx.sz(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.destructive,
                  ),
                ),
              ),
          ],
        );

        final Widget label = Text(
          item.label,
          overflow: TextOverflow.ellipsis,
          style: ctx.uiText.caption.copyWith(
            color: fg,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        );

        return AnimatedContainer(
          duration: theme.motion.fast,
          padding: EdgeInsets.symmetric(
            horizontal: ctx.sp(theme.spacing.sm) * density.factor,
            vertical: ctx.sp(theme.spacing.sm) * density.factor,
          ),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : (s.hovered && enabled
                      ? c.surfaceHover
                      : c.surfaceHover.withValues(alpha: 0.0)),
            borderRadius: radius,
          ),
          foregroundDecoration: s.focused ? uiFocusRing(ctx, radius) : null,
          child: vertical
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    icon,
                    if (showLabel) ...<Widget>[
                      SizedBox(height: ctx.sp(theme.spacing.xxs)),
                      label,
                    ],
                  ],
                )
              : Row(
                  children: <Widget>[
                    icon,
                    if (showLabel) ...<Widget>[
                      SizedBox(width: ctx.sp(theme.spacing.md)),
                      Expanded(child: label),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
