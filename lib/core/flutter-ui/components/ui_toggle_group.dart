import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_common.dart';

/// Segmented toggle group (e.g. Buy / Sell, 1D / 1W / 1M).
class UiToggleGroup<T> extends StatelessWidget {
  const UiToggleGroup({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.size = UiSize.sm,
    this.expand = false,
    this.scrollableOnMobile = true,
  });

  final List<UiToggleOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final UiSize size;
  final bool expand;
  final bool scrollableOnMobile;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final BorderRadius radius = context.radius(theme.radii.lg);
    final List<Widget> items = <Widget>[
      for (final UiToggleOption<T> o in options)
        _UiToggleButton<T>(
          option: o,
          selected: o.value == value,
          size: size,
          expand: expand,
          onTap: onChanged == null ? null : () => onChanged!(o.value),
        ),
    ];

    final Widget row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        for (final Widget item in items)
          expand ? Expanded(child: item) : item,
      ],
    );

    final Widget container = Container(
      padding: EdgeInsets.all(context.sz(3)),
      decoration: BoxDecoration(
        color: theme.colors.surfaceMuted,
        borderRadius: radius,
        border: Border.all(
          color: theme.colors.border,
          width: theme.borders.hairline,
        ),
      ),
      child: row,
    );

    if (!expand && scrollableOnMobile && context.uiRes.isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: container,
      );
    }
    return container;
  }
}

class UiToggleOption<T> {
  const UiToggleOption({
    required this.value,
    required this.label,
    this.icon,
    this.intent,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Overrides the selected-pill color (e.g. bullish for Buy, bearish for Sell).
  final UiIntent? intent;
}

class _UiToggleButton<T> extends StatelessWidget {
  const _UiToggleButton({
    required this.option,
    required this.selected,
    required this.size,
    required this.expand,
    required this.onTap,
  });

  final UiToggleOption<T> option;
  final bool selected;
  final UiSize size;
  final bool expand;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final Color activeBg =
        option.intent?.color(context) ?? c.surface;
    final Color activeFg = option.intent == null ? c.foreground : c.onPrimary;
    return UiInteractive(
      enabled: onTap != null,
      onTap: onTap,
      semanticLabel: option.label,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        curve: theme.motion.curve,
        height: size.height(ctx) - ctx.sz(6),
        padding: EdgeInsets.symmetric(horizontal: ctx.sp(theme.spacing.md)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? activeBg
              : (s.hovered ? c.surfaceHover : Colors.transparent),
          borderRadius: ctx.radius(theme.radii.md),
          boxShadow: selected ? theme.shadows.sm : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (option.icon != null) ...<Widget>[
              Icon(
                option.icon,
                size: size.icon(ctx) * 0.9,
                color: selected ? activeFg : c.foregroundMuted,
              ),
              SizedBox(width: ctx.sp(theme.spacing.xs)),
            ],
            Text(
              option.label,
              style: ctx.uiText.label.copyWith(
                color: selected ? activeFg : c.foregroundMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
