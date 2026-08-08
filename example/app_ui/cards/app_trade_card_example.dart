import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppTradeCardExampleView extends StatelessWidget {
  const AppTradeCardExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppTradeCard Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppTradeCard(trade: AppTrade(id: 't1', ticker: 'NVDA', side: AppSide.long, entry: 120, exit: 135, pnl: 1500, openedAt: DateTime.now())),
        ],
      ),
    );
  }
}
