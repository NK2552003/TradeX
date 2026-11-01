import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_analytics_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_audit_log_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_overview_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_risk_compliance_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_team_seats_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_application_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_approvals_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_marketing_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_overview_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_payouts_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_referrals_page.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_records_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_settings_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_user_detail_page.dart';
import 'package:tradex/features/admin_console/models/admin_records.dart';
import '../../helpers/admin_repository_fixture.dart';
import 'package:tradex/features/settings/presentation/pages/affiliate/affiliate_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/settings_root_page.dart';
import '../../helpers/workspace_design_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(loadWorkspaceFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CustomerDataPolicy.allowDemo = true;
  });
  tearDown(() => CustomerDataPolicy.allowDemo = false);
  final pages = <String, Widget Function()>{
    'admin-overview': () =>
        AdminOverviewPage(repository: AdminRepositoryFixture()),
    'admin-analytics': () =>
        AdminAnalyticsPage(repository: AdminRepositoryFixture()),
    'admin-risk': () =>
        AdminRiskCompliancePage(repository: AdminRepositoryFixture()),
    'admin-audit': () =>
        AdminAuditLogPage(repository: AdminRepositoryFixture()),
    'admin-governance': () =>
        AdminTeamSeatsPage(repository: AdminRepositoryFixture()),
    'admin-approvals': () =>
        AffiliateApprovalsPage(repository: AdminRepositoryFixture()),
    'admin-settings': () =>
        AdminSettingsPage(repository: AdminRepositoryFixture()),
    for (final resource in [
      AdminResource.posts,
      AdminResource.comments,
      AdminResource.subscriptions,
      AdminResource.notes,
      AdminResource.journal,
      AdminResource.strategies,
      AdminResource.messages,
      AdminResource.ai,
      AdminResource.aiRequests,
    ])
      'admin-${resource.name}': () => AdminRecordsPage(
        resource: resource,
        repository: AdminRepositoryFixture(),
      ),
    'affiliate-overview': () => const AffiliateOverviewPage(),
    'affiliate-referrals': () => const AffiliateReferralsPage(),
    'affiliate-campaigns': () => const AffiliateMarketingPage(),
    'affiliate-payouts': () => const AffiliatePayoutsPage(),
    'affiliate-settings': () => const AffiliateSettingsPage(),
    'affiliate-application': () => const AffiliateApplicationPage(
      userId: 'design-audit',
      email: 'audit@example.com',
      displayName: 'Design audit',
    ),
  };
  for (final target in [
    (name: 'phone', width: 320.0, pane: 320.0, scale: 1.5, dark: false),
    (name: 'tablet', width: 768.0, pane: 768.0, scale: 1.0, dark: false),
    (name: 'desktop', width: 1440.0, pane: 1440.0, scale: 1.0, dark: false),
    (name: 'narrow-pane', width: 1440.0, pane: 520.0, scale: 1.3, dark: true),
  ]) {
    for (final page in pages.entries) {
      testWidgets('${page.key} all content at ${target.name}', (tester) async {
        await pumpWorkspace(
          tester,
          page.value(),
          width: target.width,
          paneWidth: target.pane,
          textScale: target.scale,
          dark: target.dark,
        );
        expect(find.byType(UiSkeleton), findsNothing);
        await captureWorkspace(tester, '${page.key}-${target.name}');
        await scrollWorkspace(tester);
        await captureWorkspace(tester, '${page.key}-${target.name}-bottom');
      });
    }
    testWidgets('all user controls and records at ${target.name}', (
      tester,
    ) async {
      await pumpWorkspace(
        tester,
        AdminUserDetailPage(
          userId: AdminRepositoryFixture.userId,
          repository: AdminRepositoryFixture(),
          onBack: () {},
        ),
        width: target.width,
        paneWidth: target.pane,
        textScale: target.scale,
        dark: target.dark,
      );
      for (final tab in [
        'Permissions',
        'Subscription',
        'Affiliate',
        'Posts',
        'Notes',
        'Journal',
        'Strategies',
        'Messages',
        'AI',
        'Activity',
      ]) {
        final tabs = find.byType(UiTabs).first;
        final item = find.descendant(of: tabs, matching: find.text(tab));
        await tester.ensureVisible(item);
        await tester.tap(item);
        await settleWorkspace(tester);
        expect(tester.takeException(), isNull);
        await captureWorkspace(
          tester,
          'user-${tab.toLowerCase()}-${target.name}',
        );
        await scrollWorkspace(tester);
      }
    });
  }
  for (final role in [UserRole.userAdmin, UserRole.affiliate]) {
    for (final section in [
      'profile',
      'security',
      'notifications',
      'privacy',
      'appearance',
      'help',
    ]) {
      for (final width in [320.0, 1440.0]) {
        testWidgets('${role.name} shared settings $section at $width', (
          tester,
        ) async {
          await pumpWorkspace(
            tester,
            SettingsRootPage(userRole: role, initialSectionId: section),
            width: width,
            paneWidth: width,
          );
          await scrollWorkspace(tester);
        });
      }
    }
  }
}
