import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class TrackerTypingExampleView extends StatelessWidget {
  const TrackerTypingExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiTracker & UiTypingIndicator', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiTracker(
            blocks: <UiTrackerBlock>[
              UiTrackerBlock(intent: UiIntent.bullish),
              UiTrackerBlock(intent: UiIntent.bullish),
              UiTrackerBlock(intent: UiIntent.bearish),
              UiTrackerBlock(intent: UiIntent.bullish),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          const UiTypingIndicator(),
        ],
      ),
    );
  }
}
