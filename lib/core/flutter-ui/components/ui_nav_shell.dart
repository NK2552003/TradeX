import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_tabs.dart';

/// Bottom navigation for the mobile app shell, side rail on wide screens.
class UiNavShell extends StatelessWidget {
  const UiNavShell({
    super.key,
    this.items = const <UiTabItem>[],
    this.selectedIndex = 0,
    this.onChanged,
    required this.body,
    this.sidebar,
    this.floatingAction,
  });

  final List<UiTabItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;
  final Widget body;
  final Widget? sidebar;
  final Widget? floatingAction;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final bool rail = !context.uiRes.isMobile;

    if (sidebar != null) {
      if (rail) {
        return Row(
          children: <Widget>[
            sidebar!,
            Expanded(child: body),
          ],
        );
      }
      return Column(
        children: <Widget>[
          Expanded(child: body),
          if (items.isNotEmpty)
            Container(
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
                    for (int i = 0; i < items.length; i++)
                      Expanded(
                        child: _UiNavEntry(
                          item: items[i],
                          selected: i == selectedIndex,
                          showLabel: true,
                          vertical: true,
                          onTap: () => onChanged?.call(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    if (rail) {
      return Row(
        children: <Widget>[
          Container(
            width: context.sz(context.uiRes.isDesktop ? 190 : 60),
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
              child: Column(
                children: <Widget>[
                  SizedBox(height: context.sp(theme.spacing.lg)),
                  for (int i = 0; i < items.length; i++)
                    _UiNavEntry(
                      item: items[i],
                      selected: i == selectedIndex,
                      showLabel: context.uiRes.isDesktop,
                      onTap: () => onChanged?.call(i),
                    ),
                  const Spacer(),
                  if (floatingAction != null)
                    Padding(
                      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                      child: floatingAction!,
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Column(
      children: <Widget>[
        Expanded(child: body),
        if (items.isNotEmpty)
          Container(
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
                  for (int i = 0; i < items.length; i++)
                    Expanded(
                      child: _UiNavEntry(
                        item: items[i],
                        selected: i == selectedIndex,
                        showLabel: true,
                        vertical: true,
                        onTap: () => onChanged?.call(i),
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

class _UiNavEntry extends StatelessWidget {
  const _UiNavEntry({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onTap,
    this.vertical = false,
  });

  final UiTabItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Color fg = selected
        ? theme.colors.primary
        : theme.colors.foregroundMuted;
    final Widget icon = Icon(
      item.icon ?? Icons.circle,
      size: context.sz(theme.sizes.iconMd),
      color: fg,
    );
    final Widget label = Text(
      item.label,
      overflow: TextOverflow.ellipsis,
      style: context.uiText.caption.copyWith(
        color: fg,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );

    return UiInteractive(
      onTap: onTap,
      semanticLabel: item.label,
      builder: (BuildContext ctx, UiInteractiveState s) => Container(
        padding: EdgeInsets.symmetric(
          vertical: ctx.sp(theme.spacing.sm),
          horizontal: ctx.sp(theme.spacing.md),
        ),
        margin: vertical
            ? EdgeInsets.zero
            : EdgeInsets.symmetric(
                horizontal: ctx.sp(theme.spacing.sm),
                vertical: ctx.sp(theme.spacing.xxs),
              ),
        decoration: BoxDecoration(
          color: !vertical && selected
              ? theme.colors.primary.withValues(alpha: 0.10)
              : (s.hovered ? theme.colors.surfaceHover : Colors.transparent),
          borderRadius: ctx.radius(theme.radii.lg),
        ),
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
      ),
    );
  }
}
