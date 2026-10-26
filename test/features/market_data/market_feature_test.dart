import 'package:flutter/material.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/navigation/role_navigation_config.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/presentation/market_root_screen.dart';
import 'package:tradex/features/market_data/presentation/market_movers_panel.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart';
import 'package:tradex/features/market_data/presentation/market_visuals.dart';
import '../public_site/public_content_test.dart' show FileAssets;

void main() {
  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settleAssets(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  test(
    'all roles can open the independent Market Intelligence destinations',
    () {
      for (final role in UserRole.values) {
        final nav = RoleNavigationConfig.forRole(role);
        for (final route in [
          'market',
          'market_overview',
          'market_coverage',
          'market_news',
          'market_movers',
          'market_instruments',
          'market_screeners',
        ]) {
          expect(nav.allows(route), isTrue);
        }
        expect(nav.sections.any((s) => s.title == 'Markets'), isTrue);
        expect(nav.mobileMoreItems.any((i) => i.id == 'market'), isTrue);
      }
    },
  );
  test('movers use quote changes and actual exported price history', () async {
    final repo = AssetMarketRepository(bundle: FileAssets());
    final snapshot = await repo.snapshot();
    expect(snapshot.gainers.every((q) => q.changePercent > 0), isTrue);
    expect(snapshot.losers.every((q) => q.changePercent < 0), isTrue);
    expect(
      snapshot.gainers.first.changePercent,
      greaterThanOrEqualTo(snapshot.gainers.last.changePercent),
    );
    for (final q in snapshot.instruments.where((q) => q.spark.isNotEmpty)) {
      final detail = await repo.detail(q.symbol);
      final prices = ((detail['chart'] as Map)['data'] as List)
          .map((c) => (c['close'] as num).toDouble())
          .toList();
      expect(q.spark, prices);
      if ((detail['summary'] as Map)['name'] != null) {
        expect(q.name, (detail['summary'] as Map)['name']);
      }
      expect(q.change, q.price - q.previousClose!);
    }
    expect(snapshot.articles.any((a) => a.thumbnailUrl != null), isTrue);
    expect(snapshot.topics, isNotEmpty);
    final files = (snapshot.manifest['files'] as List).cast<String>();
    expect(
      snapshot.manifest['history_count'],
      files.where((path) => path.startsWith('history/')).length,
    );
    expect(
      snapshot.manifest['history_count'],
      lessThan(snapshot.instruments.length),
    );
  });
  testWidgets(
    'news search filters stories and unfunctional like button is removed',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      viewport(tester, 1440);
      final repo = AssetMarketRepository(bundle: FileAssets());
      final data = (await tester.runAsync(() => repo.snapshot()))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketRootScreen(
              repository: repo,
              destination: 'market_news',
              searchQuery: 'no-result-market-query-987654',
            ),
          ),
        ),
      );
      await settleAssets(tester);
      expect(find.text('No articles available'), findsOneWidget);
      final video = data.videos.first;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketRootScreen(
              key: const ValueKey('video-market'),
              repository: repo,
              destination: 'market_news',
            ),
          ),
        ),
      );
      await settleAssets(tester);
      final videoCard = find
          .ancestor(
            of: find.text(video.title).first,
            matching: find.byType(MarketNewsCard),
          )
          .first;
      await tester.ensureVisible(videoCard);
      // Like button removed as it remains unfunctional
      expect(
        find.descendant(of: videoCard, matching: find.text('Like')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('full company dossier charts use exported fields', (
    tester,
  ) async {
    viewport(tester, 1440);
    final repo = AssetMarketRepository(bundle: FileAssets());
    final data = (await tester.runAsync(() async {
      final snapshot = await repo.snapshot();
      await repo.detail('AAPL');
      return snapshot;
    }))!;
    final apple = data.instruments.firstWhere((q) => q.symbol == 'AAPL');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketInstrumentView(
            instrument: apple,
            repository: repo,
            snapshot: data,
          ),
        ),
      ),
    );
    await settleAssets(tester);
    expect(find.byType(UiCandleChart), findsOneWidget);
    expect(find.byType(MarketFundamentalVisuals), findsOneWidget);
    expect(find.text('52-week position'), findsOneWidget);
    await tester.ensureVisible(find.text('Options chains').first);
    await tester.tap(find.text('Options chains').first);
    await tester.pump();
    expect(find.byType(MarketOptionsInterest), findsOneWidget);
    await tester.ensureVisible(find.text('Dividends & splits').first);
    await tester.tap(find.text('Dividends & splits').first);
    await tester.pump();
    expect(find.byType(MarketDividendHistory), findsOneWidget);
    await tester.ensureVisible(find.text('Ownership & holders').first);
    await tester.tap(find.text('Ownership & holders').first);
    await tester.pump();
    expect(find.byType(MarketInstitutionalHolders), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('market news, readers and screeners fit $width px', (
      tester,
    ) async {
      viewport(tester, width);

      final repo = AssetMarketRepository(bundle: FileAssets());
      final data = (await tester.runAsync(() async {
        final data = await repo.snapshot();
        await repo.detail(data.instruments.first.symbol);
        return data;
      }))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketRootScreen(
              repository: repo,
              destination: 'market_news',
            ),
          ),
        ),
      );
      await settleAssets(tester);
      expect(find.byType(MarketNewsCard), findsWidgets);
      expect(find.byType(UiRemoteImage), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text(data.articles.first.title).first);
      await tester.tap(find.text(data.articles.first.title).first);
      await tester.pump();
      expect(find.byType(MarketArticleView), findsOneWidget);
      expect(find.text('Read original article'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Back'));
      await tester.pump();
      await tester.ensureVisible(find.text('Movers'));
      await tester.ensureVisible(find.text('Movers'));
      await tester.tap(find.text('Movers'));
      await tester.pump();
      expect(find.text('Top gainers'), findsOneWidget);
      expect(find.text('Top losers'), findsOneWidget);
      expect(find.byType(MarketNewsCard), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Instruments'));
      await tester.tap(find.text('Instruments'));
      await tester.pump();
      if (width < 1100) {
        await tester.pump();
        expect(find.byType(MarketQuoteRow), findsWidgets);
        expect(find.byType(MarketQuoteRow).evaluate().length, lessThan(100));
      } else {
        expect(find.byType(UiTable<MarketInstrument>), findsOneWidget);
      }
      await tester.tap(find.text(data.instruments.first.symbol).first);
      await settleAssets(tester);
      final detail = (await tester.runAsync(
        () => repo.detail(data.instruments.first.symbol),
      ))!;
      if (((detail['chart'] as Map)['data'] as List).isEmpty) {
        expect(find.text('No price history in this snapshot'), findsOneWidget);
      } else {
        expect(find.byType(UiCandleChart), findsOneWidget);
      }
      expect(find.text('Options chains'), findsWidgets);
      expect(find.text('Ownership & holders'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Back'));
      await tester.pump();
      await tester.ensureVisible(find.text('Screeners'));
      await tester.tap(find.text('Screeners'));
      await tester.pump();
      expect(find.text('Screen library'), findsOneWidget);
      expect(find.text('Most active'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('desktop overview and full coverage load without layout errors', (
    tester,
  ) async {
    viewport(tester, 1440);
    final repo = AssetMarketRepository(bundle: FileAssets());
    final data = (await tester.runAsync(() async {
      await repo.read('tickers/universe');
      return repo.snapshot();
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MarketRootScreen(repository: repo)),
      ),
    );
    await settleAssets(tester);
    expect(find.text('World Indices'), findsOneWidget);
    expect(find.text('${data.manifest['detail_count']}'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Coverage').first);
    await settleAssets(tester);
    expect(find.text('DIRECTORY SYMBOLS'), findsOneWidget);
    expect(find.text('QUOTES AVAILABLE'), findsOneWidget);
    expect(find.byType(UiTable<Map>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('desktop screener pagination survives an instrument round trip', (
    tester,
  ) async {
    viewport(tester, 1440);
    final repo = AssetMarketRepository(bundle: FileAssets());
    final data = (await tester.runAsync(() async {
      final data = await repo.snapshot();
      await repo.detail(data.screeners['most_active']![30].symbol);
      return data;
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketRootScreen(
            repository: repo,
            destination: 'market_screeners',
          ),
        ),
      ),
    );
    await settleAssets(tester);
    await tester.ensureVisible(find.byIcon(Icons.chevron_right).last);
    await tester.tap(find.byIcon(Icons.chevron_right).last);
    await tester.pump();
    final symbol = data.screeners['most_active']![30].symbol;
    await tester.ensureVisible(find.text(symbol));
    await tester.tap(find.text(symbol));
    await settleAssets(tester);
    expect(find.text('Snapshot & availability'), findsWidgets);
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(find.text('Page 2 of 4'), findsOneWidget);
    expect(find.text(symbol), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'community rail contains only gainers and losers with sparklines',
    (tester) async {
      viewport(tester, 320);
      final repo = AssetMarketRepository(bundle: FileAssets());
      await tester.runAsync(() => repo.snapshot());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketMoversPanel(repository: repo),
            ),
          ),
        ),
      );
      await settleAssets(tester);
      expect(find.text('Top gainers'), findsOneWidget);
      expect(find.text('Top losers'), findsOneWidget);
      final data = (await tester.runAsync(() => repo.snapshot()))!;
      if ([
        ...data.gainers.take(5),
        ...data.losers.take(5),
      ].any((q) => q.spark.length > 1)) {
        expect(find.byType(UiSparkChart), findsWidgets);
      } else {
        expect(find.text('No history'), findsWidgets);
      }
      expect(find.text('Market Tickers'), findsNothing);
      expect(find.text('Subscribe to Premium'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('mobile shell can reach market tabs and return to community', (
    tester,
  ) async {
    viewport(tester, 390);
    await tester.pumpWidget(
      const MaterialApp(
        home: AppScaffold(
          initialDestination: 'community_feed',
          userRole: UserRole.customer,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.bySemanticsLabel('Switch to App'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Market Intelligence').last);
    await tester.pump(const Duration(seconds: 1));
    for (
      var attempt = 0;
      attempt < 30 && find.text('Movers').evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(find.byType(MarketRootScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Movers'));
    await tester.tap(find.text('Movers'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<AppShell>(find.byType(AppShell)).selectedId,
      'market_movers',
    );
    expect(find.text('Top gainers'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Community').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<AppShell>(find.byType(AppShell)).selectedId,
      'community',
    );
    expect(tester.takeException(), isNull);
  });
}
