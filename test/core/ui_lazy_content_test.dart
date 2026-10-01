import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

void main() {
  testWidgets('deferred sections build only near their viewport', (
    tester,
  ) async {
    var builds = 0;
    final anchor = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 2000),
                UiDeferred(
                  key: anchor,
                  builder: (_) {
                    builds++;
                    return const SizedBox(
                      height: 200,
                      child: Text('Loaded section'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(builds, 0);
    await tester.ensureVisible(find.byKey(anchor));
    await tester.pump();
    await tester.pump();
    expect(builds, 1);
    expect(find.text('Loaded section'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('lazy lists reveal batches while building visible rows', (
    tester,
  ) async {
    final built = <int>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UiLazyList(
            itemCount: 1000,
            itemBuilder: (_, i) {
              built.add(i);
              return SizedBox(height: 60, child: Text('Record $i'));
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(built.every((i) => i < 20), isTrue);
    expect(find.text('Record 999'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Record 40'),
      400,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();
    expect(find.text('Record 40'), findsOneWidget);
    expect(built.length, lessThan(100));
    expect(tester.takeException(), isNull);
  });
}
