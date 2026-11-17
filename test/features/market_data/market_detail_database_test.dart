import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart';

const _quote = {'ticker': 'AAPL', 'price': 250, 'previous_close': 245};
const _optionalTables = [
  'analyst_recommendations',
  'holders',
  'dividends',
  'stock_splits',
  'stock_details',
];

SupabaseClient _client({
  String? unavailableTable,
  String errorCode = 'PGRST205',
}) => SupabaseClient(
  'https://example.test',
  'test-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    final table = request.url.pathSegments.last;
    if (table == unavailableTable) {
      return http.Response(
        jsonEncode({'code': errorCode, 'message': 'Table request failed'}),
        errorCode == '42501' ? 403 : 404,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    final rows = switch (table) {
      'tickers' => [
        {'ticker': 'AAPL', 'name': 'Apple Inc.', 'market': 'US'},
      ],
      'stock_quotes' => [_quote],
      'stock_fundamentals' => [
        {'ticker': 'AAPL', 'sector': 'Technology', 'pe_ratio': 30},
      ],
      'stock_price_history' => [
        {
          'date': '2026-11-06',
          'open': 245,
          'high': 251,
          'low': 244,
          'close': 250,
        },
        {
          'date': '2026-11-05',
          'open': 240,
          'high': 246,
          'low': 239,
          'close': 245,
        },
      ],
      'stock_splits' => [
        {'split_date': '2020-08-31', 'ratio': 4},
      ],
      _ => [],
    };
    return http.Response(
      jsonEncode(rows),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }),
);

void main() {
  for (final table in _optionalTables) {
    test('missing $table preserves quote, fundamentals and history', () async {
      final client = _client(unavailableTable: table);
      addTearDown(client.dispose);
      final detail = await AssetMarketRepository(client: client).detail('AAPL');
      expect(detail['quote']['price'], 250);
      expect(detail['summary']['sector'], 'Technology');
      expect(detail['chart']['data'].map((row) => row['close']), [245, 250]);
      if (table == 'stock_splits') {
        expect(detail['dividends_and_splits']['splits'], isEmpty);
      } else {
        expect(detail['dividends_and_splits']['splits'].single['ratio'], 4);
      }
    });
  }

  test('missing SQL relation also leaves the instrument usable', () async {
    final client = _client(
      unavailableTable: 'stock_splits',
      errorCode: '42P01',
    );
    addTearDown(client.dispose);
    final detail = await AssetMarketRepository(client: client).detail('AAPL');
    expect(detail['quote']['price'], 250);
  });

  test('a required quote table error still surfaces', () async {
    final client = _client(unavailableTable: 'stock_quotes');
    addTearDown(client.dispose);
    await expectLater(
      AssetMarketRepository(client: client).detail('AAPL'),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'optional table permission errors are not disguised as missing data',
    () async {
      final client = _client(
        unavailableTable: 'stock_splits',
        errorCode: '42501',
      );
      addTearDown(client.dispose);
      await expectLater(
        AssetMarketRepository(client: client).detail('AAPL'),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  for (final width in [1440.0, 390.0]) {
    testWidgets(
      'instrument details render without stock_splits at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final client = (await tester.runAsync(
          () async => _client(unavailableTable: 'stock_splits'),
        ))!;
        addTearDown(() => tester.runAsync(client.dispose));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MarketInstrumentView(
                  instrument: MarketInstrument.fromJson(_quote, {
                    'name': 'Apple Inc.',
                  }),
                  repository: AssetMarketRepository(client: client),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Instrument details unavailable'), findsNothing);
        expect(find.text('Apple Inc.'), findsWidgets);
        expect(find.text('Technology'), findsWidgets);
        expect(find.byType(UiCandleChart), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test('snapshot scopes quotes, fundamentals and screeners to market_universe', () async {
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        final rows = switch (table) {
          'market_universe' => [
            {
              'ticker': 'AAPL',
              'display_symbol': 'AAPL',
              'rank': 1,
              'name': 'Apple Inc.',
              'exchange': 'NASDAQ',
              'sector': 'Technology',
              'market_cap': 5180000000000,
            },
          ],
          'tickers' => [
            {'ticker': 'AAPL', 'name': 'Apple Inc.', 'market': 'US'},
            {'ticker': 'RELIANCE.NS', 'name': 'Reliance', 'market': 'IN'},
          ],
          'stock_quotes' => [
            {'ticker': 'AAPL', 'price': 250, 'previous_close': 245, 'change_pct': 2.0, 'volume': 100},
            {'ticker': 'RELIANCE.NS', 'price': 3000, 'previous_close': 2950, 'change_pct': 1.7, 'volume': 200},
          ],
          'stock_fundamentals' => [
            {'ticker': 'AAPL', 'sector': 'Technology'},
            {'ticker': 'RELIANCE.NS', 'sector': 'Energy'},
          ],
          'screener_categories' => [
            {'id': 1, 'name': 'top_gainers', 'category_type': 'GLOBAL'},
          ],
          'screener_results' => [
            {'category_id': 1, 'ticker': 'AAPL', 'rank': 1, 'price': 250, 'change_pct': 2.0},
            {'category_id': 1, 'ticker': 'RELIANCE.NS', 'rank': 2, 'price': 3000, 'change_pct': 1.7},
          ],
          _ => [],
        };
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repo = AssetMarketRepository(client: client);
    final snap = await repo.snapshot();
    expect(snap.instruments.map((e) => e.symbol).toList(), ['AAPL']);
    expect(snap.screeners['top_gainers']?.map((e) => e.symbol).toList(), ['AAPL']);
  });

  test('detail normalizes SQL tables and forwards stock_details options/news/snapshot', () async {
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        final rows = switch (table) {
          'tickers' => [{'ticker': 'AAPL', 'name': 'Apple Inc.', 'market': 'US'}],
          'stock_quotes' => [_quote],
          'stock_fundamentals' => [{'ticker': 'AAPL', 'sector': 'Technology'}],
          'analyst_recommendations' => [
            {'ticker': 'AAPL', 'period': '0m', 'strong_buy': 10, 'buy': 20, 'hold': 5, 'sell': 1, 'strong_sell': 0},
          ],
          'holders' => [
            {'ticker': 'AAPL', 'holder_type': 'institutional', 'holder_name': 'Vanguard', 'shares': 1000, 'pct_out': 0.09},
          ],
          'dividends' => [
            {'ticker': 'AAPL', 'ex_date': '2026-11-01', 'amount': 0.25},
          ],
          'stock_details' => [
            {
              'detail': {
                'ticker': 'AAPL',
                'options': {
                  'expirations': ['2026-12-18'],
                  'chains': {'2026-12-18': {'calls': [{'strike': 250, 'openInterest': 500}], 'puts': []}},
                },
                'news': [{'title': 'Apple headline', 'link': 'https://example.test/n'}],
                'snapshot': {'source': 'yahoo', 'sections_available': 5},
                'availability': {'options': {'available': true, 'count': 1}},
              },
            },
          ],
          _ => [],
        };
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final detail = await AssetMarketRepository(client: client).detail('AAPL');
    expect((detail['recommendations'] as List).first['strongBuy'], 10);
    expect((detail['holders']['institutional_holders'] as List).first['Holder'], 'Vanguard');
    expect((detail['dividends_and_splits']['dividends'] as List).first['date'], '2026-11-01');
    expect((detail['options']['chains'] as Map).containsKey('2026-12-18'), isTrue);
    expect((detail['news'] as List).first['title'], 'Apple headline');
    expect(detail['snapshot']['sections_available'], 5);
  });

  test('snapshot, instruments page, coverage page and news lazy-load bounded slices', () async {
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final table = request.url.pathSegments.last;
        if (request.method == 'HEAD') {
          return http.Response(
            '',
            200,
            headers: {
              'content-type': 'application/json',
              'content-range': '*/5000',
            },
            request: request,
          );
        }
        final rows = switch (table) {
          'market_universe' => [
            {
              'ticker': 'AAPL',
              'display_symbol': 'AAPL',
              'rank': 1,
              'name': 'Apple Inc.',
              'exchange': 'NASDAQ',
              'sector': 'Technology',
              'market_cap': 5180000000000,
            },
          ],
          'tickers' => [
            {'ticker': 'AAPL', 'name': 'Apple Inc.', 'market': 'US'},
          ],
          'stock_quotes' => [
            {'ticker': 'AAPL', 'price': 250, 'previous_close': 245, 'change_pct': 2.0, 'volume': 100},
          ],
          'stock_fundamentals' => [
            {'ticker': 'AAPL', 'sector': 'Technology'},
          ],
          'news_articles' => [
            {'id': 1, 'title': 'Market Update', 'link': 'https://example.test/1'},
          ],
          _ => [],
        };
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repo = AssetMarketRepository(client: client);
    final snap = await repo.snapshot();
    expect(snap.manifest['quote_count'], 5000);
    expect(snap.instruments.map((e) => e.symbol).toList(), ['AAPL']);

    final instPage = await repo.loadInstrumentsPage(page: 0, pageSize: 30);
    expect(instPage.totalCount, 5000);
    expect(instPage.items.single.symbol, 'AAPL');

    final covPage = await repo.loadCoveragePage(page: 0, pageSize: 30);
    expect(covPage.totalCount, 5000);
    expect(covPage.items.single['has_quote'], isTrue);

    final moreNews = await repo.loadMoreNews(offset: 25, limit: 20);
    expect(moreNews.single.title, 'Market Update');
  });
}
