import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/navigation/role_navigation_config.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/journal/ui/journal_screen.dart';
import 'package:tradex/features/markets/data/market_repository.dart';
import 'package:tradex/features/markets/ui/markets_screen.dart';
import 'package:tradex/features/markets/ui/news_screen.dart';
import 'package:tradex/features/notes/ui/notes_screen.dart';
import 'package:tradex/features/strategies/ui/strategies_screen.dart';

Widget host(Widget child, double width) => UiApp(
  theme: UiTheme.dark(),
  builder: (context) => MaterialApp(
    theme: UiTheme.dark().toThemeData(),
    builder: (context, child) => UiToastScope(child: child!),
    home: Scaffold(
      body: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: width,
          child: AppShell(
            sections: RoleNavigationConfig.forRole(UserRole.customer).sections,
            selectedId: 'journal',
            onSelect: (_) {},
            researchPanelBuilder: (context, close, overlay) => ResearchRail(
              onClose: close,
              onOpenSymbol: (_) {},
              onOpenRef: (_) {},
            ),
            child: child,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [390.0, 768.0, 1440.0]) {
    for (final page in [
      'journal',
      'strategies',
      'notes',
      'markets',
      'watchlist',
    ]) {
      testWidgets('$page is usable at $width with the research rail', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() => MarketWorkspaceStore.instance.initialize());
        final child = switch (page) {
          'journal' => const JournalScreen(),
          'strategies' => const StrategiesScreen(),
          'notes' => const NotesScreen(),
          'watchlist' => const MarketsScreen(watchlist: true),
          _ => const MarketsScreen(),
        };
        await tester.pumpWidget(host(child, width));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (width == 1440) {
          expect(find.byType(ResearchRail), findsOneWidget);
          await tester.tap(find.widgetWithText(UiButton, 'Focus mode'));
          await tester.pumpAndSettle();
          expect(find.byType(ResearchRail), findsNothing);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets(
    'news creates a private research note with source and ticker links',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => MarketWorkspaceStore.instance.initialize());
      await tester.pumpWidget(host(const NewsScreen(), 1000));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppNewsStoryCard).first);
      await tester.pumpAndSettle();
      final create = find.widgetWithText(UiButton, 'Create research note');
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.text('Research note created'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
