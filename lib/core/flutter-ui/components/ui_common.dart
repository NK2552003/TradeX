import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';

class UiOption<T> {
  const UiOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;
  final bool enabled;
}

/// Shared enums + helpers used across components. Nothing visual is hardcoded;
/// every mapping resolves against [UiTheme].
enum UiSize { sm, md, lg }

enum UiVariant { primary, secondary, ghost, outline, destructive, success }

enum UiIntent { neutral, primary, bullish, bearish, warning, info }

extension UiSizeX on UiSize {
  double height(BuildContext context) {
    final s = context.uiSizes;
    switch (this) {
      case UiSize.sm:
        return context.sz(s.controlHeightSm);
      case UiSize.md:
        return context.sz(s.controlHeightMd);
      case UiSize.lg:
        return context.sz(s.controlHeightLg);
    }
  }

  double icon(BuildContext context) {
    final s = context.uiSizes;
    switch (this) {
      case UiSize.sm:
        return context.sz(s.iconSm);
      case UiSize.md:
        return context.sz(s.iconMd);
      case UiSize.lg:
        return context.sz(s.iconLg);
    }
  }

  EdgeInsets padding(BuildContext context) {
    final sp = context.uiSpace;
    switch (this) {
      case UiSize.sm:
        return EdgeInsets.symmetric(horizontal: context.sp(sp.md));
      case UiSize.md:
        return EdgeInsets.symmetric(horizontal: context.sp(sp.lg));
      case UiSize.lg:
        return EdgeInsets.symmetric(horizontal: context.sp(sp.xl));
    }
  }

  TextStyle textStyle(BuildContext context) {
    final t = context.uiText;
    switch (this) {
      case UiSize.sm:
        return t.label;
      case UiSize.md:
        return t.bodyStrong;
      case UiSize.lg:
        return t.subheading;
    }
  }
}

extension UiIntentX on UiIntent {
  Color color(BuildContext context) {
    final c = context.uiColors;
    switch (this) {
      case UiIntent.neutral:
        return c.foregroundMuted;
      case UiIntent.primary:
        return c.primary;
      case UiIntent.bullish:
        return c.bullish;
      case UiIntent.bearish:
        return c.bearish;
      case UiIntent.warning:
        return c.warning;
      case UiIntent.info:
        return c.info;
    }
  }

  Color surface(BuildContext context) => color(context).withValues(alpha: 0.12);
}

/// Wraps a child with hover / press / focus state without any styling opinion.
class UiInteractive extends StatefulWidget {
  const UiInteractive({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.cursor = SystemMouseCursors.click,
    this.borderRadius,
    this.semanticLabel,
  });

  final Widget Function(BuildContext context, UiInteractiveState state) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final MouseCursor cursor;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  State<UiInteractive> createState() => _UiInteractiveState();
}

class UiInteractiveState {
  const UiInteractiveState({
    required this.hovered,
    required this.pressed,
    required this.focused,
    required this.enabled,
  });

  final bool hovered;
  final bool pressed;
  final bool focused;
  final bool enabled;
}

class _UiInteractiveState extends State<UiInteractive> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.enabled && widget.onTap != null ||
        (widget.enabled && widget.onLongPress != null);
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      enabled: widget.enabled,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        mouseCursor:
            widget.enabled ? widget.cursor : SystemMouseCursors.forbidden,
        onShowHoverHighlight: (bool v) => setState(() => _hovered = v),
        onShowFocusHighlight: (bool v) => setState(() => _focused = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          child: widget.builder(
            context,
            UiInteractiveState(
              hovered: _hovered,
              pressed: _pressed,
              focused: _focused,
              enabled: widget.enabled,
            ),
          ),
        ),
      ),
    );
  }
}

/// Focus ring decoration derived from tokens.
BoxDecoration uiFocusRing(BuildContext context, BorderRadius radius) =>
    BoxDecoration(
      borderRadius: radius,
      border: Border.all(
        color: context.uiColors.focusRing,
        width: context.ui.borders.focus,
      ),
    );

/// Number formatting helper used by charts / lists (no intl dependency).
typedef UiValueFormatter = String Function(num value);

String uiCompactNumber(num value) {
  final double v = value.toDouble();
  final double abs = v.abs();
  if (abs >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
  if (abs >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
  if (abs >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
  if (abs >= 100) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

String uiSignedPercent(num value, {int decimals = 2}) =>
    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(decimals)}%';
