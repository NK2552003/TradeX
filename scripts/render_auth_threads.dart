// Run with flutter test scripts/render_auth_threads.dart --dart-define=THREAD_FRAMES=/tmp/frames.
// Encode the transparent, single-play sequence from a fresh frame directory:
//   avifenc --fps 50 --repetition-count 0 --speed 8 --jobs 5 -y 420 -q 67 \
//     --qalpha 74 /tmp/frames/*.png web/auth-thread-pull.avif
// Save the last PNG as web/auth-threads.webp for reduced motion.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

void main() {
  testWidgets('render the web splash from AlphaThread', (tester) async {
    const output = String.fromEnvironment('THREAD_FRAMES');
    if (output.isEmpty) {
      throw ArgumentError('Set THREAD_FRAMES to an output directory.');
    }
    final directory = Directory(output)..createSync(recursive: true);
    final font = FontLoader('NotoSans')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 2160);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundary = GlobalKey();
    final pull = AnimationController(vsync: tester);
    addTearDown(pull.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: boundary,
          child: Column(
            children: [
              for (final phase in [12.7, 12.7 + 31.4, 12.7 + 17.9, 12.7 + 64.2])
                AlphaThread(
                  height: 540,
                  phase: phase,
                  thickness: 64,
                  reveal: pull,
                ),
            ],
          ),
        ),
      ),
    );

    const stepMs = 20;
    final duration = AlphaThread.pullDuration.inMilliseconds;
    for (var time = 0; time <= duration; time += stepMs) {
      pull.value = time / duration;
      await tester.pump();
      await tester.runAsync(() async {
        final art =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await art.toImage(pixelRatio: .5);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${directory.path}/${time.toString().padLeft(4, '0')}.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }
  });
}
