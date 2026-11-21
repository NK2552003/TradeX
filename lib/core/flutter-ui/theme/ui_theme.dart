import 'package:flutter/material.dart';

import 'ui_responsive.dart';
import 'ui_tokens.dart';

/// The theme object every component reads from. Injected once via
/// [UiThemeScope] (or as a Material [ThemeExtension]).
@immutable
class UiTheme extends ThemeExtension<UiTheme> {
  const UiTheme({
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.radii,
    required this.borders,
    required this.shadows,
    required this.motion,
    required this.sizes,
    required this.breakpoints,
    required this.scaleConfig,
    required this.brightness,
    this.zoom = 1,
  });

  final UiColors colors;
  final UiTypography typography;
  final UiSpacing spacing;
  final UiRadii radii;
  final UiBorders borders;
  final UiShadows shadows;
  final UiMotion motion;
  final UiSizes sizes;
  final UiBreakpoints breakpoints;
  final UiScaleConfig scaleConfig;
  final Brightness brightness;
  final double zoom;

  static UiTheme light({
    UiColors? colors,
    UiTypography? typography,
    UiSpacing spacing = const UiSpacing(),
    UiRadii radii = const UiRadii(),
    UiBorders borders = const UiBorders(),
    UiShadows? shadows,
    UiMotion motion = const UiMotion(),
    UiSizes sizes = const UiSizes(),
    UiBreakpoints breakpoints = const UiBreakpoints(),
    UiScaleConfig scaleConfig = const UiScaleConfig(),
  }) => UiTheme(
    colors: colors ?? UiColors.light(),
    typography: typography ?? UiTypography.standard(),
    spacing: spacing,
    radii: radii,
    borders: borders,
    shadows: shadows ?? UiShadows.light(),
    motion: motion,
    sizes: sizes,
    breakpoints: breakpoints,
    scaleConfig: scaleConfig,
    brightness: Brightness.light,
  );

  static UiTheme dark({
    UiColors? colors,
    UiTypography? typography,
    UiSpacing spacing = const UiSpacing(),
    UiRadii radii = const UiRadii(),
    UiBorders borders = const UiBorders(),
    UiShadows? shadows,
    UiMotion motion = const UiMotion(),
    UiSizes sizes = const UiSizes(),
    UiBreakpoints breakpoints = const UiBreakpoints(),
    UiScaleConfig scaleConfig = const UiScaleConfig(),
  }) => UiTheme(
    colors: colors ?? UiColors.dark(),
    typography: typography ?? UiTypography.standard(),
    spacing: spacing,
    radii: radii,
    borders: borders,
    shadows: shadows ?? UiShadows.dark(),
    motion: motion,
    sizes: sizes,
    breakpoints: breakpoints,
    scaleConfig: scaleConfig,
    brightness: Brightness.dark,
  );

  /// Builds a Material [ThemeData] that carries this design system, so plain
  /// Material widgets match the custom components.
  ThemeData toThemeData() {
    final effectiveTypography = _uiScaledTypography(typography, zoom);
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      error: colors.destructive,
      onError: colors.onDestructive,
      surface: colors.surface,
      onSurface: colors.foreground,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      fontFamily: typography.fontFamily,
      dividerColor: colors.border,
      // No Material ripple: interaction reads as a quiet background/border
      // shift, matching the rest of the system.
      splashFactory: NoSplash.splashFactory,
      splashColor: const Color(0x00000000),
      highlightColor: const Color(0x00000000),
      hoverColor: colors.surfaceHover,
      focusColor: colors.surfaceHover,
      textTheme: TextTheme(
        displaySmall: effectiveTypography.display.copyWith(
          color: colors.foreground,
        ),
        headlineSmall: effectiveTypography.title.copyWith(
          color: colors.foreground,
        ),
        titleLarge: effectiveTypography.heading.copyWith(
          color: colors.foreground,
        ),
        titleMedium: effectiveTypography.subheading.copyWith(
          color: colors.foreground,
        ),
        bodyMedium: effectiveTypography.body.copyWith(color: colors.foreground),
        labelLarge: effectiveTypography.label.copyWith(
          color: colors.foreground,
        ),
        bodySmall: effectiveTypography.caption.copyWith(
          color: colors.foregroundMuted,
        ),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.dragged)) {
            return colors.foregroundMuted.withValues(alpha: 0.85);
          }
          if (states.contains(WidgetState.hovered)) {
            return colors.foregroundMuted.withValues(alpha: 0.65);
          }
          return colors.border.withValues(alpha: 0.65);
        }),
        trackColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        trackBorderColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        thickness: WidgetStateProperty.resolveWith<double>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged)) {
            return 6.0;
          }
          return 4.0;
        }),
        radius: const Radius.circular(8.0),
        crossAxisMargin: 2.0,
        mainAxisMargin: 2.0,
        interactive: true,
      ),
      extensions: <ThemeExtension<dynamic>>[this],
    );
  }

  @override
  UiTheme copyWith({
    UiColors? colors,
    UiTypography? typography,
    UiSpacing? spacing,
    UiRadii? radii,
    UiBorders? borders,
    UiShadows? shadows,
    UiMotion? motion,
    UiSizes? sizes,
    UiBreakpoints? breakpoints,
    UiScaleConfig? scaleConfig,
    Brightness? brightness,
    double? zoom,
  }) => UiTheme(
    colors: colors ?? this.colors,
    typography: typography ?? this.typography,
    spacing: spacing ?? this.spacing,
    radii: radii ?? this.radii,
    borders: borders ?? this.borders,
    shadows: shadows ?? this.shadows,
    motion: motion ?? this.motion,
    sizes: sizes ?? this.sizes,
    breakpoints: breakpoints ?? this.breakpoints,
    scaleConfig: scaleConfig ?? this.scaleConfig,
    brightness: brightness ?? this.brightness,
    zoom: zoom ?? this.zoom,
  );

  @override
  UiTheme lerp(ThemeExtension<UiTheme>? other, double t) {
    if (other is! UiTheme) return this;
    return copyWith(
      colors: colors.lerpTo(other.colors, t),
      brightness: t < 0.5 ? brightness : other.brightness,
      zoom: t < 0.5 ? zoom : other.zoom,
    );
  }
}

/// Provides [UiTheme] to the widget tree.
class UiThemeScope extends InheritedTheme {
  const UiThemeScope({super.key, required this.theme, required super.child});

  final UiTheme theme;

  /// Lets Flutter capture this scope when a dialog, menu, or bottom sheet is
  /// pushed onto a navigator overlay. This keeps local density overrides —
  /// such as the compact community scale — consistent in overlay content.
  @override
  Widget wrap(BuildContext context, Widget child) =>
      UiThemeScope(theme: theme, child: child);

  static UiTheme of(BuildContext context) {
    final UiThemeScope? scope = context
        .dependOnInheritedWidgetOfExactType<UiThemeScope>();
    if (scope != null) return scope.theme;
    final UiTheme? ext = Theme.of(context).extension<UiTheme>();
    if (ext != null) return ext;
    return Theme.of(context).brightness == Brightness.dark
        ? UiTheme.dark()
        : UiTheme.light();
  }

  @override
  bool updateShouldNotify(UiThemeScope oldWidget) => oldWidget.theme != theme;
}

/// One-stop app wrapper: theme + responsive metrics + Material theme sync.
class UiApp extends StatelessWidget {
  const UiApp({super.key, required this.theme, required this.builder});

  final UiTheme theme;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => UiThemeScope(
    theme: theme,
    child: Theme(
      data: theme.toThemeData(),
      child: Builder(builder: builder),
    ),
  );
}

/// Ergonomic access to tokens + responsive helpers from any widget.
extension UiThemeContext on BuildContext {
  UiTheme get ui => UiThemeScope.of(this);
  UiColors get uiColors => ui.colors;
  UiSpacing get uiSpace => ui.spacing;
  UiRadii get uiRadii => ui.radii;
  UiSizes get uiSizes => ui.sizes;
  UiMotion get uiMotion => ui.motion;
  UiShadows get uiShadows => ui.shadows;

  UiResponsive get uiRes {
    final theme = ui;
    return UiResponsive.of(
      this,
      breakpoints: theme.breakpoints,
      scaleConfig: theme.scaleConfig,
      zoom: theme.zoom,
    );
  }

  /// Device-scaled typography.
  ///
  /// Memoized: `scaled()` rebuilds nine [TextStyle]s, and a single page build
  /// reads `uiText` hundreds of times. The cache is keyed by the base
  /// typography identity plus the resolved factor, so a theme or text-size
  /// change still produces fresh styles.
  UiTypography get uiText {
    final UiTheme theme = ui;
    final UiResponsive r = uiRes;
    return _uiScaledTypography(theme.typography, r.scale.text);
  }

  double sp(double v) => uiRes.sp(v);
  double sz(double v) => uiRes.sz(v);

  /// Responsive size for a literal font value. Text widgets apply the current
  /// [TextScaler] after the viewport and zoom adjustments.
  double fs(double v) => uiRes.fs(v);

  BorderRadius radius(double v) => BorderRadius.circular(sz(v));

  /// Bottom padding a scrollable page should reserve so its last control clears
  /// whatever the shell floats over the content (a bottom dock, a home
  /// indicator, a rail shadow).
  ///
  /// The shell keeps the real system bottom inset on [MediaQuery] so [SafeArea]
  /// pages do not render an opaque dead band, while scrollable pages add the
  /// floating mobile dock clearance here.
  double get uiDockInset =>
      MediaQuery.paddingOf(this).bottom +
      (uiRes.isMobile ? 68.0 : 0.0) +
      sp(uiSpace.lg);

  /// [uiDockInset], or room for the keyboard when it is open.
  double get uiPageBottomInset {
    final double keyboard = MediaQuery.viewInsetsOf(this).bottom;
    if (keyboard > 0) return keyboard + sp(uiSpace.xl);
    return uiDockInset;
  }
}

/// Small identity+factor keyed cache backing [UiThemeContext.uiText].
///
/// An app realistically uses one base typography and a handful of scale
/// factors (one per device class × the reader's text-size setting), so a tiny
/// bounded map removes essentially all of the repeated [TextStyle] allocation
/// without ever going stale.
class _UiTypographyKey {
  const _UiTypographyKey(this.typographyId, this.factor);

  final int typographyId;
  final int factor;

  @override
  bool operator ==(Object other) =>
      other is _UiTypographyKey &&
      other.typographyId == typographyId &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(typographyId, factor);
}

final Map<_UiTypographyKey, UiTypography> _uiTypographyCache =
    <_UiTypographyKey, UiTypography>{};

UiTypography _uiScaledTypography(UiTypography base, double factor) {
  // Quantise to 1/1000 so float noise cannot fragment the cache.
  final _UiTypographyKey key = _UiTypographyKey(
    identityHashCode(base),
    (factor * 1000).round(),
  );
  final UiTypography? hit = _uiTypographyCache[key];
  if (hit != null) return hit;
  if (_uiTypographyCache.length > 32) _uiTypographyCache.clear();
  final UiTypography scaled = base.scaled(factor);
  _uiTypographyCache[key] = scaled;
  return scaled;
}
