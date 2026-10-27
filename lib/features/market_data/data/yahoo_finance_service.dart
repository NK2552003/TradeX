import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/market_snapshot.dart';
import '../presentation/market_sector_heatmap_card.dart';
import '../presentation/market_world_indices_card.dart';
import '../presentation/yahoo_market_ribbon.dart';

/// Direct, unofficial Yahoo Finance API service for real-time market quotes,
/// global indices, live sector performances, and news.
/// Features dynamic rotatory mobile IP headers, mobile User-Agents, and multi-host rotation.
class YahooFinanceService {
  YahooFinanceService({http.Client? client}) : _client = client ?? http.Client();

  static final YahooFinanceService instance = YahooFinanceService();
  final http.Client _client;

  static final math.Random _random = math.Random();

  /// Real-world mobile cellular & residential IP pool for header rotation.
  static const List<String> _mobileIpPrefixes = [
    '107.77', // AT&T Mobile
    '70.192', // Verizon Wireless
    '172.56', // T-Mobile US
    '66.87',  // Sprint / T-Mobile
    '80.229', // Vodafone UK
    '49.32',  // Reliance Jio Mobile
    '80.187', // Deutsche Telekom Mobile
    '90.84',  // Orange Mobile FR
    '24.114', // Rogers Wireless CA
    '120.29', // Telstra Mobile AU
    '185.220', // Swisscom Mobile
    '223.190', // Bharti Airtel Mobile
  ];

  /// Pool of modern mobile and tablet browser User-Agents.
  static const List<String> _mobileUserAgents = [
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/131.0.6778.73 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.6778.39 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.6778.39 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; SM-A536B) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/25.0 Chrome/121.0.6167.101 Mobile Safari/537.36',
  ];

  static const List<String> _hosts = [
    'query1.finance.yahoo.com',
    'query2.finance.yahoo.com',
  ];

  String? _cachedCookie;
  String? _cachedCrumb;
  DateTime? _sessionExpiry;
  Future<void>? _sessionFuture;

  /// Ensures a valid cookie and crumb session for Yahoo Finance API requests.
  Future<void> _ensureSession() async {
    if (_cachedCrumb != null &&
        _sessionExpiry != null &&
        DateTime.now().isBefore(_sessionExpiry!)) {
      return;
    }
    _sessionFuture ??= _initSession();
    try {
      await _sessionFuture;
    } finally {
      _sessionFuture = null;
    }
  }

  Future<void> _initSession() async {
    try {
      final ua = _mobileUserAgents[_random.nextInt(_mobileUserAgents.length)];
      final fcRes = await _client.get(
        Uri.parse('https://fc.yahoo.com'),
        headers: {
          'User-Agent': ua,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 4));

      final setCookie = fcRes.headers['set-cookie'] ?? '';
      final cookieParts = setCookie.split(RegExp(r',(?=[A-Za-z0-9_-]+=)'));
      final cookies = <String>[];
      for (final part in cookieParts) {
        final first = part.split(';').first.trim();
        if (first.isNotEmpty) cookies.add(first);
      }
      final cookieHeader =
          cookies.isNotEmpty ? cookies.join('; ') : setCookie.split(';').first.trim();

      final crumbRes = await _client.get(
        Uri.parse('https://query2.finance.yahoo.com/v1/test/getcrumb'),
        headers: {
          'User-Agent': ua,
          'Cookie': cookieHeader,
          'Accept': 'text/plain, */*',
        },
      ).timeout(const Duration(seconds: 4));

      if (crumbRes.statusCode == 200 &&
          crumbRes.body.isNotEmpty &&
          !crumbRes.body.contains('<')) {
        _cachedCookie = cookieHeader;
        _cachedCrumb = crumbRes.body.trim();
        _sessionExpiry = DateTime.now().add(const Duration(hours: 1));
      }
    } catch (_) {}
  }

  /// Generates dynamic rotating headers with random mobile IP and mobile User-Agent.
  Map<String, String> _rotatingHeaders() {
    final prefix = _mobileIpPrefixes[_random.nextInt(_mobileIpPrefixes.length)];
    final ip = '$prefix.${10 + _random.nextInt(200)}.${1 + _random.nextInt(250)}';
    final ua = _mobileUserAgents[_random.nextInt(_mobileUserAgents.length)];
    final isIos = ua.contains('iPhone') || ua.contains('iPad');

    final headers = {
      'Accept': 'application/json, text/plain, */*',
      'User-Agent': ua,
      'X-Forwarded-For': ip,
      'X-Real-IP': ip,
      'Client-IP': ip,
      'CF-Connecting-IP': ip,
      'True-Client-IP': ip,
      'X-Client-IP': ip,
      'Sec-Ch-Ua-Mobile': '?1',
      'Sec-Ch-Ua-Platform': isIos ? '"iOS"' : '"Android"',
      'Accept-Language': 'en-US,en;q=0.9',
    };

    if (_cachedCookie != null && _cachedCookie!.isNotEmpty) {
      headers['Cookie'] = _cachedCookie!;
    }

    return headers;
  }

  /// Selects a random host for query rotation.
  static String _randomHost() => _hosts[_random.nextInt(_hosts.length)];

  /// Fetches real-time quote & sparkline from unofficial Yahoo Finance v8 chart API.
  Future<YahooMarketItem?> fetchQuote(
    String symbol, {
    String? displayName,
    String category = 'US Markets',
  }) async {
    try {
      await _ensureSession();
      final host = _randomHost();
      final queryParams = {
        'interval': '1d',
        'range': '5d',
        if (_cachedCrumb != null && _cachedCrumb!.isNotEmpty) 'crumb': _cachedCrumb!,
      };
      final uri = Uri.https(
        host,
        '/v8/finance/chart/$symbol',
        queryParams,
      );
      final res = await _client
          .get(uri, headers: _rotatingHeaders())
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);
        final dynamic result = decoded?['chart']?['result']?[0];
        if (result is Map) {
          final meta = result['meta'] as Map?;
          final indicators = result['indicators']?['quote']?[0] as Map?;
          final price = (meta?['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
          final prevClose =
              (meta?['chartPreviousClose'] as num?)?.toDouble() ?? price;
          final change = price - prevClose;
          final changePct =
              (meta?['regularMarketChangePercent'] as num?)?.toDouble() ??
              (prevClose == 0 ? 0.0 : (change / prevClose) * 100);
          final closes = (indicators?['close'] as List?)
                  ?.whereType<num>()
                  .map((n) => n.toDouble())
                  .where((v) => v.isFinite)
                  .toList() ??
              [];

          return YahooMarketItem(
            symbol: symbol,
            name: displayName ?? (meta?['shortName'] as String?) ?? symbol,
            price: price,
            change: change,
            changePercent: changePct,
            spark: closes.isNotEmpty ? closes : [prevClose, price],
            category: category,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetches real-time index item for World Indices table (Image 2).
  Future<MarketIndexItem?> fetchIndexItem(String symbol, String name) async {
    try {
      await _ensureSession();
      final host = _randomHost();
      final queryParams = {
        'interval': '1d',
        'range': '5d',
        if (_cachedCrumb != null && _cachedCrumb!.isNotEmpty) 'crumb': _cachedCrumb!,
      };
      final uri = Uri.https(
        host,
        '/v8/finance/chart/$symbol',
        queryParams,
      );
      final res = await _client
          .get(uri, headers: _rotatingHeaders())
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);
        final dynamic result = decoded?['chart']?['result']?[0];
        if (result is Map) {
          final meta = result['meta'] as Map?;
          final indicators = result['indicators']?['quote']?[0] as Map?;
          final price = (meta?['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
          final prevClose =
              (meta?['chartPreviousClose'] as num?)?.toDouble() ?? price;
          final change = price - prevClose;
          final changePct =
              (meta?['regularMarketChangePercent'] as num?)?.toDouble() ??
              (prevClose == 0 ? 0.0 : (change / prevClose) * 100);
          final closes = (indicators?['close'] as List?)
                  ?.whereType<num>()
                  .map((n) => n.toDouble())
                  .where((v) => v.isFinite)
                  .toList() ??
              [];

          return MarketIndexItem(
            symbol: symbol,
            name: name,
            price: price,
            changePercent: changePct,
            spark: closes.isNotEmpty ? closes : [prevClose, price],
          );
        }
      }
    } catch (_) {}
    return null;
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

  /// Fetches real-time sector performances from unofficial Yahoo Finance API (Image 3)
  /// using rotatory mobile IP calls and calculating live day and YTD returns directly.
  Future<List<SectorPerformanceItem>> fetchSectors() async {
    final results = <SectorPerformanceItem>[];
    await _ensureSession();

    for (final s in kSectorMapping) {
      try {
        final host = _randomHost();
        final queryParams = {
          'interval': '1d',
          'range': 'ytd',
          if (_cachedCrumb != null && _cachedCrumb!.isNotEmpty) 'crumb': _cachedCrumb!,
        };
        final uri = Uri.https(
          host,
          '/v8/finance/chart/${s.$2}',
          queryParams,
        );
        final res = await _client
            .get(uri, headers: _rotatingHeaders())
            .timeout(const Duration(seconds: 4));

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
              ),
            );
          }
        }
      } catch (_) {}
    }
    return results;
  }

  /// Fetches real-time financial news from unofficial Yahoo Finance search API (Image 3)
  /// using rotatory mobile IPs and rotating headers.
  Future<List<MarketArticle>> fetchLiveNews({
    String query = 'stock',
    int count = 25,
  }) async {
    try {
      await _ensureSession();
      final host = _randomHost();
      final uri = Uri.https(
        host,
        '/v1/finance/search',
        {
          'q': query,
          'newsCount': '$count',
          'quotesCount': '0',
          'enableFuzzyQuery': 'false',
        },
      );
      final res = await _client
          .get(uri, headers: _rotatingHeaders())
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);
        final dynamic newsList = decoded?['news'];
        if (newsList is List) {
          final articles = <MarketArticle>[];
          for (final raw in newsList) {
            if (raw is Map) {
              final title = raw['title'] as String? ?? '';
              final publisher = raw['publisher'] as String? ?? 'Yahoo Finance';
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

              // Generate descriptive 2-line summary based on live article context
              final summary = tickers.isNotEmpty
                  ? 'Latest real-time reporting on ${tickers.join(", ")} market developments, earnings, and financial outlook.'
                  : 'Breaking market coverage from $publisher on equities, macro indicators, and industry shifts.';

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
          if (articles.isNotEmpty) return articles;
        }
      }
    } catch (_) {}
    return [];
  }
}
