import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
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
  List<DeskOrderApproval> _orders = const <DeskOrderApproval>[];
  List<DeskRiskBreach> _breaches = const <DeskRiskBreach>[];

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
      setState(() {
        _policy = results[0] as DeskRiskModel;
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
      setState(() => _policy = updated);
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

  Future<void> _reviewOrderDialog(
    DeskOrderApproval order,
    bool approve,
  ) async {
    final TextEditingController notesCtrl = TextEditingController(
      text: approve
          ? 'Approved after verifying SPAN margin and delta hedge.'
          : 'Rejected: Exceeds single-order concentration cap.',
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => UiDialog(
        title: approve
            ? 'Approve Pre-Trade Order?'
            : 'Reject Pre-Trade Order?',
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
            'Configure firm-wide INR drawdown rules, approve high-notional NSE/NFO/MCX orders, and resolve desk risk breaches.',
        leading: Icon(Icons.shield_outlined, color: theme.colors.primary),
        actions: <Widget>[
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
          UiCardGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 4,
            largeColumns: 4,
            childAspectRatio: context.uiRes.isMobile ? 2.3 : 1.9,
            children: <Widget>[
              UiMetricCard(
                label: 'Circuit Breaker Status',
                value: _breakerState.toUpperCase(),
                caption: _breakerState == 'halted'
                    ? 'All non-owner seats frozen'
                    : 'Pre-trade risk engine active',
                icon: Icons.gpp_good_outlined,
                intent: _breakerState == 'halted'
                    ? UiIntent.danger
                    : UiIntent.success,
              ),
              UiMetricCard(
                label: 'Max Intraday Leverage',
                value: '${_policy.maxLeverage.toStringAsFixed(0)}x',
                caption:
                    'Daily Loss Cap: ${_policy.maxDailyLossPercent.toStringAsFixed(1)}%',
                icon: Icons.speed_rounded,
              ),
              UiMetricCard(
                label: 'Pending Order Approvals',
                value: '$pendingCount Flagged',
                caption: '${_orders.length} total pre-trade checks',
                icon: Icons.rule_folder_outlined,
                intent: pendingCount > 0 ? UiIntent.warning : UiIntent.success,
              ),
              UiMetricCard(
                label: 'Active Breach Incidents',
                value: '$openBreachesCount Open',
                caption:
                    'Hard Drawdown Cap: ${_policy.maxTotalDrawdownPercent.toStringAsFixed(1)}%',
                icon: Icons.warning_amber_rounded,
                intent: openBreachesCount > 0
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Institutional Margin & Drawdown Thresholds',
            style: context.uiText.subheading,
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Real-time thresholds enforced across all proprietary trader seats.',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
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
                () => _policy = _policy.copyWith(maxLeverage: v.roundToDouble()),
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
              value: _policy.maxTotalDrawdownPercent.clamp(2.0, 30.0),
              min: 2.0,
              max: 30.0,
              divisions: 28,
              onChanged: (double v) => setState(
                () => _policy = _policy.copyWith(maxTotalDrawdownPercent: v),
              ),
            ),
          ),
        ],
      ),
    );

    final Widget gatesCard = UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Exchange Segment & Execution Gates',
            style: context.uiText.subheading,
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Control permitted asset classes and mandatory order attachments.',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppSettingCard(
            title: 'Mandatory Stop-Loss Attachment',
            description:
                'Reject any trader order submitted without a hard GTT/bracket stop-loss.',
            icon: Icons.shield_moon_outlined,
            control: UiSwitch(
              value: _policy.requireStopLoss,
              onChanged: (bool v) =>
                  setState(() => _policy = _policy.copyWith(requireStopLoss: v)),
            ),
          ),
          AppSettingCard(
            title: 'Auto-Liquidate on Hard Drawdown Breach',
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

    if (context.uiRes.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          slidersCard,
          SizedBox(height: context.sp(theme.spacing.md)),
          gatesCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: slidersCard),
        SizedBox(width: context.sp(theme.spacing.md)),
        Expanded(child: gatesCard),
      ],
    );
  }

  Widget _buildOrderApprovalSection(
    BuildContext context,
    List<DeskOrderApproval> visibleOrders,
  ) {
    final UiTheme theme = context.ui;
    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: context.sp(theme.spacing.md),
            runSpacing: context.sp(theme.spacing.sm),
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Pre-Trade High-Notional Order Approval Queue (INR ₹)',
                    style: context.uiText.subheading,
                  ),
                  Text(
                    'Review and release or block flagged institutional orders before exchange routing.',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
              UiToggleGroup<String>(
                value: _orderFilter,
                options: const <UiToggleOption<String>>[
                  UiToggleOption(value: 'pending', label: 'Pending'),
                  UiToggleOption(value: 'approved', label: 'Approved'),
                  UiToggleOption(value: 'rejected', label: 'Rejected'),
                  UiToggleOption(value: 'all', label: 'All'),
                ],
                onChanged: (String v) => setState(() => _orderFilter = v),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
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
                  cellBuilder: (BuildContext ctx, DeskOrderApproval o) =>
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              UiBadge(
                                label: '${o.side} · ${o.exchange}',
                                intent: o.side == 'BUY'
                                    ? UiIntent.bullish
                                    : UiIntent.bearish,
                                size: UiSize.xs,
                              ),
                              SizedBox(width: ctx.sp(theme.spacing.xs)),
                              Flexible(
                                child: Text(
                                  o.symbol,
                                  style: ctx.uiText.bodyStrong,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Risk Breach Incident Log (INR)',
            style: context.uiText.subheading,
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Historical and active margin, drawdown, and stop-loss compliance alerts.',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
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
                valueGetter: (b) =>
                    '${formatInrCompact(b.metricValueInr)} / ${formatInrCompact(b.thresholdValueInr)}',
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
