import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppUsageBlockExampleView extends StatelessWidget {
  const AppUsageBlockExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppUsageBlock Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const AppUsageBlock(metrics: <AppUsageMetric>[AppUsageMetric(label: 'Trades', used: 142, limit: 500)]),
        ],
      ),
    );
  }
}
