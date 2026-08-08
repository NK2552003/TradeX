import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class PortfolioCardsExampleView extends StatelessWidget {
  const PortfolioCardsExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppStatCard Portfolio Metrics', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppStatCard(
            stat: AppStat(
              label: 'Total Net P/L',
              value: 18450,
              formatter: (v) => '+\$$v',
              intentOverride: AppTrend.up,
            ),
          ),
        ],
      ),
    );
  }
}
