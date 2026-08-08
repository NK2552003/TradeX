import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class ChartBlocksExampleView extends StatelessWidget {
  const ChartBlocksExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppPriceChartBlock Example', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppPriceChartBlock(
            candles: <AppCandle>[
              AppCandle(time: DateTime.now().subtract(const Duration(days: 2)), open: 120, high: 125, low: 119, close: 124),
              AppCandle(time: DateTime.now().subtract(const Duration(days: 1)), open: 124, high: 130, low: 123, close: 129),
            ],
          ),
        ],
      ),
    );
  }
}
