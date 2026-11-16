import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/settings/data/repositories/desk_risk_repository.dart';
import 'package:tradex/features/settings/models/desk_risk_model.dart';

class DeskRiskPage extends StatefulWidget {
  const DeskRiskPage({super.key, this.repository});

  final DeskRiskRepository? repository;

  @override
  State<DeskRiskPage> createState() => _DeskRiskPageState();
}

class _DeskRiskPageState extends State<DeskRiskPage> {
  late final DeskRiskRepository _repo;
  DeskRiskModel? _config;
  bool _loading = true;
  bool _saving = false;

  late double _sampleOrderNotional = DeskRiskModel.positionPerTraderMin;
  bool _sampleChecklistDone = true;

  /// The threshold held on to while the approval gate is switched off. Without it
  /// the figure would be lost the moment the switch went off, and turning it back
  /// on would silently pick a number the desk never chose.
  double _lastApprovalThreshold =
      DeskRiskModel.defaultConfig().requireManagerApprovalAboveAmount;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DeskRiskRepositoryImpl();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final c = await _repo.getDeskRiskConfig();
      if (mounted) {
        setState(() {
          _config = c;
          if (c.requiresManagerApproval) {
            _lastApprovalThreshold = c.requireManagerApprovalAboveAmount;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (_config == null) return;
    setState(() => _saving = true);
    try {
      final updated = await _repo.updateDeskRiskConfig(_config!);
      if (mounted) {
        setState(() {
          _config = updated;
          _saving = false;
        });
        UiToast.show(
          context,
          title: 'Risk Policies Synced',
          message:
              'Desk-wide risk management policies and limits have been updated.',
          intent: UiIntent.success,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        UiToast.show(
          context,
          title: 'Risk policies could not be saved',
          intent: UiIntent.danger,
        );
      }
    }
  }

  (String title, String message, UiIntent intent) _simulateOrder(
    DeskRiskModel c,
  ) {
    if (_sampleOrderNotional > c.maxPositionPerTrader) {
      return (
        'Order Blocked by Capital Limit',
        'Sample order (${AppTokens.lakhCrore(_sampleOrderNotional)}) exceeds max allocation per trader (${AppTokens.lakhCrore(c.maxPositionPerTrader)}).',
        UiIntent.danger,
      );
    }
    if (c.enforcePreTradeChecklistAllTraders && !_sampleChecklistDone) {
      return (
        'Held for Pre-Trade Checklist',
        'Traders must complete the mandatory desk risk checklist before broker routing.',
        UiIntent.warning,
      );
    }
    if (c.requiresManagerApproval &&
        _sampleOrderNotional > c.requireManagerApprovalAboveAmount) {
      return (
        'Routed for Manager Approval',
        'Order (${AppTokens.lakhCrore(_sampleOrderNotional)}) exceeds the ${AppTokens.lakhCrore(c.requireManagerApprovalAboveAmount)} threshold.',
        UiIntent.warning,
      );
    }
    return (
      'Auto-Execute Eligible',
      'Sample order (${AppTokens.lakhCrore(_sampleOrderNotional)}) clears all active desk risk gates${c.auditLoggingEnabled ? ' with audit logging' : ''}.',
      UiIntent.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final isMobile = context.uiRes.isMobile;

    if (_loading) {
      return UiSkeleton.settingsDetail(sections: 2, rowsPerSection: 4);
    }

    if (_config == null) {
      return UiEmptyState(
        title: 'Risk settings unavailable',
        message: 'Your policy could not be loaded. Try again.',
        action: UiButton(label: 'Try again', onPressed: _loadConfig),
      );
    }

    final c = _config!;
    final verdict = _simulateOrder(c);
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : context.uiDockInset)
        : context.sp(theme.spacing.lg);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        bottomInset,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live Risk Posture Strip
              UiCard(
                variant: UiCardVariant.surface,
                accentColor: colors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Firm Risk & Compliance Controls',
                              style: context.uiText.title,
                            ),
                            const UiGap.v(2),
                            Text(
                              'Settings configured here apply globally to all traders, portfolio managers, and sub-accounts on your desk.',
                              style: context.uiText.caption,
                            ),
                          ],
                        ),
                        UiButton(
                          label: 'Refresh',
                          leadingIcon: Icons.refresh,
                          size: UiSize.sm,
                          variant: UiVariant.outline,
                          onPressed: _loadConfig,
                        ),
                      ],
                    ),
                    const UiGap.v(14),
                    UiStatStrip(
                      minCellWidth: 150,
                      stats: [
                        UiStat(
                          label: 'Max daily drawdown',
                          value: AppTokens.percent(c.maxFirmDrawdownPercent),
                          intent: UiIntent.danger,
                          icon: Icons.trending_down_rounded,
                        ),
                        UiStat(
                          label: 'Trader capital cap',
                          value: AppTokens.lakhCrore(c.maxPositionPerTrader),
                          intent: UiIntent.primary,
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                        UiStat(
                          label: 'Approval gate',
                          value: c.requiresManagerApproval
                              ? AppTokens.lakhCrore(
                                  c.requireManagerApprovalAboveAmount,
                                )
                              : 'Disabled',
                          intent: c.requiresManagerApproval
                              ? UiIntent.warning
                              : UiIntent.neutral,
                          icon: Icons.verified_user_outlined,
                        ),
                        UiStat(
                          label: 'Audit trail',
                          value: c.auditLoggingEnabled
                              ? 'Immutable'
                              : 'Paused',
                          intent: c.auditLoggingEnabled
                              ? UiIntent.success
                              : UiIntent.danger,
                          icon: Icons.history_edu_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Interactive Order Gate Live Simulator
              AppSettingsSectionBlock(
                title: 'Live Execution Gate Preview',
                description:
                    'Simulate a sample order notional to preview how your active risk policy routes it in real time.',
                children: [
                  UiCard(
                    variant: UiCardVariant.surface,
                    accentColor: switch (verdict.$3) {
                      UiIntent.danger => colors.danger,
                      UiIntent.warning => colors.warning,
                      _ => colors.success,
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RiskLimitHeading(
                          label: 'Simulated Order Size',
                          badge: UiBadge(
                            label: AppTokens.lakhCrore(_sampleOrderNotional),
                            intent: UiIntent.primary,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        UiSlider(
                          value: _sampleOrderNotional.clamp(
                            DeskRiskModel.positionPerTraderMin,
                            DeskRiskModel.positionPerTraderMax,
                          ),
                          min: DeskRiskModel.positionPerTraderMin,
                          max: DeskRiskModel.positionPerTraderMax,
                          valueFormatter: AppTokens.lakhCrore,
                          onChanged: (val) =>
                              setState(() => _sampleOrderNotional = val),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        UiSwitch(
                          label: 'Sample trader checklist completed',
                          value: _sampleChecklistDone,
                          onChanged: (val) =>
                              setState(() => _sampleChecklistDone = val),
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        UiCallout(
                          title: verdict.$1,
                          message: verdict.$2,
                          intent: verdict.$3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Drawdown Limits
              AppSettingsSectionBlock(
                title: 'Drawdown & Position Size Ceilings',
                description:
                    'Automated circuit breakers that halt trading or restrict leverage.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RiskLimitHeading(
                          label: 'Firm-Wide Max Daily Drawdown',
                          badge: UiBadge(
                            label:
                                '${AppTokens.percent(c.maxFirmDrawdownPercent)} Max Daily Loss',
                            intent: UiIntent.danger,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.xs)),
                        Text(
                          'If cumulative portfolio losses exceed this threshold intraday, all open orders will be frozen.',
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundMuted,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        UiSlider(
                          value: c.maxFirmDrawdownPercent,
                          min: DeskRiskModel.firmDrawdownMinPercent,
                          max: DeskRiskModel.firmDrawdownMaxPercent,
                          valueFormatter: AppTokens.percent,
                          onChanged: (val) {
                            setState(() {
                              _config = c.copyWith(maxFirmDrawdownPercent: val);
                            });
                          },
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        _RiskLimitHeading(
                          label: 'Max Capital Allocation per Individual Trader',
                          badge: UiBadge(
                            label:
                                '${AppTokens.lakhCrore(c.maxPositionPerTrader)} Limit',
                            intent: UiIntent.primary,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        UiSlider(
                          value: c.maxPositionPerTrader,
                          min: DeskRiskModel.positionPerTraderMin,
                          max: DeskRiskModel.positionPerTraderMax,
                          valueFormatter: AppTokens.lakhCrore,
                          onChanged: (val) {
                            setState(() {
                              _config = c.copyWith(maxPositionPerTrader: val);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Mandatory Checklist and Manager Approvals
              AppSettingsSectionBlock(
                title: 'Execution Gates & Workflow Approvals',
                description:
                    'Enforce discipline and risk officer reviews on large order sizes.',
                children: [
                  AppSettingCard(
                    title: 'Enforce Pre-Trade Checklist for All Desk Traders',
                    description:
                        'Traders must complete risk checks before submitting orders to connected brokers.',
                    icon: Icons.checklist_rtl_rounded,
                    control: UiSwitch(
                      value: c.enforcePreTradeChecklistAllTraders,
                      onChanged: (val) {
                        setState(() {
                          _config = c.copyWith(
                            enforcePreTradeChecklistAllTraders: val,
                          );
                        });
                      },
                    ),
                  ),
                  AppSettingCard(
                    title: c.requiresManagerApproval
                        ? 'Require Risk Manager Approval Above '
                              '${AppTokens.lakhCrore(c.requireManagerApprovalAboveAmount)}'
                        : 'Require Risk Manager Approval On Large Orders',
                    description: c.requiresManagerApproval
                        ? 'Orders above '
                              '${AppTokens.price(c.requireManagerApprovalAboveAmount)} '
                              'notional need one-click approval from a desk admin '
                              'before they reach the broker.'
                        : 'Traders can route any order size to the broker without '
                              'a desk admin reviewing it first.',
                    icon: Icons.verified_user_outlined,
                    control: UiSwitch(
                      value: c.requiresManagerApproval,
                      onChanged: (val) {
                        setState(() {
                          _config = c.copyWith(
                            requireManagerApprovalAboveAmount: val
                                ? _lastApprovalThreshold
                                : 0,
                          );
                        });
                      },
                    ),
                  ),
                  if (c.requiresManagerApproval)
                    UiCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RiskLimitHeading(
                            label: 'Approval Threshold',
                            badge: UiBadge(
                              label:
                                  'Above ${AppTokens.lakhCrore(c.requireManagerApprovalAboveAmount)}',
                              intent: UiIntent.warning,
                            ),
                          ),
                          SizedBox(height: context.sp(theme.spacing.xs)),
                          Text(
                            'Anything at or below this notional executes straight '
                            'away. Raise it to keep the desk moving, lower it to '
                            'review more of the flow.',
                            style: context.uiText.caption.copyWith(
                              color: colors.foregroundMuted,
                            ),
                          ),
                          SizedBox(height: context.sp(theme.spacing.sm)),
                          UiSlider(
                            value: c.requireManagerApprovalAboveAmount.clamp(
                              DeskRiskModel.approvalThresholdMin,
                              DeskRiskModel.approvalThresholdMax,
                            ),
                            min: DeskRiskModel.approvalThresholdMin,
                            max: DeskRiskModel.approvalThresholdMax,
                            valueFormatter: AppTokens.lakhCrore,
                            onChanged: (val) {
                              setState(() {
                                _lastApprovalThreshold = val;
                                _config = c.copyWith(
                                  requireManagerApprovalAboveAmount: val,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  AppSettingCard(
                    title: 'Immutable Compliance & Audit Logging',
                    description:
                        'Log all trader actions, order cancellations, and parameter edits with tamper-evident hashes.',
                    icon: Icons.history_edu_rounded,
                    control: UiSwitch(
                      value: c.auditLoggingEnabled,
                      onChanged: (val) {
                        setState(() {
                          _config = c.copyWith(auditLoggingEnabled: val);
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xl)),

              // Save button
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: isMobile ? double.infinity : null,
                  child: UiButton(
                    label: 'Save Risk Policies',
                    intent: UiIntent.primary,
                    variant: UiVariant.primary,
                    loading: _saving,
                    onPressed: _saveConfig,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskLimitHeading extends StatelessWidget {
  const _RiskLimitHeading({required this.label, required this.badge});

  final String label;
  final Widget badge;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: context.sp(context.ui.spacing.sm),
    runSpacing: context.sp(context.ui.spacing.sm),
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(label, style: context.uiText.bodyStrong),
      badge,
    ],
  );
}
