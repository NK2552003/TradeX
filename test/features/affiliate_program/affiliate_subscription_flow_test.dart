import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/data/app_session.dart';
import 'package:alphajournal/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:alphajournal/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/models/pricing_models.dart';
import 'package:alphajournal/features/auth/presentation/pages/signup_page.dart';
import 'package:alphajournal/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:alphajournal/features/settings/models/billing_models.dart';
import 'package:alphajournal/features/settings/presentation/pages/trader/billing_settings_page.dart';
import 'package:alphajournal/features/settings/presentation/pages/trader/change_plan_page.dart';
import 'package:alphajournal/features/settings/presentation/pages/trader/trader_affiliate_perks_page.dart';

class _MockBillingRepo implements BillingSettingsRepository {
  _MockBillingRepo({this.tier = AppTier.free, this.milestone});

  final AppTier tier;
  final AffiliateMilestoneStatus? milestone;

  String? lastValidatedCode;
  String? lastCheckoutReferralCode;

  @override
  Future<SubscriptionSummary> getSubscription() async => SubscriptionSummary(
    tier: tier,
    status: tier == AppTier.free ? 'canceled' : 'active',
    billingCycle: 'monthly',
    renewedAt: DateTime(2026, 11, 1),
    expiresAt: DateTime(2026, 12, 1),
    monthlyAmount: switch (tier) {
      AppTier.free => 0,
      AppTier.premium => 299,
      AppTier.enterprise => 499,
    },
    annualMonthsBilled: 12,
    usage: const <String, dynamic>{},
    affiliateMilestone: milestone,
  );

  @override
  Future<AffiliateMilestoneStatus> getAffiliateMilestoneStatus() async =>
      milestone ??
      const AffiliateMilestoneStatus(
        isAffiliate: false,
        paidReferralsCount: 0,
      );

  @override
  Future<ReferralDiscountQuote> validateReferralCode({
    required String code,
    required String tierId,
    required String billingCycle,
  }) async {
    lastValidatedCode = code;
    if (milestone?.isAffiliate == true) {
      return const ReferralDiscountQuote(
        valid: false,
        isAffiliateBlocked: true,
        errorCode: 'affiliate_coupon_prohibited',
        message:
            'Affiliate accounts cannot redeem their own or other partners\' referral or coupon codes.',
      );
    }
    if (code.toUpperCase() == 'PARTNER26' && billingCycle == 'monthly') {
      final bool isPro = tierId == 'tier_enterprise' || tierId == 'enterprise';
      return ReferralDiscountQuote(
        valid: true,
        code: 'PARTNER26',
        listAmountInr: isPro ? 499 : 299,
        discountInr: isPro ? 100 : 60,
        payableAmountInr: isPro ? 399 : 239,
        renewalAmountInr: isPro ? 499 : 299,
        appliesDiscount: true,
        message: isPro
            ? 'Referral applied: ₹399 for Month 1 (₹100 off), then ₹499/mo from Month 2.'
            : 'Referral applied: ₹239 for Month 1 (₹60 off), then ₹299/mo from Month 2.',
      );
    }
    return const ReferralDiscountQuote(
      valid: false,
      errorCode: 'invalid_code',
      message: 'Referral code not found.',
    );
  }

  @override
  Future<CheckoutSession> startCheckout(
    String tierId,
    String billingCycle, {
    String? referralCode,
  }) async {
    lastCheckoutReferralCode = referralCode;
    throw StateError('Test intercepted checkout');
  }

  @override
  Future<PaymentMethodSummary?> getPaymentMethod() async => null;

  @override
  Future<RetentionOffer?> getRetentionOffer() async => null;

  @override
  Future<List<Invoice>> getBillingHistory() async => const <Invoice>[];

  @override
  Future<Invoice> getInvoice(String invoiceId) async =>
      throw StateError('No invoice');

  @override
  Future<List<AppPlan>> getAvailablePlans({bool annual = false}) async =>
      const <AppPlan>[];

  @override
  Future<CheckoutSession> startPaymentMethodUpdate() async =>
      throw StateError('Unsupported');

  @override
  Future<bool> verifyCheckout({
    required String subscriptionId,
    String? paymentId,
    String? signature,
  }) async => true;

  @override
  Future<void> cancelSubscription({String? reason}) async {}

  @override
  Future<SubscriptionSummary> setCancelAtPeriodEnd(bool cancel) =>
      getSubscription();

  @override
  Future<int?> redeemCoupon(String code) async => null;
}

class _MockPricingRepo implements SubscriptionPricingRepository {
  @override
  Future<PricingCatalogueResponse> getPricingCatalogue({
    bool annual = false,
  }) async {
    return PricingCatalogueResponse(
      plans: <PricingPlanModel>[
        PricingPlanModel(
          id: 'tier_free',
          tier: AppTier.free,
          name: 'Free',
          subtitle: 'Starter',
          monthlyAmount: 0,
          annualMonthlyAmount: 0,
          currencySymbol: '₹',
          featuresSummary: const <String>['3 notes'],
          isPurchasable: true,
        ),
        PricingPlanModel(
          id: 'tier_pro',
          tier: AppTier.premium,
          name: 'Basic',
          subtitle: 'Full Markets & Messages',
          monthlyAmount: 299,
          annualMonthlyAmount: 239,
          currencySymbol: '₹',
          featuresSummary: const <String>['25 notes'],
          highlighted: true,
          isPurchasable: true,
        ),
        PricingPlanModel(
          id: 'tier_enterprise',
          tier: AppTier.enterprise,
          name: 'Pro',
          subtitle: 'Full Desk',
          monthlyAmount: 499,
          annualMonthlyAmount: 399,
          currencySymbol: '₹',
          featuresSummary: const <String>['10,000 notes'],
          isPurchasable: true,
        ),
      ],
      categories: const <PlanFeatureCategory>[],
      faqs: const <PricingFaqItem>[],
      annualDiscountPercent: 20,
      annualMonthsBilled: 12,
    );
  }

  @override
  Future<bool> selectPlan({
    required String tierId,
    required String billingCycle,
  }) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSession.instance.tier.value = AppTier.free;
    AppSession.instance.billingCycle = 'monthly';
  });

  testWidgets(
    'ChangePlanPage asks if user has a referral code and applies Month 1 ₹239 Basic Monthly discount',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final billingRepo = _MockBillingRepo();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangePlanPage(
              repository: billingRepo,
              pricingRepository: _MockPricingRepo(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Basic checkout dialog
      await tester.tap(find.text('Get Basic'));
      await tester.pumpAndSettle();

      expect(find.text('Do you have a referral code?'), findsOneWidget);
      expect(find.text('Confirm & Pay ₹299'), findsOneWidget);

      // Select "Yes, I have a code"
      await tester.tap(find.text('Yes, I have a code'));
      await tester.pumpAndSettle();

      // Enter referral code and tap Apply
      await tester.enterText(
        find.byKey(const ValueKey<String>('checkout-referral-input')),
        'PARTNER26',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('checkout-referral-apply-btn')),
      );
      await tester.pumpAndSettle();

      expect(billingRepo.lastValidatedCode, 'PARTNER26');
      expect(find.text('Confirm & Pay ₹239'), findsOneWidget);
      expect(find.textContaining('Month 1 only'), findsOneWidget);
      expect(
        find.textContaining('Renews at ₹299/mo from Month 2 onward.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ChangePlanPage blocks affiliate accounts from redeeming any referral or coupon code',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final billingRepo = _MockBillingRepo(
        milestone: const AffiliateMilestoneStatus(
          isAffiliate: true,
          paidReferralsCount: 12,
          complimentaryProUnlocked: false,
          currentCommissionInr: 10,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangePlanPage(
              repository: billingRepo,
              pricingRepository: _MockPricingRepo(),
              isAffiliate: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Basic'));
      await tester.pumpAndSettle();

      expect(find.text('Do you have a referral code?'), findsNothing);
      expect(find.text('Affiliate coupon restriction'), findsOneWidget);
      expect(
        find.textContaining('cannot redeem their own or other partners'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'BillingSettingsPage enforces no free Pro below 50 paid referrals and unlocks at 50+',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. Below 50 paid referrals: affiliate stays on Free with self-serve Change plan + milestone card
      final under50Repo = _MockBillingRepo(
        tier: AppTier.free,
        milestone: const AffiliateMilestoneStatus(
          isAffiliate: true,
          paidReferralsCount: 12,
          complimentaryProUnlocked: false,
          currentCommissionInr: 10,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillingSettingsPage(
              key: const ValueKey<String>('billing-under-50'),
              userRole: UserRole.affiliate,
              repository: under50Repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Free plan'), findsOneWidget);
      expect(find.text('Change plan'), findsOneWidget);
      expect(find.text('12 / 50 PAID'), findsOneWidget);
      expect(find.text('PARTNER PRO'), findsNothing);

      // 2. At 50+ paid referrals: complimentary Pro unlocked automatically
      final over50Repo = _MockBillingRepo(
        tier: AppTier.enterprise,
        milestone: const AffiliateMilestoneStatus(
          isAffiliate: true,
          paidReferralsCount: 52,
          complimentaryProUnlocked: true,
          currentCommissionInr: 30,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillingSettingsPage(
              key: const ValueKey<String>('billing-over-50'),
              userRole: UserRole.affiliate,
              repository: over50Repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pro plan · 50+ Partner Milestone'), findsOneWidget);
      expect(find.text('PARTNER PRO'), findsOneWidget);
      expect(find.text('52 / 50 PAID'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SignupPage prompts Customers for referral code and blocks referral input for Affiliates',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(
            key: const ValueKey<String>('signup-customer'),
            initialRole: UserRole.customer,
            onSignupSuccess: (_, _, {requiresVerification = false}) {},
            onNavigateToLogin: (_) {},
            onNavigateBack: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Do you have a referral code?'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('signup-has-referral-toggle')),
        findsOneWidget,
      );

      // Render as Affiliate role -> referral input replaced with Rev 2026.2-INR policy callout
      await tester.pumpWidget(
        MaterialApp(
          home: SignupPage(
            key: const ValueKey<String>('signup-affiliate'),
            initialRole: UserRole.affiliate,
            onSignupSuccess: (_, _, {requiresVerification = false}) {},
            onNavigateToLogin: (_) {},
            onNavigateBack: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Do you have a referral code?'), findsNothing);
      expect(
        find.text('Affiliate Program Terms (Rev 2026.2-INR)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TraderAffiliatePerksPage displays ₹10 -> ₹30 payout tiers and 50-user Free Pro milestone',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TraderAffiliatePerksPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('₹10 → ₹30 / USER'), findsOneWidget);
      expect(find.text('₹10 First 50 · ₹30 After 50'), findsOneWidget);
      expect(find.text('Free Pro at 50 Paid Users'), findsOneWidget);
      // Default slider = 25 traders -> 25 * ₹10 = ₹250, 25 more to unlock
      expect(find.text('₹250'), findsOneWidget);
      expect(find.text('25 more to unlock'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'AffiliateWorkspaceRepository exposes Revision 2026.2-INR terms and tiered payout schedule',
    () async {
      final repo = AffiliateWorkspaceRepository(demoOverride: true);
      final w = await repo.load();
      expect(w.terms.length, greaterThanOrEqualTo(6));
      expect(
        w.terms.every((t) => t.text('version') == '2026.2-INR'),
        isTrue,
      );
      expect(
        w.terms.any((t) => t.text('clause_code') == 'AFFILIATE-COUPON-BAN-03'),
        isTrue,
      );
      expect(
        w.terms.any((t) => t.text('clause_code') == 'FREE-PRO-MILESTONE-04'),
        isTrue,
      );
      expect(w.freeProThreshold, 50);
    },
  );
}
