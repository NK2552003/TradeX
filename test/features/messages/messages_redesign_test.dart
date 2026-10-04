import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/messages_root_screen.dart';
import 'package:tradex/features/messages/presentation/views/messages_inbox_view.dart';
import 'package:tradex/features/messages/presentation/widgets/message_bubble.dart';

void main() {
  group('Messages Redesign Tests', () {
    testWidgets(
      'MessagesRootScreen uses UiSplitPane on desktop and AppPaneHeader on secondary views',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = MessagesRepository();
        addTearDown(() => repo.dispose());

        // Archive a thread so the Archived footer link is present
        repo.toggleArchive('thread_2');

        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.dark().toThemeData(),
            home: Scaffold(
              body: MessagesRootScreen(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must use UiSplitPane for responsive two-pane layout
        expect(find.byType(UiSplitPane), findsOneWidget);

        // Tap Archived in footer to open secondary panel
        final archivedFinder = find.text('Archived');
        expect(archivedFinder, findsWidgets);
        await tester.tap(archivedFinder.first);
        await tester.pumpAndSettle();

        // Secondary view must use AppPaneHeader
        expect(find.byType(AppPaneHeader), findsOneWidget);
        expect(find.text('Archived'), findsWidgets);
      },
    );

    testWidgets('MessagesInboxView renders Active now presence strip', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MessagesRepository();
      addTearDown(() => repo.dispose());

      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: Scaffold(
            body: MessagesInboxView(
              repository: repo,
              onOpenThread: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // MessagesSectionHeader renders title in uppercase
      expect(find.text('ACTIVE NOW'), findsOneWidget);
    });

    testWidgets(
      'MessageBubble renders rich trade setup card with stats and risk-reward badges',
      (WidgetTester tester) async {
        final message = ChatMessage(
          id: 'msg_setup_1',
          threadId: 't1',
          body: 'Check out this setup on NVDA',
          fromMe: false,
          sentAt: DateTime.now(),
          attachment: const MessageAttachment(
            id: 'att_setup_1',
            title: 'NVDA Bull Flag',
            subtitle: 'Clean breakout above \$142 with heavy volume confirmation.',
            kind: MessageAttachmentKind.tradeSetup,
            direction: 'long',
            entry: 142.50,
            stop: 138.00,
            target: 152.00,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.dark().toThemeData(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: MessageBubble(
                  message: message,
                  senderName: 'Trader Alice',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Trade setup card elements
        expect(find.text('NVDA Bull Flag'), findsOneWidget);
        expect(find.text('Long'), findsOneWidget);
        expect(find.text('R:R 2.11'), findsOneWidget);
        expect(find.byType(UiStatStrip), findsOneWidget);
        expect(
          find.text('Clean breakout above \$142 with heavy volume confirmation.'),
          findsOneWidget,
        );
      },
    );
  });
}
