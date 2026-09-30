import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_create_sheet.dart';
import 'package:tradex/features/ai_assistant/presentation/views/ai_chat_view.dart';

void main() {
  testWidgets('every AI create target opens a populated creation sheet', (
    WidgetTester tester,
  ) async {
    final AiAssistantRepository repository = AiAssistantRepository();
    addTearDown(repository.dispose);

    for (final AiCreateTarget target in AiCreateTarget.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => UiButton(
                label: 'Open',
                onPressed: () => AiCreateSheet.show(
                  context,
                  repository: repository,
                  target: target,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(target.label), findsOneWidget);
      expect(find.text(target.actionLabel), findsOneWidget);
      expect(find.byType(UiInput), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a targeted capability enters its creation flow', (
    WidgetTester tester,
  ) async {
    final AiAssistantRepository repository = AiAssistantRepository(
      seedThreads: <AiThread>[],
    );
    addTearDown(repository.dispose);
    AiSuggestedAction? openedAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiChatView(
            repository: repository,
            onCreateFromChat: (AiSuggestedAction action) {
              openedAction = action;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Draft a research note'));

    expect(openedAction?.target, AiCreateTarget.note);
  });
}
