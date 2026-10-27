import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/config/customer_quota_usage.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:tradex/features/auth/models/pricing_models.dart';
import 'package:tradex/features/settings/models/billing_models.dart';

abstract class BillingSettingsRepository {
  Future<SubscriptionSummary> getSubscription();

  /// The catalogue priced for [annual] or monthly billing.
  Future<List<AppPlan>> getAvailablePlans({bool annual = false});
  Future<CheckoutSession> startCheckout(String tierId, String billingCycle);
  Future<PaymentMethodSummary?> getPaymentMethod();
  Future<CheckoutSession> startPaymentMethodUpdate();
  Future<List<Invoice>> getBillingHistory();
  Future<Invoice> getInvoice(String invoiceId);
  Future<void> cancelSubscription({String? reason});

  /// Stops or restarts renewal without changing the plan. Access always runs to
  /// the end of the period the reader has already paid for.
  Future<SubscriptionSummary> setCancelAtPeriodEnd(bool cancel);

  /// Applies [code] to the subscription. Returns the discount percentage, or
  /// null when the code is not one this account can use.
  Future<int?> redeemCoupon(String code);

  /// The discount this account can be offered instead of cancelling, or null
  /// when there is nothing to discount.
  Future<RetentionOffer?> getRetentionOffer();
}

/// Billing surfaces in settings: the plan chooser, the payment method, the
/// invoice list and the cancel flow.
class BillingSettingsRepositoryImpl implements BillingSettingsRepository {
  BillingSettingsRepositoryImpl({DemoDataSource? source, AppSession? session})
    : _source = source ?? DemoDataSource.instance,
      _session = session ?? AppSession.instance;

  final DemoDataSource _source;
  final AppSession _session;
  PricingCatalogueResponse? _pricingCatalogue;

  String _resolveUserId() =>
      SupabaseConfig.client?.auth.currentUser?.id ??
      SupabaseAuthBackendService.instance.currentUserProfile?.id ??
      '';

  AppTier get _tier => _session.tier.value;

  /// Months of history the generated invoice list covers.
  static const int _historyMonths = 6;

  /// Coupons the prototype accepts, with what each takes off. The backend
  /// replaces this with the promotion codes it actually issued.
  static const Map<String, int> _coupons = <String, int>{
    'TRADEX20': 20,
    'DESK50': 50,
  };

  /// Free accounts are not on a billing cycle at all, so the status has to be
  /// derived rather than stored — otherwise cancelling and then downgrading
  /// leaves the page claiming a canceled paid plan.
  String get _status {
    if (_tier == AppTier.free) return 'canceled';
    return _session.cancelAtPeriodEnd ? 'canceled' : 'active';
  }

  SubscriptionSummary _summary({
    AppTier? tier,
    String? status,
    String? billingCycle,
    DateTime? renewedAt,
    DateTime? expiresAt,
    Map<String, dynamic>? usage,
  }) => SubscriptionSummary(
    tier: tier ?? _tier,
    status: status ?? _status,
    billingCycle: billingCycle ?? _session.billingCycle,
    renewedAt: renewedAt ?? _session.renewedAt,
    expiresAt: expiresAt ?? _session.expiresAt,
    usage:
        usage ??
        (CustomerDataPolicy.allowDemo ? _source.accountUsage(_tier) : {}),
    monthlyAmount:
        _pricingCatalogue?.plans
            .where((plan) => plan.tier == (tier ?? _tier))
            .firstOrNull
            ?.monthlyAmount ??
        0,
    annualMonthsBilled: _pricingCatalogue?.annualMonthsBilled ?? 12,
    cancelAtPeriodEnd: _session.cancelAtPeriodEnd,
    discountCode: _session.discountCode,
    discountPercent: _session.discountPercent,
  );

  @override
  Future<SubscriptionSummary> getSubscription() async {
    _pricingCatalogue = await SubscriptionPricingRepositoryImpl()
        .getPricingCatalogue();
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();
      if (targetUserId.isEmpty) throw StateError('Sign in to read your plan.');
      final counted = await CustomerQuotaUsage.fetch();
      final data = await client
          .from('subscriptions')
          .select('*')
          .eq('user_id', targetUserId)
          .maybeSingle();
      final tier = counted.tier;
      final cycle = data?['billing_cycle'] as String? ?? 'monthly';
      _session.billingCycle = cycle;
      _session.cancelAtPeriodEnd = data?['status'] == 'canceled';
      final renewed = DateTime.tryParse(data?['renewed_at']?.toString() ?? '');
      final expires = DateTime.tryParse(data?['expires_at']?.toString() ?? '');
      if (tier != AppTier.free && cycle != 'lifetime' && expires == null) {
        throw StateError('Your billing period is unavailable. Please retry.');
      }
      return _summary(
        tier: tier,
        status: tier == AppTier.free
            ? 'canceled'
            : data?['status'] as String? ?? 'active',
        billingCycle: cycle,
        renewedAt: renewed ?? DateTime.fromMillisecondsSinceEpoch(0),
        expiresAt: expires ?? DateTime.fromMillisecondsSinceEpoch(0),
        usage: {
          'journal_trades_used': counted.tradesUsed,
          'journal_trades_limit': counted.tradesLimit,
          'ai_queries_used': counted.aiQueriesUsed,
          'ai_queries_limit': counted.aiQueriesLimit,
          'notes_used': counted.notesUsed,
          'notes_limit': counted.notesLimit,
          'live_playbooks_used': counted.livePlaybooksUsed,
          'live_playbooks_limit': counted.livePlaybooksLimit,
        },
      );
    }
    return _summary();
  }

  @override
  Future<List<AppPlan>> getAvailablePlans({bool annual = false}) async {
    final catalogue = await SubscriptionPricingRepositoryImpl()
        .getPricingCatalogue(annual: annual);
    _pricingCatalogue = catalogue;
    return catalogue.plans.map((plan) {
      final amount = annual
          ? plan.annualMonthlyAmount * 12
          : plan.monthlyAmount;
      return AppPlan(
        tier: plan.tier,
        amount: amount,
        priceLabel: plan.priceLabel(isAnnual: annual),
        period: annual ? '/yr' : '/mo',
        description: plan.subtitle,
        features: plan.featuresSummary,
        highlighted: plan.highlighted,
        current: plan.tier == _tier,
      );
    }).toList();
  }

  @override
  Future<CheckoutSession> startCheckout(
    String tierId,
    String billingCycle,
  ) async {
    if (tierId != 'tier_enterprise' ||
        (billingCycle != 'monthly' && billingCycle != 'annual')) {
      throw StateError('Choose a supported Business billing cycle.');
    }
    final client = SupabaseConfig.client;
    if (client?.auth.currentUser == null) {
      throw StateError('Sign in to start Business checkout.');
    }
    final response = await client!.functions.invoke(
      'create-business-checkout',
      body: {'billing_cycle': billingCycle},
    );
    if (response.status != 200 || response.data is! Map) {
      throw StateError('Business checkout is not available yet.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final id = data['subscription_id'];
    final url = data['checkout_url'];
    if (id is! String || url is! String) {
      throw StateError('The payment provider returned an invalid checkout.');
    }
    final checkout = Uri.tryParse(url);
    if (checkout == null ||
        checkout.scheme != 'https' ||
        !{
          'rzp.io',
          'razorpay.com',
          'www.razorpay.com',
        }.contains(checkout.host)) {
      throw StateError('The payment provider returned an invalid checkout.');
    }
    return CheckoutSession(sessionId: id, url: url, checkoutUrl: url);
  }

  @override
  Future<SubscriptionSummary> setCancelAtPeriodEnd(bool cancel) async {
    throw StateError('Manage renewal through the store Customer Center.');
  }

  @override
  Future<int?> redeemCoupon(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!CustomerDataPolicy.allowDemo) return null;
    final int? percent = _coupons[code.trim().toUpperCase()];
    if (percent == null) return null;
    _session.discountCode = code.trim().toUpperCase();
    _session.discountPercent = percent;
    return percent;
  }

  /// Code held back for an account that starts cancelling. It is one of
  /// [_coupons], so the saving the retention dialog quotes is the saving
  /// [redeemCoupon] goes on to apply.
  static const String _retentionCode = 'DESK50';
  static const int _retentionCycles = 3;

  @override
  Future<RetentionOffer?> getRetentionOffer() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    // A free plan has no renewal to discount, and an account already holding a
    // coupon is not offered a second one.
    if (_tier == AppTier.free || _session.discountPercent > 0) return null;
    final int? percent = _coupons[_retentionCode];
    if (percent == null) return null;
    return RetentionOffer(
      code: _retentionCode,
      discountPercent: percent,
      cycles: _retentionCycles,
    );
  }

  @override
  Future<PaymentMethodSummary?> getPaymentMethod() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return CustomerDataPolicy.allowDemo ? _card() : null;
  }

  /// The card on file, or null when there is none. A free account has never been
  /// charged, so the pages read this as "add a payment method" rather than
  /// showing a card the reader never entered.
  PaymentMethodSummary? _card() {
    if (_tier == AppTier.free) return null;
    return const PaymentMethodSummary(
      brand: 'Visa',
      last4: '4242',
      expMonth: 12,
      expYear: 2028,
    );
  }

  @override
  Future<CheckoutSession> startPaymentMethodUpdate() async {
    throw StateError(
      'Payment method updates require a verified billing provider.',
    );
  }

  @override
  Future<List<Invoice>> getBillingHistory() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        if (targetUserId.isEmpty) return _invoices();

        final res = await client
            .from('invoices')
            .select('*')
            .eq('user_id', targetUserId)
            .order('issued_at', ascending: false);

        if ((res as List).isNotEmpty) {
          final list = <Invoice>[];
          final card = _card();
          for (final item in res) {
            final rawItems = item['line_items'] as List<dynamic>? ?? [];
            final lineItems = rawItems.map((li) {
              final map = li as Map<String, dynamic>;
              return InvoiceLineItem(
                description:
                    map['description'] as String? ?? 'Subscription Charge',
                amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
                quantity: (map['quantity'] as num?)?.toInt() ?? 1,
              );
            }).toList();

            list.add(
              Invoice(
                id: item['id'] as String,
                amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
                currency: item['currency'] as String? ?? 'INR',
                status: item['status'] as String? ?? 'paid',
                issuedAt:
                    DateTime.tryParse(item['issued_at'] as String? ?? '') ??
                    DateTime.now(),
                pdfUrl: item['pdf_url'] as String? ?? '',
                paymentMethodLabel: card == null
                    ? null
                    : '${card.brand} •••• ${card.last4}',
                lineItems: lineItems,
              ),
            );
          }
          return list;
        }
      } catch (e) {
        debugPrint('BillingSettingsRepositoryImpl.getBillingHistory error: $e');
      }
    }
    return CustomerDataPolicy.allowDemo ? _invoices() : [];
  }

  @override
  Future<Invoice> getInvoice(String invoiceId) async {
    final rows = await getBillingHistory();
    for (final Invoice invoice in rows) {
      if (invoice.id == invoiceId) return invoice;
    }
    throw StateError('Invoice $invoiceId not found');
  }

  /// One row per past billing period at the current plan's price. A free account
  /// has nothing to show, which is the honest empty state for the history page.
  List<Invoice> _invoices() {
    if (_tier == AppTier.free) return const <Invoice>[];
    final SubscriptionSummary summary = _summary();
    final double amount = summary.amount;
    final String planName = AppTokens.tierLabel(_tier);
    final bool annual = summary.billingCycle == 'annual';
    final String cycleLabel = annual ? 'Annual' : 'Monthly';
    final int stride = annual ? 365 : 30;
    final String? coupon = summary.discountCode;
    final PaymentMethodSummary? card = _card();
    return <Invoice>[
      for (int i = 0; i < _historyMonths; i++)
        Invoice(
          id: 'inv_${_invoiceRef(i, stride)}',
          amount: amount,
          currency: 'INR',
          status: 'paid',
          issuedAt: summary.renewedAt.subtract(Duration(days: i * stride)),
          pdfUrl: 'https://alphajournal.in/invoices/${_invoiceRef(i, stride)}.pdf',
          issuer: _issuer,
          taxPercent: _taxPercent,
          paymentMethodLabel: card == null
              ? null
              : '${card.brand} •••• ${card.last4}',
          lineItems: <InvoiceLineItem>[
            InvoiceLineItem(
              description: '$planName ($cycleLabel subscription)',
              amount: summary.listAmount,
              quantity: 1,
            ),
            if (coupon != null)
              InvoiceLineItem(
                description: 'Coupon $coupon (−${summary.discountPercent}%)',
                amount: amount - summary.listAmount,
                quantity: 1,
              ),
          ],
        ),
    ];
  }

  /// Entity the charges are raised by, and the rate its prices include. A
  /// backend replaces this with the billing account's own registration; it lives
  /// here rather than in the receipt layout so the document cannot claim a
  /// company or a tax rate the charge was not made under.
  static const InvoiceIssuer _issuer = InvoiceIssuer(
    name: 'alphajournal',
    addressLines: <String>[
      '4th Floor, Prestige Trade Tower',
      '46 Palace Road, Bengaluru 560001',
      'Karnataka, India',
    ],
    supportEmail: 'billing@alphajournal.in',
    taxId: '29AABCT1332L1ZT',
    taxLabel: 'GST',
  );

  /// Tax already included in every price the catalogue quotes.
  static const double _taxPercent = 18;

  String _invoiceRef(int index, int stride) {
    final DateTime issued = _session.renewedAt.subtract(
      Duration(days: index * stride),
    );
    return '${issued.year}_${issued.month.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> cancelSubscription({String? reason}) async {
    throw StateError('Manage cancellation through the store Customer Center.');
  }
}
