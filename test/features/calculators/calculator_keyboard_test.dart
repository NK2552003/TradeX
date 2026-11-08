import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/calculators/ui/calculators_screen.dart';
import 'package:tradex/features/calculators/ui/options_pnl_screen.dart';

void main() {
  testWidgets('More-dock calculator preserves selection and input when the keyboard opens', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(theme: UiTheme.dark().toThemeData(), home: Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppShell(sections: const [], selectedId: 'calculators', onSelect: (_) {},
        mobilePrimaryItems: const [AppNavItem(id: 'overview', label: 'Home', icon: Icons.home_outlined),
          AppNavItem(id: 'market', label: 'Market', icon: Icons.show_chart)],
        mobileMoreItems: const [AppNavItem(id: 'calculators', label: 'Calculators', icon: Icons.calculate_outlined)],
        child: const CalculatorsScreen()),
    )));
    await tester.pumpAndSettle();
    final search = find.byWidgetPredicate((w) => w is UiInput && w.hintText?.toLowerCase().contains('search') == true).last;
    await tester.enterText(find.descendant(of: search, matching: find.byType(TextField)), 'Options P&L');
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((w) => w is AppCalculatorNavItem && w.meta.id == 'options_pnl'));
    await tester.pumpAndSettle();
    expect(find.byType(OptionsPnlCalculatorScreen), findsOneWidget);
    final original = tester.state(find.byType(OptionsPnlCalculatorScreen));
    final field = find.byWidgetPredicate((w) => w is AppCalcNumberField && w.label == 'Premium');
    await tester.ensureVisible(field);
    final input = find.descendant(of: field, matching: find.byType(TextField));
    await tester.enterText(input, '175');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.byType(OptionsPnlCalculatorScreen), findsOneWidget);
    expect(tester.state(find.byType(OptionsPnlCalculatorScreen)), same(original));
    expect(tester.widget<AppCalcNumberField>(field).value, 175);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(OptionsPnlCalculatorScreen)), same(original));
    expect(tester.widget<AppCalcNumberField>(field).value, 175);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
