import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    final notifications = [
      {
        'title': 'Price Alert Triggered: RELIANCE',
        'body': 'RELIANCE crossed above your threshold of ₹2,950.00 (+2.8% today).',
        'category': 'Market Alert',
        'time': '12m ago',
        'intent': UiIntent.bullish,
      },
      {
        'title': 'Direct Message Received',
        'body': 'Ava Chen (@quantqueen) sent you a new direct message.',
        'category': 'Community',
        'time': '45m ago',
        'intent': UiIntent.primary,
      },
      {
        'title': 'AI Journal Summary Ready',
        'body': 'Weekly trading performance narrative and psychology review has been generated.',
        'category': 'AI Insights',
        'time': '3h ago',
        'intent': UiIntent.success,
      },
      {
        'title': 'Affiliate Bonus Credit Awarded',
        'body': 'You earned ₹500.00 affiliate bonus credit for user signup via REF-TRADEX-2026.',
        'category': 'Affiliate',
        'time': '1d ago',
        'intent': UiIntent.warning,
      },
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Center',
                    style: context.uiText.display.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    'Price alerts, direct messages, AI recommendations and system updates',
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
              UiButton(
                label: 'Mark All Read',
                leadingIcon: Icons.done_all,
                variant: UiVariant.outline,
                intent: UiIntent.neutral,
                onPressed: () {
                  UiToast.show(
                    context,
                    title: 'Notifications Cleared',
                    message: 'All notifications marked as read',
                    intent: UiIntent.info,
                  );
                },
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Notifications List
          for (final n in notifications)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: UiCard(
                child: Row(
                  children: [
                    UiBadge(
                      label: n['category'] as String,
                      intent: n['intent'] as UiIntent,
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n['title'] as String,
                            style: context.uiText.bodyStrong,
                          ),
                          SizedBox(height: context.sp(theme.spacing.xxs)),
                          Text(
                            n['body'] as String,
                            style: context.uiText.body.copyWith(
                              color: theme.colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Text(
                      n['time'] as String,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
