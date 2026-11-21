import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
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

  testWidgets(
    'mobile workspace hides customer plan banner and shows 2x2 quick-link grid below calendar',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkspaceScreen(
              onOpenFeature: (_) {},
              onOpenTraderSkill: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Customer plan banner must be hidden on mobile workspace.
      expect(find.byType(CustomerLimitationsBanner), findsNothing);
      expect(find.text('Customer Plan & Workspace Allowances'), findsNothing);

      // Quick-link cards below the calendar must form a 2x2 grid on mobile.
      final Finder quickStrip = find.byType(AppQuickLinkStrip);
      expect(quickStrip, findsOneWidget);
      final Finder cells = find.descendant(
        of: quickStrip,
        matching: find.byType(UiInteractive),
      );
      expect(cells, findsNWidgets(4));

      final Rect notesRect = tester.getRect(cells.at(0));
      final Rect journalRect = tester.getRect(cells.at(1));
      final Rect strategiesRect = tester.getRect(cells.at(2));
      final Rect skillsRect = tester.getRect(cells.at(3));

      // Row 1: Notes and Journal side by side with matching height and width.
      expect(notesRect.top, closeTo(journalRect.top, 0.5));
      expect(notesRect.height, closeTo(journalRect.height, 0.5));
      expect(notesRect.width, closeTo(journalRect.width, 1.0));
      expect(journalRect.left, greaterThan(notesRect.left));

      // Row 2: Strategies and Trader skills directly below Row 1.
      expect(strategiesRect.top, greaterThan(notesRect.top));
      expect(strategiesRect.top, closeTo(skillsRect.top, 0.5));
      expect(strategiesRect.height, closeTo(skillsRect.height, 0.5));
      expect(strategiesRect.width, closeTo(skillsRect.width, 1.0));
      expect(skillsRect.left, greaterThan(strategiesRect.left));
      expect(notesRect.left, closeTo(strategiesRect.left, 1.0));
      expect(journalRect.left, closeTo(skillsRect.left, 1.0));
      expect(notesRect.height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop workspace keeps customer plan banner and 4-column quick-link strip',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkspaceScreen(
              onOpenFeature: (_) {},
              onOpenTraderSkill: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomerLimitationsBanner), findsOneWidget);

      final Finder cells = find.descendant(
        of: find.byType(AppQuickLinkStrip),
        matching: find.byType(UiInteractive),
      );
      expect(cells, findsNWidgets(4));
      final double firstTop = tester.getRect(cells.at(0)).top;
      for (int i = 1; i < 4; i++) {
        expect(tester.getRect(cells.at(i)).top, closeTo(firstTop, 0.5));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
