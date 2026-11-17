import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';

/// Market intelligence repository.
///
/// In live application runtime (when no custom test [AssetBundle] is injected and
/// [SupabaseConfig.isConfigured] is true), all quotes, fundamentals, price
/// histories, news articles, and screeners are queried directly from the live
/// Supabase database tables (`tickers`, `stock_quotes`, `stock_fundamentals`,
/// `stock_price_history`, `news_articles`, `news_article_tickers`,
/// `screener_categories`, `screener_results`) without reading any bundled files
/// from `assets/data/`.
class AssetMarketRepository {
  AssetMarketRepository({AssetBundle? bundle, this.client})
    : _customBundle = bundle,
      _bundle = bundle ?? rootBundle;
  static AssetMarketRepository shared = AssetMarketRepository();
  final SupabaseClient? client;
  SupabaseClient get _database => client ?? SupabaseConfig.client!;
  final AssetBundle? _customBundle;
  final AssetBundle _bundle;
  final Map<String, Future<dynamic>> _cache = {};
  final Map<String, List<MarketArticle>> _topicCache = {};
  final Map<String, List<MarketInstrument>> _screenerCache = {};
  final Map<String, Map<String, dynamic>> _detailCache = {};
  final Map<String, List<double>> _sparkCache = {};
  final Map<String, Future<List<double>>> _inFlightSparks = {};
  DateTime? _snapshotExpiresAt;
  static const Duration _snapshotTtl = Duration(minutes: 2);

  /// True when this repository should query live Supabase tables instead of
  /// reading bundled JSON assets.
  bool get usesDatabase =>
      _customBundle == null && (client != null || SupabaseConfig.isConfigured);

  Future<dynamic> read(String path) => _cache.putIfAbsent(
    path,
    () async {
      if (usesDatabase) {
        return _readFromDatabase(path);
      }
      if (_customBundle == null) {
        throw StateError('Market database is not configured.');
      }
      return jsonDecode(await _bundle.loadString('assets/data/$path.json'));
    },
  );

  Future<List<Map<String, dynamic>>> _fetchPaged(
    Future<dynamic> Function(int from, int to) fetchPage, {
    int pageSize = 1000,
    int maxRows = 5000,
  }) async {
    final out = <Map<String, dynamic>>[];
    for (var offset = 0; offset < maxRows; offset += pageSize) {
      final to = (offset + pageSize - 1).clamp(offset, maxRows - 1);
      final raw = await fetchPage(offset, to);
      final page = (raw as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      out.addAll(page);
      if (page.length < pageSize) break;
    }
    return out;
  }

  Future<Set<String>?> _loadUniverseSet(SupabaseClient client) async {
    try {
      final rows = await _fetchPaged(
        (from, to) => client
            .from('market_universe')
            .select('ticker')
            .order('rank', ascending: true)
            .range(from, to),
      );
      if (rows.isEmpty) return null;
      return {
        for (final r in rows)
          if ('${r['ticker'] ?? ''}'.isNotEmpty) '${r['ticker']}',
      };
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST205' || error.code == '42P01') return null;
      rethrow;
    }
  }

  Future<dynamic> _readFromDatabase(String path) async {
    final SupabaseClient client = _database;
    if (path == 'tickers/universe') {
      try {
        final universeRows = await _fetchPaged(
          (from, to) => client
              .from('market_universe')
              .select('ticker, display_symbol, rank, name, exchange, sector, market_cap')
              .order('rank', ascending: true)
              .range(from, to),
        );
        if (universeRows.isNotEmpty) {
          return [
            for (final r in universeRows)
              <String, dynamic>{
                ...r,
                'market': 'US',
                'currency': 'USD',
              },
          ];
        }
      } on PostgrestException catch (error) {
        if (error.code != 'PGRST205' && error.code != '42P01') rethrow;
      }
      return _fetchPaged(
        (from, to) => client
            .from('tickers')
            .select('ticker, name, market, exchange, currency, asset_type')
            .order('ticker', ascending: true)
            .range(from, to),
      );
    }
    if (path == 'quotes') {
      final allowed = await _loadUniverseSet(client);
      final rows = await _fetchPaged(
        (from, to) => client
            .from('stock_quotes')
            .select(
              'ticker, price, previous_close, day_high, day_low, volume, change_pct, updated_at',
            )
            .order('ticker', ascending: true)
            .range(from, to),
      );
      final tickersRows = await _fetchPaged(
        (from, to) => client
            .from('tickers')
            .select('ticker, name, market, currency')
            .order('ticker', ascending: true)
            .range(from, to),
      );
      final metaByTicker = <String, Map<String, dynamic>>{
        for (final t in tickersRows) '${t['ticker']}': t,
      };
      final map = <String, Map<String, dynamic>>{};
      for (final raw in rows) {
        final symbol = '${raw['ticker'] ?? ''}';
        if (symbol.isEmpty) continue;
        if (allowed != null && !allowed.contains(symbol)) continue;
        final meta = metaByTicker[symbol] ?? const <String, dynamic>{};
        map[symbol] = <String, dynamic>{
          ...meta,
          ...raw,
          'ticker': symbol,
          'name': meta['name'] ?? symbol,
          'market':
              meta['market'] ??
              (symbol.endsWith('.NS')
                  ? 'IN'
                  : (symbol.endsWith('-USD') ? 'CRYPTO' : 'US')),
          'currency':
              meta['currency'] ?? (symbol.endsWith('.NS') ? 'INR' : 'USD'),
        };
      }
      return map;
    }
    if (path == 'fundamentals') {
      final allowed = await _loadUniverseSet(client);
      final rows = await _fetchPaged(
        (from, to) => client
            .from('stock_fundamentals')
            .select(
              'ticker, market_cap, pe_ratio, sector, industry, dividend_yield, beta, fifty_two_week_high, fifty_two_week_low',
            )
            .order('ticker', ascending: true)
            .range(from, to),
      );
      return <String, Map<String, dynamic>>{
        for (final r in rows)
          if ('${r['ticker'] ?? ''}'.isNotEmpty &&
              (allowed == null || allowed.contains('${r['ticker']}')))
            '${r['ticker']}': r,
      };
    }
    if (path == 'all_news' || path == 'news') {
      final rows = await client
          .from('news_articles')
          .select(
            'id, title, summary, link, publisher, thumbnail_url, content_type, published_at',
          )
          .order('published_at', ascending: false)
          .limit(250);
      final articleIds = (rows as List)
          .whereType<Map>()
          .map((r) => r['id'])
          .where((id) => id != null)
          .toList();
      List<dynamic> tickerLinks = const <dynamic>[];
      if (articleIds.isNotEmpty) {
        try {
          tickerLinks = await client
              .from('news_article_tickers')
              .select('article_id, ticker')
              .inFilter('article_id', articleIds)
              .limit(1000);
        } catch (_) {}
      }
      final tickersByArticle = <String, List<String>>{};
      for (final link in tickerLinks.whereType<Map>()) {
        final aid = '${link['article_id'] ?? ''}';
        final t = '${link['ticker'] ?? ''}';
        if (aid.isNotEmpty && t.isNotEmpty) {
          (tickersByArticle[aid] ??= <String>[]).add(t);
        }
      }
      return [
        for (final raw in (rows as List).whereType<Map>())
          <String, dynamic>{
            ...Map<String, dynamic>.from(raw),
            'related_tickers':
                tickersByArticle['${raw['id']}'] ?? const <String>[],
          },
      ];
    }
    if (path == 'screeners') {
      final allowed = await _loadUniverseSet(client);
      final cats = await client
          .from('screener_categories')
          .select('id, name, category_type')
          .limit(100);
      final results = await client
          .from('screener_results')
          .select('category_id, ticker, rank, price, change_pct, extra_data')
          .order('rank', ascending: true)
          .limit(2000);
      final catNameById = <int, String>{
        for (final c in (cats as List).whereType<Map>())
          if (c['id'] is int && '${c['name'] ?? ''}'.isNotEmpty)
            c['id'] as int: '${c['name']}',
      };
      final out = <String, Map<String, dynamic>>{};
      for (final r in (results as List).whereType<Map>()) {
        final ticker = '${r['ticker'] ?? ''}';
        if (allowed != null && !allowed.contains(ticker)) continue;
        final catName = catNameById[r['category_id']];
        if (catName == null) continue;
        final bucket = out.putIfAbsent(
          catName,
          () => <String, dynamic>{'quotes': <Map<String, dynamic>>[]},
        );
        final list = bucket['quotes'] as List<Map<String, dynamic>>;
        final extra = r['extra_data'] is Map
            ? Map<String, dynamic>.from(r['extra_data'] as Map)
            : <String, dynamic>{};
        list.add(<String, dynamic>{
          ...extra,
          'ticker': r['ticker'],
          'symbol': r['ticker'],
          'price': r['price'] ?? extra['price'] ?? extra['regularMarketPrice'],
          'change_pct':
              r['change_pct'] ??
              extra['change_pct'] ??
              extra['regularMarketChangePercent'],
        });
      }
      return out;
    }
    if (path.startsWith('history/')) {
      final symbol = path.substring('history/'.length);
      final rows = await client
          .from('stock_price_history')
          .select('date, open, high, low, close, volume')
          .eq('ticker', symbol)
          .order('date', ascending: false)
          .limit(730);
      return <String, dynamic>{
        'ticker': symbol,
        'data': [
          for (final r in (rows as List).reversed.whereType<Map>())
            Map<String, dynamic>.from(r),
        ],
      };
    }
    return null;
  }

  /// Safe reader that catches missing file exceptions and returns null
  /// instead of throwing and crashing the entire application.
  Future<dynamic> safeRead(String path) async {
    try {
      return await read(path);
    } catch (_) {
      return null;
    }
  }

  Future<MarketSnapshot>? _snapshot;
  Future<MarketSnapshot> snapshot({bool refresh = false}) {
    final now = DateTime.now();
    final expired =
        _snapshotExpiresAt != null && now.isAfter(_snapshotExpiresAt!);
    if (refresh || expired) {
      _cache.clear();
      _topicCache.clear();
      _screenerCache.clear();
      _detailCache.clear();
      _sparkCache.clear();
      _snapshot = null;
    }
    _snapshotExpiresAt ??= now.add(_snapshotTtl);
    return _snapshot ??= _loadSnapshot().whenComplete(() {
      _snapshotExpiresAt = DateTime.now().add(_snapshotTtl);
    });
  }

  Future<MarketSnapshot> _loadSnapshot() async {
    if (usesDatabase) {
      return _loadDatabaseSnapshot();
    }
    if (_customBundle == null) {
      return const MarketSnapshot(
        instruments: <MarketInstrument>[],
        articles: <MarketArticle>[],
      );
    }
    // 1. Load manifest first (or fallback)
    final manifestRaw = await safeRead('manifest');
    final manifest = Map<String, dynamic>.from(
      manifestRaw is Map ? manifestRaw : {},
    );
    final files = (manifest['files'] as List? ?? [])
        .whereType<String>()
        .toList();

    // 2. Load quotes, fundamentals, articles, details, and screeners safely
    final values = await Future.wait([
      safeRead('quotes'),
      safeRead('fundamentals'),
      safeRead('all_news'),
      safeRead('stock_detail'),
      safeRead('screeners'),
    ]);

    final quotes = Map<String, dynamic>.from(
      values[0] is Map ? values[0] as Map : {},
    );
    final fundamentals = Map<String, dynamic>.from(
      values[1] is Map ? values[1] as Map : {},
    );
    final details = Map<String, dynamic>.from(
      values[3] is Map ? values[3] as Map : {},
    );

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

    // 3. Load sparks only for visible mover candidates
    final ranked = [...instruments]
      ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    final active = [...instruments]
      ..sort((a, b) => b.volume.compareTo(a.volume));
    final sparks = <String, List<double>>{};
    final initialCandidates = {
      ...ranked.take(10),
      ...ranked.reversed.take(10),
      ...active.take(10),
    };

    await Future.wait(
      initialCandidates.map((q) async {
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
      }),
    );

    final enriched = instruments
        .map(
          (q) => sparks.containsKey(q.symbol)
              ? q.withHistory(sparks[q.symbol]!)
              : q,
        )
        .toList();

    // 4. Load articles: support single file ('all_news.json' or 'news.json')
    // and multiple files ('by_topic/*.json')
    final seen = <String>{};
    final List<MarketArticle> articles = [];
    final rawNews = values[2] ?? await safeRead('news');

    if (rawNews is List) {
      for (final raw in rawNews) {
        if (raw is Map) {
          final a = MarketArticle.fromJson(Map<String, dynamic>.from(raw));
          if (a.title.isNotEmpty && seen.add(a.link.isEmpty ? a.title : a.link)) {
            articles.add(a);
          }
        }
      }
      articles.sort(
        (a, b) => (b.publishedAt ?? DateTime(1970)).compareTo(
          a.publishedAt ?? DateTime(1970),
        ),
      );
    }

    // 5. Topics: find topic paths in manifest or use standard categories
    final topicPaths = files
        .where((p) => p.startsWith('by_topic/') && p.endsWith('.json'))
        .toList();

    final topicMap = <String, List<MarketArticle>>{};
    if (topicPaths.isNotEmpty) {
      // Multiple JSON files mode: load topic files
      final topicRows = await Future.wait(
        topicPaths.map((p) => topic(p.substring(9, p.length - 5))),
      );
      for (var i = 0; i < topicPaths.length; i++) {
        final key = topicPaths[i].substring(9, topicPaths[i].length - 5);
        topicMap[key] = topicRows[i];
        if (articles.isEmpty) {
          for (final a in topicRows[i]) {
            if (seen.add(a.link.isEmpty ? a.title : a.link)) {
              articles.add(a);
            }
          }
        }
      }
    } else {
      // Single JSON file mode: filter articles into standard topics
      final standardTopics = [
        'stock_market_general',
        'magnificent_seven',
        'banks_and_financials',
        'enterprise_cloud',
        'pharma_and_biotech',
        'clean_energy',
        'aerospace_and_defense',
        'oil_and_gas',
        'cybersecurity',
        'housing',
        'crypto',
      ];
      for (final t in standardTopics) {
        topicMap[t] = _filterArticlesByTopic(articles, t);
      }
    }

    // 6. Screeners: support single file ('screeners.json') or split files ('screeners/*.json')
    final screenerPayloads = Map<String, dynamic>.from(
      values[4] is Map ? values[4] as Map : {},
    );
    final screens = <String, List<MarketInstrument>>{};

    if (screenerPayloads.isNotEmpty) {
      for (final screen in flattenScreens(screenerPayloads).entries) {
        screens[screen.key] = screen.value
            .map((row) => screenInstrument(row, quotes, fundamentals))
            .whereType<MarketInstrument>()
            .toList();
      }
    } else {
      // Split files mode: discover from manifest
      final screenerFiles = files
          .where((p) => p.startsWith('screeners/') && p.endsWith('.json'))
          .map((p) => p.substring(10, p.length - 5))
          .toList();
      for (final cat in screenerFiles) {
        screens[cat] = <MarketInstrument>[];
      }
      for (final core in ['top_gainers', 'top_losers', 'most_active']) {
        screens[core] = await loadScreener(
          core,
          quotes: quotes,
          fundamentals: fundamentals,
        );
      }
    }

    // Ensure core screens are never empty
    if (!screens.containsKey('top_gainers') || screens['top_gainers']!.isEmpty) {
      screens['top_gainers'] = enriched.where((q) => q.changePercent > 0).toList()
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    }
    if (!screens.containsKey('top_losers') || screens['top_losers']!.isEmpty) {
      screens['top_losers'] = enriched.where((q) => q.changePercent < 0).toList()
        ..sort((a, b) => a.changePercent.compareTo(b.changePercent));
    }
    if (!screens.containsKey('most_active') || screens['most_active']!.isEmpty) {
      screens['most_active'] = [...enriched]
        ..sort((a, b) => b.volume.compareTo(a.volume));
    }

    // Fetch sparks for visible mover candidates in screens
    final visibleSymbols = {
      for (final key in ['top_gainers', 'top_losers', 'most_active'])
        for (final q in (screens[key] ?? <MarketInstrument>[]).take(10))
          q.symbol,
    };
    await Future.wait(
      visibleSymbols.map((symbol) async {
        if (sparks.containsKey(symbol)) return;
        try {
          final rows = (await history(symbol))['data'] as List? ?? [];
          sparks[symbol] = rows
              .map((c) => (c['close'] as num?)?.toDouble())
              .whereType<double>()
              .where((v) => v.isFinite)
              .toList();
        } catch (_) {
          /* Missing history defaults to empty spark */
        }
      }),
    );

    return MarketSnapshot(
      manifest: manifest,
      screenerPayloads: screenerPayloads,
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
      topics: topicMap,
    );
  }

  Future<MarketSnapshot> _loadDatabaseSnapshot() async {
    final values = await Future.wait<dynamic>([
      safeRead('quotes'),
      safeRead('fundamentals'),
      safeRead('all_news'),
      safeRead('screeners'),
    ]);

    final quotes = Map<String, dynamic>.from(
      values[0] is Map ? values[0] as Map : <String, dynamic>{},
    );
    final fundamentals = Map<String, dynamic>.from(
      values[1] is Map ? values[1] as Map : <String, dynamic>{},
    );
    final rawNews = values[2];
    final screenerPayloads = Map<String, dynamic>.from(
      values[3] is Map ? values[3] as Map : <String, dynamic>{},
    );

    final instruments =
        quotes.values
            .whereType<Map>()
            .map((raw) {
              final quote = Map<String, dynamic>.from(raw);
              return MarketInstrument.fromJson(
                quote,
                Map<String, dynamic>.from(
                  fundamentals[quote['ticker']] as Map? ?? <String, dynamic>{},
                ),
              );
            })
            .where((q) => q.price.isFinite)
            .toList()
          ..sort(
            (a, b) => a.market == b.market
                ? a.symbol.compareTo(b.symbol)
                : a.market.compareTo(b.market),
          );

    // A per-symbol limit prevents the server row cap from starving later
    // symbols. Other visible rows load their history on demand.
    final ranked = [...instruments]
      ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    final active = [...instruments]
      ..sort((a, b) => b.volume.compareTo(a.volume));
    final candidateSymbols = <String>{
      for (final q in ranked.take(12)) q.symbol,
      for (final q in ranked.reversed.take(12)) q.symbol,
      for (final q in active.take(12)) q.symbol,
    };
    final sparks = await _loadSparksBatch(candidateSymbols.toList());

    final enriched = instruments
        .map(
          (q) => sparks.containsKey(q.symbol)
              ? q.withHistory(sparks[q.symbol]!)
              : q,
        )
        .toList();

    final seen = <String>{};
    final List<MarketArticle> articles = <MarketArticle>[];
    if (rawNews is List) {
      for (final raw in rawNews.whereType<Map>()) {
        final a = MarketArticle.fromJson(Map<String, dynamic>.from(raw));
        if (a.title.isNotEmpty &&
            seen.add(a.link.isEmpty ? a.title : a.link)) {
          articles.add(a);
        }
      }
      articles.sort(
        (a, b) => (b.publishedAt ?? DateTime(1970)).compareTo(
          a.publishedAt ?? DateTime(1970),
        ),
      );
    }

    const standardTopics = <String>[
      'stock_market_general',
      'magnificent_seven',
      'banks_and_financials',
      'enterprise_cloud',
      'pharma_and_biotech',
      'clean_energy',
      'aerospace_and_defense',
      'oil_and_gas',
      'cybersecurity',
      'housing',
      'crypto',
    ];
    final topicMap = <String, List<MarketArticle>>{
      for (final t in standardTopics) t: _filterArticlesByTopic(articles, t),
    };

    final screens = <String, List<MarketInstrument>>{};
    if (screenerPayloads.isNotEmpty) {
      for (final screen in flattenScreens(screenerPayloads).entries) {
        screens[screen.key] = screen.value
            .map((row) => screenInstrument(row, quotes, fundamentals))
            .whereType<MarketInstrument>()
            .toList();
      }
    }

    if (!screens.containsKey('top_gainers') || screens['top_gainers']!.isEmpty) {
      screens['top_gainers'] =
          enriched.where((q) => q.changePercent > 0).toList()
            ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    }
    if (!screens.containsKey('top_losers') || screens['top_losers']!.isEmpty) {
      screens['top_losers'] =
          enriched.where((q) => q.changePercent < 0).toList()
            ..sort((a, b) => a.changePercent.compareTo(b.changePercent));
    }
    if (!screens.containsKey('most_active') || screens['most_active']!.isEmpty) {
      screens['most_active'] = [...enriched]
        ..sort((a, b) => b.volume.compareTo(a.volume));
    }

    final manifest = <String, dynamic>{
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'data_source': 'supabase_live',
      'quote_count': enriched.length,
      'detail_count': fundamentals.length,
      'history_count': fundamentals.length,
      'source_history_count': fundamentals.length,
    };

    return MarketSnapshot(
      manifest: manifest,
      screenerPayloads: screenerPayloads,
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
      topics: topicMap,
    );
  }

  // Older deployments may not have every supplemental market table. Only
  // missing relations are optional; authentication and transport errors surface.
  Future<T?> _optionalDetailQuery<T>(String table, Future<T> query) async {
    try {
      return await query;
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST205' && error.code != '42P01') rethrow;
      debugPrint('[AssetMarketRepository] Optional table $table is unavailable.');
      return null;
    }
  }

  Future<Map<String, dynamic>> _loadDatabaseDetail(String symbol) async {
    final SupabaseClient client = _database;
    final results = await Future.wait<dynamic>([
      client
          .from('tickers')
          .select('ticker, name, market, exchange, currency, asset_type')
          .eq('ticker', symbol)
          .maybeSingle(),
      client
          .from('stock_quotes')
          .select(
            'ticker, price, previous_close, day_high, day_low, volume, change_pct, updated_at',
          )
          .eq('ticker', symbol)
          .maybeSingle(),
      client
          .from('stock_fundamentals')
          .select(
            'ticker, market_cap, pe_ratio, forward_pe, peg_ratio, eps, sector, industry, fifty_two_week_high, fifty_two_week_low, fifty_day_average, two_hundred_day_average, dividend_yield, beta, avg_volume, shares_outstanding, updated_at',
          )
          .eq('ticker', symbol)
          .maybeSingle(),
      client
          .from('stock_price_history')
          .select('date, open, high, low, close, volume')
          .eq('ticker', symbol)
          .order('date', ascending: false)
          .limit(730),
      _optionalDetailQuery(
        'analyst_recommendations',
        client
            .from('analyst_recommendations')
            .select('ticker, period, strong_buy, buy, hold, sell, strong_sell')
            .eq('ticker', symbol)
            .limit(20),
      ),
      _optionalDetailQuery(
        'holders',
        client
            .from('holders')
            .select(
              'ticker, holder_type, holder_name, shares, date_reported, pct_out, value',
            )
            .eq('ticker', symbol)
            .limit(30),
      ),
      _optionalDetailQuery(
        'dividends',
        client
            .from('dividends')
            .select('ticker, ex_date, amount')
            .eq('ticker', symbol)
            .limit(30),
      ),
      _optionalDetailQuery(
        'stock_splits',
        client
            .from('stock_splits')
            .select('ticker, split_date, ratio')
            .eq('ticker', symbol)
            .limit(20),
      ),
      _optionalDetailQuery(
        'stock_details',
        client
            .from('stock_details')
            .select('detail')
            .eq('ticker', symbol)
            .limit(1)
            .then((rows) => rows.firstOrNull),
      ),
    ]);

    final tickerRow = results[0] is Map
        ? Map<String, dynamic>.from(results[0] as Map)
        : <String, dynamic>{};
    final quoteRow = results[1] is Map
        ? Map<String, dynamic>.from(results[1] as Map)
        : <String, dynamic>{};
    final fundRow = results[2] is Map
        ? Map<String, dynamic>.from(results[2] as Map)
        : <String, dynamic>{};
    final historyRows = (results[3] as List? ?? const <dynamic>[])
        .reversed
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final analystRows = (results[4] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final holderRows = (results[5] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final dividendRows = (results[6] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final splitRows = (results[7] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();

    List<Map<String, dynamic>> companyNews = <Map<String, dynamic>>[];
    try {
      final allArticles = await safeRead('all_news');
      if (allArticles is List) {
        companyNews = allArticles
            .whereType<Map>()
            .where((a) {
              final related = (a['related_tickers'] as List? ?? const <dynamic>[])
                  .map((e) => '$e'.toUpperCase());
              return related.contains(symbol.toUpperCase()) ||
                  '${a['title'] ?? ''}'.toUpperCase().contains(
                    symbol.toUpperCase(),
                  );
            })
            .map((a) => Map<String, dynamic>.from(a))
            .take(15)
            .toList();
      }
    } catch (_) {}

    final storedDetail = results[8] is Map && (results[8] as Map)['detail'] is Map
        ? Map<String, dynamic>.from((results[8] as Map)['detail'] as Map)
        : <String, dynamic>{};

    // Merge company news from stock_details.detail['news'] and global all_news.
    final seenNewsKeys = <String>{};
    final mergedNews = <Map<String, dynamic>>[];
    void addNewsItem(Map<String, dynamic> item) {
      final link = '${item['link'] ?? ''}';
      final title = '${item['title'] ?? ''}';
      final key = link.isNotEmpty ? link : title;
      if (key.isEmpty || !seenNewsKeys.add(key)) return;
      mergedNews.add(item);
    }

    for (final raw in (storedDetail['news'] as List? ?? const <dynamic>[]).whereType<Map>()) {
      addNewsItem(Map<String, dynamic>.from(raw));
    }
    for (final item in companyNews) {
      addNewsItem(item);
    }

    final storedQuote = storedDetail['quote'] is Map
        ? Map<String, dynamic>.from(storedDetail['quote'] as Map)
        : const <String, dynamic>{};
    final mergedQuote = <String, dynamic>{
      ...storedQuote,
      ...tickerRow,
      ...quoteRow,
      'ticker': symbol,
      'price': quoteRow['price'] ?? storedQuote['price'] ?? 0.0,
      'name': tickerRow['name'] ?? fundRow['name'] ?? storedQuote['name'] ?? symbol,
      'market':
          tickerRow['market'] ??
          storedQuote['market'] ??
          (symbol.endsWith('.NS')
              ? 'IN'
              : (symbol.endsWith('-USD') ? 'CRYPTO' : 'US')),
      'currency':
          tickerRow['currency'] ??
          storedQuote['currency'] ??
          (symbol.endsWith('.NS') ? 'INR' : 'USD'),
    };

    final storedSummary = storedDetail['summary'] is Map
        ? Map<String, dynamic>.from(storedDetail['summary'] as Map)
        : const <String, dynamic>{};
    final mergedSummary = <String, dynamic>{
      ...storedSummary,
      'name': tickerRow['name'] ?? storedSummary['name'] ?? symbol,
      'market': mergedQuote['market'],
      'exchange': tickerRow['exchange'] ?? storedSummary['exchange'],
      'currency': mergedQuote['currency'],
      ...fundRow,
    };

    final storedChart = storedDetail['chart'] is Map
        ? Map<String, dynamic>.from(storedDetail['chart'] as Map)
        : const <String, dynamic>{};
    final chartData = historyRows.isNotEmpty
        ? historyRows
        : (storedChart['data'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();

    final normalizedDividends = [
      for (final r in dividendRows)
        <String, dynamic>{
          ...r,
          'date': r['date'] ?? r['ex_date'],
        },
    ];
    final normalizedSplits = [
      for (final r in splitRows)
        <String, dynamic>{
          ...r,
          'date': r['date'] ?? r['split_date'],
        },
    ];
    final storedActions = storedDetail['dividends_and_splits'] is Map
        ? Map<String, dynamic>.from(storedDetail['dividends_and_splits'] as Map)
        : const <String, dynamic>{};
    final mergedDividends = normalizedDividends.isNotEmpty
        ? normalizedDividends
        : (storedActions['dividends'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
    final mergedSplits = normalizedSplits.isNotEmpty
        ? normalizedSplits
        : (storedActions['splits'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();

    final normalizedRecs = [
      for (final r in analystRows)
        <String, dynamic>{
          ...r,
          'strongBuy': r['strongBuy'] ?? r['strong_buy'] ?? 0,
          'buy': r['buy'] ?? 0,
          'hold': r['hold'] ?? 0,
          'sell': r['sell'] ?? 0,
          'strongSell': r['strongSell'] ?? r['strong_sell'] ?? 0,
        },
    ];
    final mergedRecs = normalizedRecs.isNotEmpty
        ? normalizedRecs
        : (storedDetail['recommendations'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();

    Map<String, dynamic> normalizeHolder(Map<String, dynamic> r) => <String, dynamic>{
      ...r,
      if (r['Holder'] == null && r['holder_name'] != null) 'Holder': r['holder_name'],
      if (r['pctHeld'] == null && r['pct_out'] != null) 'pctHeld': r['pct_out'],
      if (r['Shares'] == null && r['shares'] != null) 'Shares': r['shares'],
      if (r['Value'] == null && r['value'] != null) 'Value': r['value'],
      if (r['Date Reported'] == null && r['date_reported'] != null)
        'Date Reported': r['date_reported'],
    };
    final normalizedHolders = holderRows.map(normalizeHolder).toList();
    final storedHolders = storedDetail['holders'] is Map
        ? Map<String, dynamic>.from(storedDetail['holders'] as Map)
        : const <String, dynamic>{};
    final mergedHolders = normalizedHolders.isNotEmpty
        ? <String, dynamic>{
            'major_holders': normalizedHolders
                .where((h) => '${h['holder_type']}' == 'major')
                .toList(),
            'institutional_holders': normalizedHolders
                .where((h) => '${h['holder_type']}'.contains('institution'))
                .toList(),
            'mutual_fund_holders': normalizedHolders
                .where((h) => '${h['holder_type']}'.contains('mutual'))
                .toList(),
          }
        : storedHolders;

    final mergedOptions = storedDetail['options'] is Map
        ? Map<String, dynamic>.from(storedDetail['options'] as Map)
        : const <String, dynamic>{'expirations': <dynamic>[], 'chains': <String, dynamic>{}};

    final res = <String, dynamic>{
      'ticker': symbol,
      'market': mergedQuote['market'],
      'quote': mergedQuote,
      'summary': mergedSummary,
      'chart': <String, dynamic>{
        ...storedChart,
        'ticker': symbol,
        'data': chartData,
      },
      'news': mergedNews.take(15).toList(),
      'recommendations': mergedRecs,
      'analyst_recommendations': mergedRecs,
      'holders': mergedHolders,
      'dividends_and_splits': <String, dynamic>{
        'dividends': mergedDividends,
        'splits': mergedSplits,
      },
      'options': mergedOptions,
      if (storedDetail['universe'] != null) 'universe': storedDetail['universe'],
      if (storedDetail['availability'] != null)
        'availability': storedDetail['availability'],
      if (storedDetail['snapshot'] != null) 'snapshot': storedDetail['snapshot'],
      'data_source': 'supabase_live',
      'fetched_at':
          quoteRow['updated_at'] ??
          fundRow['updated_at'] ??
          storedDetail['updated_at'],
    };
    _detailCache[symbol] = res;
    return res;
  }

  /// Lazy loads instrument detail dossier from live Supabase tables (in app runtime)
  /// or from split/consolidated JSON files when a test [AssetBundle] is injected.
  Future<Map<String, dynamic>> detail(String symbol) async {
    if (_detailCache.containsKey(symbol)) {
      return _detailCache[symbol]!;
    }
    if (usesDatabase) {
      return _loadDatabaseDetail(symbol);
    }

    // 1. Multiple files mode: try stock_detail/$symbol.json
    final singleFile = await safeRead('stock_detail/$symbol');
    if (singleFile is Map) {
      final res = Map<String, dynamic>.from(singleFile);
      _detailCache[symbol] = res;
      return res;
    }

    // 2. Single file mode: try stock_detail.json[symbol]
    final allDetails = await safeRead('stock_detail');
    if (allDetails is Map && allDetails[symbol] is Map) {
      final res = Map<String, dynamic>.from(allDetails[symbol] as Map);
      _detailCache[symbol] = res;
      return res;
    }

    // 3. Fallback: resolve from quotes and screeners
    final quotesRaw = await safeRead('quotes');
    final quotes = quotesRaw is Map ? quotesRaw : {};
    Map? quote = quotes[symbol] as Map?;

    if (quote == null) {
      final scRaw = await safeRead('screeners');
      if (scRaw is Map) {
        for (final rows in flattenScreens(scRaw).values) {
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
                break;
              }
            }
          }
          if (quote != null) break;
        }
      }
    }

    if (quote == null) {
      final universeRaw = await safeRead('tickers/universe');
      if (universeRaw is List) {
        final row = universeRaw
            .whereType<Map>()
            .where((r) => r['ticker'] == symbol)
            .firstOrNull;
        if (row != null) {
          final fundsRaw = await safeRead('fundamentals');
          final funds = fundsRaw is Map ? fundsRaw : {};
          final res = {
            'ticker': symbol,
            'market': row['market'],
            'quote': <String, dynamic>{},
            'summary':
                funds[symbol] ??
                {'name': row['name'] ?? symbol, 'market': row['market']},
            'chart': {'data': []},
            'data_source': 'directory_only',
          };
          _detailCache[symbol] = res;
          return res;
        }
      }
    }

    final fundsRaw = await safeRead('fundamentals');
    final funds = fundsRaw is Map ? fundsRaw : {};
    Map<String, dynamic> chart;
    try {
      chart = await history(symbol);
    } catch (_) {
      chart = {'data': []};
    }

    final res = {
      'ticker': symbol,
      'market': quote?['market'] ?? '',
      'quote': quote ?? {'ticker': symbol, 'price': 0.0},
      'summary': funds[symbol] ?? {'name': quote?['name'] ?? symbol},
      'chart': chart,
      'data_source': 'quote_and_history',
      'fetched_at': quote?['updated_at'],
    };
    _detailCache[symbol] = res;
    return res;
  }

  Future<Map<String, dynamic>> history(String symbol) async {
    final hist = await safeRead('history/$symbol');
    if (hist is Map) {
      return Map<String, dynamic>.from(hist);
    }
    return {'data': []};
  }

  Future<Map<String, List<double>>> _loadSparksBatch(List<String> symbols) async {
    final out = <String, List<double>>{};
    final missing = <String>[];
    for (final sym in symbols) {
      final cached = _sparkCache[sym];
      if (cached != null) {
        out[sym] = cached;
      } else if (!missing.contains(sym)) {
        missing.add(sym);
      }
    }
    if (missing.isEmpty) return out;
    if (!usesDatabase) {
      for (var offset = 0; offset < missing.length; offset += 6) {
        await Future.wait(
          missing.skip(offset).take(6).map((symbol) async {
            out[symbol] = await getSpark(symbol);
          }),
        );
      }
      return out;
    }

    // Batch up to 20 symbols per query so total rows stay well below PostgREST limits.
    final futures = <Future<void>>[];
    for (var offset = 0; offset < missing.length; offset += 20) {
      final chunk = missing.skip(offset).take(20).toList();
      futures.add(() async {
        try {
          final rows = await _database
              .from('stock_price_history')
              .select('ticker, date, close')
              .inFilter('ticker', chunk)
              .order('date', ascending: false)
              .limit(chunk.length * 36);
          final groupedDesc = <String, List<double>>{};
          for (final r in (rows as List).whereType<Map>()) {
            final t = '${r['ticker'] ?? ''}';
            final close = (r['close'] as num?)?.toDouble();
            if (t.isEmpty || close == null || !close.isFinite) continue;
            final list = groupedDesc.putIfAbsent(t, () => <double>[]);
            if (list.length < 36) list.add(close);
          }
          for (final sym in chunk) {
            final chronological =
                (groupedDesc[sym] ?? const <double>[]).reversed.toList();
            _sparkCache[sym] = chronological;
            out[sym] = chronological;
          }
        } catch (_) {
          // Leave missing symbols empty so on-demand getSpark can retry later.
        }
      }());
    }
    await Future.wait(futures);
    return out;
  }

  /// Lazy sparkline loader for on-demand chart rendering
  Future<List<double>> getSpark(String symbol) async {
    if (_sparkCache.containsKey(symbol)) {
      return _sparkCache[symbol]!;
    }
    final existing = _inFlightSparks[symbol];
    if (existing != null) {
      return existing;
    }
    final future = () async {
      final List rows;
      if (usesDatabase) {
        try {
          final result = await _database
              .from('stock_price_history')
              .select('date, close')
              .eq('ticker', symbol)
              .order('date', ascending: false)
              .limit(36);
          rows = result.reversed.toList();
        } catch (_) {
          return const <double>[]; // Allow the next request to retry a temporary outage.
        }
      } else {
        final hist = await history(symbol);
        rows = hist['data'] as List? ?? [];
      }
      final spark = rows
          .map((c) => (c['close'] as num?)?.toDouble())
          .whereType<double>()
          .where((v) => v.isFinite)
          .toList();
      _sparkCache[symbol] = spark;
      return spark;
    }();
    _inFlightSparks[symbol] = future;
    try {
      return await future;
    } finally {
      _inFlightSparks.remove(symbol);
    }
  }

  Future<Map<String, dynamic>> screeners() async {
    final raw = await safeRead('screeners');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  /// Lazy loads a specific screener category from either split files ('screeners/$category.json')
  /// or consolidated 'screeners.json'.
  Future<List<MarketInstrument>> loadScreener(
    String category, {
    Map quotes = const {},
    Map fundamentals = const {},
  }) async {
    if (_screenerCache.containsKey(category)) {
      return _screenerCache[category]!;
    }

    Map qMap = quotes;
    Map fMap = fundamentals;
    if (qMap.isEmpty) {
      final qRaw = await safeRead('quotes');
      if (qRaw is Map) qMap = qRaw;
    }
    if (fMap.isEmpty) {
      final fRaw = await safeRead('fundamentals');
      if (fRaw is Map) fMap = fRaw;
    }

    // 1. Try split file mode: 'screeners/$category.json'
    final fileRaw = await safeRead('screeners/$category');
    if (fileRaw != null) {
      List rows = [];
      if (fileRaw is List) {
        rows = fileRaw;
      } else if (fileRaw is Map) {
        if (fileRaw['quotes'] is List) {
          rows = fileRaw['quotes'] as List;
        } else {
          final flat = flattenScreens({category: fileRaw});
          if (flat.containsKey(category)) {
            rows = flat[category]!;
          }
        }
      }
      final instruments = rows
          .whereType<Map>()
          .map((r) => screenInstrument(Map<String, dynamic>.from(r), qMap, fMap))
          .whereType<MarketInstrument>()
          .toList();
      _screenerCache[category] = instruments;
      return instruments;
    }

    // 2. Try single file mode: 'screeners.json'
    final allScreeners = await safeRead('screeners');
    if (allScreeners is Map) {
      final flat = flattenScreens(allScreeners);
      if (flat.containsKey(category)) {
        final instruments = flat[category]!
            .map((r) => screenInstrument(r, qMap, fMap))
            .whereType<MarketInstrument>()
            .toList();
        _screenerCache[category] = instruments;
        return instruments;
      }
    }

    // 3. Fallback: synthesize from quotes universe
    if (category == 'top_gainers' || category == 'top_losers' || category == 'most_active') {
      final universe = qMap.values
          .whereType<Map>()
          .map((r) => screenInstrument(Map<String, dynamic>.from(r), qMap, fMap))
          .whereType<MarketInstrument>()
          .where((i) => i.price.isFinite)
          .toList();
      if (category == 'top_gainers') {
        final gainers = universe.where((q) => q.changePercent > 0).toList()
          ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
        _screenerCache[category] = gainers;
        return gainers;
      }
      if (category == 'top_losers') {
        final losers = universe.where((q) => q.changePercent < 0).toList()
          ..sort((a, b) => a.changePercent.compareTo(b.changePercent));
        _screenerCache[category] = losers;
        return losers;
      }
      if (category == 'most_active') {
        final active = [...universe]..sort((a, b) => b.volume.compareTo(a.volume));
        _screenerCache[category] = active;
        return active;
      }
    }

    _screenerCache[category] = <MarketInstrument>[];
    return <MarketInstrument>[];
  }

  /// Lazy loads articles for a specific topic on demand from either split files ('by_topic/$topic.json')
  /// or filtering from consolidated 'all_news.json'.
  Future<List<MarketArticle>> loadTopic(
    String topicKey, {
    List<MarketArticle>? fallbackArticles,
  }) async {
    if (_topicCache.containsKey(topicKey)) {
      return _topicCache[topicKey]!;
    }

    // 1. Multiple files mode: try 'by_topic/$topicKey.json'
    final raw = await safeRead('by_topic/$topicKey');
    if (raw is List) {
      final list = raw
          .whereType<Map>()
          .map((m) => MarketArticle.fromJson(Map<String, dynamic>.from(m)))
          .where((a) => a.title.isNotEmpty)
          .toList();
      _topicCache[topicKey] = list;
      return list;
    }

    // 2. Single file mode: filter from all_news or provided fallback articles
    final sourceArticles = fallbackArticles ?? await _loadAllArticles();
    final filtered = _filterArticlesByTopic(sourceArticles, topicKey);
    _topicCache[topicKey] = filtered;
    return filtered;
  }

  Future<List<MarketArticle>> _loadAllArticles() async {
    final raw = await safeRead('all_news') ?? await safeRead('news');
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => MarketArticle.fromJson(Map<String, dynamic>.from(m)))
          .where((a) => a.title.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<List<MarketArticle>> topic(String topic) => loadTopic(topic);
}

/// Categorizes news articles into topics when running from a single consolidated JSON file.
List<MarketArticle> _filterArticlesByTopic(List<MarketArticle> articles, String topicKey) {
  final key = topicKey.toLowerCase();
  switch (key) {
    case 'magnificent_seven':
      const mag7 = {'AAPL', 'MSFT', 'GOOGL', 'GOOG', 'AMZN', 'NVDA', 'META', 'TSLA'};
      return articles.where((a) => a.tickers.any((t) => mag7.contains(t.toUpperCase()))).toList();
    case 'crypto':
      return articles.where((a) =>
        a.tickers.any((t) => t.endsWith('-USD') || t == 'BTC' || t == 'ETH' || t == 'SOL' || t == 'XRP') ||
        a.title.toLowerCase().contains('crypto') ||
        a.title.toLowerCase().contains('bitcoin')
      ).toList();
    case 'banks_and_financials':
      return articles.where((a) =>
        a.tickers.any((t) => {'JPM', 'BAC', 'WFC', 'C', 'GS', 'MS', 'HDFCBANK.NS', 'ICICIBANK.NS', 'SBIN.NS'}.contains(t.toUpperCase())) ||
        a.title.toLowerCase().contains('bank') ||
        a.title.toLowerCase().contains('treasury') ||
        a.title.toLowerCase().contains('yield') ||
        a.title.toLowerCase().contains('fed')
      ).toList();
    case 'enterprise_cloud':
      return articles.where((a) =>
        a.tickers.any((t) => {'CRM', 'NOW', 'SNOW', 'ORCL', 'ADBE', 'MSFT', 'INFY.NS', 'TCS.NS'}.contains(t.toUpperCase())) ||
        a.title.toLowerCase().contains('cloud') ||
        a.title.toLowerCase().contains('software') ||
        a.title.toLowerCase().contains('ai')
      ).toList();
    case 'pharma_and_biotech':
      return articles.where((a) =>
        a.tickers.any((t) => {'LLY', 'NVO', 'PFE', 'MRK', 'ABBV', 'JNJ'}.contains(t.toUpperCase())) ||
        a.title.toLowerCase().contains('pharma') ||
        a.title.toLowerCase().contains('drug') ||
        a.title.toLowerCase().contains('biotech') ||
        a.title.toLowerCase().contains('fda')
      ).toList();
    case 'clean_energy':
      return articles.where((a) =>
        a.tickers.any((t) => {'TSLA', 'ENPH', 'SEDG', 'FSLR', 'NEE'}.contains(t.toUpperCase())) ||
        a.title.toLowerCase().contains('energy') ||
        a.title.toLowerCase().contains('solar') ||
        a.title.toLowerCase().contains('ev')
      ).toList();
    case 'aerospace_and_defense':
      return articles.where((a) =>
        a.tickers.any((t) => {'BA', 'LMT', 'RTX', 'NOC', 'GD'}.contains(t.toUpperCase())) ||
        a.title.toLowerCase().contains('aerospace') ||
        a.title.toLowerCase().contains('defense') ||
        a.title.toLowerCase().contains('boeing')
      ).toList();
    case 'oil_and_gas':
      return articles.where((a) =>
        a.tickers.any((t) => {'XOM', 'CVX', 'COP', 'BP', 'SHEL', 'RELIANCE.NS'}.contains(t.toUpperCase())) ||
        a.title.toLowerCase().contains('oil') ||
        a.title.toLowerCase().contains('gas') ||
        a.title.toLowerCase().contains('crude')
      ).toList();
    case 'cybersecurity':
      return articles.where((a) =>
        a.tickers.any((t) => {'CRWD', 'PANW', 'FTNT', 'ZS', 'NET'}.contains(t.toUpperCase())) ||
        a.title.toLowerCase().contains('cyber') ||
        a.title.toLowerCase().contains('hack') ||
        a.title.toLowerCase().contains('security')
      ).toList();
    case 'housing':
      return articles.where((a) =>
        a.tickers.any((t) => {'DHI', 'LEN', 'TOL', 'HD', 'LOW'}.contains(t.toUpperCase())) ||
        a.title.toLowerCase().contains('housing') ||
        a.title.toLowerCase().contains('mortgage') ||
        a.title.toLowerCase().contains('home')
      ).toList();
    case 'stock_market_general':
    default:
      final matches = articles.where((a) =>
        a.title.toLowerCase().contains(key.replaceAll('_', ' ')) ||
        a.summary.toLowerCase().contains(key.replaceAll('_', ' '))
      ).toList();
      return matches.isNotEmpty ? matches : articles.take(15).toList();
  }
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
