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
    'exhausted AI quota shows a single notice card and scrolls with content',
    (tester) async {
      tester.view.physicalSize = const Size(390, 720);
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

      final quotaFinder = find.textContaining('Monthly AI quota reached');
      expect(quotaFinder, findsOneWidget);
      expect(find.textContaining('AI Credits Exhausted'), findsNothing);
      expect(find.text('Upgrade Plan'), findsOneWidget);

      final double initialQuotaTop = tester.getTopLeft(quotaFinder).dy;
      await tester.drag(
        find.text('What can I help with?'),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      final double scrolledQuotaTop = tester.getTopLeft(quotaFinder).dy;
      expect(scrolledQuotaTop, lessThan(initialQuotaTop - 100));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'monthly AI credit banner scrolls with welcome content and messages',
    (tester) async {
      tester.view.physicalSize = const Size(390, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = CopilotController(autoLoad: false)
        ..quotaUsed = 1
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

      final creditsFinder = find.textContaining('AI credits remaining');
      expect(creditsFinder, findsOneWidget);
      final double beforeBannerTop = tester.getTopLeft(creditsFinder).dy;
      await tester.drag(
        find.text('What can I help with?'),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(creditsFinder).dy,
        lessThan(beforeBannerTop - 100),
      );

      // Also verify quota notice scrolls with active conversation messages.
      controller.quotaExceeded = true;
      controller.quotaUsed = 5;
      controller.workspace = CopilotWorkspace.fromJson({
        ...initialWorkspace(),
        'threads': [
          {
            'id': 't-scroll',
            'specialistId': 'analyst',
            'title': 'Scroll check',
            'messages': [
              {
                'id': 'm1',
                'role': 'user',
                'body': 'Analyze NVDA earnings.',
              },
              {
                'id': 'm2',
                'role': 'assistant',
                'body':
                    '## Direct Answer\n${List.filled(18, 'Detailed research paragraph line for scrolling verification.').join('\n\n')}',
              },
            ],
          },
        ],
      });
      controller.selectThread('t-scroll');
      await tester.pumpAndSettle();
      final listView = find.byType(ListView);
      expect(listView, findsOneWidget);
      final listController = tester.widget<ListView>(listView).controller!;
      listController.jumpTo(0);
      await tester.pumpAndSettle();
      final activeQuotaFinder = find.textContaining('Monthly AI quota reached');
      expect(activeQuotaFinder, findsOneWidget);
      final double threadQuotaTop = tester.getTopLeft(activeQuotaFinder).dy;
      await tester.drag(listView, const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(activeQuotaFinder).dy,
        lessThan(threadQuotaTop - 40),
      );
      await tester.drag(listView, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(activeQuotaFinder, findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
