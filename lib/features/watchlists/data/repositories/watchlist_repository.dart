import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// A named collection of instruments the trader tracks.
@immutable
class Watchlist {
  const Watchlist({
    required this.id,
    required this.name,
    required this.symbols,
  });

  final String id;
  final String name;
  final List<String> symbols;
}

abstract class WatchlistRepository {
  Future<List<Watchlist>> getWatchlists();
  Future<Watchlist> createWatchlist(String name);
  Future<Watchlist> renameWatchlist(String id, String name);
  Future<void> deleteWatchlist(String id);
  Future<List<AppTicker>> getTickers(String watchlistId);
  Future<void> addSymbol(String watchlistId, String symbol);
  Future<void> removeSymbol(String watchlistId, String symbol);
  Future<List<AppTicker>> getHeatmap();
  Future<List<AppCandle>> getCandles(String symbol);
  Future<List<AppPriceAlert>> getAlerts();
  Future<AppPriceAlert> saveAlert(AppPriceAlert alert);
  Future<AppPriceAlert> toggleAlert(String id, bool active);
  Future<void> deleteAlert(String id);
  Future<List<AppNewsItem>> getNews({String? symbol});
  Future<List<AppAiInsight>> getInsights({String? symbol});
  Future<List<String>> getAvailableSymbols();
  Future<({double bullish, double neutral, double bearish})> getSentiment(
    String symbol,
  );
}

class WatchlistRepositoryImpl implements WatchlistRepository {
  WatchlistRepositoryImpl({DemoDataSource? source})
    : _source = source ?? DemoDataSource.instance {
    final List<String> all = _source.symbols;
    _watchlists = <Watchlist>[
      Watchlist(
        id: 'wl_core',
        name: 'Core holdings',
        symbols: all.take(6).toList(),
      ),
      Watchlist(
        id: 'wl_intraday',
        name: 'Intraday scan',
        symbols: all.skip(4).take(5).toList(),
      ),
      Watchlist(
        id: 'wl_index',
        name: 'Index & futures',
        symbols: <String>['NIFTY50', 'BANKNIFTY'],
      ),
    ];
    _alerts = <AppPriceAlert>[
      for (int i = 0; i < 4; i++)
        AppPriceAlert(
          id: 'alr_${i + 1}',
          symbol: all[i],
          targetPrice:
              _source.tickerFor(all[i]).price * (i.isEven ? 1.03 : 0.97),
          above: i.isEven,
          currentPrice: _source.tickerFor(all[i]).price,
          active: i != 3,
          triggeredAt: i == 3
              ? DateTime.now().subtract(const Duration(hours: 5))
              : null,
        ),
    ];
  }

  final DemoDataSource _source;
  late List<Watchlist> _watchlists;
  late List<AppPriceAlert> _alerts;

  @override
  Future<List<Watchlist>> getWatchlists() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return List<Watchlist>.from(_watchlists);
  }

  @override
  Future<Watchlist> createWatchlist(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final Watchlist created = Watchlist(
      id: 'wl_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      symbols: const <String>[],
    );
    _watchlists = <Watchlist>[..._watchlists, created];
    return created;
  }

  @override
  Future<Watchlist> renameWatchlist(String id, String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final Watchlist current = _byId(id);
    final Watchlist renamed = Watchlist(
      id: current.id,
      name: name,
      symbols: current.symbols,
    );
    _watchlists = _watchlists
        .map((Watchlist w) => w.id == id ? renamed : w)
        .toList(growable: false);
    return renamed;
  }

  @override
  Future<void> deleteWatchlist(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _watchlists = _watchlists.where((Watchlist w) => w.id != id).toList();
  }

  Watchlist _byId(String id) => _watchlists.firstWhere(
    (Watchlist w) => w.id == id,
    orElse: () => _watchlists.first,
  );

  @override
  Future<List<AppTicker>> getTickers(String watchlistId) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final Watchlist list = _byId(watchlistId);
    return list.symbols
        .map((String s) => _source.tickerFor(s))
        .toList(growable: false);
  }

  @override
  Future<void> addSymbol(String watchlistId, String symbol) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    _watchlists = _watchlists
        .map(
          (Watchlist w) => w.id == watchlistId && !w.symbols.contains(symbol)
              ? Watchlist(
                  id: w.id,
                  name: w.name,
                  symbols: <String>[...w.symbols, symbol],
                )
              : w,
        )
        .toList();
  }

  @override
  Future<void> removeSymbol(String watchlistId, String symbol) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _watchlists = _watchlists
        .map(
          (Watchlist w) => w.id == watchlistId
              ? Watchlist(
                  id: w.id,
                  name: w.name,
                  symbols: w.symbols
                      .where((String s) => s != symbol)
                      .toList(growable: false),
                )
              : w,
        )
        .toList();
  }

  @override
  Future<List<AppTicker>> getHeatmap() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _source.tickers();
  }

  @override
  Future<List<AppCandle>> getCandles(String symbol) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    return _source.candles(symbol);
  }

  @override
  Future<List<AppPriceAlert>> getAlerts() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return List<AppPriceAlert>.from(_alerts);
  }

  @override
  Future<AppPriceAlert> saveAlert(AppPriceAlert alert) async {
    await Future<void>.delayed(const Duration(milliseconds: 360));
    final int index = _alerts.indexWhere((AppPriceAlert a) => a.id == alert.id);
    if (index >= 0) {
      _alerts[index] = alert;
    } else {
      _alerts = <AppPriceAlert>[alert, ..._alerts];
    }
    return alert;
  }

  @override
  Future<AppPriceAlert> toggleAlert(String id, bool active) async {
    final int index = _alerts.indexWhere((AppPriceAlert a) => a.id == id);
    if (index < 0) throw StateError('Alert $id not found');
    final AppPriceAlert current = _alerts[index];
    final AppPriceAlert updated = AppPriceAlert(
      id: current.id,
      symbol: current.symbol,
      targetPrice: current.targetPrice,
      above: current.above,
      currentPrice: current.currentPrice,
      active: active,
      triggeredAt: current.triggeredAt,
    );
    _alerts[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteAlert(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _alerts = _alerts.where((AppPriceAlert a) => a.id != id).toList();
  }

  @override
  Future<List<AppNewsItem>> getNews({String? symbol}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final List<AppNewsItem> all = _source.news();
    if (symbol == null) return all;
    final List<AppNewsItem> filtered = all
        .where((AppNewsItem n) => n.tickers.contains(symbol))
        .toList(growable: false);
    return filtered.isEmpty ? all : filtered;
  }

  @override
  Future<List<AppAiInsight>> getInsights({String? symbol}) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final List<AppAiInsight> all = _source.insights();
    if (symbol == null) return all;
    final List<AppAiInsight> filtered = all
        .where((AppAiInsight i) => i.tickers.contains(symbol))
        .toList(growable: false);
    return filtered.isEmpty ? all.take(2).toList(growable: false) : filtered;
  }

  @override
  Future<List<String>> getAvailableSymbols() async => _source.symbols;

  @override
  Future<({double bullish, double neutral, double bearish})> getSentiment(
    String symbol,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final double change = _source.tickerFor(symbol).changePercent;
    final double bullish = (50 + change * 6).clamp(8, 88).toDouble();
    final double bearish = (100 - bullish) * 0.7;
    return (
      bullish: bullish,
      neutral: 100 - bullish - bearish,
      bearish: bearish,
    );
  }
}
