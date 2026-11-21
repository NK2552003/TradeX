import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// One bar of a [UiWaterfallChart].
@immutable
class UiWaterfallStep {
  const UiWaterfallStep({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.color,
  });

  final String label;

  /// Signed delta applied to the running total, or the absolute figure when
  /// [isTotal] is set.
  final double value;

  /// Anchors the bar to zero and resets the running total — opening balances,
  /// subtotals and final results.
  final bool isTotal;
  final Color? color;
}

/// Bridge chart: how a starting figure becomes an ending figure, one signed
/// contribution at a time.
///
/// This is the shape a cost or tax breakdown actually has — gross, minus each
/// charge, equals net — and a stacked bar or pie cannot show it, because
/// neither expresses subtraction. Bars sit at their running-total height and
/// hairline connectors carry the eye from each bar's close to the next bar's
/// open.
class UiWaterfallChart extends StatelessWidget {
  const UiWaterfallChart({
    super.key,
    required this.steps,
    this.height,
    this.valueFormatter,
    this.showLabels = true,
  });

  final List<UiWaterfallStep> steps;
  final double? height;
  final UiValueFormatter? valueFormatter;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final theme = context.ui;
    final c = theme.colors;
    final UiValueFormatter fmt = valueFormatter ?? uiCompactNumber;

    // Resolve each bar's open/close from the running total.
    final List<double> opens = <double>[];
    final List<double> closes = <double>[];
    double running = 0;
    for (final UiWaterfallStep s in steps) {
      if (s.isTotal) {
        opens.add(0);
        closes.add(s.value);
        running = s.value;
      } else {
        opens.add(running);
        running += s.value;
        closes.add(running);
      }
    }

    double lo = 0;
    double hi = 0;
    for (int i = 0; i < steps.length; i++) {
      lo = <double>[
        lo,
        opens[i],
        closes[i],
      ].reduce((double a, double b) => a < b ? a : b);
      hi = <double>[
        hi,
        opens[i],
        closes[i],
      ].reduce((double a, double b) => a > b ? a : b);
    }
    if (hi - lo < 1e-9) hi = lo + 1;

    final List<Color> colors = <Color>[
      for (int i = 0; i < steps.length; i++)
        steps[i].color ??
            (steps[i].isTotal
                ? c.primary
                : (steps[i].value >= 0 ? c.bullish : c.bearish)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: context.sz(height ?? 132),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _WaterfallPainter(
                opens: opens,
                closes: closes,
                colors: colors,
                isTotal: steps.map((UiWaterfallStep s) => s.isTotal).toList(),
                lo: lo,
                hi: hi,
                connector: c.borderStrong,
                baseline: c.border,
                radius: context.sz(theme.radii.sm) / 2,
              ),
            ),
          ),
        ),
        if (showLabels) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xs)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < steps.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.xxs),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          fmt(steps[i].value),
                          textAlign: TextAlign.center,
                          style: context.uiText.caption.copyWith(
                            color: colors[i],
                            fontWeight: FontWeight.w600,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          steps[i].label,
                          textAlign: TextAlign.center,
                          style: context.uiText.caption.copyWith(
                            color: c.foregroundSubtle,
                            fontSize: context.fs(10),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _WaterfallPainter extends CustomPainter {
  const _WaterfallPainter({
    required this.opens,
    required this.closes,
    required this.colors,
    required this.isTotal,
    required this.lo,
    required this.hi,
    required this.connector,
    required this.baseline,
    required this.radius,
  });

  final List<double> opens;
  final List<double> closes;
  final List<Color> colors;
  final List<bool> isTotal;
  final double lo;
  final double hi;
  final Color connector;
  final Color baseline;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final int n = opens.length;
    if (n == 0 || size.width <= 0 || size.height <= 0) return;
    final double slot = size.width / n;
    final double barW = (slot * 0.58).clamp(2.0, slot);
    double y(double v) => size.height * (1 - (v - lo) / (hi - lo));

    if (lo < 0 && hi > 0) {
      canvas.drawLine(
        Offset(0, y(0)),
        Offset(size.width, y(0)),
        Paint()
          ..color = baseline
          ..strokeWidth = 1,
      );
    }

    final Paint link = Paint()
      ..color = connector.withValues(alpha: 0.6)
      ..strokeWidth = 1;

    for (int i = 0; i < n; i++) {
      final double cx = slot * i + slot / 2;
      final double top = y(opens[i] > closes[i] ? opens[i] : closes[i]);
      final double bottom = y(opens[i] > closes[i] ? closes[i] : opens[i]);
      final double h = (bottom - top).abs().clamp(1.5, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barW / 2, top, barW, h),
          Radius.circular(radius),
        ),
        Paint()..color = colors[i],
      );
      if (i < n - 1 && !isTotal[i + 1]) {
        final double yc = y(closes[i]);
        canvas.drawLine(
          Offset(cx + barW / 2, yc),
          Offset(cx + slot - barW / 2, yc),
          link,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WaterfallPainter old) =>
      old.opens != opens ||
      old.closes != closes ||
      old.colors != colors ||
      old.lo != lo ||
      old.hi != hi;
}
