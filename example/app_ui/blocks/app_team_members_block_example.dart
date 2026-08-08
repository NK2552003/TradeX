import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppTeamMembersBlockExampleView extends StatelessWidget {
  const AppTeamMembersBlockExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppTeamMembersBlock Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const AppUsageBlock(metrics: <AppUsageMetric>[AppUsageMetric(label: 'Team Seats', used: 4, limit: 10)]),
        ],
      ),
    );
  }
}
