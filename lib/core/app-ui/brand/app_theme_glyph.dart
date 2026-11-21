import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pure-Dart vector sun / crescent-moon glyph for header theme toggles.
///
/// Painted directly via [CustomPaint] so the theme toggle never disappears due
/// to web font tree-shaking or stale browser font caches across deployments.
class AppThemeGlyph extends StatelessWidget {
  const AppThemeGlyph({
    super.key,
    required this.isDark,
    this.size = 18,
    this.color,
  });

  /// When `true` (dark mode active), renders a sun to switch to light mode.
  /// When `false` (light mode active), renders a crescent moon to switch to dark mode.
  final bool isDark;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor =
        color ?? IconTheme.of(context).color ?? const Color(0xFFFFFFFF);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _AppThemeGlyphPainter(
          isDark: isDark,
          color: effectiveColor,
        ),
      ),
    );
  }
}

class _AppThemeGlyphPainter extends CustomPainter {
  const _AppThemeGlyphPainter({required this.isDark, required this.color});

  final bool isDark;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double side = math.min(size.width, size.height);
    if (side <= 0) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = side / 2;

    if (isDark) {
      // Sun glyph (switch to light theme)
      final Paint fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawCircle(center, radius * 0.42, fillPaint);

      final Paint rayPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, side * 0.105)
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      const int rayCount = 8;
      final double inner = radius * 0.68;
      final double outer = radius * 0.92;
      for (int i = 0; i < rayCount; i++) {
        final double angle = (i * math.pi * 2) / rayCount;
        final double cosA = math.cos(angle);
        final double sinA = math.sin(angle);
        canvas.drawLine(
          Offset(center.dx + cosA * inner, center.dy + sinA * inner),
          Offset(center.dx + cosA * outer, center.dy + sinA * outer),
          rayPaint,
        );
      }
      return;
    }

    // Crescent moon glyph (switch to dark theme) built from two pure circular arcs.
    final double scale = side / 24.0;
    final double ox = (size.width - side) / 2;
    final double oy = (size.height - side) / 2;
    Offset pt(double x, double y) => Offset(ox + x * scale, oy + y * scale);

    final Path moonPath = Path()
      ..moveTo(pt(14.20, 3.79).dx, pt(14.20, 3.79).dy)
      ..arcToPoint(
        pt(19.70, 15.59),
        radius: Radius.circular(8.5 * scale),
        largeArc: true,
        clockwise: false,
      )
      ..arcToPoint(
        pt(14.20, 3.79),
        radius: Radius.circular(7.2 * scale),
        largeArc: false,
        clockwise: true,
      )
      ..close();

    final Paint moonPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(moonPath, moonPaint);
  }

  @override
  bool shouldRepaint(covariant _AppThemeGlyphPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.color != color;
  }
}
