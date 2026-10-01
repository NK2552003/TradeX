import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/presentation/messages_root_screen.dart';
import 'package:tradex/features/messages/presentation/widgets/conversation_tile.dart';

void main() {
  group('MessagesRootScreen Redesign Tests', () {
    testWidgets('renders desktop split-pane with inbox and empty detail initially', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MessagesRepository();
      addTearDown(() => repo.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesRootScreen(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify search input
      expect(find.byType(UiInput), findsWidgets);
      expect(find.text('Search messages'), findsOneWidget);

      // Verify filter chips
      expect(find.text('All'), findsWidgets);

      // Verify empty detail placeholder on the right
      expect(find.text('Your messages'), findsOneWidget);
      expect(find.text('Choose a conversation from the list, or start a new one.'), findsOneWidget);
    });

    testWidgets('renders mobile layout, taps conversation tile, and views thread', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MessagesRepository();
      addTearDown(() => repo.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesRootScreen(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In mobile mode, search is shown
      expect(find.text('Search messages'), findsOneWidget);

      // Find the first conversation tile and tap it
      expect(find.byType(ConversationTile), findsWidgets);
      await tester.tap(find.byType(ConversationTile).first);
      await tester.pumpAndSettle();

      // Thread conversation is now opened: composer and attachments are visible
      expect(find.byTooltip('Attach or share'), findsOneWidget);
      expect(find.byTooltip('Quick reactions'), findsOneWidget);

      // Enter a new message in composer
      await tester.enterText(find.byType(TextField).last, 'Target reached on NIFTY!');
      await tester.pump();

      // Tap send button (which is now visible with tooltip 'Send')
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      // Advance clock past simulated peer reply timer
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Message should be displayed in the thread
      expect(find.text('Target reached on NIFTY!'), findsOneWidget);
    });
  });
}
