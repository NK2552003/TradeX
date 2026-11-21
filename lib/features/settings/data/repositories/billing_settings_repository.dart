import 'package:alphajournal/core/config/customer_data_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/env_config.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/core/config/customer_quota_usage.dart';
import 'package:alphajournal/core/data/app_session.dart';
import 'package:alphajournal/core/data/demo_data_source.dart';
import 'package:alphajournal/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:alphajournal/features/auth/models/pricing_models.dart';
import 'package:alphajournal/features/settings/models/billing_models.dart';

abstract class BillingSettingsRepository {
  Future<SubscriptionSummary> getSubscription();

  /// The catalogue priced for [annual] or monthly billing.
  Future<List<AppPlan>> getAvailablePlans({bool annual = false});
  Future<CheckoutSession> startCheckout(
    String tierId,
    String billingCycle, {
    String? referralCode,
  });
  Future<ReferralDiscountQuote> validateReferralCode({
    required String code,
    required String tierId,
    required String billingCycle,
  });
  Future<AffiliateMilestoneStatus> getAffiliateMilestoneStatus();
  Future<bool> verifyCheckout({
    required String subscriptionId,
    String? paymentId,
    String? signature,
  });
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
    AffiliateMilestoneStatus? affiliateMilestone,
  }) {
    final AppTier effectiveTier = tier ?? _tier;
    final String effectiveCycle = billingCycle ?? _session.billingCycle;
    final PricingPlanModel? plan = _pricingCatalogue?.plans
        .where((p) => p.tier == effectiveTier)
        .firstOrNull;
    final double fallbackMonthly = switch (effectiveTier) {
      AppTier.free => 0,
      AppTier.premium => effectiveCycle == 'annual' ? 239 : 299,
      AppTier.enterprise => effectiveCycle == 'annual' ? 399 : 499,
    };
    final double resolvedMonthly = plan == null
        ? fallbackMonthly
        : (effectiveCycle == 'annual'
              ? plan.annualMonthlyAmount
              : plan.monthlyAmount);

    return SubscriptionSummary(
      tier: effectiveTier,
      status: status ?? _status,
      billingCycle: effectiveCycle,
      renewedAt: renewedAt ?? _session.renewedAt,
      expiresAt: expiresAt ?? _session.expiresAt,
      usage:
          usage ??
          (CustomerDataPolicy.allowDemo
              ? _source.accountUsage(effectiveTier)
              : {}),
      monthlyAmount: resolvedMonthly,
      annualMonthsBilled: _pricingCatalogue?.annualMonthsBilled ?? 12,
      cancelAtPeriodEnd:
          effectiveTier != AppTier.free && _session.cancelAtPeriodEnd,
      discountCode: _session.discountCode,
      discountPercent: _session.discountPercent,
      affiliateMilestone: affiliateMilestone,
    );
  }

  @override
  Future<AffiliateMilestoneStatus> getAffiliateMilestoneStatus() async {
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();
      if (targetUserId.isEmpty) {
        return const AffiliateMilestoneStatus(
          isAffiliate: false,
          paidReferralsCount: 0,
        );
      }
      try {
        final affRow = await client
            .from('affiliate_profiles')
            .select(
              'id, status, paid_referrals_count, active_referrals, complimentary_pro_unlocked',
            )
            .eq('id', targetUserId)
            .maybeSingle();
        if (affRow != null) {
          final int paidCount =
              (affRow['paid_referrals_count'] as num?)?.toInt() ??
              (affRow['active_referrals'] as num?)?.toInt() ??
              0;
          final bool active = affRow['status']?.toString() == 'active';
          final bool unlocked =
              active &&
              (affRow['complimentary_pro_unlocked'] == true || paidCount >= 50);
          return AffiliateMilestoneStatus(
            isAffiliate: true,
            paidReferralsCount: paidCount,
            threshold: 50,
            complimentaryProUnlocked: unlocked,
            currentCommissionInr: paidCount >= 50 ? 30.0 : 10.0,
          );
        }
        final appRow = await client
            .from('affiliate_applications')
            .select('status')
            .eq('user_id', targetUserId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        final String appStatus = appRow?['status']?.toString() ?? '';
        if (const {
          'pending',
          'pending_review',
          'approved',
          'active',
          'suspended',
        }.contains(appStatus)) {
          return const AffiliateMilestoneStatus(
            isAffiliate: true,
            paidReferralsCount: 0,
            threshold: 50,
            complimentaryProUnlocked: false,
            currentCommissionInr: 10.0,
          );
        }
      } catch (e) {
        debugPrint(
          'BillingSettingsRepositoryImpl.getAffiliateMilestoneStatus error: $e',
        );
      }
    }
    return const AffiliateMilestoneStatus(
      isAffiliate: false,
      paidReferralsCount: 0,
    );
  }

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
          .select(
            'user_id, billing_cycle, status, billing_provider, provider_subscription_id, renewed_at, expires_at',
          )
          .eq('user_id', targetUserId)
          .maybeSingle();
      final tier = counted.tier;
      final cycle = data?['billing_cycle'] as String? ?? 'monthly';
      _session.tier.value = tier;
      _session.billingCycle = cycle;
      _session.cancelAtPeriodEnd =
          tier != AppTier.free && data?['status'] == 'canceled';
      final renewed = DateTime.tryParse(data?['renewed_at']?.toString() ?? '');
      final expires = DateTime.tryParse(data?['expires_at']?.toString() ?? '');
      final effectiveRenewed = renewed ?? DateTime.now();
      final effectiveExpires =
          expires ??
          (tier == AppTier.free
              ? DateTime.fromMillisecondsSinceEpoch(0)
              : effectiveRenewed.add(
                  Duration(days: cycle == 'annual' ? 365 : 30),
                ));
      if (tier != AppTier.free) {
        _session.renewedAt = effectiveRenewed;
        _session.expiresAt = effectiveExpires;
      }
      final affiliateMilestone = await getAffiliateMilestoneStatus();
      return _summary(
        tier: tier,
        status: tier == AppTier.free
            ? 'canceled'
            : data?['status'] as String? ?? 'active',
        billingCycle: cycle,
        renewedAt: tier == AppTier.free
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : effectiveRenewed,
        expiresAt: effectiveExpires,
        affiliateMilestone: affiliateMilestone,
        usage: {
          'journal_trades_used': counted.tradesUsed,
          'journal_trades_limit': counted.tradesLimit,
          'ai_queries_used': counted.aiQueriesUsed,
          'ai_queries_limit': counted.aiQueriesLimit,
          'notes_used': counted.notesUsed,
          'notes_limit': counted.notesLimit,
          'live_playbooks_used': counted.livePlaybooksUsed,
          'live_playbooks_limit': counted.livePlaybooksLimit,
          'watchlists_used': counted.watchlistsUsed,
          'watchlists_limit': counted.watchlistsLimit,
          'alerts_used': counted.alertsUsed,
          'alerts_limit': counted.alertsLimit,
          'community_posts_today': counted.communityPostsToday,
          'community_posts_per_day_limit': counted.communityPostsPerDayLimit,
          'community_comments_today': counted.communityCommentsToday,
          'community_comments_per_day_limit':
              counted.communityCommentsPerDayLimit,
          'allow_pdf_export': counted.allowPdfExport,
          'allow_advanced_backtest': counted.allowAdvancedBacktest,
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

  static String? normalizePaidTier(String rawTierId) {
    final normalized = rawTierId.trim().toLowerCase();
    if ({'tier_pro', 'tier_basic', 'premium', 'basic'}.contains(normalized)) {
      return 'premium';
    }
    if ({
      'tier_enterprise',
      'enterprise',
      'pro',
      'business',
    }.contains(normalized)) {
      return 'enterprise';
    }
    return null;
  }

  @override
  Future<ReferralDiscountQuote> validateReferralCode({
    required String code,
    required String tierId,
    required String billingCycle,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    final normalizedTier = normalizePaidTier(tierId);
    final normalizedCycle = billingCycle == 'yearly' ? 'annual' : billingCycle;
    if (cleanCode.isEmpty) {
      return const ReferralDiscountQuote(
        valid: false,
        errorCode: 'invalid_code',
        message: 'Enter a referral code to apply.',
      );
    }
    if (normalizedTier == null ||
        (normalizedCycle != 'monthly' && normalizedCycle != 'annual')) {
      return const ReferralDiscountQuote(
        valid: false,
        errorCode: 'invalid_plan',
        message: 'Choose Basic or Pro with Monthly or Annual billing.',
      );
    }
    final client = SupabaseConfig.client;
    if (client?.auth.currentUser != null) {
      try {
        final response = await client!.functions.invoke(
          'create-business-checkout',
          body: <String, Object?>{
            'action': 'validate_referral',
            'referral_code': cleanCode,
            'tier': normalizedTier,
            'tier_id': tierId,
            'billing_cycle': normalizedCycle,
          },
        );
        if (response.data is Map) {
          return ReferralDiscountQuote.fromJson(
            Map<String, dynamic>.from(response.data as Map),
          );
        }
      } catch (_) {
        // Fall through to direct RPC validation when Edge Function is unavailable
      }
      try {
        final rpcData = await client!.rpc(
          'validate_referral_code',
          params: <String, Object?>{
            'p_code': cleanCode,
            'p_tier': normalizedTier,
            'p_billing_cycle': normalizedCycle,
          },
        );
        if (rpcData is Map) {
          return ReferralDiscountQuote.fromJson(
            Map<String, dynamic>.from(rpcData),
          );
        }
      } catch (e) {
        return ReferralDiscountQuote(
          valid: false,
          errorCode: 'validation_failed',
          message: e.toString().replaceFirst('Bad state: ', ''),
        );
      }
    }
    return const ReferralDiscountQuote(
      valid: false,
      errorCode: 'auth_required',
      message: 'Sign in to validate a referral code.',
    );
  }

  @override
  Future<CheckoutSession> startCheckout(
    String tierId,
    String billingCycle, {
    String? referralCode,
  }) async {
    final normalizedTier = normalizePaidTier(tierId);
    final normalizedCycle = billingCycle == 'yearly' ? 'annual' : billingCycle;
    if (normalizedTier == null ||
        (normalizedCycle != 'monthly' && normalizedCycle != 'annual')) {
      throw StateError('Choose a supported plan and billing cycle.');
    }
    final client = SupabaseConfig.client;
    if (client?.auth.currentUser == null) {
      throw StateError('Sign in to start subscription checkout.');
    }
    final cleanRef = referralCode?.trim();
    final response = await client!.functions.invoke(
      'create-business-checkout',
      body: <String, Object?>{
        'tier': normalizedTier,
        'tier_id': tierId,
        'billing_cycle': normalizedCycle,
        if (cleanRef != null && cleanRef.isNotEmpty) 'referral_code': cleanRef,
      },
    );
    if (response.status != 200 || response.data is! Map) {
      final errMsg = response.data is Map
          ? (response.data as Map)['error']?.toString()
          : null;
      throw StateError(errMsg ?? 'Subscription checkout is not available yet.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final id = data['subscription_id'];
    final url = data['checkout_url'];
    final serverKeyId = data['key_id']?.toString();
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
          'api.razorpay.com',
        }.contains(checkout.host)) {
      throw StateError('The payment provider returned an invalid checkout.');
    }
    final resolvedKeyId =
        (serverKeyId != null && serverKeyId.trim().isNotEmpty)
        ? serverKeyId.trim()
        : EnvConfig.razorpayKeyId;
    return CheckoutSession(
      sessionId: id,
      url: url,
      checkoutUrl: url,
      keyId: resolvedKeyId,
      amountPaise: (data['amount_paise'] as num?)?.toInt(),
      discountPaise: (data['discount_paise'] as num?)?.toInt() ?? 0,
      referralCode: data['referral_code']?.toString(),
      replacesSubscriptionId: data['replaces_subscription_id']?.toString(),
    );
  }

  @override
  Future<bool> verifyCheckout({
    required String subscriptionId,
    String? paymentId,
    String? signature,
  }) async {
    final client = SupabaseConfig.client;
    if (client?.auth.currentUser == null) {
      throw StateError('Sign in to verify your subscription.');
    }
    final response = await client!.functions.invoke(
      'create-business-checkout',
      body: {
        'action': 'verify',
        'subscription_id': subscriptionId,
        'razorpay_subscription_id': subscriptionId,
        'razorpay_payment_id': ?paymentId,
        'razorpay_signature': ?signature,
      },
    );
    if (response.status != 200 || response.data is! Map) {
      return false;
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final verified = data['verified'] == true;
    if (verified) {
      final tierStr = data['tier']?.toString();
      final cycleStr = data['billing_cycle']?.toString() ?? 'monthly';
      if (tierStr == 'premium') {
        _session.startPeriod(AppTier.premium, cycleStr);
      } else if (tierStr == 'enterprise') {
        _session.startPeriod(AppTier.enterprise, cycleStr);
      }
      _session.cancelAtPeriodEnd = false;
      try {
        await CustomerQuotaUsage.fetch();
      } catch (_) {}
    }
    return verified;
  }

  @override
  Future<SubscriptionSummary> setCancelAtPeriodEnd(bool cancel) async {
    if (!cancel) {
      throw StateError(
        'To restart a cancelled subscription, start a new checkout from Change Plan.',
      );
    }
    await cancelSubscription(reason: 'Stopped renewal at period end');
    return getSubscription();
  }

  @override
  Future<int?> redeemCoupon(String code) async {
    // Live production discounts are exclusively server-validated via
    // validateReferralCode and Razorpay Subscription Offers.
    return null;
  }

  @override
  Future<RetentionOffer?> getRetentionOffer() async {
    // Retention offers are disabled until backed by server-verified Razorpay offers.
    return null;
  }

  @override
  Future<PaymentMethodSummary?> getPaymentMethod() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        if (targetUserId.isNotEmpty) {
          final subData = await client
              .from('subscriptions')
              .select(
                'tier, status, billing_provider, provider_subscription_id, expires_at',
              )
              .eq('user_id', targetUserId)
              .maybeSingle();
          final subId =
              subData?['provider_subscription_id']?.toString().trim() ?? '';
          if (subId.isEmpty) return null;
          final provider =
              subData?['billing_provider']?.toString().trim() ?? 'razorpay';
          final expires =
              DateTime.tryParse(subData?['expires_at']?.toString() ?? '') ??
              _session.expiresAt;
          return PaymentMethodSummary(
            brand: provider == 'revenuecat' ? 'App Store' : 'Razorpay',
            last4: subId,
            expMonth: expires.month,
            expYear: expires.year,
          );
        }
      } catch (e) {
        debugPrint('BillingSettingsRepositoryImpl.getPaymentMethod error: $e');
      }
      return null;
    }
    return null;
  }

  @override
  Future<CheckoutSession> startPaymentMethodUpdate() async {
    throw StateError(
      'Payment mandates are updated through Razorpay Checkout when changing or renewing your plan.',
    );
  }

  @override
  Future<List<Invoice>> getBillingHistory() async {
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();
      if (targetUserId.isEmpty) return const <Invoice>[];

      // 1. Read real rows from public.invoices
      try {
        final res = await client
            .from('invoices')
            .select(
              'id, user_id, amount, currency, status, issued_at, pdf_url, line_items, provider, provider_subscription_id, provider_payment_id',
            )
            .eq('user_id', targetUserId)
            .order('issued_at', ascending: false)
            .limit(50);

        if ((res as List).isNotEmpty) {
          final list = <Invoice>[];
          for (final item in res) {
            final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
            final rawItems = item['line_items'] as List<dynamic>? ?? [];
            final lineItems = rawItems.map((li) {
              final map = Map<String, dynamic>.from(li as Map);
              return InvoiceLineItem(
                description:
                    map['description']?.toString() ?? 'Subscription Charge',
                amount: (map['amount'] as num?)?.toDouble() ?? amount,
                quantity: (map['quantity'] as num?)?.toInt() ?? 1,
              );
            }).toList();

            final paymentId =
                item['provider_payment_id']?.toString().trim() ?? '';
            final subId =
                item['provider_subscription_id']?.toString().trim() ?? '';
            final String? paymentLabel = paymentId.isNotEmpty
                ? 'Razorpay ($paymentId)'
                : (subId.isNotEmpty ? 'Razorpay ($subId)' : null);

            list.add(
              Invoice(
                id: item['id']?.toString() ?? '',
                amount: amount,
                currency: item['currency']?.toString() ?? 'INR',
                status: item['status']?.toString() ?? 'paid',
                issuedAt:
                    DateTime.tryParse(item['issued_at']?.toString() ?? '') ??
                    DateTime.now(),
                pdfUrl: item['pdf_url']?.toString() ?? '',
                taxPercent: _taxPercent,
                paymentMethodLabel: paymentLabel,
                lineItems: lineItems,
              ),
            );
          }
          return list;
        }
      } catch (e) {
        debugPrint(
          'BillingSettingsRepositoryImpl.getBillingHistory invoices query error: $e',
        );
      }

      // 2. Fallback only to real settled rows in public.billing_checkout_intents
      try {
        final intents = await client
            .from('billing_checkout_intents')
            .select(
              'id, tier, billing_cycle, razorpay_subscription_id, expected_amount_paise, checkout_url, status, created_at, updated_at',
            )
            .eq('user_id', targetUserId)
            .eq('status', 'active')
            .order('created_at', ascending: false)
            .limit(25);

        if ((intents as List).isNotEmpty) {
          final list = <Invoice>[];
          for (final row in intents) {
            final subId =
                row['razorpay_subscription_id']?.toString().trim() ?? '';
            if (subId.isEmpty) continue;
            final paise =
                (row['expected_amount_paise'] as num?)?.toDouble() ?? 0;
            final amount = paise / 100.0;
            final tierStr = row['tier']?.toString() ?? 'premium';
            final planName = tierStr == 'enterprise'
                ? 'AlphaJournal Pro'
                : 'AlphaJournal Basic';
            final cycleStr = row['billing_cycle']?.toString() ?? 'monthly';
            final cycleLabel = cycleStr == 'annual' ? 'Annual' : 'Monthly';
            final issuedAt =
                DateTime.tryParse(
                  row['updated_at']?.toString() ??
                      row['created_at']?.toString() ??
                      '',
                ) ??
                DateTime.now();

            list.add(
              Invoice(
                id: 'inv_$subId',
                amount: amount,
                currency: 'INR',
                status: 'paid',
                issuedAt: issuedAt,
                pdfUrl: row['checkout_url']?.toString() ?? '',
                taxPercent: _taxPercent,
                paymentMethodLabel: 'Razorpay ($subId)',
                lineItems: <InvoiceLineItem>[
                  InvoiceLineItem(
                    description: '$planName ($cycleLabel subscription)',
                    amount: amount,
                    quantity: 1,
                  ),
                ],
              ),
            );
          }
          return list;
        }
      } catch (e) {
        debugPrint(
          'BillingSettingsRepositoryImpl.getBillingHistory intents query error: $e',
        );
      }

      return const <Invoice>[];
    }
    return const <Invoice>[];
  }

  @override
  Future<Invoice> getInvoice(String invoiceId) async {
    final rows = await getBillingHistory();
    for (final Invoice invoice in rows) {
      if (invoice.id == invoiceId) return invoice;
    }
    throw StateError('Invoice $invoiceId not found');
  }

  /// Tax already included in every price the catalogue quotes.
  static const double _taxPercent = 18;

  @override
  Future<void> cancelSubscription({String? reason}) async {
    final client = SupabaseConfig.client;
    if (client?.auth.currentUser == null) {
      throw StateError('Sign in to manage your subscription.');
    }
    final response = await client!.functions.invoke(
      'create-business-checkout',
      body: {'action': 'cancel', 'reason': ?reason},
    );
    if (response.status != 200) {
      final errMsg = response.data is Map
          ? (response.data as Map)['error']?.toString()
          : null;
      throw StateError(
        errMsg ?? 'Could not cancel subscription through billing provider.',
      );
    }
    _session.cancelAtPeriodEnd = true;
  }
}
