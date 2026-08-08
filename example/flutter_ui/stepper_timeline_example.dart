import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class StepperTimelineExampleView extends StatefulWidget {
  const StepperTimelineExampleView({super.key});

  @override
  State<StepperTimelineExampleView> createState() => _StepperTimelineExampleViewState();
}

class _StepperTimelineExampleViewState extends State<StepperTimelineExampleView> {
  int _step = 1;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiStepper & UiTimeline', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiStepper(
            steps: const <UiStepperStep>[
              UiStepperStep(title: 'Identify Setup', subtitle: 'Breakout above \$130 resistance'),
              UiStepperStep(title: 'Calculate Position Sizing', subtitle: 'Risk capped at \$500'),
              UiStepperStep(title: 'Execute Order', subtitle: 'Limit order filled @ \$130.50'),
            ],
            currentIndex: _step,
            onStepTap: (i) => setState(() => _step = i),
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          const UiTimeline(
            entries: <UiTimelineEntry>[
              UiTimelineEntry(
                title: 'Order Placed',
                subtitle: 'Limit order to BUY 100 NVDA @ \$130.00',
                intent: UiIntent.info,
              ),
              UiTimelineEntry(
                title: 'Order Filled',
                subtitle: 'Execution complete at \$130.00',
                intent: UiIntent.bullish,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
