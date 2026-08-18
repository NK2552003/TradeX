import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

@immutable
class SubscriptionSummary {
  const SubscriptionSummary({
    required this.tier,
    required this.status,
    required this.billingCycle,
    required this.renewedAt,
    required this.expiresAt,
    required this.usage,
  });

  final AppTier tier;

  /// 'active' | 'trialing' | 'canceled' | 'past_due'
  final String status;

  /// 'monthly' | 'annual'
  final String billingCycle;
  final DateTime renewedAt;
  final DateTime expiresAt;
  final Map<String, dynamic> usage;

  String get planName => AppTokens.tierLabel(tier);
  double get amount {
    final double monthly = switch (tier) {
      AppTier.free => 0,
      AppTier.premium => 2499,
      AppTier.enterprise => 7999,
    };
    return billingCycle == 'annual' ? monthly * 10 : monthly;
  }

  DateTime get currentPeriodEnd => expiresAt;
  int get tradesLoggedThisMonth => (usage['journal_trades_used'] as int?) ?? 38;
  int get maxTradesPerMonth => (usage['journal_trades_limit'] as int?) ?? 100;
  int get aiTokensUsed => (usage['ai_queries_used'] as int?) ?? 142;
  int get maxAiTokens => (usage['ai_queries_limit'] as int?) ?? 500;

  factory SubscriptionSummary.mockPremium() {
    return SubscriptionSummary.mockForTier(AppTier.premium);
  }

  factory SubscriptionSummary.mockForTier(AppTier tier) {
    return SubscriptionSummary(
      tier: tier,
      status: 'active',
      billingCycle: 'monthly',
      renewedAt: DateTime.now().subtract(const Duration(days: 12)),
      expiresAt: DateTime.now().add(const Duration(days: 18)),
      usage: <String, dynamic>{
        'ai_queries_used': 142,
        'ai_queries_limit': tier == AppTier.free ? 25 : 500,
        'journal_trades_used': 38,
        'journal_trades_limit': 100,
        'watchlists_used': 7,
        'watchlists_limit': tier == AppTier.free ? 3 : 20,
      },
    );
  }
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
    this.sessionId = 'cs_mock_12345',
    this.url = 'https://checkout.stripe.com/c/pay/mock_session',
    this.checkoutUrl = 'https://checkout.stripe.com/c/pay/mock_session',
    this.clientSecret = 'pi_mock_secret_123456789',
  });

  final String sessionId;
  final String url;
  final String checkoutUrl;
  final String clientSecret;
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
  }) : createdAt = createdAt ?? issuedAt ?? DateTime.now();

  final String id;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final String pdfUrl;
  final List<InvoiceLineItem> lineItems;

  DateTime get issuedAt => createdAt;
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
