import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
import 'package:alphajournal/core/data/app_session.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:alphajournal/features/settings/models/billing_models.dart';
import 'package:alphajournal/features/settings/presentation/pages/trader/billing_settings_page.dart';

class _FakeBillingSettingsRepository implements BillingSettingsRepository {
  _FakeBillingSettingsRepository();

  @override
  Future<SubscriptionSummary> getSubscription() async {
    return SubscriptionSummary(
      tier: AppTier.free,
      status: 'active',
      billingCycle: 'monthly',
      renewedAt: DateTime(2026, 1, 1),
      expiresAt: DateTime(2026, 12, 31),
      monthlyAmount: 0,
      annualMonthsBilled: 12,
      usage: const <String, dynamic>{
        'notes': 1,
        'trades_this_month': 2,
        'live_playbooks': 0,
        'ai_tokens': 3,
        'seats': 1,
      },
    );
  }

  @override
  Future<PaymentMethodSummary?> getPaymentMethod() async => null;

  @override
  Future<RetentionOffer?> getRetentionOffer() async => null;

  @override
  Future<AffiliateMilestoneStatus> getAffiliateMilestoneStatus() async =>
      const AffiliateMilestoneStatus(
        isAffiliate: false,
        paidReferralsCount: 0,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CustomerLimitationsBanner & BillingSettingsPage Redesign', () {
    testWidgets(
      'CustomerLimitationsBanner renders UiDataPanel and UiStatStrip with 4 stats',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        AppSession.instance.tier.value = AppTier.free;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: CustomerLimitationsBanner(
                  noteCount: 1,
                  tradeCount: 4,
                  liveStrategyCount: 0,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should render UiDataPanel and UiStatStrip
        expect(find.byType(UiDataPanel), findsOneWidget);
        expect(find.byType(UiStatStrip), findsOneWidget);

        // Verify header title
        expect(
          find.text('CUSTOMER PLAN & WORKSPACE ALLOWANCES'),
          findsOneWidget,
        );

        // Verify all 8 quota metric cards are present
        expect(find.text('RESEARCH NOTES'), findsOneWidget);
        expect(find.text('JOURNAL TRADES'), findsOneWidget);
        expect(find.text('LIVE PLAYBOOKS'), findsOneWidget);
        expect(find.text('AI COPILOT QUERIES'), findsOneWidget);
        expect(find.text('WATCHLISTS'), findsOneWidget);
        expect(find.text('PRICE ALERTS'), findsOneWidget);
        expect(find.text('COMMUNITY POSTS / DAY'), findsOneWidget);
        expect(find.text('COMMENTS / DAY'), findsOneWidget);

        // Feature capability cards are omitted by default (e.g. on Workspace)
        expect(find.text('INCLUDED IN FREE'), findsNothing);
        expect(find.text('UNLOCK WITH UPGRADE'), findsNothing);
        expect(find.textContaining('PDF & CSV Exports'), findsNothing);
        expect(find.textContaining('Advanced Backtest'), findsNothing);

        // Verify upgrade plan button is present
        expect(find.widgetWithText(UiButton, 'Upgrade Plan'), findsOneWidget);
        final CustomerTierQuota freeQuota = CustomerTierQuota.forTier(
          AppTier.free,
        );
        final Finder planBadge = find.byWidgetPredicate(
          (Widget widget) =>
              widget is UiBadge &&
              widget.label ==
                  '${freeQuota.planName} Tier · ${freeQuota.priceLabel}',
        );
        expect(planBadge, findsOneWidget);
        final Rect panelRect = tester.getRect(find.byType(UiDataPanel));
        final Rect upgradeRect = tester.getRect(
          find.widgetWithText(UiButton, 'Upgrade Plan'),
        );
        expect(panelRect.right - upgradeRect.right, lessThan(36));
      },
    );

    testWidgets(
      'BillingSettingsPage renders CustomerLimitationsBanner data panel and feature cards outside the panel',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        AppSession.instance.tier.value = AppTier.free;
        final repo = _FakeBillingSettingsRepository();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(body: BillingSettingsPage(repository: repo)),
          ),
        );

        await tester.pumpAndSettle();

        // Should render CustomerLimitationsBanner
        expect(find.byType(CustomerLimitationsBanner), findsOneWidget);
        expect(find.byType(UiDataPanel), findsOneWidget);
        expect(find.byType(UiStatStrip), findsOneWidget);

        // Verify metric labels
        expect(find.text('RESEARCH NOTES'), findsOneWidget);
        expect(find.text('JOURNAL TRADES'), findsOneWidget);
        expect(find.text('LIVE PLAYBOOKS'), findsOneWidget);
        expect(find.text('AI COPILOT QUERIES'), findsOneWidget);
        expect(find.text('WATCHLISTS'), findsOneWidget);
        expect(find.text('PRICE ALERTS'), findsOneWidget);
        expect(find.text('COMMUNITY POSTS / DAY'), findsOneWidget);
        expect(find.text('COMMENTS / DAY'), findsOneWidget);

        // Verify feature cards are displayed on settings_billing and sit outside UiDataPanel
        expect(find.text('INCLUDED IN ALPHAJOURNAL FREE'), findsOneWidget);
        expect(find.text('UNLOCK WITH UPGRADE'), findsOneWidget);
        expect(find.textContaining('PDF & CSV Exports'), findsOneWidget);
        expect(find.textContaining('Advanced Backtest'), findsOneWidget);

        final Rect panelRect = tester.getRect(find.byType(UiDataPanel));
        final Rect includedHeaderRect = tester.getRect(
          find.text('INCLUDED IN ALPHAJOURNAL FREE'),
        );
        expect(includedHeaderRect.top, greaterThanOrEqualTo(panelRect.bottom));
      },
    );

    test(
      'BillingSettingsRepositoryImpl normalizes Basic and Pro tiers and rejects Free or invalid checkout attempts',
      () async {
        expect(
          BillingSettingsRepositoryImpl.normalizePaidTier('tier_pro'),
          'premium',
        );
        expect(
          BillingSettingsRepositoryImpl.normalizePaidTier('basic'),
          'premium',
        );
        expect(
          BillingSettingsRepositoryImpl.normalizePaidTier('premium'),
          'premium',
        );
        expect(
          BillingSettingsRepositoryImpl.normalizePaidTier('tier_enterprise'),
          'enterprise',
        );
        expect(
          BillingSettingsRepositoryImpl.normalizePaidTier('pro'),
          'enterprise',
        );
        expect(
          BillingSettingsRepositoryImpl.normalizePaidTier('enterprise'),
          'enterprise',
        );
        expect(
          BillingSettingsRepositoryImpl.normalizePaidTier('tier_free'),
          isNull,
        );
        expect(BillingSettingsRepositoryImpl.normalizePaidTier('free'), isNull);

        final repo = BillingSettingsRepositoryImpl();
        await expectLater(
          repo.startCheckout('tier_free', 'monthly'),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          repo.startCheckout('tier_pro', 'weekly'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'Plan-based verified tick rules: Free has no tick, Basic has Blue tick, Pro has Orange tick',
      () {
        final theme = UiTheme.dark();

        const freeAuthor = CommunityAuthor(
          id: 'u_free',
          handle: 'freetrader',
          displayName: 'Free Trader',
          userRole: UserRole.customer,
          tier: AppTier.free,
          subscriptionTier: 'free',
          verified: true, // Even if DB row had true, Free plan never shows tick
        );
        expect(freeAuthor.verified, isFalse);

        const basicAuthor = CommunityAuthor(
          id: 'u_basic',
          handle: 'basictrader',
          displayName: 'Basic Trader',
          userRole: UserRole.customer,
          tier: AppTier.premium,
          subscriptionTier: 'premium',
        );
        expect(basicAuthor.verified, isTrue);
        expect(basicAuthor.verifiedColor(theme), AppTokens.verifiedBasicBlue);

        const proAuthor = CommunityAuthor(
          id: 'u_pro',
          handle: 'protrader',
          displayName: 'Pro Trader',
          userRole: UserRole.customer,
          tier: AppTier.enterprise,
          subscriptionTier: 'enterprise',
        );
        expect(proAuthor.verified, isTrue);
        expect(proAuthor.verifiedColor(theme), AppTokens.verifiedProOrange);

        const freeTrader = AppTrader(
          id: 't_free',
          handle: 'freetrader',
          tier: AppTier.free,
          verified: true,
        );
        expect(freeTrader.verified, isFalse);

        const basicTrader = AppTrader(
          id: 't_basic',
          handle: 'basictrader',
          tier: AppTier.premium,
        );
        expect(basicTrader.verified, isTrue);
        expect(basicTrader.verifiedColor, AppTokens.verifiedBasicBlue);

        const proTrader = AppTrader(
          id: 't_pro',
          handle: 'protrader',
          tier: AppTier.enterprise,
        );
        expect(proTrader.verified, isTrue);
        expect(proTrader.verifiedColor, AppTokens.verifiedProOrange);
      },
    );
  });
}
