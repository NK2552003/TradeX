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
          children: <Widget>[if (hasCaption) _caption(context, pad), body],
        ),
      ),
    );
  }

  Widget _caption(BuildContext context, double pad) {
    final theme = context.ui;
    final c = theme.colors;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isNarrow =
            constraints.maxWidth < context.sz(520) || context.uiRes.isMobile;

        final Widget iconWidget = leadingIcon != null
            ? Padding(
                padding: EdgeInsets.only(right: context.sp(theme.spacing.xs)),
                child: Icon(
                  leadingIcon,
                  size: context.sz(theme.sizes.iconXs),
                  color: accent ?? c.foregroundSubtle,
                ),
              )
            : const SizedBox.shrink();

        final Widget? labelWidget = label != null
            ? Text(
                label!.toUpperCase(),
                style: uiOverline(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null;

        final Widget? trailingWidget = trailing != null
            ? Padding(
                padding: EdgeInsets.only(left: context.sp(theme.spacing.xs)),
                child: trailing!,
              )
            : null;

        final Widget content;

        if (isNarrow) {
          if (label != null && hint != null) {
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: context.sp(theme.spacing.xs),
                    runSpacing: context.sp(theme.spacing.xxs),
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (leadingIcon != null) iconWidget,
                          Flexible(child: labelWidget!),
                        ],
                      ),
                      ?trailing,
                    ],
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  hint!,
                  style: context.uiText.caption.copyWith(
                    color: c.foregroundSubtle,
                    height: 1.3,
                  ),
                  softWrap: true,
                ),
              ],
            );
          } else {
            content = SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xxs),
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (leadingIcon != null) iconWidget,
                      if (labelWidget != null)
                        Flexible(child: labelWidget)
                      else if (hint != null)
                        Flexible(
                          child: Text(
                            hint!,
                            style: context.uiText.caption.copyWith(
                              color: c.foregroundSubtle,
                              height: 1.3,
                            ),
                            softWrap: true,
                          ),
                        ),
                    ],
                  ),
                  ?trailing,
                ],
              ),
            );
          }
        } else {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (leadingIcon != null) iconWidget,
              if (labelWidget != null)
                Flexible(flex: 3, fit: FlexFit.loose, child: labelWidget),
              if (hint != null) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  flex: 2,
                  child: Text(
                    hint!,
                    textAlign: label != null ? TextAlign.end : TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: c.foregroundSubtle,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ] else ...<Widget>[const Spacer()],
              ?trailingWidget,
            ],
          );
        }

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
          child: content,
        );
      },
    );
  }
}
