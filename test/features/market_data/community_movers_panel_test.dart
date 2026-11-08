import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart';
import 'package:tradex/features/market_data/presentation/market_movers_panel.dart';

class _Market extends AssetMarketRepository {
  final quote = MarketInstrument.fromJson(
    {'ticker': 'AAPL', 'name': 'Apple', 'price': 120, 'change_pct': 2},
    {},
    history: [110, 120],
  );
  @override
  Future<MarketSnapshot> snapshot({bool refresh = false}) async =>
      MarketSnapshot(instruments: [quote], articles: []);
  @override
  Future<Map<String, dynamic>> detail(String symbol) async => {
    'quote': {'price': 120},
    'summary': {},
    'chart': {'data': []},
  };
}

void main() {
  for (final width in [1440.0, 390.0]) {
    testWidgets('mover opens one dismissible side sheet at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketMoversPanel(repository: _Market()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = tester.widget<MarketQuoteRow>(find.byType(MarketQuoteRow));
      row.onTap();
      row.onTap();
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('settings-side-sheet-surface'));
      expect(panel, findsOneWidget);
      expect(find.byType(MarketInstrumentView), findsOneWidget);
      final bounds = tester.getRect(panel);
      if (width > 900) {
        expect(bounds.left, greaterThan(width / 2 - 40));
        expect(bounds.width, lessThanOrEqualTo(760));
      }
      expect(bounds.right, lessThanOrEqualTo(width));
      await tester.tap(find.byTooltip('Close panel'));
      await tester.pumpAndSettle();
      expect(find.byType(MarketInstrumentView), findsNothing);
      expect(find.text('Top gainers'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
