import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Examples showcasing all domain-specific App UI Cards.
class AppUiCardsExampleView extends StatelessWidget {
  const AppUiCardsExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    final mockTrade = AppTrade(
      id: 't1',
      ticker: 'AAPL',
      side: AppSide.long,
      entry: 215.00,
      exit: 228.40,
      pnl: 1340.00,
      pnlPercent: 6.23,
      openedAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    final mockStrategy = AppStrategy(
      id: 's1',
      name: 'Momentum Breakout 3.0',
      summary: 'High-volume breakout strategy focused on mega-cap tech stocks.',
      winRate: 0.72,
      netPnl: 48900.00,
      trades: 184,
    );

    final mockPlan = const AppPlan(
      tier: AppTier.premium,
      priceLabel: '\$29',
      features: <String>['Unlimited trades', 'AI insights', 'Webhook integrations'],
      highlighted: true,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Journal Trade Card', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppTradeCard(trade: mockTrade),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Strategy Performance Card', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppStrategyCard(strategy: mockStrategy),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Subscription Plan Card', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppPlanCard(plan: mockPlan),
        ],
      ),
    );
  }
}
