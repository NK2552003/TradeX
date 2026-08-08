import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_common.dart';

/// Card-style radio group (e.g. choose order type: Market / Limit / Stop).
class UiRadioCardGroup<T> extends StatelessWidget {
  const UiRadioCardGroup({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
  });

  final List<UiOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final int cols = context.uiRes.columns(
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
      large: desktopColumns,
    );
    final double gap = context.sp(theme.spacing.md);

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double itemWidth =
            (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final UiOption<T> o in options)
              SizedBox(
                width: itemWidth,
                child: _UiRadioCard<T>(
                  option: o,
                  selected: o.value == value,
                  onTap: o.enabled && onChanged != null
                      ? () => onChanged!(o.value)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _UiRadioCard<T> extends StatelessWidget {
  const _UiRadioCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final UiOption<T> option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    return UiInteractive(
      enabled: onTap != null,
      onTap: onTap,
      semanticLabel: option.label,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        padding: EdgeInsets.all(ctx.sp(theme.spacing.lg)),
        decoration: BoxDecoration(
          color: selected ? c.primary.withValues(alpha: 0.08) : c.surface,
          borderRadius: ctx.radius(theme.radii.lg),
          border: Border.all(
            color: selected
                ? c.primary
                : (s.hovered ? c.borderStrong : c.border),
            width: selected ? theme.borders.thick : theme.borders.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (option.icon != null) ...<Widget>[
                  Icon(
                    option.icon,
                    size: ctx.sz(theme.sizes.iconMd),
                    color: selected ? c.primary : c.foregroundMuted,
                  ),
                  SizedBox(width: ctx.sp(theme.spacing.sm)),
                ],
                Expanded(
                  child: Text(
                    option.label,
                    overflow: TextOverflow.ellipsis,
                    style: ctx.uiText.bodyStrong.copyWith(color: c.foreground),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: ctx.sz(theme.sizes.iconSm),
                  color: selected ? c.primary : c.foregroundSubtle,
                ),
              ],
            ),
            if (option.description != null) ...<Widget>[
              SizedBox(height: ctx.sp(theme.spacing.xs)),
              Text(
                option.description!,
                style: ctx.uiText.caption.copyWith(color: c.foregroundMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
