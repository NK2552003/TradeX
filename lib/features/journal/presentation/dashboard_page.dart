import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_limitations.dart';
import 'package:tradex/features/journal/data/supabase_trade_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.repository});

  final SupabaseTradeRepository? repository;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final SupabaseTradeRepository _repo;
  bool _loading = true;
  Map<String, dynamic>? _stats;
  List<AppTrade> _recentTrades = [];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? SupabaseTradeRepositoryImpl();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final stats = await _repo.getPortfolioStats();
      final trades = await _repo.getEntries();
      if (mounted) {
        setState(() {
          _stats = stats;
          _recentTrades = trades.take(5).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('DashboardPage error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    if (_loading) {
      return UiSkeleton.dashboard();
    }

    final totalPnlVal = (_stats?['total_pnl'] as num?)?.toDouble() ?? 0.0;
    final winRateVal = (_stats?['win_rate_percent'] as num?)?.toDouble() ?? 0.0;
    final avgRrVal = (_stats?['avg_rr'] as num?)?.toDouble() ?? 0.0;
    final bestTradeVal = (_stats?['best_trade_pnl'] as num?)?.toDouble() ?? 0.0;

    return AppPageBlock(
      title: 'Executive Dashboard',
      subtitle:
          'Portfolio equity, daily PnL performance, and key trading metrics',
      actions: [
        UiButton(
          label: 'Export Report',
          leadingIcon: Icons.download_outlined,
          variant: UiVariant.outline,
          size: UiSize.sm,
          onPressed: () async {
            final allowed = await CustomerLimitations.checkCanExportPdf(
              context,
              featureLabel: 'Performance Report Export',
            );
            if (!allowed || !context.mounted) return;
            UiToast.show(
              context,
              title: 'Export Started',
              message: 'Generating PDF performance report...',
              intent: UiIntent.info,
            );
          },
        ),
      ],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppStatGridBlock(
              stats: [
                AppStat(
                  label: 'Net Profit',
                  value: totalPnlVal,
                  delta: 0.0,
                  suffix: '\$',
                ),
                AppStat(
                  label: 'Win Rate',
                  value: winRateVal,
                  delta: 0.0,
                  suffix: '%',
                ),
                AppStat(label: 'Avg R:R', value: avgRrVal, delta: 0.0),
                AppStat(
                  label: 'Best Trade',
                  value: bestTradeVal,
                  delta: 0.0,
                  suffix: '\$',
                ),
              ],
            ),
            UiGap.v(context.sp(theme.spacing.xl)),
            AppRecentTradesBlock(trades: _recentTrades),
          ],
        ),
      ),
    );
  }
}
