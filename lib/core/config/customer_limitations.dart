import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
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

  String get priceLabel =>
      monthlyPriceInr == 0 ? '₹0 / mo' : '${formatInrAmount(monthlyPriceInr)} / mo';

  static CustomerTierQuota forTier(AppTier tier) => switch (tier) {
    AppTier.free => const CustomerTierQuota(
      tier: AppTier.free,
      planName: 'TradeX Basic',
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
      planName: 'TradeX Pro',
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
      planName: 'TradeX Enterprise',
      monthlyPriceInr: 7999,
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
    final CustomerTierQuota quota = currentQuota;
    if (currentNoteCount < quota.maxNotes) return true;
    await showPlanUpgradeDialog(
      context,
      featureTitle: 'Note Limit Reached (${quota.maxNotes} Notes)',
      reason:
          'Your ${quota.planName} (${quota.priceLabel}) plan includes up to ${quota.maxNotes} research notes. Upgrade to TradeX Pro (₹2,499/mo) for 500 notes and PDF exports.',
    );
    return false;
  }

  /// Checks whether the customer can log another trade under their active plan
  /// and whether the Institutional Desk Circuit Breaker allows execution.
  static Future<bool> checkCanCreateTrade(
    BuildContext context, {
    required int currentTradeCount,
  }) async {
    final String breakerState =
        await AdminConsoleRepository.instance.getCircuitBreakerState();
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

    final CustomerTierQuota quota = currentQuota;
    if (currentTradeCount < quota.maxTrades) return true;
    await showPlanUpgradeDialog(
      context,
      featureTitle: 'Journal Quota Reached (${quota.maxTrades} Trades)',
      reason:
          'Your ${quota.planName} (${quota.priceLabel}) plan supports up to ${quota.maxTrades} logged trades. Upgrade to TradeX Pro (₹2,499/mo) for 5,000 trades and full analytics.',
    );
    return false;
  }

  /// Checks whether the customer can create or activate another strategy playbook.
  static Future<bool> checkCanCreateStrategy(
    BuildContext context, {
    required int currentLiveStrategyCount,
  }) async {
    final CustomerTierQuota quota = currentQuota;
    if (currentLiveStrategyCount < quota.maxLiveStrategies) return true;
    await showPlanUpgradeDialog(
      context,
      featureTitle:
          'Active Playbook Limit Reached (${quota.maxLiveStrategies} Live)',
      reason:
          'Your ${quota.planName} (${quota.priceLabel}) plan allows up to ${quota.maxLiveStrategies} live playbooks. Upgrade to TradeX Pro (₹2,499/mo) for 25 live playbooks.',
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
    final String breakerState =
        await AdminConsoleRepository.instance.getCircuitBreakerState();
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

    final DeskRiskModel risk =
        await AdminConsoleRepository.instance.getDeskRiskConfig();
    final double notionalInr =
        (entryPrice.isFinite && quantity.isFinite && entryPrice > 0 && quantity > 0)
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
        title: 'Exceeds Max Position Cap (${formatInrAmount(effectiveMaxPosition)})',
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
                      final CustomerTierQuota q = CustomerTierQuota.forTier(tier);
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
                          onTap: () {
                            session.changeTier(tier);
                            setModalState(() {});
                            Navigator.of(ctx).pop();
                            UiToast.success(
                              context,
                              title: 'Plan Updated to ${q.planName}',
                              message:
                                  'Active tier: ${q.planName} (${q.priceLabel}). Limits updated immediately.',
                            );
                          },
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
                                        SizedBox(width: ctx.sp(theme.spacing.xs)),
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
                                label: selected ? 'Current' : 'Select',
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

  @override
  void initState() {
    super.initState();
    _loadDeskState();
  }

  Future<void> _loadDeskState() async {
    final String state =
        await AdminConsoleRepository.instance.getCircuitBreakerState();
    final DeskRiskModel risk =
        await AdminConsoleRepository.instance.getDeskRiskConfig();
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
            final bool isHalted = _breakerState == 'halted';
            final bool isTripped = _breakerState == 'tripped';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
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
                            label: 'Notes ${widget.noteCount}/${quota.maxNotes}',
                            intent: widget.noteCount >= quota.maxNotes
                                ? UiIntent.danger
                                : UiIntent.info,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                          UiBadge(
                            label: 'Trades ${widget.tradeCount}/${quota.maxTrades}',
                            intent: widget.tradeCount >= quota.maxTrades
                                ? UiIntent.danger
                                : UiIntent.info,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                          UiBadge(
                            label:
                                'Live Playbooks ${widget.liveStrategyCount}/${quota.maxLiveStrategies}',
                            intent:
                                widget.liveStrategyCount >=
                                    quota.maxLiveStrategies
                                ? UiIntent.warning
                                : UiIntent.success,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                          UiBadge(
                            label:
                                'AI Copilot $aiUsed/${quota.maxAiQueriesPerMonth}',
                            intent: aiUsed >= quota.maxAiQueriesPerMonth
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
                                  : 'Enterprise (₹7,999)',
                              size: UiSize.xs,
                              variant: UiVariant.soft,
                              intent: UiIntent.primary,
                              onPressed: () =>
                                  CustomerLimitations.showPlanUpgradeDialog(
                                    context,
                                    featureTitle: 'Customer Plan & Limits (INR)',
                                    reason:
                                        'Manage your TradeX subscription tier and workspace quotas in Indian Rupees (₹).',
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
    final DeskRiskModel r =
        await AdminConsoleRepository.instance.getDeskRiskConfig();
    final String state =
        await AdminConsoleRepository.instance.getCircuitBreakerState();
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
