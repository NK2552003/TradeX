import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/workspace/ui/workspace_screen.dart';

void main() {
  testWidgets('mobile workspace filters fill the content width evenly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkspaceScreen(onOpenFeature: (_) {})),
      ),
    );
    await tester.pumpAndSettle();

    final Finder filters = find.byType(UiToggleGroup<String>);
    expect(filters, findsNWidgets(3));

    final List<double> widths = <double>[
      for (int index = 0; index < 3; index++)
        tester.getSize(filters.at(index)).width,
    ];
    expect(widths.every((double width) => width >= 280), isTrue);
    expect(widths.toSet().length, 1);

    final Finder strategyButtons = find.descendant(
      of: filters.at(2),
      matching: find.byType(UiInteractive),
    );
    expect(strategyButtons, findsNWidgets(5));
    final List<double> buttonWidths = <double>[
      for (int index = 0; index < 5; index++)
        tester.getSize(strategyButtons.at(index)).width,
    ];
    expect(
      buttonWidths.reduce((double a, double b) => a > b ? a : b) -
          buttonWidths.reduce((double a, double b) => a < b ? a : b),
      lessThan(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'workspace skill shortcut opens the catalog and returns a command',
    (tester) async {
      String? command;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkspaceScreen(
              onOpenFeature: (_) {},
              onOpenTraderSkill: (skill) => command = skill.command,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Trader skills'));
      await tester.tap(find.text('Trader skills'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('/trader-tax'));
      await tester.tap(find.text('/trader-tax'));
      await tester.pumpAndSettle();
      expect(command, '/trader-tax');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('workspace restores calendar mode and filters after leaving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    WorkspaceViewState? saved;
    Widget workspace({WorkspaceViewState? viewState}) => MaterialApp(
      home: Scaffold(
        body: WorkspaceScreen(
          viewState: viewState,
          onViewStateChanged: (state) => saved = state,
          onOpenFeature: (_) {},
          searchQuery: 'review',
        ),
      ),
    );
    await tester.pumpWidget(workspace());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(saved, isNotNull);
    expect(saved!.isMonthView, isTrue);
    final snapshot = saved!;
    await tester.pumpWidget(workspace(viewState: snapshot));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(saved!.isMonthView, isTrue);
    expect(saved!.selectedDay, snapshot.selectedDay);
    expect(saved!.notesFilter, snapshot.notesFilter);
  });
}
