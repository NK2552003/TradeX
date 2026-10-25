import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/navigation/role_navigation_config.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_analytics_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_overview_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_overview_page.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  group('Admin Console & Analytics Functional Verification', () {
    test('AdminConsoleRepository fallbackSnapshot returns valid non-empty snapshot', () {
      final repo = AdminConsoleRepository.instance;
      final snap = repo.fallbackSnapshot('1M');
      expect(snap.allocatedCapitalInr, greaterThan(0));
      expect(snap.points, isNotEmpty);
      expect(snap.divisions, isNotEmpty);
      expect(snap.subscriptionMrrInr, greaterThan(0));
      expect(snap.affiliateGeneratedArrInr, greaterThan(0));
    });

    testWidgets('AdminOverviewPage (Desk Console) renders fully populated and not empty', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdminOverviewPage())),
      );
      await settle(tester);

      expect(find.byType(UiSkeleton), findsNothing);
      expect(find.text('Institutional Desk Console'), findsOneWidget);
      expect(find.text('Allocated Desk Capital'), findsOneWidget);
      expect(find.text('Intraday Desk Net P&L'), findsOneWidget);
      expect(find.byType(UiAreaChart), findsOneWidget);
      expect(find.byType(UiDonutChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminAnalyticsPage renders fully populated charts and leaderboard table', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdminAnalyticsPage())),
      );
      await settle(tester);

      expect(find.byType(UiSkeleton), findsNothing);
      expect(find.text('Organization & Desk Analytics (INR ₹)'), findsOneWidget);
      expect(find.byType(UiAreaChart), findsOneWidget);
      expect(find.byType(UiBarChart), findsOneWidget);
      expect(find.byType(UiBarList), findsOneWidget);
      expect(find.byType(UiDonutChart), findsOneWidget);
      expect(find.text('Proprietary Trader Scorecard Leaderboard (INR ₹)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('Strict Role Separation: Admin navigation excludes trader-only notes and strategies', () {
      final adminConfig = RoleNavigationConfig.forRole(UserRole.userAdmin);
      final allAdminIds = adminConfig.destinations.map((e) => e.id).toSet();
      expect(allAdminIds.contains('notes'), isFalse);
      expect(allAdminIds.contains('strategies'), isFalse);
      expect(allAdminIds.contains('journal'), isFalse);
      expect(allAdminIds.contains('community'), isFalse);
      expect(adminConfig.notificationTargets.containsKey('Notes'), isFalse);
      expect(adminConfig.notificationTargets.containsKey('Community'), isFalse);
    });

    test('Strict Role Separation: Affiliate navigation excludes trader-only notes, strategies, and community', () {
      final affConfig = RoleNavigationConfig.forRole(UserRole.affiliate);
      final allAffIds = affConfig.destinations.map((e) => e.id).toSet();
      expect(allAffIds.contains('notes'), isFalse);
      expect(allAffIds.contains('strategies'), isFalse);
      expect(allAffIds.contains('journal'), isFalse);
      expect(allAffIds.contains('community'), isFalse);
      expect(affConfig.notificationTargets.containsKey('Notes'), isFalse);
      expect(affConfig.notificationTargets.containsKey('Community'), isFalse);
    });

    testWidgets('AppScaffold correctly routes workspace destination for Admin and Affiliate', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Admin with initialDestination 'workspace' lands on Institutional Desk Console
      await tester.pumpWidget(
        const MaterialApp(
          home: AppScaffold(
            userRole: UserRole.userAdmin,
            initialDestination: 'workspace',
          ),
        ),
      );
      await settle(tester);
      expect(find.byType(AdminOverviewPage), findsOneWidget);
      expect(find.text('Institutional Desk Console'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 2. Affiliate with initialDestination 'workspace' lands on Partner Hub
      await tester.pumpWidget(
        const MaterialApp(
          home: AppScaffold(
            userRole: UserRole.affiliate,
            initialDestination: 'workspace',
          ),
        ),
      );
      await settle(tester);
      expect(find.byType(AffiliateOverviewPage), findsOneWidget);
      expect(find.text('Affiliate Partner Hub'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
