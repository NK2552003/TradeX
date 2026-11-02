import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/messages_root_screen.dart';
import 'package:tradex/features/messages/presentation/overlays/message_share_chart_dialog.dart';
import 'package:tradex/features/messages/presentation/overlays/message_trade_setup_dialog.dart';
import 'package:tradex/features/messages/presentation/views/messages_inbox_view.dart';
import 'package:tradex/features/messages/presentation/widgets/message_bubble.dart';
import 'package:tradex/features/messages/presentation/widgets/message_composer.dart';

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

    testWidgets('MessageComposer renders symmetrical layout and quick action pills', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: Scaffold(
            body: MessageComposer(
              threadId: 't1',
              onSendText: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Flanking circular targets
      expect(find.byTooltip('Attach or share'), findsOneWidget);
      expect(find.byTooltip('Record voice note'), findsOneWidget);
      expect(find.byTooltip('Quick reactions'), findsOneWidget);

      // Quick action pills
      expect(find.text('Chart'), findsOneWidget);
      expect(find.text('Trade Setup'), findsOneWidget);
      expect(find.text('Voice Note'), findsOneWidget);
    });

    testWidgets('MessageComposer triggers live voice recording and discard', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: Scaffold(
            body: MessageComposer(
              threadId: 't1',
              onSendText: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap voice note pill to start recording
      await tester.tap(find.text('Voice Note'));
      await tester.pump();

      // In recording mode: timer display and discard button are visible
      expect(find.text('0:00'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // Tap discard
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump();

      // Returns to standard composer
      expect(find.byTooltip('Record voice note'), findsOneWidget);
    });

    testWidgets('MessageShareChartDialog renders symbol picker, timeframe, pattern and preview', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: const Scaffold(
            body: MessageShareChartDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share Technical Chart'), findsOneWidget);
      expect(find.text('NIFTY 50'), findsWidgets);
      expect(find.text('Bullish Breakout'), findsWidgets);
      expect(find.byType(UiCandleChart), findsOneWidget);
      expect(find.text('Share Chart'), findsOneWidget);
    });

    testWidgets('MessageTradeSetupDialog calculates risk-reward ratio dynamically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: const Scaffold(
            body: MessageTradeSetupDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share Trade Setup'), findsOneWidget);
      expect(find.text('LONG (BUY)'), findsWidgets);
      expect(find.text('SHORT (SELL)'), findsWidgets);
      expect(find.text('Max Risk'), findsOneWidget);
      expect(find.text('Share Setup'), findsOneWidget);
    });

    testWidgets('MessageBubble renders interactive UiCandleChart for chart attachments', (
      WidgetTester tester,
    ) async {
      final now = DateTime.now();
      final candles = List<UiCandle>.generate(10, (i) {
        final t = now.subtract(Duration(minutes: (10 - i) * 15));
        final base = 24000.0 + (i * 20);
        return UiCandle(
          time: t,
          open: base,
          high: base + 15,
          low: base - 10,
          close: base + 8,
          volume: 12000,
        );
      });

      final message = ChatMessage(
        id: 'msg_chart_1',
        threadId: 't1',
        body: 'Check out the breakout pattern on NIFTY',
        fromMe: false,
        sentAt: DateTime.now(),
        attachment: MessageAttachment(
          id: 'att_chart_1',
          kind: MessageAttachmentKind.chart,
          title: 'NIFTY 50 • 15m',
          subtitle: 'Bullish Breakout',
          candles: candles,
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
                senderName: 'Alpha Desk',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NIFTY 50 • 15m'), findsOneWidget);
      expect(find.text('Bullish Breakout'), findsOneWidget);
      expect(find.byType(UiCandleChart), findsOneWidget);
    });
  });
}
