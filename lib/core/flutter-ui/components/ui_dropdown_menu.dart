import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_button.dart';

/// A single row, section header, or divider inside [UiDropdownMenu].
class UiMenuItem {
  const UiMenuItem({
    required this.label,
    this.icon,
    this.trailingIcon,
    this.shortcut,
    this.description,
    this.leading,
    UiIntent? intent,
    bool destructive = false,
    this.enabled = true,
    this.selected = false,
    VoidCallback? onTap,
    VoidCallback? onSelected,
    VoidCallback? onPressed,
    this.children = const <UiMenuItem>[],
  }) : intent = intent ?? (destructive ? UiIntent.danger : null),
       onTap = onPressed ?? onTap ?? onSelected,
       isDivider = false,
       isSection = false;

  const UiMenuItem.divider()
    : label = '',
      leading = null,
      icon = null,
      trailingIcon = null,
      shortcut = null,
      description = null,
      intent = null,
      enabled = true,
      selected = false,
      onTap = null,
      children = const <UiMenuItem>[],
      isDivider = true,
      isSection = false;

  const UiMenuItem.section(this.label)
    : leading = null,
      icon = null,
      trailingIcon = null,
      shortcut = null,
      description = null,
      intent = null,
      enabled = true,
      selected = false,
      onTap = null,
      children = const <UiMenuItem>[],
      isDivider = false,
      isSection = true;

  final String label;
  final Widget? leading;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Keyboard hint text shown right-aligned, e.g. "⌘K".
  final String? shortcut;
  final String? description;
  final UiIntent? intent;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;

  /// Nested submenu items (rendered as an inline indented group).
  final List<UiMenuItem> children;

  final bool isDivider;
  final bool isSection;
}

typedef UiMenuAction = UiMenuItem;

/// Anchored popup menu with sections, dividers, shortcuts, icons, intents,
/// selection checkmarks and nested groups.
class UiDropdownMenu extends StatefulWidget {
  const UiDropdownMenu({
    super.key,
    List<UiMenuItem>? items,
    List<UiMenuItem>? actions,
    required this.child,
    this.width,
    this.alignRight = false,
    this.offset = 4,
    this.size = UiSize.sm,
    this.density = UiDensity.compact,
    this.enabled = true,
    this.header,
    this.footer,
    this.maxHeight = 360,
    this.closeOnSelect = true,
    this.semanticLabel,
    this.axis = Axis.vertical,
  }) : items = items ?? actions ?? const <UiMenuItem>[];

  final List<UiMenuItem> items;

  /// Use horizontal for compact reaction and quick-action palettes.
  final Axis axis;

  /// The trigger widget.
  final Widget child;

  final double? width;
  final bool alignRight;
  final double offset;
  final UiSize size;
  final UiDensity density;
  final bool enabled;

  final Widget? header;
  final Widget? footer;
  final double maxHeight;
  final bool closeOnSelect;
  final String? semanticLabel;

  @override
  State<UiDropdownMenu> createState() => _UiDropdownMenuState();
}

class _UiDropdownMenuState extends State<UiDropdownMenu>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(vsync: this);
  late final _progress = _motion.drive(CurveTween(curve: Curves.easeOutCubic));
  bool _closing = false;
  final LayerLink _link = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _remove();
    _motion.dispose();
    super.dispose();
  }

  void _remove() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _closing = false;
  }

  Future<void> _dismiss() async {
    if (_entry == null || _closing) return;
    _closing = true;
    _entry?.markNeedsBuild();
    try {
      await _motion.reverse().orCancel;
      if (!mounted) return;
      _remove();
      setState(() {});
    } on TickerCanceled {
      // Reopening or disposing cancels the closing transition.
    }
  }

  void _toggle() {
    if (_entry != null) {
      if (_closing) {
        _closing = false;
        _motion.forward();
        _entry?.markNeedsBuild();
      } else {
        _dismiss();
      }
      return;
    }
    final reduced = MediaQuery.disableAnimationsOf(context);
    _motion.duration = reduced ? Duration.zero : context.ui.motion.normal;
    _motion.reverseDuration = reduced ? Duration.zero : context.ui.motion.fast;
    final RenderBox? box =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final double triggerWidth = box?.size.width ?? 160;
    final media = MediaQuery.of(context);
    final double gutter = context.sp(context.ui.spacing.sm);
    final double width = math.min(
      widget.width ?? math.max(triggerWidth, 220),
      math.max(0, media.size.width - gutter * 2),
    );

    final Offset triggerPos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final double screenHeight =
        media.size.height - media.viewInsets.bottom - media.padding.bottom;
    final double above = math.max(
      0,
      triggerPos.dy - media.padding.top - gutter,
    );
    final double below = math.max(
      0,
      screenHeight - triggerPos.dy - (box?.size.height ?? 0) - gutter,
    );
    final bool openUpward =
        below < context.sz(widget.maxHeight) && above > below;

    final double desiredLeft = widget.alignRight
        ? triggerPos.dx + triggerWidth - width
        : triggerPos.dx;
    final double safeLeft = desiredLeft.clamp(
      gutter,
      math.max(gutter, media.size.width - width - gutter),
    );
    final double horizontalShift = safeLeft - desiredLeft;
    final double availableHeight = openUpward
        ? triggerPos.dy - media.padding.top - gutter
        : screenHeight - triggerPos.dy - (box?.size.height ?? 0) - gutter;

    _entry = OverlayEntry(
      builder: (BuildContext ctx) => Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismiss,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: openUpward
                ? (widget.alignRight ? Alignment.topRight : Alignment.topLeft)
                : (widget.alignRight
                      ? Alignment.bottomRight
                      : Alignment.bottomLeft),
            followerAnchor: openUpward
                ? (widget.alignRight
                      ? Alignment.bottomRight
                      : Alignment.bottomLeft)
                : (widget.alignRight ? Alignment.topRight : Alignment.topLeft),
            offset: Offset(
              horizontalShift,
              openUpward
                  ? -context.sz(widget.offset)
                  : context.sz(widget.offset),
            ),
            child: FadeTransition(
              opacity: _progress,
              child: ScaleTransition(
                scale: _progress.drive(Tween(begin: .95, end: 1.0)),
                alignment: openUpward
                    ? Alignment.bottomCenter
                    : Alignment.topCenter,
                child: IgnorePointer(
                  ignoring: _closing,
                  child: _MenuSurface(
                    width: width,
                    maxHeight: math.max(
                      0,
                      math.min(
                        widget.maxHeight,
                        availableHeight / context.uiRes.scale.size,
                      ),
                    ),
                    size: widget.size,
                    density: widget.density,
                    header: widget.header,
                    footer: widget.footer,
                    items: widget.items,
                    axis: widget.axis,
                    onSelected: (UiMenuItem item) {
                      if (widget.closeOnSelect) {
                        _dismiss();
                      }
                      item.onTap?.call();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
    _motion.forward(from: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        label: widget.semanticLabel,
        button: true,
        expanded: _entry != null,
        child: UiInteractive(
          pressScale: .96,
          key: _triggerKey,
          enabled: widget.enabled,
          onTap: widget.enabled ? _toggle : null,
          selected: _entry != null,
          builder: (BuildContext ctx, UiInteractiveState s) =>
              ExcludeFocus(child: IgnorePointer(child: widget.child)),
        ),
      ),
    );
  }
}

class _MenuSurface extends StatelessWidget {
  const _MenuSurface({
    required this.width,
    required this.axis,
    required this.maxHeight,
    required this.items,
    required this.onSelected,
    required this.size,
    required this.density,
    this.header,
    this.footer,
  });

  final double width;
  final double maxHeight;
  final List<UiMenuItem> items;
  final ValueChanged<UiMenuItem> onSelected;
  final Axis axis;
  final UiSize size;
  final UiDensity density;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;

    return Material(
      color: const Color(0x00000000),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: context.radius(
            axis == Axis.horizontal ? theme.radii.pill : theme.radii.md,
          ),
          border: Border.all(color: c.border, width: theme.borders.hairline),
          boxShadow: theme.shadows.lg,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (header != null) ...<Widget>[
              Padding(
                padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                child: header!,
              ),
              Container(height: theme.borders.hairline, color: c.border),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: context.sz(maxHeight)),
                child: SingleChildScrollView(
                  padding: axis == Axis.horizontal
                      ? EdgeInsets.all(context.sp(theme.spacing.xs))
                      : EdgeInsets.symmetric(
                          vertical: context.sp(theme.spacing.xxs),
                        ),
                  child: axis == Axis.horizontal
                      ? Row(
                          children: [
                            for (final item in items)
                              Expanded(
                                child: UiButton(
                                  label: item.label,
                                  semanticLabel: item.description ?? item.label,
                                  leading: item.leading,
                                  iconOnly: item.leading != null,
                                  alignment: Alignment.center,
                                  rounded: true,
                                  variant: UiVariant.ghost,
                                  size: size,
                                  selected: item.selected,
                                  style: UiButtonStyle(
                                    padding: EdgeInsets.zero,
                                    textStyle: context.uiText.heading,
                                  ),
                                  onPressed: item.enabled
                                      ? () => onSelected(item)
                                      : null,
                                ),
                              ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _rows(context, items, 0),
                        ),
                ),
              ),
            ),
            if (footer != null) ...<Widget>[
              Container(height: theme.borders.hairline, color: c.border),
              Padding(
                padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                child: footer!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _rows(BuildContext context, List<UiMenuItem> list, int depth) {
    final theme = context.ui;
    final c = theme.colors;
    final List<Widget> out = <Widget>[];
    for (final UiMenuItem item in list) {
      if (item.isDivider) {
        out.add(
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.xxs),
            ),
            child: Container(height: theme.borders.hairline, color: c.border),
          ),
        );
        continue;
      }
      if (item.isSection) {
        out.add(
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.sp(theme.spacing.sm),
              context.sp(theme.spacing.xs),
              context.sp(theme.spacing.sm),
              context.sp(theme.spacing.xxs),
            ),
            child: Text(
              item.label.toUpperCase(),
              style: context.uiText.caption.copyWith(
                color: c.foregroundSubtle,
                fontSize: context.fs(10),
              ),
            ),
          ),
        );
        continue;
      }
      out.add(
        _MenuRow(
          item: item,
          depth: depth,
          size: size,
          density: density,
          onTap: () => onSelected(item),
        ),
      );
      if (item.children.isNotEmpty) {
        out.addAll(_rows(context, item.children, depth + 1));
      }
    }
    return out;
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.depth,
    required this.onTap,
    required this.size,
    required this.density,
  });

  final UiMenuItem item;
  final int depth;
  final VoidCallback onTap;
  final UiSize size;
  final UiDensity density;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final Color accent = item.intent?.color(context) ?? c.foreground;
    final bool enabled = item.enabled;

    return UiInteractive(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      selected: item.selected,
      semanticLabel: item.label,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        padding: EdgeInsets.only(
          left: ctx.sp(theme.spacing.sm) + depth * ctx.sp(theme.spacing.md),
          right: ctx.sp(theme.spacing.sm),
          top: ctx.sp(theme.spacing.xs) * density.factor,
          bottom: ctx.sp(theme.spacing.xs) * density.factor,
        ),
        color: !enabled
            ? const Color(0x00000000)
            : s.hovered
            ? (item.intent == null
                  ? c.surfaceHover
                  : accent.withValues(alpha: 0.10))
            : (item.selected ? c.surfaceMuted : const Color(0x00000000)),
        child: Row(
          children: <Widget>[
            if (item.icon != null) ...<Widget>[
              Icon(
                item.icon,
                size: size == UiSize.xs ? ctx.sz(14) : size.icon(ctx),
                color: enabled
                    ? (item.intent == null ? c.foregroundMuted : accent)
                    : c.disabledForeground,
              ),
              SizedBox(width: ctx.sp(theme.spacing.xs)),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: size
                        .textStyle(ctx)
                        .copyWith(
                          fontSize: size == UiSize.sm
                              ? ctx.fs(13.0)
                              : (size == UiSize.xs ? ctx.fs(11.5) : null),
                          color: enabled ? accent : c.disabledForeground,
                          fontWeight: item.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                  ),
                  if (item.description != null)
                    Text(
                      item.description!,
                      softWrap: true,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: ctx.uiText.caption.copyWith(
                        color: c.foregroundSubtle,
                        fontSize: ctx.fs(11.0),
                      ),
                    ),
                ],
              ),
            ),
            if (item.shortcut != null) ...<Widget>[
              SizedBox(width: ctx.sp(theme.spacing.xs)),
              Text(
                item.shortcut!,
                style: ctx.uiText.caption.copyWith(
                  color: c.foregroundSubtle,
                  fontSize: ctx.fs(11.0),
                ),
              ),
            ],
            if (item.selected) ...<Widget>[
              SizedBox(width: ctx.sp(theme.spacing.xxs)),
              Icon(
                Icons.check,
                size: ctx.sz(12),
                color: item.intent?.color(ctx) ?? c.primary,
              ),
            ] else if (item.trailingIcon != null) ...<Widget>[
              SizedBox(width: ctx.sp(theme.spacing.xxs)),
              Icon(
                item.trailingIcon,
                size: ctx.sz(12),
                color: c.foregroundSubtle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
