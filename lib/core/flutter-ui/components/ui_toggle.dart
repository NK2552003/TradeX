import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Visual treatment of a standalone toggle.
enum UiToggleVariant { pill, soft, outline, ghost, solid }

/// Single on/off action (bookmark, like, follow, watchlist, mute).
///
/// States: off, on, hover, focus, pressed, loading, disabled — plus optional
/// count badge, label placement and per-state icons/labels.
class UiToggle extends StatelessWidget {
  const UiToggle({
    super.key,
    bool value = false,
    bool? selected,
    this.icon = Icons.check_rounded,
    this.activeIcon,
    this.onChanged,
    this.label,
    this.activeLabel,
    this.activeIntent = UiIntent.primary,
    this.inactiveIntent = UiIntent.neutral,
    this.variant = UiToggleVariant.pill,
    this.size = UiSize.md,
    this.density = UiDensity.comfortable,
    this.enabled = true,
    this.loading = false,
    this.count,
    this.showLabel = true,
    this.labelOnRight = true,
    this.tooltip,
    this.semanticLabel,
    this.autofocus = false,
    this.onLongPress,
    this.onHoverChanged,
  }) : value = selected ?? value;

  final bool value;
  final IconData icon;
  final IconData? activeIcon;
  final ValueChanged<bool>? onChanged;

  final String? label;

  /// Label swapped in when [value] is true (e.g. "Following").
  final String? activeLabel;

  final UiIntent activeIntent;
  final UiIntent inactiveIntent;
  final UiToggleVariant variant;
  final UiSize size;
  final UiDensity density;

  final bool enabled;
  final bool loading;

  /// Optional counter rendered after the label (likes, reposts).
  final int? count;

  final bool showLabel;
  final bool labelOnRight;

  final String? tooltip;
  final String? semanticLabel;
  final bool autofocus;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHoverChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final double f = density.factor;
    final Color active = activeIntent.color(context);
    final Color idle = inactiveIntent.color(context);
    final bool interactive = enabled && !loading && onChanged != null;
    final String? text = showLabel
        ? (value ? (activeLabel ?? label) : label)
        : null;
    final BorderRadius radius = context.radius(
      variant == UiToggleVariant.pill ? theme.radii.pill : size.radius(context),
    );

    return UiInteractive(
      enabled: interactive,
      autofocus: autofocus,
      selected: value,
      tooltip: tooltip,
      onHoverChanged: onHoverChanged,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel ?? label,
      borderRadius: radius,
      onTap: interactive ? () => onChanged!(!value) : null,
      builder: (BuildContext ctx, UiInteractiveState s) {
        final Color fg = !enabled
            ? c.disabledForeground
            : value
            ? (variant == UiToggleVariant.solid
                  ? activeIntent.onColor(ctx)
                  : active)
            : (s.hovered ? c.foreground : idle);
        final Color bg = !enabled
            ? (variant == UiToggleVariant.ghost
                  ? const Color(0x00000000)
                  : c.disabledBackground)
            : value
            ? switch (variant) {
                UiToggleVariant.solid => active,
                UiToggleVariant.outline => const Color(0x00000000),
                UiToggleVariant.ghost => active.withValues(alpha: 0.08),
                _ => active.withValues(alpha: 0.12),
              }
            : (s.hovered && variant != UiToggleVariant.ghost
                  ? c.surfaceHover
                  : const Color(0x00000000));

        return AnimatedScale(
          scale: s.pressed ? 0.96 : 1,
          duration: theme.motion.fast,
          curve: theme.motion.curve,
          child: AnimatedContainer(
            duration: theme.motion.fast,
            curve: theme.motion.curve,
            constraints: BoxConstraints(
              minHeight: size.height(ctx),
              minWidth: size.height(ctx),
            ),
            padding: EdgeInsets.symmetric(
              horizontal:
                  ctx.sp(text == null ? theme.spacing.xs : theme.spacing.md) *
                  f,
              vertical: ctx.sp(theme.spacing.xs) * f,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: variant == UiToggleVariant.outline
                  ? Border.all(
                      color: value ? active : c.border,
                      width: value
                          ? theme.borders.thick
                          : theme.borders.hairline,
                    )
                  : null,
              boxShadow: value && variant == UiToggleVariant.solid
                  ? uiGlow(ctx, active)
                  : null,
            ),
            foregroundDecoration: s.focused ? uiFocusRing(ctx, radius) : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (!labelOnRight && text != null) ...<Widget>[
                  _label(ctx, text, fg),
                  SizedBox(width: size.gap(ctx, density: density)),
                ],
                if (loading)
                  SizedBox(
                    width: size.icon(ctx),
                    height: size.icon(ctx),
                    child: CircularProgressIndicator(
                      strokeWidth: theme.borders.thick,
                      color: fg,
                    ),
                  )
                else
                  AnimatedSwitcher(
                    duration: theme.motion.fast,
                    child: Icon(
                      value ? (activeIcon ?? icon) : icon,
                      key: ValueKey<bool>(value),
                      size: size.icon(ctx),
                      color: fg,
                    ),
                  ),
                if (labelOnRight && text != null) ...<Widget>[
                  SizedBox(width: size.gap(ctx, density: density)),
                  _label(ctx, text, fg),
                ],
                if (count != null) ...<Widget>[
                  SizedBox(width: ctx.sp(theme.spacing.xs)),
                  Text(
                    uiCompactNumber(count!),
                    style: ctx.uiText.caption.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _label(BuildContext ctx, String text, Color fg) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: size
        .textStyle(ctx)
        .copyWith(
          color: fg,
          fontWeight: value ? FontWeight.w600 : FontWeight.w500,
        ),
  );
}
