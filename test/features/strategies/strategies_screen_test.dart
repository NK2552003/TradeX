import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/strategies/ui/strategies_screen.dart';

Widget _host(Widget child) => UiApp(
  theme: UiTheme.dark(),
  builder: (BuildContext context) => MaterialApp(home: Scaffold(body: child)),
);

/// Guards the playbook library's two surfaces and its link entry point.
///
/// The same contract as the journal destination, on purpose: whatever is true of
/// one index ⇄ document pair should be true of the other, so a reader who learns
/// the journal already knows this.
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

  testWidgets(
    'desktop is a workbench: playbook rail beside the open playbook',
    (WidgetTester tester) async {
      await pumpAt(tester, const StrategiesScreen());

      expect(find.byType(AppWorkbenchLayout), findsOneWidget);
      expect(find.byType(AppWorkbenchIndex), findsOneWidget);
      expect(find.byType(AppStrategyNoteIndexList), findsOneWidget);
      expect(find.byType(AppStrategyNoteGrid), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('strategy_index_mobile')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('strategy_new_rail')),
        findsOneWidget,
      );
      expect(find.byType(AppLinkedRecordsPanel), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phone is a library that opens a playbook, and reports the step',
    (WidgetTester tester) async {
      String? announced;
      VoidCallback? back;
      await pumpAt(
        tester,
        StrategiesScreen(
          onSubpageChanged:
              (String? title, IconData? icon, VoidCallback? onBack) {
                announced = title;
                back = onBack;
              },
        ),
        size: phone,
      );

      expect(
        find.byKey(const ValueKey<String>('strategy_index_mobile')),
        findsOneWidget,
      );
      expect(find.byType(AppStrategyNoteGrid), findsOneWidget);
      expect(find.byType(AppWorkbenchLayout), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('strategy_new_fab')),
        findsOneWidget,
      );
      expect(announced, isNull);

      await tester.tap(find.byType(AppStrategyNoteCard).first);
      await tester.pumpAndSettle();

      expect(find.byType(AppStrategyNoteGrid), findsNothing);
      expect(announced, isNotNull);
      expect(back, isNotNull);

      back!();
      await tester.pumpAndSettle();
      expect(find.byType(AppStrategyNoteGrid), findsOneWidget);
      expect(announced, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an open request from the shell opens that playbook', (
    WidgetTester tester,
  ) async {
    final AppStrategy target = DemoDataSource.instance.strategies()[4];

    await pumpAt(
      tester,
      StrategiesScreen(
        openRequest: AppLinkOpenRequest(
          kind: AppLinkKind.strategy,
          id: target.id,
          seq: 1,
        ),
      ),
    );

    expect(
      find.byKey(ValueKey<String>('strategy_document_${target.id}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a request for another kind is ignored, not obeyed', (
    WidgetTester tester,
  ) async {
    await pumpAt(
      tester,
      const StrategiesScreen(
        openRequest: AppLinkOpenRequest(
          kind: AppLinkKind.note,
          id: 'note_1',
          seq: 1,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('strategy_document_note_1')),
      findsNothing,
    );
    expect(find.byType(AppWorkbenchLayout), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('win rate reads as a percentage, never as a raw ratio', (
    WidgetTester tester,
  ) async {
    // Regression: `AppStrategy.winRate` is already 0..100, and a `* 100` in the
    // badge rendered "5840%" with an always-bullish intent. Anything over 100%
    // means that multiplication is back.
    await pumpAt(tester, const StrategiesScreen());

    final Iterable<Text> texts = tester.widgetList<Text>(find.byType(Text));
    final List<String> percents = <String>[
      for (final Text t in texts)
        if ((t.data ?? '').endsWith('%')) t.data!,
    ];
    expect(percents, isNotEmpty);
    for (final String raw in percents) {
      final double? value = double.tryParse(
        raw.substring(0, raw.length - 1).replaceAll('+', ''),
      );
      if (value == null) continue;
      expect(value.abs(), lessThanOrEqualTo(100));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop collapses internal left sidebar when in edit mode', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const StrategiesScreen());

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
