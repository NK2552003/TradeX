import 'package:flutter/material.dart';

/// Clean, official 4-color Google 'G' brand mark vector painted with exact
/// cubic bezier paths. Scales cleanly to any size with no rasterization artifacts.
class GoogleLogoMark extends StatelessWidget {
  const GoogleLogoMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);

    final paint = Paint()..isAntiAlias = true;

    // 1. Blue (#4285F4)
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(23.49, 12.275)
      ..cubicTo(23.49, 11.423, 23.414, 10.604, 23.272, 9.82)
      ..lineTo(12, 9.82)
      ..lineTo(12, 14.461)
      ..lineTo(18.442, 14.461)
      ..cubicTo(18.164, 15.959, 17.319, 17.229, 16.048, 18.08)
      ..lineTo(16.048, 21.089)
      ..lineTo(19.926, 21.089)
      ..cubicTo(22.195, 19, 23.49, 15.923, 23.49, 12.275)
      ..close();
    canvas.drawPath(bluePath, paint);

    // 2. Green (#34A853)
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(12, 24)
      ..cubicTo(15.24, 24, 17.957, 22.926, 19.942, 21.089)
      ..lineTo(16.064, 18.08)
      ..cubicTo(14.989, 18.8, 13.613, 19.225, 12, 19.225)
      ..cubicTo(8.875, 19.225, 6.229, 17.115, 5.284, 14.278)
      ..lineTo(1.256, 14.278)
      ..lineTo(1.256, 17.387)
      ..cubicTo(3.237, 21.284, 7.309, 24, 12, 24)
      ..close();
    canvas.drawPath(greenPath, paint);

    // 3. Yellow (#FBBC05)
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(5.284, 14.278)
      ..cubicTo(5.043, 13.558, 4.905, 12.788, 4.905, 12)
      ..cubicTo(4.905, 11.212, 5.043, 10.442, 5.284, 9.722)
      ..lineTo(5.284, 6.613)
      ..lineTo(1.256, 6.613)
      ..cubicTo(0.456, 8.204, 0, 9.99, 0, 12)
      ..cubicTo(0, 14.01, 0.456, 15.796, 1.256, 17.387)
      ..lineTo(5.284, 14.278)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // 4. Red (#EA4335)
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(12, 4.75)
      ..cubicTo(13.762, 4.75, 15.344, 5.356, 16.587, 6.545)
      ..lineTo(20.027, 3.105)
      ..cubicTo(17.952, 1.19, 15.235, 0, 12, 0)
      ..cubicTo(7.309, 0, 3.237, 2.716, 1.256, 6.613)
      ..lineTo(5.284, 9.722)
      ..cubicTo(6.229, 6.885, 8.875, 4.75, 12, 4.75)
      ..close();
    canvas.drawPath(redPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
