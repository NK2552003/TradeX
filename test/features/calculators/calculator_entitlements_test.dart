import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/data/app_session.dart';
import 'package:alphajournal/features/calculators/ui/black_scholes_screen.dart';
import 'package:alphajournal/features/calculators/ui/calculators_screen.dart';

void main() {
  testWidgets('Free shows advanced calculators as locked', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppSession.instance.changeTier(AppTier.free);
    addTearDown(() => AppSession.instance.changeTier(AppTier.premium));

    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark().toThemeData(),
        home: const Scaffold(body: CalculatorsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final lockedTool = find.byWidgetPredicate(
      (widget) =>
          widget is AppCalculatorNavItem && widget.meta.id == 'black_scholes',
    );
    await tester.ensureVisible(lockedTool);
    final tile = tester.widget<AppCalculatorNavItem>(lockedTool);
    expect(tile.enabled, isFalse);
    expect(tile.disabledLabel, 'Basic');

    await tester.tap(lockedTool);
    await tester.pumpAndSettle();

    expect(find.byType(BlackScholesCalculatorScreen), findsNothing);
    expect(find.text('Advanced calculators · Basic or Pro'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
