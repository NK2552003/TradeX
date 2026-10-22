import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';

/// Sole asset adapter for the finance kits. Symbols are kept exactly as exported.
class AssetMarketRepository {
  AssetMarketRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  static AssetMarketRepository shared = AssetMarketRepository();
  final AssetBundle _bundle;
  final Map<String, Future<dynamic>> _cache = {};
  Future<dynamic> read(String path) => _cache.putIfAbsent(
    path,
    () async => jsonDecode(await _bundle.loadString('assets/data/$path.json')),
  );
  Future<MarketSnapshot>? _snapshot;
  Future<MarketSnapshot> snapshot({bool refresh = false}) {
    if (refresh) {
      _cache.clear();
      _snapshot = null;
    }
    return _snapshot ??= _loadSnapshot();
  }

  Future<MarketSnapshot> _loadSnapshot() async {
    final values = await Future.wait([
      read('quotes'),
      read('fundamentals'),
      read('all_news'),
      read('stock_detail'),
      read('manifest'),
      read('screeners'),
    ]);
    final quotes = Map<String, dynamic>.from(values[0] as Map);
    final fundamentals = Map<String, dynamic>.from(values[1] as Map);
    final details = Map<String, dynamic>.from(values[3] as Map);
    final instruments =
        quotes.values
            .map((raw) {
              final quote = Map<String, dynamic>.from(raw as Map);
              return MarketInstrument.fromJson(
                quote,
                Map<String, dynamic>.from(
                  (details[quote['ticker']] as Map?)?['summary'] as Map? ??
                      fundamentals[quote['ticker']] as Map? ??
                      {},
                ),
                history:
                    (((details[quote['ticker']] as Map?)?['chart']
                                    as Map?)?['data']
                                as List? ??
                            [])
                        .map((c) => (c['close'] as num).toDouble())
                        .where((v) => v.isFinite)
                        .toList(),
              );
            })
            .where((q) => q.price.isFinite)
            .toList()
          ..sort(
            (a, b) => a.market == b.market
                ? a.symbol.compareTo(b.symbol)
                : a.market.compareTo(b.market),
          );
    // Load price history only for visible mover candidates; a full universe can
    // contain thousands of files, so avoid eagerly decoding every history.
    final ranked = [...instruments]
      ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    final active = [...instruments]
      ..sort((a, b) => b.volume.compareTo(a.volume));
    final sparks = <String, List<double>>{};
    await Future.wait(
      {...ranked.take(10), ...ranked.reversed.take(10), ...active.take(10)}.map(
        (q) async {
          if (q.spark.isNotEmpty) return;
          try {
            final rows = (await history(q.symbol))['data'] as List? ?? [];
            sparks[q.symbol] = rows
                .map((c) => (c['close'] as num?)?.toDouble())
                .whereType<double>()
                .where((v) => v.isFinite)
                .toList();
          } catch (_) {
            /* A missing provider history is an explicit empty spark. */
          }
        },
      ),
    );
    final enriched = instruments
        .map(
          (q) => sparks.containsKey(q.symbol)
              ? q.withHistory(sparks[q.symbol]!)
              : q,
        )
        .toList();
    final seen = <String>{};
    final articles =
        (values[2] as List)
            .map(
              (raw) =>
                  MarketArticle.fromJson(Map<String, dynamic>.from(raw as Map)),
            )
            .where(
              (a) =>
                  a.title.isNotEmpty &&
                  seen.add(a.link.isEmpty ? a.title : a.link),
            )
            .toList()
          ..sort(
            (a, b) => (b.publishedAt ?? DateTime(1970)).compareTo(
              a.publishedAt ?? DateTime(1970),
            ),
          );
    final paths = ((values[4] as Map)['files'] as List)
        .whereType<String>()
        .where((p) => p.startsWith('by_topic/') && p.endsWith('.json'))
        .toList();
    final topicRows = await Future.wait(
      paths.map((p) => topic(p.substring(9, p.length - 5))),
    );
    final screens = {
      for (final screen in flattenScreens(values[5] as Map).entries)
        screen.key: screen.value
            .map((row) => screenInstrument(row, quotes, fundamentals))
            .whereType<MarketInstrument>()
            .toList(),
    };
    final visibleSymbols = {
      for (final key in ['top_gainers', 'top_losers', 'most_active'])
        for (final q in (screens[key] ?? <MarketInstrument>[]).take(10))
          q.symbol,
    };
    await Future.wait(
      visibleSymbols.map((symbol) async {
        try {
          final rows = (await history(symbol))['data'] as List? ?? [];
          sparks[symbol] = rows
              .map((c) => (c['close'] as num?)?.toDouble())
              .whereType<double>()
              .where((v) => v.isFinite)
              .toList();
        } catch (_) {
          /* Not every screen result has a tracked history. */
        }
      }),
    );
    return MarketSnapshot(
      manifest: Map<String, dynamic>.from(values[4] as Map),
      screenerPayloads: Map<String, dynamic>.from(values[5] as Map),
      instruments: enriched,
      screeners: {
        for (final entry in screens.entries)
          entry.key: entry.value
              .map(
                (q) => sparks.containsKey(q.symbol)
                    ? q.withHistory(sparks[q.symbol]!)
                    : q,
              )
              .toList(),
      },
      articles: articles,
      topics: {
        for (var i = 0; i < paths.length; i++)
          paths[i].substring(9, paths[i].length - 5): topicRows[i],
      },
    );
  }

  Future<Map<String, dynamic>> detail(String symbol) async {
    try {
      return Map<String, dynamic>.from(
        await read('stock_detail/$symbol') as Map,
      );
    } catch (_) {
      final quotes = await read('quotes') as Map;
      Map? quote = quotes[symbol] as Map?;
      if (quote == null) {
        for (final rows in flattenScreens(
          await read('screeners') as Map,
        ).values) {
          for (final row in rows) {
            if ((row['symbol'] ?? row['ticker']) == symbol) {
              final q = screenInstrument(row, quotes, {});
              if (q != null) {
                quote = {
                  'ticker': symbol,
                  'market': q.market,
                  'price': q.price,
                  'change_pct': q.changePercent,
                  'currency': q.currency,
                  'name': q.name,
                };
              }
            }
          }
        }
      }
      if (quote == null) {
        final directory = await read('tickers/universe') as List;
        final row = directory
            .whereType<Map>()
            .where((row) => row['ticker'] == symbol)
            .firstOrNull;
        if (row == null) rethrow;
        final funds = await read('fundamentals') as Map;
        return {
          'ticker': symbol,
          'market': row['market'],
          'quote': <String, dynamic>{},
          'summary':
              funds[symbol] ??
              {'name': row['name'] ?? symbol, 'market': row['market']},
          'chart': {'data': []},
          'data_source': 'directory_only',
        };
      }
      final funds = await read('fundamentals') as Map;
      Map<String, dynamic> chart;
      try {
        chart = await history(symbol);
      } catch (_) {
        chart = {'data': []};
      }
      return {
        'ticker': symbol,
        'market': quote['market'],
        'quote': quote,
        'summary': funds[symbol] ?? {'name': quote['name'] ?? symbol},
        'chart': chart,
        'data_source': 'quote_and_history',
        'fetched_at': quote['updated_at'],
      };
    }
  }

  Future<Map<String, dynamic>> history(String symbol) async {
    return Map<String, dynamic>.from(await read('history/$symbol') as Map);
  }

  Future<Map<String, dynamic>> screeners() async =>
      Map<String, dynamic>.from(await read('screeners') as Map);
  Future<List<MarketArticle>> topic(String topic) async =>
      (await read('by_topic/$topic') as List)
          .map(
            (raw) =>
                MarketArticle.fromJson(Map<String, dynamic>.from(raw as Map)),
          )
          .toList();
}

Map<String, List<Map<String, dynamic>>> flattenScreens(Map raw) {
  final result = <String, List<Map<String, dynamic>>>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is List || value is Map && value['quotes'] is List) {
      final rows = value is List ? value : value['quotes'] as List;
      result['${entry.key}'] = rows
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } else if (entry.key == 'sector_breakdown' && value is Map) {
      result['${entry.key}'] = [
        for (final e in value.entries)
          if (e.value is Map)
            {'name': e.key, ...Map<String, dynamic>.from(e.value as Map)},
      ];
    } else if (entry.key == 'world_indices_by_continent' && value is Map) {
      for (final region in value.entries) {
        result['Indices · ${region.key}'] = [
          for (final e in (region.value as Map).entries)
            if (e.value is Map)
              {'ticker': e.key, ...Map<String, dynamic>.from(e.value as Map)},
        ];
      }
    }
  }
  return result;
}

MarketInstrument? screenInstrument(
  Map<String, dynamic> row,
  Map quotes,
  Map funds,
) {
  final symbol = row['symbol'] ?? row['ticker'];
  if (symbol is! String) return null;
  final quote = quotes[symbol] as Map? ?? {};
  final price = row['regularMarketPrice'] ?? row['price'] ?? quote['price'];
  if (price is! num || !price.isFinite) return null;
  final change = row['regularMarketChange'] as num?;
  return MarketInstrument.fromJson({
    ...row,
    ...quote,
    'ticker': symbol,
    'price': price,
    'name':
        row['longName'] ??
        row['shortName'] ??
        row['name'] ??
        quote['name'] ??
        symbol,
    'change_pct':
        row['regularMarketChangePercent'] ??
        row['change_pct'] ??
        quote['change_pct'] ??
        0,
    'previous_close': change != null ? price - change : quote['previous_close'],
    'volume': row['regularMarketVolume'] ?? quote['volume'] ?? 0,
    'currency':
        row['currency'] ??
        quote['currency'] ??
        (symbol.endsWith('.NS') ? 'INR' : 'USD'),
    'market': quote['market'] ?? (symbol.endsWith('-USD') ? 'CRYPTO' : 'US'),
  }, Map<String, dynamic>.from(funds[symbol] as Map? ?? {}));
}
