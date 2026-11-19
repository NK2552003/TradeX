import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/market_data/presentation/market_world_indices_card.dart';

void main() {
  testWidgets('World Indices and Assets each use one consolidated table', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark().toThemeData(),
        home: const Scaffold(
          body: SingleChildScrollView(child: MarketWorldIndicesCard()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('World Indices'), findsOneWidget);
    expect(find.text('Assets'), findsOneWidget);
    expect(
      find.byWidgetPredicate((Widget widget) => widget is UiTable),
      findsNWidgets(2),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
