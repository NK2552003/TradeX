import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/presentation/pages/get_started_page.dart';
import 'package:tradex/features/auth/presentation/pages/login_page.dart';
import 'package:tradex/features/auth/presentation/pages/signup_page.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets('pulled thread completes each loop and respects reduced motion', (
    tester,
  ) async {
    final boundary = GlobalKey();
    Future<void> showThread(bool reduced) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: RepaintBoundary(
              key: boundary,
              child: const SizedBox(
                width: 480,
                height: 160,
                child: AlphaThread(animate: true, phase: 12.7, thickness: 64),
              ),
            ),
          ),
        ),
      ),
    );
    Future<List<int>> pixels() async {
      final bytes = await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        try {
          return (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      });
      return bytes!;
    }

    bool hasInk(List<int> rgba, int left, int right) {
      for (var y = 0; y < 160; y++) {
        for (var x = left; x < right; x++) {
          if (rgba[(y * 480 + x) * 4 + 3] > 0) return true;
        }
      }
      return false;
    }

    await showThread(false);
    expect(hasInk(await pixels(), 0, 480), isFalse);
    final samples = <List<int>>[];
    for (var i = 0; i < 8; i++) {
      await tester.pump(AlphaThread.pullDuration ~/ 8);
      samples.add(await pixels());
    }
    final halfway = samples[3];
    expect(hasInk(halfway, 0, 240), isTrue);
    expect(hasInk(halfway, 420, 480), isFalse);
    final resting = samples.last;
    expect(hasInk(resting, 241, 480), isTrue);
    // A loop folds back behind its tip. Check across the pull, so this
    // geometry assertion doesn't depend on the speed of the entrance.
    bool hasUnfinishedLoop(List<int> frame) {
      final tipX = List.generate(
        480,
        (x) => x,
      ).lastWhere((x) => hasInk(frame, x, x + 1), orElse: () => 0);
      var missingBehindTip = 0;
      for (var y = 0; y < 160; y++) {
        for (var x = 0; x < tipX - 12; x++) {
          final alpha = (y * 480 + x) * 4 + 3;
          if (frame[alpha] < 15 && resting[alpha] > 220) missingBehindTip++;
        }
      }
      return missingBehindTip > 50;
    }

    expect(samples.any(hasUnfinishedLoop), isTrue);
    await showThread(true);
    expect(await pixels(), orderedEquals(resting));
    await tester.pump(const Duration(seconds: 2));
    expect(await pixels(), orderedEquals(resting));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 740), const Size(740, 320)]) {
    for (final scale in [1.0, 1.5]) {
      for (final page in ['welcome', 'login', 'signup']) {
        testWidgets('$page fits $size with text scale $scale', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final Widget child = switch (page) {
            'welcome' => GetStartedPage(onGetStarted: (_) {}, onSignIn: () {}),
            'login' => LoginPage(
              onLoginSuccess: (_, _) {},
              onNavigateToSignup: (_) {},
              onNavigateToForgotPassword: () {},
              onNavigateBack: () {},
            ),
            _ => SignupPage(
              onSignupSuccess: (_, _, {bool requiresVerification = false}) {},
              onNavigateToLogin: (_) {},
              onNavigateBack: () {},
            ),
          };
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: child,
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));
          final ribbons = tester.widgetList<AlphaThread>(
            find.byType(AlphaThread),
          );
          expect(ribbons, isNotEmpty);
          expect(ribbons.every((ribbon) => ribbon.animate), isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
