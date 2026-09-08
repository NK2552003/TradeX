import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/navigation/role_navigation_config.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

Widget shell() => UiApp(
  theme: UiTheme.dark(),
  builder: (context) => MaterialApp(
    home: AppShell(
      sections: RoleNavigationConfig.forRole(UserRole.customer).sections,
      selectedId: 'journal',
      onSelect: (_) {},
      researchPanelBuilder: (context, close, overlay) => Column(
        children: [
          UiButton(label: 'Close research', onPressed: close),
          const Expanded(child: Center(child: Text('Research content'))),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topLeft,
          child: UiInput(hintText: 'Draft'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('research sits beside header and focus preserves the draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shell());
    await tester.pumpAndSettle();
    final header = find.byKey(const ValueKey('app-header-surface'));
    final panel = find.byKey(const ValueKey('app-research-surface'));
    final content = find.byKey(const ValueKey('app-content-surface'));
    final headerRect = tester.getRect(header);
    final panelRect = tester.getRect(panel);
    expect(panelRect.top, closeTo(headerRect.top, 1));
    expect(panelRect.bottom, greaterThan(980));
    expect(panelRect.left, greaterThan(headerRect.right));
    expect(find.ancestor(of: panel, matching: content), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppTopBar),
        matching: find.text('Focus mode'),
      ),
      findsOneWidget,
    );
    expect(find.text('TRADER WORKSPACE'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Keep my unsaved thesis');
    await tester.tap(find.widgetWithText(UiButton, 'Focus mode'));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(tester.getSize(header).width, greaterThan(headerRect.width));
    expect(find.text('Keep my unsaved thesis'), findsOneWidget);
    await tester.tap(find.widgetWithText(UiButton, 'Research desk'));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(find.text('Keep my unsaved thesis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 768.0]) {
    testWidgets('research opens in an inset overlay at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-research-surface')), findsNothing);
      final action = width < 600
          ? find.byTooltip('Research desk')
          : find.widgetWithText(UiButton, 'Research desk');
      await tester.tap(action);
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byKey(const ValueKey('ui-drawer-surface')),
      );
      expect(rect.left, greaterThan(0));
      expect(rect.right, lessThan(width));
      expect(rect.top, greaterThan(0));
      expect(rect.bottom, lessThan(900));
      await tester.tap(find.text('Close research'));
      await tester.pumpAndSettle();
      expect(find.text('Research content'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [390.0, 1440.0]) {
    testWidgets('dialog floats and stays scrollable above keyboard at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (context) => MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => UiButton(
                  label: 'Open',
                  onPressed: () => UiDialog.show<void>(
                    context,
                    child: const UiDialog(
                      title: 'Link your thinking',
                      content: Column(
                        children: [
                          UiInput(hintText: 'Find a note'),
                          SizedBox(height: 700),
                          Text('Last result'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byKey(const ValueKey('ui-dialog-surface')),
      );
      expect(rect.left, greaterThan(0));
      expect(rect.right, lessThan(width));
      expect(rect.top, greaterThan(0));
      expect(rect.bottom, lessThanOrEqualTo(500));
      await tester.ensureVisible(find.text('Last result'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
