import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:alphajournal/core/config/supabase_config.dart';
import '../models/market_snapshot.dart';
import '../presentation/market_sector_heatmap_card.dart';
import '../presentation/market_world_indices_card.dart';
import '../presentation/yahoo_market_ribbon.dart';

/// Market intelligence service for real-time and snapshot quotes, global indices,
/// sector performances, and news.
///
/// In browser/web runtimes and authenticated production deployments, requests
/// are proxied through the secure backend `market-quote-proxy` Edge Function to
/// eliminate CORS rejections, prevent browser rate-limit IP blocks, and keep
/// provider credentials strictly server-side.
class YahooFinanceService {
  YahooFinanceService({http.Client? client})
    : _client = client ?? http.Client();

  static final YahooFinanceService instance = YahooFinanceService();
  final http.Client _client;

  // In-memory cache structures with TTL
  final Map<String, ({YahooMarketItem item, DateTime expires})> _quoteCache =
      {};
  final Map<String, ({MarketIndexItem item, DateTime expires})> _indexCache =
      {};
  ({List<SectorPerformanceItem> items, DateTime expires})? _sectorCache;
  final Map<String, ({List<MarketArticle> items, DateTime expires})>
  _newsCache = {};

  // In-flight request deduplication
  final Map<String, Future<YahooMarketItem?>> _inFlightQuotes = {};
  Future<List<SectorPerformanceItem>>? _inFlightSectors;
  final Map<String, Future<List<MarketArticle>>> _inFlightNews = {};

  // Proxy circuit breaker with exponential backoff so 404/CORS failures never loop
  int _proxyFailures = 0;
  DateTime? _proxyBlockedUntil;
  static const List<int> _proxyBackoffSeconds = [30, 60, 120, 300];
  static const int _maxProxyConsecutiveFailures = 5;
  static const int _maxProxyBatch = 30;

  static const Duration _quoteTtl = Duration(minutes: 1);
  static const Duration _sectorTtl = Duration(minutes: 5);
  static const Duration _newsTtl = Duration(minutes: 5);
  static const Duration _requestTimeout = Duration(seconds: 5);

  bool get _canCallProxy {
    final blockedUntil = _proxyBlockedUntil;
    return blockedUntil == null || DateTime.now().isAfter(blockedUntil);
  }

  void _recordProxySuccess() {
    _proxyFailures = 0;
    _proxyBlockedUntil = null;
  }

  void _recordProxyFailure() {
    _proxyFailures += 1;
    final idx = (_proxyFailures - 1).clamp(0, _proxyBackoffSeconds.length - 1);
    final secs = _proxyFailures >= _maxProxyConsecutiveFailures
        ? _proxyBackoffSeconds.last
        : _proxyBackoffSeconds[idx];
    _proxyBlockedUntil = DateTime.now().add(Duration(seconds: secs));
  }

  /// S&P 500 Sector ETF definitions mapping to Image 3 sectors.
  static const List<(String, String, String, double)> kSectorMapping = [
    ('Technology', 'XLK', 'technology', 32.43),
    ('Financial Services', 'XLF', 'financial_services', 13.44),
    ('Industrials', 'XLI', 'industrials', 10.23),
    ('Healthcare', 'XLV', 'healthcare', 9.83),
    ('Consumer Cyclical', 'XLY', 'consumer_cyclical', 9.32),
    ('Communication Services', 'XLC', 'communication_services', 8.57),
    ('Energy', 'XLE', 'energy', 5.22),
    ('Consumer Defensive', 'XLP', 'consumer_defensive', 4.61),
    ('Basic Materials', 'XLB', 'basic_materials', 2.47),
    ('Real Estate', 'XLRE', 'real_estate', 1.98),
    ('Utilities', 'XLU', 'utilities', 1.90),
  ];

  /// Fetches a batch of market quotes in minimal requests with deduplication,
  /// circuit-breaker backoff on proxy errors, and batched Supabase fallback.
  Future<Map<String, YahooMarketItem>> fetchQuotes(
    List<String> symbols, {
    Map<String, String>? displayNames,
    String category = 'US Markets',
    bool forceRefresh = false,
  }) async {
    final results = <String, YahooMarketItem>{};
    if (symbols.isEmpty) return results;

    final now = DateTime.now();
    final uniqueSymbols = symbols.toSet().toList();
    final waitFutures = <String, Future<YahooMarketItem?>>{};
    final completers = <String, Completer<YahooMarketItem?>>{};
    final missingSymbols = <String>[];

    for (final sym in uniqueSymbols) {
      final cacheKey = '${category}_$sym';
      final cached = _quoteCache[cacheKey];
      if (!forceRefresh && cached != null && cached.expires.isAfter(now)) {
        results[sym] = cached.item;
        continue;
      }
      final existing = _inFlightQuotes[cacheKey];
      if (existing != null) {
        waitFutures[sym] = existing;
        continue;
      }
      final completer = Completer<YahooMarketItem?>();
      _inFlightQuotes[cacheKey] = completer.future;
      completers[sym] = completer;
      missingSymbols.add(sym);
    }

    if (missingSymbols.isNotEmpty) {
      try {
        await _resolveQuotesBatch(
          missingSymbols,
          displayNames: displayNames,
          category: category,
          results: results,
        );
      } finally {
        for (final sym in missingSymbols) {
          final cacheKey = '${category}_$sym';
          final resolved = results[sym] ?? _quoteCache[cacheKey]?.item;
          if (resolved != null) {
            results[sym] = resolved;
          }
          completers[sym]?.complete(resolved);
          _inFlightQuotes.remove(cacheKey);
        }
      }
    }

    if (waitFutures.isNotEmpty) {
      final entries = await Future.wait(
        waitFutures.entries.map((e) async => MapEntry(e.key, await e.value)),
      );
      for (final entry in entries) {
        if (entry.value != null) {
          results[entry.key] = entry.value!;
        }
      }
    }

    return results;
  }

  Future<void> _resolveQuotesBatch(
    List<String> symbols, {
    Map<String, String>? displayNames,
    required String category,
    required Map<String, YahooMarketItem> results,
  }) async {
    final remaining = List<String>.from(symbols);

    // 1. Try Supabase Edge Function Backend Proxy in batches of up to 30
    if (SupabaseConfig.isConfigured && _canCallProxy) {
      final client = SupabaseConfig.client!;
      final unresolved = <String>[];
      for (
        var offset = 0;
        offset < remaining.length;
        offset += _maxProxyBatch
      ) {
        final end = (offset + _maxProxyBatch).clamp(0, remaining.length);
        final chunk = remaining.sublist(offset, end);
        if (!_canCallProxy) {
          unresolved.addAll(chunk);
          continue;
        }
        try {
          final res = await client.functions
              .invoke(
                'market-quote-proxy',
                body: {'action': 'quotes', 'symbols': chunk},
              )
              .timeout(_requestTimeout);

          if (res.status == 200 && res.data is Map) {
            _recordProxySuccess();
            final quotesMap = res.data['quotes'];
            for (final sym in chunk) {
              if (quotesMap is Map && quotesMap[sym] is Map) {
                final q = quotesMap[sym] as Map;
                final double price = (q['price'] as num?)?.toDouble() ?? 0.0;
                final double prevClose =
                    (q['previousClose'] as num?)?.toDouble() ?? price;
                final double change =
                    (q['change'] as num?)?.toDouble() ?? (price - prevClose);
                final double changePct =
                    (q['changePercent'] as num?)?.toDouble() ??
                    (prevClose == 0 ? 0.0 : (change / prevClose) * 100);
                final List<double> spark =
                    (q['spark'] as List?)
                        ?.whereType<num>()
                        .map((n) => n.toDouble())
                        .toList() ??
                    [prevClose, price];
                final item = YahooMarketItem(
                  symbol: sym,
                  name: displayNames?[sym] ?? (q['name'] as String?) ?? sym,
                  price: price,
                  change: change,
                  changePercent: changePct,
                  spark: spark,
                  category: category,
                  isLive: q['isLive'] as bool? ?? true,
                  timestamp: q['timestamp'] != null
                      ? DateTime.tryParse(q['timestamp'].toString()) ??
                            DateTime.now()
                      : DateTime.now(),
                  source: (q['source'] as String?) ?? 'Market Quote Proxy',
                );
                _quoteCache['${category}_$sym'] = (
                  item: item,
                  expires: DateTime.now().add(_quoteTtl),
                );
                results[sym] = item;
              } else {
                unresolved.add(sym);
              }
            }
          } else {
            _recordProxyFailure();
            unresolved.addAll(chunk);
          }
        } catch (e) {
          _recordProxyFailure();
          debugPrint('[YahooFinanceService] Proxy fetchQuotes error: $e');
          unresolved.addAll(chunk);
        }
      }
      remaining
        ..clear()
        ..addAll(unresolved);
    }

    if (remaining.isEmpty) return;

    // 1b. Single batched fallback query against Supabase stock_quotes
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final rows = await client
            .from('stock_quotes')
            .select('ticker, price, previous_close, change_pct, updated_at')
            .inFilter('ticker', remaining);
        final resolvedFromDb = <String>{};
        for (final row in (rows as List).whereType<Map>()) {
          final sym = row['ticker']?.toString();
          if (sym == null || sym.isEmpty || row['price'] is! num) continue;
          final double price = (row['price'] as num).toDouble();
          final double prevClose =
              (row['previous_close'] as num?)?.toDouble() ?? price;
          final double change = price - prevClose;
          final double changePct =
              (row['change_pct'] as num?)?.toDouble() ??
              (prevClose == 0 ? 0.0 : (change / prevClose) * 100);
          final item = YahooMarketItem(
            symbol: sym,
            name: displayNames?[sym] ?? sym,
            price: price,
            change: change,
            changePercent: changePct,
            spark: <double>[prevClose, price],
            category: category,
            isLive: true,
            timestamp:
                DateTime.tryParse('${row['updated_at']}') ?? DateTime.now(),
            source: 'Supabase Live DB',
          );
          _quoteCache['${category}_$sym'] = (
            item: item,
            expires: DateTime.now().add(_quoteTtl),
          );
          results[sym] = item;
          resolvedFromDb.add(sym);
        }
        remaining.removeWhere(resolvedFromDb.contains);
      } catch (_) {}
    }

    if (remaining.isEmpty || kIsWeb) return;

    // 2. Direct HTTP call on non-web native platforms only
    await Future.wait(
      remaining.map((symbol) async {
        try {
          final uri = Uri.https(
            'query1.finance.yahoo.com',
            '/v8/finance/chart/$symbol',
            {'interval': '1d', 'range': '5d'},
          );
          final res = await _client
              .get(
                uri,
                headers: const {
                  'Accept': 'application/json',
                  'User-Agent': 'AlphaJournal/1.0',
                },
              )
              .timeout(_requestTimeout);

          if (res.statusCode == 200) {
            final dynamic decoded = jsonDecode(res.body);
            final dynamic result = decoded?['chart']?['result']?[0];
            if (result is Map) {
              final meta = result['meta'] as Map?;
              final indicators = result['indicators']?['quote']?[0] as Map?;
              final price =
                  (meta?['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
              final prevClose =
                  (meta?['chartPreviousClose'] as num?)?.toDouble() ?? price;
              final change = price - prevClose;
              final changePct =
                  (meta?['regularMarketChangePercent'] as num?)?.toDouble() ??
                  (prevClose == 0 ? 0.0 : (change / prevClose) * 100);
              final closes =
                  (indicators?['close'] as List?)
                      ?.whereType<num>()
                      .map((n) => n.toDouble())
                      .where((v) => v.isFinite)
                      .toList() ??
                  [];

              final item = YahooMarketItem(
                symbol: symbol,
                name:
                    displayNames?[symbol] ??
                    (meta?['shortName'] as String?) ??
                    symbol,
                price: price,
                change: change,
                changePercent: changePct,
                spark: closes.isNotEmpty ? closes : [prevClose, price],
                category: category,
                isLive: true,
                timestamp: DateTime.now(),
                source: 'Direct Market Feed',
              );

              _quoteCache['${category}_$symbol'] = (
                item: item,
                expires: DateTime.now().add(_quoteTtl),
              );
              results[symbol] = item;
            }
          }
        } catch (_) {}
      }),
    );
  }

  /// Fetches market quote & sparkline via backend proxy or clean platform channel.
  Future<YahooMarketItem?> fetchQuote(
    String symbol, {
    String? displayName,
    String category = 'US Markets',
    bool forceRefresh = false,
  }) async {
    final map = await fetchQuotes(
      [symbol],
      displayNames: displayName != null ? {symbol: displayName} : null,
      category: category,
      forceRefresh: forceRefresh,
    );
    return map[symbol];
  }

  /// Fetches multiple index items in batched requests via [fetchQuotes].
  Future<Map<String, MarketIndexItem>> fetchIndexItems(
    List<({String symbol, String name})> items, {
    bool forceRefresh = false,
  }) async {
    final results = <String, MarketIndexItem>{};
    if (items.isEmpty) return results;

    final now = DateTime.now();
    final toFetch = <String>[];
    final namesBySymbol = <String, String>{};

    for (final entry in items) {
      namesBySymbol[entry.symbol] = entry.name;
      final cached = _indexCache[entry.symbol];
      if (!forceRefresh && cached != null && cached.expires.isAfter(now)) {
        results[entry.symbol] = cached.item;
      } else {
        toFetch.add(entry.symbol);
      }
    }

    if (toFetch.isNotEmpty) {
      final quotes = await fetchQuotes(
        toFetch,
        displayNames: namesBySymbol,
        category: 'Indices',
        forceRefresh: forceRefresh,
      );
      for (final sym in toFetch) {
        final q = quotes[sym];
        if (q != null) {
          final indexItem = MarketIndexItem(
            symbol: sym,
            name: namesBySymbol[sym] ?? q.name,
            price: q.price,
            changePercent: q.changePercent,
            spark: q.spark,
            isLive: q.isLive,
            timestamp: q.timestamp,
            source: q.source,
          );
          _indexCache[sym] = (
            item: indexItem,
            expires: DateTime.now().add(_quoteTtl),
          );
          results[sym] = indexItem;
        } else {
          final stale = _indexCache[sym]?.item;
          if (stale != null) {
            results[sym] = stale;
          }
        }
      }
    }

    return results;
  }

  /// Fetches index item for World Indices and Assets tables via backend proxy.
  Future<MarketIndexItem?> fetchIndexItem(
    String symbol,
    String name, {
    bool forceRefresh = false,
  }) async {
    final map = await fetchIndexItems([
      (symbol: symbol, name: name),
    ], forceRefresh: forceRefresh);
    return map[symbol];
  }

  /// Fetches sector performances via backend proxy or baseline calculation.
  Future<List<SectorPerformanceItem>> fetchSectors({
    bool forceRefresh = false,
  }) async {
    final cached = _sectorCache;
    if (!forceRefresh &&
        cached != null &&
        cached.expires.isAfter(DateTime.now())) {
      return cached.items;
    }

    if (_inFlightSectors != null) {
      return await _inFlightSectors!;
    }

    final future = _fetchSectorsInternal(cached);
    _inFlightSectors = future;
    try {
      return await future;
    } finally {
      _inFlightSectors = null;
    }
  }

  Future<List<SectorPerformanceItem>> _fetchSectorsInternal(
    ({List<SectorPerformanceItem> items, DateTime expires})? cached,
  ) async {
    // 1. Try Supabase Edge Function Backend Proxy
    if (SupabaseConfig.isConfigured && _canCallProxy) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client.functions
            .invoke('market-quote-proxy', body: {'action': 'sectors'})
            .timeout(_requestTimeout);

        if (res.status == 200 && res.data is Map) {
          _recordProxySuccess();
          final sectorsList = res.data['sectors'];
          if (sectorsList is List && sectorsList.isNotEmpty) {
            final items = sectorsList.map((raw) {
              final map = raw as Map;
              return SectorPerformanceItem(
                name: map['name'] as String? ?? '',
                marketWeight: (map['marketWeight'] as num?)?.toDouble() ?? 0.0,
                ytdReturn: (map['ytdReturn'] as num?)?.toDouble() ?? 0.0,
                dayReturn: (map['dayReturn'] as num?)?.toDouble() ?? 0.0,
                key: map['key'] as String? ?? '',
                isLive: map['isLive'] as bool? ?? true,
                timestamp: DateTime.now(),
                source: 'Market Quote Proxy',
              );
            }).toList();

            _sectorCache = (
              items: items,
              expires: DateTime.now().add(_sectorTtl),
            );
            return items;
          }
        } else {
          _recordProxyFailure();
        }
      } catch (e) {
        _recordProxyFailure();
        debugPrint('[YahooFinanceService] Proxy fetchSectors error: $e');
      }
    }

    // 2. Direct HTTP call on non-web native platforms only
    if (!kIsWeb) {
      final results = <SectorPerformanceItem>[];
      for (final s in kSectorMapping) {
        try {
          final uri = Uri.https(
            'query1.finance.yahoo.com',
            '/v8/finance/chart/${s.$2}',
            {'interval': '1d', 'range': 'ytd'},
          );
          final res = await _client
              .get(
                uri,
                headers: const {
                  'Accept': 'application/json',
                  'User-Agent': 'AlphaJournal/1.0',
                },
              )
              .timeout(const Duration(seconds: 3));

          if (res.statusCode == 200) {
            final dynamic decoded = jsonDecode(res.body);
            final dynamic result = decoded?['chart']?['result']?[0];
            if (result is Map) {
              final meta = result['meta'] as Map?;
              final indicators = result['indicators']?['quote']?[0] as Map?;
              final price =
                  (meta?['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
              final dayChangePct =
                  (meta?['regularMarketChangePercent'] as num?)?.toDouble() ??
                  0.0;
              final closes =
                  (indicators?['close'] as List?)
                      ?.whereType<num>()
                      .map((n) => n.toDouble())
                      .where((v) => v.isFinite)
                      .toList() ??
                  [];

              double ytdReturn = dayChangePct;
              if (closes.isNotEmpty && price > 0) {
                final startOfYearPrice = closes.first;
                if (startOfYearPrice > 0) {
                  ytdReturn =
                      ((price - startOfYearPrice) / startOfYearPrice) * 100;
                }
              }

              results.add(
                SectorPerformanceItem(
                  name: s.$1,
                  marketWeight: s.$4,
                  ytdReturn: ytdReturn,
                  dayReturn: dayChangePct,
                  key: s.$3,
                  isLive: true,
                  timestamp: DateTime.now(),
                  source: 'Direct Market Feed',
                ),
              );
            }
          }
        } catch (_) {}
      }
      if (results.isNotEmpty) {
        _sectorCache = (
          items: results,
          expires: DateTime.now().add(_sectorTtl),
        );
        return results;
      }
    }

    // 3. Fallback to cached items if available
    if (cached != null) {
      return cached.items;
    }

    // 4. Return offline baseline sectors
    return kSectorMapping
        .map(
          (s) => SectorPerformanceItem(
            name: s.$1,
            marketWeight: s.$4,
            ytdReturn: 0.0,
            dayReturn: 0.0,
            key: s.$3,
            isLive: false,
            timestamp: DateTime.parse('2026-09-04T00:00:00Z'),
            source: 'Offline Baseline',
          ),
        )
        .toList();
  }

  /// Fetches financial news via backend proxy or offline asset cache.
  Future<List<MarketArticle>> fetchLiveNews({
    String query = 'stock',
    int count = 25,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${query}_$count';
    final cached = _newsCache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        cached.expires.isAfter(DateTime.now())) {
      return cached.items;
    }

    final existing = _inFlightNews[cacheKey];
    if (existing != null) {
      return await existing;
    }

    final future = _fetchLiveNewsInternal(query, count, cacheKey, cached);
    _inFlightNews[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inFlightNews.remove(cacheKey);
    }
  }

  Future<List<MarketArticle>> _fetchLiveNewsInternal(
    String query,
    int count,
    String cacheKey,
    ({List<MarketArticle> items, DateTime expires})? cached,
  ) async {
    // 1. Try Supabase Edge Function Backend Proxy
    if (SupabaseConfig.isConfigured && _canCallProxy) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client.functions
            .invoke(
              'market-quote-proxy',
              body: {'action': 'news', 'query': query, 'count': count},
            )
            .timeout(_requestTimeout);

        if (res.status == 200 && res.data is Map) {
          _recordProxySuccess();
          final newsList = res.data['news'];
          if (newsList is List && newsList.isNotEmpty) {
            final articles = newsList
                .map(
                  (raw) => MarketArticle.fromJson(
                    Map<String, dynamic>.from(raw as Map),
                  ),
                )
                .toList();

            _newsCache[cacheKey] = (
              items: articles,
              expires: DateTime.now().add(_newsTtl),
            );
            return articles;
          }
        } else {
          _recordProxyFailure();
        }
      } catch (e) {
        _recordProxyFailure();
        debugPrint('[YahooFinanceService] Proxy fetchLiveNews error: $e');
      }
    }

    // 1b. Fallback to live Supabase news_articles table
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final rows = await client
            .from('news_articles')
            .select(
              'title, summary, link, publisher, thumbnail_url, content_type, published_at',
            )
            .order('published_at', ascending: false)
            .limit(count);
        if (rows.isNotEmpty) {
          final articles = rows
              .whereType<Map>()
              .map(
                (raw) => MarketArticle.fromJson(Map<String, dynamic>.from(raw)),
              )
              .toList();
          _newsCache[cacheKey] = (
            items: articles,
            expires: DateTime.now().add(_newsTtl),
          );
          return articles;
        }
      } catch (_) {}
    }

    // 2. Direct HTTP call on non-web native platforms only
    if (!kIsWeb) {
      try {
        final uri =
            Uri.https('query1.finance.yahoo.com', '/v1/finance/search', {
              'q': query,
              'newsCount': '$count',
              'quotesCount': '0',
              'enableFuzzyQuery': 'false',
            });
        final res = await _client
            .get(
              uri,
              headers: const {
                'Accept': 'application/json',
                'User-Agent': 'AlphaJournal/1.0',
              },
            )
            .timeout(_requestTimeout);

        if (res.statusCode == 200) {
          final dynamic decoded = jsonDecode(res.body);
          final dynamic newsList = decoded?['news'];
          if (newsList is List) {
            final articles = <MarketArticle>[];
            for (final raw in newsList) {
              if (raw is Map) {
                final title = raw['title'] as String? ?? '';
                final publisher =
                    raw['publisher'] as String? ?? 'Financial News';
                final link = raw['link'] as String? ?? '';
                final pubTime = raw['providerPublishTime'] is num
                    ? DateTime.fromMillisecondsSinceEpoch(
                        (raw['providerPublishTime'] as num).toInt() * 1000,
                      )
                    : DateTime.now();

                String? thumb;
                if (raw['thumbnail_url'] is String &&
                    (raw['thumbnail_url'] as String).isNotEmpty) {
                  thumb = raw['thumbnail_url'] as String;
                } else if (raw['thumbnail'] is Map) {
                  final thumbMap = raw['thumbnail'] as Map;
                  if (thumbMap['originalUrl'] is String &&
                      (thumbMap['originalUrl'] as String).isNotEmpty) {
                    thumb = thumbMap['originalUrl'] as String;
                  } else if (thumbMap['url'] is String &&
                      (thumbMap['url'] as String).isNotEmpty) {
                    thumb = thumbMap['url'] as String;
                  }
                  final thumbs = thumbMap['resolutions'];
                  if (thumb == null && thumbs is List && thumbs.isNotEmpty) {
                    final orig = thumbs.firstWhere(
                      (r) => r is Map && r['tag'] == 'original',
                      orElse: () => null,
                    );
                    if (orig is Map && orig['url'] is String) {
                      thumb = orig['url'] as String;
                    } else if (thumbs.first is Map &&
                        thumbs.first['url'] is String) {
                      thumb = thumbs.first['url'] as String;
                    }
                  }
                }

                final tickers = (raw['relatedTickers'] as List? ?? [])
                    .whereType<String>()
                    .toList();

                final rawSummary =
                    (raw['summary'] ?? raw['description'] ?? raw['snippet'])
                        as String?;
                final summary =
                    (rawSummary != null && rawSummary.trim().isNotEmpty)
                    ? rawSummary.trim()
                    : (tickers.isNotEmpty
                          ? 'Latest reporting on ${tickers.join(", ")} market developments and earnings outlook.'
                          : 'Market coverage from $publisher on equities and economic trends.');

                if (title.isNotEmpty) {
                  articles.add(
                    MarketArticle.fromJson({
                      'title': title,
                      'summary': summary,
                      'publisher': publisher,
                      'link': link,
                      'published_at': pubTime.toIso8601String(),
                      'thumbnail_url': thumb,
                      'related_tickers': tickers,
                    }),
                  );
                }
              }
            }
            if (articles.isNotEmpty) {
              _newsCache[cacheKey] = (
                items: articles,
                expires: DateTime.now().add(_newsTtl),
              );
              return articles;
            }
          }
        }
      } catch (_) {}
    }

    return cached?.items ?? [];
  }

  /// Clears in-memory quote and item caches.
  void clearCache() {
    _quoteCache.clear();
    _indexCache.clear();
    _sectorCache = null;
    _newsCache.clear();
    _proxyFailures = 0;
    _proxyBlockedUntil = null;
  }
}
