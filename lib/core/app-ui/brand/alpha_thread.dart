// alpha_thread.dart
//
// AlphaThread: one continuous, looping "thread" of text that runs along the top of a screen
// (the AlphaJournal login header). No packages needed, only Flutter.
//
// Usage:
//
//   Stack(children: [
//     const Positioned(top: 0, left: 0, right: 0, height: 360, child: AlphaThread()),
//     // ...your login form below...
//   ]);
//
// Everything is optional:
//
//   AlphaThread(
//     label: 'ALPHAJOURNAL',   // text repeated along the thread
//     thickness: 76,           // ribbon width in design units (1600 x 540 canvas)
//     ribbonColor: Colors.black,
//     textColor: Color(0xFFD9D9D9),
//     phase: 47.229,           // change it to get a different (still smooth) arrangement
//     shadow: true,            // soft shadow where the thread crosses itself
//   )

import 'dart:math' as math;
import 'dart:ui' as ui show Gradient, PathMetric;
import 'package:flutter/material.dart';

/// Design canvas the thread is generated on. It is scaled to cover the widget,
/// anchored to the top edge so the thread always touches the top.
const double _kW = 1600;
const double _kH = 540;

class AlphaThread extends StatefulWidget {
  const AlphaThread({
    super.key,
    this.label = 'ALPHAJOURNAL',
    this.thickness = 76,
    this.ribbonColor,
    this.textColor,
    this.phase = 47.229,
    this.shadow = true,
    this.animate = false,
    this.height,
    this.scale,
  });

  final String label;
  final double thickness;
  final Color? ribbonColor;
  final Color? textColor;
  final double phase;
  final bool shadow;
  final bool animate;
  final double? scale;

  /// Optional fixed height. When null the widget fills the space it is given.
  final double? height;

  @override
  State<AlphaThread> createState() => _AlphaThreadState();
}

class _AlphaThreadState extends State<AlphaThread>
    with SingleTickerProviderStateMixin {
  _ThreadModel? _model;
  String? _key;

  AnimationController? _motion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(AlphaThread oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncMotion();
  }

  void _syncMotion() {
    if (!widget.animate ||
        MediaQuery.disableAnimationsOf(context) ||
        ModalRoute.isCurrentOf(context) == false) {
      _motion?.reset();
      return;
    }
    final motion = _motion ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    if (motion.isDismissed) motion.forward();
  }

  @override
  void dispose() {
    _motion?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ribbon = widget.ribbonColor ?? (dark ? Colors.black : Colors.white);
    final text =
        widget.textColor ??
        (dark ? const Color(0xFFD9D9D9) : const Color(0xFF222222));

    final key =
        '${widget.label}|${widget.thickness}|${widget.phase}|${text.hashCode}';
    if (key != _key) {
      _model = _ThreadModel.build(
        points: AlphaThreadGeometry.generate(
          thickness: widget.thickness,
          phase: widget.phase,
        ),
        label: widget.label,
        thickness: widget.thickness,
        textColor: text,
      );
      _key = key;
    }

    final paint = CustomPaint(
      painter: _ThreadPainter(
        _model!,
        ribbon,
        widget.thickness,
        widget.shadow,
        scale: widget.scale,
        motion: _motion,
      ),
      child: const SizedBox.expand(),
    );

    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: widget.height == null
              ? paint
              : SizedBox(
                  width: double.infinity,
                  height: widget.height,
                  child: paint,
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Geometry: the thread is built by integrating a smooth curvature profile, so
// it has no corners or pinches. Loop size, shape (round to oval), tilt, side and
// the thread's own heading all follow sine equations of the loop index.
// ---------------------------------------------------------------------------

class AlphaThreadGeometry {
  AlphaThreadGeometry._();

  static List<Offset> generate({
    double thickness = 76,
    double phase = 47.229,
    double step = 4,
  }) {
    double x = -220, y = 30, ph = 0;
    final pts = <Offset>[Offset(x, y)];

    void run(double len, double Function(double u) k) {
      final n = math.max(2, (len / step).ceil());
      final h = len / n;
      for (var i = 0; i < n; i++) {
        ph += k((i + .5) * h) * h;
        x += math.cos(ph) * h;
        y += math.sin(ph) * h;
        pts.add(Offset(x, y));
      }
    }

    void loop(
      double dir,
      double len,
      double total,
      double sq,
      double se,
      double sp,
    ) {
      final n = (len / step).ceil();
      final h = len / n;
      final f = List<double>.filled(n, 0);
      var sum = 0.0, mx = 0.0;
      for (var i = 0; i < n; i++) {
        final t = (i + .5) / n;
        f[i] =
            math.pow(math.sin(math.pi * t), sq).toDouble() *
            (1 + se * math.cos(4 * math.pi * t + sp));
        sum += f[i] * h;
        if (f[i] > mx) mx = f[i];
      }
      final sc = total / sum;
      final peak = sc * mx;
      final lim = 1 / (.9 * thickness);
      if (peak > lim) {
        // keep every bend wider than the ribbon
        loop(dir, len * peak / lim * 1.02, total, sq, se, sp);
        return;
      }
      run(len, (u) => dir * sc * f[math.min(n - 1, (u / h).floor())]);
    }

    var count = 0;
    while (x < 1750 && count < 40) {
      final k = count + 1 + phase;
      final ty = 40 + 40 * math.sin(.9 * k + .3) + 20 * math.sin(2.7 * k + 1);
      final ws = y > ty + 45
          ? -1.0
          : (y < ty - 45 ? 1.0 : (math.sin(2.2 * k + .7) > 0 ? 1.0 : -1.0));
      final sq = math.max(.25, .7 + .55 * math.sin(2.3 * k + .5));
      final se = .3 + .3 * math.sin(1.9 * k + 1.2);
      final sp = (3.1 * k) % (2 * math.pi);
      final len = math.max(
        420.0,
        520 + 170 * math.sin(1.7 * k + 1) + 110 * math.sin(3.9 * k + 2),
      );
      loop(ws, len, 2 * math.pi, sq, se, sp);

      final cur = ph - 2 * math.pi * (ph / (2 * math.pi)).round();
      var ht =
          (.012 * (ty - y)).clamp(-.9, .9).toDouble() +
          .4 * math.sin(4.1 * k + 1);
      ht = ht.clamp(-1.1, 1.1).toDouble();
      final d = ht - cur;
      final g = math.max(50 + 60 * (1 + math.sin(3.3 * k)), d.abs() / .006);
      run(g, (u) => d / g * (1 - math.cos(2 * math.pi * u / g)));
      count++;
    }
    return pts;
  }
}

// ---------------------------------------------------------------------------
// Model: the thread is cut into short chunks drawn one on top of the next, so
// every crossing shows an over/under overlap with a shadow. Each chunk carries
// its own letters, placed one by one along the path.
// ---------------------------------------------------------------------------

class _Glyph {
  _Glyph(this.painter, this.position, this.angle, this.distance);
  final TextPainter painter;
  final Offset position;
  final double angle;
  final double distance;
}

class _Chunk {
  _Chunk(this.path, this.glyphs, this.metric, this.points);
  final ui.PathMetric metric;
  final List<Offset> points;
  late final Rect bounds = path.getBounds();
  final Path path;
  final List<_Glyph> glyphs;
}

class _ThreadModel {
  _ThreadModel(this.chunks);
  final List<_Chunk> chunks;

  static _ThreadModel build({
    required List<Offset> points,
    required String label,
    required double thickness,
    required Color textColor,
  }) {
    final fs = thickness * .5;
    final style = TextStyle(
      fontSize: fs,
      fontWeight: FontWeight.w500,
      color: textColor,
      letterSpacing: fs * .02,
      height: 1,
    );
    final cache = <String, TextPainter>{};
    TextPainter glyphFor(String c) => cache.putIfAbsent(
      c,
      () => TextPainter(
        text: TextSpan(text: c, style: style),
        textDirection: TextDirection.ltr,
      )..layout(),
    );

    const chunkSize = 100;
    final unit = '$label ';
    final chunks = <_Chunk>[];

    for (var s = 0; s < points.length - 1; s += chunkSize) {
      final seg = points.sublist(s, math.min(s + chunkSize + 3, points.length));
      final path = Path()..moveTo(seg.first.dx, seg.first.dy);
      for (var i = 1; i < seg.length; i++) {
        path.lineTo(seg[i].dx, seg[i].dy);
      }
      final metric = path.computeMetrics().first;
      final len = metric.length;

      final n = math.max(1, (len / (fs * 9.4)).floor());
      final chars = List.filled(n, unit).join().split('');
      var natural = 0.0;
      for (final c in chars) {
        natural += glyphFor(c).width;
      }
      final extra =
          ((len - 4) - natural) /
          chars.length; // spread letters to fill the chunk

      final glyphs = <_Glyph>[];
      var d = 0.0;
      for (final c in chars) {
        final tp = glyphFor(c);
        if (c != ' ') {
          final distance = (d + tp.width / 2).clamp(0.0, len).toDouble();
          final t = metric.getTangentForOffset(distance);
          if (t != null) {
            glyphs.add(
              _Glyph(
                tp,
                t.position,
                math.atan2(t.vector.dy, t.vector.dx),
                distance,
              ),
            );
          }
        }
        d += tp.width + extra;
      }
      chunks.add(
        _Chunk(path, glyphs, metric, [
          for (int i = 0; i < seg.length - 1; i += 2) seg[i],
          seg.last,
        ]),
      );
    }
    return _ThreadModel(chunks);
  }
}

class _ThreadPainter extends CustomPainter {
  _ThreadPainter(
    this.model,
    this.ribbon,
    this.thickness,
    this.shadow, {
    this.scale,
    this.motion,
  }) : super(repaint: motion);

  final Animation<double>? motion;
  final _ThreadModel model;
  final Color ribbon;
  final double thickness;
  final bool shadow;
  final double? scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final effectiveScale =
        scale ?? math.max(size.width / _kW, size.height / _kH);
    canvas.translate(
      (size.width - _kW * effectiveScale) / 2,
      0,
    ); // centered horizontally, pinned to the top
    canvas.scale(effectiveScale);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round
      ..color = ribbon
      ..isAntiAlias = true;
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round
      ..color = const Color.fromRGBO(0, 0, 0, .45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final progress = Curves.easeInOutSine.transform(motion?.value ?? 0);
    final flowing = progress > 0 && progress < 1;
    final amplitude = thickness * .24 * math.sin(math.pi * progress);
    final wavelength = thickness * 3;
    double waveAt(double x) => x / wavelength - 2 * math.pi * progress;
    Offset bend(Offset p) =>
        Offset(p.dx, p.dy + amplitude * math.sin(waveAt(p.dx)));

    if (flowing) {
      // A travelling highlight follows the roll on both light and dark ribbon.
      final highlight = Color.lerp(
        ribbon,
        ribbon.computeLuminance() < 0.5 ? Colors.white : Colors.black,
        0.12 * math.sin(math.pi * progress),
      )!;
      final start = Offset(wavelength * progress * 2 * math.pi, 0);
      stroke.shader = ui.Gradient.linear(
        start,
        start + Offset(wavelength * math.pi, 0),
        [ribbon, highlight, ribbon],
        const [0, 0.5, 1],
        TileMode.repeated,
      );
    }
    final visible = canvas.getLocalClipBounds().inflate(thickness + amplitude);
    for (final chunk in model.chunks) {
      if (!visible.overlaps(chunk.bounds)) continue;
      final path = flowing
          ? (Path()..addPolygon(chunk.points.map(bend).toList(), false))
          : chunk.path;
      if (shadow) {
        canvas.drawPath(path.shift(const Offset(0, 7)), shadowPaint);
      }
      canvas.drawPath(path, stroke);
      for (final g in chunk.glyphs) {
        var position = g.position;
        var angle = g.angle;
        var faceScale = 1.0;
        if (flowing) {
          final length = chunk.metric.length;
          final distance = (g.distance + length * progress) % length;
          final tangent = chunk.metric.getTangentForOffset(distance)!;
          position = bend(tangent.position);
          final roll = math.cos(waveAt(position.dx)) * amplitude / wavelength;
          angle = math.atan2(
            tangent.vector.dy + roll * tangent.vector.dx,
            tangent.vector.dx,
          );
          faceScale -= roll.abs();
        }
        canvas.save();
        canvas.translate(position.dx, position.dy);
        canvas.rotate(angle);
        if (flowing) canvas.scale(1, faceScale);
        g.painter.paint(
          canvas,
          Offset(-g.painter.width / 2, -g.painter.height / 2),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ThreadPainter old) =>
      old.model != model ||
      old.ribbon != ribbon ||
      old.thickness != thickness ||
      old.shadow != shadow ||
      old.scale != scale ||
      old.motion != motion;
}

/// Places [AlphaThread] ribbons around the edges of the screen, behind
/// [child]. Each screen passes its own [phase] / [thickness] so the ribbons
/// differ in loop shape and size.
///
/// * [allSides] false: top edge only (mobile top / landing hero).
/// * [allSides] true: top + bottom, and on wide screens left + right too.
/// * [opacity] / [fadeOut] soften the ribbon so it never fights with content.
class AlphaThreadBackdrop extends StatelessWidget {
  const AlphaThreadBackdrop({
    super.key,
    required this.child,
    this.phase = 47.229,
    this.thickness = 76,
    this.mobileHeight = 230,
    this.desktopHeight = 340,
    this.allSides = false,
    this.showSideEdges = true,
    this.reveal,
    this.animate = false,
    this.opacity = 1,
    this.fadeOut = false,
    this.ribbonColor,
    this.textColor,
  });

  const AlphaThreadBackdrop.auth({
    Key? key,
    required Widget child,
    double phase = 12.7,
    bool showSideEdges = true,
    Animation<double>? reveal,
  }) : this(
         key: key,
         child: child,
         phase: phase,
         thickness: 64,
         mobileHeight: 200,
         desktopHeight: 320,
         opacity: 0.5,
         allSides: true,
         showSideEdges: showSideEdges,
         reveal: reveal,
         animate: reveal == null,
       );

  final Widget child;
  final double phase;
  final double thickness;
  final double mobileHeight;
  final double desktopHeight;
  final bool allSides;
  final bool showSideEdges;
  final Animation<double>? reveal;
  final bool animate;
  final double opacity;
  final bool fadeOut;
  final Color? ribbonColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool wide = screenSize.width >= 700;
    final double band = wide ? desktopHeight : mobileHeight;
    final double uniformScale = math.max(screenSize.width / _kW, band / _kH);

    // Keep the full design depth during the entrance, including inward loops.
    final depth = reveal == null ? band : _kH * uniformScale;
    Widget ribbon(double ph) {
      final thread = AlphaThread(
        phase: ph,
        thickness: thickness,
        scale: uniformScale,
        animate: animate,
        ribbonColor: ribbonColor,
        textColor: textColor,
      );
      final entrance = reveal;
      if (entrance == null || MediaQuery.disableAnimationsOf(context)) {
        return thread;
      }
      return FadeTransition(
        opacity: entrance,
        child: SlideTransition(
          position: entrance.drive(
            Tween(begin: const Offset(0, -0.12), end: Offset.zero),
          ),
          child: thread,
        ),
      );
    }

    final List<Widget> layers = <Widget>[
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: depth,
        child: ribbon(phase),
      ),
      if (allSides)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: depth,
          child: RotatedBox(
            quarterTurns: 2,
            child: _FillBox(ribbon(phase + 31.4)),
          ),
        ),
      if (allSides && wide && showSideEdges) ...<Widget>[
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: depth,
          child: RotatedBox(
            quarterTurns: 3,
            child: _FillBox(ribbon(phase + 17.9)),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: depth,
          child: RotatedBox(
            quarterTurns: 1,
            child: _FillBox(ribbon(phase + 64.2)),
          ),
        ),
      ],
    ];

    Widget art = Stack(children: layers);
    if (fadeOut) {
      art = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (Rect r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.white, Colors.white, Colors.transparent],
          stops: <double>[0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, r.width, band)),
        child: art,
      );
    }
    if (opacity < 1) art = Opacity(opacity: opacity, child: art);

    return Stack(
      children: <Widget>[
        Positioned.fill(child: art),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _FillBox extends StatelessWidget {
  const _FillBox(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox.expand(child: child);
}
