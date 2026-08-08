import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppOnboardingBlockExampleView extends StatelessWidget {
  const AppOnboardingBlockExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppOnboardingBlock Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCard(title: 'AppOnboardingBlock', child: Text('Onboarding Block')),
        ],
      ),
    );
  }
}
