import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Soft, code-drawn gradient backdrop shared by every auth screen.
///
/// No image or SVG assets — two blurred radial "aurora" blooms sit behind
/// a faint, gently pulsating grid, tinted from the live theme so it always
/// matches dark/light mode and the app's primary/bullish accent colors.
class AuthBackground extends StatefulWidget {
  const AuthBackground({super.key, required this.child, this.showGrid = true});

  final Widget child;
  final bool showGrid;

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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
          if (widget.showGrid)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    // Ease in/out rather than a linear pulse.
                    final t = Curves.easeInOut.transform(
                      _pulseController.value,
                    );
                    return CustomPaint(
                      size: Size.infinite,
                      painter: _DotGridPainter(
                        color: colors.foregroundSubtle,
                        pulse: t,
                      ),
                    );
                  },
                ),
              ),
            ),
          widget.child,
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
  const _DotGridPainter({required this.color, required this.pulse});

  final Color color;

  /// 0..1 animation progress, already eased.
  final double pulse;

  static const double _gap = 28;
  static const double _minRadius = 0.6;
  static const double _maxRadius = 1.6;
  static const double _minAlpha = 0.03;
  static const double _maxAlpha = 0.08;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = _minAlpha + (_maxAlpha - _minAlpha) * pulse;
    final radius = _minRadius + (_maxRadius - _minRadius) * pulse;
    final paint = Paint()..color = color.withValues(alpha: alpha);

    for (double y = 0; y < size.height; y += _gap) {
      for (double x = 0; x < size.width; x += _gap) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pulse != pulse;
}
