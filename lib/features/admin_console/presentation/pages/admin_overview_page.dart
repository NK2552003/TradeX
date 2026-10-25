import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/admin_console/models/admin_console_models.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({
    super.key,
    this.onNavigate,
  });

  final ValueChanged<String>? onNavigate;

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  final AdminConsoleRepository _repo = AdminConsoleRepository.instance;

  bool _loading = true;
  AdminDeskAnalyticsSnapshot? _snapshot;
  List<AdminTraderSeat> _seats = const <AdminTraderSeat>[];
  List<AdminConsumerAccount> _consumers = const <AdminConsumerAccount>[];
  List<DeskOrderApproval> _orders = const <DeskOrderApproval>[];
  List<DeskRiskBreach> _breaches = const <DeskRiskBreach>[];
  List<AdminAuditLogEntry> _audits = const <AdminAuditLogEntry>[];
  List<AffiliateApplicationModel> _applications =
      const <AffiliateApplicationModel>[];
  AffiliateWorkspace? _affiliateWorkspace;
  List<AccountDeletionRequestModel> _deletions =
      const <AccountDeletionRequestModel>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _repo.getAnalyticsSnapshot('1M').catchError((e) {
          debugPrint('AdminOverviewPage getAnalyticsSnapshot fallback: $e');
          return _repo.fallbackSnapshot('1M');
        }),
        _repo.listTraderSeats().catchError((e) {
          debugPrint('AdminOverviewPage listTraderSeats error: $e');
          return <AdminTraderSeat>[];
        }),
        _repo.listOrderApprovals().catchError((e) {
          debugPrint('AdminOverviewPage listOrderApprovals error: $e');
          return <DeskOrderApproval>[];
        }),
        _repo.listRiskBreaches().catchError((e) {
          debugPrint('AdminOverviewPage listRiskBreaches error: $e');
          return <DeskRiskBreach>[];
        }),
        _repo.listAuditLogs().catchError((e) {
          debugPrint('AdminOverviewPage listAuditLogs error: $e');
          return <AdminAuditLogEntry>[];
        }),
        _repo.listAffiliateApplications().catchError((e) {
          debugPrint('AdminOverviewPage listAffiliateApplications error: $e');
          return <AffiliateApplicationModel>[];
        }),
        _repo.getAffiliateWorkspaceSnapshot().catchError((e) {
          debugPrint('AdminOverviewPage getAffiliateWorkspaceSnapshot error: $e');
          return AffiliateWorkspace.fromJson(const <String, Object?>{});
        }),
        _repo.listDeletionRequests().catchError((e) {
          debugPrint('AdminOverviewPage listDeletionRequests error: $e');
          return <AccountDeletionRequestModel>[];
        }),
        _repo.listConsumerAccounts().catchError((e) {
          debugPrint('AdminOverviewPage listConsumerAccounts error: $e');
          return <AdminConsumerAccount>[];
        }),
      ]);
      if (!mounted) return;
      setState(() {
        _snapshot = results[0] as AdminDeskAnalyticsSnapshot;
        _seats = results[1] as List<AdminTraderSeat>;
        _orders = results[2] as List<DeskOrderApproval>;
        _breaches = results[3] as List<DeskRiskBreach>;
        _audits = results[4] as List<AdminAuditLogEntry>;
        _applications = results[5] as List<AffiliateApplicationModel>;
        _affiliateWorkspace = results[6] as AffiliateWorkspace;
        _deletions = results[7] as List<AccountDeletionRequestModel>;
        _consumers = results[8] as List<AdminConsumerAccount>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleCircuitBreaker(String currentState) async {
    final bool isHalted = currentState == 'halted';
    final TextEditingController reasonCtrl = TextEditingController(
      text: isHalted
          ? 'All NSE/NFO margin checks verified. Resuming normal desk execution.'
          : 'Emergency volatility circuit breaker triggered by Desk Admin.',
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => UiDialog(
        title: isHalted
            ? 'Resume Institutional Desk Execution?'
            : 'Engage Emergency Desk Killswitch?',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            UiCallout(
              title: isHalted
                  ? 'Unfreezing all active trader seats'
                  : 'All non-owner seats will be frozen immediately',
              message: isHalted
                  ? 'Traders will regain order placement capabilities within their assigned INR capital and drawdown limits.'
                  : 'New pre-trade orders across NSE, BSE, NFO, and MCX will be blocked until the circuit breaker is reset.',
              intent: isHalted ? UiIntent.success : UiIntent.danger,
            ),
            SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
            UiField(
              label: 'Compliance Audit Reason',
              required: true,
              child: UiTextarea(
                controller: reasonCtrl,
                minLines: 2,
                maxLines: 4,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          UiButton(
            label: 'Cancel',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          UiButton(
            label: isHalted ? 'Resume Desk' : 'Engage Killswitch',
            intent: isHalted ? UiIntent.success : UiIntent.danger,
            variant: isHalted ? UiVariant.solid : UiVariant.destructive,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.setCircuitBreakerState(
        state: isHalted ? 'armed' : 'halted',
        reason: reasonCtrl.text,
      );
      reasonCtrl.dispose();
      await _load();
      if (mounted) {
        UiToast.show(
          context,
          title: isHalted
              ? 'Desk Execution Resumed'
              : 'Emergency Killswitch Engaged',
          message: isHalted
              ? 'Circuit breaker reset to ARMED. Audit hash recorded.'
              : 'All trader seats frozen and logged to SHA-256 compliance ledger.',
          intent: isHalted ? UiIntent.success : UiIntent.danger,
        );
      }
    } else {
      reasonCtrl.dispose();
    }
  }

  Future<void> _quickReviewOrder(DeskOrderApproval order, bool approve) async {
    await _repo.reviewOrderApproval(
      orderId: order.id,
      approve: approve,
      notes: approve
          ? 'Quick-approved from Desk Console.'
          : 'Rejected from Desk Console due to exposure concentration.',
    );
    await _load();
    if (mounted) {
      UiToast.show(
        context,
        title: approve ? 'Pre-Trade Order Approved' : 'Pre-Trade Order Rejected',
        message: '${order.side} ${order.quantity} ${order.symbol} (${formatInrCompact(order.notionalValueInr)}) updated.',
        intent: approve ? UiIntent.success : UiIntent.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    if (_loading || _snapshot == null) {
      return UiSkeleton.dashboard();
    }
    final AdminDeskAnalyticsSnapshot snap = _snapshot!;
    final bool isHalted = snap.activeCircuitBreakerState == 'halted';
    final List<DeskOrderApproval> pendingOrders = _orders
        .where((o) => o.status == 'pending')
        .toList();
    final List<DeskRiskBreach> openBreaches = _breaches
        .where((b) => b.status == 'open' || b.status == 'acknowledged')
        .toList();
    final int pendingAffiliates = _applications
        .where((a) => a.status == AffiliateApplicationStatus.pending)
        .length;
    final int pendingPayouts = (_affiliateWorkspace?.payouts ?? const <AffiliatePayout>[])
        .where((p) => p.status == 'pending' || p.status == 'processing')
        .length;
    final int pendingDeletions = _deletions
        .where((d) => d.status != 'data_purged' && d.status != 'cancelled')
        .length;

    return UiPage(
      maxWidth: 1440,
      header: UiHeader(
        title: 'Institutional Desk Console',
        subtitle:
            'Real-time INR capital allocation, pre-trade risk gates, affiliate governance, and DPDP data purge supervision.',
        leading: Icon(Icons.space_dashboard_outlined, color: theme.colors.primary),
        actions: <Widget>[
          UiButton(
            label: 'Refresh',
            leadingIcon: Icons.refresh_rounded,
            variant: UiVariant.outline,
            size: UiSize.sm,
            onPressed: _load,
          ),
          UiButton(
            label: isHalted ? 'Resume Desk Execution' : 'Emergency Killswitch',
            leadingIcon: isHalted
                ? Icons.play_circle_outline_rounded
                : Icons.gpp_maybe_outlined,
            intent: isHalted ? UiIntent.success : UiIntent.danger,
            variant: isHalted ? UiVariant.solid : UiVariant.destructive,
            size: UiSize.sm,
            onPressed: () =>
                _toggleCircuitBreaker(snap.activeCircuitBreakerState),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Circuit Breaker Banner
          UiCallout(
            title: isHalted
                ? 'CIRCUIT BREAKER HALTED — ALL NON-OWNER TRADER SEATS FROZEN'
                : 'DESK CIRCUIT BREAKER ARMED · NSE / BSE / NFO / MCX PRE-TRADE GATES ACTIVE',
            message: isHalted
                ? (snap.killswitchReason ??
                      'Desk execution halted by Risk Officer.')
                : 'Supervised Firm Capital: ${formatInrCompact(snap.supervisedCapitalInr)} · Deployed Across ${_seats.length} Seats: ${formatInrCompact(snap.allocatedCapitalInr)} · Max Firm Drawdown: ${snap.maxDrawdownPct.toStringAsFixed(2)}%',
            intent: isHalted ? UiIntent.danger : UiIntent.info,
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Top KPI Metric Grid (100% INR)
          UiCardGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 4,
            largeColumns: 4,
            children: <Widget>[
              UiMetricCard(
                label: 'Allocated Desk Capital',
                value: formatInrCompact(snap.allocatedCapitalInr),
                caption:
                    '${_consumers.length} registered consumer traders · ${formatInrCompact(snap.supervisedCapitalInr)} pool',
                delta: 8.4,
                icon: Icons.account_balance_outlined,
                sparkline: const <double>[15.0, 16.2, 16.8, 17.5, 18.0, 18.5],
              ),
              UiMetricCard(
                label: 'Intraday Desk Net P&L',
                value: formatInrCompact(snap.intradayPnlInr, signed: true),
                caption:
                    'MRR: ${formatInrAmount(snap.subscriptionMrrInr)}/mo (${_consumers.where((c) => c.subscriptionTier != "Basic").length} Paid Subscribers)',
                delta: 14.2,
                icon: Icons.trending_up_rounded,
                sparkline: const <double>[4.2, 6.8, 5.9, 9.4, 11.1, 12.65],
              ),
              UiMetricCard(
                label: 'Pre-Trade & Breach Queue',
                value:
                    '${pendingOrders.length} Orders · ${openBreaches.length} Alerts',
                caption: 'Click Risk & Compliance to action',
                icon: Icons.shield_outlined,
                intent: openBreaches.isNotEmpty
                    ? UiIntent.warning
                    : UiIntent.success,
              ),
              UiMetricCard(
                label: 'Partner & Deletion Queue',
                value:
                    '${pendingAffiliates + pendingPayouts} Partner · $pendingDeletions Purge',
                caption:
                    'Settled INR Payouts: ${formatInrCompact(snap.affiliatePayoutsSettledInr)}',
                icon: Icons.handshake_outlined,
                intent: UiIntent.primary,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Charts Row: Cumulative Desk P&L (INR) & Division Capital Allocation
          _buildChartsSection(context, snap),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Live Action Queues: Pre-Trade Approvals & Risk Breaches
          _buildLiveQueuesSection(context, pendingOrders, openBreaches),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Cross-Platform Linking Hub (Consumer, Affiliate INR, & Account Deletions) + Audit Stream
          _buildGovernanceAndAuditSection(
            context,
            pendingAffiliates: pendingAffiliates,
            pendingPayouts: pendingPayouts,
            pendingDeletions: pendingDeletions,
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(
    BuildContext context,
    AdminDeskAnalyticsSnapshot snap,
  ) {
    final UiTheme theme = context.ui;
    final Widget pnlChartCard = UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Cumulative Desk P&L vs Benchmark (INR ₹)',
                      style: context.uiText.subheading,
                    ),
                    Text(
                      'Net institutional desk return compared against NIFTY 50 equivalent exposure',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              UiButton(
                label: 'Full Analytics',
                variant: UiVariant.ghost,
                size: UiSize.sm,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => widget.onNavigate?.call('org_analytics'),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiAreaChart(
            height: 230,
            valueFormatter: (num v) => formatInrCompact(v),
            data: snap.points
                .map(
                  (p) => UiChartPoint(
                    label: p.label,
                    values: <double>[
                      p.deskPnlInr,
                      p.benchmarkPnlInr,
                    ],
                  ),
                )
                .toList(),
            series: <UiChartSeries>[
              UiChartSeries(
                name: 'Desk Net P&L (₹)',
                color: theme.colors.primary,
                lineGlow: true,
              ),
              UiChartSeries(
                name: 'NIFTY Benchmark (₹)',
                color: theme.colors.info,
              ),
            ],
          ),
        ],
      ),
    );

    final Widget divisionCard = UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Desk Capital Allocation (INR)',
                      style: context.uiText.subheading,
                    ),
                    Text(
                      'Deployed margin across Indian market segments',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              UiBadge(
                label: formatInrCompact(snap.allocatedCapitalInr),
                intent: UiIntent.primary,
                size: UiSize.xs,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiDonutChart(
            size: 165,
            centerLabel: formatInrCompact(snap.allocatedCapitalInr),
            valueFormatter: (num v) => formatInrCompact(v),
            slices: snap.divisions
                .map(
                  (d) => UiDonutSlice(
                    label: d.divisionName,
                    value: d.allocatedCapitalInr,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );

    if (MediaQuery.sizeOf(context).width < 960) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          pnlChartCard,
          SizedBox(height: context.sp(theme.spacing.md)),
          divisionCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 3, child: pnlChartCard),
        SizedBox(width: context.sp(theme.spacing.md)),
        Expanded(flex: 2, child: divisionCard),
      ],
    );
  }

  Widget _buildLiveQueuesSection(
    BuildContext context,
    List<DeskOrderApproval> pendingOrders,
    List<DeskRiskBreach> openBreaches,
  ) {
    final UiTheme theme = context.ui;

    final Widget ordersCard = UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Pre-Trade Order Approval Queue',
                      style: context.uiText.subheading,
                    ),
                    Text(
                      'Orders exceeding single-order INR notional or concentration gates',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              UiButton(
                label: 'Risk & Compliance',
                variant: UiVariant.outline,
                size: UiSize.xs,
                onPressed: () => widget.onNavigate?.call('org_risk'),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          if (pendingOrders.isEmpty)
            const UiEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'All pre-trade orders cleared',
              message: 'No high-notional INR orders awaiting manual desk approval.',
              compact: true,
            )
          else
            ...pendingOrders.map(
              (order) => Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                child: UiCard(
                  variant: UiCardVariant.outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          UiBadge(
                            label: '${order.side} · ${order.exchange}',
                            intent: order.side == 'BUY'
                                ? UiIntent.bullish
                                : UiIntent.bearish,
                            size: UiSize.xs,
                          ),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          Expanded(
                            child: Text(
                              '${order.symbol} (${order.quantity} qty)',
                              style: context.uiText.bodyStrong,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            formatInrCompact(order.notionalValueInr),
                            style: context.uiText.mono.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      Text(
                        '${order.traderName} (@${order.traderHandle}) · ${order.reasonFlagged}',
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.sm)),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: context.sp(theme.spacing.xs),
                        runSpacing: context.sp(theme.spacing.xs),
                        children: <Widget>[
                          UiButton(
                            label: 'Reject',
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            intent: UiIntent.danger,
                            onPressed: () => _quickReviewOrder(order, false),
                          ),
                          UiButton(
                            label: 'Approve Order',
                            size: UiSize.xs,
                            intent: UiIntent.success,
                            onPressed: () => _quickReviewOrder(order, true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final Widget breachesCard = UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Active Risk Breach Alerts',
                      style: context.uiText.subheading,
                    ),
                    Text(
                      'Live drawdown, SPAN margin, and mandatory stop-loss triggers',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              UiBadge(
                label: '${openBreaches.length} ACTIVE',
                intent: openBreaches.isEmpty
                    ? UiIntent.success
                    : UiIntent.warning,
                size: UiSize.xs,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          if (openBreaches.isEmpty)
            const UiEmptyState(
              icon: Icons.verified_user_outlined,
              title: 'Zero active risk breaches',
              message: 'All seats are operating within INR margin and drawdown caps.',
              compact: true,
            )
          else
            ...openBreaches.map(
              (breach) => Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                child: UiCard(
                  variant: UiCardVariant.outlined,
                  intent: breach.severity == 'critical'
                      ? UiIntent.danger
                      : UiIntent.warning,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${breach.breachType} · ${breach.symbol}',
                              style: context.uiText.bodyStrong,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          UiBadge(
                            label: breach.severity.toUpperCase(),
                            intent: breach.severity == 'critical'
                                ? UiIntent.danger
                                : UiIntent.warning,
                            size: UiSize.xs,
                          ),
                        ],
                      ),
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      Text(
                        '${breach.traderName} (@${breach.traderHandle}) — ${breach.description}',
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.sm)),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: context.sp(theme.spacing.xs),
                        runSpacing: context.sp(theme.spacing.xs),
                        children: <Widget>[
                          UiButton(
                            label: 'Freeze Seat',
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            intent: UiIntent.danger,
                            onPressed: () async {
                              await _repo.updateRiskBreachStatus(
                                breachId: breach.id,
                                status: 'trader_frozen',
                                freezeTrader: true,
                                resolutionNotes:
                                    'Seat frozen from Desk Console.',
                              );
                              await _load();
                            },
                          ),
                          UiButton(
                            label: 'Mark Resolved',
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            intent: UiIntent.success,
                            onPressed: () async {
                              await _repo.updateRiskBreachStatus(
                                breachId: breach.id,
                                status: 'resolved',
                                resolutionNotes:
                                    'Resolved and verified from Desk Console.',
                              );
                              await _load();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (MediaQuery.sizeOf(context).width < 960) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ordersCard,
          SizedBox(height: context.sp(theme.spacing.md)),
          breachesCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: ordersCard),
        SizedBox(width: context.sp(theme.spacing.md)),
        Expanded(child: breachesCard),
      ],
    );
  }

  Widget _buildGovernanceAndAuditSection(
    BuildContext context, {
    required int pendingAffiliates,
    required int pendingPayouts,
    required int pendingDeletions,
  }) {
    final UiTheme theme = context.ui;
    final AffiliateWorkspace? ws = _affiliateWorkspace;

    final Widget crossPlatformHub = UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Cross-Platform Governance (Consumer · Affiliate INR · DPDP Purge)',
            style: context.uiText.subheading,
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Direct administrative links across Trader seats, Consumer subscriptions, Affiliate INR payouts, and conditional account deletions.',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppSettingCard(
            title: 'Traders, Seats & Consumer Directory',
            description:
                '${_consumers.length} registered consumer traders · Overrides for Basic (₹0), Pro (₹2,499) and Enterprise (₹7,999) tiers.',
            icon: Icons.badge_outlined,
            control: UiButton(
              label: 'Manage Seats',
              size: UiSize.xs,
              variant: UiVariant.outline,
              onPressed: () => widget.onNavigate?.call('org_team'),
            ),
          ),
          AppSettingCard(
            title: 'Affiliate Applications & INR Payout Settlement',
            description:
                '$pendingAffiliates pending partner reviews · $pendingPayouts INR payouts awaiting UTR · Unpaid partner ledger: ${formatInrAmount(ws?.profile.unpaidBalance ?? 0)}',
            icon: Icons.fact_check_outlined,
            control: UiButton(
              label: 'Review Affiliates',
              size: UiSize.xs,
              intent: UiIntent.primary,
              onPressed: () => widget.onNavigate?.call('affiliate_reviews'),
            ),
          ),
          AppSettingCard(
            title: 'Account Deletions & Conditional Data Purge Queue',
            description:
                '$pendingDeletions requests awaiting immediate or 30-day conditional data purge.',
            icon: Icons.delete_sweep_outlined,
            control: UiButton(
              label: 'Inspect Queue',
              size: UiSize.xs,
              variant: UiVariant.outline,
              intent: pendingDeletions > 0 ? UiIntent.warning : UiIntent.neutral,
              onPressed: () => widget.onNavigate?.call('org_team'),
            ),
          ),
        ],
      ),
    );

    final Widget auditStream = UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Tamper-Evident Audit Stream (SHA-256)',
                      style: context.uiText.subheading,
                    ),
                    Text(
                      'Latest cryptographic compliance events across desk & partner operations',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              UiButton(
                label: 'Full Audit Log',
                size: UiSize.xs,
                variant: UiVariant.ghost,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => widget.onNavigate?.call('org_audit'),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiTimeline(
            entries: _audits
                .take(4)
                .map(
                  (a) => UiTimelineEntry(
                    title: '${a.action} · ${a.targetLabel}',
                    subtitle:
                        '@${a.actorHandle} · ${a.details}\nSHA-256: ${a.sha256Hash.substring(0, 16)}…',
                    timestamp: AppTokens.shortDate(a.createdAt),
                    icon: switch (a.category) {
                      'risk_control' => Icons.shield_outlined,
                      'order_approval' => Icons.rule_folder_outlined,
                      'payout_settlement' => Icons.currency_rupee_rounded,
                      'account_deletion' => Icons.delete_forever_outlined,
                      _ => Icons.verified_user_outlined,
                    },
                    intent: switch (a.severity) {
                      'critical' => UiIntent.danger,
                      'warning' => UiIntent.warning,
                      _ => UiIntent.primary,
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );

    if (MediaQuery.sizeOf(context).width < 960) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          crossPlatformHub,
          SizedBox(height: context.sp(theme.spacing.md)),
          auditStream,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: crossPlatformHub),
        SizedBox(width: context.sp(theme.spacing.md)),
        Expanded(child: auditStream),
      ],
    );
  }
}
