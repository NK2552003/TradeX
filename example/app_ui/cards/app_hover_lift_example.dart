import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppHoverLiftExampleView extends StatelessWidget {
  const AppHoverLiftExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppHoverLift Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const AppHoverLift(child: Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Hover Lift')))),
        ],
      ),
    );
  }
}
