import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppPlanCardExampleView extends StatelessWidget {
  const AppPlanCardExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppPlanCard Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const AppPlanCard(plan: AppPlan(tier: AppTier.premium, priceLabel: '\$29', features: <String>['AI Insights'])),
        ],
      ),
    );
  }
}
