import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_common.dart';

class UiBarListItem {
  const UiBarListItem({
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.color,
  });

  final String label;
  final num value;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;
}

/// Horizontal ranked bars (top gainers, most-discussed tickers).
class UiBarList extends StatelessWidget {
  const UiBarList({
    super.key,
    required this.items,
    this.valueFormatter,
    this.intent = UiIntent.primary,
  });

  final List<UiBarListItem> items;
  final UiValueFormatter? valueFormatter;
  final UiIntent intent;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final num max = items.isEmpty
        ? 1
        : items.map((UiBarListItem e) => e.value.abs()).reduce(
            (num a, num b) => a > b ? a : b);
    final UiValueFormatter fmt = valueFormatter ?? uiCompactNumber;

    return Column(
      children: <Widget>[
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == items.length - 1 ? 0 : context.sp(theme.spacing.sm),
            ),
            child: UiInteractive(
              enabled: items[i].onTap != null,
              onTap: items[i].onTap,
              builder: (BuildContext ctx, UiInteractiveState s) => Stack(
                children: <Widget>[
                  FractionallySizedBox(
                    widthFactor:
                        max == 0 ? 0 : (items[i].value.abs() / max).clamp(0, 1),
                    child: Container(
                      height: ctx.sz(theme.sizes.controlHeightSm),
                      decoration: BoxDecoration(
                        color: (items[i].color ?? intent.color(ctx))
                            .withValues(alpha: s.hovered ? 0.28 : 0.18),
                        borderRadius: ctx.radius(theme.radii.md),
                      ),
                    ),
                  ),
                  Container(
                    height: ctx.sz(theme.sizes.controlHeightSm),
                    padding: EdgeInsets.symmetric(
                      horizontal: ctx.sp(theme.spacing.sm),
                    ),
                    child: Row(
                      children: <Widget>[
                        if (items[i].icon != null) ...<Widget>[
                          Icon(
                            items[i].icon,
                            size: ctx.sz(theme.sizes.iconSm),
                            color: theme.colors.foregroundMuted,
                          ),
                          SizedBox(width: ctx.sp(theme.spacing.xs)),
                        ],
                        Expanded(
                          child: Text(
                            items[i].label,
                            overflow: TextOverflow.ellipsis,
                            style: ctx.uiText.label
                                .copyWith(color: theme.colors.foreground),
                          ),
                        ),
                        Text(
                          fmt(items[i].value),
                          style: ctx.uiText.numeric
                              .copyWith(color: theme.colors.foregroundMuted),
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
