import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:tradex/features/affiliate_program/presentation/widgets/affiliate_workspace_view.dart';

export 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart'
    show referralCsv;

class AffiliateReferralsPage extends StatefulWidget {
  const AffiliateReferralsPage({
    super.key,
    this.onNavigate,
    this.onSwitchToTraderView,
    this.onOpenPayouts,
    this.onOpenMarketing,
    this.repository,
  });

  final ValueChanged<String>? onNavigate;
  final VoidCallback? onSwitchToTraderView;
  final VoidCallback? onOpenPayouts;
  final VoidCallback? onOpenMarketing;
  final AffiliateWorkspaceRepository? repository;

  @override
  State<AffiliateReferralsPage> createState() => _AffiliateReferralsPageState();
}

class _AffiliateReferralsPageState extends State<AffiliateReferralsPage> {
  static const _pageSize = 6;
  String _query = '', _status = 'all', _sortId = 'date';
  bool _asc = false;
  int _page = 1;

  List<AffiliateRecord> _sorted(List<AffiliateRecord> rows) {
    final copy = [...rows];
    int cmp(AffiliateRecord a, AffiliateRecord b) => switch (_sortId) {
      'id' => a.id.compareTo(b.id),
      'channel' => a.text('channel').compareTo(b.text('channel')),
      'status' => a.text('status').compareTo(b.text('status')),
      'bonus' => a.number('bonus_awarded').compareTo(b.number('bonus_awarded')),
      _ => a.text('created_at').compareTo(b.text('created_at')),
    };
    copy.sort((a, b) => _asc ? cmp(a, b) : cmp(b, a));
    return copy;
  }

  void _showReferral(
    BuildContext context,
    AffiliateWorkspace w,
    AffiliateRecord r,
  ) {
    final double gross = r.number('bonus_awarded');
    final double tds = r.number('tds_deducted_inr') > 0
        ? r.number('tds_deducted_inr')
        : (gross > 0 ? w.tdsAmountFor(gross) : 0.0);
    final double net = r.number('net_commission_inr') > 0
        ? r.number('net_commission_inr')
        : (gross - tds);

    UiDialog.show<void>(
      context,
      child: Builder(
        builder: (ctx) => UiDialog(
          title: 'Referral Attribution ${r.id}',
          content: UiKeyValueTable(
            rows: [
              UiKeyValueRow(
                label: 'Referral Code / Slug',
                value: Text(r.text('referral_code')),
              ),
              UiKeyValueRow(
                label: 'Attribution Channel',
                value: Text(r.text('channel', 'direct').toUpperCase()),
              ),
              UiKeyValueRow(
                label: 'Subscribed Plan (INR)',
                value: Text(
                  '${r.text('plan_tier', 'pro').toUpperCase()} (${w.money(r.number('subscription_amount_inr') > 0 ? r.number('subscription_amount_inr') : 2499)}/mo)',
                ),
              ),
              UiKeyValueRow(
                label: 'Status',
                value: Text(r.text('status').toUpperCase()),
              ),
              UiKeyValueRow(
                label: 'Gross Commission (INR)',
                value: Text(w.money(gross), style: ctx.uiText.mono),
              ),
              UiKeyValueRow(
                label: 'TDS Deducted (5% u/s 194H)',
                value: Text(w.money(tds), style: ctx.uiText.mono),
              ),
              UiKeyValueRow(
                label: 'Net Credited to Balance (INR)',
                value: Text(
                  w.money(net),
                  style: ctx.uiText.mono.copyWith(
                    color: ctx.ui.colors.bullish,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              UiKeyValueRow(
                label: 'Recorded At',
                value: Text(r.text('created_at').split('T').first),
              ),
            ],
          ),
          actions: [
            UiButton(
              label: 'Copy ID',
              variant: UiVariant.outline,
              onPressed: () => copyAffiliateText(ctx, 'Referral ID', r.id),
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
      title: 'Referrals & INR Attribution',
      subtitle:
          'Monitor attributed signups, qualifying Pro/Enterprise INR subscriptions, and net commissions after 5% TDS.',
      repository: widget.repository,
      onNavigate: widget.onNavigate,
      actions: (ctx, w, _) {
        final rows = _sorted(w.filterReferrals(_query, _status));
        return [
          if (widget.onSwitchToTraderView != null)
            UiButton(
              label: 'Trader View',
              leadingIcon: Icons.candlestick_chart_rounded,
              size: UiSize.sm,
              variant: UiVariant.secondary,
              onPressed: widget.onSwitchToTraderView,
            ),
          UiButton(
            label: 'Copy CSV (INR)',
            leadingIcon: Icons.table_view_outlined,
            size: UiSize.sm,
            variant: UiVariant.outline,
            onPressed: rows.isEmpty
                ? null
                : () => copyAffiliateText(
                    ctx,
                    'Referral CSV',
                    referralCsv(rows, w.currency),
                  ),
          ),
        ];
      },
      builder: (context, w, _) {
        final filtered = _sorted(w.filterReferrals(_query, _status));
        final pages = math.max(1, (filtered.length / _pageSize).ceil());
        final page = _page.clamp(1, pages);
        final slice = filtered
            .skip((page - 1) * _pageSize)
            .take(_pageSize)
            .toList();
        final earned = filtered.fold<double>(
          0,
          (s, r) => s + r.number('bonus_awarded'),
        );
        final netEarned = filtered.fold<double>(
          0,
          (s, r) =>
              s +
              (r.number('net_commission_inr') > 0
                  ? r.number('net_commission_inr')
                  : w.netPayoutFor(r.number('bonus_awarded'))),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiCardGrid(
              equalHeight: true,
              minTileWidth: 210,
              children: [
                UiMetricCard(
                  label: 'Matching Referrals',
                  value: '${filtered.length}',
                  caption: 'Of ${w.referrals.length} total signups',
                  icon: Icons.group_outlined,
                ),
                UiMetricCard(
                  label: 'Converted Subscribers',
                  value:
                      '${filtered.where((r) => r.text('status') == 'converted').length}',
                  caption:
                      '${w.conversionRate.toStringAsFixed(1)}% conversion rate',
                  icon: Icons.verified_outlined,
                  intent: UiIntent.bullish,
                ),
                UiMetricCard(
                  label: 'Pending Qualification',
                  value:
                      '${filtered.where((r) => r.text('status') == 'pending').length}',
                  caption: 'Awaiting billing qualification',
                  icon: Icons.schedule_rounded,
                  intent: UiIntent.warning,
                ),
                UiMetricCard(
                  label: 'Filtered Commission (INR)',
                  value: w.money(earned),
                  caption: 'Net after 5% TDS: ${w.money(netEarned)}',
                  icon: Icons.currency_rupee_rounded,
                  intent: UiIntent.primary,
                ),
              ],
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
                      spacing: context.sp(context.ui.spacing.sm),
                      runSpacing: context.sp(context.ui.spacing.sm),
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: UiInput.search(
                            value: _query,
                            hintText: 'Search ID, channel, plan or status...',
                            onChanged: (v) => setState(() {
                              _query = v;
                              _page = 1;
                            }),
                          ),
                        ),
                        UiToggleGroup<String>(
                          size: UiSize.sm,
                          value: _status,
                          onChanged: (v) => setState(() {
                            _status = v;
                            _page = 1;
                          }),
                          options: const [
                            UiOption(value: 'all', label: 'All'),
                            UiOption(value: 'converted', label: 'Converted'),
                            UiOption(value: 'pending', label: 'Pending'),
                            UiOption(value: 'churned', label: 'Churned'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  UiTable<AffiliateRecord>(
                    rows: slice,
                    rowKey: (r) => r.id,
                    stackOnMobile: true,
                    sortColumnId: _sortId,
                    sortAscending: _asc,
                    onSort: (colIndex, asc) => setState(() {
                      const ids = <String>[
                        'id',
                        'channel',
                        'status',
                        'bonus',
                        'date',
                      ];
                      if (colIndex >= 0 && colIndex < ids.length) {
                        _sortId = ids[colIndex];
                      }
                      _asc = asc;
                    }),
                    onRowTap: (r) => _showReferral(context, w, r),
                    emptyLabel:
                        'No matching referrals. Try another search or share a campaign.',
                    columns: [
                      UiTableColumn<AffiliateRecord>(
                        id: 'id',
                        label: 'Referral ID',
                        sortable: true,
                        cellBuilder: (ctx, r) =>
                            Text(r.id, style: ctx.uiText.mono),
                      ),
                      UiTableColumn<AffiliateRecord>(
                        id: 'channel',
                        label: 'Channel & Plan',
                        sortable: true,
                        cellBuilder: (ctx, r) => Text(
                          '${r.text('channel', 'direct').toUpperCase()} · ${r.text('plan_tier', 'pro').toUpperCase()}',
                        ),
                      ),
                      UiTableColumn<AffiliateRecord>(
                        id: 'status',
                        label: 'Status',
                        sortable: true,
                        cellBuilder: (_, r) => UiBadge(
                          label: r.text('status').toUpperCase(),
                          intent: r.text('status') == 'converted'
                              ? UiIntent.bullish
                              : r.text('status') == 'pending'
                              ? UiIntent.warning
                              : UiIntent.neutral,
                        ),
                      ),
                      UiTableColumn<AffiliateRecord>(
                        id: 'bonus',
                        label: 'Gross Commission (₹)',
                        numeric: true,
                        sortable: true,
                        cellBuilder: (ctx, r) => Text(
                          w.money(r.number('bonus_awarded')),
                          style: ctx.uiText.mono,
                        ),
                      ),
                      UiTableColumn<AffiliateRecord>(
                        id: 'date',
                        label: 'Date',
                        sortable: true,
                        cellBuilder: (ctx, r) => Text(
                          r.text('created_at').split('T').first,
                          style: ctx.uiText.mono,
                        ),
                      ),
                    ],
                  ),
                  if (pages > 1)
                    Padding(
                      padding: EdgeInsets.all(
                        context.sp(context.ui.spacing.md),
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: UiPagination(
                          page: page,
                          totalPages: pages,
                          onChanged: (next) => setState(() => _page = next),
                        ),
                      ),
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
