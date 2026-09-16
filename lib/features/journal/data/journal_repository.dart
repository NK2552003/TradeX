import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';

abstract class JournalRepository {
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

class JournalRepositoryImpl implements JournalRepository {
  JournalRepositoryImpl._();

  static final JournalRepositoryImpl instance = JournalRepositoryImpl._();

  factory JournalRepositoryImpl() => instance;

  final List<AppTrade> _inMemoryTrades = <AppTrade>[
    AppTrade(
      id: 'trd_001',
      ticker: 'NIFTY50',
      side: AppSide.long,
      entry: 22450.0,
      exit: 22620.0,
      openedAt: DateTime.now().subtract(const Duration(days: 2)),
      closedAt: DateTime.now().subtract(const Duration(days: 1)),
      stopLoss: 22380.0,
      target: 22650.0,
      size: 50,
      pnl: 8500.0,
      pnlPercent: 3.78,
      rMultiple: 2.4,
      outcome: AppOutcome.win,
      strategy: 'ORB Breakout',
      tags: const <String>['Breakout', 'Momentum'],
      notes: 'Strong morning volume sweep above 22450 high.',
    ),
    AppTrade(
      id: 'trd_002',
      ticker: 'RELIANCE',
      side: AppSide.long,
      entry: 2980.0,
      exit: 2950.0,
      openedAt: DateTime.now().subtract(const Duration(days: 1)),
      closedAt: DateTime.now().subtract(const Duration(hours: 4)),
      stopLoss: 2950.0,
      target: 3040.0,
      size: 100,
      pnl: -3000.0,
      pnlPercent: -1.0,
      rMultiple: -1.0,
      outcome: AppOutcome.loss,
      strategy: 'VWAP Bounce',
      tags: const <String>['Reversal'],
      notes: 'Failed to hold VWAP support during afternoon selloff.',
    ),
  ];

  @override
  Future<List<AppTrade>> getEntries({
    String? query,
    AppOutcome? outcome,
    String? ticker,
  }) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          var req = client.from('journal_entries').select().eq('user_id', user.id);

          if (ticker != null && ticker.isNotEmpty) {
            req = req.ilike('ticker', '%$ticker%');
          }
          if (outcome != null) {
            req = req.eq('outcome', outcome.name);
          }

          final res = await req.order('created_at', ascending: false);
          return (res as List).map((row) => _mapRowToTrade(row)).toList();
        }
      } catch (e) {
        debugPrint('[JournalRepository] getEntries error: $e');
      }
    }

    return _inMemoryTrades.where((trade) {
      if (outcome != null && trade.outcome != outcome) return false;
      if (ticker != null && ticker.isNotEmpty && !trade.ticker.toLowerCase().contains(ticker.toLowerCase())) return false;
      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        final matchTicker = trade.ticker.toLowerCase().contains(q);
        final matchNotes = trade.notes?.toLowerCase().contains(q) ?? false;
        final matchTag = trade.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchTicker && !matchNotes && !matchTag) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<AppTrade> createEntry(AppTrade trade) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final res = await client
              .from('journal_entries')
              .insert({
                'user_id': user.id,
                'ticker': trade.ticker,
                'content': trade.notes ?? '',
                'entry_price': trade.entry,
                'exit_price': trade.exit,
                'stop_loss': trade.stopLoss,
                'target': trade.target,
                'size': trade.size,
                'side': trade.side.name.toUpperCase(),
                'pnl': trade.pnl,
                'outcome': trade.outcome.name,
                'tags': trade.tags,
                'screenshots': trade.screenshotUrl != null ? [trade.screenshotUrl!] : [],
              })
              .select()
              .single();

          return _mapRowToTrade(res);
        }
      } catch (e) {
        debugPrint('[JournalRepository] createEntry error: $e');
      }
    }

    _inMemoryTrades.insert(0, trade);
    return trade;
  }

  @override
  Future<AppTrade> updateEntry(AppTrade trade) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final res = await client
              .from('journal_entries')
              .update({
                'ticker': trade.ticker,
                'content': trade.notes ?? '',
                'entry_price': trade.entry,
                'exit_price': trade.exit,
                'stop_loss': trade.stopLoss,
                'target': trade.target,
                'size': trade.size,
                'side': trade.side.name.toUpperCase(),
                'pnl': trade.pnl,
                'outcome': trade.outcome.name,
                'tags': trade.tags,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', trade.id)
              .select()
              .single();

          return _mapRowToTrade(res);
        }
      } catch (e) {
        debugPrint('[JournalRepository] updateEntry error: $e');
      }
    }

    final idx = _inMemoryTrades.indexWhere((t) => t.id == trade.id);
    if (idx != -1) {
      _inMemoryTrades[idx] = trade;
    }
    return trade;
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        await client.from('journal_entries').delete().eq('id', entryId);
      } catch (e) {
        debugPrint('[JournalRepository] deleteEntry error: $e');
      }
    }

    _inMemoryTrades.removeWhere((t) => t.id == entryId);
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
            return res;
          }
        }
      } catch (e) {
        debugPrint('[JournalRepository] getPortfolioStats error: $e');
      }
    }

    int totalTrades = _inMemoryTrades.length;
    int wins = _inMemoryTrades.where((t) => t.outcome == AppOutcome.win).length;
    double netPnl = _inMemoryTrades.fold(0.0, (sum, t) => sum + t.pnl);
    double winRate = totalTrades > 0 ? (wins / totalTrades) * 100 : 0.0;

    return {
      'total_trades': totalTrades,
      'winning_trades': wins,
      'win_rate_percent': winRate,
      'total_pnl': netPnl,
    };
  }

  AppTrade _mapRowToTrade(Map<String, dynamic> row) {
    final sideStr = (row['side'] as String? ?? 'LONG').toLowerCase();
    final outcomeStr = (row['outcome'] as String? ?? 'open').toLowerCase();
    final screenshots = row['screenshots'] as List<dynamic>?;

    return AppTrade(
      id: row['id'] as String,
      ticker: row['ticker'] as String? ?? 'UNKNOWN',
      side: (sideStr == 'sell' || sideStr == 'short') ? AppSide.short : AppSide.long,
      entry: (row['entry_price'] as num?)?.toDouble() ?? 0.0,
      exit: (row['exit_price'] as num?)?.toDouble(),
      openedAt: row['created_at'] != null ? DateTime.parse(row['created_at'] as String) : DateTime.now(),
      stopLoss: (row['stop_loss'] as num?)?.toDouble(),
      target: (row['target'] as num?)?.toDouble(),
      size: (row['size'] as num?)?.toDouble() ?? 1.0,
      pnl: (row['pnl'] as num?)?.toDouble() ?? 0.0,
      outcome: outcomeStr == 'win'
          ? AppOutcome.win
          : (outcomeStr == 'loss' ? AppOutcome.loss : AppOutcome.open),
      tags: row['tags'] != null ? List<String>.from(row['tags'] as List) : const [],
      notes: row['content'] as String?,
      screenshotUrl: (screenshots != null && screenshots.isNotEmpty) ? screenshots.first.toString() : null,
    );
  }
}
