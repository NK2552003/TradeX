import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiStepperExampleView extends StatelessWidget {
  const UiStepperExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiStepper Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiStepper(steps: const <UiStepperStep>[UiStepperStep(title: 'Step 1', subtitle: 'Setup')], currentIndex: 0),
        ],
      ),
    );
  }
}
