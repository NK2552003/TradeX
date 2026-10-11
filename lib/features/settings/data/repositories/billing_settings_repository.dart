import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/data/demo_data_source.dart';
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

  static const String _demoUserId = '00000000-0000-0000-0000-000000000001';

  final DemoDataSource _source;
  final AppSession _session;

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

  SubscriptionSummary _summary() => SubscriptionSummary(
    tier: _tier,
    status: _status,
    billingCycle: _session.billingCycle,
    renewedAt: _session.renewedAt,
    expiresAt: _session.expiresAt,
    usage: _source.accountUsage(_tier),
    monthlyAmount: _source.planPrice(_tier),
    annualMonthsBilled: _source.annualMonthsBilled,
    cancelAtPeriodEnd: _session.cancelAtPeriodEnd,
    discountCode: _session.discountCode,
    discountPercent: _session.discountPercent,
  );

  @override
  Future<SubscriptionSummary> getSubscription() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        final data = await client.from('subscriptions').select('*').eq('user_id', targetUserId).maybeSingle();
        if (data != null) {
          final tierStr = data['tier'] as String? ?? 'free';
          final tier = AppTier.values.firstWhere((t) => t.name == tierStr, orElse: () => AppTier.free);
          final statusStr = data['status'] as String? ?? 'active';
          final cycleStr = data['billing_cycle'] as String? ?? 'monthly';
          _session.startPeriod(tier, cycleStr);
          _session.cancelAtPeriodEnd = statusStr == 'canceled';
        }
      } catch (e) {
        debugPrint('BillingSettingsRepositoryImpl.getSubscription error: $e');
      }
    }
    return _summary();
  }

  @override
  Future<List<AppPlan>> getAvailablePlans({bool annual = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _source.plans(current: _tier, annual: annual);
  }

  @override
  Future<CheckoutSession> startCheckout(
    String tierId,
    String billingCycle,
  ) async {
    final AppTier tier = AppTier.values.firstWhere(
      (AppTier value) => value.name == tierId,
      orElse: () => _tier,
    );
    _session.startPeriod(tier, billingCycle);
    if (tier == AppTier.free) {
      _session.discountCode = null;
      _session.discountPercent = 0;
    }

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        await client.from('subscriptions').upsert({
          'user_id': targetUserId,
          'tier': tier.name,
          'status': 'active',
          'billing_cycle': billingCycle,
          'renewed_at': DateTime.now().toIso8601String(),
          'expires_at': DateTime.now().add(Duration(days: billingCycle == 'annual' ? 365 : 30)).toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('BillingSettingsRepositoryImpl.startCheckout error: $e');
      }
    }

    return const CheckoutSession();
  }

  @override
  Future<SubscriptionSummary> setCancelAtPeriodEnd(bool cancel) async {
    _session.cancelAtPeriodEnd = cancel;
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        await client.from('subscriptions').update({
          'status': cancel ? 'canceled' : 'active',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', targetUserId);
      } catch (e) {
        debugPrint('BillingSettingsRepositoryImpl.setCancelAtPeriodEnd error: $e');
      }
    }
    return _summary();
  }

  @override
  Future<int?> redeemCoupon(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
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
    return _card();
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
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const CheckoutSession(clientSecret: 'seti_mock_secret_987654321');
  }

  @override
  Future<List<Invoice>> getBillingHistory() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

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
                description: map['description'] as String? ?? 'Subscription Charge',
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
                issuedAt: DateTime.tryParse(item['issued_at'] as String? ?? '') ?? DateTime.now(),
                pdfUrl: item['pdf_url'] as String? ?? 'https://tradex.ai/invoices/${item['invoice_ref']}.pdf',
                issuer: _issuer,
                taxPercent: _taxPercent,
                paymentMethodLabel: card == null ? null : '${card.brand} •••• ${card.last4}',
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
    return _invoices();
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
          pdfUrl: 'https://tradex.ai/invoices/${_invoiceRef(i, stride)}.pdf',
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
    name: 'TradeX Technologies Pvt Ltd',
    addressLines: <String>[
      '4th Floor, Prestige Trade Tower',
      '46 Palace Road, Bengaluru 560001',
      'Karnataka, India',
    ],
    supportEmail: 'billing@tradex.ai',
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
    _session.cancelAtPeriodEnd = true;
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        await client.from('subscriptions').update({
          'status': 'canceled',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', targetUserId);
      } catch (e) {
        debugPrint('BillingSettingsRepositoryImpl.cancelSubscription error: $e');
      }
    }
  }
}
