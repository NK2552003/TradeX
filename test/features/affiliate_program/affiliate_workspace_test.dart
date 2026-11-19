import 'package:alphajournal/core/privacy/consent_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/config/customer_data_policy.dart';
import 'package:alphajournal/core/widgets/app_scaffold.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:alphajournal/features/affiliate_program/data/affiliate_attribution.dart';
import 'package:alphajournal/features/affiliate_program/presentation/pages/affiliate_overview_page.dart';
import 'package:alphajournal/features/affiliate_program/presentation/pages/affiliate_referrals_page.dart';
import 'package:alphajournal/features/affiliate_program/presentation/pages/affiliate_marketing_page.dart';
import 'package:alphajournal/features/affiliate_program/presentation/pages/affiliate_payouts_page.dart';
import 'package:alphajournal/features/settings/data/repositories/affiliate_settings_repository.dart';
import 'package:alphajournal/features/settings/presentation/pages/affiliate/affiliate_settings_page.dart';

class UnavailableRepository extends AffiliateWorkspaceRepository {
  @override
  Future<Never> load() async => throw StateError('offline');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test('demo is opt in and has no partner data in a regular session', () async {
    CustomerDataPolicy.allowDemo = false;
    expect((await AffiliateWorkspaceRepository().load()).enrolled, isFalse);
  });
  test(
    'campaigns persist across repository instances, with slug uniqueness',
    () async {
      final repo = AffiliateWorkspaceRepository(demoOverride: true);
      await repo.createCampaign('Launch', 'website', 'new-launch');
      final w = await AffiliateWorkspaceRepository(demoOverride: true).load();
      expect(w.campaigns.last.text('name'), 'Launch');
      expect(
        w.campaignUrl(w.campaigns.last),
        contains('utm_campaign=new-launch'),
      );
      await expectLater(
        repo.createCampaign('Duplicate', 'website', 'new-launch'),
        throwsStateError,
      );
      await expectLater(
        repo.createCampaign('Invalid', 'website', '../../x'),
        throwsArgumentError,
      );
      await repo.setCampaignStatus(w.campaigns.last.id, false);
      expect((await repo.load()).campaigns.last.text('status'), 'paused');
    },
  );
  test(
    'payout reserves balance and rejects duplicate, excess, precision and non-finite amounts',
    () async {
      final repo = AffiliateWorkspaceRepository(demoOverride: true);
      for (final amount in [
        999.0,
        64001.0,
        double.nan,
        double.infinity,
        1000.001,
      ]) {
        await expectLater(
          repo.requestPayout(amount),
          throwsA(anyOf(isA<StateError>(), isA<ArgumentError>())),
        );
      }
      expect((await repo.load()).profile.number('unpaid_balance'), 64000);
      await repo.requestPayout(20000);
      final w = await repo.load();
      expect(w.profile.number('unpaid_balance'), 44000);
      expect(w.payouts.first.text('status'), 'pending');
      await expectLater(repo.requestPayout(20000), throwsStateError);
      expect((await repo.load()).profile.number('unpaid_balance'), 44000);
    },
  );
  test(
    'settings persist into the workspace and reject invalid destinations',
    () async {
      final repo = AffiliateWorkspaceRepository(demoOverride: true);
      final settings = AffiliateSettingsRepositoryImpl(workspace: repo);
      await settings.updateCustomSlug('new-partner');
      await settings.updatePayoutSettings(
        payoutMethod: 'upi',
        payoutAccount: 'partner@bank',
        minimumThreshold: 1500,
        autoPayout: false,
      );
      final w = await repo.load();
      expect(w.referralUrl, endsWith('/r/new-partner'));
      expect(w.profile.number('minimum_payout_threshold'), 1500);
      expect(
        (await settings.getAffiliateSettings()).payoutAccount,
        'partner@bank',
      );
      await expectLater(
        settings.updatePayoutSettings(
          payoutMethod: 'paypal',
          payoutAccount: '',
          minimumThreshold: 1000,
          autoPayout: false,
        ),
        throwsArgumentError,
      );
    },
  );
  test('referral search, filters and CSV preserve the selected rows', () async {
    final w = await AffiliateWorkspaceRepository(demoOverride: true).load();
    final rows = w.filterReferrals('youtube', 'converted');
    expect(rows, hasLength(4));
    expect(w.filterReferrals('missing', 'all'), isEmpty);
    expect(referralCsv(rows, w.currency).split('\r\n'), hasLength(5));
  });

  test('simultaneous preview withdrawals reserve only once', () async {
    final repo = AffiliateWorkspaceRepository(demoOverride: true);
    final results = await Future.wait([
      for (int i = 0; i < 2; i++)
        repo.requestPayout(20000).then((_) => true, onError: (_) => false),
    ]);
    expect(results.where((r) => r), hasLength(1));
    expect((await repo.load()).profile.number('unpaid_balance'), 44000);
  });
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
    for (final name in [
      'overview',
      'referrals',
      'marketing',
      'payouts',
      'settings',
    ]) {
      testWidgets('$name responsive at $width', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = AffiliateWorkspaceRepository(demoOverride: true);
        final page = switch (name) {
          'overview' => AffiliateOverviewPage(repository: repo),
          'referrals' => AffiliateReferralsPage(repository: repo),
          'marketing' => AffiliateMarketingPage(repository: repo),
          'payouts' => AffiliatePayoutsPage(repository: repo),
          _ => AffiliateSettingsPage(
            repository: AffiliateSettingsRepositoryImpl(workspace: repo),
          ),
        };
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
        await settle(tester);
        expect(find.byType(UiSkeleton), findsNothing);
        expect(tester.takeException(), isNull);
        final scroll = find.byType(SingleChildScrollView).first;
        await tester.drag(scroll, const Offset(0, -700));
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('referral attribution persists and rejects malformed links', () async {
    await ConsentController.instance.initialize();
    await ConsentController.instance.save(
      const ConsentPreferences(affiliate: true),
    );
    await AffiliateAttribution.capture('partner-alpha', 'weekly-news');
    expect((await AffiliateAttribution.load())?['code'], 'partner-alpha');
    await AffiliateAttribution.capture('../invalid', 'weekly-news');
    expect((await AffiliateAttribution.load())?['code'], 'partner-alpha');
    await AffiliateAttribution.clear();
    expect(await AffiliateAttribution.load(), isNull);
  });
  testWidgets('campaign creation and pause run through the actual controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = AffiliateWorkspaceRepository(demoOverride: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AffiliateMarketingPage(repository: repo)),
      ),
    );
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Product launch');
    await tester.enterText(find.byType(TextField).at(1), 'product-launch');
    await tester.tap(find.text('Create tracking link'));
    await settle(tester);
    final campaign = (await repo.load()).campaigns.last;
    expect(campaign.text('slug'), 'product-launch');
    expect(find.text('Product launch'), findsOneWidget);
    await tester.ensureVisible(find.text('Pause').first);
    await tester.tap(find.text('Pause').first);
    await settle(tester);
    expect(
      (await repo.load()).campaigns.where((c) => c.text('status') == 'paused'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'payout confirmation reserves funds and prevents a second request',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = AffiliateWorkspaceRepository(demoOverride: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AffiliatePayoutsPage(repository: repo)),
        ),
      );
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, '20000');
      await settle(tester);
      await tester.tap(find.text('Review payout request'));
      await settle(tester);
      expect(find.text('Confirm payout request'), findsOneWidget);
      await tester.tap(find.text('Confirm request'));
      await settle(tester);
      expect((await repo.load()).profile.number('unpaid_balance'), 44000);
      expect(find.text('A payout is in progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final page in [
    'overview',
    'referrals',
    'marketing',
    'payouts',
    'settings',
  ]) {
    testWidgets('$page fits narrow display with larger text', (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = AffiliateWorkspaceRepository(demoOverride: true);
      final child = switch (page) {
        'overview' => AffiliateOverviewPage(repository: repo),
        'referrals' => AffiliateReferralsPage(repository: repo),
        'marketing' => AffiliateMarketingPage(repository: repo),
        'payouts' => AffiliatePayoutsPage(repository: repo),
        _ => AffiliateSettingsPage(
          repository: AffiliateSettingsRepositoryImpl(workspace: repo),
        ),
      };
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -1000),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('affiliate workspace entry opens Partner Hub', (tester) async {
    CustomerDataPolicy.allowDemo = true;
    addTearDown(() => CustomerDataPolicy.allowDemo = false);
    await tester.pumpWidget(
      const MaterialApp(home: AppScaffold(userRole: UserRole.affiliate)),
    );
    await settle(tester);
    expect(find.byType(AffiliateOverviewPage), findsOneWidget);
    expect(find.text('Not available'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('load failure offers retry without sample data', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AffiliateOverviewPage(repository: UnavailableRepository()),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Workspace unavailable'), findsOneWidget);
    expect(find.text('Partner preview'), findsNothing);
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.text('Workspace unavailable'), findsOneWidget);
  });
  testWidgets('referral query changes directory results', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AffiliateReferralsPage(
            repository: AffiliateWorkspaceRepository(demoOverride: true),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'no-such-referral');
    await settle(tester);
    expect(
      find.text(
        'No matching referrals. Try another search or share a campaign.',
      ),
      findsOneWidget,
    );
  });
}
