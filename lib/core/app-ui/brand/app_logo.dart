import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';

/// TraderHub brand mark: an upward arc rising out of three candlesticks.
/// Painted in pure Dart so it scales, themes and animates with no asset.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({
    super.key,
    this.size,
    this.color,
    this.accentColor,
    this.progress = 1,
    this.rounded = true,
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
    final Color base = color ?? theme.colors.foreground;
    final Color accent = accentColor ?? theme.colors.primary;

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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
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

    final double stroke = math.max(1.4, w * 0.09);

    // Three candlesticks of increasing height.
    final List<double> heights = <double>[0.40, 0.62, 0.86];
    final Paint candle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    for (int i = 0; i < heights.length; i++) {
      final double t = ((progress * 3) - i).clamp(0, 1);
      if (t <= 0) continue;
      final double x = w * (0.18 + i * 0.32);
      final double full = h * heights[i];
      final double top = h * 0.92 - full * t;
      candle.color = i == heights.length - 1
          ? accent.withValues(alpha: 0.95)
          : base.withValues(alpha: 0.55);
      canvas.drawLine(Offset(x, h * 0.92), Offset(x, top), candle);
    }

    // Upward arc sweeping over the candles.
    final Path arc = Path()
      ..moveTo(w * 0.10, h * 0.66)
      ..cubicTo(w * 0.36, h * 0.62, w * 0.52, h * 0.42, w * 0.92, h * 0.12);

    final List<ui.PathMetric> metricsList = arc.computeMetrics().toList();
    if (metricsList.isNotEmpty) {
      final ui.PathMetric metric = metricsList.first;
      final Path drawn = metric.extractPath(0, metric.length * progress);

      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke * 0.85
          ..color = accent,
      );
    }

    // Arrow head at the arc tip.
    if (progress > 0.85) {
      final double a = ((progress - 0.85) / 0.15).clamp(0, 1);
      final Paint head = Paint()..color = accent.withValues(alpha: a);
      final Path tip = Path()
        ..moveTo(w * 0.95, h * 0.09)
        ..lineTo(w * 0.66, h * 0.14)
        ..lineTo(w * 0.90, h * 0.38)
        ..close();
      canvas.drawPath(tip, head);
    }
  }

  @override
  bool shouldRepaint(_AppLogoPainter old) =>
      old.progress != progress || old.base != base || old.accent != accent;
}

/// Wordmark: "Trader" in foreground, "Hub" in the brand color.
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
          const TextSpan(text: 'Trader'),
          TextSpan(
            text: 'Hub',
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
  });

  final bool compact;
  final double? size;
  final bool stacked;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Widget mark = AppLogoMark(size: size);
    if (compact) return mark;

    final Widget text = Column(
      crossAxisAlignment:
          stacked ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppWordmark(fontSize: size == null ? null : context.sz(size! * 0.7)),
        if (tagline != null)
          Text(
            tagline!,
            style: context.uiText.caption
                .copyWith(color: theme.colors.foregroundMuted),
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
        final double draw =
            Curves.easeInOutCubic.transform((_controller.value / 0.7).clamp(0, 1));
        final double textIn =
            Curves.easeOutCubic.transform(((_controller.value - 0.55) / 0.45).clamp(0, 1));
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
                        style: context.uiText.caption
                            .copyWith(color: theme.colors.foregroundMuted),
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
