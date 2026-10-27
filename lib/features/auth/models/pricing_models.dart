import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/theme/app_tokens.dart';

/// Single subscription plan model for hejournal.in pricing catalogue.
@immutable
class PricingPlanModel {
  const PricingPlanModel({
    required this.id,
    required this.tier,
    required this.name,
    required this.subtitle,
    required this.monthlyAmount,
    required this.annualMonthlyAmount,
    required this.currencySymbol,
    required this.featuresSummary,
    this.badgeLabel,
    this.highlighted = false,
    this.isCurrent = false,
    this.ctaLabel = 'Get Started',
    this.isPurchasable = true,
  });

  final String id;
  final AppTier tier;
  final String name;
  final String subtitle;
  final double monthlyAmount;
  final double annualMonthlyAmount;
  final String currencySymbol;
  final List<String> featuresSummary;
  final String? badgeLabel;
  final bool highlighted;
  final bool isCurrent;
  final String ctaLabel;
  final bool isPurchasable;

  /// Price formatted according to billing cycle.
  String priceLabel({required bool isAnnual}) {
    final double amount = isAnnual ? annualMonthlyAmount : monthlyAmount;
    if (amount <= 0) return '${currencySymbol}0';
    return '$currencySymbol${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  /// Billing period subtext.
  String periodLabel({required bool isAnnual}) {
    if (monthlyAmount <= 0) return 'free forever';
    return isAnnual
        ? 'per month, billed annually'
        : 'per month, billed monthly';
  }

  factory PricingPlanModel.fromJson(Map<String, dynamic> json) {
    return PricingPlanModel(
      id: json['id'] as String? ?? 'free',
      tier: AppTier.values.firstWhere(
        (t) => t.name == (json['tier'] as String?),
        orElse: () => AppTier.free,
      ),
      name: json['name'] as String? ?? 'Free',
      subtitle: json['subtitle'] as String? ?? '',
      monthlyAmount: (json['monthly_amount'] as num?)?.toDouble() ?? 0.0,
      annualMonthlyAmount:
          (json['annual_monthly_amount'] as num?)?.toDouble() ?? 0.0,
      currencySymbol: json['currency_symbol'] as String? ?? '₹',
      featuresSummary:
          (json['features_summary'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      badgeLabel: json['badge_label'] as String?,
      highlighted: json['highlighted'] as bool? ?? false,
      isCurrent: json['is_current'] as bool? ?? false,
      ctaLabel: json['cta_label'] as String? ?? 'Get Started',
      isPurchasable: json['is_purchasable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tier': tier.name,
    'name': name,
    'subtitle': subtitle,
    'monthly_amount': monthlyAmount,
    'annual_monthly_amount': annualMonthlyAmount,
    'currency_symbol': currencySymbol,
    'features_summary': featuresSummary,
    'badge_label': badgeLabel,
    'highlighted': highlighted,
    'is_current': isCurrent,
    'cta_label': ctaLabel,
    'is_purchasable': isPurchasable,
  };
}

/// Single row in the feature comparison matrix across Free, Pro, and Enterprise.
@immutable
class PlanComparisonRow {
  const PlanComparisonRow({
    required this.id,
    required this.title,
    this.tooltip,
    required this.freeValue,
    required this.proValue,
    required this.enterpriseValue,
    this.isBoolean = false,
  });

  final String id;
  final String title;
  final String? tooltip;
  final dynamic freeValue;
  final dynamic proValue;
  final dynamic enterpriseValue;
  final bool isBoolean;

  dynamic valueForTier(AppTier tier) => switch (tier) {
    AppTier.free => freeValue,
    AppTier.premium => proValue,
    AppTier.enterprise => enterpriseValue,
  };

  factory PlanComparisonRow.fromJson(Map<String, dynamic> json) {
    return PlanComparisonRow(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      tooltip: json['tooltip'] as String?,
      freeValue: json['free_value'],
      proValue: json['pro_value'],
      enterpriseValue: json['enterprise_value'],
      isBoolean: json['is_boolean'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'tooltip': tooltip,
    'free_value': freeValue,
    'pro_value': proValue,
    'enterprise_value': enterpriseValue,
    'is_boolean': isBoolean,
  };
}

/// Category grouping comparison rows (e.g. Core Trading, Journaling, AI, Risk).
@immutable
class PlanFeatureCategory {
  const PlanFeatureCategory({
    required this.id,
    required this.name,
    required this.rows,
  });

  final String id;
  final String name;
  final List<PlanComparisonRow> rows;

  factory PlanFeatureCategory.fromJson(Map<String, dynamic> json) {
    return PlanFeatureCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rows:
          (json['rows'] as List<dynamic>?)
              ?.map(
                (e) => PlanComparisonRow.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <PlanComparisonRow>[],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rows': rows.map((r) => r.toJson()).toList(),
  };
}

/// FAQ item categorized for pricing questions.
@immutable
class PricingFaqItem {
  const PricingFaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  final String id;

  /// 'all' | 'billing' | 'features' | 'enterprise'
  final String category;
  final String question;
  final String answer;

  factory PricingFaqItem.fromJson(Map<String, dynamic> json) {
    return PricingFaqItem(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'question': question,
    'answer': answer,
  };
}

/// Root data model response for the entire pricing & subscription catalogue.
@immutable
class PricingCatalogueResponse {
  const PricingCatalogueResponse({
    required this.plans,
    required this.categories,
    required this.faqs,
    this.copy = const {},
    this.annualDiscountPercent = 20,
    this.annualMonthsBilled = 10,
    this.footerDisclaimer =
        'Prices in INR (₹). Standard 18% GST itemized transparently at checkout. Cancel anytime.',
  });

  final List<PricingPlanModel> plans;
  final List<PlanFeatureCategory> categories;
  final List<PricingFaqItem> faqs;
  final Map<String, String> copy;
  String text(String key) => copy[key] ?? '';
  final int annualDiscountPercent;
  final int annualMonthsBilled;
  final String footerDisclaimer;

  factory PricingCatalogueResponse.fromJson(Map<String, dynamic> json) {
    return PricingCatalogueResponse(
      copy: (json['copy'] as Map? ?? {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      plans:
          (json['plans'] as List<dynamic>?)
              ?.map((e) => PricingPlanModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PricingPlanModel>[],
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map(
                (e) => PlanFeatureCategory.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <PlanFeatureCategory>[],
      faqs:
          (json['faqs'] as List<dynamic>?)
              ?.map((e) => PricingFaqItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PricingFaqItem>[],
      annualDiscountPercent: json['annual_discount_percent'] as int? ?? 20,
      annualMonthsBilled: json['annual_months_billed'] as int? ?? 10,
      footerDisclaimer: json['footer_disclaimer'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'copy': copy,
    'plans': plans.map((p) => p.toJson()).toList(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'faqs': faqs.map((f) => f.toJson()).toList(),
    'annual_discount_percent': annualDiscountPercent,
    'annual_months_billed': annualMonthsBilled,
    'footer_disclaimer': footerDisclaimer,
  };
}
