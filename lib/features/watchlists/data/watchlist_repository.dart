import 'package:alphajournal/core/config/customer_data_policy.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
import 'package:alphajournal/core/config/record_access.dart';
import 'package:alphajournal/features/market_data/data/asset_market_repository.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/supabase_config.dart';

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
  WatchlistRepositoryImpl._() {
    if (!CustomerDataPolicy.allowDemo) {
      _inMemoryTickers.clear();
      _inMemoryWatchlists.clear();
    }
  }

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

  final List<String> _inMemoryWatchlists = <String>[
    'Default Watchlist',
    'Options Tracker',
    'Crypto Favorites',
  ];

  Future<AppTicker> _quoteTicker(
    String symbol, {
    String? category,
    bool favorite = false,
  }) async {
    MarketInstrument? quote;
    try {
      quote = (await AssetMarketRepository.shared.snapshot()).instruments
          .where((q) => q.symbol == symbol)
          .firstOrNull;
    } catch (_) {
      /* A saved symbol can exist without an available quote. */
    }
    return AppTicker(
      symbol: symbol,
      name: quote?.name ?? symbol,
      price: quote?.price ?? double.nan,
      changePercent: quote?.changePercent ?? 0,
      spark: quote?.spark ?? [],
      category: category,
      isFavorite: favorite,
      currencySymbol: quote?.currency == 'INR'
          ? '₹'
          : quote?.currency == 'USD'
          ? r'$'
          : '${quote?.currency ?? ''} ',
      note: quote == null
          ? 'Quote unavailable'
          : 'Bundled snapshot; may be out of date',
    );
  }

  @override
  Future<List<AppTicker>> getWatchlistTickers({String? category}) async {
    List<AppTicker> items;
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final user = client.auth.currentUser;
      if (user == null) throw StateError('Sign in to load your watchlists.');
      final rows = await client
          .from('watchlist_items')
          .select('*, watchlists!inner(user_id, name)')
          .eq('watchlists.user_id', user.id);
      items = await Future.wait([
        for (final row in rows)
          _quoteTicker(
            row['ticker'] as String,
            category: row['category'] as String?,
            favorite: row['is_favorite'] as bool? ?? false,
          ),
      ]);
    } else {
      items = await Future.wait([
        for (final ticker in _inMemoryTickers)
          _quoteTicker(
            ticker.symbol,
            category: ticker.category,
            favorite: ticker.isFavorite,
          ),
      ]);
    }
    return category == null || category.isEmpty
        ? items
        : items.where((t) => t.category == category).toList();
  }

  @override
  Future<List<String>> getWatchlists() async {
    if (!SupabaseConfig.isConfigured) return List.of(_inMemoryWatchlists);
    final client = SupabaseConfig.client!;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in to load watchlists.');
    final rows = await client
        .from('watchlists')
        .select('name')
        .eq('user_id', user.id);
    return [for (final row in rows) row['name'] as String];
  }

  @override
  Future<void> createWatchlist(String name) async {
    RecordAccess.requireService();
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('A watchlist name is required.');
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final user = client.auth.currentUser;
      if (user == null) throw StateError('Sign in to create watchlists.');
      final existing = await client
          .from('watchlists')
          .select('id')
          .eq('user_id', user.id);
      await CustomerLimitations.assertCanCreateWatchlist(
        currentWatchlistCount: existing.length,
      );
      await client.from('watchlists').insert({
        'user_id': user.id,
        'name': clean,
      });
    } else if (!_inMemoryWatchlists.contains(clean)) {
      await CustomerLimitations.assertCanCreateWatchlist(
        currentWatchlistCount: _inMemoryWatchlists.length,
      );
      _inMemoryWatchlists.add(clean);
    }
  }

  @override
  Future<void> addTickerToWatchlist(String watchlistName, String symbol) async {
    RecordAccess.requireService();
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final user = client.auth.currentUser;
      if (user == null) throw StateError('Sign in to save symbols.');
      final list = await client
          .from('watchlists')
          .select('id')
          .eq('user_id', user.id)
          .eq('name', watchlistName)
          .single();
      await client.from('watchlist_items').upsert({
        'watchlist_id': list['id'],
        'ticker': symbol,
      }, onConflict: 'watchlist_id,ticker');
    } else if (!_inMemoryTickers.any((t) => t.symbol == symbol)) {
      _inMemoryTickers.add(await _quoteTicker(symbol));
    }
  }

  @override
  Future<void> removeTickerFromWatchlist(
    String watchlistName,
    String symbol,
  ) async {
    RecordAccess.requireService();
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final user = client.auth.currentUser;
      if (user == null) throw StateError('Sign in to remove symbols.');
      final list = await client
          .from('watchlists')
          .select('id')
          .eq('user_id', user.id)
          .eq('name', watchlistName)
          .single();
      await client
          .from('watchlist_items')
          .delete()
          .eq('watchlist_id', list['id'])
          .eq('ticker', symbol);
    } else {
      _inMemoryTickers.removeWhere((t) => t.symbol == symbol);
    }
  }

  @override
  Future<void> setPriceAlert({
    required String symbol,
    required double threshold,
    required String direction,
  }) async {
    if (!threshold.isFinite ||
        threshold <= 0 ||
        !const {'above', 'below'}.contains(direction)) {
      throw ArgumentError(
        'Use a positive alert price and an above/below direction.',
      );
    }
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (!SupabaseConfig.isConfigured || client == null || user == null) {
      throw StateError('Sign in to a connected account to save price alerts.');
    }
    final items = await client
        .from('watchlist_items')
        .select('id, alert_armed, watchlists!inner(user_id)')
        .eq('ticker', symbol)
        .eq('watchlists.user_id', user.id);
    if (items.isEmpty) {
      throw StateError(
        'Add this symbol to a watchlist before creating an alert.',
      );
    }
    final bool alreadyArmed = items.first['alert_armed'] == true;
    if (!alreadyArmed) {
      final armedRows = await client
          .from('watchlist_items')
          .select('id, watchlists!inner(user_id)')
          .eq('alert_armed', true)
          .eq('watchlists.user_id', user.id);
      await CustomerLimitations.assertCanCreatePriceAlert(
        currentAlertCount: armedRows.length,
      );
    }
    await client
        .from('watchlist_items')
        .update({
          'price_alert_threshold': threshold,
          'price_alert_direction': direction,
          'alert_armed': true,
        })
        .eq('id', items.first['id'])
        .select('id')
        .single();
  }
}
