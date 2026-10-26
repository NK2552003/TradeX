import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/admin_console/models/admin_console_models.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:tradex/features/settings/models/desk_risk_model.dart';

class AdminRiskCompliancePage extends StatefulWidget {
  const AdminRiskCompliancePage({super.key});

  @override
  State<AdminRiskCompliancePage> createState() =>
      _AdminRiskCompliancePageState();
}

class _AdminRiskCompliancePageState extends State<AdminRiskCompliancePage> {
  final AdminConsoleRepository _repo = AdminConsoleRepository.instance;

  bool _loading = true;
  bool _savingPolicy = false;
  String _breakerState = 'armed';
  String _orderFilter = 'pending'; // pending | approved | rejected | all
  DeskRiskModel _policy = DeskRiskModel.defaultConfig();
  DeskRiskModel _savedPolicy = DeskRiskModel.defaultConfig();
  List<DeskOrderApproval> _orders = const <DeskOrderApproval>[];
  List<DeskRiskBreach> _breaches = const <DeskRiskBreach>[];

  bool get _hasUnsavedChanges => _policy != _savedPolicy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _repo.getDeskRiskConfig(),
        _repo.getCircuitBreakerState(),
        _repo.listOrderApprovals(),
        _repo.listRiskBreaches(),
      ]);
      if (!mounted) return;
      final loadedPolicy = results[0] as DeskRiskModel;
      setState(() {
        _policy = loadedPolicy;
        _savedPolicy = loadedPolicy;
        _breakerState = results[1] as String;
        _orders = results[2] as List<DeskOrderApproval>;
        _breaches = results[3] as List<DeskRiskBreach>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePolicy() async {
    setState(() => _savingPolicy = true);
    try {
      final updated = await _repo.updateDeskRiskConfig(_policy);
      if (!mounted) return;
      setState(() {
        _policy = updated;
        _savedPolicy = updated;
      });
      UiToast.show(
        context,
        title: 'Desk Risk Policy Enforced',
        message:
            'Updated pre-trade margin & drawdown limits across all institutional seats.',
        intent: UiIntent.success,
      );
    } finally {
      if (mounted) setState(() => _savingPolicy = false);
    }
  }

  Future<void> _reviewOrderDialog(DeskOrderApproval order, bool approve) async {
    final TextEditingController notesCtrl = TextEditingController(
      text: approve
          ? 'Approved after verifying SPAN margin and delta hedge.'
          : 'Rejected: Exceeds single-order concentration cap.',
    );

    final bool? confirmed = await UiDialog.present<bool>(
      context: context,
      builder: (BuildContext ctx) => UiDialog(
        title: approve ? 'Approve Pre-Trade Order?' : 'Reject Pre-Trade Order?',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            UiCallout(
              title:
                  '${order.side} ${order.quantity} ${order.symbol} (${order.exchange})',
              message:
                  'Trader: ${order.traderName} (@${order.traderHandle})\n'
                  'Notional Exposure: ${formatInrCompact(order.notionalValueInr)} (${order.leverageX}x leverage)\n'
                  'Stop-Loss: ${formatInrCompact(order.stopLossInr)} · Target: ${formatInrCompact(order.targetPriceInr)}',
              intent: approve ? UiIntent.success : UiIntent.danger,
            ),
            SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
            UiField(
              label: 'Risk Officer Review Note',
              required: true,
              child: UiTextarea(
                controller: notesCtrl,
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
            label: approve ? 'Confirm Approval' : 'Reject Order',
            intent: approve ? UiIntent.success : UiIntent.danger,
            variant: approve ? UiVariant.solid : UiVariant.destructive,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repo.reviewOrderApproval(
        orderId: order.id,
        approve: approve,
        notes: notesCtrl.text,
      );
      await _load();
      if (mounted) {
        UiToast.show(
          context,
          title: approve ? 'Order Released to Exchange' : 'Order Blocked',
          message:
              '${order.symbol} (${formatInrCompact(order.notionalValueInr)}) logged to compliance ledger.',
          intent: approve ? UiIntent.success : UiIntent.warning,
        );
      }
    }
    notesCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    if (_loading) {
      return UiSkeleton.page();
    }

    final List<DeskOrderApproval> visibleOrders = _orderFilter == 'all'
        ? _orders
        : _orders.where((o) => o.status == _orderFilter).toList();
    final int pendingCount = _orders.where((o) => o.status == 'pending').length;
    final int openBreachesCount = _breaches
        .where((b) => b.status == 'open' || b.status == 'acknowledged')
        .length;

    return UiPage(
      maxWidth: 1440,
      header: UiHeader(
        title: 'Risk Limits, Pre-Trade Gates & Compliance',
        subtitle:
            'Firm-wide INR margin caps, high-notional order approvals & breach incident response.',
        leading: Icon(Icons.shield_outlined, color: theme.colors.primary),
        actions: <Widget>[
          if (_hasUnsavedChanges)
            const UiBadge(
              label: 'Unsaved Policy Changes',
              intent: UiIntent.warning,
              size: UiSize.xs,
            )
          else
            const UiBadge(
              label: 'All Rules Synced',
              intent: UiIntent.success,
              size: UiSize.xs,
            ),
          UiButton(
            label: 'Refresh',
            leadingIcon: Icons.refresh_rounded,
            variant: UiVariant.outline,
            size: UiSize.sm,
            onPressed: _load,
          ),
          UiButton(
            label: 'Save Risk Policy',
            leadingIcon: Icons.save_outlined,
            intent: UiIntent.primary,
            size: UiSize.sm,
            loading: _savingPolicy,
            onPressed: _savePolicy,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Desk Ledger 4-Column Summary Block
          DeskLedgerBlock(
            items: <DeskLedgerItem>[
              DeskLedgerItem(
                label: 'CIRCUIT BREAKER',
                value: _breakerState == 'halted' ? 'HALTED' : 'ARMED',
                valueColor: _breakerState == 'halted'
                    ? theme.colors.danger
                    : theme.colors.success,
                subtext: _breakerState == 'halted'
                    ? 'All non-owner seats frozen'
                    : 'Pre-trade risk engine active',
                badgeText: _breakerState == 'halted' ? 'HALTED' : 'ARMED',
                badgeIntent: _breakerState == 'halted'
                    ? UiIntent.danger
                    : UiIntent.success,
              ),
              DeskLedgerItem(
                label: 'MAX INTRADAY LEVERAGE',
                value: '${_policy.maxLeverage.toStringAsFixed(0)}x',
                subtext:
                    'Daily loss cap: ${_policy.maxDailyLossPercent.toStringAsFixed(1)}%',
              ),
              DeskLedgerItem(
                label: 'ORDERS AWAITING APPROVAL',
                value: '$pendingCount Flagged',
                valueColor: pendingCount > 0
                    ? theme.colors.warning
                    : theme.colors.foreground,
                subtext: '${_orders.length} total pre-trade checks',
                badgeText: pendingCount > 0 ? 'NEEDS REVIEW' : 'CLEAR',
                badgeIntent: pendingCount > 0
                    ? UiIntent.warning
                    : UiIntent.success,
              ),
              DeskLedgerItem(
                label: 'OPEN BREACHES',
                value: '$openBreachesCount Open',
                valueColor: openBreachesCount > 0
                    ? theme.colors.danger
                    : theme.colors.success,
                subtext:
                    'Hard drawdown cap: ${_policy.maxTotalDrawdownPercent.toStringAsFixed(1)}%',
                badgeText: openBreachesCount > 0 ? 'ALERT' : 'OPTIMAL',
                badgeIntent: openBreachesCount > 0
                    ? UiIntent.danger
                    : UiIntent.success,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Firm-Wide Risk Policy Controls + Circuit Breaker
          _buildPolicyControlsSection(context),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Pre-Trade Order Approval Queue
          _buildOrderApprovalSection(context, visibleOrders),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Risk Breach Incident Log
          _buildBreachLogSection(context),
        ],
      ),
    );
  }

  Widget _buildPolicyControlsSection(BuildContext context) {
    final UiTheme theme = context.ui;

    final Widget slidersCard = UiCard(
      title: 'Institutional Margin & Drawdown Thresholds',
      subtitle:
          'Real-time thresholds enforced across all proprietary trader seats.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_policy.maxDailyLossPercent > _policy.maxTotalDrawdownPercent) ...<Widget>[
            UiCallout(
              title: 'Configuration Warning',
              message:
                  'Daily loss cap (${_policy.maxDailyLossPercent.toStringAsFixed(1)}%) cannot exceed total drawdown cap (${_policy.maxTotalDrawdownPercent.toStringAsFixed(1)}%). Risk engine may trigger premature liquidation.',
              intent: UiIntent.warning,
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
          ],
          UiField(
            label:
                'Maximum Intraday Leverage (${_policy.maxLeverage.toStringAsFixed(0)}x)',
            helperText: 'Applies to NSE Cash, NFO Futures, and MCX Intraday',
            child: UiSlider(
              value: _policy.maxLeverage.clamp(1.0, 50.0),
              min: 1.0,
              max: 50.0,
              divisions: 49,
              onChanged: (double v) => setState(
                () =>
                    _policy = _policy.copyWith(maxLeverage: v.roundToDouble()),
              ),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiField(
            label:
                'Max Daily Seat Loss Cap (${_policy.maxDailyLossPercent.toStringAsFixed(1)}%)',
            helperText:
                'Automatically switches trader seat to close-only when reached',
            child: UiSlider(
              value: _policy.maxDailyLossPercent.clamp(0.5, 15.0),
              min: 0.5,
              max: 15.0,
              divisions: 29,
              onChanged: (double v) => setState(
                () => _policy = _policy.copyWith(maxDailyLossPercent: v),
              ),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiField(
            label:
                'Max Total Seat Drawdown Cap (${_policy.maxTotalDrawdownPercent.toStringAsFixed(1)}%)',
            helperText:
                'Trailing high-water mark drawdown limit before seat suspension',
            child: UiSlider(
              value: _policy.maxTotalDrawdownPercent.clamp(1.0, 30.0),
              min: 1.0,
              max: 30.0,
              divisions: 29,
              onChanged: (double v) => setState(
                () => _policy = _policy.copyWith(maxTotalDrawdownPercent: v),
              ),
            ),
          ),
        ],
      ),
    );

    final Widget gatesCard = UiCard(
      title: 'Exchange Segment & Execution Gates',
      subtitle:
          'Control permitted asset classes and mandatory order attachments.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSettingCard(
            title: 'Mandatory Stop-Loss Attachment',
            description:
                'Reject any trader order submitted without a hard GTT/bracket stop-loss.',
            icon: Icons.shield_moon_outlined,
            control: UiSwitch(
              value: _policy.requireStopLoss,
              onChanged: (bool v) => setState(
                () => _policy = _policy.copyWith(requireStopLoss: v),
              ),
            ),
          ),
          AppSettingCard(
            title: 'Auto Square-Off on Hard Drawdown Breach',
            description:
                'Automatically square off open positions if daily loss cap is breached.',
            icon: Icons.flash_on_outlined,
            control: UiSwitch(
              value: _policy.autoLiquidateOnBreach,
              onChanged: (bool v) => setState(
                () => _policy = _policy.copyWith(autoLiquidateOnBreach: v),
              ),
            ),
          ),
          AppSettingCard(
            title: 'Permit NSE/BSE Index & Equity Options (NFO)',
            description:
                'Allow option writing and multi-leg spreads within SPAN margin limits.',
            icon: Icons.candlestick_chart_outlined,
            control: UiSwitch(
              value: _policy.allowOptions,
              onChanged: (bool v) =>
                  setState(() => _policy = _policy.copyWith(allowOptions: v)),
            ),
          ),
          AppSettingCard(
            title: 'Permit Digital Assets / Crypto Derivatives',
            description:
                'Allow 24/7 digital asset pairs (subject to 30% VDA tax compliance).',
            icon: Icons.currency_bitcoin_rounded,
            control: UiSwitch(
              value: _policy.allowCrypto,
              onChanged: (bool v) =>
                  setState(() => _policy = _policy.copyWith(allowCrypto: v)),
            ),
          ),
        ],
      ),
    );

    return UiCardGrid(
      minTileWidth: 420,
      largeColumns: 2,
      children: [slidersCard, gatesCard],
    );
  }

  Widget _buildOrderApprovalSection(
    BuildContext context,
    List<DeskOrderApproval> visibleOrders,
  ) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Pre-Trade High-Notional Order Approval Queue (INR ₹)',
      subtitle:
          'Review and release or block flagged institutional orders before exchange routing.',
      trailing: UiToggleGroup<String>(
        value: _orderFilter,
        options: const <UiToggleOption<String>>[
          UiToggleOption(value: 'pending', label: 'Pending'),
          UiToggleOption(value: 'approved', label: 'Approved'),
          UiToggleOption(value: 'rejected', label: 'Rejected'),
          UiToggleOption(value: 'all', label: 'All'),
        ],
        onChanged: (String v) => setState(() => _orderFilter = v),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (visibleOrders.isEmpty)
            const UiEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No orders in this filter',
              message: 'Select another filter or wait for new pre-trade flags.',
              compact: true,
            )
          else
            UiTable<DeskOrderApproval>(
              rows: visibleOrders,
              rowKey: (o) => o.id,
              stackOnMobile: true,
              columns: <UiTableColumn<DeskOrderApproval>>[
                UiTableColumn<DeskOrderApproval>(
                  id: 'instrument',
                  label: 'Instrument & Exchange',
                  flex: 2,
                  cellBuilder: (BuildContext ctx, DeskOrderApproval o) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Wrap(
                        spacing: ctx.sp(theme.spacing.xs),
                        runSpacing: ctx.sp(theme.spacing.xs),
                        children: <Widget>[
                          UiBadge(
                            label: '${o.side} · ${o.exchange}',
                            intent: o.side == 'BUY'
                                ? UiIntent.bullish
                                : UiIntent.bearish,
                            size: UiSize.xs,
                          ),
                          Text(o.symbol, style: ctx.uiText.bodyStrong),
                        ],
                      ),
                      Text(
                        '${o.quantity} qty @ ${formatInrAmount(o.orderPriceInr)} · ${o.strategyName}',
                        style: ctx.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                UiTableColumn<DeskOrderApproval>(
                  id: 'trader',
                  label: 'Trader & Division',
                  valueGetter: (o) => '${o.traderName} (@${o.traderHandle})',
                ),
                UiTableColumn<DeskOrderApproval>(
                  id: 'notional',
                  label: 'Notional Value (₹)',
                  numeric: true,
                  sortValue: (o) => o.notionalValueInr,
                  cellBuilder: (BuildContext ctx, DeskOrderApproval o) =>
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            formatInrCompact(o.notionalValueInr),
                            style: ctx.uiText.mono.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${o.leverageX}x leverage',
                            style: ctx.uiText.caption.copyWith(
                              color: theme.colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                ),
                UiTableColumn<DeskOrderApproval>(
                  id: 'reason',
                  label: 'Gate Trigger',
                  flex: 2,
                  valueGetter: (o) => o.reasonFlagged,
                ),
                UiTableColumn<DeskOrderApproval>(
                  id: 'status',
                  label: 'Decision',
                  cellBuilder: (BuildContext ctx, DeskOrderApproval o) =>
                      o.status == 'pending'
                      ? Wrap(
                          spacing: ctx.sp(theme.spacing.xxs),
                          children: <Widget>[
                            UiButton(
                              label: 'Approve',
                              size: UiSize.xs,
                              intent: UiIntent.success,
                              onPressed: () => _reviewOrderDialog(o, true),
                            ),
                            UiButton(
                              label: 'Reject',
                              size: UiSize.xs,
                              variant: UiVariant.outline,
                              intent: UiIntent.danger,
                              onPressed: () => _reviewOrderDialog(o, false),
                            ),
                          ],
                        )
                      : UiBadge(
                          label: o.status.toUpperCase(),
                          intent: o.status == 'approved'
                              ? UiIntent.success
                              : UiIntent.danger,
                          size: UiSize.xs,
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBreachLogSection(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Risk Breach Incident Log (INR)',
      subtitle:
          'Historical and active margin, drawdown, and stop-loss compliance alerts.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiTable<DeskRiskBreach>(
            rows: _breaches,
            rowKey: (b) => b.id,
            stackOnMobile: true,
            columns: <UiTableColumn<DeskRiskBreach>>[
              UiTableColumn<DeskRiskBreach>(
                id: 'breach',
                label: 'Breach Type & Symbol',
                flex: 2,
                cellBuilder: (BuildContext ctx, DeskRiskBreach b) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${b.breachType} (${b.symbol})',
                      style: ctx.uiText.bodyStrong,
                    ),
                    Text(
                      b.description,
                      style: ctx.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              UiTableColumn<DeskRiskBreach>(
                id: 'trader',
                label: 'Trader',
                valueGetter: (b) => '${b.traderName} (@${b.traderHandle})',
              ),
              UiTableColumn<DeskRiskBreach>(
                id: 'exposure',
                label: 'Metric vs Cap (₹)',
                numeric: true,
                cellBuilder: (BuildContext ctx, DeskRiskBreach b) {
                  final double ratio = b.thresholdValueInr > 0
                      ? (b.metricValueInr / b.thresholdValueInr).clamp(0.0, 1.5)
                      : 1.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${formatInrCompact(b.metricValueInr)} / ${formatInrCompact(b.thresholdValueInr)}',
                        style: ctx.uiText.mono.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: ctx.sp(theme.spacing.xxs)),
                      SizedBox(
                        width: 90,
                        height: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: (ratio / 1.5).clamp(0.0, 1.0),
                            backgroundColor: theme.colors.surfaceMuted,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ratio >= 1.0
                                  ? theme.colors.danger
                                  : theme.colors.warning,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              UiTableColumn<DeskRiskBreach>(
                id: 'status',
                label: 'Status',
                cellBuilder: (BuildContext ctx, DeskRiskBreach b) => UiBadge(
                  label: b.status.toUpperCase(),
                  intent: switch (b.status) {
                    'resolved' => UiIntent.success,
                    'trader_frozen' => UiIntent.danger,
                    _ => UiIntent.warning,
                  },
                  size: UiSize.xs,
                ),
              ),
              UiTableColumn<DeskRiskBreach>(
                id: 'action',
                label: 'Action',
                cellBuilder: (BuildContext ctx, DeskRiskBreach b) =>
                    b.status == 'resolved'
                    ? Text(
                        b.resolutionNotes ?? 'Resolved',
                        style: ctx.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      )
                    : Wrap(
                        spacing: ctx.sp(theme.spacing.xxs),
                        children: <Widget>[
                          UiButton(
                            label: 'Freeze Trader',
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            intent: UiIntent.danger,
                            onPressed: () async {
                              await _repo.updateRiskBreachStatus(
                                breachId: b.id,
                                status: 'trader_frozen',
                                freezeTrader: true,
                                resolutionNotes:
                                    'Trader seat frozen by Risk Officer.',
                              );
                              await _load();
                            },
                          ),
                          UiButton(
                            label: 'Resolve',
                            size: UiSize.xs,
                            intent: UiIntent.success,
                            onPressed: () async {
                              await _repo.updateRiskBreachStatus(
                                breachId: b.id,
                                status: 'resolved',
                                resolutionNotes:
                                    'Margin verified and breach resolved.',
                              );
                              await _load();
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
