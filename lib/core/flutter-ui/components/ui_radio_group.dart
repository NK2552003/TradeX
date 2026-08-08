import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Radio group (vertical on mobile, optional horizontal row on larger screens).
class UiRadioGroup<T> extends StatelessWidget {
  const UiRadioGroup({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.horizontalFromTablet = false,
    this.enabled = true,
  });

  final List<UiOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final bool horizontalFromTablet;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final bool horizontal =
        horizontalFromTablet && !context.uiRes.isMobile;
    final List<Widget> tiles = <Widget>[
      for (final UiOption<T> o in options)
        _UiRadioTile<T>(
          option: o,
          selected: o.value == value,
          enabled: enabled && o.enabled && onChanged != null,
          onTap: () => onChanged?.call(o.value),
        ),
    ];
    final double gap = context.sp(theme.spacing.md);

    if (horizontal) {
      return Wrap(spacing: gap, runSpacing: gap, children: tiles);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < tiles.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: gap),
          tiles[i],
        ],
      ],
    );
  }
}

class _UiRadioTile<T> extends StatelessWidget {
  const _UiRadioTile({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final UiOption<T> option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final double dim = context.sz(theme.sizes.radio);
    return UiInteractive(
      enabled: enabled,
      onTap: onTap,
      semanticLabel: option.label,
      builder: (BuildContext ctx, UiInteractiveState s) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AnimatedContainer(
            duration: theme.motion.fast,
            width: dim,
            height: dim,
            margin: EdgeInsets.only(top: ctx.sp(theme.spacing.xxs)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? c.surface : c.disabledBackground,
              border: Border.all(
                color: !enabled
                    ? c.border
                    : selected
                        ? c.primary
                        : (s.hovered ? c.borderStrong : c.border),
                width: theme.borders.thick,
              ),
            ),
            alignment: Alignment.center,
            child: selected
                ? Container(
                    width: dim * 0.5,
                    height: dim * 0.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: enabled ? c.primary : c.disabledForeground,
                    ),
                  )
                : null,
          ),
          SizedBox(width: ctx.sp(theme.spacing.sm)),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  option.label,
                  style: ctx.uiText.body.copyWith(
                    color: enabled ? c.foreground : c.disabledForeground,
                  ),
                ),
                if (option.description != null)
                  Text(
                    option.description!,
                    style:
                        ctx.uiText.caption.copyWith(color: c.foregroundMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
