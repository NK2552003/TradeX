import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// Lifecycle of a referred account.
enum ReferralStatus { active, trialing, churned }

ReferralStatus referralStatusFrom(String raw) => switch (raw) {
  'trialing' => ReferralStatus.trialing,
  'churned' => ReferralStatus.churned,
  _ => ReferralStatus.active,
};

String referralStatusLabel(ReferralStatus status) => switch (status) {
  ReferralStatus.active => 'Active',
  ReferralStatus.trialing => 'Trialing',
  ReferralStatus.churned => 'Churned',
};

UiIntent referralStatusIntent(ReferralStatus status) => switch (status) {
  ReferralStatus.active => UiIntent.success,
  ReferralStatus.trialing => UiIntent.warning,
  ReferralStatus.churned => UiIntent.danger,
};

/// One referred account attributed to the affiliate.
@immutable
class Referral {
  const Referral({
    required this.id,
    required this.name,
    required this.email,
    required this.channel,
    required this.joinedAt,
    required this.tier,
    required this.status,
    required this.commission,
  });

  final String id;
  final String name;
  final String email;
  final String channel;
  final DateTime joinedAt;
  final AppTier tier;
  final ReferralStatus status;
  final double commission;
}

/// Lifecycle of a payout request.
enum PayoutStatus { pending, processing, paid }

PayoutStatus payoutStatusFrom(String raw) => switch (raw) {
  'pending' => PayoutStatus.pending,
  'processing' => PayoutStatus.processing,
  _ => PayoutStatus.paid,
};

String payoutStatusLabel(PayoutStatus status) => switch (status) {
  PayoutStatus.pending => 'Pending',
  PayoutStatus.processing => 'Processing',
  PayoutStatus.paid => 'Paid',
};

UiIntent payoutStatusIntent(PayoutStatus status) => switch (status) {
  PayoutStatus.pending => UiIntent.warning,
  PayoutStatus.processing => UiIntent.info,
  PayoutStatus.paid => UiIntent.success,
};

/// A row in the affiliate payout ledger.
@immutable
class Payout {
  const Payout({
    required this.id,
    required this.amount,
    required this.requestedAt,
    required this.method,
    required this.status,
    this.paidAt,
    this.reference,
  });

  final String id;
  final double amount;
  final DateTime requestedAt;
  final String method;
  final PayoutStatus status;
  final DateTime? paidAt;
  final String? reference;
}

/// A withdrawal rail the affiliate can send their balance to.
@immutable
class PayoutMethod {
  const PayoutMethod({
    required this.id,
    required this.label,
    required this.detail,
    required this.icon,
    required this.minimum,
    required this.feePercent,
    required this.eta,
  });

  final String id;
  final String label;
  final String detail;
  final IconData icon;

  /// Smallest amount finance will process on this rail.
  final double minimum;

  /// Processor fee deducted from the requested amount.
  final double feePercent;
  final String eta;

  /// What actually lands in the partner's account for a given request.
  double netOf(double amount) => amount - amount * feePercent / 100;
}

/// Traffic funnel for one acquisition channel.
@immutable
class ChannelPerformance {
  const ChannelPerformance({
    required this.channel,
    required this.clicks,
    required this.signups,
    required this.revenue,
  });

  final String channel;
  final int clicks;
  final int signups;
  final double revenue;

  double get conversionPercent => clicks == 0 ? 0 : signups / clicks * 100;
}

/// A downloadable asset in the marketing kit.
@immutable
class Creative {
  const Creative({
    required this.id,
    required this.title,
    required this.format,
    required this.dimensions,
    required this.sizeLabel,
    required this.icon,
  });

  final String id;
  final String title;
  final String format;
  final String dimensions;
  final String sizeLabel;
  final IconData icon;
}

/// Everything the affiliate overview needs in one round trip.
@immutable
class AffiliatePortalSnapshot {
  const AffiliatePortalSnapshot({
    required this.stats,
    required this.clicks,
    required this.channels,
    required this.recentReferrals,
    required this.pendingBalance,
    required this.lifetimeEarned,
    required this.commissionPercent,
    required this.referralLink,
    required this.nextPayout,
  });

  final List<AppStat> stats;
  final List<AppSeriesPoint> clicks;
  final List<ChannelPerformance> channels;
  final List<Referral> recentReferrals;
  final double pendingBalance;
  final double lifetimeEarned;
  final double commissionPercent;
  final String referralLink;
  final Payout? nextPayout;
}

abstract class AffiliatePortalRepository {
  Future<AffiliatePortalSnapshot> getSnapshot({String range = '30D'});
  Future<List<String>> getRanges();
  Future<List<Referral>> getReferrals({
    String? query,
    ReferralStatus? status,
    String? channel,
  });
  Future<List<String>> getChannels();
  Future<List<Payout>> getPayouts();
  Future<List<PayoutMethod>> getPayoutMethods();
  Future<Payout> requestPayout(double amount, String method);
  Future<List<Creative>> getCreatives();
  Future<String> getReferralLink();
  Future<String> updateSlug(String slug);
}

class AffiliatePortalRepositoryImpl implements AffiliatePortalRepository {
  AffiliatePortalRepositoryImpl({DemoDataSource? source})
    : _source = source ?? DemoDataSource.instance {
    _referrals = <Referral>[
      for (final ({
            String id,
            String name,
            String email,
            String channel,
            DateTime joinedAt,
            AppTier tier,
            String status,
            double commission,
          })
          row
          in _source.referrals())
        Referral(
          id: row.id,
          name: row.name,
          email: row.email,
          channel: row.channel,
          joinedAt: row.joinedAt,
          tier: row.tier,
          status: referralStatusFrom(row.status),
          commission: row.commission,
        ),
    ];
    _payouts = <Payout>[
      for (final ({
            String id,
            double amount,
            DateTime requestedAt,
            DateTime? paidAt,
            String method,
            String status,
            String? reference,
          })
          row
          in _source.payouts())
        Payout(
          id: row.id,
          amount: row.amount,
          requestedAt: row.requestedAt,
          method: row.method,
          status: payoutStatusFrom(row.status),
          paidAt: row.paidAt,
          reference: row.reference,
        ),
    ];
  }

  final DemoDataSource _source;
  late List<Referral> _referrals;
  late List<Payout> _payouts;
  String _slug = 'nitish';

  static const double _commissionPercent = 25;
  static const Map<String, int> _rangeDays = <String, int>{
    '7D': 7,
    '30D': 30,
    '90D': 90,
    'ALL': 365,
  };

  @override
  Future<List<String>> getRanges() async => _rangeDays.keys.toList();

  @override
  Future<String> getReferralLink() async => 'https://tradex.ai/r/$_slug';

  @override
  Future<String> updateSlug(String slug) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    _slug = slug.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '');
    return getReferralLink();
  }

  @override
  Future<AffiliatePortalSnapshot> getSnapshot({String range = '30D'}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final int days = _rangeDays[range] ?? 30;
    final DateTime cutoff = DateTime.now().subtract(Duration(days: days));
    final List<Referral> inRange = _referrals
        .where((Referral r) => r.joinedAt.isAfter(cutoff))
        .toList(growable: false);
    final List<AppSeriesPoint> clicks = _source.referralClicks(
      days: days > 90 ? 90 : days,
    );
    final double totalClicks = clicks.fold<double>(
      0,
      (double sum, AppSeriesPoint p) => sum + p.value,
    );
    final double earned = inRange.fold<double>(
      0,
      (double sum, Referral r) => sum + r.commission,
    );
    final double lifetime = _referrals.fold<double>(
      0,
      (double sum, Referral r) => sum + r.commission,
    );
    final double paid = _payouts
        .where((Payout p) => p.status == PayoutStatus.paid)
        .fold<double>(0, (double sum, Payout p) => sum + p.amount);
    final List<Referral> recent = List<Referral>.from(_referrals)
      ..sort((Referral a, Referral b) => b.joinedAt.compareTo(a.joinedAt));

    return AffiliatePortalSnapshot(
      stats: <AppStat>[
        AppStat(
          label: 'Commission earned',
          value: earned,
          delta: earned * 0.12,
          icon: Icons.payments_rounded,
          formatter: AppTokens.money,
        ),
        AppStat(
          label: 'Referred accounts',
          value: inRange.length,
          icon: Icons.person_add_alt_1_rounded,
          formatter: (num v) => v.toStringAsFixed(0),
        ),
        AppStat(
          label: 'Link clicks',
          value: totalClicks,
          icon: Icons.ads_click_rounded,
          formatter: (num v) => v.toStringAsFixed(0),
        ),
        AppStat(
          label: 'Conversion',
          value: totalClicks == 0 ? 0 : inRange.length / totalClicks * 100,
          icon: Icons.percent_rounded,
          formatter: AppTokens.percent,
        ),
      ],
      clicks: clicks,
      channels: <ChannelPerformance>[
        for (final ({String channel, int clicks, int signups, double revenue})
            row
            in _source.referralFunnel())
          ChannelPerformance(
            channel: row.channel,
            clicks: row.clicks,
            signups: row.signups,
            revenue: row.revenue,
          ),
      ],
      recentReferrals: recent.take(6).toList(growable: false),
      pendingBalance: (lifetime - paid).clamp(0, double.infinity).toDouble(),
      lifetimeEarned: lifetime,
      commissionPercent: _commissionPercent,
      referralLink: await getReferralLink(),
      nextPayout: _payouts
          .where((Payout p) => p.status != PayoutStatus.paid)
          .fold<Payout?>(null, (Payout? found, Payout p) => found ?? p),
    );
  }

  @override
  Future<List<Referral>> getReferrals({
    String? query,
    ReferralStatus? status,
    String? channel,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final String needle = (query ?? '').trim().toLowerCase();
    final List<Referral> rows = _referrals.where((Referral r) {
      if (status != null && r.status != status) return false;
      if (channel != null && r.channel != channel) return false;
      if (needle.isEmpty) return true;
      return r.name.toLowerCase().contains(needle) ||
          r.email.toLowerCase().contains(needle) ||
          r.channel.toLowerCase().contains(needle);
    }).toList();
    rows.sort((Referral a, Referral b) => b.joinedAt.compareTo(a.joinedAt));
    return rows;
  }

  @override
  Future<List<String>> getChannels() async => _source.referralChannels;

  @override
  Future<List<Payout>> getPayouts() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final List<Payout> rows = List<Payout>.from(_payouts);
    rows.sort((Payout a, Payout b) => b.requestedAt.compareTo(a.requestedAt));
    return rows;
  }

  @override
  Future<List<PayoutMethod>> getPayoutMethods() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return <PayoutMethod>[
      for (final ({
            String id,
            String label,
            String detail,
            IconData icon,
            double minimum,
            double feePercent,
            String eta,
          })
          row
          in _source.payoutMethods())
        PayoutMethod(
          id: row.id,
          label: row.label,
          detail: row.detail,
          icon: row.icon,
          minimum: row.minimum,
          feePercent: row.feePercent,
          eta: row.eta,
        ),
    ];
  }

  @override
  Future<Payout> requestPayout(double amount, String method) async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
    final Payout payout = Payout(
      id: 'pay_${DateTime.now().microsecondsSinceEpoch}',
      amount: amount,
      requestedAt: DateTime.now(),
      method: method,
      status: PayoutStatus.pending,
    );
    _payouts = <Payout>[payout, ..._payouts];
    return payout;
  }

  @override
  Future<List<Creative>> getCreatives() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return <Creative>[
      for (final ({
            String id,
            String title,
            String format,
            String dimensions,
            String sizeLabel,
            IconData icon,
          })
          row
          in _source.creatives())
        Creative(
          id: row.id,
          title: row.title,
          format: row.format,
          dimensions: row.dimensions,
          sizeLabel: row.sizeLabel,
          icon: row.icon,
        ),
    ];
  }
}
