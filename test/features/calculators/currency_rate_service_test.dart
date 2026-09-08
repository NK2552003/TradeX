import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tradex/features/calculators/logic/currency_calculators.dart';
import 'package:tradex/features/calculators/services/currency_rate_service.dart';

void main() {
  group('CurrencyRatesSnapshot', () {
    test('initialFallback contains verified today rates and offline source', () {
      final CurrencyRatesSnapshot snap = CurrencyRatesSnapshot.initialFallback();

      expect(snap.base, 'USD');
      expect(snap.date, kRatesDate);
      expect(snap.isLive, isFalse);
      expect(snap.rateFor('USD'), 1.0);
      expect(snap.rateFor('INR'), closeTo(94.73, 1e-9));
      expect(snap.rateFor('EUR'), closeTo(0.86193, 1e-9));
      expect(snap.rateFor('UNKNOWN'), 1.0);
    });
  });

  group('CurrencyRateService', () {
    test('parses Frankfurter v2 flat array JSON response successfully', () async {
      final List<Map<String, dynamic>> mockV2Response = <Map<String, dynamic>>[
        <String, dynamic>{'date': '2026-09-04', 'base': 'USD', 'quote': 'EUR', 'rate': 0.86193},
        <String, dynamic>{'date': '2026-09-04', 'base': 'USD', 'quote': 'GBP', 'rate': 0.74097},
        <String, dynamic>{'date': '2026-09-04', 'base': 'USD', 'quote': 'INR', 'rate': 94.73},
        <String, dynamic>{'date': '2026-09-04', 'base': 'USD', 'quote': 'JPY', 'rate': 158.13},
      ];

      final MockClient client = MockClient((http.Request request) async {
        expect(request.url.host, 'api.frankfurter.dev');
        expect(request.url.path, '/v2/rates');
        expect(request.url.queryParameters['base'], 'USD');
        return http.Response(jsonEncode(mockV2Response), 200);
      });

      final CurrencyRateService service = CurrencyRateService(client: client);
      final CurrencyRatesSnapshot snapshot = await service.getRates();

      expect(snapshot.isLive, isTrue);
      expect(snapshot.date, '2026-09-04');
      expect(snapshot.source, 'Frankfurter v2');
      expect(snapshot.rateFor('EUR'), closeTo(0.86193, 1e-9));
      expect(snapshot.rateFor('GBP'), closeTo(0.74097, 1e-9));
      expect(snapshot.rateFor('INR'), closeTo(94.73, 1e-9));
      expect(snapshot.rateFor('JPY'), closeTo(158.13, 1e-9));
      expect(service.latestKnownRates.isLive, isTrue);
    });

    test('caches live rates and does not make duplicate network requests', () async {
      int requestCount = 0;
      final MockClient client = MockClient((http.Request request) async {
        requestCount++;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{'date': '2026-09-04', 'base': 'USD', 'quote': 'EUR', 'rate': 0.85},
          ]),
          200,
        );
      });

      final CurrencyRateService service = CurrencyRateService(client: client);
      await service.getRates();
      expect(requestCount, 1);

      // Second call should hit the in-memory cache
      final CurrencyRatesSnapshot second = await service.getRates();
      expect(requestCount, 1);
      expect(second.rateFor('EUR'), 0.85);

      // Forced refresh should trigger a new network call
      await service.getRates(forceRefresh: true);
      expect(requestCount, 2);
    });

    test('falls back gracefully to offline rates on 500 error or network failure', () async {
      final MockClient failingClient = MockClient((http.Request request) async {
        return http.Response('Internal Server Error', 500);
      });

      final CurrencyRateService service = CurrencyRateService(client: failingClient);
      final CurrencyRatesSnapshot snapshot = await service.getRates();

      expect(snapshot.isLive, isFalse);
      expect(snapshot.rateFor('INR'), closeTo(94.73, 1e-9));
      expect(snapshot.rateFor('USD'), 1.0);
    });

    test('fetches historical rates by date parameter', () async {
      final DateTime historicalDate = DateTime(2026, 1, 5);

      final MockClient client = MockClient((http.Request request) async {
        expect(request.url.queryParameters['date'], '2026-01-05');
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{'date': '2026-01-05', 'base': 'USD', 'quote': 'EUR', 'rate': 0.85431},
            <String, dynamic>{'date': '2026-01-05', 'base': 'USD', 'quote': 'INR', 'rate': 90.08},
          ]),
          200,
        );
      });

      final CurrencyRateService service = CurrencyRateService(client: client);
      final CurrencyRatesSnapshot snapshot = await service.getRates(date: historicalDate);

      expect(snapshot.isLive, isTrue);
      expect(snapshot.date, '2026-01-05');
      expect(snapshot.rateFor('EUR'), closeTo(0.85431, 1e-9));
      expect(snapshot.rateFor('INR'), closeTo(90.08, 1e-9));
    });

    test('cross-conversions work seamlessly with snapshot rates', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{'date': '2026-09-04', 'base': 'USD', 'quote': 'EUR', 'rate': 0.86193},
            <String, dynamic>{'date': '2026-09-04', 'base': 'USD', 'quote': 'INR', 'rate': 94.73},
          ]),
          200,
        );
      });

      final CurrencyRateService service = CurrencyRateService(client: client);
      final CurrencyRatesSnapshot snapshot = await service.getRates();

      final ConversionResult result = convertCurrency(
        amount: 100,
        from: 'EUR',
        to: 'INR',
        rates: snapshot.rates,
      );

      expect(result.rate, closeTo(94.73 / 0.86193, 1e-9));
      expect(result.converted, closeTo(100 * 94.73 / 0.86193, 1e-6));
    });
  });
}
