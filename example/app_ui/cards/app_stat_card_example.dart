import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppStatCardExampleView extends StatelessWidget {
  const AppStatCardExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppStatCard Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppStatCard(stat: AppStat(label: 'Total P/L', value: 14250, formatter: (v) => '+\$$v')),
        ],
      ),
    );
  }
}
