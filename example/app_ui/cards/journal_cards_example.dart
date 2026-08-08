import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class JournalCardsExampleView extends StatelessWidget {
  const JournalCardsExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppTradeCard Example', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppTradeCard(
            trade: AppTrade(
              id: 't1',
              ticker: 'NVDA',
              side: AppSide.long,
              entry: 125.0,
              exit: 135.0,
              pnl: 1450.0,
              pnlPercent: 8.0,
              openedAt: DateTime.now(),
            ),
          ),
        ],
      ),
    );
  }
}
