import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class EnterprisePage extends StatelessWidget {
  const EnterprisePage({super.key});

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
                    'Enterprise & Risk Administration',
                    style: context.uiText.display.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    'Team management, organization risk rules, compliance audit & API keys',
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
              const UiBadge(
                label: 'Enterprise Authorization Active',
                intent: UiIntent.danger,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Enterprise Stat Cards
          Row(
            children: [
              const Expanded(
                child: UiMetricCard(
                  label: 'Active Team Seats',
                  value: '18 / 25',
                  delta: 7,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              const Expanded(
                child: UiMetricCard(
                  label: 'Max Daily Loss Limit',
                  value: '\$15,000.00',
                  delta: 0,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              const Expanded(
                child: UiMetricCard(
                  label: 'Audit Compliance',
                  value: '100%',
                  delta: 100,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Settings & Clearance Cards
          AppSettingCard(
            title: 'Master Admin Key Clearance',
            description: 'LIC-ADMIN-2026-KEY active for organization policy overrides.',
            icon: Icons.shield_outlined,
            control: const UiBadge(label: 'Verified Key', intent: UiIntent.success),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Enterprise Block
          UiCard(
            title: 'Organization Members & Permissions',
            subtitle: 'Manage administrative roles, risk limits and API tokens',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const UiAvatar(name: 'Nitish Kumar'),
                  title: const Text('Nitish Kumar (Master Admin)'),
                  subtitle: const Text('nitish@tradex.ai • Master Security Clearance Key Active'),
                  trailing: const UiBadge(label: 'Super Admin', intent: UiIntent.danger),
                ),
                const UiDivider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const UiAvatar(name: 'Ava Chen'),
                  title: const Text('Ava Chen (Risk Officer)'),
                  subtitle: const Text('ava@tradex.ai • Trading Desk Lead'),
                  trailing: const UiBadge(label: 'Admin', intent: UiIntent.warning),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
