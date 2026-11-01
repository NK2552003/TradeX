import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/journal/ui/journal_screen.dart';
import 'package:tradex/features/journal/ui/journal_editor_screen.dart';
import 'package:tradex/features/strategies/ui/strategies_screen.dart';
import 'package:tradex/features/strategies/ui/strategy_editor_screen.dart';

void main() {
  testWidgets('tapping FAB and picking template opens editor', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: JournalScreen())),
    );
    await tester.pumpAndSettle();

    // Find FAB and tap it
    final fab = find.byTooltip('Log Trade');
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Dialog "Log a trade" should be visible
    expect(find.text('Log a trade'), findsOneWidget);
    expect(find.text('Blank entry'), findsOneWidget);

    // Tap "Blank entry"
    await tester.tap(find.text('Blank entry'));
    await tester.pumpAndSettle();

    // Is JournalEditorScreen visible?
    final editor = find.byType(JournalEditorScreen);
    expect(editor, findsOneWidget);
  });

  testWidgets('tapping FAB and picking strategy template opens strategy editor', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StrategiesScreen())),
    );
    await tester.pumpAndSettle();

    final fab = find.byTooltip('New playbook');
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(find.text('New playbook'), findsWidgets);
    expect(find.text('Blank playbook'), findsOneWidget);

    await tester.tap(find.text('Blank playbook'));
    await tester.pumpAndSettle();

    final editor = find.byType(StrategyEditorScreen);
    expect(editor, findsOneWidget);
  });
}
