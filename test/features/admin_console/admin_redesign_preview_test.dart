import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/admin_console/models/admin_records.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_analytics_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_overview_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_record_detail_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_records_page.dart';
import 'package:tradex/features/admin_console/presentation/pages/admin_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/admin/desk_risk_page.dart';
import 'package:tradex/features/settings/presentation/pages/admin/organization_settings_page.dart';

import '../../helpers/admin_repository_fixture.dart';
import '../../helpers/workspace_design_harness.dart';

Future<void> _tapText(WidgetTester tester, String label) async {
  final finder = find.text(label).first;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settleWorkspace(tester);
}

void main() {
  setUpAll(loadWorkspaceFonts);

  testWidgets('overview renders donut, bar list, timeline, and chart switcher', (
    tester,
  ) async {
    final repository = AdminRepositoryFixture();
    await pumpWorkspace(tester, AdminOverviewPage(repository: repository));

    expect(find.byType(UiDonutChart), findsOneWidget);
    expect(find.byType(UiBarList), findsOneWidget);
    expect(find.byType(UiTimeline), findsOneWidget);
    expect(find.byType(UiAreaChart), findsOneWidget);

    await _tapText(tester, 'Bar');
    expect(find.byType(UiBarChart), findsOneWidget);
  });

  testWidgets('analytics page renders dedicated telemetry & tier breakdown', (
    tester,
  ) async {
    final repository = AdminRepositoryFixture();
    await pumpWorkspace(tester, AdminAnalyticsPage(repository: repository));

    expect(find.text('Product analytics'), findsOneWidget);
    expect(find.text('Telemetry pulse · Last 30 days'), findsOneWidget);
    expect(find.text('Subscription tier & role mix'), findsOneWidget);
    expect(find.text('AI throughput & moderation funnel'), findsOneWidget);
    expect(find.byType(UiStatStrip), findsOneWidget);
  });

  testWidgets('records panel switches Cards <-> Table and opens live Preview pane', (
    tester,
  ) async {
    final repository = AdminRepositoryFixture();
    await pumpWorkspace(
      tester,
      AdminRecordsPage(resource: AdminResource.posts, repository: repository),
      width: 1440,
    );

    expect(find.byType(UiCardGrid), findsWidgets);
    expect(find.text('Preview'), findsWidgets);

    // Clicking Preview on desktop opens the live side inspector pane
    await _tapText(tester, 'Preview');
    expect(find.text('Live Posts Preview'), findsOneWidget);
    expect(find.text('Full details'), findsOneWidget);

    // Switching to Table renders UiTable
    await _tapText(tester, 'Table');
    expect(find.byType(UiTable<AdminRecord>), findsOneWidget);
  });

  testWidgets('record detail renders live preview alongside details and history', (
    tester,
  ) async {
    final repository = AdminRepositoryFixture();
    await pumpWorkspace(
      tester,
      AdminRecordDetailPage(
        resource: AdminResource.posts,
        recordId: AdminRepositoryFixture.recordId,
        repository: repository,
        onBack: () {},
      ),
    );

    expect(find.text('Live preview'), findsOneWidget);
    expect(find.text('Record details'), findsOneWidget);
    expect(find.text('Recent record history'), findsOneWidget);
  });

  testWidgets('app settings shows live surface preview and dirty change counter', (
    tester,
  ) async {
    final repository = AdminRepositoryFixture();
    await pumpWorkspace(tester, AdminSettingsPage(repository: repository));

    expect(find.text('Live platform surface preview'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);

    final aiSwitch = find.byWidgetPredicate(
      (w) => w is UiSwitch && w.label == 'Use AI',
    );
    tester.widget<UiSwitch>(aiSwitch).onChanged!(false);
    await settleWorkspace(tester);

    expect(find.text('1 unsaved edits'), findsOneWidget);
    expect(find.text('Reset changes'), findsOneWidget);
  });

  testWidgets('desk risk page shows live execution gate simulator', (
    tester,
  ) async {
    await pumpWorkspace(tester, const DeskRiskPage());

    expect(find.text('Live Execution Gate Preview'), findsOneWidget);
    expect(find.text('Simulated Order Size'), findsOneWidget);
    expect(find.text('Auto-Execute Eligible'), findsOneWidget);

    // Turning off sample trader checklist when checklist is mandatory updates live verdict
    final checklistSwitch = find.byWidgetPredicate(
      (w) => w is UiSwitch && w.label == 'Sample trader checklist completed',
    );
    tester.widget<UiSwitch>(checklistSwitch).onChanged!(false);
    await settleWorkspace(tester);

    expect(find.text('Held for Pre-Trade Checklist'), findsOneWidget);
  });

  testWidgets('organization settings shows live draft preview as firm name changes', (
    tester,
  ) async {
    await pumpWorkspace(tester, const OrganizationSettingsPage());

    expect(find.text('Saved workspace'), findsOneWidget);
    final nameField = find.byType(EditableText).first;
    await tester.enterText(nameField, 'Apex Alpha Desk');
    await settleWorkspace(tester);

    expect(find.text('Live draft preview'), findsOneWidget);
    expect(find.text('Apex Alpha Desk'), findsWidgets);
  });
}
