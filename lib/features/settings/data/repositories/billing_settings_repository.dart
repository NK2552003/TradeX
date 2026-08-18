import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/models/billing_models.dart';

abstract class BillingSettingsRepository {
  Future<SubscriptionSummary> getSubscription();
  Future<List<AppPlan>> getAvailablePlans();
  Future<CheckoutSession> startCheckout(String tierId, String billingCycle);
  Future<PaymentMethodSummary?> getPaymentMethod();
  Future<CheckoutSession> startPaymentMethodUpdate();
  Future<List<Invoice>> getBillingHistory();
  Future<Invoice> getInvoice(String invoiceId);
  Future<void> cancelSubscription({String? reason});
}

class BillingSettingsRepositoryImpl implements BillingSettingsRepository {
  BillingSettingsRepositoryImpl({AppTier initialTier = AppTier.premium})
    : _subscription = SubscriptionSummary.mockForTier(initialTier);

  SubscriptionSummary _subscription;

  final PaymentMethodSummary _paymentMethod = const PaymentMethodSummary(
    brand: 'Visa',
    last4: '4242',
    expMonth: 12,
    expYear: 2028,
  );

  final List<Invoice> _invoices = <Invoice>[
    Invoice(
      id: 'inv_2026_08',
      amount: 2499.00,
      currency: 'INR',
      status: 'paid',
      issuedAt: DateTime.now().subtract(const Duration(days: 12)),
      pdfUrl: 'https://tradex.ai/invoices/inv_2026_08.pdf',
      lineItems: const <InvoiceLineItem>[
        InvoiceLineItem(
          description: 'TradeX Pro Plan (Monthly Subscription)',
          amount: 2499.00,
          quantity: 1,
        ),
      ],
    ),
    Invoice(
      id: 'inv_2026_07',
      amount: 2499.00,
      currency: 'INR',
      status: 'paid',
      issuedAt: DateTime.now().subtract(const Duration(days: 42)),
      pdfUrl: 'https://tradex.ai/invoices/inv_2026_07.pdf',
      lineItems: const <InvoiceLineItem>[
        InvoiceLineItem(
          description: 'TradeX Pro Plan (Monthly Subscription)',
          amount: 2499.00,
          quantity: 1,
        ),
      ],
    ),
    Invoice(
      id: 'inv_2026_06',
      amount: 2499.00,
      currency: 'INR',
      status: 'paid',
      issuedAt: DateTime.now().subtract(const Duration(days: 72)),
      pdfUrl: 'https://tradex.ai/invoices/inv_2026_06.pdf',
      lineItems: const <InvoiceLineItem>[
        InvoiceLineItem(
          description: 'TradeX Pro Plan (Monthly Subscription)',
          amount: 2499.00,
          quantity: 1,
        ),
      ],
    ),
  ];

  @override
  Future<SubscriptionSummary> getSubscription() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _subscription;
  }

  @override
  Future<List<AppPlan>> getAvailablePlans() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return <AppPlan>[
      AppPlan(
        tier: AppTier.free,
        priceLabel: '₹0',
        period: '/mo',
        current: _subscription.tier == AppTier.free,
        description: 'Core journal logging and basic charts for individuals.',
        features: <String>[
          'Up to 100 journal entries',
          'Basic NSE / BSE scanner',
          'Standard charts & technical indicators',
          'Community feed access',
        ],
      ),
      AppPlan(
        tier: AppTier.premium,
        priceLabel: '₹2,499',
        period: '/mo',
        highlighted: true,
        current: _subscription.tier == AppTier.premium,
        description:
            'Advanced analytics, AI signal assistant, and unlimited journaling.',
        features: <String>[
          'Unlimited journal entries',
          'AI Trading Assistant & Nifty/BankNifty pattern detection',
          'Real-time Level 2 market scanner',
          '500 monthly AI query credits',
          'Direct messaging & mentor reviews',
          'Export journal to CSV / PDF',
        ],
      ),
      AppPlan(
        tier: AppTier.enterprise,
        priceLabel: '₹7,999',
        period: '/mo',
        current: _subscription.tier == AppTier.enterprise,
        description:
            'Dedicated team collaboration, custom compliance, and priority execution.',
        features: <String>[
          'Everything in Pro',
          'Multi-seat desk workspace',
          'Institutional risk controls & audit trails',
          'Unlimited AI credits',
          'Dedicated account manager & API support',
        ],
      ),
    ];
  }

  @override
  Future<CheckoutSession> startCheckout(
    String tierId,
    String billingCycle,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final AppTier tier = AppTier.values.firstWhere(
      (AppTier value) => value.name == tierId,
      orElse: () => _subscription.tier,
    );
    _subscription = SubscriptionSummary(
      tier: tier,
      status: 'active',
      billingCycle: billingCycle,
      renewedAt: DateTime.now(),
      expiresAt: DateTime.now().add(
        Duration(days: billingCycle == 'annual' ? 365 : 30),
      ),
      usage: _subscription.usage,
    );
    return const CheckoutSession(
      checkoutUrl: 'https://checkout.stripe.com/c/pay/mock_session',
      clientSecret: 'pi_mock_secret_123456789',
    );
  }

  @override
  Future<PaymentMethodSummary?> getPaymentMethod() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _paymentMethod;
  }

  @override
  Future<CheckoutSession> startPaymentMethodUpdate() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const CheckoutSession(clientSecret: 'seti_mock_secret_987654321');
  }

  @override
  Future<List<Invoice>> getBillingHistory() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List<Invoice>.from(_invoices);
  }

  @override
  Future<Invoice> getInvoice(String invoiceId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _invoices.firstWhere(
      (inv) => inv.id == invoiceId,
      orElse: () => _invoices.first,
    );
  }

  @override
  Future<void> cancelSubscription({String? reason}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _subscription = SubscriptionSummary(
      tier: AppTier.free,
      status: 'canceled',
      billingCycle: 'monthly',
      renewedAt: _subscription.renewedAt,
      expiresAt: DateTime.now().add(const Duration(days: 5)),
      usage: _subscription.usage,
    );
  }
}
