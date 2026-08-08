import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class ProgressExampleView extends StatelessWidget {
  const ProgressExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiProgressBar & UiProgressCircle', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiProgressBar(value: 0.72, label: 'Monthly Trading Profit Target'),
          SizedBox(height: context.sp(theme.spacing.lg)),
          const UiProgressCircle(value: 0.84),
        ],
      ),
    );
  }
}
