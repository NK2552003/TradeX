/// Data model representing an affiliate profile & earnings in TraderHub TradeX.
class AffiliateProfileModel {
  const AffiliateProfileModel({
    required this.id,
    required this.affiliateCode,
    this.tier = 'standard',
    this.commissionRate = 0.15,
    this.totalReferrals = 0,
    this.activeReferrals = 0,
    this.totalEarnings = 0.0,
    this.unpaidBalance = 0.0,
    this.paidEarnings = 0.0,
    this.payoutMethod = 'bank_transfer',
    this.payoutDetails = const {},
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String affiliateCode;
  final String tier;
  final double commissionRate;
  final int totalReferrals;
  final int activeReferrals;
  final double totalEarnings;
  final double unpaidBalance;
  final double paidEarnings;
  final String payoutMethod;
  final Map<String, dynamic> payoutDetails;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AffiliateProfileModel.fromJson(Map<String, dynamic> json) {
    return AffiliateProfileModel(
      id: json['id'] as String,
      affiliateCode: json['affiliate_code'] as String,
      tier: json['tier'] as String? ?? 'standard',
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.15,
      totalReferrals: json['total_referrals'] as int? ?? 0,
      activeReferrals: json['active_referrals'] as int? ?? 0,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
      unpaidBalance: (json['unpaid_balance'] as num?)?.toDouble() ?? 0.0,
      paidEarnings: (json['paid_earnings'] as num?)?.toDouble() ?? 0.0,
      payoutMethod: json['payout_method'] as String? ?? 'bank_transfer',
      payoutDetails: json['payout_details'] is Map<String, dynamic>
          ? json['payout_details'] as Map<String, dynamic>
          : {},
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'affiliate_code': affiliateCode,
      'tier': tier,
      'commission_rate': commissionRate,
      'total_referrals': totalReferrals,
      'active_referrals': activeReferrals,
      'total_earnings': totalEarnings,
      'unpaid_balance': unpaidBalance,
      'paid_earnings': paidEarnings,
      'payout_method': payoutMethod,
      'payout_details': payoutDetails,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
