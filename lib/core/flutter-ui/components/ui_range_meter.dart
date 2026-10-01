import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_data_panel.dart';

/// A shaded band on a [UiRangeMeter] track.
@immutable
class UiRangeZone {
  const UiRangeZone({
    required this.start,
    required this.end,
    required this.intent,
    this.label,
    this.alpha = 0.22,
  });

  final double start;
  final double end;
  final UiIntent intent;
  final String? label;
  final double alpha;
}

/// A needle on a [UiRangeMeter], labelled above or below the track.
@immutable
class UiRangeMarker {
  const UiRangeMarker({
    required this.value,
    required this.label,
    this.intent = UiIntent.primary,
    this.below = false,
    this.strong = false,
  });

  final double value;
  final String label;
  final UiIntent intent;

  /// Put the label under the track. Alternate above/below to fit more needles.
  final bool below;

  /// Thicker needle for the value the reader came for (spot, breakeven, PP).
  final bool strong;
}

/// A one-dimensional price axis with shaded zones and labelled needles.
///
/// Whenever an answer is "where does this number sit between two others" — spot
/// against breakeven, price against support and resistance, IV against its
/// historical band, utilisation against a cap — a bar or line chart forces the
/// reader to reconstruct the comparison. This states it directly: one axis, the
/// zones that matter, and the needles worth naming.
class UiRangeMeter extends StatelessWidget {
  const UiRangeMeter({
    super.key,
    required this.min,
    required this.max,
    this.zones = const <UiRangeZone>[],
    this.markers = const <UiRangeMarker>[],
    this.valueFormatter,
    this.trackThickness,
    this.showBounds = true,
    this.minLabel,
    this.maxLabel,
  });

  final double min;
  final double max;
  final List<UiRangeZone> zones;
  final List<UiRangeMarker> markers;
  final UiValueFormatter? valueFormatter;
  final double? trackThickness;
  final bool showBounds;
  final String? minLabel;
  final String? maxLabel;

  double _f(double v) {
    final double span = max - min;
    if (span.abs() < 1e-9) return 0.5;
    return ((v - min) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final UiValueFormatter fmt = valueFormatter ?? uiCompactNumber;
    final double track = context.sz(trackThickness ?? 10);
    final List<UiRangeMarker> above =
        markers.where((UiRangeMarker m) => !m.below).toList();
    final List<UiRangeMarker> below =
        markers.where((UiRangeMarker m) => m.below).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (above.isNotEmpty) _lane(context, above, fmt),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        SizedBox(
          height: track * 1.9,
          child: LayoutBuilder(
            builder: (BuildContext ctx, BoxConstraints constraints) {
              final double w = constraints.maxWidth;
              return Stack(
                children: <Widget>[
                  Align(
                    child: Container(
                      height: track,
                      decoration: BoxDecoration(
                        color: c.surfaceMuted,
                        borderRadius: ctx.radius(theme.radii.pill),
                        border: Border.all(
                          color: c.border,
                          width: theme.borders.hairline,
                        ),
                      ),
                    ),
                  ),
                  for (final UiRangeZone z in zones)
                    Positioned(
                      left: w * _f(z.start < z.end ? z.start : z.end),
                      width: w <= 0
                          ? 0.0
                          : (w * (_f(z.end) - _f(z.start)).abs())
                              .clamp(0.0, w),
                      top: (track * 1.9 - track) / 2,
                      height: track,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: z.intent.color(ctx).withValues(alpha: z.alpha),
                          borderRadius: ctx.radius(theme.radii.pill),
                        ),
                      ),
                    ),
                  for (final UiRangeMarker m in markers)
                    Align(
                      alignment: Alignment(_f(m.value) * 2 - 1, 0),
                      child: Container(
                        width: ctx.sz(m.strong ? 3 : 2),
                        height: track * 1.9,
                        decoration: BoxDecoration(
                          color: m.intent.color(ctx),
                          borderRadius: ctx.radius(theme.radii.pill),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (below.isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xxs)),
          _lane(context, below, fmt),
        ],
        if (showBounds) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Row(
            children: <Widget>[
              Text(
                minLabel ?? fmt(min),
                style: uiOverline(context),
              ),
              const Spacer(),
              Text(
                maxLabel ?? fmt(max),
                style: uiOverline(context),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _lane(
    BuildContext context,
    List<UiRangeMarker> lane,
    UiValueFormatter fmt,
  ) {
    return Stack(
      children: <Widget>[
        // Reserves the lane's height even where no label lands.
        Opacity(
          opacity: 0,
          child: Text('X', style: uiOverline(context)),
        ),
        for (final UiRangeMarker m in lane)
          Align(
            alignment: Alignment(_f(m.value) * 2 - 1, 0),
            child: Text(
              '${m.label} ${fmt(m.value)}',
              style: uiOverline(context, color: m.intent.color(context)),
              maxLines: 1,
            ),
          ),
      ],
    );
  }
}
