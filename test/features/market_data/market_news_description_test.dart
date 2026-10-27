import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_sidebar_widgets.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('News card 2-line description tests', () {
    testWidgets('MarketNewsCard displays 2 lines of description below title', (
      WidgetTester tester,
    ) async {
      final article = MarketArticle.fromJson({
        'title': 'Fed Signals Interest Rate Cut as Inflation Cools',
        'summary':
            'Federal Reserve officials indicated that easing inflationary pressures provide runway for an initial 25-basis-point policy reduction in the coming quarter.',
        'publisher': 'Reuters',
        'link': 'https://example.com/fed-cut',
        'published_at': DateTime.now().toIso8601String(),
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'related_tickers': ['SPY', 'QQQ'],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketNewsCard(
              article: article,
              snapshot: const MarketSnapshot(instruments: [], articles: []),
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Fed Signals Interest Rate Cut as Inflation Cools'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Federal Reserve officials indicated that easing inflationary pressures provide runway for an initial 25-basis-point policy reduction in the coming quarter.',
        ),
        findsOneWidget,
      );

      final summaryFinder = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data != null &&
            w.data!.startsWith('Federal Reserve officials') &&
            w.maxLines == 2 &&
            w.overflow == TextOverflow.ellipsis,
      );
      expect(summaryFinder, findsOneWidget);
    });

    testWidgets('CommunityNewsWidget displays 2 lines of description in sidebar row', (
      WidgetTester tester,
    ) async {
      final item = CommunityNewsItem(
        id: 'news_item_1',
        headline: 'NIFTY Breaks All-Time High on Strong Institutional Inflows',
        summary:
            'Domestic and foreign institutional investors poured aggressive liquidity into banking and energy sectors pushing the index to record highs.',
        source: 'hejournal.in Market Desk',
        publishedAt: DateTime.now(),
        category: 'Macro',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityNewsWidget(
              items: [item],
              onShowMore: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('NIFTY Breaks All-Time High on Strong Institutional Inflows'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Domestic and foreign institutional investors poured aggressive liquidity into banking and energy sectors pushing the index to record highs.',
        ),
        findsOneWidget,
      );

      final summaryFinder = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data != null &&
            w.data!.startsWith('Domestic and foreign institutional investors') &&
            w.maxLines == 2 &&
            w.overflow == TextOverflow.ellipsis,
      );
      expect(summaryFinder, findsOneWidget);
    });

    testWidgets('MarketNewsCard does not render like button', (
      WidgetTester tester,
    ) async {
      final article = MarketArticle.fromJson({
        'title': 'Test Article Headline',
        'summary': 'Test Article Summary Description',
        'publisher': 'Bloomberg',
        'link': 'https://example.com/test',
        'published_at': DateTime.now().toIso8601String(),
        'related_tickers': ['AAPL'],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketNewsCard(
              article: article,
              snapshot: const MarketSnapshot(instruments: [], articles: []),
              onTap: () {},
              onLike: () {},
              isLiked: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Like button should NOT be rendered
      expect(find.text('Like'), findsNothing);
      expect(find.text('Liked'), findsNothing);
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });
  });
}
