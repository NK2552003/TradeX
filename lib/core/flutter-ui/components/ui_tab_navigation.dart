import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_tabs.dart';

/// Standalone tab bar (also used as page-level [TabNavigation]).
class UiTabBar extends StatelessWidget {
  const UiTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.variant = UiTabsVariant.underline,
    this.expand = false,
  });

  final List<UiTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final UiTabsVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final List<Widget> tabs = <Widget>[
      for (int i = 0; i < items.length; i++)
        _UiTab(
          item: items[i],
          selected: i == selectedIndex,
          variant: variant,
          onTap: () => onChanged(i),
        ),
    ];

    final bool stretch = expand || !context.uiRes.isMobile && items.length <= 4;
    final Widget row = Row(
      mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        for (final Widget t in tabs) stretch ? Expanded(child: t) : t,
      ],
    );

    final Widget content = variant == UiTabsVariant.underline
        ? DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colors.border,
                  width: theme.borders.hairline,
                ),
              ),
            ),
            child: row,
          )
        : Container(
            padding: EdgeInsets.all(context.sz(3)),
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.lg),
            ),
            child: row,
          );

    if (stretch) return content;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: content,
    );
  }
}

class _UiTab extends StatelessWidget {
  const _UiTab({
    required this.item,
    required this.selected,
    required this.variant,
    required this.onTap,
  });

  final UiTabItem item;
  final bool selected;
  final UiTabsVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final Color fg = selected ? c.foreground : c.foregroundMuted;

    return UiInteractive(
      onTap: onTap,
      semanticLabel: item.label,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        padding: EdgeInsets.symmetric(
          horizontal: ctx.sp(theme.spacing.lg),
          vertical: ctx.sp(theme.spacing.md),
        ),
        decoration: BoxDecoration(
          color: variant == UiTabsVariant.pill
              ? (selected
                  ? c.surface
                  : (s.hovered ? c.surfaceHover : Colors.transparent))
              : (s.hovered ? c.surfaceMuted : Colors.transparent),
          borderRadius: variant == UiTabsVariant.pill
              ? ctx.radius(theme.radii.md)
              : null,
          border: variant == UiTabsVariant.underline
              ? Border(
                  bottom: BorderSide(
                    color: selected ? c.primary : Colors.transparent,
                    width: theme.borders.focus,
                  ),
                )
              : null,
          boxShadow: variant == UiTabsVariant.pill && selected
              ? theme.shadows.sm
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (item.icon != null) ...<Widget>[
              Icon(item.icon, size: ctx.sz(theme.sizes.iconSm), color: fg),
              SizedBox(width: ctx.sp(theme.spacing.xs)),
            ],
            Text(
              item.label,
              overflow: TextOverflow.ellipsis,
              style: ctx.uiText.label.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (item.badge != null) ...<Widget>[
              SizedBox(width: ctx.sp(theme.spacing.xs)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ctx.sp(theme.spacing.xs),
                ),
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: ctx.radius(theme.radii.pill),
                ),
                child: Text(
                  item.badge!,
                  style: ctx.uiText.caption.copyWith(color: c.foregroundMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
