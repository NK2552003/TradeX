import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';

abstract class SupabaseTradeRepository {
  Future<List<AppTrade>> getEntries({
    String? query,
    AppOutcome? outcome,
    String? ticker,
  });

  Future<AppTrade> createEntry(AppTrade trade);

  Future<AppTrade> updateEntry(AppTrade trade);

  Future<void> deleteEntry(String entryId);

  Future<Map<String, dynamic>> getPortfolioStats();
}

class SupabaseTradeRepositoryImpl implements SupabaseTradeRepository {
  SupabaseTradeRepositoryImpl._([JournalRepository? journalRepo])
    : _journalRepo = journalRepo;

  static final SupabaseTradeRepositoryImpl instance =
      SupabaseTradeRepositoryImpl._();

  factory SupabaseTradeRepositoryImpl({JournalRepository? journalRepo}) =>
      journalRepo != null
      ? SupabaseTradeRepositoryImpl._(journalRepo)
      : instance;

  final JournalRepository? _journalRepo;

  JournalRepository get _repo =>
      _journalRepo ?? JournalRepositoryScope.repository;

  @override
  Future<List<AppTrade>> getEntries({
    String? query,
    AppOutcome? outcome,
    String? ticker,
  }) async {
    final all = await _repo.fetchAll();
    return JournalQuery.apply(
      all,
      query: query ?? '',
      outcome: outcome,
      ticker: ticker,
    );
  }

  @override
  Future<AppTrade> createEntry(AppTrade trade) async {
    return await _repo.create(trade);
  }

  @override
  Future<AppTrade> updateEntry(AppTrade trade) async {
    return await _repo.update(trade);
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    await _repo.delete(entryId);
  }

  @override
  Future<Map<String, dynamic>> getPortfolioStats() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final res = await client
              .from('portfolio_stats')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();

          if (res != null) {
            return Map<String, dynamic>.from(res);
          }
        }
      } catch (e) {
        debugPrint('[SupabaseTradeRepository] getPortfolioStats error: $e');
      }
    }

    final trades = await _repo.fetchAll();
    final closed = trades.where((t) => !t.isOpen).toList();
    final wins = closed.where((t) => t.outcome == AppOutcome.win).length;
    final double netPnl = closed.fold(0.0, (sum, t) => sum + t.pnl);
    final double winRate = closed.isNotEmpty
        ? (wins / closed.length) * 100
        : 0.0;
    final rs = closed
        .where((t) => t.rMultiple != null)
        .map((t) => t.rMultiple!);
    final double avgRr = rs.isNotEmpty
        ? rs.reduce((a, b) => a + b) / rs.length
        : 0.0;
    final double bestPnl = trades.isNotEmpty
        ? trades.map((t) => t.pnl).reduce((a, b) => a > b ? a : b)
        : 0.0;

    return <String, dynamic>{
      'total_trades': trades.length,
      'winning_trades': wins,
      'win_rate_percent': winRate,
      'total_pnl': netPnl,
      'avg_rr': avgRr,
      'best_trade_pnl': bestPnl,
    };
  }
}
