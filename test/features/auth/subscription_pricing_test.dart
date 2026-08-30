import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/theme/app_tokens.dart';
import 'package:tradex/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:tradex/features/auth/models/pricing_models.dart';

void main() {
  group('Subscription Pricing Models & Repository Tests', () {
    late SubscriptionPricingRepository repository;

    setUp(() {
      repository = SubscriptionPricingRepositoryImpl();
    });

    test('PricingCatalogueResponse loads valid INR plans, matrix, and FAQs', () async {
      final PricingCatalogueResponse response =
          await repository.getPricingCatalogue(annual: true);

      expect(response.plans.length, 3);
      expect(response.categories.isNotEmpty, true);
      expect(response.faqs.isNotEmpty, true);
      expect(response.annualDiscountPercent, 20);

      // Verify Free Tier
      final PricingPlanModel freePlan = response.plans.firstWhere(
        (p) => p.tier == AppTier.free,
      );
      expect(freePlan.monthlyAmount, 0);
      expect(freePlan.priceLabel(isAnnual: true), '₹0');
      expect(freePlan.priceLabel(isAnnual: false), '₹0');

      // Verify Pro Tier
      final PricingPlanModel proPlan = response.plans.firstWhere(
        (p) => p.tier == AppTier.premium,
      );
      expect(proPlan.monthlyAmount, 2499);
      expect(proPlan.annualMonthlyAmount, 1999);
      expect(proPlan.priceLabel(isAnnual: true), '₹1,999');
      expect(proPlan.priceLabel(isAnnual: false), '₹2,499');
      expect(proPlan.highlighted, true);

      // Verify Enterprise Tier
      final PricingPlanModel entPlan = response.plans.firstWhere(
        (p) => p.tier == AppTier.enterprise,
      );
      expect(entPlan.monthlyAmount, 7999);
      expect(entPlan.annualMonthlyAmount, 6499);
      expect(entPlan.priceLabel(isAnnual: true), '₹6,499');
      expect(entPlan.priceLabel(isAnnual: false), '₹7,999');
    });

    test('PricingPlanModel serialization to and from JSON works symmetrically', () {
      const PricingPlanModel plan = PricingPlanModel(
        id: 'test_pro',
        tier: AppTier.premium,
        name: 'Pro Trader',
        subtitle: 'Quant edge',
        monthlyAmount: 2499,
        annualMonthlyAmount: 1999,
        currencySymbol: '₹',
        featuresSummary: <String>['Feature 1', 'Feature 2'],
        badgeLabel: 'HOT',
        highlighted: true,
      );

      final Map<String, dynamic> json = plan.toJson();
      final PricingPlanModel deserialized = PricingPlanModel.fromJson(json);

      expect(deserialized.id, plan.id);
      expect(deserialized.tier, plan.tier);
      expect(deserialized.name, plan.name);
      expect(deserialized.monthlyAmount, plan.monthlyAmount);
      expect(deserialized.annualMonthlyAmount, plan.annualMonthlyAmount);
      expect(deserialized.currencySymbol, plan.currencySymbol);
      expect(deserialized.featuresSummary, plan.featuresSummary);
      expect(deserialized.badgeLabel, plan.badgeLabel);
      expect(deserialized.highlighted, plan.highlighted);
    });

    test('PlanComparisonRow returns proper tier values', () {
      const PlanComparisonRow row = PlanComparisonRow(
        id: 'feat_test',
        title: 'Real-time Tick Data',
        freeValue: '15m Delayed',
        proValue: 'Live Tick',
        enterpriseValue: 'Ultra Low Latency',
      );

      expect(row.valueForTier(AppTier.free), '15m Delayed');
      expect(row.valueForTier(AppTier.premium), 'Live Tick');
      expect(row.valueForTier(AppTier.enterprise), 'Ultra Low Latency');
    });
  });
}
