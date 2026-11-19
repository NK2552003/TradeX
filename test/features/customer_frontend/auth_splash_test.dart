import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/auth/presentation/pages/auth_wrapper.dart';
import 'package:alphajournal/features/auth/presentation/pages/login_page.dart';
import 'package:alphajournal/features/auth/presentation/pages/splash_screen.dart';

class DelayedPreferences extends InMemorySharedPreferencesStore {
  DelayedPreferences()
    : super.withData({'flutter.auth_has_seen_onboarding': true});
  final ready = Completer<void>();
  @override
  Future<Map<String, Object>> getAll() async {
    await ready.future;
    return super.getAll();
  }
}

void main() {
  testWidgets('splash reveals the thread along the visible edges', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final (size, platform, edgeCount) in [
      (const Size(1280, 800), TargetPlatform.macOS, 4),
      (const Size(390, 844), TargetPlatform.iOS, 2),
      (const Size(844, 390), TargetPlatform.android, 2),
    ]) {
      tester.view.physicalSize = size;
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: SplashScreen(onFinish: () => finished = true),
        ),
      );
      expect(find.byType(AlphaThread), findsNWidgets(edgeCount));
      final entrance = tester
          .widget<AlphaThread>(find.byType(AlphaThread).first)
          .reveal!;
      expect(entrance.value, 0.0);
      await tester.pump(const Duration(seconds: 2));
      expect(finished, isFalse);
      expect(entrance.value, inExclusiveRange(0, 1));
      await tester.pump(AlphaThread.pullDuration - const Duration(seconds: 2));
      expect(entrance.value, 1.0);
      await tester.pump(const Duration(milliseconds: 16));
      expect(finished, isTrue);

      final ribbons = tester
          .widgetList<AlphaThread>(find.byType(AlphaThread))
          .toList();
      expect(ribbons.map((ribbon) => ribbon.phase), [
        12.7,
        12.7 + 31.4,
        if (edgeCount == 4) ...[12.7 + 17.9, 12.7 + 64.2],
      ]);
      expect(ribbons.map((ribbon) => ribbon.scale).toSet(), hasLength(1));
      expect(ribbons.every((ribbon) => ribbon.thickness == 64), isTrue);
      final topRect = tester.getRect(find.byType(AlphaThread).first);
      expect(topRect.topLeft, Offset.zero);
      expect(topRect.width, size.width);
      if (edgeCount == 4) {
        final leftRect = tester.getRect(find.byType(AlphaThread).at(2));
        expect(leftRect.topLeft.distance, lessThan(0.001));
        expect(leftRect.height, closeTo(size.height, 0.001));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('reduced motion shows the complete thread on the first frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: SplashScreen(onFinish: () {}),
        ),
      ),
    );
    expect(find.byType(AlphaThread), findsNWidgets(2));
    final boundary = find.descendant(
      of: find.byType(AlphaThread).first,
      matching: find.byType(RepaintBoundary),
    );
    final top = tester.renderObject<RenderRepaintBoundary>(boundary);
    final hasInkOnRight = await tester.runAsync(() async {
      final image = await top.toImage();
      try {
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (var y = 0; y < image.height; y++) {
          for (var x = image.width ~/ 2; x < image.width; x++) {
            if (rgba.getUint8((y * image.width + x) * 4 + 3) > 0) return true;
          }
        }
        return false;
      } finally {
        image.dispose();
      }
    });
    expect(hasInkOnRight, isTrue);
  });

  testWidgets('splash stays visible until session restoration finishes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final previous = SharedPreferencesStorePlatform.instance;
    final delayed = DelayedPreferences();
    SharedPreferencesStorePlatform.instance = delayed;
    addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
    await tester.pumpWidget(const MaterialApp(home: AuthWrapper()));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byType(SplashScreen));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('Restoring secure session...'), findsNothing);
    delayed.ready.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('stalled session restoration exits the splash screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final previous = SharedPreferencesStorePlatform.instance;
    final delayed = DelayedPreferences();
    SharedPreferencesStorePlatform.instance = delayed;
    addTearDown(() => SharedPreferencesStorePlatform.instance = previous);

    await tester.pumpWidget(const MaterialApp(home: AuthWrapper()));
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 16));
    await tester.pump();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);

    delayed.ready.complete();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
