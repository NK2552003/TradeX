import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiDonutChartExampleView extends StatelessWidget {
  const UiDonutChartExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiDonutChart Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          SizedBox(height: 120, child: UiDonutChart(slices: const <UiDonutSlice>[UiDonutSlice(label: 'Tech', value: 60, color: Colors.blue)])),
        ],
      ),
    );
  }
}
