import 'package:flutter/foundation.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

@immutable
class SubscriptionSummary {
  const SubscriptionSummary({
    required this.tier,
    required this.status,
    required this.billingCycle,
    required this.renewedAt,
    required this.expiresAt,
    required this.usage,
    required this.monthlyAmount,
    required this.annualMonthsBilled,
    this.cancelAtPeriodEnd = false,
    this.discountCode,
    this.discountPercent = 0,
    this.affiliateMilestone,
  });

  final AppTier tier;

  /// 'active' | 'trialing' | 'canceled' | 'past_due'
  final String status;

  /// 'monthly' | 'annual'
  final String billingCycle;
  final DateTime renewedAt;
  final DateTime expiresAt;
  final Map<String, dynamic> usage;

  /// List price of [tier] per month, handed down by the repository from the plan
  /// catalogue. The model does not know prices — that keeps the number on an
  /// invoice and the number on a plan card the same number.
  final double monthlyAmount;

  /// Months charged on a yearly plan, also handed down rather than assumed, so
  /// the discount advertised on the plan chooser is the discount applied here.
  final int annualMonthsBilled;

  /// Set when the reader has cancelled but the paid period has not run out. The
  /// plan still applies until [expiresAt]; only renewal has stopped.
  final bool cancelAtPeriodEnd;

  /// Coupon currently applied to the subscription, if any.
  final String? discountCode;
  final int discountPercent;

  /// Affiliate 50-paid-referral Pro milestone status when the account is an affiliate.
  final AffiliateMilestoneStatus? affiliateMilestone;

  String get planName => AppTokens.tierLabel(tier);

  /// Months of a year an annual plan does not pay for.
  int get annualMonthsFree => 12 - annualMonthsBilled;

  /// The saving an annual plan represents, derived from the months actually
  /// billed. Surfaces read this instead of advertising a figure of their own, so
  /// the discount on a toggle is the discount on the invoice.
  int get annualSavingPercent => (annualMonthsFree / 12 * 100).round();

  /// Whether the account is billed yearly.
  bool get isAnnual => billingCycle == 'annual';

  /// Amount before any coupon for the current cycle.
  double get listAmount =>
      isAnnual ? monthlyAmount * annualMonthsBilled : monthlyAmount;

  /// Amount actually billed for the current cycle, coupon included.
  double get amount => listAmount * (1 - discountPercent / 100);

  /// What the coupon takes off the current cycle, as a positive number.
  double get discountAmount => listAmount - amount;

  /// Whether the plan is paid for now but will not renew.
  bool get endsAtPeriodEnd => cancelAtPeriodEnd || status == 'canceled';

  DateTime get currentPeriodEnd => expiresAt;
  int get tradesLoggedThisMonth => _count('journal_trades_used');
  int get maxTradesPerMonth => _count('journal_trades_limit');
  int get aiTokensUsed => _count('ai_queries_used');
  int get maxAiTokens => _count('ai_queries_limit');
  int get notesUsed => _count('notes_used');
  int get maxNotes => _count('notes_limit');
  int get livePlaybooksUsed => _count('live_playbooks_used');
  int get maxLivePlaybooks => _count('live_playbooks_limit');
  int get watchlistsUsed => _count('watchlists_used');
  int get maxWatchlists => _count('watchlists_limit');
  int get alertsUsed => _count('alerts_used');
  int get maxAlerts => _count('alerts_limit');
  int get communityPostsToday => _count('community_posts_today');
  int get maxCommunityPostsPerDay => _count('community_posts_per_day_limit');
  int get communityCommentsToday => _count('community_comments_today');
  int get maxCommunityCommentsPerDay =>
      _count('community_comments_per_day_limit');
  bool get allowPdfExport => usage['allow_pdf_export'] == true;
  bool get allowAdvancedBacktest => usage['allow_advanced_backtest'] == true;
  int get seatsUsed => _count('seats_used');
  int get maxSeats => _count('seats_limit');

  /// True when the plan covers more than the account holder — the point at
  /// which a seat meter is worth showing at all.
  bool get isMultiSeat => maxSeats > 1;

  /// A meter's fill for [used] out of [limit], safe when the plan is unmetered.
  static double fraction(int used, int limit) =>
      limit <= 0 ? 0 : (used / limit).clamp(0, 1).toDouble();

  int _count(String key) => (usage[key] as int?) ?? 0;

  SubscriptionSummary copyWith({
    AppTier? tier,
    String? status,
    String? billingCycle,
    DateTime? renewedAt,
    DateTime? expiresAt,
    Map<String, dynamic>? usage,
    double? monthlyAmount,
    int? annualMonthsBilled,
    bool? cancelAtPeriodEnd,
    String? discountCode,
    int? discountPercent,
    AffiliateMilestoneStatus? affiliateMilestone,
  }) => SubscriptionSummary(
    tier: tier ?? this.tier,
    status: status ?? this.status,
    billingCycle: billingCycle ?? this.billingCycle,
    renewedAt: renewedAt ?? this.renewedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    usage: usage ?? this.usage,
    monthlyAmount: monthlyAmount ?? this.monthlyAmount,
    annualMonthsBilled: annualMonthsBilled ?? this.annualMonthsBilled,
    cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
    discountCode: discountCode ?? this.discountCode,
    discountPercent: discountPercent ?? this.discountPercent,
    affiliateMilestone: affiliateMilestone ?? this.affiliateMilestone,
  );
}

/// The discount an account can be offered instead of cancelling.
///
/// It names a real coupon code, so the saving a retention dialog quotes is the
/// saving redeeming it will actually apply — the dialog does not get to invent
/// a number.
@immutable
class RetentionOffer {
  const RetentionOffer({
    required this.code,
    required this.discountPercent,
    required this.cycles,
  });

  final String code;
  final int discountPercent;

  /// Billing periods the discount runs for.
  final int cycles;
}

@immutable
class PaymentMethodSummary {
  const PaymentMethodSummary({
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
  });

  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
}

@immutable
class CheckoutSession {
  const CheckoutSession({
    required this.sessionId,
    required this.url,
    required this.checkoutUrl,
    this.clientSecret,
    this.keyId,
    this.amountPaise,
    this.discountPaise = 0,
    this.referralCode,
    this.replacesSubscriptionId,
  });

  final String sessionId;
  final String url;
  final String checkoutUrl;
  final String? clientSecret;
  final String? keyId;
  final int? amountPaise;
  final int discountPaise;
  final String? referralCode;
  final String? replacesSubscriptionId;
}

/// Server-validated affiliate referral quote for a target paid plan and cycle.
///
/// Subscriber discounts apply to Monthly plans only (Month 1 only):
/// - Basic Monthly: ₹299 -> ₹239 (-₹60), then ₹299/mo from Month 2
/// - Pro Monthly:   ₹499 -> ₹399 (-₹100), then ₹499/mo from Month 2
/// - Annual plans:  already include 20% discount; referral attributes partner.
@immutable
class ReferralDiscountQuote {
  const ReferralDiscountQuote({
    required this.valid,
    required this.message,
    this.code,
    this.listAmountInr = 0,
    this.discountInr = 0,
    this.payableAmountInr = 0,
    this.renewalAmountInr = 0,
    this.appliesDiscount = false,
    this.errorCode,
    this.isAffiliateBlocked = false,
    this.validUntil,
    this.offerConfigured = true,
  });

  final bool valid;
  final String message;
  final String? code;
  final double listAmountInr;
  final double discountInr;
  final double payableAmountInr;
  final double renewalAmountInr;
  final bool appliesDiscount;
  final String? errorCode;
  final bool isAffiliateBlocked;
  final DateTime? validUntil;
  final bool offerConfigured;

  factory ReferralDiscountQuote.fromJson(Map<String, dynamic> json) {
    return ReferralDiscountQuote(
      valid: json['valid'] == true,
      message:
          json['message']?.toString() ??
          json['error']?.toString() ??
          'Unable to validate referral code.',
      code: json['code']?.toString(),
      listAmountInr: (json['list_amount_inr'] as num?)?.toDouble() ?? 0,
      discountInr: (json['discount_inr'] as num?)?.toDouble() ?? 0,
      payableAmountInr: (json['payable_amount_inr'] as num?)?.toDouble() ?? 0,
      renewalAmountInr: (json['renewal_amount_inr'] as num?)?.toDouble() ?? 0,
      appliesDiscount: json['applies_discount'] == true,
      errorCode: json['error_code']?.toString(),
      isAffiliateBlocked:
          json['is_affiliate_blocked'] == true ||
          json['error_code']?.toString() == 'affiliate_coupon_prohibited',
      validUntil: json['valid_until'] == null
          ? null
          : DateTime.tryParse(json['valid_until'].toString()),
      offerConfigured: json['offer_configured'] != false,
    );
  }
}

/// Server-backed progress toward the 50-paid-referral complimentary Pro milestone.
@immutable
class AffiliateMilestoneStatus {
  const AffiliateMilestoneStatus({
    required this.isAffiliate,
    required this.paidReferralsCount,
    this.threshold = 50,
    this.complimentaryProUnlocked = false,
    this.currentCommissionInr = 10,
  });

  final bool isAffiliate;
  final int paidReferralsCount;
  final int threshold;
  final bool complimentaryProUnlocked;
  final double currentCommissionInr;

  int get remainingForFreePro =>
      (threshold - paidReferralsCount).clamp(0, threshold);
  double get progress =>
      threshold <= 0 ? 1.0 : (paidReferralsCount / threshold).clamp(0.0, 1.0);
}

/// The entity that raised an invoice: who is charging, from where, and under
/// what tax registration.
///
/// It travels on the [Invoice] rather than being written into the receipt
/// layout, because the company a charge comes from is a fact of the billing
/// account — a reseller or a second legal entity issues under its own name.
@immutable
class InvoiceIssuer {
  const InvoiceIssuer({
    required this.name,
    required this.addressLines,
    required this.supportEmail,
    this.taxId,
    this.taxLabel = 'Tax',
  });

  final String name;
  final List<String> addressLines;
  final String supportEmail;

  /// Registration the tax is collected under (a GSTIN, VAT or EIN), shown on
  /// the receipt when the issuer has one.
  final String? taxId;

  /// What the tax line is called where the issuer trades — 'GST', 'VAT', 'Sales
  /// tax'. Named by the data so the receipt does not assume a jurisdiction.
  final String taxLabel;
}

@immutable
class Invoice {
  Invoice({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    DateTime? createdAt,
    DateTime? issuedAt,
    required this.pdfUrl,
    this.lineItems = const <InvoiceLineItem>[],
    this.issuer,
    this.taxPercent = 0,
    this.paymentMethodLabel,
  }) : createdAt = createdAt ?? issuedAt ?? DateTime.now();

  final String id;

  /// Total charged, tax included. Every other figure on a receipt is derived
  /// from this one so the breakdown can never add up to something else.
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final String pdfUrl;
  final List<InvoiceLineItem> lineItems;

  /// Who raised the charge. Null while a backend has not supplied one, in which
  /// case the receipt simply omits the letterhead.
  final InvoiceIssuer? issuer;

  /// Tax rate already included in [amount], as a percentage.
  final double taxPercent;

  /// The card or mandate the charge settled against, as the reader would
  /// recognise it ('Visa •••• 4242'). Null when it is not known.
  final String? paymentMethodLabel;

  DateTime get issuedAt => createdAt;

  /// What the line items add up to. Falls back to [amount] for an invoice that
  /// arrived without an itemisation.
  double get subtotal => lineItems.isEmpty
      ? amount
      : lineItems.fold<double>(
          0,
          (double sum, InvoiceLineItem item) =>
              sum + item.amount * item.quantity,
        );

  /// The charge with tax stripped out — the taxable value a receipt has to
  /// state separately from the tax collected on it.
  double get netAmount =>
      taxPercent <= 0 ? amount : amount / (1 + taxPercent / 100);

  /// Tax collected, as the difference between the total and its taxable value.
  /// Derived rather than multiplied out so the two lines always sum to [amount].
  double get taxAmount => amount - netAmount;
}

@immutable
class InvoiceLineItem {
  const InvoiceLineItem({
    required this.description,
    required this.amount,
    required this.quantity,
  });

  final String description;
  final double amount;
  final int quantity;
}
