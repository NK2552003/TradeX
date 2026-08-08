import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class PopoverTooltipToastExampleView extends StatelessWidget {
  const PopoverTooltipToastExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiTooltip, UiPopover & UiToast', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiTooltip(
            message: 'Risk calculated per account equity',
            child: const Text('Hover or tap for tooltip info'),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiButton(
            label: 'Trigger Toast Notification',
            variant: UiVariant.outline,
            onPressed: () {
              UiToast.show(
                context,
                title: 'Order Executed',
                message: 'BUY 100 NVDA @ \$135.00 filled successfully.',
                intent: UiIntent.bullish,
              );
            },
          ),
        ],
      ),
    );
  }
}
