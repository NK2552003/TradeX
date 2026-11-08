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
}
