import 'dart:convert';
import 'package:tradex/core/app-ui/models/app_models.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';

abstract class StrategyRepository {
  Future<List<AppStrategy>> getStrategies();
  Future<AppStrategy> createStrategy({
    required String name,
    String? summary,
    String? category,
    bool isPublic = false,
    Map<String, dynamic>? rulesJson,
  });
  Future<AppStrategy> updateStrategy(AppStrategy strategy);
  Future<void> deleteStrategy(String strategyId);
  Future<List<AppStrategyVersion>> getVersionHistory(String strategyId);
  Future<AppStrategyVersion> createVersion({
    required String strategyId,
    required String note,
    required Map<String, dynamic> contentJson,
  });
}

class StrategyRepositoryImpl implements StrategyRepository {
  StrategyRepositoryImpl._([StrategiesRepository? repo]) : _strategiesRepo = repo;

  static final StrategyRepositoryImpl instance = StrategyRepositoryImpl._();

  factory StrategyRepositoryImpl({StrategiesRepository? repo}) =>
      repo != null ? StrategyRepositoryImpl._(repo) : instance;

  final StrategiesRepository? _strategiesRepo;

  StrategiesRepository get _repo =>
      _strategiesRepo ?? StrategiesRepositoryScope.repository;

  @override
  Future<List<AppStrategy>> getStrategies() async {
    return await _repo.fetchAll();
  }

  @override
  Future<AppStrategy> createStrategy({
    required String name,
    String? summary,
    String? category,
    bool isPublic = false,
    Map<String, dynamic>? rulesJson,
  }) async {
    final String content = rulesJson != null
        ? const JsonEncoder.withIndent('  ').convert(rulesJson)
        : '';

    final AppStrategy draft = AppStrategy(
      id: '',
      name: name,
      summary: summary,
      category: category,
      isPublic: isPublic,
      content: content,
    );

    return await _repo.create(draft);
  }

  @override
  Future<AppStrategy> updateStrategy(AppStrategy strategy) async {
    return await _repo.update(strategy);
  }

  @override
  Future<void> deleteStrategy(String strategyId) async {
    await _repo.delete(strategyId);
  }

  @override
  Future<List<AppStrategyVersion>> getVersionHistory(String strategyId) async {
    return await _repo.versions(strategyId);
  }

  @override
  Future<AppStrategyVersion> createVersion({
    required String strategyId,
    required String note,
    required Map<String, dynamic> contentJson,
  }) async {
    return await _repo.saveVersion(strategyId, note: note);
  }
}
