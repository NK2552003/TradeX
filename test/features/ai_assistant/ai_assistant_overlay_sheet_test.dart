import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_assistant_overlay_sheet.dart';

void main() {
  group('AiAssistantOverlaySheet Tests', () {
    testWidgets('renders overlay sheet with context banner and suggestions', (
      WidgetTester tester,
    ) async {
      final repo = AiAssistantRepository(
        seedThreads: <AiThread>[
          AiThread(
            id: 'test_thread_1',
            title: 'Strategy Discussion',
            persona: AiPersona.options,
            messages: const <AppAiMessage>[],
            updatedAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      AiAssistantOverlaySheet.show(
                        context,
                        repository: repo,
                        contextTitle: 'ORB-15 Momentum Strategy',
                        contextSubtitle: 'Breakout rules & risk sizing',
                        contextIcon: Icons.bolt_rounded,
                      );
                    },
                    child: const Text('Open Copilot'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap button to open overlay sheet
      await tester.tap(find.text('Open Copilot'));
      await tester.pumpAndSettle();

      // Header components
      expect(find.text('alphajournal AI Copilot'), findsOneWidget);
      expect(find.textContaining('ORB-15 Momentum Strategy'), findsOneWidget);
      expect(find.textContaining('Breakout rules & risk sizing'), findsOneWidget);

      // Suggestions pills for strategy context
      expect(find.textContaining('Stress-test'), findsOneWidget);

      // Send prompt field & button (shared AppAiChatBlock composer)
      expect(find.byType(UiInput), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsWidgets);
    });

    testWidgets('entering prompt and sending adds user message', (
      WidgetTester tester,
    ) async {
      final repo = AiAssistantRepository(
        seedThreads: <AiThread>[
          AiThread(
            id: 'test_thread_2',
            title: 'Empty Setup',
            persona: AiPersona.momentum,
            messages: const <AppAiMessage>[],
            updatedAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      AiAssistantOverlaySheet.show(
                        context,
                        repository: repo,
                        contextTitle: 'NIFTY Options Setup',
                      );
                    },
                    child: const Text('Open Sheet'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Enter a prompt in the input
      await tester.enterText(find.byType(UiInput), 'What is the risk-to-reward?');
      await tester.pump();

      // Tap send (shared composer tooltip)
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      // Stop generation so timer doesn't linger
      repo.stop();
      await tester.pumpAndSettle();

      expect(find.text('What is the risk-to-reward?'), findsOneWidget);
    });
  });
}
