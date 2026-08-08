import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

void main() {
  Widget buildTestable(Widget child) {
    final UiTheme theme = UiTheme.dark();
    return MaterialApp(
      theme: theme.toThemeData(),
      home: UiApp(
        theme: theme,
        builder: (BuildContext context) => Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('App UI Cards & Blocks Tests', () {
    final mockTrade = AppTrade(
      id: 't1',
      ticker: 'NVDA',
      side: AppSide.long,
      entry: 120.50,
      exit: 135.00,
      pnl: 1450.00,
      pnlPercent: 12.03,
      openedAt: DateTime.now().subtract(const Duration(days: 2)),
    );

    final mockPlan = AppPlan(
      tier: AppTier.premium,
      priceLabel: '\$29',
      features: ['Unlimited trades', 'AI insights'],
      highlighted: true,
    );

    testWidgets('AppTradeCard renders ticker and PnL', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          AppTradeCard(trade: mockTrade),
        ),
      );

      expect(find.text('NVDA'), findsOneWidget);
      expect(find.text('+12.03%'), findsOneWidget);
    });

    testWidgets('AppPlanCard renders plan priceLabel', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          AppPlanCard(plan: mockPlan),
        ),
      );

      expect(find.text('\$29'), findsOneWidget);
    });

    testWidgets('AppLogo wordmark renders app branding', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          const AppLogo(),
        ),
      );

      expect(find.byType(AppLogo), findsOneWidget);
    });

    testWidgets('AppFadeIn animation renders child widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestable(
          const AppFadeIn(
            child: Text('Animated Entrance'),
          ),
        ),
      );

      expect(find.text('Animated Entrance'), findsOneWidget);
    });
  });
}
