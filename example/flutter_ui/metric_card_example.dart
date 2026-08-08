import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class MetricCardExampleView extends StatelessWidget {
  const MetricCardExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiMetricCard - KPI Portfolio Metrics', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: <Widget>[
              const Expanded(
                child: UiMetricCard(
                  label: 'Monthly Net P/L',
                  value: '+\$18,450.00',
                  delta: 22.4,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              const Expanded(
                child: UiMetricCard(
                  label: 'Win Rate',
                  value: '72.5%',
                  delta: 4.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
