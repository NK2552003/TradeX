import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tradex/features/calculators/services/market_data_service.dart';

void main() {
  group('MarketQuote', () {
    test('fallback returns verified presets for indices', () {
      final MarketQuote nifty = MarketQuote.fallback('NIFTY');
      expect(nifty.price, 23901.60);
      expect(nifty.high, 23949.85);
      expect(nifty.low, 23895.85);
      expect(nifty.fiftyTwoWeekHigh, 26373.20);
      expect(nifty.fiftyTwoWeekLow, 22182.55);
      expect(nifty.isLive, isFalse);
    });
  });

  group('MarketDataService', () {
    test('parses Yahoo Finance v8 chart JSON correctly', () async {
      final Map<String, dynamic> mockYahooResponse = <String, dynamic>{
        'chart': <String, dynamic>{
          'result': <dynamic>[
            <String, dynamic>{
              'meta': <String, dynamic>{
                'currency': 'INR',
                'symbol': '^NSEI',
                'regularMarketPrice': 24100.50,
                'chartPreviousClose': 24000.00,
                'fiftyTwoWeekHigh': 26000.00,
                'fiftyTwoWeekLow': 21000.00,
                'longName': 'NIFTY 50',
              },
              'indicators': <String, dynamic>{
                'quote': <dynamic>[
                  <String, dynamic>{
                    'open': <dynamic>[24050.0],
                    'high': <dynamic>[24150.0],
                    'low': <dynamic>[23980.0],
                  },
                ],
              },
            },
          ],
        },
      };

      final MockClient client = MockClient((http.Request request) async {
        expect(request.url.host, 'query1.finance.yahoo.com');
        return http.Response(jsonEncode(mockYahooResponse), 200);
      });

      final MarketDataService service = MarketDataService(client: client);
      final MarketQuote quote = await service.getQuote('NIFTY');

      expect(quote.isLive, isTrue);
      expect(quote.price, 24100.50);
      expect(quote.open, 24050.0);
      expect(quote.high, 24150.0);
      expect(quote.low, 23980.0);
      expect(quote.fiftyTwoWeekHigh, 26000.0);
      expect(quote.fiftyTwoWeekLow, 21000.0);
      expect(quote.changePercent, closeTo((24100.50 - 24000.00) / 24000.00 * 100, 1e-6));
    });

    test('falls back gracefully on network failure without throwing', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response('Server error', 500);
      });

      final MarketDataService service = MarketDataService(client: client);
      final MarketQuote quote = await service.getQuote('NIFTY');

      expect(quote.isLive, isFalse);
      expect(quote.price, 23901.60);
      expect(quote.high, 23949.85);
    });

    test('parses World Bank CPI inflation rate', () async {
      final List<dynamic> mockWorldBankResponse = <dynamic>[
        <String, dynamic>{'page': 1, 'pages': 1},
        <dynamic>[
          <String, dynamic>{
            'country': <String, dynamic>{'value': 'India'},
            'date': '2025',
            'value': 3.85,
          },
        ],
      ];

      final MockClient client = MockClient((http.Request request) async {
        expect(request.url.host, 'api.worldbank.org');
        return http.Response(jsonEncode(mockWorldBankResponse), 200);
      });

      final MarketDataService service = MarketDataService(client: client);
      final MacroBenchmarks benchmarks = await service.getMacroBenchmarks();

      expect(benchmarks.isLive, isTrue);
      expect(benchmarks.cpiInflationRate, 3.85);
      expect(benchmarks.rbiRepoRate, 6.50);
      expect(benchmarks.ppfRate, 7.10);
    });
  });
}
