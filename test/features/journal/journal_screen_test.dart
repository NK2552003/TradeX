import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/journal/ui/journal_screen.dart';

Widget _host(Widget child) => UiApp(
  theme: UiTheme.dark(),
  builder: (BuildContext context) => MaterialApp(home: Scaffold(body: child)),
);

/// Guards the two things that make the journal destination what it is: that the
/// phone and the desktop get genuinely different surfaces rather than one
/// reflowing layout, and that a link arriving from another destination opens the
/// entry it names.
void main() {
  const Size desktop = Size(1600, 1100);
  const Size phone = Size(390, 844);

  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    Size size = desktop,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(child));
    await tester.pumpAndSettle();
  }

  testWidgets('desktop is a workbench: index rail beside the open entry', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const JournalScreen());

    expect(find.byType(AppWorkbenchLayout), findsOneWidget);
    expect(find.byType(AppWorkbenchIndex), findsOneWidget);
    expect(find.byType(AppJournalNoteIndexList), findsOneWidget);
    // The rail is the desktop's own surface. Its grid twin belongs to the phone
    // and must not be built here as well.
    expect(find.byType(AppJournalNoteGrid), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('journal_index_mobile')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('journal_new_entry_rail')),
      findsOneWidget,
    );

    // Widest layout: the third column names what the open entry is linked to.
    expect(find.byType(AppLinkedRecordsPanel), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone is an index that opens an entry, and reports the step', (
    WidgetTester tester,
  ) async {
    String? announced;
    VoidCallback? back;
    await pumpAt(
      tester,
      JournalScreen(
        onSubpageChanged:
            (String? title, IconData? icon, VoidCallback? onBack) {
              announced = title;
              back = onBack;
            },
      ),
      size: phone,
    );

    expect(
      find.byKey(const ValueKey<String>('journal_index_mobile')),
      findsOneWidget,
    );
    expect(find.byType(AppJournalNoteGrid), findsOneWidget);
    expect(find.byType(AppWorkbenchLayout), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('journal_new_entry_fab')),
      findsOneWidget,
    );
    // Nothing is open yet, so the shell's app bar keeps naming the destination.
    expect(announced, isNull);

    await tester.tap(find.byType(AppJournalNoteCard).first);
    await tester.pumpAndSettle();

    expect(find.byType(AppJournalNoteGrid), findsNothing);
    expect(announced, isNotNull);
    expect(back, isNotNull);

    // The reported back callback is the only way off the entry on a phone.
    back!();
    await tester.pumpAndSettle();
    expect(find.byType(AppJournalNoteGrid), findsOneWidget);
    expect(announced, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an open request from the shell opens that entry', (
    WidgetTester tester,
  ) async {
    // Reached by scrolling in the rail, so a request that lands on it proves the
    // request drove the selection rather than the default first row.
    final AppTrade target = DemoDataSource.instance.trades()[6];

    await pumpAt(
      tester,
      JournalScreen(
        openRequest: AppLinkOpenRequest(
          kind: AppLinkKind.journal,
          id: target.id,
          seq: 1,
        ),
      ),
    );

    expect(
      find.byKey(ValueKey<String>('journal_document_${target.id}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a request for another kind is ignored, not obeyed', (
    WidgetTester tester,
  ) async {
    await pumpAt(
      tester,
      const JournalScreen(
        openRequest: AppLinkOpenRequest(
          kind: AppLinkKind.strategy,
          id: 'str_1',
          seq: 1,
        ),
      ),
    );

    // Whatever the rail chose to show, it is an entry — never the playbook the
    // misrouted request named.
    expect(
      find.byKey(const ValueKey<String>('journal_document_str_1')),
      findsNothing,
    );
    expect(find.byType(AppWorkbenchLayout), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop collapses internal left sidebar when in edit mode', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const JournalScreen());

    expect(find.byType(AppWorkbenchIndex), findsOneWidget);

    final Finder editButton = find.widgetWithText(UiButton, 'Edit details');
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    // In edit mode: internal left sidebar is collapsed
    expect(find.byType(AppWorkbenchIndex), findsNothing);

    // Back to preview: internal left sidebar is restored
    final Finder backButton = find.byTooltip('Back to record');
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.byType(AppWorkbenchIndex), findsOneWidget);
  });
}
