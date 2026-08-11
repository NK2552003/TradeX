import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Soft, code-drawn gradient backdrop shared by every auth screen.
///
/// No image or SVG assets — two blurred radial "aurora" blooms sit behind
/// a faint grid, tinted from the live theme so it always matches dark/light
/// mode and the app's primary/bullish accent colors.
class AuthBackground extends StatelessWidget {
  const AuthBackground({
    super.key,
    required this.child,
    this.showGrid = true,
  });

  final Widget child;
  final bool showGrid;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return Container(
      color: colors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Primary bloom — top-left.
          Positioned(
            top: context.sz(-160),
            left: context.sz(-120),
            child: _Bloom(
              size: context.sz(460),
              color: colors.primary.withValues(alpha: 0.16),
            ),
          ),
          // Secondary bloom — bottom-right, tinted with the bullish accent
          // so the backdrop nods at "growth" without being literal.
          Positioned(
            bottom: context.sz(-180),
            right: context.sz(-140),
            child: _Bloom(
              size: context.sz(520),
              color: colors.bullish.withValues(alpha: 0.10),
            ),
          ),
          if (showGrid)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DotGridPainter(
                    color: colors.foregroundSubtle.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});

  final Color color;

  static const double _gap = 28;
  static const double _dotRadius = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = 0; y < size.height; y += _gap) {
      for (double x = 0; x < size.width; x += _gap) {
        canvas.drawCircle(Offset(x, y), _dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}
