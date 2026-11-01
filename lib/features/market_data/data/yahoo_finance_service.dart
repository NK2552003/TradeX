import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tradex/core/config/supabase_config.dart';
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
  YahooFinanceService({http.Client? client}) : _client = client ?? http.Client();

  static final YahooFinanceService instance = YahooFinanceService();
  final http.Client _client;

  // In-memory cache structures with TTL
  final Map<String, ({YahooMarketItem item, DateTime expires})> _quoteCache = {};
  final Map<String, ({MarketIndexItem item, DateTime expires})> _indexCache = {};
  ({List<SectorPerformanceItem> items, DateTime expires})? _sectorCache;
  final Map<String, ({List<MarketArticle> items, DateTime expires})> _newsCache = {};

  static const Duration _quoteTtl = Duration(minutes: 1);
  static const Duration _sectorTtl = Duration(minutes: 5);
  static const Duration _newsTtl = Duration(minutes: 5);
  static const Duration _requestTimeout = Duration(seconds: 5);

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

  /// Fetches market quote & sparkline via backend proxy or clean platform channel.
  Future<YahooMarketItem?> fetchQuote(
    String symbol, {
    String? displayName,
    String category = 'US Markets',
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${category}_$symbol';
    final cached = _quoteCache[cacheKey];
    if (!forceRefresh && cached != null && cached.expires.isAfter(DateTime.now())) {
      return cached.item;
    }

    // 1. Try Supabase Edge Function Backend Proxy
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client.functions.invoke(
          'market-quote-proxy',
          body: {
            'action': 'quotes',
            'symbols': [symbol],
          },
        ).timeout(_requestTimeout);

        if (res.status == 200 && res.data is Map) {
          final quotesMap = res.data['quotes'];
          if (quotesMap is Map && quotesMap[symbol] is Map) {
            final q = quotesMap[symbol] as Map;
            final double price = (q['price'] as num?)?.toDouble() ?? 0.0;
            final double prevClose = (q['previousClose'] as num?)?.toDouble() ?? price;
            final double change = (q['change'] as num?)?.toDouble() ?? (price - prevClose);
            final double changePct = (q['changePercent'] as num?)?.toDouble() ??
                (prevClose == 0 ? 0.0 : (change / prevClose) * 100);
            final List<double> spark = (q['spark'] as List?)
                    ?.whereType<num>()
                    .map((n) => n.toDouble())
                    .toList() ??
                [prevClose, price];
            final String name = displayName ?? (q['name'] as String?) ?? symbol;
            final bool isLive = q['isLive'] as bool? ?? true;
            final DateTime timestamp = q['timestamp'] != null
                ? DateTime.tryParse(q['timestamp'].toString()) ?? DateTime.now()
                : DateTime.now();
            final String source = (q['source'] as String?) ?? 'Market Quote Proxy';

            final item = YahooMarketItem(
              symbol: symbol,
              name: name,
              price: price,
              change: change,
              changePercent: changePct,
              spark: spark,
              category: category,
              isLive: isLive,
              timestamp: timestamp,
              source: source,
            );

            _quoteCache[cacheKey] = (item: item, expires: DateTime.now().add(_quoteTtl));
            return item;
          }
        }
      } catch (e) {
        debugPrint('[YahooFinanceService] Proxy fetchQuote error: $e');
      }
    }

    // 2. Direct HTTP call on non-web native platforms only
    if (!kIsWeb) {
      try {
        final uri = Uri.https(
          'query1.finance.yahoo.com',
          '/v8/finance/chart/$symbol',
          {'interval': '1d', 'range': '5d'},
        );
        final res = await _client.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'TradeX/1.0',
          },
        ).timeout(_requestTimeout);

        if (res.statusCode == 200) {
          final dynamic decoded = jsonDecode(res.body);
          final dynamic result = decoded?['chart']?['result']?[0];
          if (result is Map) {
            final meta = result['meta'] as Map?;
            final indicators = result['indicators']?['quote']?[0] as Map?;
            final price = (meta?['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
            final prevClose = (meta?['chartPreviousClose'] as num?)?.toDouble() ?? price;
            final change = price - prevClose;
            final changePct = (meta?['regularMarketChangePercent'] as num?)?.toDouble() ??
                (prevClose == 0 ? 0.0 : (change / prevClose) * 100);
            final closes = (indicators?['close'] as List?)
                    ?.whereType<num>()
                    .map((n) => n.toDouble())
                    .where((v) => v.isFinite)
                    .toList() ??
                [];

            final item = YahooMarketItem(
              symbol: symbol,
              name: displayName ?? (meta?['shortName'] as String?) ?? symbol,
              price: price,
              change: change,
              changePercent: changePct,
              spark: closes.isNotEmpty ? closes : [prevClose, price],
              category: category,
              isLive: true,
              timestamp: DateTime.now(),
              source: 'Direct Market Feed',
            );

            _quoteCache[cacheKey] = (item: item, expires: DateTime.now().add(_quoteTtl));
            return item;
          }
        }
      } catch (_) {}
    }

    // 3. Fallback to cached item if available
    return cached?.item;
  }

  /// Fetches index item for World Indices and Assets tables via backend proxy.
  Future<MarketIndexItem?> fetchIndexItem(
    String symbol,
    String name, {
    bool forceRefresh = false,
  }) async {
    final cached = _indexCache[symbol];
    if (!forceRefresh && cached != null && cached.expires.isAfter(DateTime.now())) {
      return cached.item;
    }

    // 1. Try Supabase Edge Function Backend Proxy
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client.functions.invoke(
          'market-quote-proxy',
          body: {
            'action': 'quotes',
            'symbols': [symbol],
          },
        ).timeout(_requestTimeout);

        if (res.status == 200 && res.data is Map) {
          final quotesMap = res.data['quotes'];
          if (quotesMap is Map && quotesMap[symbol] is Map) {
            final q = quotesMap[symbol] as Map;
            final double price = (q['price'] as num?)?.toDouble() ?? 0.0;
            final double prevClose = (q['previousClose'] as num?)?.toDouble() ?? price;
            final double change = (q['change'] as num?)?.toDouble() ?? (price - prevClose);
            final double changePct = (q['changePercent'] as num?)?.toDouble() ??
                (prevClose == 0 ? 0.0 : (change / prevClose) * 100);
            final List<double> spark = (q['spark'] as List?)
                    ?.whereType<num>()
                    .map((n) => n.toDouble())
                    .toList() ??
                [prevClose, price];
            final bool isLive = q['isLive'] as bool? ?? true;
            final DateTime timestamp = q['timestamp'] != null
                ? DateTime.tryParse(q['timestamp'].toString()) ?? DateTime.now()
                : DateTime.now();
            final String source = (q['source'] as String?) ?? 'Market Quote Proxy';

            final item = MarketIndexItem(
              symbol: symbol,
              name: name,
              price: price,
              changePercent: changePct,
              spark: spark,
              isLive: isLive,
              timestamp: timestamp,
              source: source,
            );

            _indexCache[symbol] = (item: item, expires: DateTime.now().add(_quoteTtl));
            return item;
          }
        }
      } catch (e) {
        debugPrint('[YahooFinanceService] Proxy fetchIndexItem error: $e');
      }
    }

    // 2. Direct HTTP call on non-web native platforms only
    if (!kIsWeb) {
      try {
        final uri = Uri.https(
          'query1.finance.yahoo.com',
          '/v8/finance/chart/$symbol',
          {'interval': '1d', 'range': '5d'},
        );
        final res = await _client.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'TradeX/1.0',
          },
        ).timeout(_requestTimeout);

        if (res.statusCode == 200) {
          final dynamic decoded = jsonDecode(res.body);
          final dynamic result = decoded?['chart']?['result']?[0];
          if (result is Map) {
            final meta = result['meta'] as Map?;
            final indicators = result['indicators']?['quote']?[0] as Map?;
            final price = (meta?['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
            final prevClose = (meta?['chartPreviousClose'] as num?)?.toDouble() ?? price;
            final change = price - prevClose;
            final changePct = (meta?['regularMarketChangePercent'] as num?)?.toDouble() ??
                (prevClose == 0 ? 0.0 : (change / prevClose) * 100);
            final closes = (indicators?['close'] as List?)
                    ?.whereType<num>()
                    .map((n) => n.toDouble())
                    .where((v) => v.isFinite)
                    .toList() ??
                [];

            final item = MarketIndexItem(
              symbol: symbol,
              name: name,
              price: price,
              changePercent: changePct,
              spark: closes.isNotEmpty ? closes : [prevClose, price],
              isLive: true,
              timestamp: DateTime.now(),
              source: 'Direct Market Feed',
            );

            _indexCache[symbol] = (item: item, expires: DateTime.now().add(_quoteTtl));
            return item;
          }
        }
      } catch (_) {}
    }

    return cached?.item;
  }

  /// Fetches sector performances via backend proxy or baseline calculation.
  Future<List<SectorPerformanceItem>> fetchSectors({bool forceRefresh = false}) async {
    final cached = _sectorCache;
    if (!forceRefresh && cached != null && cached.expires.isAfter(DateTime.now())) {
      return cached.items;
    }

    // 1. Try Supabase Edge Function Backend Proxy
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client.functions.invoke(
          'market-quote-proxy',
          body: {'action': 'sectors'},
        ).timeout(_requestTimeout);

        if (res.status == 200 && res.data is Map) {
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

            _sectorCache = (items: items, expires: DateTime.now().add(_sectorTtl));
            return items;
          }
        }
      } catch (e) {
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
          final res = await _client.get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'TradeX/1.0',
            },
          ).timeout(const Duration(seconds: 3));

          if (res.statusCode == 200) {
            final dynamic decoded = jsonDecode(res.body);
            final dynamic result = decoded?['chart']?['result']?[0];
            if (result is Map) {
              final meta = result['meta'] as Map?;
              final indicators = result['indicators']?['quote']?[0] as Map?;
              final price = (meta?['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
              final dayChangePct =
                  (meta?['regularMarketChangePercent'] as num?)?.toDouble() ?? 0.0;
              final closes = (indicators?['close'] as List?)
                      ?.whereType<num>()
                      .map((n) => n.toDouble())
                      .where((v) => v.isFinite)
                      .toList() ??
                  [];

              double ytdReturn = dayChangePct;
              if (closes.isNotEmpty && price > 0) {
                final startOfYearPrice = closes.first;
                if (startOfYearPrice > 0) {
                  ytdReturn = ((price - startOfYearPrice) / startOfYearPrice) * 100;
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
        _sectorCache = (items: results, expires: DateTime.now().add(_sectorTtl));
        return results;
      }
    }

    // 3. Fallback to cached items if available
    if (cached != null) {
      return cached.items;
    }

    // 4. Return offline baseline sectors
    return kSectorMapping.map((s) => SectorPerformanceItem(
      name: s.$1,
      marketWeight: s.$4,
      ytdReturn: 0.0,
      dayReturn: 0.0,
      key: s.$3,
      isLive: false,
      timestamp: DateTime.parse('2026-09-04T00:00:00Z'),
      source: 'Offline Baseline',
    )).toList();
  }

  /// Fetches financial news via backend proxy or offline asset cache.
  Future<List<MarketArticle>> fetchLiveNews({
    String query = 'stock',
    int count = 25,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${query}_$count';
    final cached = _newsCache[cacheKey];
    if (!forceRefresh && cached != null && cached.expires.isAfter(DateTime.now())) {
      return cached.items;
    }

    // 1. Try Supabase Edge Function Backend Proxy
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final res = await client.functions.invoke(
          'market-quote-proxy',
          body: {
            'action': 'news',
            'query': query,
            'count': count,
          },
        ).timeout(_requestTimeout);

        if (res.status == 200 && res.data is Map) {
          final newsList = res.data['news'];
          if (newsList is List && newsList.isNotEmpty) {
            final articles = newsList
                .map((raw) => MarketArticle.fromJson(Map<String, dynamic>.from(raw as Map)))
                .toList();

            _newsCache[cacheKey] = (items: articles, expires: DateTime.now().add(_newsTtl));
            return articles;
          }
        }
      } catch (e) {
        debugPrint('[YahooFinanceService] Proxy fetchLiveNews error: $e');
      }
    }

    // 2. Direct HTTP call on non-web native platforms only
    if (!kIsWeb) {
      try {
        final uri = Uri.https(
          'query1.finance.yahoo.com',
          '/v1/finance/search',
          {
            'q': query,
            'newsCount': '$count',
            'quotesCount': '0',
            'enableFuzzyQuery': 'false',
          },
        );
        final res = await _client.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'TradeX/1.0',
          },
        ).timeout(_requestTimeout);

        if (res.statusCode == 200) {
          final dynamic decoded = jsonDecode(res.body);
          final dynamic newsList = decoded?['news'];
          if (newsList is List) {
            final articles = <MarketArticle>[];
            for (final raw in newsList) {
              if (raw is Map) {
                final title = raw['title'] as String? ?? '';
                final publisher = raw['publisher'] as String? ?? 'Financial News';
                final link = raw['link'] as String? ?? '';
                final pubTime = raw['providerPublishTime'] is num
                    ? DateTime.fromMillisecondsSinceEpoch(
                        (raw['providerPublishTime'] as num).toInt() * 1000,
                      )
                    : DateTime.now();

                String? thumb;
                final thumbs = raw['thumbnail']?['resolutions'];
                if (thumbs is List && thumbs.isNotEmpty) {
                  thumb = thumbs.first?['url'] as String?;
                }

                final tickers = (raw['relatedTickers'] as List? ?? [])
                    .whereType<String>()
                    .toList();

                final summary = tickers.isNotEmpty
                    ? 'Latest reporting on ${tickers.join(", ")} market developments and earnings outlook.'
                    : 'Market coverage from $publisher on equities and economic trends.';

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
              _newsCache[cacheKey] = (items: articles, expires: DateTime.now().add(_newsTtl));
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
  }
}
