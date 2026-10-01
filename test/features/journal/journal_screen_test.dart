import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/journal/ui/journal_screen.dart';

void main() {
  group('JournalScreen Dashboard Redesign', () {
    testWidgets('renders dashboard on desktop with 4 metric cards, header, and FAB', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JournalScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Entries heading
      expect(find.text('Entries'), findsOneWidget);

      // 4 Metric cards
      expect(find.text('MONTH NET REALIZED'), findsOneWidget);
      expect(find.textContaining('WIN RATE'), findsOneWidget);
      expect(find.text('PROFIT FACTOR'), findsOneWidget);
      expect(find.text('EXECUTION DISCIPLINE'), findsOneWidget);

      // Keyboard shortcut footer
      expect(find.textContaining('Press N to add trade'), findsOneWidget);
      expect(find.textContaining('Connected to Zerodha Kite Broker API'), findsOneWidget);

      // Floating bottom-right action button (icon only)
      expect(find.byKey(const ValueKey<String>('journal_dashboard_stack')), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsWidgets);

      // Outcome pills on left, dropdown buttons on right
      expect(find.textContaining('All ('), findsOneWidget);
      expect(find.text('Playbook: All'), findsOneWidget);
      expect(find.text('Asset: All'), findsOneWidget);
      final double allX = tester.getTopLeft(find.textContaining('All (')).dx;
      final double playbookX = tester.getTopLeft(find.text('Playbook: All')).dx;
      expect(playbookX, greaterThan(allX + 400));
    });

    testWidgets('renders responsive dashboard on mobile without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JournalScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Entries'), findsOneWidget);
      expect(find.text('MONTH NET REALIZED'), findsOneWidget);
      expect(find.text('PROFIT FACTOR'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sort_rounded), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify narrow 360px mobile width also renders cleanly without overflow
      tester.view.physicalSize = const Size(360, 780);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('switches between Cards Grid and Table view', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: JournalScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Table switch button
      final Finder tableBtn = find.byIcon(Icons.table_chart_outlined);
      expect(tableBtn, findsOneWidget);

      await tester.tap(tableBtn);
      await tester.pumpAndSettle();

      // Table headers should now be visible
      expect(find.text('Ticker'), findsOneWidget);
      expect(find.text('Title / Strategy'), findsOneWidget);
      expect(find.text('Side'), findsOneWidget);

      // Switch back to Cards view
      final Finder cardsBtn = find.byIcon(Icons.grid_view_rounded);
      expect(cardsBtn, findsOneWidget);
      await tester.tap(cardsBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
