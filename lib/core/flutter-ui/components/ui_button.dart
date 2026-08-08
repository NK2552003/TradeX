import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_common.dart';

/// Fully themed, responsive button. No colors/sizes hardcoded.
class UiButton extends StatelessWidget {
  const UiButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = UiVariant.primary,
    this.size = UiSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.expandOnMobile = true,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final UiVariant variant;
  final UiSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;

  /// Buttons stretch full-width on phones by default (mobile-first pattern).
  final bool expandOnMobile;
  final String? tooltip;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final BorderRadius radius = context.radius(theme.radii.lg);
    final bool fullWidth = expand || (expandOnMobile && context.uiRes.isMobile);

    Widget button = UiInteractive(
      enabled: _enabled,
      onTap: onPressed,
      semanticLabel: label,
      builder: (BuildContext ctx, UiInteractiveState s) {
        final _ButtonStyle style = _resolve(ctx, s);
        return AnimatedContainer(
          duration: theme.motion.fast,
          curve: theme.motion.curve,
          height: size.height(ctx),
          padding: size.padding(ctx),
          constraints: BoxConstraints(minWidth: ctx.sz(theme.sizes.minTapTarget)),
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: radius,
            border: style.borderColor == null
                ? null
                : Border.all(
                    color: style.borderColor!,
                    width: theme.borders.hairline,
                  ),
            boxShadow: style.elevated && s.hovered ? theme.shadows.sm : null,
          ),
          foregroundDecoration:
              s.focused ? uiFocusRing(ctx, radius) : null,
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (loading)
                SizedBox(
                  width: size.icon(ctx),
                  height: size.icon(ctx),
                  child: CircularProgressIndicator(
                    strokeWidth: theme.borders.thick,
                    valueColor: AlwaysStoppedAnimation<Color>(style.foreground),
                  ),
                )
              else if (leadingIcon != null)
                Icon(leadingIcon, size: size.icon(ctx), color: style.foreground),
              if (loading || leadingIcon != null)
                SizedBox(width: ctx.sp(theme.spacing.sm)),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: size.textStyle(ctx).copyWith(color: style.foreground),
                ),
              ),
              if (trailingIcon != null) ...<Widget>[
                SizedBox(width: ctx.sp(theme.spacing.sm)),
                Icon(trailingIcon, size: size.icon(ctx), color: style.foreground),
              ],
            ],
          ),
        );
      },
    );

    if (fullWidth) button = SizedBox(width: double.infinity, child: button);
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }

  _ButtonStyle _resolve(BuildContext context, UiInteractiveState s) {
    final c = context.uiColors;
    Color hoverMix(Color base, Color hover) =>
        s.pressed || s.hovered ? hover : base;

    if (!s.enabled) {
      return _ButtonStyle(
        background: variant == UiVariant.ghost
            ? Colors.transparent
            : c.disabledBackground,
        foreground: c.disabledForeground,
        borderColor: variant == UiVariant.outline ? c.border : null,
      );
    }
    switch (variant) {
      case UiVariant.primary:
        return _ButtonStyle(
          background: hoverMix(c.primary, c.primaryHover),
          foreground: c.onPrimary,
          elevated: true,
        );
      case UiVariant.secondary:
        return _ButtonStyle(
          background: hoverMix(c.secondary, c.surfaceHover),
          foreground: c.onSecondary,
          borderColor: c.border,
        );
      case UiVariant.ghost:
        return _ButtonStyle(
          background:
              s.hovered || s.pressed ? c.surfaceHover : Colors.transparent,
          foreground: c.foreground,
        );
      case UiVariant.outline:
        return _ButtonStyle(
          background:
              s.hovered || s.pressed ? c.surfaceHover : Colors.transparent,
          foreground: c.foreground,
          borderColor: c.borderStrong,
        );
      case UiVariant.destructive:
        return _ButtonStyle(
          background: hoverMix(c.destructive, c.destructive.withValues(alpha: 0.85)),
          foreground: c.onDestructive,
          elevated: true,
        );
      case UiVariant.success:
        return _ButtonStyle(
          background: hoverMix(c.bullish, c.bullish.withValues(alpha: 0.85)),
          foreground: c.onPrimary,
          elevated: true,
        );
    }
  }
}

class _ButtonStyle {
  const _ButtonStyle({
    required this.background,
    required this.foreground,
    this.borderColor,
    this.elevated = false,
  });

  final Color background;
  final Color foreground;
  final Color? borderColor;
  final bool elevated;
}
