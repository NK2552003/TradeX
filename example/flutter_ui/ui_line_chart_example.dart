import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiLineChartExampleView extends StatelessWidget {
  const UiLineChartExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiLineChart Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiSparkChart(values: <double>[10, 20, 15, 30], height: 60),
        ],
      ),
    );
  }
}
