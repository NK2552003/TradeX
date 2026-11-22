import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/linking/link_graph.dart';
import 'package:alphajournal/features/community/presentation/widgets/public_record_detail_modal.dart';
import 'package:alphajournal/features/market_data/data/asset_market_repository.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';
import 'package:alphajournal/features/market_data/presentation/market_instrument_price.dart';
import 'package:alphajournal/features/market_data/presentation/market_root_screen.dart';
import 'package:alphajournal/features/messages/data/messages_repository.dart';
import 'package:alphajournal/features/messages/presentation/views/messages_inbox_view.dart';
import 'public_site/public_content_test.dart' show FileAssets;

void main() {
  void setMobileViewport(WidgetTester tester, {double topPadding = 84.0}) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: topPadding, bottom: 20);
    tester.view.viewPadding = tester.view.padding;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
  }

  Future<void> settleAssets(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'Market Intelligence Overview respects mobile top header clearance and makes tabs and category toggles scrollable',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      setMobileViewport(tester, topPadding: 84.0);
      final repo = AssetMarketRepository(bundle: FileAssets());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketRootScreen(repository: repo),
          ),
        ),
      );
      await settleAssets(tester);

      // Ribbon starts below the floating header inset (84px + spacing).
      final Rect ribbonRect = tester.getRect(
        find.byKey(const ValueKey<String>('market-ribbon')),
      );
      expect(ribbonRect.top, greaterThanOrEqualTo(84.0));

      // Market overview tabs are horizontally scrollable on mobile.
      final UiTabs tabs = tester.widget<UiTabs>(find.byType(UiTabs));
      expect(tabs.scrollable, isTrue);
      expect(tabs.stretch, isFalse);

      // Yahoo market ribbon category toggle scrolls on mobile instead of squishing.
      final UiToggleGroup<String> categoryToggle = tester
          .widget<UiToggleGroup<String>>(
            find.byKey(const ValueKey<String>('market-ribbon-category-toggle')),
          );
      expect(categoryToggle.expand, isFalse);
      expect(categoryToggle.scrollWhenTight, isTrue);
    },
  );

  testWidgets(
    'Ticker opened from a note returns to origin on back and uses full-width chart toggles on mobile',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      setMobileViewport(tester, topPadding: 84.0);
      final repo = AssetMarketRepository(bundle: FileAssets());
      final snapshot = await repo.snapshot();
      final MarketInstrument quote = snapshot.instruments.firstWhere(
        (i) => i.spark.isNotEmpty,
        orElse: () => snapshot.instruments.first,
      );

      VoidCallback? announcedBack;
      bool returnedToOrigin = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketRootScreen(
              repository: repo,
              openRequest: AppLinkOpenRequest(
                kind: AppLinkKind.ticker,
                id: quote.symbol,
                seq: 1,
              ),
              onSubpageChanged: (title, icon, onBack) {
                announcedBack = onBack;
              },
              onReturnToOrigin: () {
                returnedToOrigin = true;
              },
            ),
          ),
        ),
      );
      await settleAssets(tester);

      // Ticker detail starts below the floating header inset.
      final Rect navRect = tester.getRect(
        find.byKey(const ValueKey('instrument-section-toggle')),
      );
      expect(navRect.top, greaterThanOrEqualTo(84.0));

      // Chart range and chart type toggles are full-width on mobile.
      final Finder rangeToggleFinder = find.byKey(
        const ValueKey('market-history-range-toggle'),
      );
      final Finder typeToggleFinder = find.byKey(
        const ValueKey('market-history-chart-type-toggle'),
      );
      if (rangeToggleFinder.evaluate().isNotEmpty) {
        final UiToggleGroup<MarketHistoryRange> rangeToggle = tester
            .widget<UiToggleGroup<MarketHistoryRange>>(rangeToggleFinder);
        final UiToggleGroup<UiPriceChartType> typeToggle = tester
            .widget<UiToggleGroup<UiPriceChartType>>(typeToggleFinder);
        expect(rangeToggle.expand, isTrue);
        expect(typeToggle.expand, isTrue);
      }

      // Pressing Back invokes onReturnToOrigin instead of trapping the user in Market Overview.
      expect(announcedBack, isNotNull);
      announcedBack!();
      await tester.pump();
      expect(returnedToOrigin, isTrue);
    },
  );

  testWidgets(
    'PublicRecordDetailModal closes automatically and preserves overlay public context when clicking linked strategy or ticker',
    (WidgetTester tester) async {
      setMobileViewport(tester, topPadding: 24.0);
      final AppStrategy strategy = AppStrategy(
        id: 'strat_pub_1',
        name: 'Opening Range Breakout',
        category: 'US Equities',
        status: AppStrategyStatus.live,
        winRate: 0.62,
        avgR: 2.1,
        trades: 18,
        netPnl: 4200,
        isPublic: true,
        userId: 'author_1',
      );
      final AppNote note = AppNote(
        id: 'note_pub_1',
        title: 'Shared INTC Thesis',
        content: 'Watching INTC breakout setup.',
        noteType: AppNoteType.general,
        createdAt: DateTime.utc(2026, 11, 20),
        updatedAt: DateTime.utc(2026, 11, 20),
        isPublic: true,
        userId: 'author_1',
        strategyId: strategy.id,
        strategyName: strategy.name,
        linkedTickers: const <String>['INTC'],
      );
      final AppLinkGraph graph = AppLinkGraph(
        notes: <AppNote>[note],
        strategies: <AppStrategy>[strategy],
      );

      final List<AppLinkRef> openedRefs = <AppLinkRef>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: UiButton(
                  label: 'Open shared note',
                  onPressed: () {
                    PublicRecordDetailModal.show(
                      context,
                      ref: AppLinkRef(
                        kind: AppLinkKind.note,
                        id: note.id,
                        title: note.title,
                        isPublicContext: true,
                      ),
                      initialNote: note,
                      initialLinkGraph: graph,
                      onOpenRef: openedRefs.add,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Open the shared note overlay.
      await tester.tap(find.text('Open shared note'));
      await tester.pumpAndSettle();
      expect(find.byType(PublicRecordDetailModal), findsOneWidget);

      // Tap the linked strategy badge inside the shared note overlay.
      final Finder strategyBadge = find.text(strategy.name).first;
      await tester.ensureVisible(strategyBadge);
      await tester.tap(strategyBadge);
      await tester.pumpAndSettle();

      // Overlay closed automatically and propagated isPublicContext: true so the
      // linked strategy opens in an overlay too.
      expect(find.byType(PublicRecordDetailModal), findsNothing);
      expect(openedRefs, hasLength(1));
      expect(openedRefs.single.kind, AppLinkKind.strategy);
      expect(openedRefs.single.id, strategy.id);
      expect(openedRefs.single.isPublicContext, isTrue);

      // Re-open the shared note overlay and tap the linked ticker ($INTC).
      openedRefs.clear();
      await tester.tap(find.text('Open shared note'));
      await tester.pumpAndSettle();
      expect(find.byType(PublicRecordDetailModal), findsOneWidget);

      final Finder tickerBadge = find.text('\$INTC').first;
      await tester.ensureVisible(tickerBadge);
      await tester.tap(tickerBadge);
      await tester.pumpAndSettle();

      expect(find.byType(PublicRecordDetailModal), findsNothing);
      expect(openedRefs, hasLength(1));
      expect(openedRefs.single.kind, AppLinkKind.ticker);
      expect(openedRefs.single.id, 'INTC');
    },
  );

  testWidgets(
    'MessagesInboxView respects mobile top header clearance and AppShell hideMobileDock hides the floating dock',
    (WidgetTester tester) async {
      setMobileViewport(tester, topPadding: 84.0);
      final repo = MessagesRepository(autoConnect: false);
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesInboxView(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First interactive control (search bar) starts below the 84px top inset.
      final Finder searchField = find.byType(UiInput).first;
      expect(tester.getTopLeft(searchField).dy, greaterThanOrEqualTo(84.0));

      // AppShell with hideMobileDock: true hides the bottom dock completely
      // (used for mobile Messages thread views so the composer is unobstructed).
      const items = <AppNavItem>[
        AppNavItem(id: 'workspace', label: 'Desk', icon: Icons.notes),
        AppNavItem(id: 'messages', label: 'Messages', icon: Icons.chat),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            sections: const <AppNavSection>[
              AppNavSection(title: 'Main', items: items),
            ],
            selectedId: 'messages',
            onSelect: (_) {},
            onSearch: () {},
            hideMobileTopBar: true,
            hideMobileDock: true,
            child: const Center(child: Text('Thread composer')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('app-dock-slide')), findsNothing);
      expect(find.text('Thread composer'), findsOneWidget);
    },
  );
}
