import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AiBlocksExampleView extends StatelessWidget {
  const AiBlocksExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppAiInsightsBlock Example', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const AppAiInsightsBlock(
            insights: <AppAiInsight>[
              AppAiInsight(
                id: 'ai1',
                title: 'High Win Rate on NVDA',
                body: '78% win rate when buying breakout above 20 EMA on 15m timeframe.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
