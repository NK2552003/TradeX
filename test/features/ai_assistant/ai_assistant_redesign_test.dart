import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/ai_assistant_root_screen.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_assistant_overlay_sheet.dart';
import 'package:tradex/features/ai_assistant/presentation/views/ai_insights_view.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

void main() {
  group('AI Assistant Redesign Tests', () {
    testWidgets(
      'AiAssistantRootScreen uses UiTabs and responsive panes (no raw TabBar)',
      (WidgetTester tester) async {
        // Test desktop (1280 width) -> UiThreePane + UiTabs
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = AiAssistantRepository();
        addTearDown(() => repo.dispose());

        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.dark().toThemeData(),
            home: Scaffold(
              body: AiAssistantRootScreen(
                repository: repo,
                userRole: UserRole.customer,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must use UiTabs and not raw Material TabBar
        expect(find.byType(UiTabs), findsWidgets);
        expect(find.byType(TabBar), findsNothing);

        // Desktop three-pane layout
        expect(find.byType(UiThreePane), findsOneWidget);

        // Side panel uses AppPaneHeader
        expect(find.byType(AppPaneHeader), findsWidgets);

        // Switch to tablet (768 width) -> UiSplitPane + UiTabs
        tester.view.physicalSize = const Size(768, 900);
        await tester.pumpAndSettle();

        expect(find.byType(UiTabs), findsWidgets);
        expect(find.byType(TabBar), findsNothing);
        expect(find.byType(UiSplitPane), findsWidgets);
      },
    );

    testWidgets(
      'AiAssistantOverlaySheet uses AppAiChatBlock with AppAiMessageBubble action builder',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = AiAssistantRepository(
          seedThreads: <AiThread>[
            AiThread(
              id: 'thread_test',
              title: 'Trade Setup',
              persona: AiPersona.options,
              messages: <AppAiMessage>[
                const AppAiMessage(
                  id: 'msg_1',
                  role: AppAiRole.user,
                  body: 'Analyze NVDA setup',
                ),
                AppAiMessage(
                  id: 'msg_2',
                  role: AppAiRole.assistant,
                  body: 'NVDA shows a clean bull flag breakout at \$142.50.',
                  sentAt: DateTime.now(),
                ),
              ],
              updatedAt: DateTime.now(),
            ),
          ],
        );
        addTearDown(() => repo.dispose());

        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.dark().toThemeData(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    AiAssistantOverlaySheet.show(
                      context,
                      repository: repo,
                      contextTitle: 'NVDA Analysis',
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Renders unified AppAiChatBlock
        expect(find.byType(AppAiChatBlock), findsOneWidget);

        // Renders message bubbles
        expect(find.byType(AppAiMessageBubble), findsNWidgets(2));

        // Renders action buttons from the messageActionsBuilder slot
        expect(find.text('Save Note'), findsOneWidget);
        expect(find.text('Log Trade'), findsOneWidget);
        expect(find.text('Strategy'), findsOneWidget);
        expect(find.text('Post'), findsOneWidget);
      },
    );

    testWidgets('AiInsightsView renders setup distribution donut chart', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = AiAssistantRepository();
      addTearDown(() => repo.dispose());

      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiInsightsView(
                repository: repo,
                onOpenChartAnalysis: (_) {},
                onCreateFromSetup: (_, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Setups breakdown donut chart
      expect(find.text('Setups at a glance'), findsOneWidget);
      expect(find.byType(UiDonutChart), findsOneWidget);
    });
  });
}
