import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/copilot/copilot.dart';

void main() {
  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('copilot sheet fits $width and uses a single pane', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = CopilotController(autoLoad: false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => UiButton(
                label: 'Open copilot',
                onPressed: () => CopilotSheet.show(
                  context,
                  repository: controller,
                  contextTitle: 'Community copilot',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open copilot'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byKey(const ValueKey('ui-drawer-surface')),
      );
      expect(rect.right, lessThanOrEqualTo(width));
      if (width >= 600) {
        expect(rect.center.dx, greaterThan(width / 2));
      } else {
        expect(rect.center.dx, closeTo(width / 2, 1));
        expect(rect.top, greaterThan(8));
      }
      expect(find.byType(UiSplitPane), findsNothing);
      await tester.tap(find.text(width < 600 ? 'Library' : 'Workspace').first);
      await tester.pumpAndSettle();
      expect(find.text('New conversation'), findsWidgets);
      expect(tester.takeException(), isNull);
      if (width < 600) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final keyboardRect = tester.getRect(
          find.byKey(const ValueKey('ui-drawer-surface')),
        );
        expect(keyboardRect.bottom, lessThanOrEqualTo(600));
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
      }
      await tester.tap(find.byTooltip('Close').first);
      await tester.pumpAndSettle();
      expect(find.byType(CopilotScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets(
    'exhausted AI quota shows a single notice card without duplicate banner',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = CopilotController(autoLoad: false)
        ..quotaExceeded = true
        ..quotaUsed = 5
        ..quotaLimit = 5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CopilotScreen(
              repository: controller,
              embedInScaffold: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Monthly AI quota reached'), findsOneWidget);
      expect(find.textContaining('AI Credits Exhausted'), findsNothing);
      expect(find.text('Upgrade Plan'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
