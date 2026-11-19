import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';

class MarketPageResult<T> {
  const MarketPageResult({required this.items, required this.totalCount});
  final List<T> items;
  final int totalCount;
}

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
  Future<MarketSnapshot>? _communityPreviewSnapshot;
  DateTime? _communityPreviewExpiresAt;
  static const Duration _snapshotTtl = Duration(minutes: 5);
  static const Duration _communityPreviewTtl = Duration(minutes: 15);

  /// True when this repository should query live Supabase tables instead of
  /// reading bundled JSON assets.
  bool get usesDatabase =>
      _customBundle == null && (client != null || SupabaseConfig.isConfigured);

  Future<dynamic> read(String path) => _cache.putIfAbsent(path, () async {
    if (usesDatabase) {
      return _readFromDatabase(path);
    }
    if (_customBundle == null) {
      throw StateError('Market database is not configured.');
    }
    return jsonDecode(await _bundle.loadString('assets/data/$path.json'));
  });

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

  Future<int> _exactCount(String table) async {
    try {
      return await _database.from(table).count(CountOption.exact);
    } catch (_) {
      return 0;
    }
  }

  static const List<String> _knownSectors = <String>[
    'Technology',
    'Financial Services',
    'Healthcare',
    'Consumer Cyclical',
    'Industrials',
    'Communication Services',
    'Energy',
    'Consumer Defensive',
    'Basic Materials',
    'Real Estate',
    'Utilities',
    'Finance',
  ];

  Future<Map<String, int>> _loadSectorCounts(int maxTotal) async {
    if (maxTotal <= 0) return const <String, int>{};
    try {
      final counts = await Future.wait<int>([
        for (final sector in _knownSectors)
          _database
              .from('stock_fundamentals')
              .count(CountOption.exact)
              .eq('sector', sector)
              .catchError((_) => 0),
      ]);
      final out = <String, int>{};
      for (var i = 0; i < _knownSectors.length; i++) {
        final c = counts[i];
        if (c > 0 && c <= maxTotal) {
          out[_knownSectors[i]] = c;
        }
      }
      return out;
    } catch (_) {
      return const <String, int>{};
    }
  }

  Future<Map<String, dynamic>?> _loadChangeDistribution(
    int totalQuotes,
    double bestGain,
    double worstLoss,
  ) async {
    if (totalQuotes <= 0) return null;
    try {
      final counts = await Future.wait<int>([
        _database
            .from('stock_quotes')
            .count(CountOption.exact)
            .gt('change_pct', 0)
            .catchError((_) => 0),
        _database
            .from('stock_quotes')
            .count(CountOption.exact)
            .lt('change_pct', 0)
            .catchError((_) => 0),
        _database
            .from('stock_quotes')
            .count(CountOption.exact)
            .lt('change_pct', -5)
            .catchError((_) => 0),
        _database
            .from('stock_quotes')
            .count(CountOption.exact)
            .gte('change_pct', -5)
            .lt('change_pct', -2)
            .catchError((_) => 0),
        _database
            .from('stock_quotes')
            .count(CountOption.exact)
            .gte('change_pct', -2)
            .lt('change_pct', 0)
            .catchError((_) => 0),
        _database
            .from('stock_quotes')
            .count(CountOption.exact)
            .gte('change_pct', 0)
            .lt('change_pct', 2)
            .catchError((_) => 0),
        _database
            .from('stock_quotes')
            .count(CountOption.exact)
            .gte('change_pct', 2)
            .lt('change_pct', 5)
            .catchError((_) => 0),
        _database
            .from('stock_quotes')
            .count(CountOption.exact)
            .gte('change_pct', 5)
            .catchError((_) => 0),
      ]);
      final binSum = counts.skip(2).fold<int>(0, (a, b) => a + b);
      if (binSum == 0 || binSum > totalQuotes * 2) return null;
      return <String, dynamic>{
        'total': totalQuotes,
        'gainers_count': counts[0],
        'losers_count': counts[1],
        'best_gain': bestGain,
        'worst_loss': worstLoss,
        'bins': <String, int>{
          '< -5%': counts[2],
          '-5 to -2%': counts[3],
          '-2 to 0%': counts[4],
          '0 to 2%': counts[5],
          '2 to 5%': counts[6],
          '> 5%': counts[7],
        },
      };
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchNewsPage({
    int offset = 0,
    int limit = 25,
  }) async {
    final client = _database;
    final rows = await client
        .from('news_articles')
        .select(
          'id, title, summary, link, publisher, thumbnail_url, content_type, published_at',
        )
        .order('published_at', ascending: false)
        .range(offset, offset + limit - 1);
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
            .limit(500);
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

  Future<List<MarketArticle>> loadMoreNews({
    required int offset,
    int limit = 20,
  }) async {
    if (!usesDatabase) return const <MarketArticle>[];
    final rows = await _fetchNewsPage(offset: offset, limit: limit);
    return rows
        .map(MarketArticle.fromJson)
        .where((a) => a.title.isNotEmpty)
        .toList();
  }

  Future<MarketPageResult<MarketInstrument>> loadInstrumentsPage({
    int page = 0,
    int pageSize = 30,
    String query = '',
    String sort = 'rank',
  }) async {
    final q = query.trim().toLowerCase();
    if (!usesDatabase) {
      final snap = await snapshot();
      var list = snap.instruments.where((inst) {
        if (q.isEmpty) return true;
        return inst.symbol.toLowerCase().contains(q) ||
            inst.name.toLowerCase().contains(q);
      }).toList();
      if (sort == 'symbol') {
        list.sort((a, b) => a.symbol.compareTo(b.symbol));
      } else if (sort == 'change') {
        list.sort((a, b) => b.changePercent.compareTo(a.changePercent));
      } else if (sort == 'volume') {
        list.sort((a, b) => b.volume.compareTo(a.volume));
      }
      final total = list.length;
      final items = list.skip(page * pageSize).take(pageSize).toList();
      return MarketPageResult(items: items, totalCount: total);
    }

    final client = _database;
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final safeQ = q.replaceAll(RegExp(r'[,()%]'), '');

    if (sort == 'change' || sort == 'volume') {
      final orderCol = sort == 'change' ? 'change_pct' : 'volume';
      var quoteQuery = client
          .from('stock_quotes')
          .select(
            'ticker, price, previous_close, day_high, day_low, volume, change_pct, updated_at',
          );
      if (safeQ.isNotEmpty) {
        quoteQuery = quoteQuery.ilike('ticker', '%$safeQ%');
      }
      final quoteRows =
          (await quoteQuery.order(orderCol, ascending: false).range(from, to))
              as List? ??
          const <dynamic>[];
      final symbols = [
        for (final r in quoteRows.whereType<Map>())
          if ('${r['ticker'] ?? ''}'.isNotEmpty) '${r['ticker']}',
      ];
      if (symbols.isEmpty) {
        return const MarketPageResult(
          items: <MarketInstrument>[],
          totalCount: 0,
        );
      }
      final metaValues = await Future.wait<dynamic>([
        client
            .from('tickers')
            .select('ticker, name, market, exchange, currency')
            .inFilter('ticker', symbols),
        client
            .from('stock_fundamentals')
            .select(
              'ticker, market_cap, pe_ratio, sector, industry, dividend_yield, beta, fifty_two_week_high, fifty_two_week_low',
            )
            .inFilter('ticker', symbols),
        _loadSparksBatch(symbols),
        safeQ.isEmpty
            ? _exactCount('stock_quotes')
            : Future.value(symbols.length),
      ]);
      final metaMap = <String, Map<String, dynamic>>{
        for (final r in (metaValues[0] as List? ?? const []).whereType<Map>())
          '${r['ticker']}': Map<String, dynamic>.from(r),
      };
      final fundMap = <String, Map<String, dynamic>>{
        for (final r in (metaValues[1] as List? ?? const []).whereType<Map>())
          '${r['ticker']}': Map<String, dynamic>.from(r),
      };
      final sparks = metaValues[2] as Map<String, List<double>>;
      final total = (metaValues[3] as int?) ?? symbols.length;
      final items = [
        for (final raw in quoteRows.whereType<Map>())
          () {
            final sym = '${raw['ticker'] ?? ''}';
            final meta = metaMap[sym] ?? const <String, dynamic>{};
            return MarketInstrument.fromJson(
              <String, dynamic>{
                ...meta,
                ...Map<String, dynamic>.from(raw),
                'ticker': sym,
                'name': meta['name'] ?? sym,
                'market': meta['market'] ?? 'US',
                'currency': meta['currency'] ?? 'USD',
              },
              fundMap[sym] ?? const <String, dynamic>{},
              history: sparks[sym] ?? const <double>[],
            );
          }(),
      ];
      return MarketPageResult(
        items: items,
        totalCount: total > 0 ? total : from + items.length,
      );
    }

    // Default: rank-ordered from market_universe (fallback to tickers)
    List<Map<String, dynamic>> dirRows = const <Map<String, dynamic>>[];
    int totalCount = 0;
    try {
      var uQuery = client
          .from('market_universe')
          .select(
            'ticker, display_symbol, rank, name, exchange, sector, market_cap',
          );
      if (safeQ.isNotEmpty) {
        uQuery = uQuery.or('ticker.ilike.%$safeQ%,name.ilike.%$safeQ%');
      }
      final raw =
          (await uQuery
                  .order(sort == 'symbol' ? 'ticker' : 'rank', ascending: true)
                  .range(from, to))
              as List? ??
          const <dynamic>[];
      dirRows = raw
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      if (safeQ.isEmpty) {
        totalCount = await _exactCount('market_universe');
      } else {
        totalCount = dirRows.length < pageSize
            ? from + dirRows.length
            : from + dirRows.length + 1;
      }
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST205' && error.code != '42P01') rethrow;
    }

    if (dirRows.isEmpty && safeQ.isEmpty && page == 0) {
      var tQuery = client
          .from('tickers')
          .select('ticker, name, market, exchange, currency');
      final raw =
          (await tQuery.order('ticker', ascending: true).range(from, to))
              as List? ??
          const <dynamic>[];
      dirRows = raw
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      totalCount = await _exactCount('tickers');
    } else if (dirRows.isEmpty && safeQ.isNotEmpty) {
      var tQuery = client
          .from('tickers')
          .select('ticker, name, market, exchange, currency')
          .or('ticker.ilike.%$safeQ%,name.ilike.%$safeQ%');
      final raw =
          (await tQuery.order('ticker', ascending: true).range(from, to))
              as List? ??
          const <dynamic>[];
      dirRows = raw
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      totalCount = dirRows.length < pageSize
          ? from + dirRows.length
          : from + dirRows.length + 1;
    }

    final symbols = [
      for (final r in dirRows)
        if ('${r['ticker'] ?? ''}'.isNotEmpty) '${r['ticker']}',
    ];
    if (symbols.isEmpty) {
      return const MarketPageResult(items: <MarketInstrument>[], totalCount: 0);
    }

    final detailValues = await Future.wait<dynamic>([
      client
          .from('stock_quotes')
          .select(
            'ticker, price, previous_close, day_high, day_low, volume, change_pct, updated_at',
          )
          .inFilter('ticker', symbols),
      client
          .from('stock_fundamentals')
          .select(
            'ticker, market_cap, pe_ratio, sector, industry, dividend_yield, beta, fifty_two_week_high, fifty_two_week_low',
          )
          .inFilter('ticker', symbols),
      _loadSparksBatch(symbols),
    ]);
    final quoteMap = <String, Map<String, dynamic>>{
      for (final r in (detailValues[0] as List? ?? const []).whereType<Map>())
        '${r['ticker']}': Map<String, dynamic>.from(r),
    };
    final fundMap = <String, Map<String, dynamic>>{
      for (final r in (detailValues[1] as List? ?? const []).whereType<Map>())
        '${r['ticker']}': Map<String, dynamic>.from(r),
    };
    final sparks = detailValues[2] as Map<String, List<double>>;

    final items = <MarketInstrument>[
      for (final row in dirRows)
        () {
          final sym = '${row['ticker'] ?? ''}';
          final q = quoteMap[sym] ?? const <String, dynamic>{};
          final f = fundMap[sym] ?? const <String, dynamic>{};
          return MarketInstrument.fromJson(
            <String, dynamic>{
              'ticker': sym,
              'name': row['name'] ?? sym,
              'market': row['market'] ?? 'US',
              'currency': row['currency'] ?? 'USD',
              'exchange': row['exchange'],
              ...q,
              'price': q['price'] ?? double.nan,
              'change_pct': q['change_pct'] ?? 0.0,
            },
            <String, dynamic>{
              if (row['sector'] != null) 'sector': row['sector'],
              if (row['market_cap'] != null) 'market_cap': row['market_cap'],
              ...f,
            },
            history: sparks[sym] ?? const <double>[],
          );
        }(),
    ];
    return MarketPageResult(
      items: items,
      totalCount: totalCount > 0 ? totalCount : from + items.length,
    );
  }

  Future<MarketPageResult<Map<String, dynamic>>> loadCoveragePage({
    int page = 0,
    int pageSize = 30,
    String query = '',
  }) async {
    final q = query.trim().toLowerCase();
    if (!usesDatabase) {
      final raw = await safeRead('tickers/universe');
      final list = (raw is List ? raw : const <dynamic>[])
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .where((r) => q.isEmpty || '$r'.toLowerCase().contains(q))
          .toList();
      return MarketPageResult(
        items: list.skip(page * pageSize).take(pageSize).toList(),
        totalCount: list.length,
      );
    }

    final client = _database;
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final safeQ = q.replaceAll(RegExp(r'[,()%]'), '');

    List<Map<String, dynamic>> dirRows = const <Map<String, dynamic>>[];
    int totalCount = 0;
    try {
      var uQuery = client
          .from('market_universe')
          .select('ticker, display_symbol, rank, name, exchange, sector');
      if (safeQ.isNotEmpty) {
        uQuery = uQuery.or('ticker.ilike.%$safeQ%,name.ilike.%$safeQ%');
      }
      final raw =
          (await uQuery.order('rank', ascending: true).range(from, to))
              as List? ??
          const <dynamic>[];
      dirRows = raw
          .whereType<Map>()
          .map(
            (r) => <String, dynamic>{
              ...Map<String, dynamic>.from(r),
              'market': 'US',
            },
          )
          .toList();
      totalCount = safeQ.isEmpty
          ? await _exactCount('market_universe')
          : (dirRows.length < pageSize
                ? from + dirRows.length
                : from + dirRows.length + 1);
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST205' && error.code != '42P01') rethrow;
    }

    if (dirRows.isEmpty && safeQ.isEmpty && page == 0) {
      final raw =
          (await client
                  .from('tickers')
                  .select('ticker, name, market, exchange')
                  .order('ticker', ascending: true)
                  .range(from, to))
              as List? ??
          const <dynamic>[];
      dirRows = raw
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      totalCount = await _exactCount('tickers');
    }

    final symbols = [
      for (final r in dirRows)
        if ('${r['ticker'] ?? ''}'.isNotEmpty) '${r['ticker']}',
    ];
    final quoteMap = <String, Map<String, dynamic>>{};
    if (symbols.isNotEmpty) {
      final quotes =
          (await client
                  .from('stock_quotes')
                  .select('ticker, price, change_pct')
                  .inFilter('ticker', symbols))
              as List? ??
          const <dynamic>[];
      for (final r in quotes.whereType<Map>()) {
        quoteMap['${r['ticker']}'] = Map<String, dynamic>.from(r);
      }
    }
    final enriched = [
      for (final r in dirRows)
        <String, dynamic>{
          ...r,
          'has_quote': quoteMap.containsKey('${r['ticker']}'),
          if (quoteMap.containsKey('${r['ticker']}'))
            ...quoteMap['${r['ticker']}']!,
        },
    ];
    return MarketPageResult(
      items: enriched,
      totalCount: totalCount > 0 ? totalCount : from + enriched.length,
    );
  }

  Future<dynamic> _readFromDatabase(String path) async {
    final SupabaseClient client = _database;
    if (path == 'tickers/universe') {
      try {
        final universeRows = await _fetchPaged(
          (from, to) => client
              .from('market_universe')
              .select(
                'ticker, display_symbol, rank, name, exchange, sector, market_cap',
              )
              .order('rank', ascending: true)
              .range(from, to),
        );
        if (universeRows.isNotEmpty) {
          return [
            for (final r in universeRows)
              <String, dynamic>{...r, 'market': 'US', 'currency': 'USD'},
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
      return _fetchNewsPage(offset: 0, limit: 25);
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

  /// Small, server-whitelisted market payload used only by Community.
  ///
  /// This intentionally never falls back to [snapshot] for live databases: a
  /// Free account must not accidentally trigger the full paid market query
  /// graph when the limited RPC is unavailable.
  Future<MarketSnapshot> communityPreview({bool refresh = false}) {
    final now = DateTime.now();
    if (refresh ||
        (_communityPreviewExpiresAt != null &&
            now.isAfter(_communityPreviewExpiresAt!))) {
      _communityPreviewSnapshot = null;
      _communityPreviewExpiresAt = null;
    }
    final active = _communityPreviewSnapshot;
    if (active != null) return active;
    final future = _loadCommunityPreview();
    _communityPreviewSnapshot = future;
    _communityPreviewExpiresAt = now.add(_communityPreviewTtl);
    return future;
  }

  Future<MarketSnapshot> _loadCommunityPreview() async {
    if (!usesDatabase) {
      if (_customBundle == null) {
        return const MarketSnapshot(
          instruments: <MarketInstrument>[],
          articles: <MarketArticle>[],
        );
      }
      final local = await _loadSnapshot();
      final quotes = local.instruments.take(8).toList();
      return MarketSnapshot(
        manifest: const <String, dynamic>{
          'data_source': 'community_preview',
          'limited': true,
        },
        instruments: quotes,
        screeners: <String, List<MarketInstrument>>{
          'top_gainers': [...quotes]
            ..sort((a, b) => b.changePercent.compareTo(a.changePercent)),
          'top_losers': [...quotes]
            ..sort((a, b) => a.changePercent.compareTo(b.changePercent)),
        },
        articles: local.articles.take(6).toList(),
      );
    }

    try {
      final raw = await _database.rpc('community_market_preview');
      if (raw is! Map) throw const FormatException('Invalid preview payload');
      final payload = Map<String, dynamic>.from(raw);
      final instruments = (payload['quotes'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (row) => MarketInstrument.fromJson(
              Map<String, dynamic>.from(row),
              const <String, dynamic>{},
            ),
          )
          .where((quote) => quote.symbol.isNotEmpty && quote.price.isFinite)
          .toList();
      final gainers = [...instruments]
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
      final losers = [...instruments]
        ..sort((a, b) => a.changePercent.compareTo(b.changePercent));
      final articles = (payload['news'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((row) => MarketArticle.fromJson(Map<String, dynamic>.from(row)))
          .where((article) => article.title.isNotEmpty)
          .toList();
      return MarketSnapshot(
        manifest: <String, dynamic>{
          'data_source': 'community_preview',
          'limited': true,
          'quote_count': instruments.length,
        },
        instruments: instruments,
        screeners: <String, List<MarketInstrument>>{
          'top_gainers': gainers.where((q) => q.changePercent >= 0).toList(),
          'top_losers': losers.where((q) => q.changePercent < 0).toList(),
        },
        articles: articles,
      );
    } catch (error) {
      debugPrint(
        '[AssetMarketRepository] Community preview unavailable: $error',
      );
      return const MarketSnapshot(
        manifest: <String, dynamic>{
          'data_source': 'community_preview',
          'limited': true,
        },
        instruments: <MarketInstrument>[],
        articles: <MarketArticle>[],
      );
    }
  }

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
    final Future<MarketSnapshot>? activeSnapshot = _snapshot;
    if (activeSnapshot != null) return activeSnapshot;

    late final Future<MarketSnapshot> guardedSnapshot;
    guardedSnapshot = _loadSnapshot().then(
      (MarketSnapshot value) {
        _snapshotExpiresAt = DateTime.now().add(_snapshotTtl);
        return value;
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_snapshot, guardedSnapshot)) {
          _snapshot = null;
          _snapshotExpiresAt = null;
        }
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _snapshot = guardedSnapshot;
    return guardedSnapshot;
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
          if (a.title.isNotEmpty &&
              seen.add(a.link.isEmpty ? a.title : a.link)) {
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
    if (!screens.containsKey('top_gainers') ||
        screens['top_gainers']!.isEmpty) {
      screens['top_gainers'] =
          enriched.where((q) => q.changePercent > 0).toList()
            ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    }
    if (!screens.containsKey('top_losers') || screens['top_losers']!.isEmpty) {
      screens['top_losers'] =
          enriched.where((q) => q.changePercent < 0).toList()
            ..sort((a, b) => a.changePercent.compareTo(b.changePercent));
    }
    if (!screens.containsKey('most_active') ||
        screens['most_active']!.isEmpty) {
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
    try {
      return await _loadDatabaseOverviewPayload();
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202' && error.code != '42883') rethrow;
      debugPrint(
        '[AssetMarketRepository] Aggregated market RPC is not deployed; using compatibility queries.',
      );
    } on FormatException catch (error) {
      debugPrint(
        '[AssetMarketRepository] Aggregated market RPC returned an invalid payload; using compatibility queries: $error',
      );
    }
    final client = _database;
    final values = await Future.wait<dynamic>([
      client
          .from('stock_quotes')
          .select(
            'ticker, price, previous_close, day_high, day_low, volume, change_pct, updated_at',
          )
          .order('change_pct', ascending: false)
          .limit(20),
      client
          .from('stock_quotes')
          .select(
            'ticker, price, previous_close, day_high, day_low, volume, change_pct, updated_at',
          )
          .order('change_pct', ascending: true)
          .limit(20),
      client
          .from('stock_quotes')
          .select(
            'ticker, price, previous_close, day_high, day_low, volume, change_pct, updated_at',
          )
          .order('volume', ascending: false)
          .limit(20),
      safeRead('all_news'),
      safeRead('screeners'),
      _exactCount('market_universe'),
      _exactCount('stock_quotes'),
      _exactCount('stock_fundamentals'),
      _exactCount('stock_details'),
      _exactCount('news_articles'),
    ]);

    final quotes = <String, Map<String, dynamic>>{};
    for (final list in [values[0], values[1], values[2]]) {
      for (final raw in (list as List? ?? const <dynamic>[]).whereType<Map>()) {
        final sym = '${raw['ticker'] ?? ''}';
        if (sym.isNotEmpty) {
          quotes[sym] = Map<String, dynamic>.from(raw);
        }
      }
    }

    final rawNews = values[3];
    final screenerPayloads = Map<String, dynamic>.from(
      values[4] is Map ? values[4] as Map : <String, dynamic>{},
    );
    final universeCount = values[5] as int? ?? 0;
    final quoteCount = values[6] as int? ?? 0;
    final fundCount = values[7] as int? ?? 0;
    final detailCount = values[8] as int? ?? 0;
    final newsCount = values[9] as int? ?? 0;

    // Collect symbols from top movers and screeners (~40-60 symbols) so we only
    // fetch ticker metadata and fundamentals for what Overview/Screeners show.
    final neededSymbols = <String>{...quotes.keys};
    for (final screen in flattenScreens(screenerPayloads).values) {
      for (final row in screen) {
        final sym = '${row['symbol'] ?? row['ticker'] ?? ''}';
        if (sym.isNotEmpty) neededSymbols.add(sym);
      }
    }

    final metaByTicker = <String, Map<String, dynamic>>{};
    final fundamentals = <String, Map<String, dynamic>>{};
    if (neededSymbols.isNotEmpty) {
      final symbolList = neededSymbols.toList();
      final metaValues = await Future.wait<dynamic>([
        client
            .from('tickers')
            .select('ticker, name, market, exchange, currency')
            .inFilter('ticker', symbolList),
        client
            .from('stock_fundamentals')
            .select(
              'ticker, market_cap, pe_ratio, sector, industry, dividend_yield, beta, fifty_two_week_high, fifty_two_week_low',
            )
            .inFilter('ticker', symbolList),
      ]);
      for (final r in (metaValues[0] as List? ?? const []).whereType<Map>()) {
        metaByTicker['${r['ticker']}'] = Map<String, dynamic>.from(r);
      }
      for (final r in (metaValues[1] as List? ?? const []).whereType<Map>()) {
        fundamentals['${r['ticker']}'] = Map<String, dynamic>.from(r);
      }
    }

    // Scope to market_universe when available.
    if (neededSymbols.isNotEmpty) {
      try {
        final uRows =
            (await client
                    .from('market_universe')
                    .select('ticker')
                    .inFilter('ticker', neededSymbols.toList()))
                as List? ??
            const <dynamic>[];
        if (uRows.isNotEmpty) {
          final allowed = {
            for (final r in uRows.whereType<Map>()) '${r['ticker']}',
          };
          quotes.removeWhere((k, _) => !allowed.contains(k));
        }
      } catch (_) {}
    }

    final instruments =
        quotes.values
            .map((raw) {
              final sym = '${raw['ticker'] ?? ''}';
              final meta = metaByTicker[sym] ?? const <String, dynamic>{};
              final mergedQuote = <String, dynamic>{
                ...meta,
                ...raw,
                'ticker': sym,
                'name': meta['name'] ?? sym,
                'market': meta['market'] ?? 'US',
                'currency': meta['currency'] ?? 'USD',
              };
              return MarketInstrument.fromJson(
                mergedQuote,
                fundamentals[sym] ?? const <String, dynamic>{},
              );
            })
            .where((q) => q.price.isFinite)
            .toList()
          ..sort(
            (a, b) => a.market == b.market
                ? a.symbol.compareTo(b.symbol)
                : a.market.compareTo(b.market),
          );

    // Load sparklines only for visible top movers & active candidates.
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
        if (a.title.isNotEmpty && seen.add(a.link.isEmpty ? a.title : a.link)) {
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
            .map((row) {
              final sym = '${row['symbol'] ?? row['ticker'] ?? ''}';
              final mergedRow = <String, dynamic>{
                ...(metaByTicker[sym] ?? const <String, dynamic>{}),
                ...row,
              };
              return screenInstrument(mergedRow, quotes, fundamentals);
            })
            .whereType<MarketInstrument>()
            .toList();
      }
    }

    if (!screens.containsKey('top_gainers') ||
        screens['top_gainers']!.isEmpty) {
      screens['top_gainers'] =
          enriched.where((q) => q.changePercent > 0).toList()
            ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    }
    if (!screens.containsKey('top_losers') || screens['top_losers']!.isEmpty) {
      screens['top_losers'] =
          enriched.where((q) => q.changePercent < 0).toList()
            ..sort((a, b) => a.changePercent.compareTo(b.changePercent));
    }
    if (!screens.containsKey('most_active') ||
        screens['most_active']!.isEmpty) {
      screens['most_active'] = [...enriched]
        ..sort((a, b) => b.volume.compareTo(a.volume));
    }

    final effectiveQuotes = quoteCount > 0 ? quoteCount : enriched.length;
    final effectiveDetails = detailCount > 0
        ? detailCount
        : (fundCount > 0 ? fundCount : enriched.length);
    final effectiveUniverse = universeCount > 0
        ? universeCount
        : effectiveQuotes;
    final bestGain = ranked.isNotEmpty ? ranked.first.changePercent : 0.0;
    final worstLoss = ranked.isNotEmpty ? ranked.last.changePercent : 0.0;
    final metaFutures = await Future.wait<dynamic>([
      _loadSectorCounts(fundCount),
      _loadChangeDistribution(quoteCount, bestGain, worstLoss),
    ]);
    final sectorCounts = metaFutures[0] as Map<String, int>;
    final changeDist = metaFutures[1] as Map<String, dynamic>?;
    final manifest = <String, dynamic>{
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'data_source': 'supabase_live',
      'quote_count': effectiveQuotes,
      'universe_count': effectiveUniverse,
      'detail_count': effectiveDetails,
      'history_count': fundCount > 0 ? fundCount : effectiveQuotes,
      'source_history_count': effectiveUniverse,
      'news_count': newsCount > 0 ? newsCount : articles.length,
      'market_counts': <String, int>{'US': effectiveQuotes},
      if (sectorCounts.isNotEmpty) 'sector_counts': sectorCounts,
      'change_distribution': ?changeDist,
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

  Future<MarketSnapshot> _loadDatabaseOverviewPayload() async {
    final raw = await _database.rpc('market_overview_payload');
    if (raw is! Map) {
      throw const FormatException('Invalid market overview payload');
    }
    final payload = Map<String, dynamic>.from(raw);
    final instruments = (payload['quotes'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((row) {
          final data = Map<String, dynamic>.from(row);
          return MarketInstrument.fromJson(
            data,
            data,
            history: (data['spark'] as List? ?? const <dynamic>[])
                .whereType<num>()
                .map((value) => value.toDouble())
                .toList(),
          );
        })
        .where((quote) => quote.symbol.isNotEmpty && quote.price.isFinite)
        .toList();
    final quoteBySymbol = <String, MarketInstrument>{
      for (final quote in instruments) quote.symbol: quote,
    };

    final screeners = <String, List<MarketInstrument>>{};
    final rawScreeners = payload['screeners'];
    if (rawScreeners is Map) {
      for (final entry in rawScreeners.entries) {
        final rows = entry.value is List
            ? entry.value as List
            : const <dynamic>[];
        screeners['${entry.key}'] = rows
            .whereType<Map>()
            .map((row) {
              final data = Map<String, dynamic>.from(row);
              final symbol = '${data['ticker'] ?? data['symbol'] ?? ''}';
              return quoteBySymbol[symbol] ??
                  MarketInstrument.fromJson(data, const <String, dynamic>{});
            })
            .where((quote) => quote.symbol.isNotEmpty)
            .toList();
      }
    }

    final articles = (payload['news'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((row) => MarketArticle.fromJson(Map<String, dynamic>.from(row)))
        .where((article) => article.title.isNotEmpty)
        .toList();
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

    return MarketSnapshot(
      manifest: payload['manifest'] is Map
          ? Map<String, dynamic>.from(payload['manifest'] as Map)
          : const <String, dynamic>{'data_source': 'supabase_live'},
      screenerPayloads: rawScreeners is Map
          ? Map<String, dynamic>.from(rawScreeners)
          : const <String, dynamic>{},
      instruments: instruments,
      screeners: screeners,
      articles: articles,
      topics: <String, List<MarketArticle>>{
        for (final topic in standardTopics)
          topic: _filterArticlesByTopic(articles, topic),
      },
    );
  }

  // Older deployments may not have every supplemental market table. Only
  // missing relations are optional; authentication and transport errors surface.
  Future<T?> _optionalDetailQuery<T>(String table, Future<T> query) async {
    try {
      return await query;
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST205' && error.code != '42P01') rethrow;
      debugPrint(
        '[AssetMarketRepository] Optional table $table is unavailable.',
      );
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
    final historyRows = (results[3] as List? ?? const <dynamic>[]).reversed
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
              final related =
                  (a['related_tickers'] as List? ?? const <dynamic>[]).map(
                    (e) => '$e'.toUpperCase(),
                  );
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

    final storedDetail =
        results[8] is Map && (results[8] as Map)['detail'] is Map
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

    for (final raw
        in (storedDetail['news'] as List? ?? const <dynamic>[])
            .whereType<Map>()) {
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
      'name':
          tickerRow['name'] ?? fundRow['name'] ?? storedQuote['name'] ?? symbol,
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
        <String, dynamic>{...r, 'date': r['date'] ?? r['ex_date']},
    ];
    final normalizedSplits = [
      for (final r in splitRows)
        <String, dynamic>{...r, 'date': r['date'] ?? r['split_date']},
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

    Map<String, dynamic> normalizeHolder(
      Map<String, dynamic> r,
    ) => <String, dynamic>{
      ...r,
      if (r['Holder'] == null && r['holder_name'] != null)
        'Holder': r['holder_name'],
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
        : const <String, dynamic>{
            'expirations': <dynamic>[],
            'chains': <String, dynamic>{},
          };

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
      if (storedDetail['universe'] != null)
        'universe': storedDetail['universe'],
      if (storedDetail['availability'] != null)
        'availability': storedDetail['availability'],
      if (storedDetail['snapshot'] != null)
        'snapshot': storedDetail['snapshot'],
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

  Future<Map<String, List<double>>> _loadSparksBatch(
    List<String> symbols,
  ) async {
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
            final chronological = (groupedDesc[sym] ?? const <double>[])
                .reversed
                .toList();
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
          return const <
            double
          >[]; // Allow the next request to retry a temporary outage.
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
          .map(
            (r) => screenInstrument(Map<String, dynamic>.from(r), qMap, fMap),
          )
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
    if (category == 'top_gainers' ||
        category == 'top_losers' ||
        category == 'most_active') {
      final universe = qMap.values
          .whereType<Map>()
          .map(
            (r) => screenInstrument(Map<String, dynamic>.from(r), qMap, fMap),
          )
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
        final active = [...universe]
          ..sort((a, b) => b.volume.compareTo(a.volume));
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

    // 2. Single file mode (or live DB): filter from initial articles, or fetch a larger DB batch when sparse
    final sourceArticles = fallbackArticles ?? await _loadAllArticles();
    var filtered = _filterArticlesByTopic(sourceArticles, topicKey);
    if (usesDatabase && filtered.length < 5) {
      try {
        final moreRows = await _fetchNewsPage(offset: 0, limit: 150);
        final moreArticles = moreRows
            .map(MarketArticle.fromJson)
            .where((a) => a.title.isNotEmpty)
            .toList();
        filtered = _filterArticlesByTopic(moreArticles, topicKey);
      } catch (_) {}
    }
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
List<MarketArticle> _filterArticlesByTopic(
  List<MarketArticle> articles,
  String topicKey,
) {
  final key = topicKey.toLowerCase();
  switch (key) {
    case 'magnificent_seven':
      const mag7 = {
        'AAPL',
        'MSFT',
        'GOOGL',
        'GOOG',
        'AMZN',
        'NVDA',
        'META',
        'TSLA',
      };
      return articles
          .where((a) => a.tickers.any((t) => mag7.contains(t.toUpperCase())))
          .toList();
    case 'crypto':
      return articles
          .where(
            (a) =>
                a.tickers.any(
                  (t) =>
                      t.endsWith('-USD') ||
                      t == 'BTC' ||
                      t == 'ETH' ||
                      t == 'SOL' ||
                      t == 'XRP',
                ) ||
                a.title.toLowerCase().contains('crypto') ||
                a.title.toLowerCase().contains('bitcoin'),
          )
          .toList();
    case 'banks_and_financials':
      return articles
          .where(
            (a) =>
                a.tickers.any(
                  (t) => {
                    'JPM',
                    'BAC',
                    'WFC',
                    'C',
                    'GS',
                    'MS',
                    'HDFCBANK.NS',
                    'ICICIBANK.NS',
                    'SBIN.NS',
                  }.contains(t.toUpperCase()),
                ) ||
                a.title.toLowerCase().contains('bank') ||
                a.title.toLowerCase().contains('treasury') ||
                a.title.toLowerCase().contains('yield') ||
                a.title.toLowerCase().contains('fed'),
          )
          .toList();
    case 'enterprise_cloud':
      return articles
          .where(
            (a) =>
                a.tickers.any(
                  (t) => {
                    'CRM',
                    'NOW',
                    'SNOW',
                    'ORCL',
                    'ADBE',
                    'MSFT',
                    'INFY.NS',
                    'TCS.NS',
                  }.contains(t.toUpperCase()),
                ) ||
                a.title.toLowerCase().contains('cloud') ||
                a.title.toLowerCase().contains('software') ||
                a.title.toLowerCase().contains('ai'),
          )
          .toList();
    case 'pharma_and_biotech':
      return articles
          .where(
            (a) =>
                a.tickers.any(
                  (t) => {
                    'LLY',
                    'NVO',
                    'PFE',
                    'MRK',
                    'ABBV',
                    'JNJ',
                  }.contains(t.toUpperCase()),
                ) ||
                a.title.toLowerCase().contains('pharma') ||
                a.title.toLowerCase().contains('drug') ||
                a.title.toLowerCase().contains('biotech') ||
                a.title.toLowerCase().contains('fda'),
          )
          .toList();
    case 'clean_energy':
      return articles
          .where(
            (a) =>
                a.tickers.any(
                  (t) => {
                    'TSLA',
                    'ENPH',
                    'SEDG',
                    'FSLR',
                    'NEE',
                  }.contains(t.toUpperCase()),
                ) ||
                a.title.toLowerCase().contains('energy') ||
                a.title.toLowerCase().contains('solar') ||
                a.title.toLowerCase().contains('ev'),
          )
          .toList();
    case 'aerospace_and_defense':
      return articles
          .where(
            (a) =>
                a.tickers.any(
                  (t) => {
                    'BA',
                    'LMT',
                    'RTX',
                    'NOC',
                    'GD',
                  }.contains(t.toUpperCase()),
                ) ||
                a.title.toLowerCase().contains('aerospace') ||
                a.title.toLowerCase().contains('defense') ||
                a.title.toLowerCase().contains('boeing'),
          )
          .toList();
    case 'oil_and_gas':
      return articles
          .where(
            (a) =>
                a.tickers.any(
                  (t) => {
                    'XOM',
                    'CVX',
                    'COP',
                    'BP',
                    'SHEL',
                    'RELIANCE.NS',
                  }.contains(t.toUpperCase()),
                ) ||
                a.title.toLowerCase().contains('oil') ||
                a.title.toLowerCase().contains('gas') ||
                a.title.toLowerCase().contains('crude'),
          )
          .toList();
    case 'cybersecurity':
      return articles
          .where(
            (a) =>
                a.tickers.any(
                  (t) => {
                    'CRWD',
                    'PANW',
                    'FTNT',
                    'ZS',
                    'NET',
                  }.contains(t.toUpperCase()),
                ) ||
                a.title.toLowerCase().contains('cyber') ||
                a.title.toLowerCase().contains('hack') ||
                a.title.toLowerCase().contains('security'),
          )
          .toList();
    case 'housing':
      return articles
          .where(
            (a) =>
                a.tickers.any(
                  (t) => {
                    'DHI',
                    'LEN',
                    'TOL',
                    'HD',
                    'LOW',
                  }.contains(t.toUpperCase()),
                ) ||
                a.title.toLowerCase().contains('housing') ||
                a.title.toLowerCase().contains('mortgage') ||
                a.title.toLowerCase().contains('home'),
          )
          .toList();
    case 'stock_market_general':
    default:
      final matches = articles
          .where(
            (a) =>
                a.title.toLowerCase().contains(key.replaceAll('_', ' ')) ||
                a.summary.toLowerCase().contains(key.replaceAll('_', ' ')),
          )
          .toList();
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
