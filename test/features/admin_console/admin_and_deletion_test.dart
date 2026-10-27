import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_analytics_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_audit_log_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_overview_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_risk_compliance_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_team_seats_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_approvals_page.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/presentation/pages/shared/delete_account_page.dart';

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

  test(
    'AdminConsoleRepository provisions INR seats, reviews orders, and logs SHA-256 audits',
    () async {
      final repo = AdminConsoleRepository.instance;
      final initialSeats = await repo.listTraderSeats();
      expect(initialSeats, isNotEmpty);

      final seat = await repo.inviteTraderSeat(
        displayName: 'Karan Oberoi',
        email: 'karan.oberoi@tradex.in',
        role: 'trader',
        deskDivision: 'Index & Options Desk',
        allocatedCapitalInr: 25000000,
        maxDrawdownLimitPct: 5.0,
      );
      expect(seat.allocatedCapitalInr, 25000000);

      final orders = await repo.listOrderApprovals();
      final pending = orders.firstWhere((o) => o.status == 'pending');
      final reviewed = await repo.reviewOrderApproval(
        orderId: pending.id,
        approve: true,
        notes: 'Approved in unit test.',
      );
      expect(reviewed.status, 'approved');

      final audits = await repo.listAuditLogs();
      expect(audits.first.action, 'PRE_TRADE_ORDER_APPROVED');
      expect(audits.first.sha256Hash.length, 64);
    },
  );

  test(
    'Account deletion conditional data purge supports immediate and 30-day grace conditions',
    () async {
      final profileRepo = ProfileSettingsRepositoryImpl();
      final graceReq = await profileRepo.requestAccountDeletion(
        reason: 'Switching trading strategy / platform',
        feedback: 'Testing 30-day grace condition',
        dataPurgeCondition: 'after_30_day_grace',
        purgeJournalsNotesStrategies: true,
        purgeCommunityMessages: true,
        purgeAiWorkspace: true,
        purgeAffiliateCampaigns: false,
        exportBeforeDelete: true,
        userRole: 'customer',
      );
      expect(graceReq.status, 'grace_period');

      final purged = await AdminConsoleRepository.instance
          .processDeletionRequest(
            requestId: graceReq.id,
            action: 'execute_purge',
            adminNotes: 'Executed conditional purge in test',
          );
      expect(purged.status, 'data_purged');
    },
  );

  for (final width in <double>[390.0, 768.0, 1440.0]) {
    for (final pageName in <String>[
      'admin_overview',
      'admin_team_seats',
      'admin_risk',
      'admin_audit',
      'admin_analytics',
      'affiliate_approvals',
      'delete_customer',
      'delete_affiliate',
      'delete_admin',
    ]) {
      testWidgets('$pageName renders responsively at ${width.toInt()}px', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final Widget page = switch (pageName) {
          'admin_overview' => const AdminOverviewPage(),
          'admin_team_seats' => const AdminTeamSeatsPage(),
          'admin_risk' => const AdminRiskCompliancePage(),
          'admin_audit' => const AdminAuditLogPage(),
          'admin_analytics' => const AdminAnalyticsPage(),
          'affiliate_approvals' => const AffiliateApprovalsPage(),
          'delete_customer' => const DeleteAccountPage(
            userRole: UserRole.customer,
          ),
          'delete_affiliate' => const DeleteAccountPage(
            userRole: UserRole.affiliate,
          ),
          _ => const DeleteAccountPage(userRole: UserRole.userAdmin),
        };

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
        await settle(tester);
        expect(find.byType(UiSkeleton), findsNothing);
        expect(tester.takeException(), isNull);

        final scrollable = find.byType(SingleChildScrollView);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -600));
          await settle(tester);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
