import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Chrome of the group container.
enum UiToggleGroupVariant {
  /// Inset track with a sliding selected pill (default).
  segmented,

  /// Standalone pills with no shared track.
  pill,

  /// Bordered, joined buttons.
  joined,

  /// Text-only with an underline on the selected item.
  underline,
}

class UiToggleOption<T> extends UiOption<T> {
  const UiToggleOption({
    required super.value,
    required super.label,
    super.icon,
    super.intent,
    super.badge,
    super.tooltip,
    super.description,
    super.trailingLabel,
    super.group,
    super.enabled = true,
  });
}

/// Segmented control (Buy / Sell, 1D / 1W / 1M) with single or multi select.
///
/// Single select uses [value] + [onChanged]; multi select uses [values] +
/// [onValuesChanged]. Both keep the same visual states.
class UiToggleGroup<T> extends StatelessWidget {
  const UiToggleGroup({
    super.key,
    required this.options,
    this.value,
    this.onChanged,
    this.values = const <Never>[],
    this.onValuesChanged,
    this.multiple = false,
    this.size = UiSize.sm,
    this.variant = UiToggleGroupVariant.segmented,
    this.density = UiDensity.comfortable,
    this.orientation = UiOrientation.horizontal,
    this.intent,
    this.expand = false,
    this.iconOnly = false,
    this.enabled = true,
    this.scrollWhenTight = true,
    this.allowEmpty = true,
    this.label,
    this.semanticLabel,
  });

  final List<UiOption<T>> options;

  /// Selected value (single-select mode).
  final T? value;
  final ValueChanged<T>? onChanged;

  /// Selected values (multi-select mode).
  final List<T> values;
  final ValueChanged<List<T>>? onValuesChanged;
  final bool multiple;

  final UiSize size;
  final UiToggleGroupVariant variant;
  final UiDensity density;
  final UiOrientation orientation;

  /// Group-level selected color; per-option [UiToggleOption.intent] wins.
  final UiIntent? intent;

  final bool expand;
  final bool iconOnly;
  final bool enabled;

  /// Scroll horizontally instead of overflowing when the segments need more
  /// width than the box allows.
  ///
  /// This is a question about the box, not about the screen: a five-segment
  /// control is perfectly comfortable on a 1600 px desktop and clips its last
  /// segment inside a 340 dp index rail on the same screen. Turn it off only for
  /// a group you would rather see clip than scroll.
  final bool scrollWhenTight;

  /// When false, the last selected item cannot be deselected in multi mode.
  final bool allowEmpty;

  final String? label;
  final String? semanticLabel;

  bool _isSelected(UiOption<T> o) =>
      multiple ? values.contains(o.value) : o.value == value;

  void _tap(UiOption<T> o) {
    if (!multiple) {
      onChanged?.call(o.value);
      return;
    }
    final List<T> next = List<T>.from(values);
    if (next.contains(o.value)) {
      if (!allowEmpty && next.length == 1) return;
      next.remove(o.value);
    } else {
      next.add(o.value);
    }
    onValuesChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final theme = ctx.ui;
        final c = theme.colors;
        final BorderRadius radius = ctx.radius(size.radius(ctx));
        final bool vertical = orientation == UiOrientation.vertical;
        final bool hasBoundedWidth = constraints.hasBoundedWidth;
        final double minSegmentWidth = iconOnly ? ctx.sz(36) : ctx.sz(68);
        final bool fitsExpanded =
            !hasBoundedWidth ||
            constraints.maxWidth >= options.length * minSegmentWidth;
        final bool effectiveExpand =
            hasBoundedWidth &&
            (expand ||
                (constraints.hasTightWidth &&
                    variant != UiToggleGroupVariant.pill &&
                    fitsExpanded));

        final List<Widget> items = <Widget>[
          for (int i = 0; i < options.length; i++)
            _UiToggleButton<T>(
              option: options[i],
              selected: _isSelected(options[i]),
              size: size,
              variant: variant,
              density: density,
              groupIntent: intent,
              iconOnly: iconOnly,
              first: i == 0,
              last: i == options.length - 1,
              isExpanded: effectiveExpand,
              vertical: vertical,
              onTap:
                  enabled &&
                      options[i].enabled &&
                      (onChanged != null || onValuesChanged != null)
                  ? () => _tap(options[i])
                  : null,
            ),
        ];

        final Widget flow = vertical
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: items,
              )
            : Row(
                mainAxisSize: effectiveExpand
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: <Widget>[
                  for (final Widget item in items)
                    effectiveExpand ? Expanded(child: item) : item,
                ],
              );

        Widget container;
        switch (variant) {
          case UiToggleGroupVariant.segmented:
            container = Container(
              // Keep the buttons at their full token height while making the
              // complete segmented control align with other controls of this size.
              padding: EdgeInsets.all(ctx.sz(2)),
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: radius,
                border: Border.all(
                  color: c.border,
                  width: theme.borders.hairline,
                ),
              ),
              child: flow,
            );
            break;
          case UiToggleGroupVariant.joined:
            container = Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: c.border,
                  width: theme.borders.hairline,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: flow,
            );
            break;
          case UiToggleGroupVariant.pill:
            container = Wrap(
              spacing: ctx.sp(theme.spacing.xs),
              runSpacing: ctx.sp(theme.spacing.xs),
              children: items,
            );
            break;
          case UiToggleGroupVariant.underline:
            container = DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: c.border,
                    width: theme.borders.hairline,
                  ),
                ),
              ),
              child: flow,
            );
            break;
        }

        if (label != null) {
          container = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label!,
                style: ctx.uiText.label.copyWith(color: c.foregroundMuted),
              ),
              SizedBox(height: ctx.sp(theme.spacing.xs)),
              container,
            ],
          );
        }

        final Widget result = Semantics(
          label: semanticLabel,
          enabled: enabled,
          child: Opacity(opacity: enabled ? 1 : 0.6, child: container),
        );

        if (!vertical &&
            !effectiveExpand &&
            scrollWhenTight &&
            variant != UiToggleGroupVariant.pill &&
            hasBoundedWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: result,
          );
        }
        return result;
      },
    );
  }
}

class _UiToggleButton<T> extends StatelessWidget {
  const _UiToggleButton({
    required this.option,
    required this.selected,
    required this.size,
    required this.variant,
    required this.density,
    required this.iconOnly,
    required this.first,
    required this.last,
    required this.isExpanded,
    required this.vertical,
    required this.onTap,
    this.groupIntent,
  });

  final UiOption<T> option;
  final bool selected;
  final UiSize size;
  final UiToggleGroupVariant variant;
  final UiDensity density;
  final bool iconOnly;
  final bool first;
  final bool last;
  final bool isExpanded;
  final bool vertical;
  final UiIntent? groupIntent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final double f = density.factor;
    final UiIntent? tint = option.intent ?? groupIntent;
    final bool enabled = onTap != null;

    final Color activeBg = switch (variant) {
      UiToggleGroupVariant.underline => const Color(0x00000000),
      _ => tint != null ? tint.color(context) : c.surface,
    };
    final Color activeFg = switch (variant) {
      UiToggleGroupVariant.underline => c.foreground,
      _ => tint != null ? tint.onColor(context) : c.foreground,
    };

    final BorderRadius? buttonRadius;
    if (variant == UiToggleGroupVariant.underline) {
      buttonRadius = null;
    } else if (variant == UiToggleGroupVariant.pill) {
      buttonRadius = context.radius(theme.radii.pill);
    } else if (isExpanded || variant == UiToggleGroupVariant.joined) {
      final Radius cr = Radius.circular(context.sz(size.radius(context)));
      if (first && last) {
        buttonRadius = BorderRadius.all(cr);
      } else if (first) {
        buttonRadius = vertical
            ? BorderRadius.vertical(top: cr)
            : BorderRadius.horizontal(left: cr);
      } else if (last) {
        buttonRadius = vertical
            ? BorderRadius.vertical(bottom: cr)
            : BorderRadius.horizontal(right: cr);
      } else {
        buttonRadius = BorderRadius.zero;
      }
    } else {
      buttonRadius = context.radius(size.radius(context));
    }

    return UiInteractive(
      enabled: enabled,
      onTap: onTap,
      selected: selected,
      tooltip: option.tooltip ?? (iconOnly ? option.label : null),
      semanticLabel: option.label,
      borderRadius: buttonRadius,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        curve: theme.motion.curve,
        constraints: BoxConstraints(minHeight: size.height(ctx) - ctx.sz(4)),
        padding: EdgeInsets.symmetric(
          horizontal:
              ctx.sp(
                iconOnly || isExpanded ? theme.spacing.sm : theme.spacing.md,
              ) *
              f,
          vertical: ctx.sp(theme.spacing.xs) * f,
        ),
        // Pill groups live inside a Wrap and must hug their label. Supplying
        // alignment makes AnimatedContainer expand to the full available row,
        // which turns every chip into an oversized stacked bar.
        alignment: variant == UiToggleGroupVariant.pill
            ? null
            : Alignment.center,
        decoration: BoxDecoration(
          color: !enabled
              ? c.surfaceHover.withValues(alpha: 0.0)
              : selected
              ? activeBg
              : (s.hovered
                    ? c.surfaceHover
                    : c.surfaceHover.withValues(alpha: 0.0)),
          borderRadius: buttonRadius,
          border: variant == UiToggleGroupVariant.pill
              ? Border.all(
                  color: selected ? activeBg : c.border,
                  width: theme.borders.hairline,
                )
              : variant == UiToggleGroupVariant.underline
              ? Border(
                  bottom: BorderSide(
                    color: selected
                        ? (tint?.color(context) ?? c.primary)
                        : (tint?.color(context) ?? c.primary).withValues(
                            alpha: 0.0,
                          ),
                    width: theme.borders.focus,
                  ),
                )
              : null,
          boxShadow: selected && variant == UiToggleGroupVariant.segmented
              ? theme.shadows.sm
              : null,
        ),
        foregroundDecoration: s.focused
            ? uiFocusRing(ctx, buttonRadius ?? BorderRadius.zero)
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (option.icon != null) ...<Widget>[
              Icon(
                option.icon,
                size: size.icon(ctx) * 0.95,
                color: !enabled
                    ? c.disabledForeground
                    : selected
                    ? activeFg
                    : c.foregroundMuted,
              ),
              if (!iconOnly) SizedBox(width: ctx.sp(theme.spacing.xs)),
            ],
            if (!iconOnly)
              Flexible(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: size
                      .textStyle(ctx)
                      .copyWith(
                        color: !enabled
                            ? c.disabledForeground
                            : selected
                            ? activeFg
                            : c.foregroundMuted,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                ),
              ),
            if (option.badge != null && !iconOnly) ...<Widget>[
              SizedBox(width: ctx.sp(theme.spacing.xs)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ctx.sp(theme.spacing.xs),
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? activeFg.withValues(alpha: 0.16)
                      : c.surfaceMuted,
                  borderRadius: ctx.radius(theme.radii.pill),
                ),
                child: Text(
                  option.badge!,
                  style: ctx.uiText.caption.copyWith(
                    color: selected ? activeFg : c.foregroundMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
