import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/markdown_kit/markdown_preview.dart';
import 'package:alphajournal/features/journal/ui/journal_entry_screen.dart';

void main() {
  group('Journal Entry Screen Markdown Rendering', () {
    testWidgets(
      'renders markdown once and does not display duplicate raw markdown text',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const String markdownBody =
            '# Trade Thesis\n**NIFTY Breakout** setup with strong volume.';

        // Legacy case where notes was equal to content
        final AppTrade entry = AppTrade(
          id: 'test-trade-1',
          ticker: 'NIFTY',
          side: AppSide.long,
          entry: 22000.0,
          exit: 22300.0,
          openedAt: DateTime.now(),
          closedAt: DateTime.now(),
          pnl: 15000.0,
          pnlPercent: 1.36,
          content: markdownBody,
          notes: markdownBody, // identical to content
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JournalEntryScreen(
                entry: entry,
                onClose: () {},
                onEdit: () {},
                isPublicContext: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // RichMarkdownPreview should be present
        expect(find.byType(RichMarkdownPreview), findsOneWidget);

        // Raw unparsed text "# Trade Thesis" should NOT be rendered in a separate raw Text widget
        // flutter_markdown parses "# Trade Thesis" into a Text widget with just "Trade Thesis"
        expect(find.text('# Trade Thesis'), findsNothing);
        expect(find.text(markdownBody), findsNothing);
      },
    );

    testWidgets(
      'displays explicit takeaway in a Callout when distinct from content without raw duplication',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const String markdownBody = '## Analysis\nTested 50 EMA and bounced.';
        const String distinctTakeaway =
            'Always wait for the close above resistance.';

        final AppTrade entry = AppTrade(
          id: 'test-trade-2',
          ticker: 'BANKNIFTY',
          side: AppSide.long,
          entry: 48000.0,
          exit: null,
          openedAt: DateTime.now(),
          content: markdownBody,
          notes: distinctTakeaway,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JournalEntryScreen(
                entry: entry,
                onClose: () {},
                onEdit: () {},
                isPublicContext: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Key Takeaway callout should display the takeaway
        expect(find.text('Key Takeaway'), findsOneWidget);
        expect(find.text(distinctTakeaway), findsOneWidget);

        // Markdown preview should render the analysis body
        expect(find.byType(RichMarkdownPreview), findsOneWidget);
        expect(find.text('## Analysis'), findsNothing);
      },
    );
  });
}
