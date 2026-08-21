import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
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
    } catch (e) {
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
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final isMobile = context.uiRes.isMobile;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Column(
          children: const [
            UiSkeleton(height: 140),
            SizedBox(height: 16),
            UiSkeleton(height: 200),
          ],
        ),
      );
    }

    final c = _config!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Desk Warning Banner
              UiCallout(
                title: 'Firm Risk & Compliance Controls',
                message:
                    'Settings configured here apply globally to all traders, portfolio managers, and sub-accounts on your institutional desk license.',
                intent: UiIntent.primary,
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
  Widget build(BuildContext context) {
    final spacing = context.sp(context.ui.spacing.sm);
    if (context.uiRes.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.uiText.bodyStrong),
          SizedBox(height: spacing),
          badge,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: Text(label, style: context.uiText.bodyStrong)),
        SizedBox(width: spacing),
        badge,
      ],
    );
  }
}
