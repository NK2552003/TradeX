// Opt-in, read-only smoke test against the Supabase project in .env.
// TRADEX_LIVE_MARKET_TEST=1 flutter test test/features/market_data/market_detail_live_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart';

void main() {
  final isEnabled = Platform.environment['TRADEX_LIVE_MARKET_TEST'] == '1';
  for (final symbol in ['AAPL', 'RELIANCE.NS', 'BTC-USD']) {
    testWidgets('live Supabase detail renders for $symbol', (tester) async {
      tester.view.physicalSize = const Size(1440, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final allowFonts = GoogleFonts.config.allowRuntimeFetching;
      GoogleFonts.config.allowRuntimeFetching = false;
      addTearDown(() => GoogleFonts.config.allowRuntimeFetching = allowFonts);
      late SupabaseClient client;
      late AssetMarketRepository repository;
      late Map<String, dynamic> detail;
      await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(() async {
          final config = DotEnv()
            ..testLoad(fileInput: File('.env').readAsStringSync());
          final url =
              config.env['SUPABASE_URL'] ??
              config.env['NEXT_PUBLIC_SUPABASE_URL']!;
          final key =
              config.env['SUPABASE_ANON_KEY'] ??
              config.env['NEXT_PUBLIC_SUPABASE_ANON_KEY']!;
          client = SupabaseClient(
            url,
            key,
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          );
          repository = AssetMarketRepository(client: client);
          detail = await repository.detail(symbol);
        }, _LiveHttpOverrides()),
      );
      addTearDown(() => tester.runAsync(client.dispose));
      expect(detail['quote']['price'], greaterThan(0));
      expect(detail['chart']['data'], isNotEmpty);
      final instrument = MarketInstrument.fromJson(
        Map<String, dynamic>.from(detail['quote'] as Map),
        Map<String, dynamic>.from(detail['summary'] as Map),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketInstrumentView(
                instrument: instrument,
                repository: repository,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Instrument details unavailable'), findsNothing);
      expect(find.text(instrument.name), findsWidgets);
      expect(find.byType(UiCandleChart), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Public market data only; no credentials or account information.
      debugPrint(
        '$symbol: price=${detail['quote']['price']}, history=${(detail['chart']['data'] as List).length}, sector=${detail['summary']['sector'] ?? 'unavailable'}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }, skip: !isEnabled);
  }
}

class _LiveHttpOverrides extends HttpOverrides {}
