import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';

abstract class WatchlistRepository {
  Future<List<AppTicker>> getWatchlistTickers({String? category});
  Future<List<String>> getWatchlists();
  Future<void> createWatchlist(String name);
  Future<void> addTickerToWatchlist(String watchlistName, String symbol);
  Future<void> removeTickerFromWatchlist(String watchlistName, String symbol);
  Future<void> setPriceAlert({
    required String symbol,
    required double threshold,
    required String direction, // 'above' or 'below'
  });
}

class WatchlistRepositoryImpl implements WatchlistRepository {
  WatchlistRepositoryImpl._();

  static final WatchlistRepositoryImpl instance = WatchlistRepositoryImpl._();

  factory WatchlistRepositoryImpl() => instance;

  final List<AppTicker> _inMemoryTickers = <AppTicker>[
    const AppTicker(
      symbol: 'RELIANCE',
      name: 'Reliance Industries',
      price: 2912.40,
      changePercent: 1.85,
      category: 'Energy',
      isFavorite: true,
      spark: <double>[100, 102, 101, 104, 103, 106, 108],
    ),
    const AppTicker(
      symbol: 'HDFCBANK',
      name: 'HDFC Bank',
      price: 1684.75,
      changePercent: -0.45,
      category: 'Financials',
      isFavorite: true,
      spark: <double>[100, 99, 98, 99.5, 98.8, 99.2],
    ),
    const AppTicker(
      symbol: 'NIFTY50',
      name: 'Nifty 50 Index',
      price: 24380.55,
      changePercent: 0.92,
      category: 'Index',
      isFavorite: true,
      spark: <double>[100, 101, 102, 103, 102.5, 104],
    ),
    const AppTicker(
      symbol: 'TCS',
      name: 'Tata Consultancy Services',
      price: 3902.10,
      changePercent: 2.15,
      category: 'IT',
      isFavorite: false,
      spark: <double>[100, 101.5, 103, 102.8, 104.2],
    ),
  ];

  final List<String> _inMemoryWatchlists = <String>['Default Watchlist', 'Options Tracker', 'Crypto Favorites'];

  @override
  Future<List<AppTicker>> getWatchlistTickers({String? category}) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final res = await client
              .from('watchlist_items')
              .select('*, watchlists!inner(user_id, name)')
              .eq('watchlists.user_id', user.id);

          if ((res as List).isNotEmpty) {
            return (res as List).map((row) {
              final symbol = row['ticker'] as String? ?? 'UNKNOWN';
              return AppTicker(
                symbol: symbol,
                name: symbol,
                price: (row['price_alert_threshold'] as num?)?.toDouble() ?? 100.0,
                changePercent: 0.0,
                category: row['category'] as String? ?? 'General',
                isFavorite: row['is_favorite'] as bool? ?? false,
              );
            }).toList();
          }
        }
      } catch (e) {
        debugPrint('[WatchlistRepository] getWatchlistTickers error: $e');
      }
    }

    if (category != null && category.isNotEmpty) {
      return _inMemoryTickers.where((t) => t.category == category).toList();
    }
    return List<AppTicker>.from(_inMemoryTickers);
  }

  @override
  Future<List<String>> getWatchlists() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final res = await client
              .from('watchlists')
              .select('name')
              .eq('user_id', user.id);

          if ((res as List).isNotEmpty) {
            return (res as List).map((r) => r['name'] as String).toList();
          }
        }
      } catch (e) {
        debugPrint('[WatchlistRepository] getWatchlists error: $e');
      }
    }
    return List<String>.from(_inMemoryWatchlists);
  }

  @override
  Future<void> createWatchlist(String name) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          await client.from('watchlists').upsert({
            'user_id': user.id,
            'name': name,
          });
        }
      } catch (e) {
        debugPrint('[WatchlistRepository] createWatchlist error: $e');
      }
    }
    if (!_inMemoryWatchlists.contains(name)) {
      _inMemoryWatchlists.add(name);
    }
  }

  @override
  Future<void> addTickerToWatchlist(String watchlistName, String symbol) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final wl = await client
              .from('watchlists')
              .select('id')
              .eq('user_id', user.id)
              .eq('name', watchlistName)
              .maybeSingle();

          if (wl != null) {
            await client.from('watchlist_items').upsert({
              'watchlist_id': wl['id'],
              'ticker': symbol,
            });
          }
        }
      } catch (e) {
        debugPrint('[WatchlistRepository] addTickerToWatchlist error: $e');
      }
    }
  }

  @override
  Future<void> removeTickerFromWatchlist(String watchlistName, String symbol) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final wl = await client
              .from('watchlists')
              .select('id')
              .eq('user_id', user.id)
              .eq('name', watchlistName)
              .maybeSingle();

          if (wl != null) {
            await client
                .from('watchlist_items')
                .delete()
                .eq('watchlist_id', wl['id'])
                .eq('ticker', symbol);
          }
        }
      } catch (e) {
        debugPrint('[WatchlistRepository] removeTickerFromWatchlist error: $e');
      }
    }
  }

  @override
  Future<void> setPriceAlert({
    required String symbol,
    required double threshold,
    required String direction,
  }) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        if (user != null) {
          final items = await client
              .from('watchlist_items')
              .select('id, watchlists!inner(user_id)')
              .eq('ticker', symbol)
              .eq('watchlists.user_id', user.id);

          if ((items as List).isNotEmpty) {
            final itemId = items.first['id'];
            await client.from('watchlist_items').update({
              'price_alert_threshold': threshold,
              'price_alert_direction': direction,
              'alert_armed': true,
            }).eq('id', itemId);
          }
        }
      } catch (e) {
        debugPrint('[WatchlistRepository] setPriceAlert error: $e');
      }
    }
  }
}
