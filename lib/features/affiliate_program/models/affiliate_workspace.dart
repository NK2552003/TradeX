import 'package:flutter/foundation.dart';
import 'package:alphajournal/core/navigation/share_links.dart';

final RegExp affiliateSlugPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{2,39}$');
final RegExp affiliateCampaignSlugPattern = RegExp(
  r'^[a-z0-9][a-z0-9-]{2,39}$',
);
final RegExp affiliatePanPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
final RegExp affiliateIfscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
final RegExp affiliateGstinPattern = RegExp(
  r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
);

/// Formats a numeric value using the Indian numbering system (Lakhs / Crores)
/// with the `₹` Rupee symbol (e.g. `₹1,84,500.00` or `₹1,250`).
String formatInrAmount(
  num amount, {
  int decimals = 2,
  bool symbol = true,
  bool signed = false,
}) {
  final bool negative = amount < 0;
  final double absVal = amount.abs().toDouble();
  final String fixed = absVal.toStringAsFixed(decimals);
  final List<String> parts = fixed.split('.');
  final String intPart = parts[0];
  final String decPart = parts.length > 1 ? '.${parts[1]}' : '';

  String formattedInt;
  if (intPart.length <= 3) {
    formattedInt = intPart;
  } else {
    final String lastThree = intPart.substring(intPart.length - 3);
    final String rest = intPart.substring(0, intPart.length - 3);
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) {
        buf.write(',');
      }
      buf.write(rest[i]);
    }
    formattedInt = '${buf.toString()},$lastThree';
  }

  final String prefix = symbol ? '₹' : 'INR ';
  final String sign = negative ? '-' : (signed && amount > 0 ? '+' : '');
  return '$sign$prefix$formattedInt$decPart';
}

typedef AffiliatePayout = AffiliateRecord;

@immutable
class AffiliateRecord {
  const AffiliateRecord(this.data);
  final Map<String, Object?> data;

  String get id => text('id');
  String text(String key, [String fallback = '']) =>
      data[key]?.toString() ?? fallback;
  double number(String key) => (data[key] as num?)?.toDouble() ?? 0;
  int count(String key) => (data[key] as num?)?.toInt() ?? 0;
  bool flag(String key) => data[key] == true;
  DateTime? date(String key) => DateTime.tryParse(text(key));

  String get displayName => text(
    'display_name',
    text('full_name', text('affiliate_code', 'Partner')),
  );
  String get referralSlug => text('custom_slug').isNotEmpty
      ? text('custom_slug')
      : text('affiliate_code');
  String get tier => text('tier', 'standard');
  String get tierId => text('tier_code', text('tier', 'standard'));
  double get commissionRate =>
      number('commission_rate') > 0 ? number('commission_rate') : 0.25;
  double get lifetimeEarnings => number('total_earnings');
  double get unpaidBalance => number('unpaid_balance');
  double get totalPaidOut => number('paid_earnings');
  double get monthlyPrice => number('monthly_price_inr') > 0
      ? number('monthly_price_inr')
      : number('bonus_awarded');
  double get amount =>
      number('amount') > 0 ? number('amount') : number('gross_amount_inr');
  double get grossAmount => number('gross_amount_inr') > 0
      ? number('gross_amount_inr')
      : number('amount');
  double get tdsAmount => number('tds_amount_inr') > 0
      ? number('tds_amount_inr')
      : double.parse((grossAmount * 0.05).toStringAsFixed(2));
  double get netAmount => number('net_amount_inr') > 0
      ? number('net_amount_inr')
      : double.parse((grossAmount - tdsAmount).toStringAsFixed(2));
  String get methodLabel =>
      text('payout_method', 'upi').toUpperCase().replaceAll('_', ' ');
  String get destination {
    final Map<String, Object?> dest = map('payout_destination');
    return dest['payout_account']?.toString() ??
        dest['upi_id']?.toString() ??
        dest['account_number']?.toString() ??
        text('payout_method', 'UPI');
  }

  DateTime get requestedAt => date('created_at') ?? DateTime.now();
  String get referenceCode => text('transaction_reference');
  String get status => text('status', 'pending');

  List<String> stringList(String key) {
    final Object? raw = data[key];
    if (raw is Iterable) {
      return raw.map((e) => e.toString()).toList(growable: false);
    }
    return const <String>[];
  }

  Map<String, Object?> map(String key) {
    final raw = data[key];
    return raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), v))
        : const <String, Object?>{};
  }
}

@immutable
class AffiliateWorkspace {
  const AffiliateWorkspace({
    required this.profile,
    required this.campaigns,
    required this.referrals,
    required this.payouts,
    required this.assets,
    this.tiers = const <AffiliateRecord>[],
    this.terms = const <AffiliateRecord>[],
    this.isPreview = false,
  });

  final AffiliateRecord profile;
  final List<AffiliateRecord> campaigns;
  final List<AffiliateRecord> referrals;
  final List<AffiliateRecord> payouts;
  final List<AffiliateRecord> assets;
  final List<AffiliateRecord> tiers;
  final List<AffiliateRecord> terms;
  final bool isPreview;

  bool get isDemo => isPreview;
  bool get enrolled => profile.id.isNotEmpty;
  String get currency {
    final String raw = profile.text('currency', 'INR').toUpperCase();
    return raw == 'USD' || raw.isEmpty ? 'INR' : raw;
  }

  String get code => profile.text('affiliate_code');
  String get slug => profile.text('custom_slug').isNotEmpty
      ? profile.text('custom_slug')
      : code;
  String get referralUrl => slug.isEmpty ? '' : AppShareLinks.referral(slug);

  String get payoutMethod => profile.text('payout_method', 'upi');

  String get payoutAccount {
    final Map<String, Object?> details = profile.map('payout_details');
    final String vpa =
        details['upi_id']?.toString() ??
        details['payout_vpa']?.toString() ??
        '';
    final String acct =
        details['account_number']?.toString() ??
        details['payout_account']?.toString() ??
        '';
    if (payoutMethod == 'upi' && vpa.isNotEmpty) return vpa;
    if (acct.isNotEmpty) {
      final String bank = details['bank_name']?.toString() ?? '';
      final String ifsc = details['ifsc']?.toString() ?? '';
      if (bank.isNotEmpty || ifsc.isNotEmpty) {
        return '$acct${bank.isNotEmpty ? ' · $bank' : ''}${ifsc.isNotEmpty ? ' ($ifsc)' : ''}';
      }
      return acct;
    }
    return vpa.isNotEmpty ? vpa : acct;
  }

  String get rawPayoutDestination {
    final Map<String, Object?> details = profile.map('payout_details');
    return details['payout_account']?.toString() ??
        details['upi_id']?.toString() ??
        details['payout_vpa']?.toString() ??
        details['account_number']?.toString() ??
        '';
  }

  String get bankName =>
      profile.map('payout_details')['bank_name']?.toString() ?? '';
  String get accountHolder =>
      profile.map('payout_details')['account_holder']?.toString() ?? '';
  String get accountNumber =>
      profile.map('payout_details')['account_number']?.toString() ?? '';
  String get ifscCode =>
      profile.map('payout_details')['ifsc']?.toString() ?? '';
  String get upiId => profile.map('payout_details')['upi_id']?.toString() ?? '';
  String get panNumber => profile.text('pan_number').isNotEmpty
      ? profile.text('pan_number')
      : (profile.map('payout_details')['pan']?.toString() ?? '');
  String get gstin => profile.text('gstin').isNotEmpty
      ? profile.text('gstin')
      : (profile.map('payout_details')['gstin']?.toString() ?? '');
  bool get gstRegistered =>
      profile.flag('gst_registered') || gstin.trim().isNotEmpty;

  double get tdsRate {
    final double r = profile.number('tds_rate');
    return r > 0 ? r : 0.05; // 5% statutory TDS u/s 194H
  }

  double tdsAmountFor(num gross) =>
      double.parse((gross.toDouble() * tdsRate).toStringAsFixed(2));

  double gstAmountFor(num gross) => gstRegistered
      ? double.parse((gross.toDouble() * 0.18).toStringAsFixed(2))
      : 0.0;

  double netPayoutFor(num gross) => double.parse(
    (gross.toDouble() - tdsAmountFor(gross) + gstAmountFor(gross))
        .toStringAsFixed(2),
  );

  bool get hasOpenPayout => payouts.any((p) {
    final s = p.text('status');
    return s == 'pending' || s == 'processing';
  });

  int get totalClicks => campaigns.fold(0, (sum, c) => sum + c.count('clicks'));
  int get convertedCount =>
      referrals.where((r) => r.text('status') == 'converted').length;
  int get pendingReferralsCount =>
      referrals.where((r) => r.text('status') == 'pending').length;

  double get conversionRate =>
      referrals.isEmpty ? 0 : (convertedCount / referrals.length) * 100;

  AffiliateRecord? get currentTierRecord {
    final String code = profile.text('tier', 'standard').toLowerCase();
    for (final AffiliateRecord t in tiers) {
      if (t.text('tier_code').toLowerCase() == code) return t;
    }
    return tiers.isNotEmpty ? tiers.first : null;
  }

  AffiliateRecord? get nextTierRecord {
    if (tiers.isEmpty) return null;
    final String code = profile.text('tier', 'standard').toLowerCase();
    for (int i = 0; i < tiers.length - 1; i++) {
      if (tiers[i].text('tier_code').toLowerCase() == code) {
        return tiers[i + 1];
      }
    }
    return null;
  }

  double get progressToNextTier {
    final AffiliateRecord? next = nextTierRecord;
    if (next == null) return 1.0;
    final int target = next.count('min_active_referrals');
    if (target <= 0) return 1.0;
    final int active = profile.count('active_referrals');
    return (active / target).clamp(0.0, 1.0);
  }

  String campaignUrl(AffiliateRecord campaign) =>
      '$referralUrl?utm_campaign=${Uri.encodeQueryComponent(campaign.text('slug'))}';

  String money(num amount) {
    if (currency == 'INR') {
      return formatInrAmount(amount, decimals: 2, symbol: true);
    }
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  List<AffiliateRecord> filterReferrals(String query, String status) {
    final q = query.trim().toLowerCase();
    return referrals
        .where((r) {
          final matchesStatus = status == 'all' || r.text('status') == status;
          final hay =
              '${r.id} ${r.text('referral_code')} ${r.text('channel')} ${r.text('plan_tier')} ${r.text('status')}'
                  .toLowerCase();
          return matchesStatus && (q.isEmpty || hay.contains(q));
        })
        .toList(growable: false);
  }

  factory AffiliateWorkspace.fromJson(
    Map<String, Object?> json, {
    bool isPreview = false,
  }) {
    List<AffiliateRecord> list(String key) {
      final raw = json[key];
      if (raw is! List) return const <AffiliateRecord>[];
      return raw
          .whereType<Map>()
          .map(
            (row) =>
                AffiliateRecord(row.map((k, v) => MapEntry(k.toString(), v))),
          )
          .toList(growable: false);
    }

    return AffiliateWorkspace(
      profile: AffiliateRecord(
        json['profile'] is Map
            ? (json['profile']! as Map).map((k, v) => MapEntry(k.toString(), v))
            : const <String, Object?>{},
      ),
      campaigns: list('campaigns'),
      referrals: list('referrals'),
      payouts: list('payouts'),
      assets: list('assets'),
      tiers: list('tiers'),
      terms: list('terms'),
      isPreview: isPreview,
    );
  }
}

String referralCsv(List<AffiliateRecord> rows, String currency) {
  String cell(String value) {
    final safe =
        value.startsWith(RegExp(r'[=+\-@]')) ||
            value.startsWith('\t') ||
            value.startsWith('\r')
        ? "'$value"
        : value;
    return '"${safe.replaceAll('"', '""')}"';
  }

  final lines = <String>[
    'id,referral_code,channel,plan_tier,status,currency,gross_commission_inr,tds_deducted_inr,net_commission_inr,created_at',
    for (final r in rows)
      [
        cell(r.id),
        cell(r.text('referral_code')),
        cell(r.text('channel', 'direct')),
        cell(r.text('plan_tier', 'pro')),
        cell(r.text('status')),
        cell(currency),
        r.number('bonus_awarded').toStringAsFixed(2),
        r.number('tds_deducted_inr').toStringAsFixed(2),
        (r.number('net_commission_inr') > 0
                ? r.number('net_commission_inr')
                : r.number('bonus_awarded') * 0.95)
            .toStringAsFixed(2),
        cell(r.text('created_at')),
      ].join(','),
  ];
  return lines.join('\r\n');
}
