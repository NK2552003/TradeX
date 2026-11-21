import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/auth/presentation/widgets/apple_device_frames.dart';
import 'package:alphajournal/features/copilot/copilot.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_copilot_launcher.dart';

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

  testWidgets(
    'CommunityCopilotLauncher uses AI sparkle icon instead of message icon',
    (tester) async {
      await tester.pumpWidget(
        UiThemeScope(
          theme: UiTheme.dark(),
          child: const MaterialApp(
            home: Scaffold(body: CommunityCopilotLauncher()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);

      await tester.pumpWidget(
        UiThemeScope(
          theme: UiTheme.dark(),
          child: MaterialApp(
            home: Scaffold(
              body: CommunityCopilotLauncher(
                showCompose: true,
                onCompose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    },
  );

  testWidgets(
    'AppleIphoneSvgFrame community demo dock uses AI sparkle icon on right FAB',
    (tester) async {
      await tester.pumpWidget(
        UiThemeScope(
          theme: UiTheme.dark(),
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppleIphoneSvgFrame(
                  communityDock: true,
                  screen: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    },
  );
}
