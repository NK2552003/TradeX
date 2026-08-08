import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppSettingsSectionBlockExampleView extends StatelessWidget {
  const AppSettingsSectionBlockExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppSettingsSectionBlock Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCard(title: 'AppSettingsSectionBlock', child: Text('Settings Block')),
        ],
      ),
    );
  }
}
