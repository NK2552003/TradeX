import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// Rolled-up journal metrics for the filter header and summary cards.
@immutable
class JournalSummary {
  const JournalSummary({
    required this.netPnl,
    required this.winRate,
    required this.avgR,
    required this.total,
    required this.wins,
    required this.losses,
    required this.breakeven,
    required this.spark,
  });

  final double netPnl;
  final double winRate;
  final double avgR;
  final int total;
  final int wins;
  final int losses;
  final int breakeven;
  final List<double> spark;
}

/// Filter state shared between the journal toolbar and the repository query.
@immutable
class JournalQuery {
  const JournalQuery({
    this.search = '',
    this.outcome,
    this.side,
    this.symbol,
    this.strategy,
    this.from,
    this.to,
  });

  final String search;
  final AppOutcome? outcome;
  final AppSide? side;
  final String? symbol;
  final String? strategy;
  final DateTime? from;
  final DateTime? to;

  JournalQuery copyWith({
    String? search,
    AppOutcome? outcome,
    AppSide? side,
    String? symbol,
    String? strategy,
    DateTime? from,
    DateTime? to,
    bool clearOutcome = false,
    bool clearSide = false,
    bool clearSymbol = false,
    bool clearStrategy = false,
    bool clearRange = false,
  }) => JournalQuery(
    search: search ?? this.search,
    outcome: clearOutcome ? null : (outcome ?? this.outcome),
    side: clearSide ? null : (side ?? this.side),
    symbol: clearSymbol ? null : (symbol ?? this.symbol),
    strategy: clearStrategy ? null : (strategy ?? this.strategy),
    from: clearRange ? null : (from ?? this.from),
    to: clearRange ? null : (to ?? this.to),
  );

  bool get hasFilters =>
      outcome != null ||
      side != null ||
      symbol != null ||
      strategy != null ||
      from != null ||
      to != null;
}

abstract class JournalRepository {
  Future<List<AppTrade>> getTrades([JournalQuery query]);
  Future<AppTrade?> getTrade(String id);
  Future<JournalSummary> getSummary();
  Future<List<AppDayPnl>> getCalendar();
  Future<List<AppChecklistItem>> getChecklist();
  Future<void> toggleChecklistItem(String id);
  Future<AppTrade> saveTrade(AppTrade trade);
  Future<void> deleteTrade(String id);
  Future<List<String>> getSymbols();
  Future<List<String>> getStrategies();
  Future<List<String>> getTags();
}

class JournalRepositoryImpl implements JournalRepository {
  JournalRepositoryImpl({DemoDataSource? source})
    : _source = source ?? DemoDataSource.instance {
    _trades = List<AppTrade>.from(_source.trades());
    _checklist = List<AppChecklistItem>.from(_source.checklist());
  }

  final DemoDataSource _source;
  late List<AppTrade> _trades;
  late List<AppChecklistItem> _checklist;

  bool _matches(AppTrade trade, JournalQuery q) {
    final String needle = q.search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      final bool hit =
          trade.ticker.toLowerCase().contains(needle) ||
          (trade.strategy ?? '').toLowerCase().contains(needle) ||
          (trade.notes ?? '').toLowerCase().contains(needle) ||
          trade.tags.any((String t) => t.toLowerCase().contains(needle));
      if (!hit) return false;
    }
    if (q.outcome != null && trade.outcome != q.outcome) return false;
    if (q.side != null && trade.side != q.side) return false;
    if (q.symbol != null && trade.ticker != q.symbol) return false;
    if (q.strategy != null && trade.strategy != q.strategy) return false;
    if (q.from != null && trade.openedAt.isBefore(q.from!)) return false;
    if (q.to != null && trade.openedAt.isAfter(q.to!)) return false;
    return true;
  }

  @override
  Future<List<AppTrade>> getTrades([
    JournalQuery query = const JournalQuery(),
  ]) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final List<AppTrade> rows = _trades
        .where((AppTrade t) => _matches(t, query))
        .toList();
    rows.sort((AppTrade a, AppTrade b) => b.openedAt.compareTo(a.openedAt));
    return rows;
  }

  @override
  Future<AppTrade?> getTrade(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (final AppTrade trade in _trades) {
      if (trade.id == id) return trade;
    }
    return null;
  }

  @override
  Future<JournalSummary> getSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final List<AppTrade> closed = _trades
        .where((AppTrade t) => t.outcome != AppOutcome.open)
        .toList(growable: false);
    final int wins = closed
        .where((AppTrade t) => t.outcome == AppOutcome.win)
        .length;
    final int losses = closed
        .where((AppTrade t) => t.outcome == AppOutcome.loss)
        .length;
    final double netPnl = closed.fold<double>(
      0,
      (double sum, AppTrade t) => sum + t.pnl,
    );
    double running = 0;
    return JournalSummary(
      netPnl: netPnl,
      winRate: closed.isEmpty ? 0 : (wins / closed.length) * 100,
      avgR: closed.isEmpty
          ? 0
          : closed.fold<double>(
                  0,
                  (double sum, AppTrade t) => sum + (t.rMultiple ?? 0),
                ) /
                closed.length,
      total: _trades.length,
      wins: wins,
      losses: losses,
      breakeven: closed.length - wins - losses,
      spark: <double>[
        for (final AppTrade t in closed.reversed) running += t.pnl,
      ],
    );
  }

  @override
  Future<List<AppDayPnl>> getCalendar() async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return _source.dayPnl();
  }

  @override
  Future<List<AppChecklistItem>> getChecklist() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return List<AppChecklistItem>.from(_checklist);
  }

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
  Future<AppTrade> saveTrade(AppTrade trade) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    final int index = _trades.indexWhere((AppTrade t) => t.id == trade.id);
    if (index >= 0) {
      _trades[index] = trade;
    } else {
      _trades.insert(0, trade);
    }
    return trade;
  }

  @override
  Future<void> deleteTrade(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    _trades.removeWhere((AppTrade t) => t.id == id);
  }

  @override
  Future<List<String>> getSymbols() async => _source.symbols;

  @override
  Future<List<String>> getStrategies() async => _source
      .strategies()
      .map((AppStrategy s) => s.name)
      .toList(growable: false);

  @override
  Future<List<String>> getTags() async {
    final Set<String> tags = <String>{};
    for (final AppTrade trade in _trades) {
      tags.addAll(trade.tags);
    }
    return tags.toList()..sort();
  }
}
