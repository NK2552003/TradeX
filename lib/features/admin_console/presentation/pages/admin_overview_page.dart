import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/admin_console/models/admin_console_models.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  final AdminConsoleRepository _repo = AdminConsoleRepository.instance;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _queueKey = GlobalKey();

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

  // In-memory resolved states for instant inline resolution morphing
  final Map<String, String> _resolvedOrders = <String, String>{};
  final Map<String, String> _resolvedBreaches = <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
          debugPrint(
            'AdminOverviewPage getAffiliateWorkspaceSnapshot error: $e',
          );
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

  void _scrollToQueue() {
    final ctx = _queueKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _toggleCircuitBreaker(String currentState) async {
    final bool isHalted = currentState == 'halted';
    final TextEditingController reasonCtrl = TextEditingController(
      text: isHalted
          ? 'All NSE/NFO margin checks verified. Resuming normal desk execution.'
          : 'Emergency volatility circuit breaker triggered by Desk Admin.',
    );

    final bool? confirmed = await UiDialog.present<bool>(
      context: context,
      builder: (BuildContext ctx) => UiDialog(
        title: isHalted
            ? 'Resume Institutional Desk Execution?'
            : 'Halt the whole desk?',
        description: isHalted
            ? 'This unfreezes every active seat and resumes order placement within assigned capital caps.'
            : 'This freezes every seat and blocks new orders until you lift the halt.',
        actions: <Widget>[
          UiButton(
            label: isHalted ? 'Cancel' : 'Keep trading',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          UiButton(
            label: isHalted ? 'Resume Desk Execution' : 'Freeze all seats',
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
          title: isHalted ? 'Desk Execution Resumed' : 'All seats frozen',
          message: isHalted
              ? 'Circuit breaker reset to armed. All active trader seats unlocked.'
              : 'All trader seats frozen and pre-trade order routing blocked.',
          intent: isHalted ? UiIntent.success : UiIntent.danger,
        );
      }
    } else {
      reasonCtrl.dispose();
    }
  }

  Future<void> _handleOrderAction(DeskOrderApproval order, bool approve) async {
    final String statusMsg = approve ? 'Order approved' : 'Order rejected';
    setState(() {
      _resolvedOrders[order.id] = statusMsg;
    });
    UiToast.show(
      context,
      title: statusMsg,
      message:
          '${order.side} ${order.quantity} ${order.symbol} (${formatInrCompact(order.notionalValueInr)})',
      intent: approve ? UiIntent.success : UiIntent.danger,
    );
    await _repo.reviewOrderApproval(
      orderId: order.id,
      approve: approve,
      notes: approve
          ? 'Approved from Institutional Desk Console.'
          : 'Rejected from Institutional Desk Console.',
    );
  }

  Future<void> _handleBreachAction(DeskRiskBreach breach, bool freeze) async {
    final String statusMsg = freeze ? 'Seat frozen' : 'Marked resolved';
    setState(() {
      _resolvedBreaches[breach.id] = statusMsg;
    });
    UiToast.show(
      context,
      title: statusMsg,
      message: '${breach.traderName} (${breach.symbol}) updated.',
      intent: freeze ? UiIntent.danger : UiIntent.success,
    );
    await _repo.updateRiskBreachStatus(
      breachId: breach.id,
      status: freeze ? 'trader_frozen' : 'resolved',
      freezeTrader: freeze,
      resolutionNotes: freeze
          ? 'Seat frozen from Institutional Desk Console.'
          : 'Breach marked resolved from Institutional Desk Console.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    if (_loading || _snapshot == null) {
      return UiSkeleton.dashboard();
    }

    final AdminDeskAnalyticsSnapshot snap = _snapshot!;
    final bool isHalted = snap.activeCircuitBreakerState == 'halted';

    // Pending list minus any resolved in-memory during this session
    final List<DeskOrderApproval> pendingOrders = _orders
        .where((o) => o.status == 'pending' && !_resolvedOrders.containsKey(o.id))
        .toList();
    final List<DeskRiskBreach> openBreaches = _breaches
        .where((b) =>
            (b.status == 'open' || b.status == 'acknowledged') &&
            !_resolvedBreaches.containsKey(b.id))
        .toList();

    final int pendingAffiliates = _applications
        .where((a) => a.status == AffiliateApplicationStatus.pending)
        .length;
    final int pendingPayouts =
        (_affiliateWorkspace?.payouts ?? const <AffiliatePayout>[])
            .where((p) => p.status == 'pending' || p.status == 'processing')
            .length;
    final int pendingDeletions = _deletions
        .where((d) => d.status != 'data_purged' && d.status != 'cancelled')
        .length;

    return Scaffold(
      backgroundColor: c.background,
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Top Frozen Banner
            if (isHalted)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: context.sp(theme.spacing.sm),
                  horizontal: context.sp(theme.spacing.md),
                ),
                color: c.destructive,
                child: Center(
                  child: Text(
                    'Desk halted: all seats are frozen',
                    style: context.uiText.bodyStrong.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            // Main Wrap Container
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.md),
                    vertical: context.sp(theme.spacing.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Top bar / Header
                      Padding(
                        padding: EdgeInsets.only(
                          top: context.sp(theme.spacing.sm),
                          bottom: context.sp(theme.spacing.md),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Institutional Desk Console',
                                    style: context.uiText.title.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 30,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: context.sp(theme.spacing.xxs)),
                                  Text(
                                    'Live INR capital, pre-trade risk checks, partner payouts and data-deletion requests.',
                                    style: context.uiText.caption.copyWith(
                                      color: c.foregroundMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.md)),
                            Wrap(
                              spacing: context.sp(theme.spacing.xs),
                              runSpacing: context.sp(theme.spacing.xs),
                              children: <Widget>[
                                UiButton(
                                  label: 'Refresh',
                                  variant: UiVariant.outline,
                                  size: UiSize.sm,
                                  onPressed: () {
                                    _load();
                                    UiToast.show(
                                      context,
                                      title: 'Figures refreshed',
                                      message: 'Desk data synced from server.',
                                      intent: UiIntent.info,
                                    );
                                  },
                                ),
                                UiButton(
                                  label: isHalted
                                      ? 'Resume desk execution'
                                      : 'Emergency killswitch',
                                  intent: isHalted
                                      ? UiIntent.success
                                      : UiIntent.danger,
                                  variant: isHalted
                                      ? UiVariant.solid
                                      : UiVariant.destructive,
                                  size: UiSize.sm,
                                  onPressed: () => _toggleCircuitBreaker(
                                    snap.activeCircuitBreakerState,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Live Status Line
                      DeskStatusBar(
                        isHalted: isHalted,
                        supervisedCapitalInr: snap.supervisedCapitalInr,
                        allocatedCapitalInr: snap.allocatedCapitalInr,
                        seatCount: _seats.length,
                        maxDrawdownPct: snap.maxDrawdownPct,
                      ),

                      // 4-column Ledger KPIs
                      DeskLedgerBlock(
                        items: <DeskLedgerItem>[
                          DeskLedgerItem(
                            label: 'Allocated Desk Capital',
                            value: formatInrCompact(snap.allocatedCapitalInr),
                            subtext:
                                '${_consumers.length} registered traders · ${formatInrCompact(snap.supervisedCapitalInr)} pool',
                          ),
                          DeskLedgerItem(
                            label: 'Intraday Desk Net P&L',
                            value: formatInrCompact(snap.intradayPnlInr, signed: true),
                            valueColor: snap.intradayPnlInr >= 0
                                ? c.bullish
                                : c.bearish,
                            subtext:
                                'MRR ${formatInrAmount(snap.subscriptionMrrInr)}/mo · ${_consumers.where((c) => c.subscriptionTier != "Basic").length} paid subscribers',
                          ),
                          DeskLedgerItem(
                            label: 'Needs your decision',
                            value:
                                '${pendingOrders.length} orders · ${openBreaches.length} alerts',
                            actionLabel: 'Review below',
                            onTap: _scrollToQueue,
                          ),
                          DeskLedgerItem(
                            label: 'Partners and deletions',
                            value:
                                '${pendingAffiliates + pendingPayouts} partner · $pendingDeletions purge',
                            subtext:
                                'Settled INR payouts ${formatInrCompact(snap.affiliatePayoutsSettledInr)}',
                          ),
                        ],
                      ),
                      SizedBox(height: context.sp(theme.spacing.lg)),

                      // Main Sections Grid
                      LayoutBuilder(
                        builder: (BuildContext ctx, BoxConstraints constraints) {
                          final bool isWide = constraints.maxWidth >= 950;
                          return Column(
                            key: _queueKey,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              // Row 1: Order Approvals (7) + Risk Alerts (5)
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      flex: 7,
                                      child: _buildOrderApprovalsSection(
                                        context,
                                        pendingOrders,
                                      ),
                                    ),
                                    SizedBox(width: ctx.sp(theme.spacing.xl)),
                                    Expanded(
                                      flex: 5,
                                      child: _buildRiskAlertsSection(
                                        context,
                                        openBreaches,
                                      ),
                                    ),
                                  ],
                                )
                              else ...<Widget>[
                                _buildOrderApprovalsSection(
                                  context,
                                  pendingOrders,
                                ),
                                SizedBox(height: ctx.sp(theme.spacing.lg)),
                                _buildRiskAlertsSection(context, openBreaches),
                              ],

                              SizedBox(height: context.sp(theme.spacing.xl)),

                              // Row 2: Desk P&L Chart (7) + Segment Allocation Donut (5)
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      flex: 7,
                                      child: _buildPnlChartSection(
                                        context,
                                        snap,
                                      ),
                                    ),
                                    SizedBox(width: ctx.sp(theme.spacing.xl)),
                                    Expanded(
                                      flex: 5,
                                      child: _buildCapitalAllocationSection(
                                        context,
                                        snap,
                                      ),
                                    ),
                                  ],
                                )
                              else ...<Widget>[
                                _buildPnlChartSection(context, snap),
                                SizedBox(height: ctx.sp(theme.spacing.lg)),
                                _buildCapitalAllocationSection(context, snap),
                              ],

                              SizedBox(height: context.sp(theme.spacing.xl)),

                              // Row 3: Governance (6) + Audit Trail (6)
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      flex: 6,
                                      child: _buildGovernanceSection(
                                        context,
                                        pendingAffiliates: pendingAffiliates,
                                        pendingPayouts: pendingPayouts,
                                        pendingDeletions: pendingDeletions,
                                      ),
                                    ),
                                    SizedBox(width: ctx.sp(theme.spacing.xl)),
                                    Expanded(
                                      flex: 6,
                                      child: _buildAuditSection(context),
                                    ),
                                  ],
                                )
                              else ...<Widget>[
                                _buildGovernanceSection(
                                  context,
                                  pendingAffiliates: pendingAffiliates,
                                  pendingPayouts: pendingPayouts,
                                  pendingDeletions: pendingDeletions,
                                ),
                                SizedBox(height: ctx.sp(theme.spacing.lg)),
                                _buildAuditSection(context),
                              ],
                              SizedBox(height: context.sp(theme.spacing.xxl)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 1: Order Approvals (c7)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOrderApprovalsSection(
    BuildContext context,
    List<DeskOrderApproval> pendingOrders,
  ) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    final int count = pendingOrders.length;
    final String countLabel = count > 0 ? '$count waiting' : 'All clear';
    final UiIntent countIntent = count > 0 ? UiIntent.warning : UiIntent.success;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.border, width: theme.borders.hairline),
        ),
      ),
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Order approvals',
                  style: context.uiText.heading.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              UiBadge(
                label: countLabel,
                intent: countIntent,
                size: UiSize.xs,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            'Orders over the single-order limit or the concentration limit.',
            style: context.uiText.caption.copyWith(
              color: c.foregroundMuted,
              fontSize: 14,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          if (_orders.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.md)),
              child: Text(
                'No orders waiting.',
                style: context.uiText.caption.copyWith(color: c.foregroundMuted),
              ),
            )
          else
            ..._orders.map((DeskOrderApproval order) {
              final bool isResolved = _resolvedOrders.containsKey(order.id) ||
                  order.status != 'pending';
              final String? resolvedMsg = _resolvedOrders[order.id] ??
                  (order.status == 'approved'
                      ? 'Order approved'
                      : (order.status == 'rejected' ? 'Order rejected' : null));

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: c.border, width: theme.borders.hairline),
                  ),
                ),
                padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.md)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: context.sp(theme.spacing.xs),
                            runSpacing: context.sp(theme.spacing.xxs),
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              UiBadge(
                                label: '${order.side} · ${order.exchange}',
                                intent: order.side == 'BUY'
                                    ? UiIntent.bullish
                                    : UiIntent.bearish,
                                size: UiSize.xs,
                              ),
                              Text(
                                '${order.symbol}, ${order.quantity} qty',
                                style: context.uiText.bodyStrong.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                formatInrCompact(order.notionalValueInr),
                                style: context.uiText.bodyStrong.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: context.sp(theme.spacing.xxs)),
                          Text(
                            '${order.traderName} (@${order.traderHandle}). ${order.reasonFlagged}',
                            style: context.uiText.caption.copyWith(
                              color: c.foregroundMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    if (isResolved && resolvedMsg != null)
                      Text(
                        resolvedMsg,
                        style: context.uiText.bodyStrong.copyWith(
                          color: resolvedMsg.contains('approved')
                              ? c.bullish
                              : c.destructive,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Wrap(
                        spacing: context.sp(theme.spacing.xs),
                        children: <Widget>[
                          UiButton(
                            label: 'Reject',
                            size: UiSize.sm,
                            variant: UiVariant.outline,
                            intent: UiIntent.danger,
                            onPressed: () => _handleOrderAction(order, false),
                          ),
                          UiButton(
                            label: 'Approve',
                            size: UiSize.sm,
                            variant: UiVariant.solid,
                            intent: UiIntent.success,
                            onPressed: () => _handleOrderAction(order, true),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 2: Risk Alerts (c5)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRiskAlertsSection(
    BuildContext context,
    List<DeskRiskBreach> openBreaches,
  ) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    final int count = openBreaches.length;
    final String countLabel = count > 0 ? '$count active' : 'None active';
    final UiIntent countIntent = count > 0 ? UiIntent.danger : UiIntent.success;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.border, width: theme.borders.hairline),
        ),
      ),
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Risk alerts',
                  style: context.uiText.heading.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              UiBadge(
                label: countLabel,
                intent: countIntent,
                size: UiSize.xs,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            'Drawdown, SPAN margin and stop-loss triggers.',
            style: context.uiText.caption.copyWith(
              color: c.foregroundMuted,
              fontSize: 14,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          if (_breaches.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.md)),
              child: Text(
                'No active risk alerts.',
                style: context.uiText.caption.copyWith(color: c.foregroundMuted),
              ),
            )
          else
            ..._breaches.map((DeskRiskBreach breach) {
              final bool isResolved = _resolvedBreaches.containsKey(breach.id) ||
                  breach.status == 'resolved' ||
                  breach.status == 'trader_frozen';
              final String? resolvedMsg = _resolvedBreaches[breach.id] ??
                  (breach.status == 'trader_frozen'
                      ? 'Seat frozen'
                      : (breach.status == 'resolved' ? 'Marked resolved' : null));

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: c.border, width: theme.borders.hairline),
                  ),
                ),
                padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.md)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: context.sp(theme.spacing.xs),
                      runSpacing: context.sp(theme.spacing.xxs),
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          breach.breachType,
                          style: context.uiText.bodyStrong.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        UiBadge(
                          label: breach.severity == 'critical'
                              ? 'Critical'
                              : 'Warning',
                          intent: breach.severity == 'critical'
                              ? UiIntent.danger
                              : UiIntent.warning,
                          size: UiSize.xs,
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(theme.spacing.xxs)),
                    Text(
                      '${breach.traderName} (@${breach.traderHandle}). ${breach.description}',
                      style: context.uiText.caption.copyWith(
                        color: c.foregroundMuted,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    if (isResolved && resolvedMsg != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          resolvedMsg,
                          style: context.uiText.bodyStrong.copyWith(
                            color: resolvedMsg.contains('resolved')
                                ? c.bullish
                                : c.destructive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: context.sp(theme.spacing.xs),
                        children: <Widget>[
                          UiButton(
                            label: 'Freeze seat',
                            size: UiSize.sm,
                            variant: UiVariant.outline,
                            intent: UiIntent.danger,
                            onPressed: () => _handleBreachAction(breach, true),
                          ),
                          UiButton(
                            label: 'Mark resolved',
                            size: UiSize.sm,
                            variant: UiVariant.outline,
                            intent: UiIntent.success,
                            onPressed: () => _handleBreachAction(breach, false),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 3: Desk P&L vs NIFTY Chart (c7)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPnlChartSection(
    BuildContext context,
    AdminDeskAnalyticsSnapshot snap,
  ) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.border, width: theme.borders.hairline),
        ),
      ),
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                'Desk P&L against NIFTY',
                style: context.uiText.heading.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              InkWell(
                onTap: () => widget.onNavigate?.call('org_analytics'),
                child: Text(
                  'Full analytics',
                  style: context.uiText.caption.copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            'Net desk return compared with the same exposure held in NIFTY 50.',
            style: context.uiText.caption.copyWith(
              color: c.foregroundMuted,
              fontSize: 14,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.md),
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: c.foreground,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Text(
                    'Desk net P&L',
                    style: context.uiText.caption.copyWith(color: c.foregroundMuted),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Text(
                    'NIFTY benchmark',
                    style: context.uiText.caption.copyWith(color: c.foregroundMuted),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiAreaChart(
            height: 250,
            valueFormatter: (num v) => formatInrCompact(v),
            data: snap.points
                .map(
                  (p) => UiChartPoint(
                    label: p.label,
                    values: <double>[p.deskPnlInr, p.benchmarkPnlInr],
                  ),
                )
                .toList(),
            series: <UiChartSeries>[
              UiChartSeries(
                name: 'Desk Net P&L',
                color: c.foreground,
                lineGlow: false,
              ),
              UiChartSeries(
                name: 'NIFTY Benchmark',
                color: c.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 4: Capital by Segment Donut (c5)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCapitalAllocationSection(
    BuildContext context,
    AdminDeskAnalyticsSnapshot snap,
  ) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    final List<({String label, double pct, Color color})> segments = [
      (label: 'Index & options (NSE/NFO)', pct: 46.0, color: c.primary),
      (label: 'Cash equities', pct: 24.5, color: c.bullish),
      (label: 'Arbitrage baskets', pct: 21.4, color: c.warning),
      (label: 'Commodities & FX (MCX)', pct: 8.1, color: c.secondary),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.border, width: theme.borders.hairline),
        ),
      ),
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                'Capital by segment',
                style: context.uiText.heading.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              UiBadge(
                label: formatInrCompact(snap.allocatedCapitalInr),
                intent: UiIntent.neutral,
                size: UiSize.xs,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            'Margin deployed across Indian market segments.',
            style: context.uiText.caption.copyWith(
              color: c.foregroundMuted,
              fontSize: 14,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                flex: 4,
                child: UiDonutChart(
                  size: 155,
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
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(
                flex: 5,
                child: Column(
                  children: segments.map((s) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        vertical: context.sp(theme.spacing.xs),
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: c.border,
                            width: theme.borders.hairline,
                          ),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: s.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          Expanded(
                            child: Text(
                              s.label,
                              style: context.uiText.caption.copyWith(
                                color: c.foreground,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '${s.pct.toStringAsFixed(1)}%',
                            style: context.uiText.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 5: Traders, Partners & Deletions Governance (c6)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGovernanceSection(
    BuildContext context, {
    required int pendingAffiliates,
    required int pendingPayouts,
    required int pendingDeletions,
  }) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final AffiliateWorkspace? ws = _affiliateWorkspace;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.border, width: theme.borders.hairline),
        ),
      ),
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Traders, partners and deletions',
            style: context.uiText.heading.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            'Seats, subscriptions, INR payouts and data purges (DPDP).',
            style: context.uiText.caption.copyWith(
              color: c.foregroundMuted,
              fontSize: 14,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Row 1: Traders and seats
          Container(
            padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.md)),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: c.border, width: theme.borders.hairline),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Traders and seats',
                        style: context.uiText.bodyStrong.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.xxs)),
                      Text(
                        '${_consumers.length} registered traders. Overrides for Basic (₹0), Pro (₹2,499) and Enterprise (₹7,999).',
                        style: context.uiText.caption.copyWith(
                          color: c.foregroundMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                UiButton(
                  label: 'Manage seats',
                  size: UiSize.sm,
                  variant: UiVariant.outline,
                  onPressed: () => widget.onNavigate?.call('org_team'),
                ),
              ],
            ),
          ),

          // Row 2: Affiliate applications and payouts
          Container(
            padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.md)),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: c.border, width: theme.borders.hairline),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Affiliate applications and payouts',
                        style: context.uiText.bodyStrong.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.xxs)),
                      Text(
                        '$pendingAffiliates partner review pending. $pendingPayouts payout waiting for a UTR. Unpaid partner ledger ${formatInrAmount(ws?.profile.unpaidBalance ?? 0)}.',
                        style: context.uiText.caption.copyWith(
                          color: c.foregroundMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                UiButton(
                  label: 'Review affiliates',
                  size: UiSize.sm,
                  variant: UiVariant.solid,
                  intent: UiIntent.success,
                  onPressed: () =>
                      widget.onNavigate?.call('affiliate_reviews'),
                ),
              ],
            ),
          ),

          // Row 3: Account deletions
          Container(
            padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.md)),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: c.border, width: theme.borders.hairline),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Account deletions',
                        style: context.uiText.bodyStrong.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.xxs)),
                      Text(
                        '$pendingDeletions request waiting for an immediate or 30-day data purge.',
                        style: context.uiText.caption.copyWith(
                          color: c.foregroundMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                UiButton(
                  label: 'Inspect queue',
                  size: UiSize.sm,
                  variant: UiVariant.outline,
                  intent: UiIntent.warning,
                  onPressed: () => widget.onNavigate?.call('org_team'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section 6: Audit Trail Stream (c6)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAuditSection(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.border, width: theme.borders.hairline),
        ),
      ),
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                'Audit trail',
                style: context.uiText.heading.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              InkWell(
                onTap: () => widget.onNavigate?.call('org_audit'),
                child: Text(
                  'Full audit log',
                  style: context.uiText.caption.copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            'Latest compliance events, each sealed with a SHA-256 hash.',
            style: context.uiText.caption.copyWith(
              color: c.foregroundMuted,
              fontSize: 14,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Column(
            children: _audits.take(4).map((AdminAuditLogEntry a) {
              return Container(
                padding: EdgeInsets.only(
                  left: context.sp(theme.spacing.sm),
                  bottom: context.sp(theme.spacing.md),
                ),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: c.border,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${a.action.replaceAll('_', ' ')} · ${a.targetLabel}',
                      style: context.uiText.bodyStrong.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.xxs)),
                    Text(
                      '@${a.actorHandle} ${a.details}',
                      style: context.uiText.caption.copyWith(
                        color: c.foregroundMuted,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.xxs)),
                    Wrap(
                      spacing: context.sp(theme.spacing.sm),
                      children: <Widget>[
                        Text(
                          '${a.sha256Hash.substring(0, 16)}…',
                          style: context.uiText.mono.copyWith(
                            color: c.foregroundMuted,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          AppTokens.shortDate(a.createdAt),
                          style: context.uiText.caption.copyWith(
                            color: c.foregroundMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
