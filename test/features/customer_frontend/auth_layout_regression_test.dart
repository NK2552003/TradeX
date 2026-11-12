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
  testWidgets('thread lettering and curves move and respect reduced motion', (
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
                child: AlphaThread(animate: true),
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
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      });
      return bytes!;
    }

    await showThread(false);
    final resting = await pixels();
    await tester.pump(const Duration(seconds: 2));
    expect(await pixels(), isNot(orderedEquals(resting)));
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
