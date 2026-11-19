import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/navigation/role_navigation_config.dart';
import 'package:alphajournal/features/admin_console/models/admin_records.dart';
import 'package:alphajournal/features/admin_console/presentation/pages/admin_overview_page.dart';
import 'package:alphajournal/features/admin_console/presentation/pages/admin_records_page.dart';
import 'package:alphajournal/features/admin_console/presentation/pages/admin_settings_page.dart';
import 'package:alphajournal/features/admin_console/presentation/pages/admin_user_detail_page.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import '../../helpers/admin_repository_fixture.dart';
import '../../helpers/workspace_design_harness.dart';
import 'admin_affiliate_interaction_audit_test.dart' show tapLabel, enterField;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('admin requires authentication without sample metrics', (
    tester,
  ) async {
    await pumpWorkspace(tester, const AdminOverviewPage());
    expect(
      find.text('Sign in with an administrator account to continue.'),
      findsOneWidget,
    );
    expect(find.byType(UiMetricCard), findsNothing);
  });

  testWidgets('overview uses server totals and reloads its period', (
    tester,
  ) async {
    final repository = AdminRepositoryFixture();
    await pumpWorkspace(tester, AdminOverviewPage(repository: repository));
    expect(find.text('137'), findsOneWidget);
    expect(find.text('124'), findsOneWidget);
    expect(find.text('Content and account totals'), findsOneWidget);
    await tapLabel(tester, '7 days');
    await settleWorkspace(tester);
    expect(repository.overviewDays, 7);
    expect(find.text('Last 7 days'), findsWidgets);
  });

  test('admin navigation covers user-specific administration', () {
    final config = RoleNavigationConfig.forRole(UserRole.userAdmin);
    final ids = config.destinations.map((entry) => entry.id).toSet();
    expect(
      ids,
      containsAll([
        'org_team',
        'affiliate_reviews',
        'org_publishing',
        'admin_comments',
        'admin_subscriptions',
        'admin_notes',
        'admin_journal',
        'admin_strategies',
        'admin_messages',
        'admin_ai',
        'org_audit',
        'org_analytics',
        'admin_deletions',
      ]),
    );
    expect(
      ids.intersection({
        'notes',
        'strategies',
        'journal',
        'community',
        'org_risk',
      }),
      isEmpty,
    );
  });

  testWidgets('user details scope every resource to the selected account', (
    tester,
  ) async {
    final repository = AdminRepositoryFixture();
    await pumpWorkspace(
      tester,
      AdminRecordsPage(resource: AdminResource.users, repository: repository),
    );
    await tapLabel(tester, 'Details');
    for (final tab in [
      'Posts',
      'Notes',
      'Journal',
      'Strategies',
      'Messages',
      'AI',
      'Activity',
    ]) {
      final item = find.descendant(
        of: find.byType(UiTabs).first,
        matching: find.text(tab),
      );
      await tester.ensureVisible(item);
      await tester.tap(item);
      await settleWorkspace(tester);
      expect(repository.queries.last['userId'], AdminRepositoryFixture.userId);
    }
  });

  testWidgets('permission form validates and persists independent limits', (
    tester,
  ) async {
    final repository = AdminRepositoryFixture();
    await pumpWorkspace(
      tester,
      AdminUserDetailPage(
        userId: AdminRepositoryFixture.userId,
        repository: repository,
        onBack: () {},
        initialTab: 'Permissions',
      ),
    );
    await enterField(tester, 'Posts per day', '-1');
    await tapLabel(tester, 'Save permissions and limits');
    expect(
      find.text('Posts per day must be a whole number from 0 to 1000000.'),
      findsOneWidget,
    );
    expect(repository.changes, isEmpty);
    await enterField(tester, 'Posts per day', '2');
    await enterField(tester, 'AI requests per day', '0');
    await tapLabel(tester, 'Save permissions and limits');
    await enterField(
      tester,
      'Reason for this change',
      'Temporary publishing limits',
    );
    await tapLabel(tester, 'Confirm');
    final values = repository.changes.single['value'] as Map;
    expect(values['limits'], {'posts_per_day': 2, 'ai_queries_per_day': 0});
    expect(repository.changes.single['userId'], AdminRepositoryFixture.userId);
  });

  testWidgets('subscription override is expiring and separate from billing', (
    tester,
  ) async {
    final repository = AdminRepositoryFixture();
    await pumpWorkspace(
      tester,
      AdminUserDetailPage(
        userId: AdminRepositoryFixture.userId,
        repository: repository,
        onBack: () {},
        initialTab: 'Subscription',
      ),
    );
    final select = find.byType(UiSelect<String>);
    tester.widget<UiSelect<String>>(select).onChanged!('premium');
    await settleWorkspace(tester);
    await enterField(tester, 'Access duration (days)', '10');
    await tapLabel(tester, 'Save access override');
    await enterField(
      tester,
      'Reason for this change',
      'Support courtesy access',
    );
    await tapLabel(tester, 'Confirm');
    final values = repository.changes.single['value'] as Map;
    expect(values['tier'], 'premium');
    expect(
      DateTime.parse(values['expires_at'] as String).isAfter(DateTime.now()),
      isTrue,
    );
    expect(find.text('Use billing subscription'), findsOneWidget);
  });

  testWidgets('post moderation saves its record and returns to the list', (
    tester,
  ) async {
    final repository = AdminRepositoryFixture();
    await pumpWorkspace(
      tester,
      AdminRecordsPage(resource: AdminResource.posts, repository: repository),
    );
    await tapLabel(tester, 'Details');
    expect(find.text('31'), findsOneWidget);
    await tapLabel(tester, 'Approve');
    await enterField(tester, 'Reason for this change', 'Content reviewed');
    await tapLabel(tester, 'Confirm');
    expect(repository.changes.single['action'], 'moderate_post');
    expect(
      repository.changes.single['recordId'],
      AdminRepositoryFixture.recordId,
    );
    expect(find.text('Approve'), findsNothing);
    await tapLabel(tester, 'Back');
    expect(find.text('Approved'), findsOneWidget);
  });

  testWidgets('settings errors preserve unsaved choices for retry', (
    tester,
  ) async {
    final repository = AdminRepositoryFixture()..failWrites = true;
    await pumpWorkspace(tester, AdminSettingsPage(repository: repository));
    final toggle = find.byWidgetPredicate(
      (w) => w is UiSwitch && w.label == 'Use AI',
    );
    tester.widget<UiSwitch>(toggle).onChanged!(false);
    await settleWorkspace(tester);
    await tapLabel(tester, 'Save app settings');
    await enterField(tester, 'Reason for this change', 'Provider maintenance');
    await enterField(tester, 'Type SAVE to confirm', 'SAVE');
    await tapLabel(tester, 'Confirm');
    expect(find.text('Server rejected the change'), findsOneWidget);
    expect(repository.changes, isEmpty);
    repository.failWrites = false;
    await tapLabel(tester, 'Confirm');
    expect(repository.platformFeatures['ai'], false);
  });
}
