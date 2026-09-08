import '../models/strategy_model.dart';

/// Repository for strategy data operations.
abstract class StrategyRepository {
  Future<List<Strategy>> getAllStrategies();
  Future<Strategy?> getStrategyById(String id);
  Future<Strategy> createStrategy(Strategy strategy);
  Future<Strategy> updateStrategy(Strategy strategy);
  Future<void> deleteStrategy(String id);
  Future<List<Strategy>> getStrategiesByCategory(String category);
  Future<List<Strategy>> getFavoriteStrategies();
}
