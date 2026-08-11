import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// 3-Column Social Authentication Buttons (Apple, Google, Meta) using TraderHub design tokens.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    this.onApplePressed,
    this.onGooglePressed,
    this.onMetaPressed,
    this.actionLabelPrefix = 'Continue with',
  });

  final VoidCallback? onApplePressed;
  final VoidCallback? onGooglePressed;
  final VoidCallback? onMetaPressed;
  final String actionLabelPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return UiButton(
      label: '$actionLabelPrefix Google',
      variant: UiVariant.outline,
      intent: UiIntent.neutral,
      onPressed: onGooglePressed ?? () => _showSocialToast(context, 'Google'),
      leading: SizedBox(
        height: context.sz(18),
        width: context.sz(18),
        child: CustomPaint(
          painter: _GoogleLogoPainter(),
        ),
      ),
    );
  }

  void _showSocialToast(BuildContext context, String provider) {
    UiToast.show(
      context,
      title: '$provider Authentication',
      message: '$actionLabelPrefix $provider initiated',
      intent: UiIntent.primary,
    );
  }
}

class _AppleLogoPainter extends CustomPainter {
  _AppleLogoPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Apple Leaf
    path.moveTo(w * 0.68, h * 0.16);
    path.cubicTo(w * 0.72, h * 0.11, w * 0.75, h * 0.04, w * 0.74, 0);
    path.close();

    // Apple Body
    path.moveTo(w * 0.75, h * 0.45);
    path.cubicTo(w * 0.75, h * 0.35, w * 0.83, h * 0.3, w * 0.78, h * 0.23);
    path.cubicTo(w * 0.54, h * 0.21, w * 0.47, h * 0.26, w * 0.42, h * 0.26);
    path.cubicTo(w * 0.15, h * 0.22, w * 0.07, h * 0.27, -0.07, h * 0.51);
    path.cubicTo(0.17, h * 0.92, 0.22, h * 0.99, 0.29, h * 0.99);
    path.cubicTo(0.55, h * 0.94, 0.58, h * 0.99, 0.65, h * 0.99);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AppleLogoPainter oldDelegate) => oldDelegate.color != color;
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    final bluePaint = Paint()..color = const Color(0xFF4285F4);

    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, -0.6, 1.8, true, redPaint);
    canvas.drawArc(rect, 1.2, 1.2, true, yellowPaint);
    canvas.drawArc(rect, 2.4, 1.2, true, greenPaint);
    canvas.drawArc(rect, 3.6, 1.2, true, bluePaint);

    final innerCutout = Paint()..color = const Color(0xFF18181B);
    canvas.drawCircle(center, radius * 0.6, innerCutout);

    final barRect = Rect.fromLTRB(w * 0.45, h * 0.4, w * 0.95, h * 0.6);
    canvas.drawRect(barRect, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetaLogoPainter extends CustomPainter {
  _MetaLogoPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.15, h * 0.6);
    path.cubicTo(w * 0.05, h * 0.35, w * 0.35, h * 0.15, w * 0.5, h * 0.5);
    path.cubicTo(w * 0.65, h * 0.85, w * 0.95, h * 0.65, w * 0.85, h * 0.4);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MetaLogoPainter oldDelegate) => oldDelegate.color != color;
}
