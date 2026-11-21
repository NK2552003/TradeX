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
import 'dart:ui' as ui show PathMetric;
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
    this.reveal,
    this.height,
    this.scale,
  });

  static const pullDuration = Duration(milliseconds: 3600);

  final String label;
  final double thickness;
  final Color? ribbonColor;
  final Color? textColor;
  final double phase;
  final bool shadow;
  final bool animate;

  /// Optional entrance progress supplied by the containing screen.
  final Animation<double>? reveal;
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
  bool _motionEnabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(AlphaThread oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate ||
        oldWidget.reveal != widget.reveal) {
      _syncMotion();
    }
  }

  void _syncMotion() {
    _motionEnabled =
        widget.animate &&
        widget.reveal == null &&
        !MediaQuery.disableAnimationsOf(context) &&
        ModalRoute.isCurrentOf(context) != false;
    if (!_motionEnabled) {
      _motion?.reset();
      return;
    }
    final motion = _motion ??= AnimationController(
      vsync: this,
      duration: AlphaThread.pullDuration,
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
        pull: MediaQuery.disableAnimationsOf(context)
            ? null
            : widget.reveal ?? (_motionEnabled ? _motion : null),
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
// each new section can cross above the ribbon and lettering already drawn.
// ---------------------------------------------------------------------------

class _Glyph {
  const _Glyph(this.painter, this.center);
  final TextPainter painter;
  final double center;
}

class _Chunk {
  _Chunk(this.path, this.strokePath, this.start)
    : metric = path.computeMetrics().first,
      strokeMetric = strokePath.computeMetrics().first {
    strokeOverlapLength = math.max(0.0, strokeMetric.length - metric.length);
  }

  /// Exact non-overlapping segment used for shadow casting & distance ranges so
  /// outer drop shadows never double-darken at chunk joints.
  final Path path;

  /// Extended segment that begins [strokeOverlapLength] units inside the
  /// previous chunk so the opaque ribbon stroke completely covers any backward
  /// blur bleed from this chunk's drop shadow and eliminates butt-cap seams.
  final Path strokePath;

  final double start;
  final ui.PathMetric metric;
  final ui.PathMetric strokeMetric;
  late final double strokeOverlapLength;
  late final Rect bounds = strokePath.getBounds();
  double get end => start + metric.length;
}

class _ThreadModel {
  _ThreadModel(this.chunks, this.word, this.repeatLength, this.entranceStart);
  final List<_Chunk> chunks;
  final List<_Glyph> word;
  final double repeatLength;
  final double entranceStart;
  double get length => chunks.last.end;

  static _ThreadModel build({
    required List<Offset> points,
    required String label,
    required double thickness,
    required Color textColor,
  }) {
    final style = TextStyle(
      fontFamily: 'NotoSans',
      fontSize: thickness * .5,
      fontWeight: FontWeight.w500,
      color: textColor,
      height: 1,
    );
    final cache = <String, TextPainter>{};
    final word = <_Glyph>[];
    var advance = 0.0;
    for (final c in '$label '.characters) {
      final glyph = cache.putIfAbsent(
        c,
        () => TextPainter(
          text: TextSpan(text: c, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      if (c != ' ') word.add(_Glyph(glyph, advance + glyph.width / 2));
      advance += glyph.width + thickness * .05;
    }

    const chunkSize = 100;
    // 14 points * ~4 design units ≈ 56 units — exceeds the blur (8 * 3 = 24) +
    // shadow Y shift (7) + half-glyph width, yet stays well below any loop
    // self-crossing distance (min circumference ≥ 2π * 0.9 * thickness ≈ 430).
    const overlapPoints = 14;
    final chunks = <_Chunk>[];
    // Skip the invisible lead-in on the design canvas. Leave a margin for the
    // stroke and its blurred shadow before the first visible point.
    final artBounds = const Rect.fromLTWH(
      0,
      0,
      _kW,
      _kH,
    ).inflate(thickness / 2 + 24);
    double? entranceStart;
    var start = 0.0;
    for (var s = 0; s < points.length - 1; s += chunkSize) {
      final endIdx = math.min(s + chunkSize + 1, points.length);
      final segment = points.sublist(s, endIdx);
      final path = Path()..addPolygon(segment, false);
      final strokePath = s == 0
          ? path
          : (Path()..addPolygon(
              points.sublist(math.max(0, s - overlapPoints), endIdx),
              false,
            ));
      final chunk = _Chunk(path, strokePath, start);
      if (entranceStart == null && artBounds.overlaps(chunk.bounds)) {
        var distance = start;
        for (var i = 1; i < segment.length; i++) {
          if (artBounds.contains(segment[i])) {
            entranceStart = distance;
            break;
          }
          distance += (segment[i] - segment[i - 1]).distance;
        }
      }
      chunks.add(chunk);
      start = chunk.end;
    }
    return _ThreadModel(chunks, word, advance, entranceStart ?? 0);
  }
}

class _ThreadPainter extends CustomPainter {
  _ThreadPainter(
    this.model,
    this.ribbon,
    this.thickness,
    this.shadow, {
    this.scale,
    this.pull,
  }) : super(repaint: pull);

  final Animation<double>? pull;
  final _ThreadModel model;
  final Color ribbon;
  final double thickness;
  final bool shadow;
  final double? scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (thickness <= 0 || size.isEmpty) return;
    final t = (pull?.value ?? 1).clamp(0.0, 1.0);
    // Smoothstep starts and ends at rest, with peak speed halfway through.
    final progress = t * t * (3 - 2 * t);
    if (progress <= 0) return;
    final tip = progress == 1
        ? model.length
        : model.entranceStart + (model.length - model.entranceStart) * progress;
    // The tip reveals the full path, but the lettering only drifts half a
    // word. Longer ribbons no longer make the characters race past.
    final remaining = model.repeatLength * .5 * (1 - progress);
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
    final bool lightRibbon = ribbon.computeLuminance() > 0.5;
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round
      ..color = Color.fromRGBO(0, 0, 0, lightRibbon ? 0.24 : 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final visible = canvas.getLocalClipBounds().inflate(thickness);
    final chunks = model.chunks;
    for (var idx = 0; idx < chunks.length; idx++) {
      final chunk = chunks[idx];
      if (chunk.start >= tip) break;
      if (!visible.overlaps(chunk.bounds)) continue;
      final end = math.min(tip, chunk.end);
      final isFullChunk = end == chunk.end;
      final shadowPath = isFullChunk
          ? chunk.path
          : chunk.metric.extractPath(0, end - chunk.start);
      final fillPath = isFullChunk
          ? chunk.strokePath
          : chunk.strokeMetric.extractPath(
              0,
              chunk.strokeOverlapLength + (end - chunk.start),
            );
      if (shadow) {
        canvas.drawPath(shadowPath.shift(const Offset(0, 7)), shadowPaint);
      }
      canvas.drawPath(fillPath, stroke);

      // Defer glyphs inside the next chunk's overlap tail so they are painted
      // once — cleanly on top of the next chunk's seamless stroke bridge — with
      // zero shadow cut or sliced letters across the chunk joint.
      final _Chunk? nextChunk = idx + 1 < chunks.length
          ? chunks[idx + 1]
          : null;
      final bool nextChunkDrawn =
          nextChunk != null &&
          nextChunk.start < tip &&
          visible.overlaps(nextChunk.bounds);
      final double glyphRangeStart = chunk.start - chunk.strokeOverlapLength;
      final double glyphRangeEnd = nextChunkDrawn
          ? math.min(end, nextChunk.start - nextChunk.strokeOverlapLength)
          : end;

      final firstWord = ((glyphRangeStart + remaining) / model.repeatLength)
          .floor();
      for (
        var origin = firstWord * model.repeatLength - remaining;
        origin < glyphRangeEnd;
        origin += model.repeatLength
      ) {
        for (final glyph in model.word) {
          final distance = origin + glyph.center;
          if (distance < glyphRangeStart ||
              distance >= glyphRangeEnd ||
              distance + glyph.painter.width / 2 > tip) {
            continue;
          }
          final offsetInStroke = (distance - glyphRangeStart).clamp(
            0.0,
            chunk.strokeMetric.length,
          );
          final tangent = chunk.strokeMetric.getTangentForOffset(
            offsetInStroke,
          );
          if (tangent == null) continue;
          canvas.save();
          canvas.translate(tangent.position.dx, tangent.position.dy);
          canvas.rotate(math.atan2(tangent.vector.dy, tangent.vector.dx));
          glyph.painter.paint(
            canvas,
            Offset(-glyph.painter.width / 2, -glyph.painter.height / 2),
          );
          canvas.restore();
        }
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
      old.pull != pull;
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
      return AlphaThread(
        phase: ph,
        thickness: thickness,
        scale: uniformScale,
        animate: animate,
        reveal: reveal,
        ribbonColor: ribbonColor,
        textColor: textColor,
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
        Positioned.fill(child: RepaintBoundary(child: art)),
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
