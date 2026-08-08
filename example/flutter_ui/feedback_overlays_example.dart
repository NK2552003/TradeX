import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Examples for Feedback & Overlays (Dialog, Drawer, Popover, Tooltip, Toast, Skeleton, EmptyState).
class FeedbackOverlaysExampleView extends StatelessWidget {
  const FeedbackOverlaysExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Empty State Placeholder', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCard(
            child: UiEmptyState(
              title: 'No Active Trades',
              message: 'You have no open positions in your journal for this trading session.',
              icon: Icons.assignment_outlined,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Skeleton Loading Indicators', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              UiSkeleton(width: 180, height: 24),
              SizedBox(height: 8),
              UiSkeleton(width: 320, height: 16),
              SizedBox(height: 8),
              UiSkeleton(width: 240, height: 16),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Dialog & Modal Triggers', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          Wrap(
            spacing: 12,
            children: <Widget>[
              UiButton(
                label: 'Open Confirmation Dialog',
                variant: UiVariant.outline,
                onPressed: () {
                  UiDialog.confirm(
                    context,
                    title: 'Confirm Order Cancellation',
                    description: 'Are you sure you want to cancel open order #84920 for NVDA?',
                    confirmLabel: 'Cancel Order',
                    confirmVariant: UiVariant.destructive,
                  );
                },
              ),
              UiButton(
                label: 'Open Drawer Panel',
                variant: UiVariant.secondary,
                onPressed: () {
                  UiDrawer.show(
                    context,
                    title: 'Trade Details & Analytics',
                    child: Padding(
                      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                      child: const Text('Detailed trade analytics, execution timestamps, and risk breakdown.'),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
