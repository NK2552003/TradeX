import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/features/markets/data/market_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'JSON adapter accepts nullable data and rejects invalid quotes',
    () async {
      final repository = JsonMarketRepository(
        baseUrl: 'http://localhost:8000',
        client: MockClient((request) async {
          final payload = switch (request.url.path) {
            '/quotes.json' => {
              'AAPL': {'price': 200, 'change_pct': null},
              'BAD': {'price': null},
            },
            '/fundamentals.json' => <String, dynamic>{},
            '/news.json' => [
              {'title': 'Story', 'link': 'https://example.com/story'},
              {'title': 'Story', 'link': 'https://example.com/story'},
            ],
            _ => {
              'data': [
                {
                  'date': '2026-09-01',
                  'open': 190,
                  'high': 202,
                  'low': 189,
                  'close': 200,
                  'volume': 20,
                },
                {
                  'date': '2026-09-02',
                  'open': 190,
                  'high': 150,
                  'low': 189,
                  'close': 200,
                },
              ],
            },
          };
          return http.Response(jsonEncode(payload), 200);
        }),
      );
      final snapshot = await repository.load();
      expect(snapshot.instruments.single.symbol, 'AAPL');
      expect(snapshot.instruments.single.changeLabel, '—');
      expect(snapshot.news.length, 1);
      expect((await repository.history('AAPL')).length, 1);
    },
  );

  test(
    'failed endpoint uses labeled bundled data; history stays consistent',
    () async {
      final repository = JsonMarketRepository(
        baseUrl: 'http://localhost:8000',
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      final snapshot = await repository.load();
      expect(snapshot.fallback, isTrue);
      expect(snapshot.instruments.length, 11);
      expect(snapshot.instruments.any((q) => q.demo), isTrue);
      final history = await repository.history(
        snapshot.instruments.first.symbol,
      );
      expect(history.length, greaterThan(5));
    },
  );

  test('remote history failure cannot display unrelated demo prices', () async {
    final repository = JsonMarketRepository(
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        if (request.url.path.startsWith('/history/')) {
          return http.Response('failed', 500);
        }
        return http.Response(
          jsonEncode(switch (request.url.path) {
            '/quotes.json' => {
              'AAPL': {'price': 900},
            },
            '/fundamentals.json' => {},
            _ => [],
          }),
          200,
        );
      }),
    );
    await repository.load();
    await expectLater(repository.history('AAPL'), throwsStateError);
  });

  test('watchlist operations and bookmarks survive a new store', () async {
    SharedPreferences.setMockInitialValues({});
    final first = MarketWorkspaceStore();
    await first.initialize();
    expect(first.createList('Breakouts'), isTrue);
    expect(first.createList('breakouts'), isFalse);
    first.toggleSymbol('AAPL');
    first.toggleSymbol('NVDA');
    first.moveSymbol('NVDA', -1);
    first.toggleBookmark('article-1');
    expect(first.watched, ['NVDA', 'AAPL']);
    // Each preference write is serialized; settle all pending platform futures.
    await first.flush();
    final second = MarketWorkspaceStore();
    await second.initialize();
    expect(second.activeList, 'Breakouts');
    expect(second.watched, ['NVDA', 'AAPL']);
    expect(second.bookmarks, contains('article-1'));
    first.dispose();
    second.dispose();
  });
}
