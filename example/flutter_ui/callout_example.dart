import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class CalloutExampleView extends StatelessWidget {
  const CalloutExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiCallout - Banner Alerts', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCallout(
            title: 'Market Hours Alert',
            message: 'US Equities market opens in 45 minutes. Ensure open orders are reviewed.',
            intent: UiIntent.info,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCallout(
            title: 'High Volatility Warning',
            message: 'FOMC interest rate decision scheduled for 2:00 PM EST today.',
            intent: UiIntent.warning,
          ),
        ],
      ),
    );
  }
}
