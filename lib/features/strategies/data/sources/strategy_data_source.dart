import 'package:tradex/core/data/demo_data_source.dart';
import '../models/strategy_model.dart';
import 'strategy_repository.dart';

/// Demo implementation of strategy repository using mock data.
class StrategyRepositoryImpl implements StrategyRepository {
  StrategyRepositoryImpl._();
  static final StrategyRepositoryImpl instance = StrategyRepositoryImpl._();

  final DemoDataSource _dataSource = DemoDataSource.instance;

  @override
  Future<List<Strategy>> getAllStrategies() async {
    // Map from demo AppStrategy to our new Strategy model
    final appStrategies = _dataSource.strategies();
    return appStrategies.map((appStrategy) {
      return Strategy(
        id: appStrategy.id,
        name: appStrategy.name,
        description: appStrategy.summary,
        category: appStrategy.category,
        isPublic: appStrategy.isPublic,
        isFavorite: appStrategy.isFavorite,
        tradesCount: appStrategy.trades,
        winRate: appStrategy.winRate,
        avgR: appStrategy.avgR,
        netPnl: appStrategy.netPnl,
        updatedAt: appStrategy.updatedAt,
        versionCount: appStrategy.versionCount,
        equityCurve: appStrategy.equityCurve,
      );
    }).toList();
  }

  @override
  Future<Strategy?> getStrategyById(String id) async {
    final strategies = await getAllStrategies();
    try {
      return strategies.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Strategy> createStrategy(Strategy strategy) async {
    // In a real implementation, this would persist to backend
    return strategy;
  }

  @override
  Future<Strategy> updateStrategy(Strategy strategy) async {
    // In a real implementation, this would update in backend
    return strategy;
  }

  @override
  Future<void> deleteStrategy(String id) async {
    // In a real implementation, this would delete from backend
  }

  @override
  Future<List<Strategy>> getStrategiesByCategory(String category) async {
    final strategies = await getAllStrategies();
    return strategies.where((s) => s.category == category).toList();
  }

  @override
  Future<List<Strategy>> getFavoriteStrategies() async {
    final strategies = await getAllStrategies();
    return strategies.where((s) => s.isFavorite).toList();
  }
}
