import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppTraderCardExampleView extends StatelessWidget {
  const AppTraderCardExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppTraderCard Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const AppTraderCard(trader: AppTrader(id: 'u1', handle: '@nitish', displayName: 'Nitish Kumar')),
        ],
      ),
    );
  }
}
