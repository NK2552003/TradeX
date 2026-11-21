import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

class UiDonutSlice {
  const UiDonutSlice({required this.label, required this.value, this.color});

  final String label;
  final double value;
  final Color? color;
}

typedef DonutSlice = UiDonutSlice;

/// Donut / pie chart with optional center content and responsive legend
/// placement (below on phones, beside on wide screens).
class UiDonutChart extends StatelessWidget {
  const UiDonutChart({
    super.key,
    required this.slices,
    this.size,
    this.thickness,
    this.center,
    this.centerLabel,
    this.showLegend = false,
    this.valueFormatter,
  });

  final List<UiDonutSlice> slices;
  final double? size;
  final double? thickness;
  final Widget? center;
  final String? centerLabel;
  final bool showLegend;
  final UiValueFormatter? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final double defaultDim = context.sz(size ?? 180);
    final double total = slices.fold<double>(
      0,
      (double a, UiDonutSlice s) => a + s.value,
    );
    final List<Color> colors = <Color>[
      for (int i = 0; i < slices.length; i++)
        slices[i].color ?? theme.colors.series[i % theme.colors.series.length],
    ];

    Widget? centerWidget = center;
    if (centerWidget == null && centerLabel != null) {
      centerWidget = Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
        child: Text(
          centerLabel!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.uiText.subheading.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colors.foreground,
          ),
        ),
      );
    }

    Widget buildDonut(double dim) => RepaintBoundary(
      child: SizedBox(
        width: dim,
        height: dim,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: Size.square(dim),
              painter: _DonutPainter(
                values: slices.map((UiDonutSlice s) => s.value).toList(),
                colors: colors,
                trackColor: theme.colors.surfaceMuted,
                thickness: context.sz(thickness ?? 22),
                gap: 0.02,
              ),
            ),
            ?centerWidget,
          ],
        ),
      ),
    );

    final Widget legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < slices.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: context.sz(8),
                  height: context.sz(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors[i],
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  child: Text(
                    slices[i].label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Flexible(
                  child: Text(
                    total == 0
                        ? '0%'
                        : '${(slices[i].value / total * 100).toStringAsFixed(1)}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: context.uiText.numeric.copyWith(
                      color: theme.colors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxAvailable = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;
        final double dim = math.min(
          defaultDim,
          maxAvailable > 40 ? maxAvailable - 16 : defaultDim,
        );
        final Widget donut = buildDonut(dim);

        if (!showLegend) return Center(child: donut);

        final bool isCompact =
            constraints.maxWidth < defaultDim + context.sz(240) ||
            context.uiRes.isMobile;
        if (isCompact) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              donut,
              SizedBox(height: context.sp(theme.spacing.md)),
              legend,
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            donut,
            SizedBox(width: context.sp(theme.spacing.md)),
            Flexible(child: legend),
          ],
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
    required this.thickness,
    required this.gap,
  });

  final List<double> values;
  final List<Color> colors;
  final Color trackColor;
  final double thickness;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect =
        Offset(thickness / 2, thickness / 2) &
        Size(size.width - thickness, size.height - thickness);
    final double total = values.fold<double>(0, (double a, double b) => a + b);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness,
    );
    if (total <= 0) return;
    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final double sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0, sweep - gap),
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = thickness,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.colors != colors;
}
