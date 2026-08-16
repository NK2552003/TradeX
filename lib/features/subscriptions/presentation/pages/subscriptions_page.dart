import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  String _selectedTier = 'premium';

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

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
                    'Subscriptions & Billing',
                    style: context.uiText.display.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    'Manage your TradeX membership tier, billing cycle and partner affiliate earnings',
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
              const UiBadge(
                label: 'Active Plan: Premium (\$9.99/mo)',
                intent: UiIntent.success,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Membership Tiers Radio Card Selector
          UiCard(
            title: 'Choose Plan Tier',
            subtitle: 'Unlock unlimited AI Trading Assistant, Direct Messages, and Advanced Analytics',
            child: Column(
              children: [
                UiRadioCardGroup<String>(
                  value: _selectedTier,
                  onChanged: (val) => setState(() => _selectedTier = val),
                  options: const [
                    UiOption<String>(
                      value: 'free',
                      label: 'Free Trader Tier',
                      description: 'Basic trade journal, 1 watchlist, read community feed',
                    ),
                    UiOption<String>(
                      value: 'premium',
                      label: 'Premium Plan (\$9.99/month)',
                      description: 'Unlimited AI Assistant, Strategy Playbooks, Direct Messages & Full Analytics',
                    ),
                    UiOption<String>(
                      value: 'enterprise',
                      label: 'Enterprise Team Licensing',
                      description: 'Multi-seat dashboard, risk limits, audit compliance & dedicated API key access',
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.md)),
                UiButton(
                  label: 'Update Membership Tier',
                  variant: UiVariant.primary,
                  intent: UiIntent.primary,
                  onPressed: () {
                    UiToast.show(
                      context,
                      title: 'Billing Updated',
                      message: 'Selected subscription tier: ${_selectedTier.toUpperCase()}',
                      intent: UiIntent.success,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
