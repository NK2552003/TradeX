import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiCandleChartExampleView extends StatelessWidget {
  const UiCandleChartExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiCandleChart Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiCandleChart(height: 140, candles: <UiCandle>[UiCandle(time: DateTime.now(), open: 120, high: 126, low: 119, close: 125)]),
        ],
      ),
    );
  }
}
