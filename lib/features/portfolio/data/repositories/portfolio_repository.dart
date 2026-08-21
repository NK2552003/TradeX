import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// Aggregated performance analytics for the portfolio surface.
@immutable
class PortfolioSnapshot {
  const PortfolioSnapshot({
    required this.stats,
    required this.equity,
    required this.allocation,
    required this.bySymbol,
    required this.byStrategy,
    required this.bySession,
    required this.days,
    required this.drawdown,
    required this.maxDrawdownPercent,
    required this.winRate,
    required this.wins,
    required this.losses,
    required this.breakeven,
    required this.avgR,
    required this.best,
    required this.worst,
    required this.streak,
    required this.strategies,
  });

  final List<AppStat> stats;
  final List<AppSeriesPoint> equity;
  final List<UiDonutSlice> allocation;
  final List<UiBarListItem> bySymbol;
  final List<UiBarListItem> byStrategy;
  final List<UiBarListItem> bySession;
  final List<AppDayPnl> days;
  final List<double> drawdown;
  final double maxDrawdownPercent;
  final double winRate;
  final int wins;
  final int losses;
  final int breakeven;
  final double avgR;
  final AppTrade? best;
  final AppTrade? worst;
  final List<double> streak;
  final List<AppStrategy> strategies;
}

abstract class PortfolioRepository {
  Future<PortfolioSnapshot> getSnapshot({String range = 'ALL'});
  Future<List<String>> getRanges();
}

class PortfolioRepositoryImpl implements PortfolioRepository {
  PortfolioRepositoryImpl({DemoDataSource? source})
    : _source = source ?? DemoDataSource.instance;

  final DemoDataSource _source;

  static const Map<String, int> _rangeDays = <String, int>{
    '1W': 7,
    '1M': 30,
    '3M': 90,
    'YTD': 240,
    'ALL': 3650,
  };

  @override
  Future<List<String>> getRanges() async => _rangeDays.keys.toList();

  @override
  Future<PortfolioSnapshot> getSnapshot({String range = 'ALL'}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final int windowDays = _rangeDays[range] ?? 3650;
    final DateTime cutoff = DateTime.now().subtract(Duration(days: windowDays));
    final List<AppTrade> all = _source
        .trades()
        .where((AppTrade t) => t.openedAt.isAfter(cutoff))
        .toList(growable: false);
    final List<AppTrade> closed = all
        .where((AppTrade t) => t.outcome != AppOutcome.open)
        .toList(growable: false);

    final double netPnl = closed.fold<double>(
      0,
      (double sum, AppTrade t) => sum + t.pnl,
    );
    final int wins = closed
        .where((AppTrade t) => t.outcome == AppOutcome.win)
        .length;
    final int losses = closed
        .where((AppTrade t) => t.outcome == AppOutcome.loss)
        .length;
    final double grossWin = closed
        .where((AppTrade t) => t.pnl > 0)
        .fold<double>(0, (double s, AppTrade t) => s + t.pnl);
    final double grossLoss = closed
        .where((AppTrade t) => t.pnl < 0)
        .fold<double>(0, (double s, AppTrade t) => s + t.pnl.abs());
    final double avgR = closed.isEmpty
        ? 0
        : closed.fold<double>(
                0,
                (double s, AppTrade t) => s + (t.rMultiple ?? 0),
              ) /
              closed.length;

    final List<AppTrade> sorted = List<AppTrade>.from(closed)
      ..sort((AppTrade a, AppTrade b) => b.pnl.compareTo(a.pnl));
    final List<double> drawdown = _source.drawdownSeries();

    return PortfolioSnapshot(
      stats: <AppStat>[
        AppStat(
          label: 'Net P/L',
          value: netPnl,
          delta: netPnl * 0.08,
          icon: Icons.trending_up_rounded,
          formatter: AppTokens.signedMoney,
        ),
        AppStat(
          label: 'Profit factor',
          value: grossLoss == 0 ? grossWin : grossWin / grossLoss,
          icon: Icons.stacked_line_chart_rounded,
          formatter: (num v) => v.toStringAsFixed(2),
        ),
        AppStat(
          label: 'Expectancy',
          value: closed.isEmpty ? 0 : netPnl / closed.length,
          icon: Icons.functions_rounded,
          formatter: AppTokens.signedMoney,
        ),
        AppStat(
          label: 'Exposure',
          value: all.where((AppTrade t) => t.outcome == AppOutcome.open).length,
          icon: Icons.layers_outlined,
          suffix: ' open',
          formatter: (num v) => v.toStringAsFixed(0),
        ),
      ],
      equity: _source.equitySeries(),
      allocation: _sliceBySector(closed),
      bySymbol: _barsBy(closed, (AppTrade t) => t.ticker),
      byStrategy: _barsBy(closed, (AppTrade t) => t.strategy ?? 'Unclassified'),
      bySession: _barsBy(
        closed,
        (AppTrade t) => t.openedAt.hour < 12 ? 'Morning session' : 'Afternoon session',
      ),
      days: _source.dayPnl(),
      drawdown: drawdown,
      maxDrawdownPercent: drawdown.isEmpty
          ? 0
          : drawdown.reduce((double a, double b) => a < b ? a : b).abs(),
      winRate: closed.isEmpty ? 0 : (wins / closed.length) * 100,
      wins: wins,
      losses: losses,
      breakeven: closed.length - wins - losses,
      avgR: avgR,
      best: sorted.isEmpty ? null : sorted.first,
      worst: sorted.isEmpty ? null : sorted.last,
      streak: _source
          .dayPnl(days: 14)
          .map((AppDayPnl d) => d.pnl)
          .toList(growable: false),
      strategies: _source.strategies(),
    );
  }

  List<UiDonutSlice> _sliceBySector(List<AppTrade> trades) {
    final Map<String, double> totals = <String, double>{};
    for (final AppTrade trade in trades) {
      final String sector = trade.tags.isEmpty ? 'Other' : trade.tags.last;
      totals[sector] = (totals[sector] ?? 0) + (trade.entry * trade.size);
    }
    final List<MapEntry<String, double>> entries = totals.entries.toList()
      ..sort(
        (MapEntry<String, double> a, MapEntry<String, double> b) =>
            b.value.compareTo(a.value),
      );
    return <UiDonutSlice>[
      for (final MapEntry<String, double> e in entries.take(6))
        UiDonutSlice(label: e.key, value: e.value),
    ];
  }

  List<UiBarListItem> _barsBy(
    List<AppTrade> trades,
    String Function(AppTrade trade) keyOf,
  ) {
    final Map<String, double> totals = <String, double>{};
    for (final AppTrade trade in trades) {
      final String key = keyOf(trade);
      totals[key] = (totals[key] ?? 0) + trade.pnl;
    }
    final List<MapEntry<String, double>> entries = totals.entries.toList()
      ..sort(
        (MapEntry<String, double> a, MapEntry<String, double> b) =>
            b.value.abs().compareTo(a.value.abs()),
      );
    return <UiBarListItem>[
      for (final MapEntry<String, double> e in entries.take(7))
        UiBarListItem(label: e.key, value: e.value),
    ];
  }
}
