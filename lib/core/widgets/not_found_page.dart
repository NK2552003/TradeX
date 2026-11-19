import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

/// Full-page "404" experience: a lost astronaut-trader drifting past a broken
/// candlestick chart. The illustration is pure vector (no raster/logo assets),
/// so it stays crisp at any size and follows the active theme colours.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({
    super.key,
    this.title = 'Lost in the markets',
    this.message =
        "We couldn't find the page you're looking for. The link may be broken, "
        'expired, or the post may have been removed.',
    this.primaryLabel = 'Back to workspace',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.sz(520)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _LostAstronaut(),
                  SizedBox(height: context.sp(theme.spacing.lg)),
                  UiBadge(
                    label: 'ERROR 404',
                    intent: UiIntent.danger,
                    variant: UiBadgeVariant.soft,
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: context.uiText.heading.copyWith(
                      fontSize: context.fs(26),
                      fontWeight: FontWeight.w800,
                      color: colors.foreground,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: context.uiText.body.copyWith(
                      color: colors.foregroundMuted,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xl)),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: context.sp(theme.spacing.sm),
                    runSpacing: context.sp(theme.spacing.sm),
                    children: <Widget>[
                      UiButton(
                        label: primaryLabel,
                        icon: Icons.home_rounded,
                        variant: UiVariant.solid,
                        intent: UiIntent.primary,
                        onPressed: onPrimary,
                      ),
                      if (secondaryLabel != null)
                        UiButton(
                          label: secondaryLabel!,
                          variant: UiVariant.outline,
                          onPressed: onSecondary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LostAstronaut extends StatefulWidget {
  const _LostAstronaut();

  @override
  State<_LostAstronaut> createState() => _LostAstronautState();
}

class _LostAstronautState extends State<_LostAstronaut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiColors colors = context.ui.colors;
    final double side = math.min(
      context.sz(300),
      MediaQuery.sizeOf(context).width - 48,
    );
    return SizedBox(
      width: side,
      height: side * 0.82,
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext _, Widget? _) => CustomPaint(
          painter: _AstronautPainter(
            t: _c.value,
            primary: colors.primary,
            bull: colors.bullish,
            bear: colors.bearish,
            surface: colors.surface,
            fg: colors.foreground,
            muted: colors.foregroundSubtle,
          ),
        ),
      ),
    );
  }
}

class _AstronautPainter extends CustomPainter {
  _AstronautPainter({
    required this.t,
    required this.primary,
    required this.bull,
    required this.bear,
    required this.surface,
    required this.fg,
    required this.muted,
  });

  final double t;
  final Color primary;
  final Color bull;
  final Color bear;
  final Color surface;
  final Color fg;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    // Design space 300 x 246.
    final double s = size.width / 300;
    canvas.scale(s);
    final double bob = math.sin(t * 2 * math.pi) * 7;
    final double tilt = math.sin(t * 2 * math.pi + 1) * 0.05;

    // Glow
    canvas.drawCircle(
      const Offset(150, 120),
      108,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                primary.withValues(alpha: 0.28),
                primary.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: const Offset(150, 120), radius: 108),
            ),
    );

    // Stars
    final Paint star = Paint()..color = fg.withValues(alpha: 0.5);
    const List<List<double>> stars = <List<double>>[
      <double>[28, 40, 1.8],
      <double>[262, 28, 1.4],
      <double>[44, 168, 1.2],
      <double>[280, 150, 2],
      <double>[120, 14, 1.2],
      <double>[220, 214, 1.5],
    ];
    for (int i = 0; i < stars.length; i++) {
      final double tw = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 2 + i);
      star.color = fg.withValues(alpha: 0.2 + 0.5 * tw);
      canvas.drawCircle(Offset(stars[i][0], stars[i][1]), stars[i][2], star);
    }

    // Drifting broken candles (background)
    void candle(double x, double y, double h, Color c, double wick) {
      final Paint p = Paint()..color = c.withValues(alpha: 0.85);
      canvas.drawRect(Rect.fromLTWH(x + 4.5, y - wick, 1.6, h + wick * 2), p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 11, h),
          const Radius.circular(2.5),
        ),
        p,
      );
    }

    final double drift = math.sin(t * 2 * math.pi + 2) * 5;
    candle(30, 96 + drift, 26, bear, 8);
    candle(52, 118 - drift, 18, bull, 7);
    candle(244, 70 - drift, 30, bull, 9);
    candle(266, 96 + drift, 22, bear, 8);

    // Astronaut
    canvas.save();
    canvas.translate(150, 128 + bob);
    canvas.rotate(tilt);

    final Paint suit = Paint()..color = const Color(0xFFF1F4FA);
    final Paint suitShade = Paint()..color = const Color(0xFFD3DAE8);
    final Paint accent = Paint()..color = primary;

    // Backpack
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-44, -4, 24, 58),
        const Radius.circular(9),
      ),
      suitShade,
    );
    // Legs
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-24, 46, 20, 40),
        const Radius.circular(9),
      ),
      suit,
    );
    canvas.save();
    canvas.translate(10, 46);
    canvas.rotate(-0.25 + math.sin(t * 2 * math.pi) * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 20, 40),
        const Radius.circular(9),
      ),
      suit,
    );
    canvas.restore();
    // Boots
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-27, 78, 26, 12),
        const Radius.circular(6),
      ),
      accent,
    );
    // Torso
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-30, -6, 60, 62),
        const Radius.circular(22),
      ),
      suit,
    );
    // Chest panel
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-14, 10, 28, 20),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF1B2233),
    );
    canvas.drawCircle(const Offset(-6, 20), 3, Paint()..color = bear);
    canvas.drawCircle(const Offset(5, 20), 3, Paint()..color = bull);
    // Arms
    canvas.save();
    canvas.translate(26, 6);
    canvas.rotate(-0.9 + math.sin(t * 2 * math.pi * 2) * 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 17, 40),
        const Radius.circular(8.5),
      ),
      suit,
    );
    canvas.drawCircle(const Offset(8.5, 42), 9, accent);
    canvas.restore();
    canvas.save();
    canvas.translate(-28, 8);
    canvas.rotate(0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-17, 0, 17, 38),
        const Radius.circular(8.5),
      ),
      suit,
    );
    canvas.drawCircle(const Offset(-8.5, 40), 9, accent);
    canvas.restore();

    // Helmet
    canvas.drawCircle(const Offset(0, -34), 44, suit);
    canvas.drawCircle(
      const Offset(0, -34),
      44,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = suitShade.color,
    );
    // Visor
    final Rect visor = Rect.fromCenter(
      center: const Offset(2, -34),
      width: 66,
      height: 52,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(visor, const Radius.circular(24)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[const Color(0xFF28324D), const Color(0xFF0B1020)],
        ).createShader(visor),
    );
    // Visor reflection
    canvas.drawArc(
      visor.deflate(7),
      math.pi * 1.1,
      math.pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    // Eyes (confused) + mouth
    final Paint eye = Paint()..color = primary;
    canvas.drawCircle(const Offset(-8, -34), 4.2, eye);
    canvas.drawCircle(const Offset(14, -34), 4.2, eye);
    canvas.drawArc(
      const Rect.fromLTWH(-3, -26, 14, 10),
      0.2,
      math.pi * 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2
        ..color = primary,
    );
    // Antenna
    canvas.drawLine(
      const Offset(-22, -72),
      const Offset(-30, -92),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = suitShade.color,
    );
    canvas.drawCircle(
      const Offset(-30, -94),
      5,
      Paint()
        ..color = bear.withValues(
          alpha: 0.6 + 0.4 * math.sin(t * 2 * math.pi * 3),
        ),
    );
    canvas.restore();

    // Floating question mark
    final TextPainter q = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          fontSize: 46,
          fontWeight: FontWeight.w900,
          color: primary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(214, 28 - bob * 0.7);
    canvas.rotate(0.25);
    q.paint(canvas, Offset.zero);
    canvas.restore();

    // Floor shadow that shrinks as the character rises
    final double shadow = 1 - (bob + 7) / 40;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(150, 236),
        width: 90 * shadow,
        height: 10 * shadow,
      ),
      Paint()..color = fg.withValues(alpha: 0.12),
    );
  }

  @override
  bool shouldRepaint(covariant _AstronautPainter old) =>
      old.t != t || old.primary != primary || old.fg != fg;
}
