import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';

/// Sole asset adapter for the finance kits. Symbols are kept exactly as exported.
class AssetMarketRepository {
  AssetMarketRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
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
      {...ranked.take(50), ...ranked.reversed.take(50), ...active.take(50)}.map(
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
              ? MarketInstrument.fromJson(
                  Map<String, dynamic>.from(quotes[q.symbol] as Map),
                  Map<String, dynamic>.from(
                    fundamentals[q.symbol] as Map? ?? {},
                  ),
                  history: sparks[q.symbol]!,
                )
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
    return MarketSnapshot(
      instruments: enriched,
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
      if (!quotes.containsKey(symbol)) rethrow;
      final funds = await read('fundamentals') as Map;
      Map<String, dynamic> chart;
      try {
        chart = await history(symbol);
      } catch (_) {
        chart = {'data': []};
      }
      return {
        'ticker': symbol,
        'market': (quotes[symbol] as Map)['market'],
        'quote': quotes[symbol],
        'summary': funds[symbol] ?? {},
        'chart': chart,
        'data_source': 'quote_and_history',
        'fetched_at': (quotes[symbol] as Map)['updated_at'],
      };
    }
  }

  Future<Map<String, dynamic>> history(String symbol) async =>
      Map<String, dynamic>.from(await read('history/$symbol') as Map);
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
