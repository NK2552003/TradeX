import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

void main() {
  testWidgets('UiCalendar toggles Apple Crown wheel picker on header tap', (
    WidgetTester tester,
  ) async {
    DateTime? selectedDate;
    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: Scaffold(
            body: UiCalendar(
              selected: DateTime(2026, 8, 21),
              firstDate: DateTime(1940),
              lastDate: DateTime(2030),
              onDateSelected: (DateTime d) => selectedDate = d,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Initial state shows month grid with weekdays
    expect(find.text('August 2026'), findsOneWidget);
    expect(find.text('Mo'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.byType(ListWheelScrollView), findsNothing);

    // 2. Tap header to open Apple Crown wheel picker
    await tester.tap(find.text('August 2026'));
    await tester.pumpAndSettle();

    // 3. Apple Crown wheels are now displayed
    expect(find.byType(ListWheelScrollView), findsNWidgets(2));
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);

    // 4. Tap Done to return to calendar grid
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(ListWheelScrollView), findsNothing);
    expect(find.text('Mo'), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(selectedDate, DateTime(2026, 8, 15));
  });

  testWidgets('UiDatePicker opens compact bottom-aligned overlay', (
    WidgetTester tester,
  ) async {
    DateTime? pickedDate;
    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: UiDatePicker(
                value: DateTime(2026, 8, 21),
                firstDate: DateTime(1940),
                lastDate: DateTime(2030),
                onChanged: (DateTime d) => pickedDate = d,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap to open picker sheet
    await tester.tap(find.byType(UiDatePicker));
    await tester.pumpAndSettle();

    expect(find.byType(UiCalendar), findsOneWidget);
    expect(find.text('August 2026'), findsOneWidget);

    // Tap day 15
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    expect(pickedDate, DateTime(2026, 8, 15));
  });
}
