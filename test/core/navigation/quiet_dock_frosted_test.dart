import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_dock/quiet_dock.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

void main() {
  testWidgets('Dock keeps the current page until navigation commits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const items = [
      AppNavItem(id: 'workspace', label: 'Workspace', icon: Icons.notes),
      AppNavItem(id: 'community', label: 'Community', icon: Icons.forum),
      AppNavItem(id: 'messages', label: 'Messages', icon: Icons.chat),
    ];
    var selected = 'workspace';
    final requested = <String>[];
    final selectedLocally = <String>[];
    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (_) => MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => AppShell(
              sections: const [AppNavSection(title: 'Workspace', items: items)],
              mobilePrimaryItems: items,
              selectedId: selected,
              onExternalSelect: (id) {
                if (id != 'community') return false;
                requested.add(id);
                return true;
              },
              onSelect: (id) {
                selectedLocally.add(id);
                setState(() => selected = id);
              },
              child: Text('Current page: $selected'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.forum).last);
    await tester.pumpAndSettle();
    expect(requested, ['community']);
    expect(selectedLocally, isEmpty);
    expect(tester.widget<QuietDock>(find.byType(QuietDock)).selectedIndex, 0);
    expect(find.text('Current page: workspace').hitTestable(), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chat).last);
    await tester.pumpAndSettle();
    expect(requested, ['community']);
    expect(selectedLocally, ['messages']);
    expect(tester.widget<QuietDock>(find.byType(QuietDock)).selectedIndex, 2);
    expect(find.text('Current page: messages').hitTestable(), findsOneWidget);
  });

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
                  reportedMediaPaddingBottom = MediaQuery.paddingOf(
                    context,
                  ).bottom;
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

      final RenderBox bodyBox = tester.renderObject<RenderBox>(
        find.byKey(bodyKey),
      );
      final Offset bodyBottomLeft = bodyBox.localToGlobal(
        Offset(0, bodyBox.size.height),
      );
      reportedChildBottom = bodyBottomLeft.dy;

      // Body extends all the way behind QuietDock (844px) instead of stopping
      // ~90px short in a blank dark container, while passing dock clearance via MediaQuery.
      expect(reportedChildBottom, closeTo(844.0, 0.5));
      // QuietDock uses frosted translucent BackdropFilter blur.
      final QuietDock dock = tester.widget<QuietDock>(find.byType(QuietDock));
      final QuietDockTheme resolvedTheme = dock.theme.resolve(
        tester.element(find.byType(QuietDock)),
      );
      expect(
        reportedMediaPaddingBottom,
        resolvedTheme.height + resolvedTheme.margin,
      );
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
      expect(
        openFilters,
        greaterThanOrEqualTo(initialFilters + moreItems.length),
      );
    },
  );

  testWidgets(
    'Android header consumes its inset and the dock slides with scroll',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 28, bottom: 24);
      tester.view.viewPadding = tester.view.padding;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      const items = [
        AppNavItem(id: 'workspace', label: 'Writing Desk', icon: Icons.notes),
        AppNavItem(id: 'messages', label: 'Messages', icon: Icons.chat),
      ];
      const listKey = ValueKey('test-scrollable-page');
      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            sections: const [AppNavSection(title: 'Workspace', items: items)],
            selectedId: 'workspace',
            onSelect: (_) {},
            onSearch: () {},
            child: SafeArea(
              bottom: false,
              child: ListView.builder(
                key: listKey,
                itemExtent: 60,
                itemCount: 40,
                itemBuilder: (_, index) => Text('Record $index'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final header = find.byType(AppTopBar);
      final surface = find.byKey(const ValueKey('app-header-surface'));
      final list = find.byKey(listKey);
      final dock = find.byType(QuietDock);
      final dockSlide = find.byKey(const ValueKey('app-dock-slide'));
      final pageBounds = tester.getRect(list);
      final dockTop = tester.getTopLeft(dock).dy;
      expect(tester.getTopLeft(surface).dy, greaterThanOrEqualTo(28));
      expect(tester.getSize(header).height - 28, lessThan(50));
      expect(pageBounds.top, tester.getBottomLeft(header).dy);

      final gesture = await tester.startGesture(pageBounds.center);
      await gesture.moveBy(const Offset(0, -100));
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump();
      expect(
        tester.widget<AnimatedSlide>(dockSlide).offset,
        const Offset(0, 1),
      );
      await tester.pump(const Duration(milliseconds: 75));
      final movingTop = tester.getTopLeft(dock).dy;
      expect(movingTop, greaterThan(dockTop));
      expect(movingTop, lessThan(844));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(dock).dy, greaterThanOrEqualTo(844));
      expect(tester.getRect(list), pageBounds);

      await gesture.moveBy(const Offset(0, 3));
      await tester.pump();
      expect(tester.widget<AnimatedSlide>(dockSlide).offset, Offset.zero);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(dock).dy, dockTop);
      expect(tester.getRect(list), pageBounds);
    },
  );
}
