import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AiCardsExampleView extends StatelessWidget {
  const AiCardsExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppAiInsightCard Example', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const AppAiInsightCard(
            insight: AppAiInsight(
              id: 'ai1',
              title: 'FOMC Risk Warning',
              body: 'High volatility expected during upcoming interest rate decision. Capping leverage recommended.',
            ),
          ),
        ],
      ),
    );
  }
}
