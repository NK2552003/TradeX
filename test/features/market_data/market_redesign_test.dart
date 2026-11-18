import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/presentation/market_root_screen.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart';
import 'package:tradex/features/market_data/presentation/market_layout.dart';
import '../public_site/public_content_test.dart' show FileAssets;

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
    for (final page in [
      'overview',
      'news',
      'movers',
      'instruments',
      'screeners',
      'coverage',
    ]) {
      testWidgets('$page has two responsive panels at $width', (tester) async {
        viewport(tester, width);
        final repo = AssetMarketRepository(bundle: FileAssets());
        await tester.runAsync(() async {
          await repo.snapshot();
          await repo.read('tickers/universe');
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MarketRootScreen(
                repository: repo,
                destination: 'market_$page',
              ),
            ),
          ),
        );
        for (
          var attempt = 0;
          attempt < 10 && find.byType(MarketTwoPanel).evaluate().isEmpty;
          attempt++
        ) {
          await settle(tester);
        }
        expect(find.byType(MarketTwoPanel), findsOneWidget);
        final panelWidth = tester.getSize(find.byType(MarketTwoPanel)).width;
        expect(
          find.byKey(
            ValueKey(
              panelWidth < 680
                  ? 'market-stacked-panels'
                  : 'market-side-by-side-panels',
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final scroll = find
            .byWidgetPredicate(
              (widget) =>
                  widget is SingleChildScrollView &&
                  widget.scrollDirection == Axis.vertical,
            )
            .first;
        await tester.drag(scroll, const Offset(0, -650));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('instrument charts and every research section work at $width', (
      tester,
    ) async {
      viewport(tester, width);
      final repo = AssetMarketRepository(bundle: FileAssets());
      final data = (await tester.runAsync(() async {
        final snapshot = await repo.snapshot();
        await repo.detail('AAPL');
        return snapshot;
      }))!;
      final instrument = data.instruments.firstWhere((q) => q.symbol == 'AAPL');
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(width == 320 ? 1.4 : 1)),
            child: child!,
          ),
          home: Scaffold(
            body: MarketInstrumentView(
              instrument: instrument,
              repository: repo,
              snapshot: data,
            ),
          ),
        ),
      );
      await settle(tester);
      final sections = find.byKey(const ValueKey('instrument-section-toggle'));
      expect(sections, findsOneWidget);
      expect(find.byType(MarketTwoPanel), findsOneWidget);
      expect(find.byType(UiCandleChart), findsOneWidget);
      final rangeControls = tester.getRect(
        find.byKey(const ValueKey('market-history-range-toggle')),
      );
      final chartControls = tester.getRect(
        find.byType(UiToggleGroup<UiPriceChartType>),
      );
      if (width == 1440) {
        final chart = tester.getRect(find.byType(UiCandleChart));
        expect(rangeControls.left, closeTo(chart.left, 0.5));
        expect(chartControls.right, closeTo(chart.right, 0.5));
        expect(chartControls.center.dy, closeTo(rangeControls.center.dy, 0.5));
      } else if (width <= 390) {
        expect(chartControls.top, greaterThanOrEqualTo(rangeControls.bottom));
      }
      for (final label in ['1D', '1W', '2W', '1M', '2M']) {
        final rangeBtn = find.text(label);
        expect(rangeBtn, findsOneWidget);
        await tester.ensureVisible(rangeBtn);
        await tester.tap(rangeBtn);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'Candles $label');
      }
      await tester.ensureVisible(find.text('Line'));
      await tester.tap(find.text('Line'));
      await tester.pump();
      expect(find.byType(UiAreaChart), findsOneWidget);
      for (final label in ['1D', '1W', '2W', '1M', '2M']) {
        final rangeBtn = find.text(label);
        await tester.ensureVisible(rangeBtn);
        await tester.tap(rangeBtn);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'Line $label');
      }
      expect(tester.takeException(), isNull);
      for (final entry in {
        'History': 'Session return heatmap',
        'Options': 'Options chains',
        'Dividends & splits': 'Corporate actions',
        'Analysts': 'Analyst consensus',
        'Ownership': 'Ownership map',
        'News': 'No company news in this snapshot',
        'Data sources': 'Snapshot & availability',
      }.entries) {
        final label = find.descendant(
          of: sections,
          matching: find.text(entry.key),
        );
        await tester.ensureVisible(label);
        await tester.pumpAndSettle();
        await tester.tap(label);
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget, reason: entry.key);
        expect(tester.takeException(), isNull, reason: entry.key);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('compact panel scope works inside a wide desktop viewport', (
    tester,
  ) async {
    viewport(tester, 1440);
    final repo = AssetMarketRepository(bundle: FileAssets());
    await tester.runAsync(() => repo.snapshot());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: MarketRootScreen(
                repository: repo,
                destination: 'market_instruments',
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('market-stacked-panels')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'filterMarketHistoryCandles slices 2M history into 1D, 1W, 2W, 1M, 2M',
    () {
      final anchor = DateTime(2026, 11, 15);
      final all = [
        for (int daysAgo = 59; daysAgo >= 0; daysAgo--)
          UiCandle(
            time: anchor.subtract(Duration(days: daysAgo)),
            open: 100,
            high: 105,
            low: 95,
            close: 102,
            volume: 1000,
          ),
      ];
      expect(filterMarketHistoryCandles(all, MarketHistoryRange.day).length, 1);
      expect(
        filterMarketHistoryCandles(all, MarketHistoryRange.week).length,
        7,
      );
      expect(
        filterMarketHistoryCandles(all, MarketHistoryRange.twoWeeks).length,
        14,
      );
      expect(
        filterMarketHistoryCandles(all, MarketHistoryRange.month).length,
        30,
      );
      expect(
        filterMarketHistoryCandles(all, MarketHistoryRange.twoMonths).length,
        60,
      );
    },
  );
}
