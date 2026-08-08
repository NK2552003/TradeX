import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppStrategyVersionCardExampleView extends StatelessWidget {
  const AppStrategyVersionCardExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppStrategyVersionCard Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCard(title: 'AppStrategyVersionCard', child: Text('Version Details')),
        ],
      ),
    );
  }
}
