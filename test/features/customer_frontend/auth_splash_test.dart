import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:tradex/features/auth/presentation/pages/auth_wrapper.dart';
import 'package:tradex/features/auth/presentation/pages/login_page.dart';
import 'package:tradex/features/auth/presentation/pages/splash_screen.dart';

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
}
