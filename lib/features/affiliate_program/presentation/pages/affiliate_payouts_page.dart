import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:tradex/features/affiliate_program/presentation/widgets/affiliate_workspace_view.dart';

class AffiliatePayoutsPage extends StatefulWidget {
  const AffiliatePayoutsPage({
    super.key,
    this.onNavigate,
    this.onSwitchToTraderView,
    this.onOpenReferrals,
    this.onOpenSettings,
    this.repository,
  });

  final ValueChanged<String>? onNavigate;
  final VoidCallback? onSwitchToTraderView;
  final VoidCallback? onOpenReferrals;
  final VoidCallback? onOpenSettings;
  final AffiliateWorkspaceRepository? repository;

  @override
  State<AffiliatePayoutsPage> createState() => _AffiliatePayoutsPageState();
}

class _AffiliatePayoutsPageState extends State<AffiliatePayoutsPage> {
  late final AffiliateWorkspaceRepository _repo =
      widget.repository ?? AffiliateWorkspaceRepository();
  String _amount = '', _status = 'all';
  String? _error;
  bool _submitting = false;

  void _confirmRequest(
    BuildContext context,
    AffiliateWorkspace w,
    VoidCallback reload,
  ) {
    final parsed = double.tryParse(_amount.trim());
    final rawMin = w.profile.number('minimum_payout_threshold');
    final min = rawMin < 1000 ? 1000.0 : rawMin;
    final balance = w.profile.number('unpaid_balance');
    if (parsed == null || parsed < min || parsed > balance) {
      setState(
        () => _error =
            'Enter an INR amount between ${w.money(min)} and ${w.money(balance)}.',
      );
      return;
    }
    if (w.payoutAccount.isEmpty) {
      setState(
        () => _error =
            'Save an Indian UPI VPA or Bank NEFT/IMPS account in Payment settings first.',
      );
      return;
    }

    final double tds = w.tdsAmountFor(parsed);
    final double gst = w.gstAmountFor(parsed);
    final double net = w.netPayoutFor(parsed);

    UiDialog.show<void>(
      context,
      child: Builder(
        builder: (ctx) => UiDialog(
          title: 'Confirm payout request',
          content: UiKeyValueTable(
            rows: [
              UiKeyValueRow(
                label: 'Gross Request Amount (INR)',
                value: Text(w.money(parsed), style: ctx.uiText.mono),
              ),
              UiKeyValueRow(
                label: 'Statutory TDS (${(w.tdsRate * 100).toStringAsFixed(0)}% u/s 194H)',
                value: Text('- ${w.money(tds)}', style: ctx.uiText.mono),
              ),
              if (gst > 0)
                UiKeyValueRow(
                  label: 'GST Input Credit (18% GSTIN)',
                  value: Text('+ ${w.money(gst)}', style: ctx.uiText.mono),
                ),
              UiKeyValueRow(
                label: 'Estimated Net Bank/UPI Credit',
                value: Text(
                  w.money(net),
                  style: ctx.uiText.mono.copyWith(
                    color: ctx.ui.colors.bullish,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              UiKeyValueRow(
                label: 'Settlement Rail',
                value: Text(w.payoutMethod.toUpperCase()),
              ),
              UiKeyValueRow(
                label: 'Destination',
                value: Text(w.payoutAccount),
              ),
              if (w.panNumber.isNotEmpty)
                UiKeyValueRow(
                  label: 'Verified PAN',
                  value: Text(w.panNumber, style: ctx.uiText.mono),
                ),
            ],
          ),
          actions: [
            UiButton(
              label: 'Cancel',
              variant: UiVariant.outline,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            UiButton(
              label: 'Confirm request',
              intent: UiIntent.primary,
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _submit(parsed, reload);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(double amount, VoidCallback reload) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repo.requestPayout(amount);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _amount = '';
      });
      reload();
      UiToast.show(
        context,
        title: 'INR Payout Requested',
        message: 'Funds are reserved in INR while the settlement desk processes your transfer.',
        intent: UiIntent.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst(RegExp(r'^.*?: '), '');
      });
    }
  }

  void _showStatement(
    BuildContext context,
    AffiliateWorkspace w,
    AffiliateRecord p,
  ) {
    final dest = p.map('payout_destination');
    final account =
        dest['payout_account']?.toString() ??
        dest['upi_id']?.toString() ??
        dest['account_number']?.toString() ??
        w.payoutAccount;
    final double gross = p.number('gross_amount_inr') > 0
        ? p.number('gross_amount_inr')
        : p.number('amount');
    final double tds = p.number('tds_amount_inr') > 0
        ? p.number('tds_amount_inr')
        : w.tdsAmountFor(gross);
    final double gst = p.number('gst_amount_inr');
    final double net = p.number('net_amount_inr') > 0
        ? p.number('net_amount_inr')
        : (gross - tds + gst);

    final statement =
        'Payout ID: ${p.id}\n'
        'Currency: INR (₹)\n'
        'Gross Amount: ${w.money(gross)}\n'
        'TDS Deducted (u/s 194H): ${w.money(tds)}\n'
        'GST Added: ${w.money(gst)}\n'
        'Net Disbursed: ${w.money(net)}\n'
        'Status: ${p.text('status')}\n'
        'Rail: ${p.text('payout_method')}\n'
        'Destination: $account\n'
        'UTR / Reference: ${p.text('transaction_reference', 'Pending')}\n'
        'Requested: ${p.text('created_at').split('T').first}';
    UiDialog.show<void>(
      context,
      child: Builder(
        builder: (ctx) => UiDialog(
          title: 'INR Payout Statement · ${p.id}',
          content: SelectableText(statement, style: ctx.uiText.mono),
          actions: [
            UiButton(
              label: 'Copy Statement',
              variant: UiVariant.outline,
              onPressed: () =>
                  copyAffiliateText(ctx, 'Payout statement', statement),
            ),
            UiButton(label: 'Close', onPressed: () => Navigator.of(ctx).pop()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AffiliateWorkspaceView(
      title: 'INR Payouts & Tax Statements (₹)',
      subtitle:
          'Request NPCI UPI or Bank NEFT/IMPS settlements in Indian Rupees (₹) and download Form 16A TDS / GST statements.',
      repository: _repo,
      onNavigate: widget.onNavigate,
      actions: (_, _, _) => [
        if (widget.onSwitchToTraderView != null)
          UiButton(
            label: 'Trader View',
            leadingIcon: Icons.candlestick_chart_rounded,
            size: UiSize.sm,
            variant: UiVariant.secondary,
            onPressed: widget.onSwitchToTraderView,
          ),
        UiButton(
          label: 'Payment settings',
          leadingIcon: Icons.tune_rounded,
          size: UiSize.sm,
          variant: UiVariant.outline,
          onPressed: () => widget.onNavigate?.call('settings_affiliate'),
        ),
      ],
      builder: (context, w, reload) {
        final p = w.profile;
        final balance = p.number('unpaid_balance');
        final rawMin = p.number('minimum_payout_threshold');
        final min = rawMin < 1000 ? 1000.0 : rawMin;
        final rows = w.payouts
            .where((row) => _status == 'all' || row.text('status') == _status)
            .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiCardGrid(
              minTileWidth: 210,
              children: [
                UiMetricCard(
                  label: 'Available Balance (INR)',
                  value: w.money(balance),
                  caption: 'Minimum withdrawal: ${w.money(min)}',
                  icon: Icons.account_balance_wallet_outlined,
                  intent: UiIntent.bullish,
                ),
                UiMetricCard(
                  label: 'Total Settled (INR)',
                  value: w.money(p.number('paid_earnings')),
                  caption: '${w.payouts.length} payout records',
                  icon: Icons.currency_rupee_rounded,
                ),
                UiMetricCard(
                  label: 'Indian Payout Rail',
                  value: w.payoutMethod.toUpperCase(),
                  caption: w.payoutAccount.isEmpty
                      ? 'Not configured'
                      : w.payoutAccount,
                  icon: Icons.account_balance_outlined,
                ),
                UiMetricCard(
                  label: 'Tax & Auto-Payout',
                  value: p.flag('auto_payout_enabled')
                      ? 'Auto · 5% TDS'
                      : 'Manual · 5% TDS',
                  caption: w.panNumber.isNotEmpty
                      ? 'PAN: ${w.panNumber}'
                      : 'Add PAN in settings',
                  icon: Icons.receipt_long_outlined,
                ),
              ],
            ),
            UiGap.v(context.ui.spacing.lg),
            UiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Request an INR Payout', style: context.uiText.heading),
                  UiGap.v(context.ui.spacing.sm),
                  if (_error != null) ...[
                    UiCallout(
                      title: 'Payout request blocked',
                      message: _error,
                      intent: UiIntent.warning,
                    ),
                    UiGap.v(context.ui.spacing.sm),
                  ],
                  if (w.hasOpenPayout)
                    const UiCallout(
                      title: 'A payout is in progress',
                      message:
                          'Another withdrawal can be requested after the open settlement completes.',
                      intent: UiIntent.info,
                    )
                  else
                    Wrap(
                      spacing: context.sp(context.ui.spacing.sm),
                      runSpacing: context.sp(context.ui.spacing.sm),
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: UiField(
                            label: 'Withdrawal Amount (INR ₹)',
                            helper:
                                'Min ${w.money(min)} · Net after 5% TDS credited to ${w.payoutMethod.toUpperCase()}',
                            child: UiInput(
                              value: _amount,
                              hintText: balance >= min
                                  ? balance.toStringAsFixed(0)
                                  : min.toStringAsFixed(0),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (v) => setState(() => _amount = v),
                            ),
                          ),
                        ),
                        UiButton(
                          label: 'Withdraw Full Balance',
                          variant: UiVariant.outline,
                          onPressed: balance >= min
                              ? () => setState(
                                  () => _amount = balance.toStringAsFixed(0),
                                )
                              : null,
                        ),
                        UiButton(
                          label: 'Review payout request',
                          leadingIcon: Icons.send_rounded,
                          intent: UiIntent.primary,
                          loading: _submitting,
                          onPressed: balance < min
                              ? null
                              : () => _confirmRequest(context, w, reload.call),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            UiGap.v(context.ui.spacing.lg),
            UiCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: context.sp(context.ui.spacing.sm),
                      runSpacing: context.sp(context.ui.spacing.sm),
                      children: [
                        Text('INR Payout History', style: context.uiText.heading),
                        UiToggleGroup<String>(
                          size: UiSize.sm,
                          value: _status,
                          onChanged: (v) => setState(() => _status = v),
                          options: const [
                            UiOption(value: 'all', label: 'All'),
                            UiOption(value: 'pending', label: 'Pending'),
                            UiOption(value: 'paid', label: 'Paid'),
                            UiOption(value: 'failed', label: 'Failed'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  UiTable<AffiliateRecord>(
                    rows: rows,
                    rowKey: (row) => row.id,
                    stackOnMobile: true,
                    onRowTap: (row) => _showStatement(context, w, row),
                    emptyLabel: 'No payouts match this filter.',
                    columns: [
                      UiTableColumn<AffiliateRecord>(
                        id: 'date',
                        label: 'Requested',
                        cellBuilder: (ctx, r) => Text(
                          r.text('created_at').split('T').first,
                          style: ctx.uiText.mono,
                        ),
                      ),
                      UiTableColumn<AffiliateRecord>(
                        id: 'method',
                        label: 'Rail & UTR Reference',
                        cellBuilder: (ctx, r) => Text(
                          '${r.text('payout_method').toUpperCase()} · ${r.text('transaction_reference', 'Awaiting UTR')}',
                        ),
                      ),
                      UiTableColumn<AffiliateRecord>(
                        id: 'status',
                        label: 'Status',
                        cellBuilder: (_, r) => UiBadge(
                          label: r.text('status').toUpperCase(),
                          intent: r.text('status') == 'paid'
                              ? UiIntent.bullish
                              : r.text('status') == 'pending' ||
                                    r.text('status') == 'processing'
                              ? UiIntent.warning
                              : UiIntent.danger,
                        ),
                      ),
                      UiTableColumn<AffiliateRecord>(
                        id: 'amount',
                        label: 'Gross / Net (₹)',
                        numeric: true,
                        cellBuilder: (ctx, r) {
                          final double gross = r.number('amount');
                          final double net = r.number('net_amount_inr') > 0
                              ? r.number('net_amount_inr')
                              : w.netPayoutFor(gross);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(w.money(gross), style: ctx.uiText.mono),
                              Text(
                                'Net: ${w.money(net)}',
                                style: ctx.uiText.caption.copyWith(
                                  color: ctx.ui.colors.bullish,
                                ),
                              ),
                            ],
                          );
                        },
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
  }
}
