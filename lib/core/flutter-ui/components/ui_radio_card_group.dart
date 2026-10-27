import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_field.dart';

/// Card-style single choice (order type, plan picker, risk profile).
///
/// Responsive column counts, optional media/footer slots per option, intents,
/// sizes, densities and validation messaging.
class UiRadioCardGroup<T> extends StatelessWidget {
  const UiRadioCardGroup({
    super.key,
    required this.options,
    this.value,
    this.onChanged,
    this.label,
    this.helperText,
    this.errorText,
    this.intent = UiIntent.primary,
    this.size = UiSize.md,
    this.density = UiDensity.comfortable,
    this.enabled = true,
    this.required = false,
    this.showRadio = true,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.mediaBuilder,
    this.footerBuilder,
    this.cardBuilder,
    this.semanticLabel,
  });

  final List<UiOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;

  final String? label;
  final String? helperText;
  final String? errorText;

  final UiIntent intent;
  final UiSize size;
  final UiDensity density;
  final bool enabled;
  final bool required;

  /// Hides the radio glyph for pure "tile" pickers.
  final bool showRadio;

  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;

  /// Optional visual above the title (icon tile, sparkline, logo).
  final Widget Function(
    BuildContext context,
    UiOption<T> option,
    bool selected,
  )?
  mediaBuilder;

  /// Optional footer inside the card (price, metrics, badges).
  final Widget Function(
    BuildContext context,
    UiOption<T> option,
    bool selected,
  )?
  footerBuilder;

  /// Replaces the whole card.
  final Widget Function(
    BuildContext context,
    UiOption<T> option,
    bool selected,
  )?
  cardBuilder;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final int cols = context.uiRes.columns(
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
      large: desktopColumns,
    );
    final double gap = context.sp(theme.spacing.md) * density.factor;
    final bool invalid = errorText != null;

    final Widget grid = LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final int effectiveCols = (availableWidth < 380 && cols > 1) ? 1 : cols;
        final double itemWidth = effectiveCols <= 1
            ? availableWidth
            : ((availableWidth - gap * (effectiveCols - 1)) / effectiveCols)
                  .clamp(40.0, availableWidth);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final UiOption<T> o in options)
              SizedBox(
                width: itemWidth,
                child: cardBuilder != null
                    ? cardBuilder!(ctx, o, o.value == value)
                    : _UiRadioCard<T>(
                        option: o,
                        selected: o.value == value,
                        intent: invalid ? UiIntent.danger : intent,
                        size: size,
                        density: density,
                        showRadio: showRadio,
                        media: mediaBuilder == null
                            ? null
                            : mediaBuilder!(ctx, o, o.value == value),
                        footer: footerBuilder == null
                            ? null
                            : footerBuilder!(ctx, o, o.value == value),
                        onTap: enabled && o.enabled && onChanged != null
                            ? () => onChanged!(o.value)
                            : null,
                      ),
              ),
          ],
        );
      },
    );

    final Widget group = Semantics(
      label: semanticLabel ?? label,
      enabled: enabled,
      child: grid,
    );

    if (label == null && helperText == null && errorText == null) return group;
    return UiField(
      label: label,
      helper: helperText,
      error: errorText,
      required: required,
      density: density,
      enabled: enabled,
      child: group,
    );
  }
}

class _UiRadioCard<T> extends StatelessWidget {
  const _UiRadioCard({
    required this.option,
    required this.selected,
    required this.intent,
    required this.size,
    required this.density,
    required this.showRadio,
    required this.onTap,
    this.media,
    this.footer,
  });

  final UiOption<T> option;
  final bool selected;
  final UiIntent intent;
  final UiSize size;
  final UiDensity density;
  final bool showRadio;
  final VoidCallback? onTap;
  final Widget? media;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final Color accent = intent.color(context);
    final bool enabled = onTap != null;
    final BorderRadius radius = context.radius(theme.radii.lg);

    return UiInteractive(
      enabled: enabled,
      onTap: onTap,
      selected: selected,
      semanticLabel: option.label,
      borderRadius: radius,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        curve: theme.motion.curve,
        transform: Matrix4.translationValues(
          0,
          s.hovered && enabled ? -ctx.sz(2) : 0,
          0,
        ),
        padding: EdgeInsets.all(ctx.sp(theme.spacing.lg) * density.factor),
        decoration: BoxDecoration(
          color: !enabled
              ? c.disabledBackground
              : selected
              ? Color.alphaBlend(accent.withValues(alpha: 0.08), c.surface)
              : (s.hovered ? c.surfaceHover : c.surface),
          borderRadius: radius,
          border: Border.all(
            color: !enabled
                ? c.border
                : selected
                ? accent
                : (s.hovered ? c.borderStrong : c.border),
            width: selected ? theme.borders.thick : theme.borders.hairline,
          ),
          boxShadow: selected
              ? uiGlow(ctx, accent, alpha: 0.16)
              : (s.hovered && enabled ? theme.shadows.md : null),
        ),
        foregroundDecoration: s.focused ? uiFocusRing(ctx, radius) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (media != null) ...<Widget>[
              media!,
              SizedBox(height: ctx.sp(theme.spacing.sm)),
            ],
            Row(
              children: <Widget>[
                if (option.icon != null) ...<Widget>[
                  Icon(
                    option.icon,
                    size: size.icon(ctx),
                    color: selected ? accent : c.foregroundMuted,
                  ),
                  SizedBox(width: ctx.sp(theme.spacing.sm)),
                ],
                Expanded(
                  child: Text(
                    option.label,
                    overflow: TextOverflow.ellipsis,
                    style: size
                        .textStyle(ctx)
                        .copyWith(
                          color: enabled ? c.foreground : c.disabledForeground,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (option.badge != null) ...<Widget>[
                  SizedBox(width: ctx.sp(theme.spacing.xs)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ctx.sp(theme.spacing.xs),
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: ctx.radius(theme.radii.pill),
                    ),
                    child: Text(
                      option.badge!,
                      style: ctx.uiText.caption.copyWith(color: accent),
                    ),
                  ),
                ],
                if (showRadio) ...<Widget>[
                  SizedBox(width: ctx.sp(theme.spacing.xs)),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: ctx.sz(theme.sizes.iconSm),
                    color: selected ? accent : c.foregroundSubtle,
                  ),
                ],
              ],
            ),
            if (option.description != null) ...<Widget>[
              SizedBox(height: ctx.sp(theme.spacing.xs)),
              Text(
                option.description!,
                style: ctx.uiText.caption.copyWith(color: c.foregroundMuted),
              ),
            ],
            if (option.trailingLabel != null) ...<Widget>[
              SizedBox(height: ctx.sp(theme.spacing.sm)),
              Text(
                option.trailingLabel!,
                style: ctx.uiText.numeric.copyWith(color: c.foreground),
              ),
            ],
            if (footer != null) ...<Widget>[
              SizedBox(height: ctx.sp(theme.spacing.sm)),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
