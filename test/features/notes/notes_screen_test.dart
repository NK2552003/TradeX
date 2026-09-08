import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/core/markdown_kit/markdown_preview.dart';
import 'package:tradex/features/notes/ui/note_editor_screen.dart';
import 'package:tradex/features/notes/ui/note_preview_screen.dart';
import 'package:tradex/features/notes/ui/notes_screen.dart';

Widget _host(Widget child) => UiApp(
  theme: UiTheme.dark(),
  builder: (BuildContext context) => MaterialApp(home: Scaffold(body: child)),
);

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(1400, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(child));
    await tester.pumpAndSettle();
  }

  testWidgets('desktop notes keep a searchable library beside the reader', (
    tester,
  ) async {
    await pumpAt(tester, const NotesScreen());
    expect(find.byType(AppWorkbenchLayout), findsOneWidget);
    expect(find.byType(AppWorkbenchIndex), findsOneWidget);
    expect(find.byType(AppIndexRow), findsWidgets);
    expect(find.byType(NotePreviewScreen), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('new_note_fab')), findsOneWidget);
    final rows = find.byType(AppIndexRow);
    expect(
      tester.getTopLeft(rows.at(1)).dy,
      greaterThan(tester.getTopLeft(rows.first).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('markdown table text follows the dark foreground colour', (
    WidgetTester tester,
  ) async {
    await pumpAt(
      tester,
      const RichMarkdownPreview(
        data: '| Field | Value |\n| --- | --- |\n| Ticker | NIFTY50 |',
      ),
    );

    final Finder table = find.byType(Table);
    expect(table, findsOneWidget);
    final Iterable<RichText> cells = tester.widgetList<RichText>(
      find.descendant(of: table, matching: find.byType(RichText)),
    );
    expect(cells, isNotEmpty);
    for (final RichText cell in cells) {
      final TextSpan span = cell.text as TextSpan;
      expect(span.style?.color, UiTheme.dark().colors.foreground);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating note and outline actions clear the mobile dock', (
    WidgetTester tester,
  ) async {
    const Size phone = Size(390, 844);
    const double dockInset = 88;

    await pumpAt(
      tester,
      const MediaQuery(
        data: MediaQueryData(
          size: phone,
          padding: EdgeInsets.only(bottom: dockInset),
        ),
        child: NotesScreen(),
      ),
      size: phone,
    );
    expect(
      tester.getBottomRight(find.byKey(const ValueKey('new_note_fab'))).dy,
      lessThanOrEqualTo(phone.height - dockInset),
    );

    final AppNote note = DemoDataSource.instance.notes().first;
    await pumpAt(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: phone,
          padding: EdgeInsets.only(bottom: dockInset),
        ),
        child: NotePreviewScreen(note: note, onClose: () {}, onEdit: () {}),
      ),
      size: phone,
    );
    final Finder outline = find.byTooltip('Jump to section');
    expect(outline, findsOneWidget);
    expect(
      tester.getBottomRight(outline).dy,
      lessThanOrEqualTo(phone.height - dockInset),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reader presents a document and responsive details rail', (
    WidgetTester tester,
  ) async {
    final AppNote note = DemoDataSource.instance.notes().first;
    await pumpAt(
      tester,
      NotePreviewScreen(note: note, onClose: () {}, onEdit: () {}),
    );

    expect(find.text('Document'), findsNothing);
    expect(find.text('Note details'), findsOneWidget);
    expect(find.text('Read time'), findsOneWidget);
    // The reader resolves its links through the workspace link graph, so it
    // shows every kind the note touches — trades, playbooks, other notes and
    // instruments — in the same panel the journal and playbook documents use,
    // rather than a journal-only list of its own.
    expect(find.byType(AppLinkedRecordsPanel), findsOneWidget);
    expect(find.text('Linked records'), findsOneWidget);
    expect(find.byType(AppLinkRefTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor stays usable on desktop and phone sizes', (
    WidgetTester tester,
  ) async {
    final AppNote note = DemoDataSource.instance.notes().first;

    await pumpAt(
      tester,
      NoteEditorScreen(note: note, onClose: (_) {}),
      size: const Size(1400, 800),
    );
    expect(find.text('Document setup'), findsNothing);
    expect(find.text('Writing canvas'), findsOneWidget);
    expect(find.text('Linked strategy'), findsOneWidget);
    expect(find.text('Link journal entry'), findsOneWidget);
    expect(find.byType(AppLinkedJournalCard), findsWidgets);
    expect(tester.takeException(), isNull);

    await pumpAt(
      tester,
      NoteEditorScreen(note: note, onClose: (_) {}),
      size: const Size(390, 844),
    );
    expect(find.text('Document setup'), findsNothing);
    expect(find.text('Writing canvas'), findsOneWidget);
    expect(find.text('Note details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone notes display the four-part stat strip', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const NotesScreen(), size: const Size(390, 844));

    expect(find.byType(AppNoteStatRow), findsOneWidget);
    expect(find.byType(UiStatStrip), findsOneWidget);

    final UiStatStrip strip = tester.widget<UiStatStrip>(
      find.byType(UiStatStrip),
    );
    expect(strip.stats.length, 4);
    expect(strip.stats.map((s) => s.label).toList(), <String>[
      'Notes',
      'This week',
      'Public',
      'Words',
    ]);
    expect(find.text('NOTES'), findsOneWidget);
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text('PUBLIC'), findsOneWidget);
    expect(find.text('WORDS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
