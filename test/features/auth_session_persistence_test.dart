import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/auth/auth.dart';
import 'package:tradex/features/journal/ui/journal_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProfile = UserProfileModel(
    id: 'usr_test_trader_101',
    handle: '@pro_trader',
    email: 'pro.trader@tradex.com',
    displayName: 'Pro Trader',
    role: UserRole.customer,
    status: ProfileStatus.active,
    subscriptionTier: 'pro',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    AppSession.instance.reset();
  });

  Widget buildTestableWidget(Widget child, {Size size = const Size(1280, 800)}) {
    return UiApp(
      theme: UiTheme.dark(),
      builder: (context) => MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(size: size),
            child: Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('Authentication Session Persistence Tests', () {
    test('1. AuthSessionStorage correctly saves, reads, and clears sessions', () async {
      SharedPreferences.setMockInitialValues({});

      // Initially no session
      final initialProfile = await AuthSessionStorage.getStoredProfile();
      expect(initialProfile, isNull);

      // Save session
      await AuthSessionStorage.saveSession(
        profile: testProfile,
        token: 'mock_jwt_token_xyz',
      );

      final loadedProfile = await AuthSessionStorage.getStoredProfile();
      expect(loadedProfile, isNotNull);
      expect(loadedProfile?.id, testProfile.id);
      expect(loadedProfile?.email, testProfile.email);
      expect(loadedProfile?.handle, testProfile.handle);

      final token = await AuthSessionStorage.getStoredToken();
      expect(token, 'mock_jwt_token_xyz');

      // Clear session
      await AuthSessionStorage.clearSession();
      final clearedProfile = await AuthSessionStorage.getStoredProfile();
      expect(clearedProfile, isNull);
    });

    test('2. AuthSessionStorage saves and retrieves last visited destination', () async {
      SharedPreferences.setMockInitialValues({});

      await AuthSessionStorage.saveLastDestination('journal');
      final lastDest = await AuthSessionStorage.getLastDestination();
      expect(lastDest, 'journal');
    });

    testWidgets('3. AuthWrapper restores active session on reload without flashing login page', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Simulate a user who had previously logged in
      SharedPreferences.setMockInitialValues({
        'auth_session_user_id': testProfile.id,
        'auth_session_email': testProfile.email,
        'auth_session_role': testProfile.role.id,
        'auth_session_profile': jsonEncode(testProfile.toJson()),
        'auth_has_seen_onboarding': true,
      });

      // Pump AuthWrapper (simulating browser page reload)
      await tester.pumpWidget(
        buildTestableWidget(
          const AuthWrapper(),
        ),
      );

      // Initially renders loading screen (zero flash of login page)
      expect(find.byType(LoginPage), findsNothing);

      // Settle session restoration
      await tester.pumpAndSettle();

      // Successfully stays logged in and renders AppScaffold
      expect(find.byType(AppScaffold), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('4. AuthWrapper redirects to LoginPage when no session exists and onboarding was seen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'auth_has_seen_onboarding': true,
      });

      await tester.pumpWidget(
        buildTestableWidget(
          const AuthWrapper(),
        ),
      );

      await tester.pumpAndSettle();

      // Routes directly to login
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(AppScaffold), findsNothing);
    });

    testWidgets('5. Reloading on a protected subpage (e.g. journal) restores user on that exact page', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Simulate user who was on the Journal page when refreshing
      SharedPreferences.setMockInitialValues({
        'auth_session_user_id': testProfile.id,
        'auth_session_email': testProfile.email,
        'auth_session_role': testProfile.role.id,
        'auth_session_profile': jsonEncode(testProfile.toJson()),
        'app_scaffold_last_destination': 'journal',
        'auth_has_seen_onboarding': true,
      });

      await tester.pumpWidget(
        buildTestableWidget(
          const AuthWrapper(),
        ),
      );

      await tester.pumpAndSettle();

      // Confirms user is restored directly onto JournalScreen
      expect(find.byType(AppScaffold), findsOneWidget);
      expect(find.byType(JournalScreen), findsOneWidget);
    });
  });
}
