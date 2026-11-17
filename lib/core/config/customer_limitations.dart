import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/config/customer_quota_usage.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:tradex/features/public_site/data/public_site_repository.dart';
import 'package:tradex/features/settings/models/desk_risk_model.dart';

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
    this.maxAlerts = 3,
    this.maxCommunityPostsPerDay = 2,
    this.maxCommunityCommentsPerDay = 10,
  });

  final AppTier tier;
  final String planName;
  final int monthlyPriceInr;
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
      planName: 'alphajournal Free',
      monthlyPriceInr: 0,
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
      planName: 'alphajournal Basic',
      monthlyPriceInr: 299,
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
      planName: 'alphajournal Pro',
      monthlyPriceInr: 499,
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
          '${quota.planName} does not include publication-grade PDF or CSV exports. Upgrade to alphajournal Pro (₹499/mo) to unlock unlimited exports.',
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
          '${quota.planName} includes core strategy tracking. Upgrade to alphajournal Pro (₹499/mo) for advanced backtesting and institutional analytics.',
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

  /// Displays an INR upgrade modal allowing the user to compare and switch plans.
  static Future<void> showPlanUpgradeDialog(
    BuildContext context, {
    required String featureTitle,
    required String reason,
  }) async {
    final AppSession session = AppSession.instance;
    await UiDialog.show<void>(
      context,
      maxWidth: 520,
      child: StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setModalState) {
          final AppTier activeTier = session.tier.value;
          final UiTheme theme = ctx.ui;
          return UiDialog(
            title: featureTitle,
            description: reason,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final AppTier tier in AppTier.values) ...<Widget>[
                  Builder(
                    builder: (BuildContext context) {
                      final CustomerTierQuota q = CustomerTierQuota.forTier(
                        tier,
                      );
                      final bool selected = tier == activeTier;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: ctx.sp(theme.spacing.xs),
                        ),
                        child: UiCard(
                          variant: selected
                              ? UiCardVariant.elevated
                              : UiCardVariant.outlined,
                          padding: EdgeInsets.all(ctx.sp(theme.spacing.sm)),
                          onTap: null,
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Text(
                                          q.planName,
                                          style: ctx.uiText.bodyStrong,
                                        ),
                                        SizedBox(
                                          width: ctx.sp(theme.spacing.xs),
                                        ),
                                        UiBadge(
                                          label: q.priceLabel,
                                          intent: tier == AppTier.free
                                              ? UiIntent.neutral
                                              : (tier == AppTier.premium
                                                    ? UiIntent.primary
                                                    : UiIntent.warning),
                                          size: UiSize.xs,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${q.maxTrades} trades · ${q.maxNotes} notes · ${q.maxLiveStrategies} live playbooks · ${q.maxAiQueriesPerMonth} AI queries/mo',
                                      style: ctx.uiText.caption.copyWith(
                                        color: theme.colors.foregroundMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              UiBadge(
                                label: selected ? 'Current' : 'Preview',
                                intent: selected
                                    ? UiIntent.success
                                    : UiIntent.primary,
                                variant: selected
                                    ? UiBadgeVariant.soft
                                    : UiBadgeVariant.solid,
                                size: UiSize.xs,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              UiButton(
                label: 'Close',
                variant: UiVariant.outline,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          );
        },
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
  });

  final int noteCount;
  final int tradeCount;
  final int liveStrategyCount;
  final int watchlistCount;
  final int alertCount;
  final int communityPostsToday;
  final int communityCommentsToday;

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
        oldWidget.liveStrategyCount != widget.liveStrategyCount) {
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
                  hint: '${quota.planName} Tier · ${quota.priceLabel}',
                  leadingIcon: Icons.account_balance_wallet_outlined,
                  trailing: tier != AppTier.enterprise
                      ? UiButton(
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
                                    'Manage your alphajournal subscription tier and workspace quotas in Indian Rupees (₹). Monthly subscriptions for Basic and Pro are disabled for now.',
                              ),
                        )
                      : null,
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
                                ? 'Daily post cap reached'
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
                                ? 'Daily comment cap reached'
                                : '${(commentsLimit - commentsToday).clamp(0, 99999)} replies left today',
                            intent: commentsToday >= commentsLimit
                                ? UiIntent.warning
                                : UiIntent.neutral,
                          ),
                        ],
                        columns: context.uiRes.isMobile ? 2 : 4,
                        density: UiDensity.comfortable,
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.sp(theme.spacing.md),
                          context.sp(theme.spacing.xs),
                          context.sp(theme.spacing.md),
                          context.sp(theme.spacing.sm),
                        ),
                        child: Wrap(
                          spacing: context.sp(theme.spacing.sm),
                          runSpacing: context.sp(theme.spacing.xs),
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            UiBadge(
                              label: pdfUnlocked
                                  ? 'PDF & CSV Exports: Enabled'
                                  : 'PDF & CSV Exports: Pro Plan',
                              icon: pdfUnlocked
                                  ? Icons.picture_as_pdf_outlined
                                  : Icons.lock_outline_rounded,
                              intent: pdfUnlocked
                                  ? UiIntent.success
                                  : UiIntent.neutral,
                              variant: UiBadgeVariant.soft,
                              size: UiSize.xs,
                            ),
                            UiBadge(
                              label: backtestUnlocked
                                  ? 'Advanced Backtest: Enabled'
                                  : 'Advanced Backtest: Pro Plan',
                              icon: backtestUnlocked
                                  ? Icons.insights_outlined
                                  : Icons.lock_outline_rounded,
                              intent: backtestUnlocked
                                  ? UiIntent.success
                                  : UiIntent.neutral,
                              variant: UiBadgeVariant.soft,
                              size: UiSize.xs,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
