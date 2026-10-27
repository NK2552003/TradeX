import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_audit_log_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_risk_compliance_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_team_seats_page.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_marketing_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_payouts_page.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_referrals_page.dart';
import 'package:tradex/features/settings/presentation/pages/admin/organization_settings_page.dart';
import '../../helpers/workspace_design_harness.dart';

Future<void> tapLabel(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settleWorkspace(tester);
  expect(tester.takeException(), isNull);
}

Future<void> enterField(WidgetTester tester, String label, String value) async {
  final field = find
      .descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is UiField && widget.label == label,
        ),
        matching: find.byType(TextField),
      )
      .last;
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await settleWorkspace(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadWorkspaceFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CustomerDataPolicy.allowDemo = true;
  });
  tearDown(() => CustomerDataPolicy.allowDemo = false);
  for (final width in [390.0, 1440.0]) {
    testWidgets('seat form validates and persists at $width', (tester) async {
      await pumpWorkspace(
        tester,
        const AdminTeamSeatsPage(),
        width: width,
        paneWidth: width,
      );
      await tapLabel(tester, 'Provision Trader Seat');
      await tapLabel(tester, 'Provision Seat');
      expect(find.text('Check seat details'), findsOneWidget);
      await enterField(tester, 'Trader Full Name', 'Scripted desk member');
      await enterField(tester, 'Corporate Email', 'layout-$width@example.com');
      await enterField(tester, 'Allocated Capital Limit (INR ₹)', '500000');
      await captureWorkspace(tester, 'seat-dialog-${width.toInt()}');
      await tapLabel(tester, 'Provision Seat');
      expect(find.byType(UiDialog), findsNothing);
      final seats = await AdminConsoleRepository.instance.listTraderSeats();
      expect(
        seats.any(
          (seat) =>
              seat.email == 'layout-$width@example.com' &&
              seat.allocatedCapitalInr == 500000,
        ),
        isTrue,
      );
    });
    testWidgets('risk review dialog and filters at $width', (tester) async {
      await pumpWorkspace(
        tester,
        const AdminRiskCompliancePage(),
        width: width,
        paneWidth: width,
      );
      await tapLabel(tester, 'Approve');
      expect(find.byType(UiDialog), findsOneWidget);
      await captureWorkspace(tester, 'order-dialog-${width.toInt()}');
      await tapLabel(tester, 'Cancel');
      final approved = find.text('Approved').first;
      await tester.ensureVisible(approved);
      await tester.tap(approved);
      await settleWorkspace(tester);
      expect(tester.takeException(), isNull);
      await scrollWorkspace(tester);
    });
    testWidgets('audit timeline and proof dialog at $width', (tester) async {
      await pumpWorkspace(
        tester,
        const AdminAuditLogPage(),
        width: width,
        paneWidth: width,
      );
      await tapLabel(tester, 'Timeline');
      final timeline = find.byType(UiTimeline);
      await tester.ensureVisible(timeline);
      final item = find
          .descendant(of: timeline, matching: find.byType(Text))
          .first;
      await tester.tap(item);
      await settleWorkspace(tester);
      expect(find.byType(UiDialog), findsOneWidget);
      await captureWorkspace(tester, 'audit-proof-${width.toInt()}');
      await tapLabel(tester, 'Done');
    });
    testWidgets('campaign slug, copied payload and media at $width', (
      tester,
    ) async {
      final repository = AffiliateWorkspaceRepository(demoOverride: true);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpWorkspace(
        tester,
        AffiliateMarketingPage(repository: repository),
        width: width,
        paneWidth: width,
      );
      await enterField(tester, 'Campaign Name', 'N');
      await enterField(tester, 'Campaign Name', 'New partner launch');
      expect(
        tester
            .widget<UiInput>(
              find.descendant(
                of: find.byWidgetPredicate(
                  (widget) =>
                      widget is UiField && widget.label == 'UTM Campaign Slug',
                ),
                matching: find.byType(UiInput),
              ),
            )
            .value,
        'new-partner-launch',
      );
      await tapLabel(tester, 'Create tracking link');
      final workspace = await repository.load();
      expect(workspace.campaigns.last.text('slug'), 'new-partner-launch');
      await tapLabel(tester, 'Copy Base Link');
      expect(copied, workspace.referralUrl);
      final copy = find.text('Copy').first;
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await settleWorkspace(tester);
      expect(copied, workspace.campaignUrl(workspace.campaigns.first));
      final asset = find.text('Copy text with link').first;
      await tester.ensureVisible(asset);
      await tester.tap(asset);
      await settleWorkspace(tester);
      expect(
        copied,
        workspace.assets.first
            .text('body')
            .replaceAll('{link}', workspace.referralUrl),
      );
    });
    testWidgets('referral detail retains ID and return at $width', (
      tester,
    ) async {
      final repository = AffiliateWorkspaceRepository(demoOverride: true);
      await pumpWorkspace(
        tester,
        AffiliateReferralsPage(repository: repository),
        width: width,
        paneWidth: width,
      );
      final workspace = await repository.load();
      final id = find.text(workspace.referrals.first.id);
      await tester.ensureVisible(id);
      await tester.tap(id);
      await settleWorkspace(tester);
      expect(find.byType(UiDialog), findsOneWidget);
      await captureWorkspace(tester, 'referral-detail-${width.toInt()}');
      await tapLabel(tester, 'Close');
      expect(find.byType(AffiliateReferralsPage), findsOneWidget);
    });
    testWidgets(
      'payout review fits with keyboard and reserves funds at $width',
      (tester) async {
        final repository = AffiliateWorkspaceRepository(demoOverride: true);
        await pumpWorkspace(
          tester,
          AffiliatePayoutsPage(repository: repository),
          width: width,
          paneWidth: width,
        );
        final amount = find.byType(TextField).first;
        await tester.ensureVisible(amount);
        await tester.enterText(amount, '20000');
        await settleWorkspace(tester);
        await tapLabel(tester, 'Review payout request');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await settleWorkspace(tester);
        expect(tester.takeException(), isNull);
        await captureWorkspace(tester, 'payout-keyboard-${width.toInt()}');
        await tapLabel(tester, 'Confirm request');
        tester.view.resetViewInsets();
        await settleWorkspace(tester);
        expect(
          (await repository.load()).profile.number('unpaid_balance'),
          44000,
        );
        expect(find.text('A payout is in progress'), findsOneWidget);
      },
    );
    testWidgets('organization branding validates and saves at $width', (
      tester,
    ) async {
      await pumpWorkspace(
        tester,
        const OrganizationSettingsPage(),
        width: width,
        paneWidth: width,
      );
      await enterField(tester, 'Organization Display Name', '');
      await tapLabel(tester, 'Save Branding');
      expect(find.text('Check organization details'), findsOneWidget);
      await enterField(
        tester,
        'Organization Display Name',
        'Scripted Alpha Desk',
      );
      await tapLabel(tester, 'Save Branding');
      expect(find.text('Scripted Alpha Desk'), findsWidgets);
    });
  }
}
