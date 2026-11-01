import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/views/community_explore_view.dart';
import 'package:tradex/features/community/presentation/widgets/community_sidebar_widgets.dart';
import 'package:tradex/features/community/presentation/widgets/community_article_sheet.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';
import '../public_site/public_content_test.dart' show FileAssets;

void main() {
  testWidgets('Explore previews one story and opens only its category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = CommunityRepository();
    addTearDown(repo.dispose);
    await tester.runAsync(
      () => repo.loadMarketData(
        source: AssetMarketRepository(bundle: FileAssets()),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark().toThemeData(),
        home: Scaffold(body: CommunityExploreView(repository: repo)),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Crypto').first);
    await tester.pump();
    await tester.pump();
    expect(find.byType(MarketNewsCard), findsOneWidget);
    await tester.ensureVisible(find.text('View all'));
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityMarketWirePage), findsOneWidget);
    final panel = find.byKey(
      const ValueKey<String>('settings-side-sheet-surface'),
    );
    expect(panel, findsOneWidget);
    expect(
      find.descendant(
        of: panel,
        matching: find.text(repo.newsByCategory['crypto']!.first.headline),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: panel,
        matching: find.text(repo.newsByCategory['crypto']!.last.headline),
      ),
      findsNothing,
    );
    await tester.tap(
      find
          .descendant(
            of: panel,
            matching: find.text(repo.newsByCategory['crypto']!.first.headline),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CommunityArticleSheet), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('settings-side-sheet-surface')),
      findsNWidgets(2),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('desktop sidebar restores all earlier community sections', (
    tester,
  ) async {
    final repo = CommunityRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark().toThemeData(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 340,
              child: CommunitySidebar(
                repository: repo,
                onShowMore: () {},
                onExplore: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(CommunityLiveRoomWidget), findsNothing);
    expect(find.text('Subscribe to Premium'), findsOneWidget);
    for (
      var i = 0;
      i < 15 && find.byType(CommunityFooterLinks).evaluate().isEmpty;
      i++
    ) {
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -600),
      );
      await tester.pump();
      await tester.pump();
    }
    expect(find.byType(CommunityNewsWidget), findsOneWidget);
    expect(find.byType(CommunityTrendingWidget), findsOneWidget);
    expect(find.byType(CommunityWhoToFollowCard), findsOneWidget);
    expect(find.byType(CommunityPushNotificationsCard), findsOneWidget);
    expect(find.byType(CommunityDisclaimerCard), findsOneWidget);
    expect(find.byType(CommunityFooterLinks), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
