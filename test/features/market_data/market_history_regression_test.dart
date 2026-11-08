import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_movers_panel.dart';

void main() {
  test(
    'history queries newest bars and renders them in chronological order',
    () async {
      final requests = <Uri>[];
      final client = SupabaseClient(
        'https://example.test',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode([
              {'date': '2026-11-06', 'close': 12},
              {'date': '2026-11-05', 'close': 11},
              {'date': '2026-11-04', 'close': 10},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      final repository = AssetMarketRepository(client: client);
      expect(await repository.getSpark('AAPL'), [10.0, 11.0, 12.0]);
      expect(requests.single.queryParameters['ticker'], 'eq.AAPL');
      expect(requests.single.queryParameters['order'], startsWith('date.desc'));
      expect(requests.single.queryParameters['limit'], '36');
      final history = await repository.history('AAPL');
      expect((history['data'] as List).first['date'], '2026-11-04');
      expect(requests.last.queryParameters['limit'], '730');
      await client.dispose();
    },
  );

  testWidgets('a visible quote without prefetched history loads its real spark', (
    tester,
  ) async {
    final repository = _HistoryRepository();
    final previous = AssetMarketRepository.shared;
    AssetMarketRepository.shared = repository;
    addTearDown(() => AssetMarketRepository.shared = previous);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketQuoteRow(
            quote: MarketInstrument.fromJson({
              'ticker': 'UNP',
              'price': 12,
            }, {}),
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No history'), findsNothing);
    expect(find.byType(UiSparkChart), findsOneWidget);
    expect(tester.widget<UiSparkChart>(find.byType(UiSparkChart)).values, [
      11.0,
      12.0,
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(repository.requestedSymbol, 'UNP');
  });
}

class _HistoryRepository extends AssetMarketRepository {
  String? requestedSymbol;
  @override
  Future<List<double>> getSpark(String symbol) async {
    requestedSymbol = symbol;
    return [11.0, 12.0];
  }
}
