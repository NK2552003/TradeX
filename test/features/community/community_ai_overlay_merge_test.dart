import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_assistant_overlay_sheet.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/widgets/community_ai_assistant_dialog.dart';

void main() {
  group('Community & Main AI Assistant Overlay Merge Tests', () {
    late CommunityRepository communityRepo;
    late AiAssistantRepository aiRepo;

    setUp(() {
      communityRepo = CommunityRepository();
      aiRepo = AiAssistantRepository(
        communityRepository: communityRepo,
        seedThreads: <AiThread>[
          AiThread(
            id: 'community_ai_thread_1',
            title: 'Market Intelligence',
            persona: AiPersona.swing,
            messages: const <AppAiMessage>[],
            updatedAt: DateTime.now(),
          ),
        ],
      );
      AiAssistantRepositoryScope.repository = aiRepo;
    });

    testWidgets(
      'CommunityAiFloatingBar opens canonical AiAssistantOverlaySheet with community intelligence context',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: <Widget>[
                  const Center(child: Text('Community Feed Content')),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: CommunityAiFloatingBar(
                      repository: communityRepo,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify the floating bar button is rendered
        expect(find.byType(CommunityAiFloatingBar), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

        // Tap the floating bar button to open the merged AI overlay
        await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
        await tester.pumpAndSettle();

        // Verify it opened the canonical AiAssistantOverlaySheet
        expect(find.byType(AiAssistantOverlaySheet), findsOneWidget);
        expect(find.text('TradeX AI Copilot'), findsOneWidget);
        expect(find.text('Institutional Market Intelligence'), findsOneWidget);

        // Verify Community Market Intelligence context bar
        expect(find.textContaining('Community Market Intelligence'), findsOneWidget);

        // Verify Community contextual suggestion chips are present
        expect(
          find.text('Scan community sentiment on BankNifty & Top F&O movers'),
          findsOneWidget,
        );

        await tester.drag(
          find.text('Scan community sentiment on BankNifty & Top F&O movers'),
          const Offset(-300, 0),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Generate swing trade setup with entry, stop loss, and targets'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CommunityAiAssistantDialog.show delegates to canonical AiAssistantOverlaySheet with preset setup',
      (WidgetTester tester) async {
        final preset = kAiChartPresets.first;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        CommunityAiAssistantDialog.show(
                          context,
                          repository: communityRepo,
                          initialPreset: preset,
                        );
                      },
                      child: const Text('Open Preset Setup'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Preset Setup'));
        await tester.pump();

        // Stop generation immediately so async timers don't run indefinitely
        aiRepo.stop();
        await tester.pumpAndSettle();

        // Verify AiAssistantOverlaySheet opened with preset context
        expect(find.byType(AiAssistantOverlaySheet), findsOneWidget);
        expect(find.text('TradeX AI Copilot'), findsOneWidget);
        expect(
          find.textContaining('${preset.symbol} (${preset.pattern})'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Confidence: ${preset.confidence}%'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CommunityAiQuickPromptDialog.show delegates to AiAssistantOverlaySheet with prompt and copilot title',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        CommunityAiQuickPromptDialog.show(
                          context,
                          repository: communityRepo,
                          initialPrompt: 'What is the institutional sentiment today?',
                        );
                      },
                      child: const Text('Open Quick Prompt'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Quick Prompt'));
        await tester.pump();

        aiRepo.stop();
        await tester.pumpAndSettle();

        expect(find.byType(AiAssistantOverlaySheet), findsOneWidget);
        expect(find.textContaining('Community Alpha Copilot'), findsOneWidget);
        expect(find.text('What is the institutional sentiment today?'), findsOneWidget);
      },
    );

    testWidgets(
      'AiAssistantOverlaySheet message actions render Post and Strategy alongside Copy, Note, Log, Share',
      (WidgetTester tester) async {
        final threadRepo = AiAssistantRepository(
          communityRepository: communityRepo,
          seedThreads: <AiThread>[
            AiThread(
              id: 'assistant_thread_action_test',
              title: 'Action Test',
              persona: AiPersona.swing,
              messages: <AppAiMessage>[
                AppAiMessage(
                  id: 'assistant_msg_1',
                  role: AppAiRole.assistant,
                  body:
                      'Breakout confirmed on NIFTY above 24,850 with heavy call unwinding.',
                  sentAt: DateTime.now(),
                ),
              ],
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
                          repository: threadRepo,
                          contextTitle: 'Community Alpha Copilot',
                        );
                      },
                      child: const Text('Open Copilot Sheet'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Copilot Sheet'));
        await tester.pumpAndSettle();

        // Verify action buttons under the assistant message
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Save Note'), findsOneWidget);
        expect(find.text('Log Trade'), findsOneWidget);
        expect(find.text('Strategy'), findsOneWidget);
        expect(find.text('Post'), findsOneWidget);
        expect(find.text('Share'), findsOneWidget);
      },
    );
  });
}
