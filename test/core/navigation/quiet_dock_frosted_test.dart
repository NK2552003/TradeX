import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_dock/quiet_dock.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

void main() {
  testWidgets(
    'AppShell mobile extends body edge-to-edge behind frosted QuietDock and blurs quick-grid tiles',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      double? reportedChildBottom;
      double? reportedMediaPaddingBottom;

      const List<AppNavItem> primaryItems = <AppNavItem>[
        AppNavItem(
          id: 'workspace',
          label: 'Writing Desk',
          icon: Icons.notes_rounded,
        ),
        AppNavItem(
          id: 'community_feed',
          label: 'Community',
          icon: Icons.forum_outlined,
        ),
        AppNavItem(
          id: 'messages',
          label: 'Messages',
          icon: Icons.chat_bubble_outline_rounded,
        ),
        AppNavItem(
          id: 'ai_copilot',
          label: 'AI Assistant',
          icon: Icons.auto_awesome_outlined,
        ),
      ];

      const List<AppNavItem> moreItems = <AppNavItem>[
        AppNavItem(
          id: 'market',
          label: 'Market Intelligence',
          icon: Icons.public_rounded,
        ),
        AppNavItem(
          id: 'calculators',
          label: 'Calculators',
          icon: Icons.calculate_outlined,
        ),
        AppNavItem(
          id: 'settings',
          label: 'Settings',
          icon: Icons.settings_outlined,
        ),
      ];

      final Key bodyKey = GlobalKey();

      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (_) => MaterialApp(
            theme: UiTheme.dark().toThemeData(),
            home: AppShell(
              sections: const <AppNavSection>[
                AppNavSection(title: 'WORKSPACE', items: primaryItems),
              ],
              mobilePrimaryItems: primaryItems,
              mobileMoreItems: moreItems,
              selectedId: 'workspace',
              onSelect: (_) {},
              child: Builder(
                builder: (BuildContext context) {
                  reportedMediaPaddingBottom = MediaQuery.paddingOf(context).bottom;
                  return Container(
                    key: bodyKey,
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.teal,
                    alignment: Alignment.bottomCenter,
                    child: const Text('Scrollable edge-to-edge body'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final RenderBox bodyBox =
          tester.renderObject<RenderBox>(find.byKey(bodyKey));
      final Offset bodyBottomLeft =
          bodyBox.localToGlobal(Offset(0, bodyBox.size.height));
      reportedChildBottom = bodyBottomLeft.dy;

      // Body extends all the way behind QuietDock (844px) instead of stopping
      // ~90px short in a blank dark container, while passing dock clearance via MediaQuery.
      expect(reportedChildBottom, closeTo(844.0, 0.5));
      expect(reportedMediaPaddingBottom, greaterThan(70.0));

      // QuietDock uses frosted translucent BackdropFilter blur.
      final QuietDock dock = tester.widget<QuietDock>(find.byType(QuietDock));
      final QuietDockTheme resolvedTheme =
          dock.theme.resolve(tester.element(find.byType(QuietDock)));
      expect(resolvedTheme.frosted, isTrue);
      expect(resolvedTheme.blur, greaterThan(0));
      expect(resolvedTheme.background!.a, lessThan(1.0));
      expect(find.byType(BackdropFilter), findsAtLeastNWidgets(1));

      final int initialFilters = find.byType(BackdropFilter).evaluate().length;

      // Opening the center quick-grid applies frosted BackdropFilter blur to every popup item tile.
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Market Intelligence'), findsOneWidget);
      expect(find.text('Calculators'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      final int openFilters = find.byType(BackdropFilter).evaluate().length;
      expect(openFilters, greaterThanOrEqualTo(initialFilters + moreItems.length));
    },
  );
}
