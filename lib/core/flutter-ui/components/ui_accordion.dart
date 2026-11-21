import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Accordion chrome.
enum UiAccordionVariant {
  /// One bordered container with hairline separators (default).
  contained,

  /// Each item is its own card with a gap between them.
  separated,

  /// No borders at all — headers only.
  ghost,

  /// Editorial hairline list with circled numerals, display headings, and
  /// animated `+` -> `×` expand/collapse transitions.
  editorial,
}

class UiAccordionItem {
  const UiAccordionItem({
    required this.title,
    required this.content,
    this.subtitle,
    this.leadingIcon,
    this.leading,
    this.trailing,
    this.badge,
    this.intent,
    this.enabled = true,
    this.initiallyOpen = false,
  });

  final String title;
  final Widget content;
  final String? subtitle;
  final IconData? leadingIcon;

  /// Replaces the leading icon (avatar, sparkline, status dot).
  final Widget? leading;

  /// Extra widget before the chevron (badge, switch, price).
  final Widget? trailing;
  final String? badge;

  /// Tints the header text/icon without adding a heavy edge stripe.
  final UiIntent? intent;
  final bool enabled;
  final bool initiallyOpen;
}

class UiAccordionSection extends UiAccordionItem {
  UiAccordionSection({
    required super.title,
    required Widget child,
    super.subtitle,
    super.leadingIcon,
    super.leading,
    super.trailing,
    super.badge,
    super.intent,
    super.enabled = true,
    super.initiallyOpen = false,
  }) : super(content: child);
}

/// Expand/collapse list. Single or multiple open sections, controlled or
/// uncontrolled, with density, size and variant options.
class UiAccordion extends StatefulWidget {
  const UiAccordion({
    super.key,
    List<UiAccordionItem>? items,
    List<UiAccordionSection>? sections,
    this.allowMultiple = false,
    this.initiallyOpen = const <int>{},
    this.openIndices,
    this.onChanged,
    this.variant = UiAccordionVariant.contained,
    this.size = UiSize.md,
    this.density = UiDensity.comfortable,
    this.chevronIcon = Icons.keyboard_arrow_down,
    this.chevronLeading = false,
    this.dividers = true,
    this.enabled = true,
  }) : items = items ?? sections ?? const <UiAccordionItem>[];

  final List<UiAccordionItem> items;
  final bool allowMultiple;
  final Set<int> initiallyOpen;

  /// When provided the accordion is controlled; pair with [onChanged].
  final Set<int>? openIndices;
  final ValueChanged<Set<int>>? onChanged;

  final UiAccordionVariant variant;
  final UiSize size;
  final UiDensity density;
  final IconData chevronIcon;
  final bool chevronLeading;
  final bool dividers;
  final bool enabled;

  @override
  State<UiAccordion> createState() => _UiAccordionState();
}

class _UiAccordionState extends State<UiAccordion> {
  late Set<int> _open = <int>{
    ...widget.initiallyOpen,
    for (int i = 0; i < widget.items.length; i++)
      if (widget.items[i].initiallyOpen) i,
  };

  Set<int> get _effective => widget.openIndices ?? _open;

  void _toggle(int index) {
    final Set<int> next = <int>{..._effective};
    if (next.contains(index)) {
      next.remove(index);
    } else {
      if (!widget.allowMultiple) next.clear();
      next.add(index);
    }
    widget.onChanged?.call(next);
    if (widget.openIndices == null) setState(() => _open = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final double gap = context.sp(theme.spacing.sm);

    final List<Widget> tiles = <Widget>[
      for (int i = 0; i < widget.items.length; i++)
        _UiAccordionTile(
          index: i,
          item: widget.items[i],
          open: _effective.contains(i),
          size: widget.size,
          density: widget.density,
          variant: widget.variant,
          chevronIcon: widget.chevronIcon,
          chevronLeading: widget.chevronLeading,
          showDivider:
              widget.dividers &&
              ((widget.variant == UiAccordionVariant.contained &&
                      i != widget.items.length - 1) ||
                  widget.variant == UiAccordionVariant.editorial),
          enabled: widget.enabled && widget.items[i].enabled,
          onTap: () => _toggle(i),
        ),
    ];

    switch (widget.variant) {
      case UiAccordionVariant.contained:
        return Container(
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: context.radius(theme.radii.lg),
            border: Border.all(
              color: theme.colors.border,
              width: theme.borders.hairline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: tiles),
        );
      case UiAccordionVariant.separated:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < tiles.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: gap),
              Container(
                decoration: BoxDecoration(
                  color: theme.colors.surface,
                  borderRadius: context.radius(theme.radii.lg),
                  border: Border.all(
                    color: theme.colors.border,
                    width: theme.borders.hairline,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: tiles[i],
              ),
            ],
          ],
        );
      case UiAccordionVariant.ghost:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: tiles,
        );
      case UiAccordionVariant.editorial:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.dividers && tiles.isNotEmpty)
              Container(
                height: theme.borders.hairline,
                color: theme.colors.border,
              ),
            ...tiles,
          ],
        );
    }
  }
}

class _UiAccordionTile extends StatelessWidget {
  const _UiAccordionTile({
    required this.index,
    required this.item,
    required this.open,
    required this.onTap,
    required this.showDivider,
    required this.size,
    required this.density,
    required this.variant,
    required this.chevronIcon,
    required this.chevronLeading,
    required this.enabled,
  });

  final int index;
  final UiAccordionItem item;
  final bool open;
  final VoidCallback onTap;
  final bool showDivider;
  final UiSize size;
  final UiDensity density;
  final UiAccordionVariant variant;
  final IconData chevronIcon;
  final bool chevronLeading;
  final bool enabled;

  Widget _buildEditorialTile(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final bool compact = context.uiRes.isMobile;
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);
    final Duration toggleDuration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 280);
    final Duration expandDuration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 320);

    final double badgeSize = compact ? 24.0 : 28.0;
    final double gap = compact ? 14.0 : 18.0;
    final double contentIndent = badgeSize + gap;

    final Widget numberBadge =
        item.leading ??
        AnimatedContainer(
          duration: toggleDuration,
          curve: Curves.easeOutCubic,
          width: badgeSize,
          height: badgeSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: open
                ? c.foreground.withValues(alpha: 0.08)
                : c.foreground.withValues(alpha: 0.0),
            border: Border.all(
              color: enabled ? c.foreground : c.disabledForeground,
              width: 1.75,
            ),
          ),
          child: Text(
            '${index + 1}',
            style: context.uiText.numeric.copyWith(
              fontSize: compact ? 12.0 : 13.5,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: enabled ? c.foreground : c.disabledForeground,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiInteractive(
          enabled: enabled,
          onTap: enabled ? onTap : null,
          selected: open,
          semanticLabel: '${index + 1}. ${item.title}',
          builder: (BuildContext ctx, UiInteractiveState s) {
            final Color iconColor = !enabled
                ? c.disabledForeground
                : (open || s.hovered ? c.foreground : c.foregroundMuted);
            return AnimatedContainer(
              duration: theme.motion.fast,
              decoration: BoxDecoration(
                color: s.hovered
                    ? c.surfaceHover.withValues(alpha: 0.45)
                    : c.surfaceHover.withValues(alpha: 0.0),
              ),
              foregroundDecoration: s.focused
                  ? uiFocusRing(ctx, BorderRadius.zero)
                  : null,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4.0 : 8.0,
                vertical: compact ? 18.0 : 24.0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  numberBadge,
                  SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          style: ctx.uiText.display.copyWith(
                            fontSize: compact ? 20.0 : 26.0,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                            height: 1.15,
                            color: enabled
                                ? c.foreground
                                : c.disabledForeground,
                          ),
                        ),
                        if (item.subtitle != null) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            item.subtitle!,
                            style: ctx.uiText.caption.copyWith(
                              color: c.foregroundMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.trailing != null) ...<Widget>[
                    SizedBox(width: ctx.sp(theme.spacing.sm)),
                    item.trailing!,
                  ],
                  SizedBox(width: ctx.sp(theme.spacing.md)),
                  AnimatedRotation(
                    turns: open ? 0.125 : 0.0,
                    duration: toggleDuration,
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.add_rounded,
                      size: compact ? 22.0 : 25.0,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        _EditorialAccordionReveal(
          open: open,
          duration: expandDuration,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                (compact ? 4.0 : 8.0) + contentIndent,
                2.0,
                compact ? 8.0 : 32.0,
                compact ? 22.0 : 30.0,
              ),
              child: DefaultTextStyle(
                style: context.uiText.body.copyWith(
                  color: c.foregroundMuted,
                ),
                child: item.content,
              ),
            ),
          ),
        ),
        if (showDivider)
          Container(height: theme.borders.hairline, color: c.border),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (variant == UiAccordionVariant.editorial) {
      return _buildEditorialTile(context);
    }
    final theme = context.ui;
    final c = theme.colors;
    final double f = density.factor;
    final Color? accent = item.intent?.color(context);
    final EdgeInsets pad = EdgeInsets.symmetric(
      horizontal: context.sp(theme.spacing.lg) * f,
      vertical: context.sp(theme.spacing.md) * f,
    );

    final Widget chevron = AnimatedRotation(
      turns: open ? 0.5 : 0,
      duration: theme.motion.normal,
      curve: theme.motion.curve,
      child: Icon(
        chevronIcon,
        size: size.icon(context),
        color: enabled ? c.foregroundMuted : c.disabledForeground,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiInteractive(
          enabled: enabled,
          onTap: enabled ? onTap : null,
          selected: open,
          semanticLabel: item.title,
          builder: (BuildContext ctx, UiInteractiveState s) =>
              AnimatedContainer(
                duration: theme.motion.fast,
                decoration: BoxDecoration(
                  color: !enabled
                      ? c.disabledBackground
                      : s.hovered
                      ? c.surfaceHover
                      : (open && variant != UiAccordionVariant.ghost
                            ? c.surfaceMuted
                            : c.surfaceHover.withValues(alpha: 0.0)),
                ),
                foregroundDecoration: s.focused
                    ? uiFocusRing(ctx, BorderRadius.zero)
                    : null,
                padding: pad,
                child: Row(
                  children: <Widget>[
                    if (chevronLeading) ...<Widget>[
                      chevron,
                      SizedBox(width: ctx.sp(theme.spacing.sm)),
                    ],
                    if (item.leading != null) ...<Widget>[
                      item.leading!,
                      SizedBox(width: ctx.sp(theme.spacing.md)),
                    ] else if (item.leadingIcon != null) ...<Widget>[
                      Icon(
                        item.leadingIcon,
                        size: size.icon(ctx),
                        color:
                            accent ??
                            (enabled
                                ? c.foregroundMuted
                                : c.disabledForeground),
                      ),
                      SizedBox(width: ctx.sp(theme.spacing.md)),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            style: size
                                .textStyle(ctx)
                                .copyWith(
                                  color: enabled
                                      ? (accent ?? c.foreground)
                                      : c.disabledForeground,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (item.subtitle != null)
                            Text(
                              item.subtitle!,
                              style: ctx.uiText.caption.copyWith(
                                color: c.foregroundMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (item.badge != null) ...<Widget>[
                      SizedBox(width: ctx.sp(theme.spacing.sm)),
                      Flexible(
                        flex: 0,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: ctx.sz(96)),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ctx.sp(theme.spacing.xs),
                            ),
                            decoration: BoxDecoration(
                              color: (accent ?? c.foregroundMuted).withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: ctx.radius(theme.radii.pill),
                            ),
                            child: Text(
                              item.badge!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ctx.uiText.caption.copyWith(
                                color: accent ?? c.foregroundMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (item.trailing != null) ...<Widget>[
                      SizedBox(width: ctx.sp(theme.spacing.sm)),
                      item.trailing!,
                    ],
                    if (!chevronLeading) ...<Widget>[
                      SizedBox(width: ctx.sp(theme.spacing.sm)),
                      chevron,
                    ],
                  ],
                ),
              ),
        ),
        AnimatedCrossFade(
          duration: theme.motion.normal,
          sizeCurve: theme.motion.curve,
          firstCurve: theme.motion.curve,
          crossFadeState: open
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Container(
            width: double.infinity,
            padding: pad.copyWith(top: 0),
            child: DefaultTextStyle(
              style: context.uiText.body.copyWith(color: c.foregroundMuted),
              child: item.content,
            ),
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
        if (showDivider)
          Container(height: theme.borders.hairline, color: c.border),
      ],
    );
  }
}

class _EditorialAccordionReveal extends StatefulWidget {
  const _EditorialAccordionReveal({
    required this.open,
    required this.duration,
    required this.child,
  });

  final bool open;
  final Duration duration;
  final Widget child;

  @override
  State<_EditorialAccordionReveal> createState() =>
      _EditorialAccordionRevealState();
}

class _EditorialAccordionRevealState extends State<_EditorialAccordionReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.open ? 1.0 : 0.0,
  );
  late final Animation<double> _sizeCurve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<double> _fadeCurve = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.12, 1.0, curve: Curves.easeOut),
    reverseCurve: const Interval(0.0, 0.72, curve: Curves.easeIn),
  );
  late final Animation<Offset> _slideCurve = Tween<Offset>(
    begin: const Offset(0, -0.04),
    end: Offset.zero,
  ).animate(_sizeCurve);

  @override
  void didUpdateWidget(covariant _EditorialAccordionReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.open != widget.open) {
      if (widget.duration == Duration.zero) {
        _controller.value = widget.open ? 1.0 : 0.0;
      } else if (widget.open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        if (_controller.isDismissed) {
          return const SizedBox.shrink();
        }
        return ClipRect(
          child: SizeTransition(
            sizeFactor: _sizeCurve,
            alignment: Alignment.topLeft,
            child: FadeTransition(
              opacity: _fadeCurve,
              child: SlideTransition(
                position: _slideCurve,
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
