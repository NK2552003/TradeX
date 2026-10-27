import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

void main() {
  testWidgets('page selection retains selections on other pages', (
    tester,
  ) async {
    Set<int> selected = {3};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => UiTable<int>(
              rows: const [1, 2, 3, 4],
              pageSize: 2,
              selectable: true,
              selectedRows: selected,
              onSelectionChanged: (value) => setState(() => selected = value),
              columns: [
                UiTableColumn(
                  header: 'Account',
                  cell: (_, row) => Text('$row'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(UiCheckbox).first);
    await tester.pump();
    expect(selected, {1, 2, 3});
    await tester.tap(find.byType(UiCheckbox).first);
    await tester.pump();
    expect(selected, {3});
    expect(tester.takeException(), isNull);
  });

  testWidgets('key value headers align and narrow records retain full values', (
    tester,
  ) async {
    const fullValue = 'partner-with-a-long-settlement-address@example.com';
    Widget table(double width) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: const UiKeyValueTable(
              labelHeader: 'Destination',
              valueHeader: 'Address',
              trailingHeader: 'Status',
              valueWidth: 240,
              rows: [
                UiKeyValueRow(
                  label: 'Payout email',
                  value: fullValue,
                  trailing: 'Verified',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(table(780));
    expect(
      tester.getRect(find.text('ADDRESS')).right,
      closeTo(tester.getRect(find.text(fullValue)).right, 0.1),
    );
    expect(
      tester.getRect(find.text('STATUS')).right,
      closeTo(tester.getRect(find.text('Verified')).right, 0.1),
    );
    await tester.pumpWidget(table(300));
    final value = tester.widget<Text>(find.text(fullValue));
    expect(value.maxLines, isNull);
    expect(value.overflow, isNot(TextOverflow.ellipsis));
    expect(
      tester.getRect(find.text(fullValue)).top,
      greaterThanOrEqualTo(tester.getRect(find.text('Payout email')).bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dense table gives adjacent values a readable gutter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UiTable<int>(
            rows: const [1],
            columns: [
              UiTableColumn(
                header: 'Account',
                cell: (_, row) => const SizedBox(
                  key: ValueKey('account'),
                  width: double.infinity,
                  height: 24,
                ),
              ),
              UiTableColumn(
                header: 'Commission',
                cell: (_, row) => const SizedBox(
                  key: ValueKey('commission'),
                  width: double.infinity,
                  height: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final account = tester.getRect(find.byKey(const ValueKey('account')));
    final commission = tester.getRect(find.byKey(const ValueKey('commission')));
    expect(commission.left - account.right, greaterThanOrEqualTo(12));
  });

  testWidgets(
    'narrow desktop pane stacks fields and keeps row expansion and selection',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Set<int> selected = {};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: StatefulBuilder(
                  builder: (context, setState) => UiTable<int>(
                    rows: const [1],
                    stackOnMobile: true,
                    selectable: true,
                    selectedRows: selected,
                    onSelectionChanged: (value) =>
                        setState(() => selected = value),
                    expandableWhen: (_) => true,
                    expandedBuilder: (_, row) => const Text('Review history'),
                    columns: [
                      UiTableColumn(
                        header: 'Partner',
                        cell: (_, row) => const Text(
                          'Long partner name',
                          key: ValueKey('partner-value'),
                        ),
                      ),
                      UiTableColumn(
                        header: 'Settlement destination',
                        cell: (_, row) => const Text('partner@bank'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final label = tester.getRect(find.text('Partner'));
      final value = tester.getRect(find.byKey(const ValueKey('partner-value')));
      expect(value.top, greaterThanOrEqualTo(label.bottom));
      await tester.tap(find.byType(UiCheckbox).last);
      await tester.pump();
      expect(selected, {1});
      await tester.tap(find.byTooltip('Expand row'));
      await tester.pump();
      expect(find.text('Review history'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
