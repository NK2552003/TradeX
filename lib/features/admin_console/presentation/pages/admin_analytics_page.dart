import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/admin_console/models/admin_console_models.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  final AdminConsoleRepository _repo = AdminConsoleRepository.instance;

  bool _loading = true;
  String _timeframe = '1M';
  AdminDeskAnalyticsSnapshot? _snapshot;
  List<AdminTraderSeat> _seats = const <AdminTraderSeat>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _repo.getAnalyticsSnapshot(_timeframe),
        _repo.listTraderSeats(),
      ]);
      if (!mounted) return;
      setState(() {
        _snapshot = results[0] as AdminDeskAnalyticsSnapshot;
        _seats = results[1] as List<AdminTraderSeat>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onTimeframeChanged(String value) async {
    setState(() => _timeframe = value);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    if (_loading || _snapshot == null) {
      return UiSkeleton.dashboard();
    }
    final AdminDeskAnalyticsSnapshot snap = _snapshot!;

    return UiPage(
      maxWidth: 1440,
      header: UiHeader(
        title: 'Organization & Desk Analytics (INR ₹)',
        subtitle:
            'Firm-wide P&L attribution, Sharpe ratio scorecards, division margin efficiency, and INR subscription + affiliate revenue.',
        leading: Icon(Icons.analytics_outlined, color: theme.colors.primary),
        actions: <Widget>[
          UiToggleGroup<String>(
            value: _timeframe,
            size: UiSize.sm,
            options: const <UiToggleOption<String>>[
              UiToggleOption(value: '1W', label: '1W'),
              UiToggleOption(value: '1M', label: '1M'),
              UiToggleOption(value: '3M', label: '3M'),
              UiToggleOption(value: '6M', label: '6M'),
              UiToggleOption(value: '1Y', label: '1Y'),
              UiToggleOption(value: 'ALL', label: 'ALL'),
            ],
            onChanged: _onTimeframeChanged,
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
            childAspectRatio: context.uiRes.isMobile ? 2.3 : 1.85,
            children: <Widget>[
              UiMetricCard(
                label: '$_timeframe Net Desk P&L',
                value: formatInrCompact(snap.periodNetPnlInr, signed: true),
                caption:
                    'Intraday: ${formatInrCompact(snap.intradayPnlInr, signed: true)}',
                delta: 16.8,
                icon: Icons.currency_rupee_rounded,
                sparkline: snap.points.map((p) => p.deskPnlInr).toList(),
              ),
              UiMetricCard(
                label: 'Firm Sharpe & Win Rate',
                value:
                    '${snap.firmSharpeRatio.toStringAsFixed(2)} · ${snap.firmWinRatePct.toStringAsFixed(1)}%',
                caption:
                    'Profit Factor: ${snap.profitFactor.toStringAsFixed(2)} · Max DD: ${snap.maxDrawdownPct.toStringAsFixed(2)}%',
                delta: 4.5,
                icon: Icons.insights_rounded,
              ),
              UiMetricCard(
                label: 'Consumer Subscription MRR',
                value: '${formatInrAmount(snap.subscriptionMrrInr)}/mo',
                caption:
                    'Annualized Run Rate: ${formatInrCompact(snap.subscriptionMrrInr * 12)}',
                delta: 11.2,
                icon: Icons.workspace_premium_outlined,
              ),
              UiMetricCard(
                label: 'Affiliate Partner ARR (INR)',
                value: formatInrCompact(snap.affiliateGeneratedArrInr),
                caption:
                    'Settled INR Payouts: ${formatInrAmount(snap.affiliatePayoutsSettledInr)}',
                delta: 22.4,
                icon: Icons.handshake_outlined,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Charts Row: Desk P&L vs Benchmark & Platform Revenue Funnel
          _buildChartsRow(context, snap),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Division Attribution Row
          _buildDivisionAttributionRow(context, snap),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Trader Scorecard Table
          _buildTraderScorecardTable(context),
        ],
      ),
    );
  }

  Widget _buildChartsRow(
    BuildContext context,
    AdminDeskAnalyticsSnapshot snap,
  ) {
    final UiTheme theme = context.ui;

    final Widget pnlCard = UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Institutional Desk Alpha vs NIFTY 50 Benchmark ($_timeframe · INR ₹)',
            style: context.uiText.subheading,
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Net realized + mark-to-market desk gains across NSE/BSE/NFO/MCX',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiAreaChart(
            height: 240,
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
                name: 'Desk P&L (₹)',
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

    final Widget revenueCard = UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Consumer & Affiliate SaaS Revenue (INR ₹)',
            style: context.uiText.subheading,
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Combined Pro (₹2,499/mo) & Enterprise (₹7,999/mo) collections',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiBarChart(
            height: 240,
            valueFormatter: (num v) => formatInrCompact(v),
            data: snap.points
                .map(
                  (p) => UiChartPoint(
                    label: p.label,
                    values: <double>[
                      p.revenueInr,
                    ],
                  ),
                )
                .toList(),
            series: <UiChartSeries>[
              UiChartSeries(
                name: 'Platform Revenue (₹)',
                color: theme.colors.bullish,
              ),
            ],
          ),
        ],
      ),
    );

    if (context.uiRes.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          pnlCard,
          SizedBox(height: context.sp(theme.spacing.md)),
          revenueCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 3, child: pnlCard),
        SizedBox(width: context.sp(theme.spacing.md)),
        Expanded(flex: 2, child: revenueCard),
      ],
    );
  }

  Widget _buildDivisionAttributionRow(
    BuildContext context,
    AdminDeskAnalyticsSnapshot snap,
  ) {
    final UiTheme theme = context.ui;

    final Widget barListCard = UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Net P&L Contribution by Desk Division (INR ₹)',
            style: context.uiText.subheading,
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Ranked performance across NSE NFO, Cash Momentum, Quant Arb, and MCX',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiBarList(
            valueFormatter: (num v) => formatInrCompact(v, signed: true),
            items: snap.divisions
                .map(
                  (d) => UiBarListItem(
                    label:
                        '${d.divisionName} · Sharpe ${d.sharpeRatio.toStringAsFixed(2)} (${d.winRatePct.toStringAsFixed(1)}% win)',
                    value: d.periodNetPnlInr,
                    icon: Icons.assessment_outlined,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );

    final Widget donutCard = UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Deployed Capital Share (INR)',
            style: context.uiText.subheading,
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Margin allocation across desk divisions',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
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

    if (context.uiRes.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          barListCard,
          SizedBox(height: context.sp(theme.spacing.md)),
          donutCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 3, child: barListCard),
        SizedBox(width: context.sp(theme.spacing.md)),
        Expanded(flex: 2, child: donutCard),
      ],
    );
  }

  Widget _buildTraderScorecardTable(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AdminTraderSeat> sorted = List<AdminTraderSeat>.from(_seats)
      ..sort((a, b) => b.monthlyPnlInr.compareTo(a.monthlyPnlInr));

    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Proprietary Trader Scorecard Leaderboard (INR ₹)',
            style: context.uiText.subheading,
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Risk-adjusted return metrics, capital utilization, and drawdown discipline per seat',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiTable<AdminTraderSeat>(
            rows: sorted,
            rowKey: (s) => s.userId,
            stackOnMobile: true,
            columns: <UiTableColumn<AdminTraderSeat>>[
              UiTableColumn<AdminTraderSeat>(
                id: 'trader',
                label: 'Trader',
                flex: 2,
                valueGetter: (s) => '${s.displayName} (@${s.handle})',
              ),
              UiTableColumn<AdminTraderSeat>(
                id: 'division',
                label: 'Desk Division',
                valueGetter: (s) => s.deskDivision,
              ),
              UiTableColumn<AdminTraderSeat>(
                id: 'capital',
                label: 'Allocated Capital (₹)',
                numeric: true,
                sortValue: (s) => s.allocatedCapitalInr,
                valueGetter: (s) => formatInrCompact(s.allocatedCapitalInr),
              ),
              UiTableColumn<AdminTraderSeat>(
                id: 'intraday',
                label: 'Intraday P&L (₹)',
                numeric: true,
                sortValue: (s) => s.dailyPnlInr,
                cellBuilder: (BuildContext ctx, AdminTraderSeat s) => Text(
                  formatInrCompact(s.dailyPnlInr, signed: true),
                  style: ctx.uiText.mono.copyWith(
                    color: s.dailyPnlInr >= 0
                        ? theme.colors.bullish
                        : theme.colors.bearish,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              UiTableColumn<AdminTraderSeat>(
                id: 'monthly',
                label: '30D Net P&L (₹)',
                numeric: true,
                sortValue: (s) => s.monthlyPnlInr,
                cellBuilder: (BuildContext ctx, AdminTraderSeat s) => Text(
                  formatInrCompact(s.monthlyPnlInr, signed: true),
                  style: ctx.uiText.mono.copyWith(
                    color: s.monthlyPnlInr >= 0
                        ? theme.colors.bullish
                        : theme.colors.bearish,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              UiTableColumn<AdminTraderSeat>(
                id: 'sharpe',
                label: 'Sharpe · Win %',
                numeric: true,
                sortValue: (s) => s.sharpeRatio,
                valueGetter: (s) =>
                    '${s.sharpeRatio.toStringAsFixed(2)} · ${s.winRatePct.toStringAsFixed(1)}%',
              ),
              UiTableColumn<AdminTraderSeat>(
                id: 'drawdown',
                label: 'Max DD / Cap',
                numeric: true,
                sortValue: (s) => s.currentDrawdownPct,
                cellBuilder: (BuildContext ctx, AdminTraderSeat s) => UiBadge(
                  label:
                      '${s.currentDrawdownPct.toStringAsFixed(1)}% / ${s.maxDrawdownLimitPct.toStringAsFixed(1)}%',
                  intent: s.isDrawdownNearLimit
                      ? UiIntent.danger
                      : UiIntent.success,
                  size: UiSize.xs,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
