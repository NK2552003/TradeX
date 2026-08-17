import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/data/repositories/desk_risk_repository.dart';
import 'package:tradex/features/settings/models/desk_risk_model.dart';

class DeskRiskPage extends StatefulWidget {
  const DeskRiskPage({
    super.key,
    this.repository,
  });

  final DeskRiskRepository? repository;

  @override
  State<DeskRiskPage> createState() => _DeskRiskPageState();
}

class _DeskRiskPageState extends State<DeskRiskPage> {
  late final DeskRiskRepository _repo;
  DeskRiskModel? _config;
  bool _loading = true;
  bool _saving = false;

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
          message: 'Desk-wide risk management policies and limits have been updated.',
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
            description: 'Automated circuit breakers that halt trading or restrict leverage.',
            children: [
              UiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Firm-Wide Max Daily Drawdown', style: context.uiText.bodyStrong),
                        UiBadge(
                          label: '${c.maxFirmDrawdownPercent.toStringAsFixed(1)}% Max Daily Loss',
                          intent: UiIntent.danger,
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    Text(
                      'If cumulative portfolio losses exceed this threshold intraday, all open orders will be frozen.',
                      style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    UiSlider(
                      value: c.maxFirmDrawdownPercent,
                      min: 1.0,
                      max: 15.0,
                      onChanged: (val) {
                        setState(() {
                          _config = c.copyWith(maxFirmDrawdownPercent: val);
                        });
                      },
                    ),
                    SizedBox(height: context.sp(theme.spacing.md)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Max Capital Allocation per Individual Trader', style: context.uiText.bodyStrong),
                        UiBadge(
                          label: c.maxPositionPerTrader >= 10000000
                              ? '₹${(c.maxPositionPerTrader / 10000000).toStringAsFixed(1)} Cr Limit'
                              : '₹${(c.maxPositionPerTrader / 100000).toInt()} Lakh Limit',
                          intent: UiIntent.primary,
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    UiSlider(
                      value: c.maxPositionPerTrader,
                      min: 1000000.0,
                      max: 50000000.0,
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
            description: 'Enforce discipline and risk officer reviews on large order sizes.',
            children: [
              AppSettingCard(
                title: 'Enforce Pre-Trade Checklist for All Desk Traders',
                description: 'Traders must complete risk checks before submitting orders to connected brokers.',
                icon: Icons.checklist_rtl_rounded,
                control: UiSwitch(
                  value: c.enforcePreTradeChecklistAllTraders,
                  onChanged: (val) {
                    setState(() {
                      _config = c.copyWith(enforcePreTradeChecklistAllTraders: val);
                    });
                  },
                ),
              ),
              AppSettingCard(
                title: 'Require Risk Manager Approval Above ₹10 Lakh',
                description: 'Orders larger than ₹10,00,000 notional require one-click approval from desk admin.',
                icon: Icons.verified_user_outlined,
                control: UiSwitch(
                  value: c.requireManagerApprovalAboveAmount > 0,
                  onChanged: (val) {
                    setState(() {
                      _config = c.copyWith(
                        requireManagerApprovalAboveAmount: val ? 1000000.0 : 0.0,
                      );
                    });
                  },
                ),
              ),
              AppSettingCard(
                title: 'Immutable Compliance & Audit Logging',
                description: 'Log all trader actions, order cancellations, and parameter edits with tamper-evident hashes.',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              UiButton(
                label: 'Save Risk Policies',
                intent: UiIntent.primary,
                variant: UiVariant.primary,
                loading: _saving,
                onPressed: _saveConfig,
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
  }
}
