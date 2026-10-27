import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';
import 'package:tradex/features/market_data/presentation/market_catalogue_view.dart';
import 'package:tradex/features/market_data/presentation/market_screeners_view.dart';

/// In-memory asset bundle that can simulate either a single consolidated JSON file
/// or split multiple JSON files for testing lazy loading and fallbacks.
class MemoryAssetBundle extends CachingAssetBundle {
  MemoryAssetBundle(this.files);
  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    if (!files.containsKey(key)) {
      throw FlutterError('Asset not found in MemoryAssetBundle: $key');
    }
    final bytes = utf8.encode(files[key]!);
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetMarketRepository Lazy Loading & Multi-File Architecture', () {
    test('loads successfully from a SINGLE consolidated JSON file for news and screeners', () async {
      final mockBundle = MemoryAssetBundle({
        'assets/data/manifest.json': jsonEncode({
          'generated_at': '2026-10-01T00:00:00Z',
          'files': ['quotes.json', 'fundamentals.json', 'all_news.json', 'screeners.json'],
        }),
        'assets/data/quotes.json': jsonEncode({
          'AAPL': {'ticker': 'AAPL', 'price': 150.0, 'change_pct': 2.5, 'market': 'US', 'name': 'Apple Inc.', 'volume': 1000000},
          'MSFT': {'ticker': 'MSFT', 'price': 300.0, 'change_pct': -1.2, 'market': 'US', 'name': 'Microsoft Corp.', 'volume': 800000},
        }),
        'assets/data/fundamentals.json': jsonEncode({
          'AAPL': {'name': 'Apple Inc.', 'sector': 'Technology'},
          'MSFT': {'name': 'Microsoft Corp.', 'sector': 'Technology'},
        }),
        'assets/data/all_news.json': jsonEncode([
          {
            'title': 'Apple Unveils Revolutionary Device',
            'summary': 'Apple announces breakthrough features in annual keynote presentation with massive preorder interest.',
            'publisher': 'TechCrunch',
            'link': 'https://example.com/apple',
            'related_tickers': ['AAPL'],
            'published_at': '2026-10-01T12:00:00Z',
          },
          {
            'title': 'Crypto Surges Past Resistance',
            'summary': 'Bitcoin and digital assets rally as global markets price in monetary easing cycles across major economies.',
            'publisher': 'CoinDesk',
            'link': 'https://example.com/crypto',
            'related_tickers': ['BTC-USD'],
            'published_at': '2026-10-01T13:00:00Z',
          },
        ]),
        'assets/data/screeners.json': jsonEncode({
          'top_gainers': {
            'quotes': [
              {'ticker': 'AAPL', 'price': 150.0, 'change_pct': 2.5, 'regularMarketPrice': 150.0, 'regularMarketChangePercent': 2.5},
            ],
          },
          'top_losers': {
            'quotes': [
              {'ticker': 'MSFT', 'price': 300.0, 'change_pct': -1.2, 'regularMarketPrice': 300.0, 'regularMarketChangePercent': -1.2},
            ],
          },
        }),
      });

      final repo = AssetMarketRepository(bundle: mockBundle);
      final snapshot = await repo.snapshot();

      expect(snapshot.instruments.length, 2);
      expect(snapshot.articles.length, 2);
      expect(snapshot.gainers.first.symbol, 'AAPL');
      expect(snapshot.losers.first.symbol, 'MSFT');
      expect(snapshot.topics, isNotEmpty);
    });

    test('loads and lazy-loads successfully from MULTIPLE split JSON files', () async {
      final mockBundle = MemoryAssetBundle({
        'assets/data/manifest.json': jsonEncode({
          'generated_at': '2026-10-01T00:00:00Z',
          'files': [
            'quotes.json',
            'by_topic/crypto.json',
            'by_topic/clean_energy.json',
            'screeners/aggressive_small_caps.json',
            'stock_detail/AAPL.json',
            'history/AAPL.json',
          ],
        }),
        'assets/data/quotes.json': jsonEncode({
          'AAPL': {'ticker': 'AAPL', 'price': 180.0, 'change_pct': 1.5, 'market': 'US', 'name': 'Apple Inc.', 'volume': 500000},
        }),
        'assets/data/by_topic/crypto.json': jsonEncode([
          {
            'title': 'Bitcoin Crosses All-Time High',
            'summary': 'Institutional ETF volumes drive cryptocurrency prices to unprecedented record highs.',
            'publisher': 'Bloomberg',
            'link': 'https://example.com/btc',
            'related_tickers': ['BTC-USD'],
            'published_at': '2026-10-01T10:00:00Z',
          },
        ]),
        'assets/data/by_topic/clean_energy.json': jsonEncode([
          {
            'title': 'Solar Installations Double Year-Over-Year',
            'summary': 'Next generation photovoltaic materials reduce levelized cost of energy across residential sectors.',
            'publisher': 'Reuters',
            'link': 'https://example.com/solar',
            'related_tickers': ['FSLR'],
            'published_at': '2026-10-01T11:00:00Z',
          },
        ]),
        'assets/data/screeners/aggressive_small_caps.json': jsonEncode({
          'id': 'screener_1',
          'title': 'Aggressive Small Caps',
          'quotes': [
            {'ticker': 'AAPL', 'price': 180.0, 'regularMarketPrice': 180.0, 'regularMarketChangePercent': 1.5},
          ],
        }),
        'assets/data/stock_detail/AAPL.json': jsonEncode({
          'ticker': 'AAPL',
          'summary': {'name': 'Apple Inc.', 'description': 'Designs consumer electronics and cloud services.'},
          'chart': {'data': [{'close': 175.0}, {'close': 180.0}]},
        }),
        'assets/data/history/AAPL.json': jsonEncode({
          'data': [{'close': 175.0}, {'close': 180.0}],
        }),
      });

      final repo = AssetMarketRepository(bundle: mockBundle);
      final snapshot = await repo.snapshot();

      expect(snapshot.instruments.length, 1);
      // Lazy-loads topic 'crypto'
      final cryptoArticles = await repo.loadTopic('crypto');
      expect(cryptoArticles.length, 1);
      expect(cryptoArticles.first.title, 'Bitcoin Crosses All-Time High');

      // Lazy-loads split screener 'aggressive_small_caps'
      final smallCaps = await repo.loadScreener(
        'aggressive_small_caps',
        quotes: {'AAPL': {'ticker': 'AAPL', 'price': 180.0}},
      );
      expect(smallCaps.length, 1);
      expect(smallCaps.first.symbol, 'AAPL');

      // Lazy-loads stock detail for AAPL
      final detail = await repo.detail('AAPL');
      expect(detail['ticker'], 'AAPL');
      expect(detail['summary']['description'], contains('Designs consumer electronics'));

      // Lazy-loads sparkline
      final spark = await repo.getSpark('AAPL');
      expect(spark, [175.0, 180.0]);
    });
  });

  group('Market Intelligence UI Pagination Tests', () {
    testWidgets('MarketNewsView paginates 10 articles per page with UiPagination and page summary', (
      WidgetTester tester,
    ) async {
      final List<MarketArticle> manyArticles = List.generate(
        25,
        (i) => MarketArticle.fromJson({
          'title': 'Market Headline Story #$i',
          'summary': 'Summary details describing economic and institutional financial news story #$i.',
          'publisher': 'Financial Times',
          'link': 'https://example.com/story-$i',
          'published_at': DateTime(2026, 10, 1, 12, i).toIso8601String(),
          'related_tickers': ['SPY'],
        }),
      );

      final snapshot = MarketSnapshot(
        instruments: const [],
        articles: manyArticles,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 900,
                child: MarketNewsView(
                  snapshot: snapshot,
                  onArticle: (_) {},
                  pageSize: 10,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Page 0: should show 10 stories (indices 0 to 9)
      expect(find.text('Market Headline Story #0'), findsOneWidget);
      expect(find.text('Market Headline Story #9'), findsOneWidget);
      expect(find.text('Market Headline Story #10'), findsNothing);

      // Verify pagination summary text
      expect(find.text('Showing 1–10 of 25 stories · Page 1 of 3'), findsOneWidget);

      // Verify UiPagination component is rendered
      expect(find.byType(UiPagination), findsOneWidget);

      // Tap on next page button (chevron_right) in UiPagination
      final nextButton = find.descendant(
        of: find.byType(UiPagination),
        matching: find.byIcon(Icons.chevron_right),
      );
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Page 1: should show 10 stories (indices 10 to 19)
      expect(find.text('Market Headline Story #0'), findsNothing);
      expect(find.text('Market Headline Story #10'), findsOneWidget);
      expect(find.text('Market Headline Story #19'), findsOneWidget);
      expect(find.text('Market Headline Story #20'), findsNothing);

      // Verify updated pagination summary text
      expect(find.text('Showing 11–20 of 25 stories · Page 2 of 3'), findsOneWidget);
    });

    testWidgets('MarketQuoteResults on mobile paginates 20 quotes per page with UiPagination', (
      WidgetTester tester,
    ) async {
      final List<MarketInstrument> quotes = List.generate(
        45,
        (i) => MarketInstrument.fromJson(
          {
            'ticker': 'SYM$i',
            'price': 100.0 + i,
            'change_pct': (i % 2 == 0 ? 1.0 : -1.0) * i,
            'market': 'US',
            'currency': 'USD',
          },
          {'name': 'Company Number $i'},
        ),
      );

      // Mobile width constraint (< 600px)
      tester.view.physicalSize = const Size(380, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 380,
                child: MarketQuoteResults(
                  quotes: quotes,
                  onInstrument: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Page 0: should show 20 items (SYM0 to SYM19)
      expect(find.text('SYM0'), findsOneWidget);
      expect(find.text('SYM19'), findsOneWidget);
      expect(find.text('SYM20'), findsNothing);

      // UiPagination is rendered
      expect(find.byType(UiPagination), findsOneWidget);

      // Tap on next page button (chevron_right) in UiPagination
      final nextButton = find.descendant(
        of: find.byType(UiPagination),
        matching: find.byIcon(Icons.chevron_right),
      );
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Page 1: should show SYM20 to SYM39
      expect(find.text('SYM0'), findsNothing);
      expect(find.text('SYM20'), findsOneWidget);
      expect(find.text('SYM39'), findsOneWidget);
      expect(find.text('SYM40'), findsNothing);
    });

    testWidgets('MarketScreenersView lazy loads and displays screener table with pagination', (
      WidgetTester tester,
    ) async {
      final mockBundle = MemoryAssetBundle({
        'assets/data/manifest.json': jsonEncode({
          'generated_at': '2026-10-01T00:00:00Z',
          'files': ['quotes.json', 'screeners/oversold_stocks_by_rsi.json'],
        }),
        'assets/data/quotes.json': jsonEncode({
          'TSLA': {'ticker': 'TSLA', 'price': 220.0, 'change_pct': -3.2, 'market': 'US', 'name': 'Tesla Inc.'},
        }),
        'assets/data/screeners/oversold_stocks_by_rsi.json': jsonEncode({
          'id': 'oversold_screen',
          'quotes': [
            {'ticker': 'TSLA', 'price': 220.0, 'regularMarketPrice': 220.0, 'regularMarketChangePercent': -3.2, 'rsi_14': 24.5},
          ],
        }),
      });

      final repo = AssetMarketRepository(bundle: mockBundle);
      final snapshot = await repo.snapshot();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 900,
                child: MarketScreenersView(
                  snapshot: snapshot,
                  onInstrument: (_) {},
                  repository: repo,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Screen library'), findsOneWidget);
      expect(find.byType(UiTable<MarketInstrument>), findsOneWidget);
    });
  });
}
