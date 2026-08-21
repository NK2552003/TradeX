import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// Everything the trader dashboard renders in a single fetch so the page never
/// juggles partial states.
@immutable
class TraderDashboardSnapshot {
  const TraderDashboardSnapshot({
    required this.stats,
    required this.equity,
    required this.days,
    required this.openTrades,
    required this.recentTrades,
    required this.movers,
    required this.insights,
    required this.news,
    required this.checklist,
    required this.dailyLossUsedPercent,
  });

  final List<AppStat> stats;
  final List<AppSeriesPoint> equity;
  final List<AppDayPnl> days;
  final List<AppTrade> openTrades;
  final List<AppTrade> recentTrades;
  final List<AppTicker> movers;
  final List<AppAiInsight> insights;
  final List<AppNewsItem> news;
  final List<AppChecklistItem> checklist;
  final double dailyLossUsedPercent;
}

abstract class DashboardRepository {
  Future<TraderDashboardSnapshot> getTraderSnapshot();
  Future<void> toggleChecklistItem(String id);
}

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({DemoDataSource? source})
    : _source = source ?? DemoDataSource.instance {
    _checklist = List<AppChecklistItem>.from(_source.checklist());
  }

  final DemoDataSource _source;
  late List<AppChecklistItem> _checklist;

  @override
  Future<void> toggleChecklistItem(String id) async {
    _checklist = _checklist
        .map(
          (AppChecklistItem item) => item.id == id
              ? AppChecklistItem(
                  id: item.id,
                  label: item.label,
                  description: item.description,
                  icon: item.icon,
                  done: !item.done,
                )
              : item,
        )
        .toList();
  }

  @override
  Future<TraderDashboardSnapshot> getTraderSnapshot() async {
    await Future<void>.delayed(const Duration(milliseconds: 260));

    final List<AppTrade> trades = _source.trades();
    final List<AppTrade> closed = trades
        .where((AppTrade t) => t.outcome != AppOutcome.open)
        .toList(growable: false);
    final List<AppTrade> open = trades
        .where((AppTrade t) => t.outcome == AppOutcome.open)
        .toList(growable: false);

    final double netPnl = closed.fold<double>(
      0,
      (double sum, AppTrade t) => sum + t.pnl,
    );
    final int wins = closed
        .where((AppTrade t) => t.outcome == AppOutcome.win)
        .length;
    final double winRate = closed.isEmpty ? 0 : (wins / closed.length) * 100;
    final double avgR = closed.isEmpty
        ? 0
        : closed.fold<double>(
                0,
                (double sum, AppTrade t) => sum + (t.rMultiple ?? 0),
              ) /
              closed.length;
    final List<AppDayPnl> days = _source.dayPnl();
    final double todayPnl = days.isEmpty ? 0 : days.last.pnl;

    return TraderDashboardSnapshot(
      stats: <AppStat>[
        AppStat(
          label: 'Net P/L',
          value: netPnl,
          delta: todayPnl,
          icon: Icons.account_balance_wallet_outlined,
          spark: _source
              .equitySeries(points: 14)
              .map((AppSeriesPoint p) => p.value)
              .toList(growable: false),
          formatter: AppTokens.signedMoney,
        ),
        AppStat(
          label: 'Win rate',
          value: winRate,
          delta: 2.4,
          icon: Icons.percent_rounded,
          suffix: '%',
          formatter: (num v) => AppTokens.percent(v),
        ),
        AppStat(
          label: 'Avg R multiple',
          value: avgR,
          delta: 0.18,
          icon: Icons.balance_rounded,
          formatter: AppTokens.rr,
        ),
        AppStat(
          label: 'Trades closed',
          value: closed.length,
          delta: closed.where((AppTrade t) => t.closedAt != null).length ~/ 6,
          icon: Icons.receipt_long_outlined,
          formatter: (num v) => v.toStringAsFixed(0),
        ),
      ],
      equity: _source.equitySeries(),
      days: days,
      openTrades: open,
      recentTrades: closed.take(6).toList(growable: false),
      movers: _source.tickers(limit: 8),
      insights: _source.insights(limit: 3),
      news: _source.news(limit: 4),
      checklist: _checklist,
      dailyLossUsedPercent: todayPnl < 0
          ? ((todayPnl.abs() / _source.dailyLossCap) * 100)
                .clamp(0, 100)
                .toDouble()
          : 0,
    );
  }
}
