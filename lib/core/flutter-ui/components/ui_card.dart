import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Surface treatments for [UiCard].
enum UiCardVariant {
  surface,
  outlined,
  ghost,
  elevated,
  gradient,
  glass,
  accent,
  subtle,
}

/// Surface container used for every panel in the app (feed post, watchlist,
/// KPI tile, chart wrapper).
///
/// Slots: [leading], [media], [title]/[subtitle], [trailing], [actions],
/// [footer], [child]. States: hover, selected, disabled, loading, collapsed.
class UiCard extends StatefulWidget {
  const UiCard({
    super.key,
    required this.child,
    this.padding,
    this.headerPadding,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.leading,
    Widget? trailing,
    Widget? action,
    this.media,
    this.actions,
    this.footer,
    this.onTap,
    this.onLongPress,
    this.elevated = false,
    this.variant,
    this.intent,
    this.accentColor,
    this.borderless = false,
    this.selected = false,
    this.enabled = true,
    this.loading = false,
    this.loadingHeight,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.onExpandedChanged,
    this.hoverLift = false,
    this.density = UiDensity.comfortable,
    this.radius,
    this.borderRadius,
    this.minHeight,
    this.headerDivider = false,
    this.semanticLabel,
    this.motion = true,
  }) : trailing = action ?? trailing;

  final BorderRadiusGeometry? borderRadius;

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Optional header inset for tables or media with an edge-to-edge body.
  final EdgeInsetsGeometry? headerPadding;
  final String? title;

  /// Overrides [title] when a custom header widget is required.
  final Widget? titleWidget;
  final String? subtitle;

  /// Icon/avatar shown before the title.
  final Widget? leading;
  final Widget? trailing;

  /// Full-bleed media rendered above the padded content.
  final Widget? media;

  /// Action row rendered under the content, above the footer.
  final List<Widget>? actions;
  final Widget? footer;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Legacy flag — equivalent to [UiCardVariant.elevated].
  final bool elevated;
  final UiCardVariant? variant;

  /// Tints selected borders, gradients and glows. Cards deliberately avoid a
  /// thick edge stripe so domain surfaces stay quiet and consistent.
  final UiIntent? intent;
  final Color? accentColor;
  final bool borderless;
  final bool selected;
  final bool enabled;
  final bool loading;

  /// Height of the loading placeholder in logical points (scaled internally).
  /// Set it to the height of the real content so the card does not resize when
  /// the data arrives.
  final double? loadingHeight;
  final bool collapsible;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpandedChanged;
  final bool hoverLift;
  final UiDensity density;
  final double? radius;
  final double? minHeight;
  final bool headerDivider;
  final String? semanticLabel;
  final bool motion;

  @override
  State<UiCard> createState() => _UiCardState();
}

class _UiCardState extends State<UiCard> {
  late bool _expanded = widget.initiallyExpanded;

  UiCardVariant get _variant =>
      widget.variant ??
      (widget.elevated ? UiCardVariant.elevated : UiCardVariant.surface);

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpandedChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final r = context.uiRes;
    final c = theme.colors;
    final Color tint =
        widget.accentColor ?? (widget.intent?.color(context) ?? c.primary);
    final BorderRadius radius =
        (widget.borderRadius as BorderRadius?) ??
        context.radius(widget.radius ?? theme.radii.lg);
    final double f = widget.density.factor;
    final EdgeInsetsGeometry pad =
        widget.padding ??
        EdgeInsets.all(
          context.sp(r.isMobile ? theme.spacing.md : theme.spacing.lg) * f,
        );
    final bool tappable = widget.enabled && widget.onTap != null;

    return UiInteractive(
      enabled: tappable,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      selected: widget.selected,
      semanticLabel: widget.semanticLabel ?? widget.title,
      cursor: tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      trackHover: widget.motion && widget.hoverLift,
      builder: (BuildContext ctx, UiInteractiveState s) {
        final bool active = widget.motion && tappable && s.active;
        final _CardSkin skin = _skin(ctx, active, tint);
        final BoxDecoration decoration = BoxDecoration(
          color: skin.gradient == null
              ? (widget.selected
                    ? Color.alphaBlend(
                        tint.withValues(alpha: 0.06),
                        skin.background,
                      )
                    : skin.background)
              : null,
          gradient: skin.gradient,
          borderRadius: radius,
          border: widget.borderless
              ? null
              : Border.all(
                  color: widget.selected
                      ? tint.withValues(alpha: 0.45)
                      : skin.borderColor,
                  width: theme.borders.hairline,
                ),
          boxShadow: skin.shadow,
        );

        final Widget inner = Opacity(
          opacity: widget.enabled ? 1 : 0.55,
          child: _cardContent(ctx, pad, f, radius),
        );

        if (!widget.motion) {
          return Container(
            constraints: widget.minHeight == null
                ? null
                : BoxConstraints(minHeight: widget.minHeight!),
            decoration: decoration,
            foregroundDecoration: s.focused ? uiFocusRing(ctx, radius) : null,
            clipBehavior: Clip.antiAlias,
            child: inner,
          );
        }

        return AnimatedContainer(
          duration: theme.motion.fast,
          curve: theme.motion.curve,
          transform: s.pressed
              ? Matrix4.diagonal3Values(0.985, 0.985, 1)
              : widget.hoverLift && s.hovered
              ? Matrix4.translationValues(0.0, -ctx.sz(2), 0.0)
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          constraints: widget.minHeight == null
              ? null
              : BoxConstraints(minHeight: widget.minHeight!),
          decoration: decoration,
          foregroundDecoration: s.focused ? uiFocusRing(ctx, radius) : null,
          clipBehavior: Clip.antiAlias,
          child: inner,
        );
      },
    );
  }

  Widget _cardContent(
    BuildContext ctx,
    EdgeInsetsGeometry pad,
    double f,
    BorderRadius radius,
  ) {
    final Widget body = _body(ctx, pad, f);
    if (widget.media == null) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.vertical(top: radius.topLeft),
          child: widget.media!,
        ),
        body,
      ],
    );
  }

  Widget _body(BuildContext ctx, EdgeInsetsGeometry pad, double f) {
    final theme = ctx.ui;
    final bool hasHeader =
        widget.title != null ||
        widget.titleWidget != null ||
        widget.trailing != null ||
        widget.leading != null ||
        widget.collapsible;

    final Widget content = widget.collapsible || widget.loading
        ? AnimatedCrossFade(
            duration: theme.motion.normal,
            sizeCurve: theme.motion.curve,
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: SizedBox(
              width: double.infinity,
              child: widget.loading
                  ? _LoadingBody(height: widget.loadingHeight)
                  : widget.child,
            ),
            secondChild: const SizedBox(width: double.infinity),
          )
        : widget.child;

    if (!hasHeader &&
        (widget.actions == null || widget.actions!.isEmpty) &&
        widget.footer == null) {
      return Padding(padding: pad, child: content);
    }

    return Padding(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hasHeader) ...<Widget>[
            Padding(
              padding: widget.headerPadding ?? EdgeInsets.zero,
              child: _UiCardHeader(
                title: widget.title,
                titleWidget: widget.titleWidget,
                subtitle: widget.subtitle,
                leading: widget.leading,
                trailing: widget.trailing,
                collapsible: widget.collapsible,
                expanded: _expanded,
                onToggle: _toggle,
              ),
            ),
            if (widget.headerDivider) ...<Widget>[
              SizedBox(height: ctx.sp(theme.spacing.md) * f),
              Divider(
                height: theme.borders.hairline,
                color: theme.colors.border,
              ),
            ],
            if (widget.headerPadding == null)
              SizedBox(height: ctx.sp(theme.spacing.md) * f),
          ],
          content,
          if (_expanded &&
              widget.actions != null &&
              widget.actions!.isNotEmpty) ...<Widget>[
            SizedBox(height: ctx.sp(theme.spacing.md) * f),
            Wrap(
              spacing: ctx.sp(theme.spacing.sm),
              runSpacing: ctx.sp(theme.spacing.sm),
              children: widget.actions!,
            ),
          ],
          if (_expanded && widget.footer != null) ...<Widget>[
            SizedBox(height: ctx.sp(theme.spacing.md) * f),
            Divider(height: theme.borders.hairline, color: theme.colors.border),
            SizedBox(height: ctx.sp(theme.spacing.md) * f),
            widget.footer!,
          ],
        ],
      ),
    );
  }

  _CardSkin _skin(BuildContext ctx, bool active, Color tint) {
    final theme = ctx.ui;
    final c = theme.colors;
    switch (_variant) {
      case UiCardVariant.outlined:
        return _CardSkin(
          background: active ? c.surfaceHover : Colors.transparent,
          borderColor: active ? c.borderStrong : c.border,
        );
      case UiCardVariant.ghost:
        return _CardSkin(
          background: active ? c.surfaceMuted : Colors.transparent,
          borderColor: Colors.transparent,
        );
      case UiCardVariant.elevated:
        return _CardSkin(
          background: active ? c.surfaceMuted : c.surface,
          borderColor: c.border,
          shadow: active ? theme.shadows.lg : theme.shadows.md,
        );
      case UiCardVariant.gradient:
        return _CardSkin(
          background: c.surface,
          borderColor: tint.withValues(alpha: 0.35),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.alphaBlend(tint.withValues(alpha: 0.16), c.surface),
              c.surface,
            ],
          ),
          shadow: active ? uiGlow(ctx, tint) : null,
        );
      case UiCardVariant.glass:
        return _CardSkin(
          background: c.surface.withValues(alpha: active ? 0.85 : 0.65),
          borderColor: c.borderStrong.withValues(alpha: 0.6),
          shadow: theme.shadows.sm,
        );
      case UiCardVariant.accent:
        return _CardSkin(
          background: Color.alphaBlend(tint.withValues(alpha: 0.08), c.surface),
          borderColor: tint.withValues(alpha: 0.45),
        );
      case UiCardVariant.subtle:
        return _CardSkin(background: c.surfaceMuted, borderColor: c.border);
      case UiCardVariant.surface:
        return _CardSkin(
          background: active ? c.surfaceMuted : c.surface,
          borderColor: active ? c.borderStrong : c.border,
        );
    }
  }
}

class _CardSkin {
  const _CardSkin({
    required this.background,
    required this.borderColor,
    this.shadow,
    this.gradient,
  });

  final Color background;
  final Color borderColor;
  final List<BoxShadow>? shadow;
  final Gradient? gradient;
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    // Scaled here so a caller can hand over a plain logical height, matching
    // UiSkeleton and the charts: the placeholder has to be the same height as
    // the content it stands in for, or the card resizes when the data lands.
    final double h = context.sz(height ?? 72);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < 3; i++) ...<Widget>[
          Container(
            height: context.sz(10),
            width: double.infinity,
            margin: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.sm),
            ),
          ),
        ],
        SizedBox(height: h * 0.1),
      ],
    );
  }
}

class _UiCardHeader extends StatelessWidget {
  const _UiCardHeader({
    this.title,
    this.titleWidget,
    this.subtitle,
    this.leading,
    this.trailing,
    this.collapsible = false,
    this.expanded = true,
    this.onToggle,
  });

  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isNarrow =
            constraints.maxWidth < context.sz(440) || context.uiRes.isMobile;
        final Widget titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (titleWidget != null)
              titleWidget!
            else if (title != null)
              Text(
                title!,
                style: context.uiText.subheading.copyWith(
                  color: theme.colors.foreground,
                ),
              ),
            if (subtitle != null) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                subtitle!,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ],
        );

        if (isNarrow && trailing != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    leading!,
                    SizedBox(width: context.sp(theme.spacing.md)),
                  ],
                  Expanded(child: titleColumn),
                  if (collapsible) ...<Widget>[
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiInteractive(
                      onTap: onToggle,
                      semanticLabel: expanded ? 'Collapse' : 'Expand',
                      builder: (_, _) => AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: theme.motion.fast,
                        child: Icon(
                          Icons.expand_more,
                          size: context.sz(theme.sizes.iconMd),
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              trailing!,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              SizedBox(width: context.sp(theme.spacing.md)),
            ],
            Expanded(child: titleColumn),
            if (trailing != null) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.sm)),
              Flexible(
                child: Align(alignment: Alignment.topRight, child: trailing!),
              ),
            ],
            if (collapsible) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiInteractive(
                onTap: onToggle,
                semanticLabel: expanded ? 'Collapse' : 'Expand',
                builder: (_, _) => AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: theme.motion.fast,
                  child: Icon(
                    Icons.expand_more,
                    size: context.sz(theme.sizes.iconMd),
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
