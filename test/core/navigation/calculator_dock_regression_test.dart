import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_dock/quiet_dock.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/navigation/role_navigation_config.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';

void main() {
  test(
    'RoleNavigationConfig does not duplicate primary dock routes in mobileMoreItems',
    () {
      final trader = RoleNavigationConfig.forRole(UserRole.customer);
      final traderPrimaryIds = trader.mobilePrimaryItems.map((e) => e.id).toSet();
      final traderMoreIds = trader.mobileMoreItems.map((e) => e.id).toSet();
      expect(traderPrimaryIds.contains('calculators'), isTrue);
      expect(traderMoreIds.contains('calculators'), isFalse);

      final affiliate = RoleNavigationConfig.forRole(UserRole.affiliate);
      final affiliatePrimaryIds = affiliate.mobilePrimaryItems
          .map((e) => e.id)
          .toSet();
      final affiliateMoreIds = affiliate.mobileMoreItems
          .map((e) => e.id)
          .toSet();
      expect(affiliatePrimaryIds.contains('marketing'), isTrue);
      expect(affiliateMoreIds.contains('marketing'), isFalse);
    },
  );

  testWidgets(
    'Tapping Calculators on mobile dock activates the Calculators slot instead of the center button',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final nav = RoleNavigationConfig.forRole(UserRole.customer);
      String selected = 'workspace';

      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (_) => MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => AppShell(
                sections: nav.sections,
                mobilePrimaryItems: nav.mobilePrimaryItems,
                mobileMoreItems: nav.mobileMoreItems,
                selectedId: selected,
                onSelect: (id) => setState(() => selected = id),
                child: Center(child: Text('Active route: $selected')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Calculators on the dock (slot 3, destination index 2).
      await tester.tap(find.byIcon(Icons.calculate_outlined).last);
      await tester.pumpAndSettle();

      expect(selected, 'calculators');
      final QuietDock dockAfterCalc = tester.widget<QuietDock>(
        find.byType(QuietDock),
      );
      expect(dockAfterCalc.selectedIndex, 2);
      expect(dockAfterCalc.centerActionActive, isFalse);
      // Center button must remain the grid icon, not a back-arrowed calculator.
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

      // Open the center More menu -> tap Messages (a true More route).
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Messages').last);
      await tester.pumpAndSettle();

      expect(selected, 'messages');
      final QuietDock dockOnMore = tester.widget<QuietDock>(
        find.byType(QuietDock),
      );
      expect(dockOnMore.centerActionActive, isTrue);

      // Tapping Calculators on the dock from Messages must return to Calculators
      // even though the dock controller's last primary index was already 2.
      await tester.tap(find.byIcon(Icons.calculate_outlined).last);
      await tester.pumpAndSettle();

      expect(selected, 'calculators');
      final QuietDock dockBackOnCalc = tester.widget<QuietDock>(
        find.byType(QuietDock),
      );
      expect(dockBackOnCalc.selectedIndex, 2);
      expect(dockBackOnCalc.centerActionActive, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AppShell keeps primary dock slot active even if mobileMoreItems duplicates its id',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const primary = <AppNavItem>[
        AppNavItem(
          id: 'workspace',
          label: 'Writing Desk',
          icon: Icons.edit_note_outlined,
          selectedIcon: Icons.edit_note_rounded,
        ),
        AppNavItem(
          id: 'community',
          label: 'Community',
          icon: Icons.forum_outlined,
          selectedIcon: Icons.forum_rounded,
        ),
        AppNavItem(
          id: 'calculators',
          label: 'Calculators',
          icon: Icons.calculate_outlined,
          selectedIcon: Icons.calculate_rounded,
        ),
        AppNavItem(
          id: 'settings',
          label: 'Settings',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
        ),
      ];
      const duplicateMore = <AppNavItem>[
        AppNavItem(
          id: 'calculators',
          label: 'Calculators',
          icon: Icons.calculate_outlined,
        ),
        AppNavItem(
          id: 'messages',
          label: 'Messages',
          icon: Icons.chat_bubble_outline_rounded,
        ),
      ];

      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (_) => MaterialApp(
            home: AppShell(
              sections: const <AppNavSection>[
                AppNavSection(title: 'Workspace', items: primary),
              ],
              mobilePrimaryItems: primary,
              mobileMoreItems: duplicateMore,
              selectedId: 'calculators',
              onSelect: (_) {},
              child: const Text('Calculators screen'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final QuietDock dock = tester.widget<QuietDock>(find.byType(QuietDock));
      expect(dock.selectedIndex, 2);
      expect(dock.centerActionActive, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
