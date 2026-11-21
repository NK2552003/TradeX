import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/billing/razorpay_web_checkout.dart';
import 'package:alphajournal/core/billing/revenuecat_billing.dart';
import 'package:alphajournal/core/config/app_constants.dart';
import 'package:alphajournal/core/config/customer_data_policy.dart';
import 'package:alphajournal/core/config/customer_quota_usage.dart';
import 'package:alphajournal/core/config/env_config.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/core/data/app_session.dart';
import 'package:alphajournal/features/admin_console/data/admin_console_repository.dart';
import 'package:alphajournal/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:alphajournal/features/public_site/data/public_site_repository.dart';
import 'package:alphajournal/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:alphajournal/features/settings/presentation/widgets/referral_code_prompt_dialog.dart';
import 'package:alphajournal/features/settings/models/desk_risk_model.dart';
import 'package:alphajournal/features/settings/presentation/pages/trader/change_plan_page.dart';

/// Subscription tier entitlements and quota limits on the customer (trader) side.
/// All pricing is denominated in Indian Rupees (INR / ₹).
@immutable
class CustomerTierQuota {
  const CustomerTierQuota({
    required this.tier,
    required this.planName,
    required this.monthlyPriceInr,
    required this.maxNotes,
    required this.maxTrades,
    required this.maxLiveStrategies,
    required this.maxWatchlists,
    required this.maxAiQueriesPerMonth,
    required this.allowPdfExport,
    required this.allowAdvancedBacktest,
    int? annualMonthlyPriceInr,
    this.maxAlerts = 3,
    this.maxCommunityPostsPerDay = 2,
    this.maxCommunityCommentsPerDay = 10,
  }) : annualMonthlyPriceInr = annualMonthlyPriceInr ?? monthlyPriceInr;

  final AppTier tier;
  final String planName;
  final int monthlyPriceInr;
  final int annualMonthlyPriceInr;
  final int maxNotes;
  final int maxTrades;
  final int maxLiveStrategies;
  final int maxWatchlists;
  final int maxAiQueriesPerMonth;
  final bool allowPdfExport;
  final bool allowAdvancedBacktest;
  final int maxAlerts;
  final int maxCommunityPostsPerDay;
  final int maxCommunityCommentsPerDay;

  int get annualTotalPriceInr => annualMonthlyPriceInr * 12;

  String get priceLabel => monthlyPriceInr == 0
      ? '₹0 / mo'
      : '${formatInrAmount(monthlyPriceInr)} / mo';

  static final Map<AppTier, CustomerTierQuota> _published = {};

  static bool get hasPublishedQuotas => _published.isNotEmpty;

  static CustomerTierQuota defaultsForTier(AppTier tier) =>
      _baselineForTier(tier);

  static void installPublishedCatalogue(Map<String, dynamic> catalogue) {
    final plans = catalogue['plans'];
    if (plans is! List) throw const FormatException('Missing pricing plans.');
    final next = <AppTier, CustomerTierQuota>{};
    for (final raw in plans) {
      final plan = Map<String, dynamic>.from(raw as Map);
      final tier = AppTier.values.firstWhere(
        (value) => value.name == plan['tier'],
        orElse: () => throw const FormatException('Unknown subscription tier.'),
      );
      final limits = Map<String, dynamic>.from(plan['limits'] as Map);
      final base = _baselineForTier(tier);
      int requiredLimit(String key) {
        final value = limits[key];
        if (value is! int || value < 0) {
          throw FormatException('Invalid $key limit for ${tier.name}.');
        }
        return value;
      }

      int optionalLimit(String key, int fallback) {
        final value = limits[key];
        if (value is int && value >= 0) return value;
        return fallback;
      }

      bool optionalFlag(String key, bool fallback) {
        final value = limits[key];
        if (value is bool) return value;
        return fallback;
      }

      next[tier] = CustomerTierQuota(
        tier: tier,
        planName: plan['name']?.toString() ?? base.planName,
        monthlyPriceInr: (plan['monthly_amount'] as num).round(),
        annualMonthlyPriceInr:
            ((plan['annual_monthly_amount'] as num?) ??
                    (plan['monthly_amount'] as num))
                .round(),
        maxNotes: requiredLimit('notes'),
        maxTrades: requiredLimit('trades'),
        maxLiveStrategies: requiredLimit('live_playbooks'),
        maxWatchlists: optionalLimit('watchlists', base.maxWatchlists),
        maxAiQueriesPerMonth: requiredLimit('ai_queries_per_month'),
        allowPdfExport: optionalFlag('allow_pdf_export', base.allowPdfExport),
        allowAdvancedBacktest: optionalFlag(
          'allow_advanced_backtest',
          base.allowAdvancedBacktest,
        ),
        maxAlerts: optionalLimit('alerts', base.maxAlerts),
        maxCommunityPostsPerDay: optionalLimit(
          'community_posts_per_day',
          base.maxCommunityPostsPerDay,
        ),
        maxCommunityCommentsPerDay: optionalLimit(
          'community_comments_per_day',
          base.maxCommunityCommentsPerDay,
        ),
      );
    }
    if (next.length != AppTier.values.length) {
      throw const FormatException('Pricing catalogue must define every tier.');
    }
    _published
      ..clear()
      ..addAll(next);
  }

  static Future<void> refreshPublishedCatalogue() async {
    final catalogue = await publicSiteRepository().pricing();
    installPublishedCatalogue(catalogue);
  }

  static CustomerTierQuota forTier(AppTier tier) =>
      _published[tier] ?? _baselineForTier(tier);

  static CustomerTierQuota _baselineForTier(AppTier tier) => switch (tier) {
    AppTier.free => const CustomerTierQuota(
      tier: AppTier.free,
      planName: 'AlphaJournal Free',
      monthlyPriceInr: 0,
      annualMonthlyPriceInr: 0,
      maxNotes: 3,
      maxTrades: 15,
      maxLiveStrategies: 1,
      maxWatchlists: 1,
      maxAiQueriesPerMonth: 5,
      allowPdfExport: false,
      allowAdvancedBacktest: false,
      maxAlerts: 3,
      maxCommunityPostsPerDay: 2,
      maxCommunityCommentsPerDay: 10,
    ),
    AppTier.premium => const CustomerTierQuota(
      tier: AppTier.premium,
      planName: 'AlphaJournal Basic',
      monthlyPriceInr: 299,
      annualMonthlyPriceInr: 239,
      maxNotes: 25,
      maxTrades: 100,
      maxLiveStrategies: 3,
      maxWatchlists: 5,
      maxAiQueriesPerMonth: 20,
      allowPdfExport: false,
      allowAdvancedBacktest: false,
      maxAlerts: 25,
      maxCommunityPostsPerDay: 15,
      maxCommunityCommentsPerDay: 50,
    ),
    AppTier.enterprise => const CustomerTierQuota(
      tier: AppTier.enterprise,
      planName: 'AlphaJournal Pro',
      monthlyPriceInr: 499,
      annualMonthlyPriceInr: 399,
      maxNotes: 10000,
      maxTrades: 50000,
      maxLiveStrategies: 250,
      maxWatchlists: 100,
      maxAiQueriesPerMonth: 5000,
      allowPdfExport: true,
      allowAdvancedBacktest: true,
      maxAlerts: 500,
      maxCommunityPostsPerDay: 100,
      maxCommunityCommentsPerDay: 500,
    ),
  };
}

/// Result of evaluating a customer trade or workspace action against
/// subscription quotas and institutional desk risk rules.
@immutable
class CustomerLimitEvaluation {
  const CustomerLimitEvaluation({
    required this.allowed,
    this.requiresManagerApproval = false,
    this.isCircuitBreakerHalted = false,
    this.exceedsPositionCap = false,
    this.missingMandatoryStopLoss = false,
    this.title,
    this.message,
  });

  final bool allowed;
  final bool requiresManagerApproval;
  final bool isCircuitBreakerHalted;
  final bool exceedsPositionCap;
  final bool missingMandatoryStopLoss;
  final String? title;
  final String? message;
}

/// Central helper for checking and enforcing customer-side subscription tier
/// limitations and institutional desk risk rules.
class CustomerLimitations {
  CustomerLimitations._();

  static CustomerTierQuota get currentQuota =>
      CustomerTierQuota.forTier(AppSession.instance.tier.value);

  /// Checks whether the customer can create another note under their active plan.
  static Future<bool> checkCanCreateNote(
    BuildContext context, {
    required int currentNoteCount,
  }) async {
    if (!await _refreshForAction(context) || !context.mounted) return false;
    final usage = SupabaseConfig.isConfigured
        ? await _readUsageForAction(context)
        : null;
    if (SupabaseConfig.isConfigured && usage == null) return false;
    if (!context.mounted) return false;
    final CustomerTierQuota quota = currentQuota;
    final limit = usage?.notesLimit ?? quota.maxNotes;
    if ((usage?.notesUsed ?? currentNoteCount) < limit) return true;
    await showPlanUpgradeDialog(
      context,
      featureTitle: 'Note Limit Reached ($limit Notes)',
      reason:
          'Your ${quota.planName} plan includes up to $limit research notes. Contact support to review your account allowance.',
    );
    return false;
  }

  /// Checks whether the customer can log another trade under their active plan
  /// and whether the Institutional Desk Circuit Breaker allows execution.
  static Future<bool> checkCanCreateTrade(
    BuildContext context, {
    required int currentTradeCount,
  }) async {
    if (!await _refreshForAction(context)) return false;
    final String breakerState = await AdminConsoleRepository.instance
        .getCircuitBreakerState();
    if (!context.mounted) return false;
    if (breakerState == 'halted') {
      final String reason =
          AdminConsoleRepository.instance.killswitchReason ??
          'Institutional Risk Officer engaged the Emergency Desk Killswitch.';
      UiToast.error(
        context,
        title: 'Desk Execution Halted',
        message: '$reason New trade logging is temporarily locked.',
      );
      return false;
    }

    final usage = SupabaseConfig.isConfigured
        ? await _readUsageForAction(context)
        : null;
    if (SupabaseConfig.isConfigured && usage == null) return false;
    if (!context.mounted) return false;
    final CustomerTierQuota quota = currentQuota;
    final limit = usage?.tradesLimit ?? quota.maxTrades;
    if ((usage?.tradesUsed ?? currentTradeCount) < limit) return true;
    await showPlanUpgradeDialog(
      context,
      featureTitle: 'Journal Quota Reached ($limit Trades)',
      reason:
          'Your ${quota.planName} plan supports up to $limit logged trades. Contact support to review your account allowance.',
    );
    return false;
  }

  /// Checks whether the customer can create or activate another strategy playbook.
  static Future<bool> checkCanCreateStrategy(
    BuildContext context, {
    required int currentLiveStrategyCount,
  }) async {
    if (!await _refreshForAction(context) || !context.mounted) return false;
    final usage = SupabaseConfig.isConfigured
        ? await _readUsageForAction(context)
        : null;
    if (SupabaseConfig.isConfigured && usage == null) return false;
    if (!context.mounted) return false;
    final CustomerTierQuota quota = currentQuota;
    final limit = usage?.livePlaybooksLimit ?? quota.maxLiveStrategies;
    if ((usage?.livePlaybooksUsed ?? currentLiveStrategyCount) < limit) {
      return true;
    }
    await showPlanUpgradeDialog(
      context,
      featureTitle: 'Active Playbook Limit Reached ($limit Live)',
      reason:
          'Your ${quota.planName} plan allows up to $limit live playbooks. Contact support to review your account allowance.',
    );
    return false;
  }

  /// True when [message] indicates a server or local AI quota exhaustion.
  static bool isQuotaErrorMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('ai_queries_per_month') ||
        lower.contains('limit reached') ||
        lower.contains('quota exceeded') ||
        lower.contains('quota exhausted') ||
        lower.contains('monthly ai quota') ||
        lower.contains('daily ai request limit');
  }

  /// Current monthly AI query allowance for the active tier.
  static int get effectiveAiQueriesLimit =>
      AppSession.instance.aiQueriesLimit.value ??
      currentQuota.maxAiQueriesPerMonth;

  static bool isAiQuotaExhausted({int? usedOverride, int? limitOverride}) {
    final limit = limitOverride ?? effectiveAiQueriesLimit;
    final used = usedOverride ?? AppSession.instance.aiQueriesUsed.value;
    return limit <= 0 || used >= limit;
  }

  static int aiQueriesRemaining({int? usedOverride, int? limitOverride}) {
    final limit = limitOverride ?? effectiveAiQueriesLimit;
    final used = usedOverride ?? AppSession.instance.aiQueriesUsed.value;
    return (limit - used).clamp(0, 999999);
  }

  static void markAiQuotaExhausted({int? limit}) {
    final max = limit ?? effectiveAiQueriesLimit;
    if (AppSession.instance.aiQueriesUsed.value < max) {
      AppSession.instance.aiQueriesUsed.value = max;
    }
  }

  /// Checks whether the customer still has monthly AI credits available.
  static Future<bool> checkCanUseAi(
    BuildContext context, {
    String featureLabel = 'AI Assistant',
    bool showDialogOnLimit = true,
  }) async {
    if (!await _refreshForAction(context) || !context.mounted) return false;
    final usage = SupabaseConfig.isConfigured
        ? await _readUsageForAction(context)
        : null;
    if (SupabaseConfig.isConfigured && usage == null) return false;
    if (!context.mounted) return false;
    final quota = currentQuota;
    final limit = usage?.aiQueriesLimit ?? quota.maxAiQueriesPerMonth;
    final used =
        usage?.aiQueriesUsed ?? AppSession.instance.aiQueriesUsed.value;
    if (limit > 0 && used < limit) return true;
    markAiQuotaExhausted(limit: limit);
    if (showDialogOnLimit && context.mounted) {
      await showPlanUpgradeDialog(
        context,
        featureTitle: '$featureLabel Quota Reached ($used/$limit)',
        reason:
            'Your ${quota.planName} plan includes $limit AI prompts per month. Upgrade your plan or wait for the monthly cycle reset.',
      );
    }
    return false;
  }

  /// Repository-safe watchlist creation check (throws [StateError] when capped).
  static Future<void> assertCanCreateWatchlist({
    required int currentWatchlistCount,
  }) async {
    if (SupabaseConfig.isConfigured &&
        SupabaseConfig.client?.auth.currentUser != null) {
      await CustomerTierQuota.refreshPublishedCatalogue().catchError((_) {});
      final usage = await CustomerQuotaUsage.fetch();
      final limit = usage.watchlistsLimit;
      if (usage.watchlistsUsed >= limit) {
        throw StateError(
          'Watchlist limit reached (${usage.watchlistsUsed} of $limit) on ${CustomerTierQuota.forTier(usage.tier).planName}.',
        );
      }
      return;
    }
    final quota = currentQuota;
    if (currentWatchlistCount >= quota.maxWatchlists) {
      throw StateError(
        'Watchlist limit reached ($currentWatchlistCount of ${quota.maxWatchlists}) on ${quota.planName}.',
      );
    }
  }

  /// Checks whether the customer can create another watchlist.
  static Future<bool> checkCanCreateWatchlist(
    BuildContext context, {
    required int currentWatchlistCount,
  }) async {
    if (!await _refreshForAction(context) || !context.mounted) return false;
    final usage = SupabaseConfig.isConfigured
        ? await _readUsageForAction(context)
        : null;
    if (SupabaseConfig.isConfigured && usage == null) return false;
    if (!context.mounted) return false;
    final quota = currentQuota;
    final limit = usage?.watchlistsLimit ?? quota.maxWatchlists;
    final used = usage?.watchlistsUsed ?? currentWatchlistCount;
    if (used < limit) return true;
    await showPlanUpgradeDialog(
      context,
      featureTitle: 'Watchlist Limit Reached ($used/$limit)',
      reason:
          'Your ${quota.planName} plan supports up to $limit watchlist${limit == 1 ? '' : 's'}. Upgrade your tier to organize more watchlists.',
    );
    return false;
  }

  /// Repository-safe price alert check (throws [StateError] when capped).
  static Future<void> assertCanCreatePriceAlert({
    int? currentAlertCount,
  }) async {
    if (SupabaseConfig.isConfigured &&
        SupabaseConfig.client?.auth.currentUser != null) {
      await CustomerTierQuota.refreshPublishedCatalogue().catchError((_) {});
      final usage = await CustomerQuotaUsage.fetch();
      if (usage.alertsUsed >= usage.alertsLimit) {
        throw StateError(
          'Price alert limit reached (${usage.alertsUsed} of ${usage.alertsLimit}) on ${CustomerTierQuota.forTier(usage.tier).planName}.',
        );
      }
      return;
    }
    final quota = currentQuota;
    if (currentAlertCount != null && currentAlertCount >= quota.maxAlerts) {
      throw StateError(
        'Price alert limit reached ($currentAlertCount of ${quota.maxAlerts}) on ${quota.planName}.',
      );
    }
  }

  /// Checks whether the customer can arm another price alert.
  static Future<bool> checkCanCreatePriceAlert(
    BuildContext context, {
    int currentAlertCount = 0,
  }) async {
    if (!await _refreshForAction(context) || !context.mounted) return false;
    final usage = SupabaseConfig.isConfigured
        ? await _readUsageForAction(context)
        : null;
    if (SupabaseConfig.isConfigured && usage == null) return false;
    if (!context.mounted) return false;
    final quota = currentQuota;
    final limit = usage?.alertsLimit ?? quota.maxAlerts;
    final used = usage?.alertsUsed ?? currentAlertCount;
    if (used < limit) return true;
    await showPlanUpgradeDialog(
      context,
      featureTitle: 'Price Alert Limit Reached ($used/$limit)',
      reason:
          'Your ${quota.planName} plan supports up to $limit active price alerts. Remove an existing alert or upgrade your tier.',
    );
    return false;
  }

  /// Synchronous local daily post quota check for offline/optimistic flows.
  static void assertCanCreateCommunityPostSync(int todayPostCount) {
    final quota = currentQuota;
    if (todayPostCount >= quota.maxCommunityPostsPerDay) {
      throw StateError(
        'Daily community post limit reached ($todayPostCount of ${quota.maxCommunityPostsPerDay} today) on ${quota.planName}.',
      );
    }
  }

  /// Repository-safe daily community post check.
  static Future<void> assertCanCreateCommunityPost({
    int? todayPostCount,
  }) async {
    if (SupabaseConfig.isConfigured &&
        SupabaseConfig.client?.auth.currentUser != null) {
      await CustomerTierQuota.refreshPublishedCatalogue().catchError((_) {});
      final usage = await CustomerQuotaUsage.fetch();
      if (usage.communityPostsToday >= usage.communityPostsPerDayLimit) {
        throw StateError(
          'Daily community post limit reached (${usage.communityPostsToday} of ${usage.communityPostsPerDayLimit} today) on ${CustomerTierQuota.forTier(usage.tier).planName}.',
        );
      }
      return;
    }
    if (todayPostCount != null) {
      assertCanCreateCommunityPostSync(todayPostCount);
    }
  }

  /// Checks whether the customer can publish another community post today.
  static Future<bool> checkCanCreateCommunityPost(
    BuildContext context, {
    int todayPostCount = 0,
  }) async {
    if (!await _refreshForAction(context) || !context.mounted) return false;
    final usage = SupabaseConfig.isConfigured
        ? await _readUsageForAction(context)
        : null;
    if (SupabaseConfig.isConfigured && usage == null) return false;
    if (!context.mounted) return false;
    final quota = currentQuota;
    final limit =
        usage?.communityPostsPerDayLimit ?? quota.maxCommunityPostsPerDay;
    final used = usage?.communityPostsToday ?? todayPostCount;
    if (used < limit) return true;
    await showPlanUpgradeDialog(
      context,
      featureTitle: 'Daily Post Limit Reached ($used/$limit)',
      reason:
          'Your ${quota.planName} plan allows up to $limit community post${limit == 1 ? '' : 's'} per day. Try again tomorrow or upgrade for higher daily capacity.',
    );
    return false;
  }

  /// Synchronous local daily comment quota check for offline/optimistic flows.
  static void assertCanCreateCommunityCommentSync(int todayCommentCount) {
    final quota = currentQuota;
    if (todayCommentCount >= quota.maxCommunityCommentsPerDay) {
      throw StateError(
        'Daily comment limit reached ($todayCommentCount of ${quota.maxCommunityCommentsPerDay} today) on ${quota.planName}.',
      );
    }
  }

  /// Repository-safe daily community comment check.
  static Future<void> assertCanCreateCommunityComment({
    int? todayCommentCount,
  }) async {
    if (SupabaseConfig.isConfigured &&
        SupabaseConfig.client?.auth.currentUser != null) {
      await CustomerTierQuota.refreshPublishedCatalogue().catchError((_) {});
      final usage = await CustomerQuotaUsage.fetch();
      if (usage.communityCommentsToday >= usage.communityCommentsPerDayLimit) {
        throw StateError(
          'Daily community comment limit reached (${usage.communityCommentsToday} of ${usage.communityCommentsPerDayLimit} today) on ${CustomerTierQuota.forTier(usage.tier).planName}.',
        );
      }
      return;
    }
    if (todayCommentCount != null) {
      assertCanCreateCommunityCommentSync(todayCommentCount);
    }
  }

  /// Checks whether the customer can post another community comment/reply today.
  static Future<bool> checkCanCreateCommunityComment(
    BuildContext context, {
    int todayCommentCount = 0,
  }) async {
    if (!await _refreshForAction(context) || !context.mounted) return false;
    final usage = SupabaseConfig.isConfigured
        ? await _readUsageForAction(context)
        : null;
    if (SupabaseConfig.isConfigured && usage == null) return false;
    if (!context.mounted) return false;
    final quota = currentQuota;
    final limit =
        usage?.communityCommentsPerDayLimit ?? quota.maxCommunityCommentsPerDay;
    final used = usage?.communityCommentsToday ?? todayCommentCount;
    if (used < limit) return true;
    await showPlanUpgradeDialog(
      context,
      featureTitle: 'Daily Comment Limit Reached ($used/$limit)',
      reason:
          'Your ${quota.planName} plan allows up to $limit comments per day. Try again tomorrow or upgrade your tier.',
    );
    return false;
  }

  /// Checks whether PDF / CSV report export is unlocked for the customer's tier.
  static Future<bool> checkCanExportPdf(
    BuildContext context, {
    String featureLabel = 'PDF & CSV Export',
  }) async {
    if (!await _refreshForAction(context) || !context.mounted) return false;
    final usage = SupabaseConfig.isConfigured
        ? await _readUsageForAction(context)
        : null;
    if (SupabaseConfig.isConfigured && usage == null) return false;
    if (!context.mounted) return false;
    final quota = currentQuota;
    final allowed = usage?.allowPdfExport ?? quota.allowPdfExport;
    if (allowed) return true;
    await showPlanUpgradeDialog(
      context,
      featureTitle: '$featureLabel (Pro Tier)',
      reason:
          '${quota.planName} does not include publication-grade PDF or CSV exports. Upgrade to AlphaJournal Pro (₹499/mo) to unlock unlimited exports.',
    );
    return false;
  }

  /// Checks whether advanced backtesting & institutional analytics are unlocked.
  static Future<bool> checkCanUseAdvancedBacktest(
    BuildContext context, {
    String featureLabel = 'Advanced Backtesting & Analytics',
  }) async {
    if (!await _refreshForAction(context) || !context.mounted) return false;
    final usage = SupabaseConfig.isConfigured
        ? await _readUsageForAction(context)
        : null;
    if (SupabaseConfig.isConfigured && usage == null) return false;
    if (!context.mounted) return false;
    final quota = currentQuota;
    final allowed = usage?.allowAdvancedBacktest ?? quota.allowAdvancedBacktest;
    if (allowed) return true;
    await showPlanUpgradeDialog(
      context,
      featureTitle: '$featureLabel (Pro Tier)',
      reason:
          '${quota.planName} includes core strategy tracking. Upgrade to AlphaJournal Pro (₹499/mo) for advanced backtesting and institutional analytics.',
    );
    return false;
  }

  /// Evaluates a trade order against Institutional Desk Risk limits before saving.
  static Future<CustomerLimitEvaluation> evaluateTradeRisk({
    required String symbol,
    required double entryPrice,
    required double quantity,
    required double? stopLoss,
  }) async {
    final String breakerState = await AdminConsoleRepository.instance
        .getCircuitBreakerState();
    if (breakerState == 'halted') {
      final String reason =
          AdminConsoleRepository.instance.killswitchReason ??
          'Emergency Desk Killswitch is active.';
      return CustomerLimitEvaluation(
        allowed: false,
        isCircuitBreakerHalted: true,
        title: 'Desk Killswitch Active',
        message:
            'New positions are halted by Desk Risk Administration: $reason',
      );
    }

    final DeskRiskModel risk = await AdminConsoleRepository.instance
        .getDeskRiskConfig();
    final double notionalInr =
        (entryPrice.isFinite &&
            quantity.isFinite &&
            entryPrice > 0 &&
            quantity > 0)
        ? entryPrice * quantity
        : 0;

    final double effectiveMaxPosition = breakerState == 'tripped'
        ? risk.maxPositionPerTrader * 0.5
        : risk.maxPositionPerTrader;

    if (risk.requireStopLoss && (stopLoss == null || stopLoss <= 0)) {
      return const CustomerLimitEvaluation(
        allowed: false,
        missingMandatoryStopLoss: true,
        title: 'Mandatory Stop-Loss Required',
        message:
            'Desk Risk Policy requires a valid Stop-Loss price (INR) on every trade before logging.',
      );
    }

    if (notionalInr > effectiveMaxPosition && effectiveMaxPosition > 0) {
      return CustomerLimitEvaluation(
        allowed: false,
        exceedsPositionCap: true,
        title:
            'Exceeds Max Position Cap (${formatInrAmount(effectiveMaxPosition)})',
        message:
            'Order notional ${formatInrAmount(notionalInr)} on ${symbol.toUpperCase()} exceeds the per-trader desk cap of ${formatInrAmount(effectiveMaxPosition)}${breakerState == 'tripped' ? ' (50% Circuit Breaker Caution cap)' : ''}.',
      );
    }

    if (risk.requiresManagerApproval &&
        notionalInr >= risk.requireManagerApprovalAboveAmount) {
      return CustomerLimitEvaluation(
        allowed: true,
        requiresManagerApproval: true,
        title: 'Pre-Trade Manager Approval Required',
        message:
            'Order notional ${formatInrAmount(notionalInr)} exceeds the ${formatInrAmount(risk.requireManagerApprovalAboveAmount)} desk approval threshold and will be queued in Admin Risk & Compliance.',
      );
    }

    return const CustomerLimitEvaluation(allowed: true);
  }

  static Future<bool> _refreshForAction(BuildContext context) async {
    if (CustomerDataPolicy.allowDemo && !SupabaseConfig.isConfigured) {
      return true;
    }
    try {
      await CustomerTierQuota.refreshPublishedCatalogue();
      return true;
    } catch (_) {
      if (context.mounted) {
        UiToast.error(
          context,
          title: 'Plan limits unavailable',
          message: 'Retry when the published catalogue is available.',
        );
      }
      return false;
    }
  }

  static Future<CustomerQuotaUsage?> _readUsageForAction(
    BuildContext context,
  ) async {
    try {
      return await CustomerQuotaUsage.fetch();
    } catch (_) {
      if (context.mounted) {
        UiToast.error(
          context,
          title: 'Account usage unavailable',
          message: 'Retry when your live quota can be checked.',
        );
      }
      return null;
    }
  }

  static List<({String label, bool included})> featuresForTier(
    CustomerTierQuota q,
  ) => switch (q.tier) {
    AppTier.free => <({String label, bool included})>[
      (
        label:
            '${q.maxTrades} logged trades · ${q.maxNotes} notes · ${q.maxLiveStrategies} live playbook',
        included: true,
      ),
      (label: '${q.maxAiQueriesPerMonth} AI Copilot queries/mo', included: true),
      (
        label:
            '${q.maxWatchlists} watchlist · ${q.maxAlerts} price alerts',
        included: true,
      ),
      (
        label:
            'Community feed (${q.maxCommunityPostsPerDay} posts & ${q.maxCommunityCommentsPerDay} replies/day)',
        included: true,
      ),
      (label: 'Core trading calculators', included: true),
      (
        label: 'Community market previews (movers, charts & wire)',
        included: true,
      ),
      (label: 'Full Market Intelligence & screeners', included: false),
      (label: 'End-to-end encrypted Private Messages', included: false),
      (label: 'Advanced options, forex & tax calculators', included: false),
      (label: 'PDF & CSV exports & advanced backtesting', included: false),
    ],
    AppTier.premium => <({String label, bool included})>[
      (
        label:
            '${q.maxTrades} logged trades · ${q.maxNotes} notes · ${q.maxLiveStrategies} live playbooks',
        included: true,
      ),
      (label: '${q.maxAiQueriesPerMonth} AI Copilot queries/mo', included: true),
      (
        label:
            '${q.maxWatchlists} watchlists · ${q.maxAlerts} price alerts',
        included: true,
      ),
      (
        label:
            'Community (${q.maxCommunityPostsPerDay} posts & ${q.maxCommunityCommentsPerDay} replies/day)',
        included: true,
      ),
      (label: 'Full Market Intelligence, charts & screeners', included: true),
      (label: 'End-to-end encrypted Private Messages', included: true),
      (label: 'All core & advanced trading calculators', included: true),
      (label: 'PDF & CSV exports', included: q.allowPdfExport),
      (label: 'Advanced backtesting & analytics', included: q.allowAdvancedBacktest),
    ],
    AppTier.enterprise => <({String label, bool included})>[
      (
        label:
            '${q.maxTrades} logged trades · ${q.maxNotes} notes · ${q.maxLiveStrategies} live playbooks',
        included: true,
      ),
      (label: '${q.maxAiQueriesPerMonth} AI Copilot queries/mo', included: true),
      (
        label:
            '${q.maxWatchlists} watchlists · ${q.maxAlerts} price alerts',
        included: true,
      ),
      (
        label:
            'Community (${q.maxCommunityPostsPerDay} posts & ${q.maxCommunityCommentsPerDay} replies/day)',
        included: true,
      ),
      (label: 'Full Market Intelligence, options & coverage', included: true),
      (label: 'End-to-end encrypted Private Messages', included: true),
      (label: 'All core & advanced trading calculators', included: true),
      (label: 'PDF & CSV journal & report exports', included: true),
      (label: 'Advanced backtesting & desk analytics', included: true),
    ],
  };

  /// Displays a sleek full-featured INR subscription comparison overlay showing
  /// only the currently available plans (Free, Basic, Pro) with grouped,
  /// icon-labeled entitlements and direct Razorpay checkout (Monthly & Annual).
  static Future<void> showPlanUpgradeDialog(
    BuildContext context, {
    required String featureTitle,
    required String reason,
  }) async {
    final AppSession session = AppSession.instance;
    final NavigatorState rootNavigator = Navigator.of(context);
    bool openChangePlanAfterClose = false;
    bool isAnnual = session.billingCycle == 'annual';
    AppTier? processingTier;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, StateSetter setDialogState) {
          final AppTier activeTier = session.tier.value;
          final bool activeIsAnnual = session.billingCycle == 'annual';
          final UiTheme theme = dialogCtx.ui;
          final bool compact = MediaQuery.sizeOf(dialogCtx).width < 820;

          final Color modalBg = theme.colors.surface;
          final Color cardBg = theme.colors.surfaceMuted.withValues(alpha: 0.38);
          final Color cardBorder = theme.colors.border;
          final Color dividerColor = theme.colors.border;

          String formatQuota(int value, String singular, String plural) {
            if (value >= 100000) return 'Unlimited $plural';
            return '$value ${value == 1 ? singular : plural}';
          }

          Future<void> handleSelectTier(AppTier tier) async {
            if (processingTier != null) return;
            final CustomerTierQuota q = CustomerTierQuota.forTier(tier);
            final String cycle = isAnnual ? 'annual' : 'monthly';

            // If user is not signed into Supabase (e.g. local/widget test mode),
            // fall back to opening ChangePlanPage.
            if (!SupabaseConfig.isConfigured ||
                SupabaseConfig.client?.auth.currentUser == null) {
              openChangePlanAfterClose = true;
              Navigator.of(ctx).pop();
              return;
            }

            if (tier == AppTier.free) {
              setDialogState(() => processingTier = tier);
              try {
                await BillingSettingsRepositoryImpl().cancelSubscription(
                  reason: 'Switched to Free from plan overlay',
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!context.mounted) return;
                UiToast.show(
                  context,
                  title: 'Renewal stopped',
                  message:
                      'Your paid features remain active until the end of your current billing period.',
                  intent: UiIntent.warning,
                );
              } catch (error) {
                if (dialogCtx.mounted) {
                  setDialogState(() => processingTier = null);
                }
                if (!context.mounted) return;
                UiToast.show(
                  context,
                  title: 'Could not switch to Free',
                  message: error.toString().replaceFirst('Bad state: ', ''),
                  intent: UiIntent.warning,
                );
              }
              return;
            }

            final String tierId = tier == AppTier.premium
                ? 'tier_pro'
                : 'tier_enterprise';
            final bool isNativeMobile =
                !kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS);
            setDialogState(() => processingTier = tier);
            try {
              if (isNativeMobile && !RevenueCatBilling.isConfigured) {
                final Uri webBillingUri = Uri.parse(
                  '${AppConstants.appSubdomainUrl}/settings_billing',
                ).replace(
                  queryParameters: <String, String>{
                    'plan': tierId,
                    'cycle': cycle,
                  },
                );
                bool opened = false;
                try {
                  opened = await launchUrl(
                    webBillingUri,
                    mode: LaunchMode.inAppBrowserView,
                  );
                } catch (_) {
                  opened = false;
                }
                if (!opened) {
                  opened = await launchUrl(
                    webBillingUri,
                    mode: LaunchMode.externalApplication,
                  );
                }
                if (!opened) {
                  throw StateError(
                    'Could not open ${AppConstants.appSubdomainUrl}.',
                  );
                }
                if (dialogCtx.mounted) {
                  setDialogState(() => processingTier = null);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!context.mounted) return;
                UiToast.show(
                  context,
                  title: 'Opened AlphaJournal Web',
                  message:
                      'Complete your upgrade on the website; your account updates automatically.',
                  intent: UiIntent.info,
                );
                return;
              }

              final billingRepo = BillingSettingsRepositoryImpl();
              final double listInr = isAnnual
                  ? (q.tier == AppTier.enterprise ? 4788.0 : 2868.0)
                  : (q.tier == AppTier.enterprise ? 499.0 : 299.0);
              final refChoice = await showReferralCodePromptDialog(
                dialogCtx,
                billingRepository: billingRepo,
                tierId: tierId,
                planName: q.planName,
                billingCycle: cycle,
                listAmountInr: listInr,
                currentTier: AppSession.instance.tier.value,
              );
              if (refChoice == null) {
                if (dialogCtx.mounted) {
                  setDialogState(() => processingTier = null);
                }
                return;
              }
              final checkoutSession = await billingRepo.startCheckout(
                tierId,
                cycle,
                referralCode: refChoice.referralCode,
              );
              final String keyId =
                  (checkoutSession.keyId != null &&
                      checkoutSession.keyId!.isNotEmpty)
                  ? checkoutSession.keyId!
                  : EnvConfig.razorpayKeyId;

              if (RazorpayWebCheckout.isSupported && keyId.isNotEmpty) {
                String toHex(Color c) {
                  final int r = (c.r * 255).round().clamp(0, 255);
                  final int g = (c.g * 255).round().clamp(0, 255);
                  final int b = (c.b * 255).round().clamp(0, 255);
                  return '#${r.toRadixString(16).padLeft(2, '0')}'
                      '${g.toRadixString(16).padLeft(2, '0')}'
                      '${b.toRadixString(16).padLeft(2, '0')}';
                }

                final bool isDark = theme.brightness == Brightness.dark;
                final modalResult = await RazorpayWebCheckout.open(
                  keyId: keyId,
                  subscriptionId: checkoutSession.sessionId,
                  planName: q.planName,
                  billingCycle: cycle,
                  userEmail: SupabaseConfig.client?.auth.currentUser?.email,
                  isDark: isDark,
                  themeColor: toHex(
                    isDark ? theme.colors.surface : theme.colors.primary,
                  ),
                  backdropColor: toHex(theme.colors.background),
                  surfaceColor: toHex(theme.colors.surface),
                  foregroundColor: toHex(theme.colors.foreground),
                  borderColor: toHex(theme.colors.borderStrong),
                  imageUrl:
                      '${AppConstants.appSubdomainUrl}/icons/Icon-192.png',
                );
                if (dialogCtx.mounted) {
                  setDialogState(() => processingTier = null);
                }
                if (modalResult.isSuccess) {
                  final verified = await billingRepo.verifyCheckout(
                    subscriptionId:
                        modalResult.subscriptionId ?? checkoutSession.sessionId,
                    paymentId: modalResult.paymentId,
                    signature: modalResult.signature,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  UiToast.show(
                    context,
                    title: verified ? 'Subscription Active' : 'Payment Received',
                    message: verified
                        ? 'You are now on ${q.planName} (${isAnnual ? 'Annual' : 'Monthly'}).'
                        : 'Your payment is being confirmed by Razorpay.',
                    intent: UiIntent.success,
                  );
                  return;
                }
                if (modalResult.isFailed) {
                  if (!context.mounted) return;
                  UiToast.show(
                    context,
                    title: 'Payment failed',
                    message:
                        modalResult.errorMessage ??
                        'Payment could not be completed. Returned to AlphaJournal.',
                    intent: UiIntent.danger,
                  );
                  return;
                }
                if (modalResult.isCancelled) {
                  if (!context.mounted) return;
                  UiToast.show(
                    context,
                    title: 'Checkout cancelled',
                    message:
                        'Returned to AlphaJournal without charging your account.',
                    intent: UiIntent.info,
                  );
                  return;
                }
              }

              if (!await launchUrl(
                Uri.parse(checkoutSession.url),
                mode: LaunchMode.externalApplication,
              )) {
                throw StateError('Could not open Razorpay checkout.');
              }
              if (dialogCtx.mounted) {
                setDialogState(() => processingTier = null);
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (!context.mounted) return;
              UiToast.show(
                context,
                title: 'Checkout opened',
                message:
                    'Your plan updates as soon as Razorpay confirms payment.',
                intent: UiIntent.info,
              );
            } catch (error) {
              if (dialogCtx.mounted) {
                setDialogState(() => processingTier = null);
              }
              if (!context.mounted) return;
              UiToast.show(
                context,
                title: 'Checkout unavailable',
                message: error.toString().replaceFirst('Bad state: ', ''),
                intent: UiIntent.warning,
              );
            }
          }

          List<({String heading, List<({IconData icon, String label})> items})>
          sectionsForTier(CustomerTierQuota q) {
            return switch (q.tier) {
              AppTier.free => [
                (
                  heading: 'Workspace & Journaling',
                  items: [
                    (
                      icon: Icons.edit_note_rounded,
                      label: formatQuota(q.maxNotes, 'note', 'notes'),
                    ),
                    (
                      icon: Icons.candlestick_chart_rounded,
                      label: formatQuota(q.maxTrades, 'trade log', 'trade logs'),
                    ),
                    (
                      icon: Icons.track_changes_rounded,
                      label: formatQuota(
                        q.maxLiveStrategies,
                        'live strategy',
                        'live strategies',
                      ),
                    ),
                    (
                      icon: Icons.bookmark_border_rounded,
                      label: formatQuota(
                        q.maxWatchlists,
                        'watchlist',
                        'watchlists',
                      ),
                    ),
                    (
                      icon: Icons.notifications_none_rounded,
                      label: formatQuota(
                        q.maxAlerts,
                        'price alert',
                        'price alerts',
                      ),
                    ),
                  ],
                ),
                (
                  heading: 'Community & Markets',
                  items: [
                    (
                      icon: Icons.forum_outlined,
                      label:
                          '${q.maxCommunityPostsPerDay} posts & ${q.maxCommunityCommentsPerDay} replies / day',
                    ),
                    (
                      icon: Icons.show_chart_rounded,
                      label: 'Market previews & basic calculators',
                    ),
                  ],
                ),
              ],
              AppTier.premium => [
                (
                  heading: 'Markets & Desk',
                  items: [
                    (
                      icon: Icons.candlestick_chart_rounded,
                      label:
                          '${formatQuota(q.maxNotes, 'note', 'notes')} & ${formatQuota(q.maxTrades, 'trade', 'trades')}',
                    ),
                    (
                      icon: Icons.track_changes_rounded,
                      label:
                          '${formatQuota(q.maxLiveStrategies, 'strategy', 'strategies')} & ${formatQuota(q.maxWatchlists, 'watchlist', 'watchlists')}',
                    ),
                    (
                      icon: Icons.insights_rounded,
                      label: 'Full Market Intelligence & screeners',
                    ),
                    (
                      icon: Icons.calculate_outlined,
                      label: 'Advanced risk & position calculators',
                    ),
                    (
                      icon: Icons.mail_outline_rounded,
                      label: 'Direct messages & trader network',
                    ),
                  ],
                ),
                (
                  heading: 'AI & Alerts',
                  items: [
                    (
                      icon: Icons.auto_awesome_rounded,
                      label: '${q.maxAiQueriesPerMonth} AI Copilot queries / mo',
                    ),
                    (
                      icon: Icons.notifications_active_outlined,
                      label: formatQuota(
                        q.maxAlerts,
                        'active alert',
                        'active alerts',
                      ),
                    ),
                    (
                      icon: Icons.forum_outlined,
                      label:
                          '${q.maxCommunityPostsPerDay} posts & ${q.maxCommunityCommentsPerDay} replies / day',
                    ),
                  ],
                ),
              ],
              AppTier.enterprise => [
                (
                  heading: 'Institutional Desk',
                  items: [
                    (
                      icon: Icons.layers_outlined,
                      label:
                          '${formatQuota(q.maxNotes, 'note', 'notes')} & ${formatQuota(q.maxTrades, 'trade', 'trades')}',
                    ),
                    (
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'CSV & PDF performance exports',
                    ),
                    (
                      icon: Icons.science_outlined,
                      label: 'Advanced strategy backtesting',
                    ),
                    (
                      icon: Icons.query_stats_rounded,
                      label: 'Deep expectancy & drawdown analytics',
                    ),
                  ],
                ),
                (
                  heading: 'AI & Priority',
                  items: [
                    (
                      icon: Icons.bolt_rounded,
                      label: '${q.maxAiQueriesPerMonth} AI Copilot queries / mo',
                    ),
                    (
                      icon: Icons.notifications_active_rounded,
                      label: formatQuota(
                        q.maxAlerts,
                        'active alert',
                        'active alerts',
                      ),
                    ),
                    (
                      icon: Icons.verified_outlined,
                      label:
                          '${q.maxCommunityPostsPerDay} posts & ${q.maxCommunityCommentsPerDay} replies / day',
                    ),
                  ],
                ),
              ],
            };
          }

          Widget buildCycleTogglePill({
            required String label,
            String? badge,
            required bool selected,
            required VoidCallback onTap,
          }) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: selected ? theme.colors.surface : Colors.transparent,
                  borderRadius: dialogCtx.radius(theme.radii.pill),
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: dialogCtx.uiText.bodyStrong.copyWith(
                        fontSize: 12.5,
                        color: selected
                            ? theme.colors.foreground
                            : theme.colors.foregroundMuted,
                      ),
                    ),
                    if (badge != null) ...<Widget>[
                      const SizedBox(width: 6),
                      UiBadge(
                        label: badge,
                        intent: UiIntent.success,
                        variant: UiBadgeVariant.soft,
                        size: UiSize.xs,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          Widget buildTierCard(AppTier tier) {
            final CustomerTierQuota q = CustomerTierQuota.forTier(tier);
            final bool isSameTier = tier == activeTier;
            final bool isCycleSwitch =
                isSameTier &&
                tier != AppTier.free &&
                activeIsAnnual != isAnnual;
            final bool selected = isSameTier && !isCycleSwitch;
            final bool highlighted = tier == AppTier.premium;
            final bool isProcessing = processingTier == tier;
            final sections = sectionsForTier(q);

            final int displayMonthlyInr = isAnnual
                ? q.annualMonthlyPriceInr
                : q.monthlyPriceInr;
            final String billingCaption = q.monthlyPriceInr == 0
                ? 'Free forever · No credit card required'
                : (isAnnual
                      ? '${formatInrAmount(q.annualTotalPriceInr)} billed annually · Save 20%'
                      : 'Billed monthly · Cancel anytime');

            final String introLine = switch (tier) {
              AppTier.free => 'Our introductory plan:',
              AppTier.premium => 'Everything in Free, and:',
              AppTier.enterprise => 'Everything in Basic, and:',
            };

            final String ctaLabel = isProcessing
                ? 'Starting checkout…'
                : selected
                ? 'Current plan'
                : isCycleSwitch
                ? 'Switch to ${isAnnual ? 'Annual' : 'Monthly'}'
                : (tier == AppTier.free
                      ? 'Switch to Free'
                      : 'Get ${q.planName}');

            final String? badgeText = isSameTier
                ? 'Current plan'
                : (highlighted
                      ? 'Most popular'
                      : (tier == AppTier.enterprise ? 'Full desk' : null));

            final UiIntent badgeIntent = isSameTier
                ? UiIntent.success
                : (highlighted ? UiIntent.primary : UiIntent.neutral);

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSameTier || highlighted
                    ? theme.colors.surfaceMuted.withValues(alpha: 0.55)
                    : cardBg,
                borderRadius: dialogCtx.radius(theme.radii.lg),
                border: Border.all(
                  color: isSameTier
                      ? theme.colors.success.withValues(alpha: 0.5)
                      : (highlighted
                            ? theme.colors.primary.withValues(alpha: 0.45)
                            : cardBorder),
                  width:
                      isSameTier || highlighted ? 1.25 : theme.borders.hairline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        q.planName,
                        style: dialogCtx.uiText.heading.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colors.foreground,
                        ),
                      ),
                      const Spacer(),
                      if (badgeText != null)
                        UiBadge(
                          label: badgeText,
                          intent: badgeIntent,
                          variant: UiBadgeVariant.soft,
                          size: UiSize.xs,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        displayMonthlyInr == 0
                            ? '₹0'
                            : formatInrAmount(displayMonthlyInr),
                        style: dialogCtx.uiText.display.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          color: theme.colors.foreground,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/month',
                        style: dialogCtx.uiText.caption.copyWith(
                          fontSize: 12,
                          color: theme.colors.foregroundSubtle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    billingCaption,
                    style: dialogCtx.uiText.caption.copyWith(
                      fontSize: 11.5,
                      color: isAnnual && q.monthlyPriceInr > 0
                          ? theme.colors.bullish
                          : theme.colors.foregroundSubtle,
                      fontWeight: isAnnual && q.monthlyPriceInr > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _OverlayPlanCtaButton(
                    label: ctaLabel,
                    selected: selected,
                    highlighted: highlighted,
                    loading: isProcessing,
                    onTap: selected || processingTier != null
                        ? null
                        : () => handleSelectTier(tier),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    introLine,
                    style: dialogCtx.uiText.caption.copyWith(
                      fontSize: 12,
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (int s = 0; s < sections.length; s++) ...<Widget>[
                    if (s > 0) const SizedBox(height: 14),
                    Text(
                      sections[s].heading,
                      style: dialogCtx.uiText.caption.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colors.foregroundSubtle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Divider(height: 1, thickness: 1, color: dividerColor),
                    const SizedBox(height: 10),
                    for (final item in sections[s].items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(
                                item.icon,
                                size: 15,
                                color: theme.colors.foregroundMuted,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                item.label,
                                style: dialogCtx.uiText.caption.copyWith(
                                  fontSize: 12.5,
                                  color: theme.colors.foreground,
                                  height: 1.32,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 24,
              vertical: compact ? 16 : 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1000,
                maxHeight: MediaQuery.sizeOf(dialogCtx).height * 0.92,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: modalBg,
                  borderRadius: dialogCtx.radius(theme.radii.xl),
                  border: Border.all(color: theme.colors.border),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: theme.colors.overlay.withValues(alpha: 0.4),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Top header row
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 16 : 24,
                        compact ? 14 : 18,
                        compact ? 12 : 16,
                        compact ? 10 : 14,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colors.surfaceMuted,
                                  borderRadius: dialogCtx.radius(
                                    theme.radii.pill,
                                  ),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 14,
                                      color: theme.colors.foreground,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'AlphaJournal',
                                      style: dialogCtx.uiText.caption.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colors.foreground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                tooltip: 'Close',
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: theme.colors.foregroundMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'One subscription. Access to everything.',
                            textAlign: TextAlign.center,
                            style: dialogCtx.uiText.display.copyWith(
                              fontSize: compact ? 20 : 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: theme.colors.foreground,
                            ),
                          ),
                          if (featureTitle.isNotEmpty ||
                              reason.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              reason.isNotEmpty ? reason : featureTitle,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: dialogCtx.uiText.caption.copyWith(
                                fontSize: 12.5,
                                color: theme.colors.foregroundMuted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // Monthly / Billed annually pill switcher
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colors.surfaceMuted.withValues(
                                alpha: 0.65,
                              ),
                              borderRadius: dialogCtx.radius(theme.radii.pill),
                              border: Border.all(
                                color: cardBorder,
                                width: theme.borders.hairline,
                              ),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                buildCycleTogglePill(
                                  label: 'Monthly',
                                  selected: !isAnnual,
                                  onTap: () =>
                                      setDialogState(() => isAnnual = false),
                                ),
                                buildCycleTogglePill(
                                  label: 'Billed annually',
                                  badge: 'Save 20%',
                                  selected: isAnnual,
                                  onTap: () =>
                                      setDialogState(() => isAnnual = true),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable cards body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 14 : 24,
                          4,
                          compact ? 14 : 24,
                          16,
                        ),
                        child: compact
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  for (
                                    int i = 0;
                                    i < AppTier.values.length;
                                    i++
                                  ) ...<Widget>[
                                    if (i > 0) const SizedBox(height: 12),
                                    buildTierCard(AppTier.values[i]),
                                  ],
                                ],
                              )
                            : IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    for (
                                      int i = 0;
                                      i < AppTier.values.length;
                                      i++
                                    ) ...<Widget>[
                                      if (i > 0) const SizedBox(width: 14),
                                      Expanded(
                                        child: buildTierCard(AppTier.values[i]),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                    ),

                    // Subtle footer note
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 16 : 24,
                        0,
                        compact ? 16 : 24,
                        14,
                      ),
                      child: Text(
                        'Prices shown in INR inclusive of 18% GST. Cancel or change your plan anytime from Settings → Billing.',
                        textAlign: TextAlign.center,
                        style: dialogCtx.uiText.caption.copyWith(
                          fontSize: 11,
                          color: theme.colors.foregroundSubtle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (openChangePlanAfterClose && context.mounted) {
      await rootNavigator.push(
        MaterialPageRoute<void>(builder: (_) => const ChangePlanPage()),
      );
    }
  }
}

class _OverlayPlanCtaButton extends StatefulWidget {
  const _OverlayPlanCtaButton({
    required this.label,
    required this.selected,
    required this.highlighted,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback? onTap;
  final bool loading;

  @override
  State<_OverlayPlanCtaButton> createState() => _OverlayPlanCtaButtonState();
}

class _OverlayPlanCtaButtonState extends State<_OverlayPlanCtaButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool enabled = widget.onTap != null && !widget.selected;

    // Highlighted (white button in dark mode) keeps a bright white/off-white
    // background on hover so dark text (onPrimary) never turns black-on-black.
    final Color bgColor = widget.selected
        ? theme.colors.surfaceMuted
        : widget.highlighted
        ? (_hovered && enabled
              ? Color.lerp(
                  theme.colors.primary,
                  const Color(0xFFD6DCE8),
                  0.22,
                )!
              : theme.colors.primary)
        : (_hovered && enabled
              ? theme.colors.surfaceHover
              : theme.colors.surface);

    final Color textColor = widget.selected
        ? theme.colors.foregroundSubtle
        : (widget.highlighted
              ? theme.colors.onPrimary
              : theme.colors.foreground);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: context.radius(theme.radii.pill),
            border: widget.selected || widget.highlighted
                ? null
                : Border.all(
                    color: _hovered && enabled
                        ? theme.colors.foregroundMuted
                        : theme.colors.borderStrong,
                  ),
          ),
          child: Text(
            widget.label,
            style: context.uiText.body.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact, responsive banner shown on the Customer Writing Desk (`WorkspaceScreen`)
/// surfacing active INR subscription quotas and live Institutional Desk Risk rules.
class CustomerLimitationsBanner extends StatefulWidget {
  const CustomerLimitationsBanner({
    super.key,
    required this.noteCount,
    required this.tradeCount,
    required this.liveStrategyCount,
    this.watchlistCount = 0,
    this.alertCount = 0,
    this.communityPostsToday = 0,
    this.communityCommentsToday = 0,
    this.showFeatureCards = false,
  });

  final int noteCount;
  final int tradeCount;
  final int liveStrategyCount;
  final int watchlistCount;
  final int alertCount;
  final int communityPostsToday;
  final int communityCommentsToday;
  final bool showFeatureCards;

  @override
  State<CustomerLimitationsBanner> createState() =>
      _CustomerLimitationsBannerState();
}

class _CustomerLimitationsBannerState extends State<CustomerLimitationsBanner> {
  String _breakerState = 'armed';
  String? _killswitchReason;
  DeskRiskModel _riskConfig = DeskRiskModel.defaultConfig();
  CustomerQuotaUsage? _accountUsage;
  bool _usageLoading = false;
  bool _usageFailed = false;

  @override
  void initState() {
    super.initState();
    _loadDeskState();
    _loadAccountUsage();
  }

  @override
  void didUpdateWidget(covariant CustomerLimitationsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteCount != widget.noteCount ||
        oldWidget.tradeCount != widget.tradeCount ||
        oldWidget.liveStrategyCount != widget.liveStrategyCount ||
        oldWidget.communityPostsToday != widget.communityPostsToday ||
        oldWidget.communityCommentsToday != widget.communityCommentsToday) {
      _loadAccountUsage();
    }
  }

  Future<void> _loadAccountUsage() async {
    if (!SupabaseConfig.isConfigured) return;
    setState(() {
      _usageLoading = true;
      _usageFailed = false;
    });
    try {
      await CustomerTierQuota.refreshPublishedCatalogue();
      final usage = await CustomerQuotaUsage.fetch();
      if (!mounted) return;
      setState(() {
        _accountUsage = usage;
        _usageLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _accountUsage = null;
        _usageLoading = false;
        _usageFailed = true;
      });
    }
  }

  Future<void> _loadDeskState() async {
    final String state = await AdminConsoleRepository.instance
        .getCircuitBreakerState();
    final DeskRiskModel risk = await AdminConsoleRepository.instance
        .getDeskRiskConfig();
    if (!mounted) return;
    setState(() {
      _breakerState = state;
      _killswitchReason = AdminConsoleRepository.instance.killswitchReason;
      _riskConfig = risk;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppSession session = AppSession.instance;
    final UiTheme theme = context.ui;

    return ValueListenableBuilder<AppTier>(
      valueListenable: session.tier,
      builder: (BuildContext context, AppTier tier, Widget? _) {
        return ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            session.aiQueriesUsed,
            session.aiQueriesLimit,
          ]),
          builder: (BuildContext context, Widget? _) {
            final int aiUsed = session.aiQueriesUsed.value;
            final CustomerTierQuota quota = CustomerTierQuota.forTier(tier);
            final int aiLimit =
                _accountUsage?.aiQueriesLimit ??
                session.aiQueriesLimit.value ??
                quota.maxAiQueriesPerMonth;
            final int? notesUsed = SupabaseConfig.isConfigured
                ? _accountUsage?.notesUsed
                : widget.noteCount;
            final int? tradesUsed = SupabaseConfig.isConfigured
                ? _accountUsage?.tradesUsed
                : widget.tradeCount;
            final int? playbooksUsed = SupabaseConfig.isConfigured
                ? _accountUsage?.livePlaybooksUsed
                : widget.liveStrategyCount;
            final int? aiUsedForAccount =
                SupabaseConfig.isConfigured && _accountUsage == null
                ? null
                : aiUsed;
            final int watchlistsUsed =
                _accountUsage?.watchlistsUsed ?? widget.watchlistCount;
            final int watchlistsLimit =
                _accountUsage?.watchlistsLimit ?? quota.maxWatchlists;
            final int alertsUsed =
                _accountUsage?.alertsUsed ?? widget.alertCount;
            final int alertsLimit =
                _accountUsage?.alertsLimit ?? quota.maxAlerts;
            final int postsToday =
                _accountUsage?.communityPostsToday ??
                widget.communityPostsToday;
            final int postsLimit =
                _accountUsage?.communityPostsPerDayLimit ??
                quota.maxCommunityPostsPerDay;
            final int commentsToday =
                _accountUsage?.communityCommentsToday ??
                widget.communityCommentsToday;
            final int commentsLimit =
                _accountUsage?.communityCommentsPerDayLimit ??
                quota.maxCommunityCommentsPerDay;
            final bool pdfUnlocked =
                _accountUsage?.allowPdfExport ?? quota.allowPdfExport;
            final bool backtestUnlocked =
                _accountUsage?.allowAdvancedBacktest ??
                quota.allowAdvancedBacktest;
            final bool isHalted = _breakerState == 'halted';
            final bool isTripped = _breakerState == 'tripped';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_usageLoading || _usageFailed) ...<Widget>[
                  UiCallout(
                    intent: _usageFailed ? UiIntent.warning : UiIntent.info,
                    title: _usageFailed
                        ? 'Account usage unavailable'
                        : 'Loading account usage',
                    description: _usageFailed
                        ? 'Your live limits could not be verified. Creation actions remain blocked until they can be checked.'
                        : 'Reading your usage and plan from the server.',
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                ],
                if (isHalted || isTripped) ...<Widget>[
                  UiCallout(
                    intent: isHalted ? UiIntent.danger : UiIntent.warning,
                    title: isHalted
                        ? 'Institutional Desk Killswitch Active — New Orders Halted'
                        : 'Desk Circuit Breaker Caution — 50% Position Cap Active',
                    description: isHalted
                        ? (_killswitchReason ??
                              'All non-owner trader seats are frozen by the Risk Officer. Review open exposure in Admin Risk & Compliance.')
                        : 'Desk drawdown approached firm warning threshold. Max single-order cap reduced to ${formatInrAmount(_riskConfig.maxPositionPerTrader * 0.5)}.',
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                ],
                UiDataPanel(
                  label: 'Customer Plan & Workspace Allowances',
                  leadingIcon: Icons.account_balance_wallet_outlined,
                  trailing: Wrap(
                    spacing: context.sp(theme.spacing.xs),
                    runSpacing: context.sp(theme.spacing.xxs),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      UiBadge(
                        label: '${quota.planName} Tier · ${quota.priceLabel}',
                        icon: Icons.workspace_premium_outlined,
                        intent: tier == AppTier.free
                            ? UiIntent.neutral
                            : UiIntent.primary,
                        variant: UiBadgeVariant.ghost,
                        size: UiSize.sm,
                      ),
                      if (tier != AppTier.enterprise)
                        UiButton(
                          label: tier == AppTier.free
                              ? 'Upgrade Plan'
                              : 'Manage Tier',
                          size: UiSize.xs,
                          variant: UiVariant.soft,
                          intent: UiIntent.primary,
                          leadingIcon: Icons.bolt_rounded,
                          onPressed: () =>
                              CustomerLimitations.showPlanUpgradeDialog(
                                context,
                                featureTitle: 'Customer Plan & Limits (INR)',
                                reason:
                                    'Manage your AlphaJournal subscription tier and workspace quotas in Indian Rupees (₹). Switch between monthly and annual billing anytime.',
                              ),
                        ),
                    ],
                  ),
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      UiStatStrip(
                        stats: <UiStat>[
                          UiStat(
                            icon: Icons.note_alt_outlined,
                            label: 'Research Notes',
                            value:
                                '${notesUsed ?? 0} / ${_accountUsage?.notesLimit ?? quota.maxNotes}',
                            hint:
                                (notesUsed != null &&
                                    notesUsed >=
                                        (_accountUsage?.notesLimit ??
                                            quota.maxNotes))
                                ? 'Limit reached · upgrade tier'
                                : '${((_accountUsage?.notesLimit ?? quota.maxNotes) - (notesUsed ?? 0)).clamp(0, 99999)} notes available',
                            intent:
                                (notesUsed != null &&
                                    notesUsed >=
                                        (_accountUsage?.notesLimit ??
                                            quota.maxNotes))
                                ? UiIntent.danger
                                : UiIntent.primary,
                          ),
                          UiStat(
                            icon: Icons.candlestick_chart_outlined,
                            label: 'Journal Trades',
                            value:
                                '${tradesUsed ?? 0} / ${_accountUsage?.tradesLimit ?? quota.maxTrades}',
                            hint:
                                (tradesUsed != null &&
                                    tradesUsed >=
                                        (_accountUsage?.tradesLimit ??
                                            quota.maxTrades))
                                ? 'Monthly cap reached'
                                : '${((_accountUsage?.tradesLimit ?? quota.maxTrades) - (tradesUsed ?? 0)).clamp(0, 99999)} entries remaining',
                            intent:
                                (tradesUsed != null &&
                                    tradesUsed >=
                                        (_accountUsage?.tradesLimit ??
                                            quota.maxTrades))
                                ? UiIntent.danger
                                : UiIntent.info,
                          ),
                          UiStat(
                            icon: Icons.psychology_outlined,
                            label: 'Live Playbooks',
                            value:
                                '${playbooksUsed ?? 0} / ${_accountUsage?.livePlaybooksLimit ?? quota.maxLiveStrategies}',
                            hint:
                                (playbooksUsed != null &&
                                    playbooksUsed >=
                                        (_accountUsage?.livePlaybooksLimit ??
                                            quota.maxLiveStrategies))
                                ? 'Strategy limit reached'
                                : '${((_accountUsage?.livePlaybooksLimit ?? quota.maxLiveStrategies) - (playbooksUsed ?? 0)).clamp(0, 99999)} active rules left',
                            intent:
                                (playbooksUsed != null &&
                                    playbooksUsed >=
                                        (_accountUsage?.livePlaybooksLimit ??
                                            quota.maxLiveStrategies))
                                ? UiIntent.warning
                                : UiIntent.success,
                          ),
                          UiStat(
                            icon: Icons.auto_awesome_outlined,
                            label: 'AI Copilot Queries',
                            value: '${aiUsedForAccount ?? 0} / $aiLimit',
                            hint:
                                (aiUsedForAccount != null &&
                                    aiUsedForAccount >= aiLimit)
                                ? 'Monthly credits exhausted'
                                : '${(aiLimit - (aiUsedForAccount ?? 0)).clamp(0, 99999)} prompt credits',
                            intent:
                                (aiUsedForAccount != null &&
                                    aiUsedForAccount >= aiLimit)
                                ? UiIntent.danger
                                : UiIntent.bullish,
                          ),
                          UiStat(
                            icon: Icons.bookmark_border_rounded,
                            label: 'Watchlists',
                            value: '$watchlistsUsed / $watchlistsLimit',
                            hint: watchlistsUsed >= watchlistsLimit
                                ? 'Watchlist limit reached'
                                : '${(watchlistsLimit - watchlistsUsed).clamp(0, 99999)} watchlists remaining',
                            intent: watchlistsUsed >= watchlistsLimit
                                ? UiIntent.warning
                                : UiIntent.info,
                          ),
                          UiStat(
                            icon: Icons.notifications_active_outlined,
                            label: 'Price Alerts',
                            value: '$alertsUsed / $alertsLimit',
                            hint: alertsUsed >= alertsLimit
                                ? 'Alert limit reached'
                                : '${(alertsLimit - alertsUsed).clamp(0, 99999)} alerts remaining',
                            intent: alertsUsed >= alertsLimit
                                ? UiIntent.warning
                                : UiIntent.primary,
                          ),
                          UiStat(
                            icon: Icons.forum_outlined,
                            label: 'Community Posts / Day',
                            value: '$postsToday / $postsLimit',
                            hint: postsToday >= postsLimit
                                ? () {
                                    final DateTime nowUtc = DateTime.now()
                                        .toUtc();
                                    final DateTime nextReset = DateTime.utc(
                                      nowUtc.year,
                                      nowUtc.month,
                                      nowUtc.day + 1,
                                    );
                                    final Duration rem = nextReset.difference(
                                      nowUtc,
                                    );
                                    return 'Cap reached · resets in ${rem.inHours}h ${rem.inMinutes.remainder(60)}m (UTC)';
                                  }()
                                : '${(postsLimit - postsToday).clamp(0, 99999)} posts left today',
                            intent: postsToday >= postsLimit
                                ? UiIntent.warning
                                : UiIntent.bullish,
                          ),
                          UiStat(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Comments / Day',
                            value: '$commentsToday / $commentsLimit',
                            hint: commentsToday >= commentsLimit
                                ? () {
                                    final DateTime nowUtc = DateTime.now()
                                        .toUtc();
                                    final DateTime nextReset = DateTime.utc(
                                      nowUtc.year,
                                      nowUtc.month,
                                      nowUtc.day + 1,
                                    );
                                    final Duration rem = nextReset.difference(
                                      nowUtc,
                                    );
                                    return 'Cap reached · resets in ${rem.inHours}h ${rem.inMinutes.remainder(60)}m (UTC)';
                                  }()
                                : '${(commentsLimit - commentsToday).clamp(0, 99999)} replies left today',
                            intent: commentsToday >= commentsLimit
                                ? UiIntent.warning
                                : UiIntent.neutral,
                          ),
                        ],
                        columns: context.uiRes.isMobile ? 2 : 4,
                        density: UiDensity.comfortable,
                      ),
                    ],
                  ),
                ),
                if (widget.showFeatureCards) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.md)),
                  Builder(
                    builder: (BuildContext ctx) {
                      final bool stacked = ctx.uiRes.isMobile;
                      final List<
                        ({IconData icon, String title, String desc})
                      >
                      includedItems = [
                        (
                          icon: Icons.edit_note_rounded,
                          title: 'Writing Desk & Journal',
                          desc:
                              '${_accountUsage?.notesLimit ?? quota.maxNotes} notes · ${_accountUsage?.tradesLimit ?? quota.maxTrades} trades · ${_accountUsage?.livePlaybooksLimit ?? quota.maxLiveStrategies} live strategy',
                        ),
                        (
                          icon: Icons.forum_outlined,
                          title: 'Community Feed & Posts',
                          desc:
                              '$postsLimit posts & $commentsLimit replies per day',
                        ),
                        (
                          icon: Icons.bookmark_border_rounded,
                          title: 'Watchlists & Alerts',
                          desc:
                              '$watchlistsLimit ${watchlistsLimit == 1 ? 'watchlist' : 'watchlists'} · $alertsLimit price alerts',
                        ),
                        (
                          icon: Icons.auto_awesome_rounded,
                          title: 'AI Copilot Workspace',
                          desc: '$aiLimit AI queries / month',
                        ),
                        (
                          icon: Icons.show_chart_rounded,
                          title: tier == AppTier.free
                              ? 'Market Previews & Calculators'
                              : 'Full Market Intelligence',
                          desc: tier == AppTier.free
                              ? 'Live previews & core sizing calculators'
                              : 'Screeners, watchlists & advanced calculators',
                        ),
                        if (tier != AppTier.free)
                          (
                            icon: Icons.mail_outline_rounded,
                            title: 'Private Messages (E2EE)',
                            desc: 'Encrypted direct trader conversations',
                          ),
                        if (pdfUnlocked)
                          (
                            icon: Icons.picture_as_pdf_outlined,
                            title: 'PDF & CSV Exports',
                            desc: 'Export full reports & trade logs',
                          ),
                        if (backtestUnlocked)
                          (
                            icon: Icons.science_outlined,
                            title: 'Advanced Backtesting',
                            desc: 'Multi-session playbook simulations',
                          ),
                      ];

                      final List<
                        ({
                          IconData icon,
                          String title,
                          String desc,
                          String badge,
                        })
                      >
                      upgradeItems = [
                        if (tier == AppTier.free) ...[
                          (
                            icon: Icons.insights_rounded,
                            title: 'Full Market Intelligence',
                            desc:
                                'Deep screeners, sector flow & full watchlists',
                            badge: 'Basic+',
                          ),
                          (
                            icon: Icons.mail_outline_rounded,
                            title: 'Private Messages (E2EE)',
                            desc: 'Encrypted 1-on-1 trader messaging',
                            badge: 'Basic+',
                          ),
                          (
                            icon: Icons.calculate_outlined,
                            title: 'Advanced Calculators',
                            desc:
                                'Expectancy, Kelly & multi-leg risk tools',
                            badge: 'Basic+',
                          ),
                        ],
                        if (!pdfUnlocked)
                          (
                            icon: Icons.picture_as_pdf_outlined,
                            title: 'PDF & CSV Exports',
                            desc:
                                'Download tax-ready & audit-ready exports',
                            badge: 'Pro',
                          ),
                        if (!backtestUnlocked)
                          (
                            icon: Icons.science_outlined,
                            title: 'Advanced Backtesting',
                            desc:
                                'Deep historical expectancy & drawdown stats',
                            badge: 'Pro',
                          ),
                      ];

                      Widget buildListCard({
                        required String heading,
                        required Widget child,
                        Widget? trailing,
                      }) {
                        return Container(
                          padding: EdgeInsets.all(
                            ctx.sp(theme.spacing.sm) + 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colors.surfaceMuted.withValues(
                              alpha: 0.32,
                            ),
                            borderRadius: ctx.radius(theme.radii.md),
                            border: Border.all(
                              color: theme.colors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      heading,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: ctx.uiText.caption.copyWith(
                                        fontSize: ctx.fs(10.5),
                                        letterSpacing: 0.7,
                                        fontWeight: FontWeight.w700,
                                        color: theme.colors.foregroundSubtle,
                                      ),
                                    ),
                                  ),
                                  if (trailing != null) ...<Widget>[
                                    const SizedBox(width: 8),
                                    trailing,
                                  ],
                                ],
                              ),
                              SizedBox(height: ctx.sp(theme.spacing.xs)),
                              const UiDivider(spacing: 0),
                              SizedBox(height: ctx.sp(theme.spacing.xs)),
                              child,
                            ],
                          ),
                        );
                      }

                      final Widget includedCard = buildListCard(
                        heading:
                            'INCLUDED IN ${quota.planName.toUpperCase()}',
                        trailing: UiBadge(
                          label: '${includedItems.length} active',
                          intent: UiIntent.success,
                          variant: UiBadgeVariant.soft,
                          size: UiSize.xs,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (int i = 0; i < includedItems.length; i++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: i == includedItems.length - 1
                                      ? 0
                                      : 9,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Container(
                                      width: 26,
                                      height: 26,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: theme.colors.success
                                            .withValues(alpha: 0.12),
                                        borderRadius: ctx.radius(
                                          theme.radii.sm,
                                        ),
                                      ),
                                      child: Icon(
                                        includedItems[i].icon,
                                        size: 14,
                                        color: theme.colors.success,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            includedItems[i].title,
                                            style: ctx.uiText.caption
                                                .copyWith(
                                                  fontSize: 12.5,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: theme
                                                      .colors
                                                      .foreground,
                                                ),
                                          ),
                                          Text(
                                            includedItems[i].desc,
                                            style: ctx.uiText.caption
                                                .copyWith(
                                                  fontSize: 11,
                                                  color: theme
                                                      .colors
                                                      .foregroundMuted,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );

                      if (upgradeItems.isEmpty) {
                        return includedCard;
                      }

                      final Widget upgradeCard = buildListCard(
                        heading: 'UNLOCK WITH UPGRADE',
                        trailing: InkWell(
                          borderRadius: ctx.radius(theme.radii.sm),
                          onTap: () =>
                              CustomerLimitations.showPlanUpgradeDialog(
                                ctx,
                                featureTitle: 'Upgrade Plan',
                                reason:
                                    'Compare Free, Basic, and Pro features.',
                              ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              'View plans →',
                              style: ctx.uiText.caption.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colors.primary,
                              ),
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (int i = 0; i < upgradeItems.length; i++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: i == upgradeItems.length - 1
                                      ? 0
                                      : 9,
                                ),
                                child: InkWell(
                                  borderRadius: ctx.radius(
                                    theme.radii.sm,
                                  ),
                                  onTap: () =>
                                      CustomerLimitations.showPlanUpgradeDialog(
                                        ctx,
                                        featureTitle:
                                            upgradeItems[i].title,
                                        reason: upgradeItems[i].desc,
                                      ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: theme.colors.surface,
                                          borderRadius: ctx.radius(
                                            theme.radii.sm,
                                          ),
                                          border: Border.all(
                                            color: theme.colors.border,
                                          ),
                                        ),
                                        child: Icon(
                                          upgradeItems[i].icon,
                                          size: 14,
                                          color: theme
                                              .colors
                                              .foregroundMuted,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              upgradeItems[i].title,
                                              style: ctx.uiText.caption
                                                  .copyWith(
                                                    fontSize: 12.5,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: theme
                                                        .colors
                                                        .foreground,
                                                  ),
                                            ),
                                            Text(
                                              upgradeItems[i].desc,
                                              style: ctx.uiText.caption
                                                  .copyWith(
                                                    fontSize: 11,
                                                    color: theme
                                                        .colors
                                                        .foregroundMuted,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      UiBadge(
                                        label: upgradeItems[i].badge,
                                        icon: Icons.lock_outline_rounded,
                                        intent:
                                            upgradeItems[i].badge == 'Pro'
                                            ? UiIntent.primary
                                            : UiIntent.neutral,
                                        variant: UiBadgeVariant.soft,
                                        size: UiSize.xs,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );

                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            includedCard,
                            SizedBox(height: ctx.sp(theme.spacing.sm)),
                            upgradeCard,
                          ],
                        );
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(child: includedCard),
                            SizedBox(width: ctx.sp(theme.spacing.sm)),
                            Expanded(child: upgradeCard),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// Live INR pre-trade risk & notional compliance bar for `JournalEditorScreen`.
class CustomerTradeRiskBanner extends StatefulWidget {
  const CustomerTradeRiskBanner({
    super.key,
    required this.symbol,
    required this.entryPrice,
    required this.quantity,
    required this.stopLoss,
  });

  final String symbol;
  final double? entryPrice;
  final double? quantity;
  final double? stopLoss;

  @override
  State<CustomerTradeRiskBanner> createState() =>
      _CustomerTradeRiskBannerState();
}

class _CustomerTradeRiskBannerState extends State<CustomerTradeRiskBanner> {
  DeskRiskModel _risk = DeskRiskModel.defaultConfig();
  String _breakerState = 'armed';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final DeskRiskModel r = await AdminConsoleRepository.instance
        .getDeskRiskConfig();
    final String state = await AdminConsoleRepository.instance
        .getCircuitBreakerState();
    if (!mounted) return;
    setState(() {
      _risk = r;
      _breakerState = state;
    });
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double entry = widget.entryPrice ?? 0;
    final double qty = widget.quantity ?? 0;
    final double notional = (entry > 0 && qty > 0) ? entry * qty : 0;
    final double maxCap = _breakerState == 'tripped'
        ? _risk.maxPositionPerTrader * 0.5
        : _risk.maxPositionPerTrader;
    final bool exceedsCap = notional > maxCap && maxCap > 0;
    final bool needsApproval =
        !exceedsCap &&
        _risk.requiresManagerApproval &&
        notional >= _risk.requireManagerApprovalAboveAmount;
    final bool missingStop =
        _risk.requireStopLoss &&
        (widget.stopLoss == null || widget.stopLoss! <= 0);

    return UiCard(
      variant: UiCardVariant.outlined,
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Wrap(
        spacing: context.sp(theme.spacing.sm),
        runSpacing: context.sp(theme.spacing.xs),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          UiBadge(
            label: 'Order Notional: ${formatInrAmount(notional)}',
            intent: exceedsCap
                ? UiIntent.danger
                : (needsApproval ? UiIntent.warning : UiIntent.primary),
            size: UiSize.xs,
          ),
          UiBadge(
            label: 'Desk Cap: ${formatInrAmount(maxCap)}',
            intent: exceedsCap ? UiIntent.danger : UiIntent.neutral,
            variant: UiBadgeVariant.soft,
            size: UiSize.xs,
          ),
          if (exceedsCap)
            const UiBadge(
              label: 'BREACH: Exceeds Trader Position Cap',
              intent: UiIntent.danger,
              size: UiSize.xs,
            )
          else if (needsApproval)
            UiBadge(
              label:
                  'Routes to Admin Approval (> ${formatInrAmount(_risk.requireManagerApprovalAboveAmount)})',
              intent: UiIntent.warning,
              size: UiSize.xs,
            ),
          if (missingStop)
            const UiBadge(
              label: 'Stop-Loss Required by Desk Policy',
              intent: UiIntent.warning,
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
            ),
        ],
      ),
    );
  }
}
