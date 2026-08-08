import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// SINGLE SOURCE OF TRUTH FOR THE DESIGN SYSTEM
///
/// Change values here only. No component file contains a hardcoded color,
/// radius, font size, spacing or duration.
/// ---------------------------------------------------------------------------

/// Raw brand palette. Only referenced by [UiColors] factories below.
class UiPalette {
  const UiPalette._();

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
  static const Color gray950 = Color(0xFF030712);

  // Brand (trading community blue)
  static const Color brand400 = Color(0xFF60A5FA);
  static const Color brand500 = Color(0xFF3B82F6);
  static const Color brand600 = Color(0xFF2563EB);
  static const Color brand700 = Color(0xFF1D4ED8);

  // Market semantics
  static const Color bullish500 = Color(0xFF16A34A);
  static const Color bullish400 = Color(0xFF22C55E);
  static const Color bearish500 = Color(0xFFDC2626);
  static const Color bearish400 = Color(0xFFEF4444);
  static const Color warning500 = Color(0xFFF59E0B);
  static const Color info500 = Color(0xFF0EA5E9);

  // Chart series
  static const List<Color> series = <Color>[
    brand500,
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF97316),
    Color(0xFF06B6D4),
  ];
}

/// Semantic colors consumed by every component.
@immutable
class UiColors {
  const UiColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceHover,
    required this.overlay,
    required this.border,
    required this.borderStrong,
    required this.foreground,
    required this.foregroundMuted,
    required this.foregroundSubtle,
    required this.primary,
    required this.primaryHover,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.bullish,
    required this.bearish,
    required this.warning,
    required this.info,
    required this.destructive,
    required this.onDestructive,
    required this.focusRing,
    required this.disabledBackground,
    required this.disabledForeground,
    required this.series,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceHover;
  final Color overlay;
  final Color border;
  final Color borderStrong;
  final Color foreground;
  final Color foregroundMuted;
  final Color foregroundSubtle;
  final Color primary;
  final Color primaryHover;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color bullish;
  final Color bearish;
  final Color warning;
  final Color info;
  final Color destructive;
  final Color onDestructive;
  final Color focusRing;
  final Color disabledBackground;
  final Color disabledForeground;
  final List<Color> series;

  factory UiColors.light() => const UiColors(
        background: UiPalette.white,
        surface: UiPalette.white,
        surfaceMuted: UiPalette.gray50,
        surfaceHover: UiPalette.gray100,
        overlay: Color(0x99111827),
        border: UiPalette.gray200,
        borderStrong: UiPalette.gray300,
        foreground: UiPalette.gray900,
        foregroundMuted: UiPalette.gray600,
        foregroundSubtle: UiPalette.gray400,
        primary: UiPalette.brand600,
        primaryHover: UiPalette.brand700,
        onPrimary: UiPalette.white,
        secondary: UiPalette.gray100,
        onSecondary: UiPalette.gray900,
        bullish: UiPalette.bullish500,
        bearish: UiPalette.bearish500,
        warning: UiPalette.warning500,
        info: UiPalette.info500,
        destructive: UiPalette.bearish500,
        onDestructive: UiPalette.white,
        focusRing: UiPalette.brand400,
        disabledBackground: UiPalette.gray100,
        disabledForeground: UiPalette.gray400,
        series: UiPalette.series,
      );

  factory UiColors.dark() => const UiColors(
        background: UiPalette.gray950,
        surface: UiPalette.gray900,
        surfaceMuted: UiPalette.gray800,
        surfaceHover: UiPalette.gray800,
        overlay: Color(0xCC030712),
        border: Color(0xFF1F2937),
        borderStrong: UiPalette.gray700,
        foreground: UiPalette.gray50,
        foregroundMuted: UiPalette.gray400,
        foregroundSubtle: UiPalette.gray500,
        primary: UiPalette.brand500,
        primaryHover: UiPalette.brand400,
        onPrimary: UiPalette.white,
        secondary: UiPalette.gray800,
        onSecondary: UiPalette.gray50,
        bullish: UiPalette.bullish400,
        bearish: UiPalette.bearish400,
        warning: UiPalette.warning500,
        info: UiPalette.info500,
        destructive: UiPalette.bearish400,
        onDestructive: UiPalette.white,
        focusRing: UiPalette.brand400,
        disabledBackground: UiPalette.gray800,
        disabledForeground: UiPalette.gray600,
        series: UiPalette.series,
      );

  UiColors lerpTo(UiColors other, double t) => UiColors(
        background: Color.lerp(background, other.background, t)!,
        surface: Color.lerp(surface, other.surface, t)!,
        surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
        surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
        overlay: Color.lerp(overlay, other.overlay, t)!,
        border: Color.lerp(border, other.border, t)!,
        borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
        foreground: Color.lerp(foreground, other.foreground, t)!,
        foregroundMuted: Color.lerp(foregroundMuted, other.foregroundMuted, t)!,
        foregroundSubtle:
            Color.lerp(foregroundSubtle, other.foregroundSubtle, t)!,
        primary: Color.lerp(primary, other.primary, t)!,
        primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
        onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
        secondary: Color.lerp(secondary, other.secondary, t)!,
        onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
        bullish: Color.lerp(bullish, other.bullish, t)!,
        bearish: Color.lerp(bearish, other.bearish, t)!,
        warning: Color.lerp(warning, other.warning, t)!,
        info: Color.lerp(info, other.info, t)!,
        destructive: Color.lerp(destructive, other.destructive, t)!,
        onDestructive: Color.lerp(onDestructive, other.onDestructive, t)!,
        focusRing: Color.lerp(focusRing, other.focusRing, t)!,
        disabledBackground:
            Color.lerp(disabledBackground, other.disabledBackground, t)!,
        disabledForeground:
            Color.lerp(disabledForeground, other.disabledForeground, t)!,
        series: t < 0.5 ? series : other.series,
      );
}

/// Spacing scale (logical px, later scaled by device).
@immutable
class UiSpacing {
  const UiSpacing({
    this.none = 0,
    this.xxs = 2,
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.xxl = 32,
    this.xxxl = 48,
  });

  final double none;
  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;
}

@immutable
class UiRadii {
  const UiRadii({
    this.none = 0,
    this.sm = 4,
    this.md = 6,
    this.lg = 10,
    this.xl = 14,
    this.xxl = 20,
    this.pill = 999,
  });

  final double none;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double pill;
}

@immutable
class UiBorders {
  const UiBorders({this.hairline = 1, this.thick = 1.5, this.focus = 2});

  final double hairline;
  final double thick;
  final double focus;
}

@immutable
class UiTypography {
  const UiTypography({
    required this.fontFamily,
    required this.monoFontFamily,
    required this.display,
    required this.title,
    required this.heading,
    required this.subheading,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.caption,
    required this.numeric,
  });

  final String? fontFamily;
  final String? monoFontFamily;
  final TextStyle display;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle subheading;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle numeric;

  factory UiTypography.standard({
    String? fontFamily,
    String? monoFontFamily,
  }) {
    TextStyle base(double size, FontWeight weight, double height) => TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          height: height,
        );
    return UiTypography(
      fontFamily: fontFamily,
      monoFontFamily: monoFontFamily,
      display: base(32, FontWeight.w700, 1.15),
      title: base(24, FontWeight.w700, 1.2),
      heading: base(18, FontWeight.w600, 1.25),
      subheading: base(16, FontWeight.w600, 1.3),
      body: base(14, FontWeight.w400, 1.45),
      bodyStrong: base(14, FontWeight.w600, 1.45),
      label: base(13, FontWeight.w500, 1.3),
      caption: base(12, FontWeight.w400, 1.35),
      numeric: TextStyle(
        fontFamily: monoFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }

  UiTypography scaled(double factor) => UiTypography(
        fontFamily: fontFamily,
        monoFontFamily: monoFontFamily,
        display: _s(display, factor),
        title: _s(title, factor),
        heading: _s(heading, factor),
        subheading: _s(subheading, factor),
        body: _s(body, factor),
        bodyStrong: _s(bodyStrong, factor),
        label: _s(label, factor),
        caption: _s(caption, factor),
        numeric: _s(numeric, factor),
      );

  static TextStyle _s(TextStyle style, double f) =>
      style.copyWith(fontSize: (style.fontSize ?? 14) * f);
}

@immutable
class UiShadows {
  const UiShadows({required this.sm, required this.md, required this.lg});

  final List<BoxShadow> sm;
  final List<BoxShadow> md;
  final List<BoxShadow> lg;

  factory UiShadows.light() => const UiShadows(
        sm: <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
        md: <BoxShadow>[
          BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
        lg: <BoxShadow>[
          BoxShadow(color: Color(0x24000000), blurRadius: 28, offset: Offset(0, 12)),
        ],
      );

  factory UiShadows.dark() => const UiShadows(
        sm: <BoxShadow>[
          BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
        md: <BoxShadow>[
          BoxShadow(color: Color(0x59000000), blurRadius: 14, offset: Offset(0, 6)),
        ],
        lg: <BoxShadow>[
          BoxShadow(color: Color(0x73000000), blurRadius: 32, offset: Offset(0, 14)),
        ],
      );
}

@immutable
class UiMotion {
  const UiMotion({
    this.fast = const Duration(milliseconds: 120),
    this.normal = const Duration(milliseconds: 200),
    this.slow = const Duration(milliseconds: 320),
    this.curve = Curves.easeOutCubic,
  });

  final Duration fast;
  final Duration normal;
  final Duration slow;
  final Curve curve;
}

/// Control metrics: every interactive component derives its size from here.
@immutable
class UiSizes {
  const UiSizes({
    this.controlHeightSm = 32,
    this.controlHeightMd = 40,
    this.controlHeightLg = 48,
    this.iconSm = 14,
    this.iconMd = 18,
    this.iconLg = 22,
    this.avatarSm = 28,
    this.avatarMd = 40,
    this.avatarLg = 56,
    this.checkbox = 18,
    this.radio = 18,
    this.switchWidth = 40,
    this.switchHeight = 22,
    this.trackThickness = 8,
    this.chartHeight = 220,
    this.sparkHeight = 48,
    this.minTapTarget = 44,
    this.maxContentWidth = 1200,
  });

  final double controlHeightSm;
  final double controlHeightMd;
  final double controlHeightLg;
  final double iconSm;
  final double iconMd;
  final double iconLg;
  final double avatarSm;
  final double avatarMd;
  final double avatarLg;
  final double checkbox;
  final double radio;
  final double switchWidth;
  final double switchHeight;
  final double trackThickness;
  final double chartHeight;
  final double sparkHeight;
  final double minTapTarget;
  final double maxContentWidth;
}
