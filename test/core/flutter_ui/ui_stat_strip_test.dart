import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

Widget _host(Widget child) => UiApp(
      theme: UiTheme.dark(),
      builder: (BuildContext context) =>
          MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('UiStatStrip auto-fills trailing cells in proper ratio with colspan',
      (WidgetTester tester) async {
    final stats = <UiStat>[
      const UiStat(label: 'Risk / Share', value: '₹25.00'),
      const UiStat(label: 'Reward / Share', value: '₹50.00'),
      const UiStat(label: 'Breakeven Rate', value: '33.3%'),
      const UiStat(label: 'Edge', value: '+1.5R'),
      const UiStat(label: 'Expectancy', value: '₹1,250'),
      const UiStat(label: 'Per Month', value: '₹25,000'),
    ];

    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 800,
          child: UiStatStrip(stats: stats, columns: 4),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 6 labels are displayed
    expect(find.text('RISK / SHARE'), findsOneWidget);
    expect(find.text('REWARD / SHARE'), findsOneWidget);
    expect(find.text('BREAKEVEN RATE'), findsOneWidget);
    expect(find.text('EDGE'), findsOneWidget);
    expect(find.text('EXPECTANCY'), findsOneWidget);
    expect(find.text('PER MONTH'), findsOneWidget);

    // Verify there are exactly 2 rows
    final statStripFinder = find.byType(UiStatStrip);
    final stripRows = find.descendant(
      of: statStripFinder,
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is Row && w.crossAxisAlignment == CrossAxisAlignment.stretch,
      ),
    );
    expect(stripRows, findsNWidgets(2));

    // First row should have exactly 4 Expanded children with flex 1
    final Row row0 = tester.widget<Row>(stripRows.at(0));
    expect(row0.children.length, 4);
    for (final Widget child in row0.children) {
      expect(child, isA<Expanded>());
      expect((child as Expanded).flex, 1);
    }

    // Second row should have exactly 2 Expanded children with flex 2 (auto-fill colspan)
    final Row row1 = tester.widget<Row>(stripRows.at(1));
    expect(row1.children.length, 2);
    for (final Widget child in row1.children) {
      expect(child, isA<Expanded>());
      expect((child as Expanded).flex, 2);
    }

    // Verify widths of Row 1 items: each should take 50% of the 800px width (400px each)
    final row1Expanded = find.descendant(
      of: stripRows.at(1),
      matching: find.byWidgetPredicate((w) => w is Expanded && w.flex == 2),
    );
    expect(row1Expanded, findsNWidgets(2));
    final size0 = tester.getSize(row1Expanded.at(0));
    final size1 = tester.getSize(row1Expanded.at(1));
    expect(size0.width, 400.0);
    expect(size1.width, 400.0);

    // Verify no empty SizedBox.shrink() placeholder boxes in Row 1
    final emptyBoxes = find.descendant(
      of: stripRows.at(1),
      matching: find.byWidget(const SizedBox.shrink()),
    );
    expect(emptyBoxes, findsNothing);
  });

  testWidgets('UiStatStrip respects explicit colSpan property',
      (WidgetTester tester) async {
    final stats = <UiStat>[
      const UiStat(label: 'Metric A', value: '10', colSpan: 2),
      const UiStat(label: 'Metric B', value: '20', colSpan: 2),
      const UiStat(label: 'Metric C', value: '30', colSpan: 4),
    ];

    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 800,
          child: UiStatStrip(stats: stats, columns: 4),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final statStripFinder = find.byType(UiStatStrip);
    final stripRows = find.descendant(
      of: statStripFinder,
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is Row && w.crossAxisAlignment == CrossAxisAlignment.stretch,
      ),
    );
    expect(stripRows, findsNWidgets(2));

    // Row 0 has 2 items with flex 2
    final Row row0 = tester.widget<Row>(stripRows.at(0));
    expect(row0.children.length, 2);
    expect((row0.children[0] as Expanded).flex, 2);
    expect((row0.children[1] as Expanded).flex, 2);

    // Row 1 has 1 item with flex 4
    final Row row1 = tester.widget<Row>(stripRows.at(1));
    expect(row1.children.length, 1);
    expect((row1.children[0] as Expanded).flex, 4);
  });
}
