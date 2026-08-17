import 'package:flutter/foundation.dart';

@immutable
class AffiliateSettingsModel {
  const AffiliateSettingsModel({
    required this.referralCode,
    required this.customSlug,
    required this.commissionRate,
    required this.tierName,
    required this.payoutMethod,
    required this.payoutAccount,
    required this.minimumPayoutThreshold,
    required this.autoPayoutEnabled,
    required this.totalReferrals,
    required this.totalEarnings,
    required this.pendingPayout,
  });

  final String referralCode;
  final String customSlug;
  final double commissionRate; // e.g. 0.30 = 30%
  final String tierName; // 'Tier 2 - Gold Partner'
  final String payoutMethod; // 'paypal' | 'bank_wire' | 'stripe'
  final String payoutAccount; // 'nitish.affiliate@gmail.com'
  final double minimumPayoutThreshold; // $100.0
  final bool autoPayoutEnabled;
  final int totalReferrals;
  final double totalEarnings;
  final double pendingPayout;

  factory AffiliateSettingsModel.mock() {
    return const AffiliateSettingsModel(
      referralCode: 'TRADEX-ALPHA-2026',
      customSlug: 'nitish_alpha',
      commissionRate: 0.30,
      tierName: 'Tier 2 · Gold Partner',
      payoutMethod: 'upi',
      payoutAccount: 'nitish@okhdfcbank',
      minimumPayoutThreshold: 2500.0,
      autoPayoutEnabled: true,
      totalReferrals: 48,
      totalEarnings: 84500.00,
      pendingPayout: 14200.00,
    );
  }

  AffiliateSettingsModel copyWith({
    String? referralCode,
    String? customSlug,
    double? commissionRate,
    String? tierName,
    String? payoutMethod,
    String? payoutAccount,
    double? minimumPayoutThreshold,
    bool? autoPayoutEnabled,
    int? totalReferrals,
    double? totalEarnings,
    double? pendingPayout,
  }) {
    return AffiliateSettingsModel(
      referralCode: referralCode ?? this.referralCode,
      customSlug: customSlug ?? this.customSlug,
      commissionRate: commissionRate ?? this.commissionRate,
      tierName: tierName ?? this.tierName,
      payoutMethod: payoutMethod ?? this.payoutMethod,
      payoutAccount: payoutAccount ?? this.payoutAccount,
      minimumPayoutThreshold:
          minimumPayoutThreshold ?? this.minimumPayoutThreshold,
      autoPayoutEnabled: autoPayoutEnabled ?? this.autoPayoutEnabled,
      totalReferrals: totalReferrals ?? this.totalReferrals,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      pendingPayout: pendingPayout ?? this.pendingPayout,
    );
  }

  factory AffiliateSettingsModel.fromJson(Map<String, dynamic> json) {
    return AffiliateSettingsModel(
      referralCode: json['referral_code'] as String? ?? '',
      customSlug: json['custom_slug'] as String? ?? '',
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.30,
      tierName: json['tier_name'] as String? ?? 'Standard Affiliate',
      payoutMethod: json['payout_method'] as String? ?? 'paypal',
      payoutAccount: json['payout_account'] as String? ?? '',
      minimumPayoutThreshold:
          (json['minimum_payout_threshold'] as num?)?.toDouble() ?? 100.0,
      autoPayoutEnabled: json['auto_payout_enabled'] as bool? ?? true,
      totalReferrals: json['total_referrals'] as int? ?? 0,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
      pendingPayout: (json['pending_payout'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'referral_code': referralCode,
      'custom_slug': customSlug,
      'commission_rate': commissionRate,
      'tier_name': tierName,
      'payout_method': payoutMethod,
      'payout_account': payoutAccount,
      'minimum_payout_threshold': minimumPayoutThreshold,
      'auto_payout_enabled': autoPayoutEnabled,
      'total_referrals': totalReferrals,
      'total_earnings': totalEarnings,
      'pending_payout': pendingPayout,
    };
  }
}
