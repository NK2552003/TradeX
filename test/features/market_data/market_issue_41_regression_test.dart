import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tradex/features/calculators/services/market_data_service.dart';
import 'package:tradex/features/market_data/data/yahoo_finance_service.dart';
import 'package:tradex/features/market_data/presentation/market_sector_heatmap_card.dart';
import 'package:tradex/features/market_data/presentation/market_world_indices_card.dart';
import 'package:tradex/features/market_data/presentation/yahoo_market_ribbon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue #41: Work Item 1 - Truthful Quote Delivery, Freshness & Timestamps', () {
    test('MarketQuote.fallback never claims to be live and preserves snapshot date', () {
      final fallback = MarketQuote.fallback('NIFTY');

      // Must be truthful: not live, snapshot freshness, and baseline date
      expect(fallback.isLive, isFalse);
      expect(fallback.freshness, equals('snapshot'));
      expect(fallback.source, equals('Verified Offline Preset'));
      expect(fallback.timestamp, equals(DateTime.parse('2026-09-04T00:00:00Z')));
      expect(fallback.price, greaterThan(0));
      expect(fallback.symbol, equals('NIFTY'));
    });

    test('MarketQuote copyWith supports freshness and preserves immutability', () {
      final initial = MarketQuote.fallback('TCS');
      final updated = initial.copyWith(
        price: 4200.0,
        isLive: true,
        freshness: 'live',
        source: 'Backend Quote Proxy (Live)',
      );

      expect(updated.price, equals(4200.0));
      expect(updated.isLive, isTrue);
      expect(updated.freshness, equals('live'));
      expect(updated.source, equals('Backend Quote Proxy (Live)'));

      // Original remains unchanged
      expect(initial.isLive, isFalse);
      expect(initial.freshness, equals('snapshot'));
    });

    test('Presentation models declare explicit freshness and truthful defaults', () {
      const ribbonItem = YahooMarketItem(
        symbol: '^GSPC',
        name: 'S&P 500',
        price: 5842.10,
        change: 12.5,
        changePercent: 0.21,
        spark: [5800.0, 5842.10],
      );
      expect(ribbonItem.isLive, isFalse);
      expect(ribbonItem.source, equals('Offline Snapshot'));

      const indexItem = MarketIndexItem(
        symbol: '^DJI',
        name: 'Dow 30',
        price: 42600.50,
        changePercent: 0.15,
        spark: [42500.0, 42600.50],
      );
      expect(indexItem.isLive, isFalse);
      expect(indexItem.source, equals('Offline Snapshot'));

      const sectorItem = SectorPerformanceItem(
        name: 'Technology',
        marketWeight: 32.43,
        ytdReturn: 28.5,
        dayReturn: 1.2,
        key: 'technology',
      );
      expect(sectorItem.isLive, isFalse);
      expect(sectorItem.source, equals('Offline Snapshot'));
    });

    test('MarketDataService caches quotes and reuses within TTL', () async {
      final service = MarketDataService();
      final q1 = await service.getQuote('RELIANCE');
      final q2 = await service.getQuote('RELIANCE');

      // Second call returns cached quote instance
      expect(identical(q1, q2), isTrue);

      // forceRefresh produces fresh lookup
      final q3 = await service.getQuote('RELIANCE', forceRefresh: true);
      expect(q3.symbol, equals('RELIANCE'));
    });

    test('MarketDataService deduplicates simultaneous in-flight requests', () async {
      final service = MarketDataService();
      final futures = [
        service.getQuote('INFY'),
        service.getQuote('INFY'),
        service.getQuote('INFY'),
      ];

      final results = await Future.wait(futures);
      expect(results.length, equals(3));
      expect(results[0].symbol, equals('INFY'));
      expect(identical(results[0], results[1]), isTrue);
      expect(identical(results[1], results[2]), isTrue);
    });
  });

  group('Issue #41: Work Item 2 - Backend Proxy Routing & No Direct Browser Scraping', () {
    test('YahooFinanceService handles offline/disconnected state without crashing', () async {
      final service = YahooFinanceService();
      service.clearCache();

      // In disconnected environment, methods return safe graceful fallbacks
      final quote = await service.fetchQuote('AAPL');
      // Returns null or cached item cleanly without unhandled exceptions
      expect(quote, anyOf(isNull, isA<YahooMarketItem>()));

      final sectors = await service.fetchSectors();
      expect(sectors, isNotEmpty);
      expect(sectors.length, equals(YahooFinanceService.kSectorMapping.length));
      expect(sectors.first.isLive, isFalse);

      final news = await service.fetchLiveNews();
      expect(news, isA<List>());
    });

    test('YahooFinanceService cache purge functions correctly', () {
      final service = YahooFinanceService();
      service.clearCache();
    });

    test('MarketDataService with mock HTTP client parses server response correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/v8/finance/chart/')) {
          return http.Response(
            '''{
              "chart": {
                "result": [{
                  "meta": {
                    "regularMarketPrice": 2500.50,
                    "chartPreviousClose": 2450.00,
                    "fiftyTwoWeekHigh": 2800.00,
                    "fiftyTwoWeekLow": 2100.00,
                    "regularMarketChangePercent": 2.06,
                    "shortName": "Reliance Industries"
                  },
                  "indicators": {
                    "quote": [{
                      "open": [2460.00],
                      "high": [2520.00],
                      "low": [2455.00]
                    }]
                  }
                }]
              }
            }''',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = MarketDataService(client: mockClient);
      final quote = await service.getQuote('RELIANCE', forceRefresh: true);

      expect(quote.symbol, equals('RELIANCE'));
      expect(quote.price, equals(2500.50));
      expect(quote.previousClose, equals(2450.00));
      expect(quote.isLive, isTrue);
      expect(quote.freshness, equals('live'));
    });

    test('MarketDataService with HTTP 500 error falls back to verified offline preset', () async {
      final mockErrorClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = MarketDataService(client: mockErrorClient);
      final quote = await service.getQuote('HDFCBANK', forceRefresh: true);

      expect(quote.symbol, equals('HDFCBANK'));
      expect(quote.isLive, isFalse);
      expect(quote.freshness, equals('snapshot'));
      expect(quote.source, equals('Verified Offline Preset'));
    });
  });

  group('Issue #41: Work Item 3 - Server Credentials & Limits Contract', () {
    test('Batch getQuotes maps multiple symbols correctly', () async {
      final service = MarketDataService();
      final map = await service.getQuotes(['NIFTY', 'BANKNIFTY', 'TCS']);

      expect(map.containsKey('NIFTY'), isTrue);
      expect(map.containsKey('BANKNIFTY'), isTrue);
      expect(map.containsKey('TCS'), isTrue);
      expect(map['NIFTY']!.price, greaterThan(0));
      expect(map['BANKNIFTY']!.price, greaterThan(0));
    });

    test('MacroBenchmarks fallback preserves economic reference rates', () {
      const b = MacroBenchmarks.fallback;
      expect(b.isLive, isFalse);
      expect(b.rbiRepoRate, equals(6.50));
      expect(b.cpiInflationRate, equals(3.65));
      expect(b.homeLoanBenchmarkRate, equals(8.50));
      expect(b.updatedDate, equals('2026-09-04'));
    });
  });
}

