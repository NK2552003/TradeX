import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/models/app_models.dart';
import 'package:tradex/core/config/supabase_config.dart';

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
  StrategyRepositoryImpl._();

  static final StrategyRepositoryImpl instance = StrategyRepositoryImpl._();

  factory StrategyRepositoryImpl() => instance;

  final List<AppStrategy> _inMemoryStrategies = <AppStrategy>[
    AppStrategy(
      id: 'str_001',
      name: 'ORB 15-Min Breakout',
      summary: 'Opening Range Breakout with 200 EMA trend filter and 1:2.5 risk-to-reward target.',
      category: 'Breakout',
      isPublic: true,
      isFavorite: true,
      trades: 42,
      winRate: 64.2,
      avgR: 2.1,
      netPnl: 124500.0,
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      versionCount: 4,
    ),
    AppStrategy(
      id: 'str_002',
      name: 'VWAP Liquidity Sweep',
      summary: 'Mean reversion entry on 5-min chart following liquidity grab beneath prior day low.',
      category: 'Reversal',
      isPublic: false,
      isFavorite: false,
      trades: 28,
      winRate: 57.1,
      avgR: 1.8,
      netPnl: 48200.0,
      updatedAt: DateTime.now().subtract(const Duration(days: 7)),
      versionCount: 2,
    ),
  ];

  final Map<String, List<AppStrategyVersion>> _versions = {
    'str_001': [
      AppStrategyVersion(
        id: 'ver_001_v4',
        version: 4,
        savedAt: DateTime.now().subtract(const Duration(days: 3)),
        author: 'Nitish Kumar',
        note: 'Added 200 EMA 4-hour trend filter',
        isCurrent: true,
      ),
      AppStrategyVersion(
        id: 'ver_001_v3',
        version: 3,
        savedAt: DateTime.now().subtract(const Duration(days: 20)),
        author: 'Nitish Kumar',
        note: 'Adjusted stop loss tight beneath 15m candle low',
        isCurrent: false,
      ),
    ],
  };

  @override
  Future<List<AppStrategy>> getStrategies() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final res = await client
              .from('strategies')
              .select()
              .eq('user_id', user.id)
              .order('updated_at', ascending: false);

          return (res as List).map((row) => _mapRowToStrategy(row)).toList();
        }
      } catch (e) {
        debugPrint('[StrategyRepository] getStrategies error: $e');
      }
    }
    return List<AppStrategy>.from(_inMemoryStrategies);
  }

  @override
  Future<AppStrategy> createStrategy({
    required String name,
    String? summary,
    String? category,
    bool isPublic = false,
    Map<String, dynamic>? rulesJson,
  }) async {
    final now = DateTime.now();

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final res = await client
              .from('strategies')
              .insert({
                'user_id': user.id,
                'title': name,
                'content': rulesJson ?? {'summary': summary ?? ''},
                'category': category ?? 'General',
                'visibility': isPublic ? 'public' : 'private',
                'ai_summary': summary,
              })
              .select()
              .single();

          final created = _mapRowToStrategy(res);
          // Initial version creation
          await createVersion(
            strategyId: created.id,
            note: 'Initial strategy creation',
            contentJson: rulesJson ?? {'summary': summary ?? ''},
          );

          return created;
        }
      } catch (e) {
        debugPrint('[StrategyRepository] createStrategy error: $e');
      }
    }

    final newStrat = AppStrategy(
      id: 'str_${now.millisecondsSinceEpoch}',
      name: name,
      summary: summary,
      category: category,
      isPublic: isPublic,
      updatedAt: now,
    );
    _inMemoryStrategies.insert(0, newStrat);
    return newStrat;
  }

  @override
  Future<AppStrategy> updateStrategy(AppStrategy strategy) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('strategies')
            .update({
              'title': strategy.name,
              'category': strategy.category,
              'visibility': strategy.isPublic ? 'public' : 'private',
              'is_favorite': strategy.isFavorite,
              'ai_summary': strategy.summary,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', strategy.id)
            .select()
            .single();

        return _mapRowToStrategy(res);
      } catch (e) {
        debugPrint('[StrategyRepository] updateStrategy error: $e');
      }
    }

    final idx = _inMemoryStrategies.indexWhere((s) => s.id == strategy.id);
    if (idx != -1) {
      _inMemoryStrategies[idx] = strategy;
    }
    return strategy;
  }

  @override
  Future<void> deleteStrategy(String strategyId) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        await client.from('strategies').delete().eq('id', strategyId);
      } catch (e) {
        debugPrint('[StrategyRepository] deleteStrategy error: $e');
      }
    }

    _inMemoryStrategies.removeWhere((s) => s.id == strategyId);
    _versions.remove(strategyId);
  }

  @override
  Future<List<AppStrategyVersion>> getVersionHistory(String strategyId) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client
            .from('strategy_versions')
            .select()
            .eq('strategy_id', strategyId)
            .order('version_number', ascending: false);

        return (res as List).map((row) {
          return AppStrategyVersion(
            id: row['id'] as String,
            version: row['version_number'] as int? ?? 1,
            savedAt: row['created_at'] != null ? DateTime.parse(row['created_at'] as String) : DateTime.now(),
            note: row['content']?['note'] as String? ?? 'Version update',
            isCurrent: (row['version_number'] as int? ?? 1) == 1,
          );
        }).toList();
      } catch (e) {
        debugPrint('[StrategyRepository] getVersionHistory error: $e');
      }
    }

    return _versions[strategyId] ?? const [];
  }

  @override
  Future<AppStrategyVersion> createVersion({
    required String strategyId,
    required String note,
    required Map<String, dynamic> contentJson,
  }) async {
    final now = DateTime.now();

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final countRes = await client
            .from('strategy_versions')
            .select('version_number')
            .eq('strategy_id', strategyId)
            .order('version_number', ascending: false)
            .limit(1)
            .maybeSingle();

        final nextVer = ((countRes?['version_number'] as int?) ?? 0) + 1;
        final payload = Map<String, dynamic>.from(contentJson)..['note'] = note;

        final res = await client
            .from('strategy_versions')
            .insert({
              'strategy_id': strategyId,
              'content': payload,
              'version_number': nextVer,
            })
            .select()
            .single();

        return AppStrategyVersion(
          id: res['id'] as String,
          version: nextVer,
          savedAt: now,
          note: note,
          isCurrent: true,
        );
      } catch (e) {
        debugPrint('[StrategyRepository] createVersion error: $e');
      }
    }

    final currentVersions = _versions[strategyId] ?? [];
    final nextVer = currentVersions.length + 1;
    final newVersion = AppStrategyVersion(
      id: 'ver_${strategyId}_v$nextVer',
      version: nextVer,
      savedAt: now,
      note: note,
      isCurrent: true,
    );
    _versions[strategyId] = [newVersion, ...currentVersions];
    return newVersion;
  }

  AppStrategy _mapRowToStrategy(Map<String, dynamic> row) {
    final visibility = row['visibility'] as String? ?? 'private';
    return AppStrategy(
      id: row['id'] as String,
      name: row['title'] as String? ?? 'Untitled Strategy',
      summary: row['ai_summary'] as String? ?? (row['content']?['summary'] as String?),
      category: row['category'] as String? ?? 'General',
      isPublic: visibility == 'public',
      isFavorite: row['is_favorite'] as bool? ?? false,
      updatedAt: row['updated_at'] != null ? DateTime.parse(row['updated_at'] as String) : DateTime.now(),
    );
  }
}
