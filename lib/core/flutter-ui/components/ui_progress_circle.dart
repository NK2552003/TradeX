import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Circular progress ring with centered content, or indeterminate spinner when value is null.
class UiProgressCircle extends StatelessWidget {
  const UiProgressCircle({
    super.key,
    this.value,
    this.size,
    this.thickness,
    this.intent = UiIntent.primary,
    this.center,
    this.showLabel = true,
  });

  final double? value;
  final double? size;
  final double? thickness;
  final UiIntent intent;
  final Widget? center;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final double dim = context.sz(size ?? 96);
    final double actualThickness = context.sz(thickness ?? theme.sizes.trackThickness);

    if (value == null) {
      return SizedBox(
        width: dim,
        height: dim,
        child: CircularProgressIndicator(
          strokeWidth: actualThickness,
          color: intent.color(context),
          backgroundColor: theme.colors.surfaceMuted,
        ),
      );
    }

    final double safeValue = value!.clamp(0, 1);
    final bool canShowLabel = showLabel && dim >= 40;
    return SizedBox(
      width: dim,
      height: dim,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size.square(dim),
            painter: _RingPainter(
              value: safeValue,
              activeColor: intent.color(context),
              trackColor: theme.colors.surfaceMuted,
              thickness: actualThickness,
            ),
          ),
          if (center != null)
            center!
          else if (canShowLabel)
            Text(
              '${(safeValue * 100).toStringAsFixed(0)}%',
              style: context.uiText.bodyStrong.copyWith(
                color: theme.colors.foreground,
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.activeColor,
    required this.trackColor,
    required this.thickness,
  });

  final double value;
  final Color activeColor;
  final Color trackColor;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect =
        Offset(thickness / 2, thickness / 2) &
        Size(size.width - thickness, size.height - thickness);
    final Paint track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    final Paint active = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = thickness;
    canvas.drawArc(rect, 0, 6.28318, false, track);
    canvas.drawArc(rect, -1.5708, 6.28318 * value, false, active);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.activeColor != activeColor ||
      old.trackColor != trackColor ||
      old.thickness != thickness;
}
