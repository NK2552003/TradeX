import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';

/// alphajournal brand mark: a dark slate journal cover with page block,
/// bookmark ribbon, and luminous Greek alpha (α) glyph.
/// Painted in pure Dart so it scales, themes and animates with no asset latency.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({
    super.key,
    this.size,
    this.color,
    this.accentColor,
    this.progress = 1,
    this.rounded = false,
  });

  final double? size;
  final Color? color;
  final Color? accentColor;

  /// 0..1 draw-in progress, used by the animated splash mark.
  final double progress;

  /// Paints the mark inside a rounded surface tile.
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double dim = context.sz(size ?? 32);
    final Color base = color ?? const Color(0xFFFAF9F6);
    final Color accent = accentColor ?? const Color(0xFF8B9FE8);

    final Widget mark = CustomPaint(
      size: Size.square(dim),
      painter: _AppLogoPainter(
        base: base,
        accent: accent,
        progress: progress.clamp(0, 1),
      ),
    );

    if (!rounded) return mark;

    return Container(
      width: dim * 1.5,
      height: dim * 1.5,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: context.radius(theme.radii.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF1E1C1A), Color(0xFF0D0C0B)],
        ),
        border: Border.all(
          color: const Color(0xFFA8A29E).withValues(alpha: 0.28),
          width: theme.borders.hairline,
        ),
      ),
      child: mark,
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  _AppLogoPainter({
    required this.base,
    required this.accent,
    required this.progress,
  });

  final Color base;
  final Color accent;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return;

    final double coverAlpha = (progress * 1.8).clamp(0.0, 1.0);
    if (coverAlpha <= 0) return;

    // 1. Page block at bottom (cream pages peeking below the book cover).
    final RRect pageBlock = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.14, h * 0.72, w * 0.72, h * 0.18),
      bottomLeft: Radius.circular(w * 0.10),
      bottomRight: Radius.circular(w * 0.10),
      topLeft: Radius.circular(w * 0.04),
      topRight: Radius.circular(w * 0.04),
    );
    final Paint pagePaint = Paint()
      ..shader =
          ui.Gradient.linear(Offset(0, h * 0.72), Offset(0, h * 0.90), <Color>[
            const Color(0xFFF5F5F4).withValues(alpha: coverAlpha),
            const Color(0xFFD6D3D1).withValues(alpha: coverAlpha),
          ]);
    canvas.drawRRect(pageBlock, pagePaint);

    // 2. Bookmark ribbon hanging from bottom-right of pages.
    if (progress > 0.25) {
      final double ribbonT = ((progress - 0.25) / 0.45).clamp(0.0, 1.0);
      final double ribbonBottom = h * (0.78 + 0.18 * ribbonT);
      final Path ribbon = Path()
        ..moveTo(w * 0.61, h * 0.78)
        ..lineTo(w * 0.73, h * 0.78)
        ..lineTo(w * 0.73, ribbonBottom)
        ..lineTo(w * 0.67, ribbonBottom - h * 0.04 * ribbonT)
        ..lineTo(w * 0.61, ribbonBottom)
        ..close();
      final Paint ribbonPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(w * 0.61, h * 0.78),
          Offset(w * 0.73, ribbonBottom),
          <Color>[
            accent.withValues(alpha: ribbonT),
            const Color(0xFF4F63C4).withValues(alpha: ribbonT),
          ],
        );
      canvas.drawPath(ribbon, ribbonPaint);
    }

    // 3. Dark slate journal cover with spine crease.
    final RRect coverRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.12, h * 0.08, w * 0.76, h * 0.70),
      topLeft: Radius.circular(w * 0.09),
      bottomLeft: Radius.circular(w * 0.09),
      topRight: Radius.circular(w * 0.15),
      bottomRight: Radius.circular(w * 0.15),
    );
    final Paint coverPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.12, h * 0.08),
        Offset(w * 0.88, h * 0.78),
        <Color>[
          const Color(0xFF3A3734).withValues(alpha: coverAlpha),
          const Color(0xFF22201E).withValues(alpha: coverAlpha),
          const Color(0xFF151312).withValues(alpha: coverAlpha),
        ],
        const <double>[0.0, 0.55, 1.0],
      );
    canvas.drawRRect(coverRect, coverPaint);

    // Subtle cover rim & spine highlight.
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, w * 0.025)
      ..color = const Color(0xFFA8A29E).withValues(alpha: 0.35 * coverAlpha);
    canvas.drawRRect(coverRect, rimPaint);

    final Paint spineCrease = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, w * 0.02)
      ..color = const Color(0xFF090807).withValues(alpha: 0.65 * coverAlpha);
    canvas.drawLine(
      Offset(w * 0.23, h * 0.09),
      Offset(w * 0.23, h * 0.77),
      spineCrease,
    );

    // 4. Luminous Greek Alpha (α) glyph on the cover.
    final Path alphaGlyph = Path()
      // Start at top-right of alpha, sweep down-left around the loop, then cross to bottom-right tail.
      ..moveTo(w * 0.69, h * 0.29)
      ..cubicTo(w * 0.61, h * 0.45, w * 0.54, h * 0.57, w * 0.44, h * 0.57)
      ..cubicTo(w * 0.33, h * 0.57, w * 0.30, h * 0.48, w * 0.30, h * 0.42)
      ..cubicTo(w * 0.30, h * 0.35, w * 0.35, h * 0.28, w * 0.45, h * 0.28)
      ..cubicTo(w * 0.55, h * 0.28, w * 0.60, h * 0.38, w * 0.64, h * 0.48)
      ..cubicTo(w * 0.67, h * 0.54, w * 0.70, h * 0.57, w * 0.75, h * 0.56);

    final List<ui.PathMetric> metricsList = alphaGlyph
        .computeMetrics()
        .toList();
    if (metricsList.isNotEmpty) {
      final ui.PathMetric metric = metricsList.first;
      final Path drawn = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = math.max(1.6, w * 0.082)
          ..color = base,
      );
    }
  }

  @override
  bool shouldRepaint(_AppLogoPainter old) =>
      old.progress != progress || old.base != base || old.accent != accent;
}

/// Wordmark: "alpha" in foreground, "journal" in the brand color.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.fontSize, this.color, this.accentColor});

  final double? fontSize;
  final Color? color;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = context.uiText.title.copyWith(
      fontSize: fontSize ?? context.uiText.heading.fontSize,
      letterSpacing: -0.4,
      color: color ?? context.uiColors.foreground,
      fontWeight: FontWeight.w700,
    );
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: <TextSpan>[
          const TextSpan(text: 'Alpha'),
          TextSpan(
            text: 'Journal',
            style: style.copyWith(
              color: accentColor ?? context.uiColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mark + wordmark lockup. Collapses to the mark only when [compact].
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.compact = false,
    this.size,
    this.stacked = false,
    this.tagline,
    this.markRounded = false,
  });

  final bool compact;
  final double? size;
  final bool stacked;
  final String? tagline;
  final bool markRounded;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Widget mark = AppLogoMark(size: size, rounded: markRounded);
    if (compact) return mark;

    final Widget text = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppWordmark(fontSize: size == null ? null : context.sz(size! * 0.7)),
        if (tagline != null)
          Text(
            tagline!,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
      ],
    );

    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          mark,
          SizedBox(height: context.sp(theme.spacing.sm)),
          text,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        mark,
        SizedBox(width: context.sp(theme.spacing.sm)),
        Flexible(child: text),
      ],
    );
  }
}

/// Animated launch mark: the arc draws itself in, then the wordmark fades up.
class AppSplashMark extends StatefulWidget {
  const AppSplashMark({super.key, this.size = 64, this.tagline});

  final double size;
  final String? tagline;

  @override
  State<AppSplashMark> createState() => _AppSplashMarkState();
}

class _AppSplashMarkState extends State<AppSplashMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double draw = Curves.easeInOutCubic.transform(
          (_controller.value / 0.7).clamp(0, 1),
        );
        final double textIn = Curves.easeOutCubic.transform(
          ((_controller.value - 0.55) / 0.45).clamp(0, 1),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppLogoMark(size: widget.size, progress: draw),
            SizedBox(height: context.sp(theme.spacing.lg)),
            Opacity(
              opacity: textIn,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - textIn)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppWordmark(fontSize: context.sz(widget.size * 0.5)),
                    if (widget.tagline != null) ...<Widget>[
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      Text(
                        widget.tagline!,
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
