import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// Graph payload for the strategy relationship canvas.
@immutable
class StrategyGraph {
  const StrategyGraph({required this.nodes, required this.links});

  final List<AppGraphNode> nodes;
  final List<AppGraphLink> links;
}

abstract class StrategyRepository {
  Future<List<AppStrategy>> getStrategies({String? search, String? category});
  Future<AppStrategy?> getStrategy(String id);
  Future<AppStrategy> saveStrategy(AppStrategy strategy);
  Future<void> deleteStrategy(String id);
  Future<AppStrategy> toggleFavorite(String id);
  Future<List<AppStrategyVersion>> getVersions(String strategyId);
  Future<void> restoreVersion(String strategyId, String versionId);
  Future<StrategyGraph> getGraph();
  Future<AppBacktestResult> runBacktest(AppStrategy strategy);
  Future<String> generateSummary(AppStrategy strategy);
  Future<List<String>> getCategories();
}

class StrategyRepositoryImpl implements StrategyRepository {
  StrategyRepositoryImpl({DemoDataSource? source})
    : _source = source ?? DemoDataSource.instance {
    _strategies = List<AppStrategy>.from(_source.strategies());
  }

  final DemoDataSource _source;
  late List<AppStrategy> _strategies;

  @override
  Future<List<AppStrategy>> getStrategies({
    String? search,
    String? category,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final String needle = (search ?? '').trim().toLowerCase();
    return _strategies.where((AppStrategy s) {
      final bool matchesSearch =
          needle.isEmpty ||
          s.name.toLowerCase().contains(needle) ||
          (s.summary ?? '').toLowerCase().contains(needle);
      final bool matchesCategory = category == null || s.category == category;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Future<AppStrategy?> getStrategy(String id) async {
    for (final AppStrategy strategy in _strategies) {
      if (strategy.id == id) return strategy;
    }
    return null;
  }

  @override
  Future<AppStrategy> saveStrategy(AppStrategy strategy) async {
    await Future<void>.delayed(const Duration(milliseconds: 380));
    final int index = _strategies.indexWhere(
      (AppStrategy s) => s.id == strategy.id,
    );
    if (index >= 0) {
      _strategies[index] = strategy;
    } else {
      _strategies.insert(0, strategy);
    }
    return strategy;
  }

  @override
  Future<void> deleteStrategy(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    _strategies.removeWhere((AppStrategy s) => s.id == id);
  }

  @override
  Future<AppStrategy> toggleFavorite(String id) async {
    final int index = _strategies.indexWhere((AppStrategy s) => s.id == id);
    if (index < 0) throw StateError('Strategy $id not found');
    final AppStrategy current = _strategies[index];
    final AppStrategy updated = AppStrategy(
      id: current.id,
      name: current.name,
      summary: current.summary,
      category: current.category,
      isPublic: current.isPublic,
      isFavorite: !current.isFavorite,
      trades: current.trades,
      winRate: current.winRate,
      avgR: current.avgR,
      netPnl: current.netPnl,
      updatedAt: current.updatedAt,
      versionCount: current.versionCount,
      equityCurve: current.equityCurve,
    );
    _strategies[index] = updated;
    return updated;
  }

  @override
  Future<List<AppStrategyVersion>> getVersions(String strategyId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _source.strategyVersions(strategyId);
  }

  @override
  Future<void> restoreVersion(String strategyId, String versionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
  }

  @override
  Future<StrategyGraph> getGraph() async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final ({List<AppGraphNode> nodes, List<AppGraphLink> links}) graph =
        _source.strategyGraph();
    return StrategyGraph(nodes: graph.nodes, links: graph.links);
  }

  @override
  Future<AppBacktestResult> runBacktest(AppStrategy strategy) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return _source.backtest(strategy);
  }

  @override
  Future<String> generateSummary(AppStrategy strategy) async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    return 'Across ${strategy.trades} logged executions this playbook returns '
        '${AppTokens.signedMoney(strategy.netPnl)} at a '
        '${AppTokens.percent(strategy.winRate)} hit rate and '
        '${AppTokens.rr(strategy.avgR)} average outcome. The edge concentrates '
        'in the first two hours of the session; entries taken later show a '
        'materially lower expectancy. Keep risk fixed at 1% and avoid adding '
        'to losers — the drawdown profile degrades quickly when size drifts.';
  }

  @override
  Future<List<String>> getCategories() async => _strategies
      .map((AppStrategy s) => s.category)
      .whereType<String>()
      .toSet()
      .toList();
}
