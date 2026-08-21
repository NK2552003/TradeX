import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// One line on an invoice list.
@immutable
class Invoice {
  const Invoice({
    required this.id,
    required this.amount,
    required this.issuedAt,
    required this.tier,
    required this.paid,
  });

  final String id;
  final double amount;
  final DateTime issuedAt;
  final AppTier tier;
  final bool paid;
}

/// Current subscription state for the account.
@immutable
class Subscription {
  const Subscription({
    required this.tier,
    required this.renewsAt,
    required this.annual,
    required this.usage,
    this.cancelAtPeriodEnd = false,
    this.paymentMethodLabel,
  });

  final AppTier tier;
  final DateTime renewsAt;
  final bool annual;
  final List<AppUsageMetric> usage;
  final bool cancelAtPeriodEnd;
  final String? paymentMethodLabel;

  String get renewalLabel => cancelAtPeriodEnd
      ? 'Ends ${AppTokens.shortDate(renewsAt)}'
      : 'Renews ${AppTokens.shortDate(renewsAt)}';
}

abstract class SubscriptionRepository {
  Future<Subscription> getSubscription();
  Future<List<AppPlan>> getPlans({bool annual = false});
  Future<Subscription> changeTier(AppTier tier, {bool annual = false});
  Future<Subscription> setCancelAtPeriodEnd(bool cancel);
  Future<List<Invoice>> getInvoices();
  Future<String> downloadInvoice(String id);
  Future<bool> redeemCoupon(String code);
}

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({DemoDataSource? source, AppSession? session})
    : _source = source ?? DemoDataSource.instance,
      _session = session ?? AppSession.instance;

  final DemoDataSource _source;

  /// The plan lives on the shared session, not on this instance — every page
  /// builds its own repository, and they all have to agree about entitlement.
  final AppSession _session;

  AppTier get _tier => _session.tier.value;
  bool _annual = false;
  bool _cancelAtPeriodEnd = false;
  DateTime _renewsAt = DateTime.now().add(const Duration(days: 21));

  static const Set<String> _validCoupons = <String>{'TRADEX20', 'DESK50'};

  Subscription _current() => Subscription(
    tier: _tier,
    renewsAt: _renewsAt,
    annual: _annual,
    usage: _source.usageMetrics(),
    cancelAtPeriodEnd: _cancelAtPeriodEnd,
    paymentMethodLabel: _tier == AppTier.free ? null : 'Visa •••• 4242',
  );

  @override
  Future<Subscription> getSubscription() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return _current();
  }

  @override
  Future<List<AppPlan>> getPlans({bool annual = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final List<AppPlan> plans = _source.plans(current: _tier);
    if (!annual) return plans;
    return <AppPlan>[
      for (final AppPlan plan in plans)
        AppPlan(
          tier: plan.tier,
          priceLabel: _annualPrice(plan.priceLabel),
          period: '/yr',
          features: <String>[
            ...plan.features,
            if (plan.tier != AppTier.free) 'Two months free on annual billing',
          ],
          highlighted: plan.highlighted,
          current: plan.current,
          description: plan.description,
        ),
    ];
  }

  String _annualPrice(String monthly) {
    final String digits = monthly.replaceAll(RegExp(r'[^0-9]'), '');
    final int value = int.tryParse(digits) ?? 0;
    if (value == 0) return monthly;
    return '₹${(value * 10).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (Match m) => '${m[1]},')}';
  }

  @override
  Future<Subscription> changeTier(AppTier tier, {bool annual = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 720));
    _session.changeTier(tier);
    _annual = annual;
    _cancelAtPeriodEnd = false;
    _renewsAt = DateTime.now().add(Duration(days: annual ? 365 : 30));
    return _current();
  }

  @override
  Future<Subscription> setCancelAtPeriodEnd(bool cancel) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    _cancelAtPeriodEnd = cancel;
    return _current();
  }

  @override
  Future<List<Invoice>> getInvoices() async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (_tier == AppTier.free) return const <Invoice>[];
    final String priceLabel = _source
        .plans(current: _tier)
        .firstWhere((AppPlan p) => p.tier == _tier)
        .priceLabel;
    final double amount =
        double.tryParse(priceLabel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return <Invoice>[
      for (int i = 0; i < 6; i++)
        Invoice(
          id: 'INV-${20260 + i}',
          amount: amount,
          issuedAt: DateTime.now().subtract(Duration(days: i * 30)),
          tier: _tier,
          paid: true,
        ),
    ];
  }

  @override
  Future<String> downloadInvoice(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 480));
    return 'tradex_$id.pdf';
  }

  @override
  Future<bool> redeemCoupon(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
    return _validCoupons.contains(code.trim().toUpperCase());
  }
}
