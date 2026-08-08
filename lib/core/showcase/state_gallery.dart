import 'package:flutter/material.dart';

import '../flutter-ui/flutter_ui.dart';

/// Simulated device widths so responsiveness is visible on one page.
enum UiShowcaseViewport {
  auto('Auto', null),
  mobile('Mobile 360', 360),
  tablet('Tablet 768', 768),
  desktop('Desktop 1440', 1440);

  const UiShowcaseViewport(this.label, this.width);

  final String label;
  final double? width;
}

/// Global showcase controls (theme brightness, density, viewport width)
/// shared by every gallery on the page.
@immutable
class UiShowcaseConfig {
  const UiShowcaseConfig({
    this.dark = true,
    this.density = UiDensity.comfortable,
    this.showLabels = true,
    this.showCode = false,
    this.rtl = false,
    this.textScale = 1.0,
    this.viewport = UiShowcaseViewport.auto,
  });

  final bool dark;
  final UiDensity density;
  final bool showLabels;
  final bool showCode;

  /// Mirrors the whole showcase to validate bidirectional layouts.
  final bool rtl;

  /// Accessibility text scaling factor applied to every gallery.
  final double textScale;

  /// Device-width simulator applied to the showcase body.
  final UiShowcaseViewport viewport;

  UiShowcaseConfig copyWith({
    bool? dark,
    UiDensity? density,
    bool? showLabels,
    bool? showCode,
    bool? rtl,
    double? textScale,
    UiShowcaseViewport? viewport,
  }) =>
      UiShowcaseConfig(
        dark: dark ?? this.dark,
        density: density ?? this.density,
        showLabels: showLabels ?? this.showLabels,
        showCode: showCode ?? this.showCode,
        rtl: rtl ?? this.rtl,
        textScale: textScale ?? this.textScale,
        viewport: viewport ?? this.viewport,
      );
}

/// Applies the global RTL / text-scale / device-width controls to a subtree.
class UiShowcaseEnvironment extends StatelessWidget {
  const UiShowcaseEnvironment({
    super.key,
    required this.config,
    required this.child,
  });

  final UiShowcaseConfig config;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double? width = config.viewport.width;
    Widget content = MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(config.textScale),
        size: width == null ? mq.size : Size(width, mq.size.height),
      ),
      child: child,
    );
    if (width != null) {
      content = Center(
        child: SizedBox(width: width, child: content),
      );
    }
    return Directionality(
      textDirection: config.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: content,
    );
  }
}

class UiShowcaseScope extends InheritedWidget {
  const UiShowcaseScope({
    super.key,
    required this.config,
    required this.onChanged,
    required super.child,
  });

  final UiShowcaseConfig config;
  final ValueChanged<UiShowcaseConfig> onChanged;

  static UiShowcaseScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiShowcaseScope>();

  static UiShowcaseConfig configOf(BuildContext context) =>
      maybeOf(context)?.config ?? const UiShowcaseConfig();

  @override
  bool updateShouldNotify(UiShowcaseScope oldWidget) =>
      oldWidget.config != config;
}

/// One cell of a state matrix: a label, an optional note and the rendered
/// component in that exact state.
@immutable
class UiStateCase {
  const UiStateCase(
    this.label, {
    this.builder,
    this.child,
    this.note,
    this.span = 1,
    this.fill = false,
  });

  /// Convenience for a case that does not need the build context.
  const UiStateCase.of(
    String label,
    Widget child, {
    String? note,
    int span = 1,
  }) : this(label, child: child, note: note, span: span);

  final String label;
  final String? note;
  final WidgetBuilder? builder;
  final Widget? child;

  /// How many grid columns the case occupies.
  final int span;

  /// Stretch the case to the full available width (charts, tables, blocks).
  final bool fill;
}

/// Renders every state of a single component inside one card, in a responsive
/// grid that reflows from 1 column (mobile) to 4 (large desktop).
class UiStateGallery extends StatelessWidget {
  const UiStateGallery({
    super.key,
    required this.name,
    required this.cases,
    this.index,
    this.description,
    this.tags = const <String>[],
    this.minCaseWidth = 240,
    this.background,
    this.padded = true,
    this.codeSnippet,
  });

  /// Component name, e.g. `UiButton`.
  final String name;

  /// Numbered showcase position, rendered as a chip when provided.
  final int? index;
  final String? description;
  final List<String> tags;
  final List<UiStateCase> cases;

  /// Smallest comfortable width for a single case before the grid reflows.
  final double minCaseWidth;
  final Color? background;
  final bool padded;
  final String? codeSnippet;

  @override
  Widget build(BuildContext context) {
    final UiShowcaseConfig config = UiShowcaseScope.configOf(context);
    final theme = context.ui;

    return UiCard(
      variant: UiCardVariant.surface,
      density: config.density,
      titleWidget: _Header(name: name, index: index, tags: tags),
      subtitle: description,
      headerDivider: true,
      collapsible: true,
      trailing: UiBadge(
        label: '${cases.length} states',
        size: UiSize.xs,
        variant: UiBadgeVariant.outline,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext ctx, BoxConstraints constraints) {
              final double gap = ctx.sp(theme.spacing.md);
              final double maxW = constraints.maxWidth;
              final int columns =
                  (maxW / ctx.sz(minCaseWidth)).floor().clamp(1, 4);
              final double colWidth =
                  (maxW - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: <Widget>[
                  for (final UiStateCase c in cases)
                    SizedBox(
                      width: c.fill
                          ? maxW
                          : (colWidth * c.span.clamp(1, columns) +
                                  gap * (c.span.clamp(1, columns) - 1))
                              .clamp(0.0, maxW),
                      child: _CaseTile(
                        state: c,
                        showLabel: config.showLabels,
                        background: background,
                        padded: padded,
                      ),
                    ),
                ],
              );
            },
          ),
          if (config.showCode && codeSnippet != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.lg)),
            _CodeBlock(code: codeSnippet!),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, this.index, this.tags = const <String>[]});

  final String name;
  final int? index;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Wrap(
      spacing: context.sp(theme.spacing.sm),
      runSpacing: context.sp(theme.spacing.xs),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (index != null)
          UiBadge(
            label: index.toString().padLeft(3, '0'),
            size: UiSize.xs,
            intent: UiIntent.primary,
            variant: UiBadgeVariant.solid,
          ),
        Text(
          name,
          style: context.uiText.heading
              .copyWith(color: theme.colors.foreground),
        ),
        for (final String t in tags)
          UiBadge(label: t, size: UiSize.xs, variant: UiBadgeVariant.ghost),
      ],
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({
    required this.state,
    required this.showLabel,
    this.background,
    this.padded = true,
  });

  final UiStateCase state;
  final bool showLabel;
  final Color? background;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showLabel) ...<Widget>[
          Text(
            state.label,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
        ],
        Container(
          width: double.infinity,
          padding: padded
              ? EdgeInsets.all(context.sp(theme.spacing.md))
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: background ?? theme.colors.surfaceMuted,
            borderRadius: context.radius(theme.radii.lg),
            border: Border.all(
              color: theme.colors.border,
              width: theme.borders.hairline,
            ),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: state.child ?? Builder(builder: state.builder!),
          ),
        ),
        if (showLabel && state.note != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            state.note!,
            style: context.uiText.caption
                .copyWith(color: theme.colors.foregroundSubtle),
          ),
        ],
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      decoration: BoxDecoration(
        color: theme.colors.background,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(
          color: theme.colors.border,
          width: theme.borders.hairline,
        ),
      ),
      child: SelectableText(
        code,
        style: context.uiText.caption.copyWith(
          fontFamily: 'monospace',
          color: theme.colors.foregroundMuted,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Section heading used to group galleries by category.
class UiShowcaseSection extends StatelessWidget {
  const UiShowcaseSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: context.sp(theme.spacing.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title.toUpperCase(),
                  style: context.uiText.heading.copyWith(
                    color: theme.colors.foreground,
                    letterSpacing: 1.2,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    subtitle!,
                    style: context.uiText.body
                        .copyWith(color: theme.colors.foregroundMuted),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Sticky control bar: theme, density, labels, code snippets.
class UiShowcaseControlBar extends StatelessWidget {
  const UiShowcaseControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    final UiShowcaseScope? scope = UiShowcaseScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    final UiShowcaseConfig cfg = scope.config;
    final theme = context.ui;

    return Container(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: context.radius(theme.radii.xl),
        border: Border.all(
          color: theme.colors.border,
          width: theme.borders.hairline,
        ),
        boxShadow: theme.shadows.sm,
      ),
      child: Wrap(
        spacing: context.sp(theme.spacing.sm),
        runSpacing: context.sp(theme.spacing.sm),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          UiButton(
            label: cfg.dark ? 'Dark theme' : 'Light theme',
            leadingIcon: cfg.dark ? Icons.dark_mode : Icons.light_mode,
            variant: UiVariant.soft,
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => scope.onChanged(cfg.copyWith(dark: !cfg.dark)),
          ),
          for (final UiDensity d in UiDensity.values)
            UiButton(
              label: d.label,
              size: UiSize.sm,
              variant:
                  cfg.density == d ? UiVariant.primary : UiVariant.outline,
              expandOnMobile: false,
              onPressed: () => scope.onChanged(cfg.copyWith(density: d)),
            ),
          UiButton(
            label: 'Labels',
            size: UiSize.sm,
            selected: cfg.showLabels,
            variant: cfg.showLabels ? UiVariant.soft : UiVariant.ghost,
            expandOnMobile: false,
            onPressed: () =>
                scope.onChanged(cfg.copyWith(showLabels: !cfg.showLabels)),
          ),
          UiButton(
            label: 'Code',
            size: UiSize.sm,
            selected: cfg.showCode,
            variant: cfg.showCode ? UiVariant.soft : UiVariant.ghost,
            expandOnMobile: false,
            onPressed: () =>
                scope.onChanged(cfg.copyWith(showCode: !cfg.showCode)),
          ),
          UiButton(
            label: 'RTL',
            size: UiSize.sm,
            selected: cfg.rtl,
            variant: cfg.rtl ? UiVariant.soft : UiVariant.ghost,
            expandOnMobile: false,
            onPressed: () => scope.onChanged(cfg.copyWith(rtl: !cfg.rtl)),
          ),
          for (final double s in const <double>[0.9, 1.0, 1.15, 1.3])
            UiButton(
              label: '${s}x',
              size: UiSize.sm,
              variant: cfg.textScale == s
                  ? UiVariant.primary
                  : UiVariant.outline,
              expandOnMobile: false,
              onPressed: () => scope.onChanged(cfg.copyWith(textScale: s)),
            ),
          for (final UiShowcaseViewport v in UiShowcaseViewport.values)
            UiButton(
              label: v.label,
              size: UiSize.sm,
              variant:
                  cfg.viewport == v ? UiVariant.primary : UiVariant.outline,
              expandOnMobile: false,
              onPressed: () => scope.onChanged(cfg.copyWith(viewport: v)),
            ),
        ],
      ),
    );
  }
}
