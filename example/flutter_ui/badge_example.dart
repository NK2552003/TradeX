import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class BadgeExampleView extends StatelessWidget {
  const BadgeExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiBadge - Status & Sentiment Badges', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              UiBadge(label: 'Bullish', intent: UiIntent.bullish),
              UiBadge(label: 'Bearish', intent: UiIntent.bearish),
              UiBadge(label: 'Neutral', intent: UiIntent.neutral),
              UiBadge(label: 'Warning', intent: UiIntent.warning),
              UiBadge(label: 'Primary', intent: UiIntent.primary),
            ],
          ),
        ],
      ),
    );
  }
}
