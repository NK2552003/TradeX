import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppStrategyCardExampleView extends StatelessWidget {
  const AppStrategyCardExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppStrategyCard Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const AppStrategyCard(strategy: AppStrategy(id: 's1', name: 'Morning Breakout', winRate: 0.72)),
        ],
      ),
    );
  }
}
