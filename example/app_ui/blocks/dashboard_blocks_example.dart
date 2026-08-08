import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class DashboardBlocksExampleView extends StatelessWidget {
  const DashboardBlocksExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppStatGridBlock Example', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppStatGridBlock(
            stats: <AppStat>[
              AppStat(label: 'Total P/L', value: 18450, formatter: (v) => '+\$$v', intentOverride: AppTrend.up),
              AppStat(label: 'Win Rate', value: 72.5, formatter: (v) => '$v%', intentOverride: AppTrend.up),
            ],
          ),
        ],
      ),
    );
  }
}
