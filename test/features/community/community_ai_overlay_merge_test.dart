import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/copilot/copilot.dart';
import 'package:tradex/features/community/presentation/widgets/community_copilot_launcher.dart';

void main() {
  testWidgets('Community opens the new copilot with the requested context', (
    tester,
  ) async {
    final controller = CopilotController(autoLoad: false);
    CopilotScope.repository = controller;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark().toThemeData(),
        home: Scaffold(
          body: Builder(
            builder: (context) => UiButton(
              label: 'Ask copilot',
              onPressed: () => showCommunityCopilot(
                context,
                initialPrompt: 'Review the risks in this trading idea.',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ask copilot'));
    await tester.pumpAndSettle();
    expect(find.byType(CopilotScreen), findsOneWidget);
    expect(find.text('Review the risks in this trading idea.'), findsOneWidget);
    expect(controller.workspace.threads, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
