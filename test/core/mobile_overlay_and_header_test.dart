import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/widgets/app_notifications_overlay.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/presentation/views/community_follow_view.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_side_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Size mobileSize = Size(390, 844);

  void configureMobileViewport(WidgetTester tester) {
    tester.view.physicalSize = mobileSize;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });
  }

  testWidgets(
    'showSettingsSideSheet attaches flush to bottom edge on mobile screens',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => UiButton(
                label: 'Open Sheet',
                onPressed: () {
                  showSettingsSideSheet<void>(
                    context,
                    title: 'Overview of Intel Corporation (INTC)',
                    showHeader: false,
                    child: const Center(child: Text('Note Body')),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final Finder sheetFinder = find.byKey(
        const ValueKey<String>('settings-side-sheet-surface'),
      );
      expect(sheetFinder, findsOneWidget);
      final Rect rect = tester.getRect(sheetFinder);
      expect(rect.bottom, closeTo(mobileSize.height, 0.5));
      expect(rect.left, closeTo(0.0, 0.5));
      expect(rect.right, closeTo(mobileSize.width, 0.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('UiDrawer.show attaches flush to bottom edge on mobile screens', (
    WidgetTester tester,
  ) async {
    configureMobileViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => UiButton(
              label: 'Open Drawer',
              onPressed: () {
                UiDrawer.show<void>(
                  context,
                  title: 'Inspector',
                  child: const Text('Drawer Content'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Drawer'));
    await tester.pumpAndSettle();

    final Finder drawerFinder = find.byKey(const ValueKey('ui-drawer-surface'));
    expect(drawerFinder, findsOneWidget);
    final Rect rect = tester.getRect(drawerFinder);
    expect(rect.bottom, closeTo(mobileSize.height, 0.5));
    expect(rect.left, closeTo(0.0, 0.5));
    expect(rect.right, closeTo(mobileSize.width, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('UiDialog.show attaches flush to bottom edge on mobile screens', (
    WidgetTester tester,
  ) async {
    configureMobileViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => UiButton(
              label: 'Open Dialog',
              onPressed: () {
                UiDialog.show<void>(
                  context,
                  child: const UiDialog(
                    title: 'Confirm Action',
                    description: 'Mobile sheet should sit flush at the bottom.',
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    final Finder dialogFinder = find.byKey(const ValueKey('ui-dialog-surface'));
    expect(dialogFinder, findsOneWidget);
    final Rect rect = tester.getRect(dialogFinder);
    expect(rect.bottom, closeTo(mobileSize.height, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AppNotificationsOverlay attaches flush to bottom edge on mobile screens',
    (WidgetTester tester) async {
      configureMobileViewport(tester);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final CommunityRepository repo = CommunityRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => UiButton(
                label: 'Open Notifications',
                onPressed: () {
                  AppNotificationsOverlay.show(context, repository: repo);
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Notifications'));
      await tester.pumpAndSettle();

      final Finder overlayFinder = find.byKey(
        const ValueKey<String>('app-notifications-overlay-surface'),
      );
      expect(overlayFinder, findsOneWidget);
      final Rect rect = tester.getRect(overlayFinder);
      expect(rect.bottom, closeTo(mobileSize.height, 0.5));
      expect(rect.left, closeTo(0.0, 0.5));
      expect(rect.right, closeTo(mobileSize.width, 0.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UiHeader centers stacked action icons horizontally on mobile screens',
    (WidgetTester tester) async {
      configureMobileViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: UiHeader(
                key: const ValueKey<String>('mobile-detail-header'),
                title: 'Overview of Intel Corporation (INTC)',
                leading: UiIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () {},
                ),
                actions: <Widget>[
                  UiIconButton(
                    key: const ValueKey<String>('header-action-0'),
                    icon: Icons.auto_awesome_outlined,
                    tooltip: 'AI',
                    onPressed: () {},
                  ),
                  UiIconButton(
                    key: const ValueKey<String>('header-action-1'),
                    icon: Icons.bookmark_border_rounded,
                    tooltip: 'Save',
                    onPressed: () {},
                  ),
                  UiIconButton(
                    key: const ValueKey<String>('header-action-2'),
                    icon: Icons.share_outlined,
                    tooltip: 'Share',
                    onPressed: () {},
                  ),
                  UiIconButton(
                    key: const ValueKey<String>('header-action-3'),
                    icon: Icons.public_rounded,
                    tooltip: 'Publish',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Rect headerRect = tester.getRect(
        find.byKey(const ValueKey<String>('mobile-detail-header')),
      );
      final Rect firstActionRect = tester.getRect(
        find.byKey(const ValueKey<String>('header-action-0')),
      );
      final Rect lastActionRect = tester.getRect(
        find.byKey(const ValueKey<String>('header-action-3')),
      );
      final double actionsCenterX =
          (firstActionRect.left + lastActionRect.right) / 2.0;

      expect(actionsCenterX, closeTo(headerRect.center.dx, 1.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('CommunityFollowView omits Refreshing network banner text', (
    WidgetTester tester,
  ) async {
    configureMobileViewport(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final CommunityRepository repo = CommunityRepository();
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommunityFollowView(repository: repo)),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Refreshing network'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.textContaining('Refreshing network'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
