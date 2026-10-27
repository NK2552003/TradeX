import 'package:flutter/foundation.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';

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
    this.currency = 'INR',
    this.accountHolder = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.upiId = '',
    this.panNumber = '',
    this.gstin = '',
    this.gstRegistered = false,
    this.tdsRate = 0.05,
    this.termsVersionAccepted = '2026.1-INR',
    this.tiers = const <AffiliateRecord>[],
    this.terms = const <AffiliateRecord>[],
  });

  final String currency;
  final String referralCode;
  final String customSlug;
  final double commissionRate;
  final String tierName;
  final String
  payoutMethod; // 'upi' | 'bank_neft' | 'bank_imps' | 'bank_rtgs' | 'bank_transfer' | 'razorpay'
  final String payoutAccount;
  final double minimumPayoutThreshold; // ₹1,000.00 INR minimum
  final bool autoPayoutEnabled;
  final int totalReferrals;
  final double totalEarnings;
  final double pendingPayout;
  final String accountHolder;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String upiId;
  final String panNumber;
  final String gstin;
  final bool gstRegistered;
  final double tdsRate;
  final String termsVersionAccepted;
  final List<AffiliateRecord> tiers;
  final List<AffiliateRecord> terms;

  String get accountHolderName => accountHolder;
  String get upiVpa => upiId;
  bool get autoPayout => autoPayoutEnabled;

  factory AffiliateSettingsModel.mock() {
    return const AffiliateSettingsModel(
      currency: 'INR',
      referralCode: 'TRADEX-ALPHA-2026',
      customSlug: 'nitish-trades',
      commissionRate: 0.25,
      tierName: 'Tier 3 · Gold Pro Partner',
      payoutMethod: 'upi',
      payoutAccount: 'nitish.alpha@okhdfcbank',
      minimumPayoutThreshold: 1000.0,
      autoPayoutEnabled: true,
      totalReferrals: 18,
      totalEarnings: 184000.00,
      pendingPayout: 64000.00,
      accountHolder: 'Nitish Kumar',
      bankName: 'HDFC Bank',
      accountNumber: '50100482910421',
      ifscCode: 'HDFC0000240',
      upiId: 'nitish.alpha@okhdfcbank',
      panNumber: 'ABCDE1234F',
      gstin: '27ABCDE1234F1Z5',
      gstRegistered: true,
      tdsRate: 0.05,
      termsVersionAccepted: '2026.1-INR',
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
    String? accountHolder,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
    String? panNumber,
    String? gstin,
    bool? gstRegistered,
    double? tdsRate,
    String? termsVersionAccepted,
    List<AffiliateRecord>? tiers,
    List<AffiliateRecord>? terms,
  }) {
    return AffiliateSettingsModel(
      currency: currency,
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
      accountHolder: accountHolder ?? this.accountHolder,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      upiId: upiId ?? this.upiId,
      panNumber: panNumber ?? this.panNumber,
      gstin: gstin ?? this.gstin,
      gstRegistered: gstRegistered ?? this.gstRegistered,
      tdsRate: tdsRate ?? this.tdsRate,
      termsVersionAccepted: termsVersionAccepted ?? this.termsVersionAccepted,
      tiers: tiers ?? this.tiers,
      terms: terms ?? this.terms,
    );
  }

  factory AffiliateSettingsModel.fromJson(Map<String, dynamic> json) {
    return AffiliateSettingsModel(
      currency: 'INR',
      referralCode: json['referral_code'] as String? ?? '',
      customSlug: json['custom_slug'] as String? ?? '',
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.25,
      tierName: json['tier_name'] as String? ?? 'Tier 1 · Standard Partner',
      payoutMethod: json['payout_method'] as String? ?? 'upi',
      payoutAccount: json['payout_account'] as String? ?? '',
      minimumPayoutThreshold:
          (json['minimum_payout_threshold'] as num?)?.toDouble() ?? 1000.0,
      autoPayoutEnabled: json['auto_payout_enabled'] as bool? ?? true,
      totalReferrals: json['total_referrals'] as int? ?? 0,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
      pendingPayout: (json['pending_payout'] as num?)?.toDouble() ?? 0.0,
      accountHolder: json['account_holder'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      ifscCode: json['ifsc'] as String? ?? '',
      upiId: json['upi_id'] as String? ?? '',
      panNumber: json['pan'] as String? ?? '',
      gstin: json['gstin'] as String? ?? '',
      gstRegistered: json['gst_registered'] as bool? ?? false,
      tdsRate: (json['tds_rate'] as num?)?.toDouble() ?? 0.05,
      termsVersionAccepted:
          json['terms_version_accepted'] as String? ?? '2026.1-INR',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currency': currency,
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
      'account_holder': accountHolder,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc': ifscCode,
      'upi_id': upiId,
      'pan': panNumber,
      'gstin': gstin,
      'gst_registered': gstRegistered,
      'tds_rate': tdsRate,
      'terms_version_accepted': termsVersionAccepted,
    };
  }
}
