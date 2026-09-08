import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Tracked, small-caps caption used by analytical surfaces.
///
/// Panel captions, table headers and axis labels all need the same quiet
/// overline. Defining it once keeps a dashboard from drifting into three
/// slightly different "small grey labels".
TextStyle uiOverline(BuildContext context, {Color? color}) =>
    context.uiText.caption.copyWith(
      fontSize: context.fs(10),
      height: 1.15,
      letterSpacing: 0.7,
      fontWeight: FontWeight.w600,
      color: color ?? context.uiColors.foregroundSubtle,
    );

/// A dense instrument panel: hairline frame, small caption bar, flush body.
///
/// [UiCard] carries product chrome — shadow, gradient, hover lift, generous
/// padding. Analytical surfaces want the opposite: a frame you stop noticing,
/// so the numbers inside carry the page. Depth here comes from one hairline and
/// a muted caption bar, never a shadow, so panels tile edge-to-edge without
/// stacking visual noise.
class UiDataPanel extends StatelessWidget {
  const UiDataPanel({
    super.key,
    required this.child,
    this.label,
    this.hint,
    this.leadingIcon,
    this.trailing,
    this.padding,
    this.density = UiDensity.compact,
    this.accent,
    this.borderless = false,
    this.filled = false,
    this.minHeight,
  });

  final Widget child;

  /// Caption text, rendered as a tracked overline rather than a heading.
  final String? label;

  /// Right-aligned hint inside the caption bar (units, count, "as of ...").
  final String? hint;
  final IconData? leadingIcon;

  /// Caption-bar action slot. Keep to icon buttons or a single small chip.
  final Widget? trailing;

  final EdgeInsetsGeometry? padding;
  final UiDensity density;

  /// Tints the caption bar's bottom rule, used to group related panels.
  final Color? accent;
  final bool borderless;

  /// Fill with `surfaceMuted` instead of `surface` — for nested panels.
  final bool filled;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final double pad = context.sp(theme.spacing.md) * density.factor;
    final bool hasCaption = label != null || hint != null || trailing != null;
    final BorderRadius radius = context.radius(theme.radii.md);

    Widget body = Padding(
      padding: padding ?? EdgeInsets.all(pad),
      child: child,
    );
    if (minHeight != null) {
      body = ConstrainedBox(
        constraints: BoxConstraints(minHeight: context.sz(minHeight!)),
        child: body,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled ? c.surfaceMuted : c.surface,
        borderRadius: radius,
        border: borderless
            ? null
            : Border.all(color: c.border, width: theme.borders.hairline),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (hasCaption) _caption(context, pad),
            body,
          ],
        ),
      ),
    );
  }

  Widget _caption(BuildContext context, double pad) {
    final theme = context.ui;
    final c = theme.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: pad,
        vertical: context.sp(theme.spacing.sm) * 0.7,
      ),
      decoration: BoxDecoration(
        color: filled ? c.surface : c.surfaceMuted,
        border: Border(
          bottom: BorderSide(
            color: accent ?? c.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (leadingIcon != null) ...<Widget>[
            Icon(
              leadingIcon,
              size: context.sz(theme.sizes.iconXs),
              color: accent ?? c.foregroundSubtle,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          if (label != null)
            Expanded(
              child: Text(
                label!.toUpperCase(),
                style: uiOverline(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Spacer(),
          if (hint != null) ...<Widget>[
            SizedBox(width: context.sp(theme.spacing.sm)),
            Text(
              hint!,
              style: context.uiText.caption.copyWith(
                color: c.foregroundSubtle,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (trailing != null) ...<Widget>[
            SizedBox(width: context.sp(theme.spacing.xs)),
            trailing!,
          ],
        ],
      ),
    );
  }
}
