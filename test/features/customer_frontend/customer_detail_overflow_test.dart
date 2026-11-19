import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/settings_root_page.dart';
import 'package:alphajournal/features/calculators/ui/black_scholes_screen.dart';
import 'package:alphajournal/features/calculators/ui/brokerage_screen.dart';
import 'package:alphajournal/features/calculators/ui/cagr_screen.dart';
import 'package:alphajournal/features/calculators/ui/contract_value_screen.dart';
import 'package:alphajournal/features/calculators/ui/currency_screen.dart';
import 'package:alphajournal/features/calculators/ui/emi_screen.dart';
import 'package:alphajournal/features/calculators/ui/fd_screen.dart';
import 'package:alphajournal/features/calculators/ui/fibonacci_screen.dart';
import 'package:alphajournal/features/calculators/ui/inflation_screen.dart';
import 'package:alphajournal/features/calculators/ui/ltcg_screen.dart';
import 'package:alphajournal/features/calculators/ui/lumpsum_screen.dart';
import 'package:alphajournal/features/calculators/ui/margin_screen.dart';
import 'package:alphajournal/features/calculators/ui/options_pnl_screen.dart';
import 'package:alphajournal/features/calculators/ui/pip_value_screen.dart';
import 'package:alphajournal/features/calculators/ui/pivot_points_screen.dart';
import 'package:alphajournal/features/calculators/ui/pnl_screen.dart';
import 'package:alphajournal/features/calculators/ui/position_size_screen.dart';
import 'package:alphajournal/features/calculators/ui/ppf_screen.dart';
import 'package:alphajournal/features/calculators/ui/risk_reward_screen.dart';
import 'package:alphajournal/features/calculators/ui/sip_screen.dart';
import 'package:alphajournal/features/calculators/ui/stcg_screen.dart';
import 'package:alphajournal/features/calculators/ui/turnover_screen.dart';

void main() {
  final pages = <String, Widget Function()>{
    'black_scholes_screen': () => const BlackScholesCalculatorScreen(),
    'brokerage_screen': () => const BrokerageCalculatorScreen(),
    'cagr_screen': () => const CagrCalculatorScreen(),
    'contract_value_screen': () => const ContractValueCalculatorScreen(),
    'currency_screen': () => const CurrencyCalculatorScreen(),
    'emi_screen': () => const EmiCalculatorScreen(),
    'fd_screen': () => const FdCalculatorScreen(),
    'fibonacci_screen': () => const FibonacciCalculatorScreen(),
    'inflation_screen': () => const InflationCalculatorScreen(),
    'ltcg_screen': () => const LtcgCalculatorScreen(),
    'lumpsum_screen': () => const LumpsumCalculatorScreen(),
    'margin_screen': () => const MarginCalculatorScreen(),
    'options_pnl_screen': () => const OptionsPnlCalculatorScreen(),
    'pip_value_screen': () => const PipValueCalculatorScreen(),
    'pivot_points_screen': () => const PivotPointsCalculatorScreen(),
    'pnl_screen': () => const PnlCalculatorScreen(),
    'position_size_screen': () => const PositionSizeCalculatorScreen(),
    'ppf_screen': () => const PpfCalculatorScreen(),
    'risk_reward_screen': () => const RiskRewardCalculatorScreen(),
    'sip_screen': () => const SipCalculatorScreen(),
    'stcg_screen': () => const StcgCalculatorScreen(),
    'turnover_screen': () => const TurnoverCalculatorScreen(),
    for (final section in [
      'profile',
      'security',
      'affiliate_perks',
      'notifications',
      'privacy',
      'appearance',
      'trading',
      'billing',
      'help',
    ])
      'settings-$section': () => SettingsRootPage(initialSectionId: section),
  };
  for (final (width, height, scale) in [
    (320.0, 844.0, 1.0),
    (390.0, 844.0, 1.5),
    (740.0, 320.0, 1.0),
  ]) {
    for (final entry in pages.entries) {
      testWidgets('${entry.key} fits $width × $height at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previousError = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          previousError?.call(details);
        };
        addTearDown(() => FlutterError.onError = previousError);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: AppThemeScope(
              controller: AppThemeController(ThemeMode.dark),
              child: Scaffold(body: entry.value()),
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
