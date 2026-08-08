import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Examples showcasing domain-specific App UI Blocks.
class AppUiBlocksExampleView extends StatelessWidget {
  const AppUiBlocksExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Dashboard Stat Grid Block', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppStatGridBlock(
            stats: <AppStat>[
              AppStat(label: 'Total P/L', value: 24890.00, formatter: (v) => '+\$$v'),
              AppStat(label: 'Win Rate', value: 71.2, formatter: (v) => '$v%'),
              const AppStat(label: 'Sharpe Ratio', value: 2.45),
              const AppStat(label: 'Open Positions', value: 4),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Subscription Limit Block', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppUsageBlock(
            metrics: const <AppUsageMetric>[
              AppUsageMetric(
                label: 'Monthly Trade Logs',
                used: 840,
                limit: 1000,
              ),
            ],
            onUpgrade: () {},
          ),
        ],
      ),
    );
  }
}
