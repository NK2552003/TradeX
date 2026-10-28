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

  String get priceLabel => monthlyPriceInr == 0
      ? '₹0 / mo'
      : '${formatInrAmount(monthlyPriceInr)} / mo';

  static final Map<AppTier, CustomerTierQuota> _published = {};

  static bool get hasPublishedQuotas => _published.isNotEmpty;

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

      next[tier] = CustomerTierQuota(
        tier: tier,
        planName: plan['name']?.toString() ?? base.planName,
        monthlyPriceInr: (plan['monthly_amount'] as num).round(),
        maxNotes: requiredLimit('notes'),
        maxTrades: requiredLimit('trades'),
        maxLiveStrategies: requiredLimit('live_playbooks'),
        maxWatchlists: base.maxWatchlists,
        maxAiQueriesPerMonth: requiredLimit('ai_queries_per_month'),
        allowPdfExport: base.allowPdfExport,
        allowAdvancedBacktest: base.allowAdvancedBacktest,
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
      planName: 'alphajournal Basic',
      monthlyPriceInr: 0,
      maxNotes: 25,
      maxTrades: 100,
      maxLiveStrategies: 3,
      maxWatchlists: 1,
      maxAiQueriesPerMonth: 20,
      allowPdfExport: false,
      allowAdvancedBacktest: false,
    ),
    AppTier.premium => const CustomerTierQuota(
      tier: AppTier.premium,
      planName: 'alphajournal Pro',
      monthlyPriceInr: 2499,
      maxNotes: 500,
      maxTrades: 5000,
      maxLiveStrategies: 25,
      maxWatchlists: 20,
      maxAiQueriesPerMonth: 500,
      allowPdfExport: true,
      allowAdvancedBacktest: true,
    ),
    AppTier.enterprise => const CustomerTierQuota(
      tier: AppTier.enterprise,
      planName: 'alphajournal Business',
      monthlyPriceInr: 999,
      maxNotes: 10000,
      maxTrades: 50000,
      maxLiveStrategies: 250,
      maxWatchlists: 100,
      maxAiQueriesPerMonth: 5000,
      allowPdfExport: true,
      allowAdvancedBacktest: true,
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
  });

  final int noteCount;
  final int tradeCount;
  final int liveStrategyCount;

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
        return ValueListenableBuilder<int>(
          valueListenable: session.aiQueriesUsed,
          builder: (BuildContext context, int aiUsed, Widget? _) {
            final CustomerTierQuota quota = CustomerTierQuota.forTier(tier);
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
                UiCard(
                  variant: UiCardVariant.outlined,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.md),
                    vertical: context.sp(theme.spacing.sm),
                  ),
                  child: Wrap(
                    spacing: context.sp(theme.spacing.md),
                    runSpacing: context.sp(theme.spacing.xs),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: <Widget>[
                      Wrap(
                        spacing: context.sp(theme.spacing.xs),
                        runSpacing: context.sp(theme.spacing.xs),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          UiBadge(
                            label: '${quota.planName} (${quota.priceLabel})',
                            intent: tier == AppTier.free
                                ? UiIntent.neutral
                                : (tier == AppTier.premium
                                      ? UiIntent.primary
                                      : UiIntent.warning),
                            size: UiSize.xs,
                          ),
                          UiBadge(
                            label:
                                'Notes ${notesUsed ?? '—'}/${(_accountUsage?.notesLimit ?? quota.maxNotes)}',
                            intent:
                                notesUsed != null &&
                                    notesUsed >=
                                        (_accountUsage?.notesLimit ??
                                            quota.maxNotes)
                                ? UiIntent.danger
                                : UiIntent.info,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                          UiBadge(
                            label:
                                'Trades ${tradesUsed ?? '—'}/${(_accountUsage?.tradesLimit ?? quota.maxTrades)}',
                            intent:
                                tradesUsed != null &&
                                    tradesUsed >=
                                        (_accountUsage?.tradesLimit ??
                                            quota.maxTrades)
                                ? UiIntent.danger
                                : UiIntent.info,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                          UiBadge(
                            label:
                                'Live Playbooks ${playbooksUsed ?? '—'}/${(_accountUsage?.livePlaybooksLimit ?? quota.maxLiveStrategies)}',
                            intent:
                                playbooksUsed != null &&
                                    playbooksUsed >=
                                        (_accountUsage?.livePlaybooksLimit ??
                                            quota.maxLiveStrategies)
                                ? UiIntent.warning
                                : UiIntent.success,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                          UiBadge(
                            label:
                                'AI Copilot ${aiUsedForAccount ?? '—'}/${(_accountUsage?.aiQueriesLimit ?? quota.maxAiQueriesPerMonth)}',
                            intent:
                                aiUsedForAccount != null &&
                                    aiUsedForAccount >=
                                        (_accountUsage?.aiQueriesLimit ??
                                            quota.maxAiQueriesPerMonth)
                                ? UiIntent.danger
                                : UiIntent.primary,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: context.sp(theme.spacing.xs),
                        runSpacing: context.sp(theme.spacing.xs),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          UiBadge(
                            label:
                                'Max Position: ${formatInrAmount(_riskConfig.maxPositionPerTrader)} · Approval > ${formatInrAmount(_riskConfig.requireManagerApprovalAboveAmount)}',
                            intent: isHalted
                                ? UiIntent.danger
                                : (isTripped
                                      ? UiIntent.warning
                                      : UiIntent.neutral),
                            variant: UiBadgeVariant.outline,
                            size: UiSize.xs,
                          ),
                          if (tier != AppTier.enterprise)
                            UiButton(
                              label: tier == AppTier.free
                                  ? 'Upgrade Plan (₹2,499)'
                                  : 'Business (₹999)',
                              size: UiSize.xs,
                              variant: UiVariant.soft,
                              intent: UiIntent.primary,
                              onPressed: () =>
                                  CustomerLimitations.showPlanUpgradeDialog(
                                    context,
                                    featureTitle:
                                        'Customer Plan & Limits (INR)',
                                    reason:
                                        'Manage your alphajournal subscription tier and workspace quotas in Indian Rupees (₹).',
                                  ),
                            ),
                        ],
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
