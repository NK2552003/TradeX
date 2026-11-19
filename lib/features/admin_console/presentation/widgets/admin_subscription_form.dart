import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import '../../data/admin_repository.dart';
import '../../models/admin_records.dart';
import 'admin_action_dialog.dart';
import 'admin_facts.dart';
import 'admin_preview_cards.dart';

class AdminSubscriptionForm extends StatefulWidget {
  const AdminSubscriptionForm({
    super.key,
    required this.user,
    required this.repository,
    required this.onSaved,
  });

  final AdminUserDetail user;
  final AdminRepository repository;
  final VoidCallback onSaved;

  @override
  State<AdminSubscriptionForm> createState() => _AdminSubscriptionFormState();
}

class _AdminSubscriptionFormState extends State<AdminSubscriptionForm> {
  late String _tier = widget.user.tier;
  String _days = '30';
  String? _error;

  Future<void> _save() async {
    final days = int.tryParse(_days);
    if (days == null || days < 1 || days > 3650) {
      setState(() => _error = 'Enter 1 to 3650 days.');
      return;
    }
    final expiry = DateTime.now().toUtc().add(Duration(days: days));
    if (await runAdminAction(
      context,
      title: 'Set subscription access',
      description:
          '${widget.user.profile.title} will use ${adminLabel(_tier)} access until ${adminDate(expiry.toIso8601String())}.',
      submit: (reason) => widget.repository.apply(
        action: 'subscription_access',
        userId: widget.user.profile.id,
        reason: reason,
        value: {'tier': _tier, 'expires_at': expiry.toIso8601String()},
      ),
    )) {
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ui.colors;
    final subscription = widget.user.subscription;
    final override = adminMap(widget.user.controls['subscription_override']);
    final quota = widget.user.quota;
    final limits = adminMap(quota['limits']);
    final parsedDays = int.tryParse(_days.trim());
    final previewValid =
        parsedDays != null && parsedDays >= 1 && parsedDays <= 3650;
    final previewExpiry = previewValid
        ? DateTime.now().toUtc().add(Duration(days: parsedDays))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          variant: UiCardVariant.surface,
          accentColor: override.isNotEmpty ? colors.info : colors.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiStatStrip(
                minCellWidth: 150,
                stats: [
                  UiStat(
                    label: 'Effective plan',
                    value: adminLabel(widget.user.tier),
                    intent: UiIntent.primary,
                    icon: Icons.workspace_premium_outlined,
                  ),
                  UiStat(
                    label: 'Billing status',
                    value: adminLabel(
                      subscription['status']?.toString() ?? 'none',
                    ),
                    hint: adminValue(subscription['billing_provider']),
                    intent: adminStatusIntent(
                      subscription['status']?.toString() ?? 'neutral',
                    ),
                    icon: Icons.credit_card_outlined,
                  ),
                  UiStat(
                    label: 'Admin override',
                    value: override.isEmpty
                        ? 'None'
                        : adminLabel('${override['tier']}'),
                    hint: override.isEmpty
                        ? 'Following billing'
                        : 'Expires ${adminDate(override['expires_at'])}',
                    intent: override.isEmpty ? UiIntent.neutral : UiIntent.info,
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
        const UiGap.v(20),
        AdminSection(
          title: 'Subscription and access',
          child: AdminFacts(
            values: {
              'Effective plan': adminLabel(widget.user.tier),
              'Billing plan': adminLabel(
                subscription['tier']?.toString() ?? 'free',
              ),
              'Billing status':
                  subscription['status']?.toString() ??
                  'No billing subscription',
              'Provider': adminValue(subscription['billing_provider']),
              'Billing cycle': adminValue(subscription['billing_cycle']),
              'Provider subscription': adminValue(
                subscription['provider_subscription_id'],
              ),
              'Billing access expires': adminDate(subscription['expires_at']),
              'Administrator override': override.isEmpty
                  ? 'None'
                  : adminLabel('${override['tier']}'),
              if (override.isNotEmpty)
                'Override expires': adminDate(override['expires_at']),
            },
          ),
        ),
        const UiGap.v(20),
        AdminSection(
          title: 'Account usage',
          child: widget.user.values['quota_error'] != null
              ? UiCallout(
                  title: 'Plan limits unavailable',
                  message: '${widget.user.values['quota_error']}',
                  intent: UiIntent.warning,
                )
              : UiCardGrid(
                  minTileWidth: 210,
                  children: [
                    for (final entry in [
                      ('Notes', 'notes_used', 'notes'),
                      ('Journal entries', 'trades_used', 'trades'),
                      (
                        'Live strategies',
                        'live_playbooks_used',
                        'live_playbooks',
                      ),
                      (
                        'AI requests this month',
                        'ai_queries_used',
                        'ai_queries_per_month',
                      ),
                      ('Watchlists', 'watchlists_used', 'watchlists'),
                      ('Price alerts', 'alerts_used', 'alerts'),
                      (
                        'Community posts today',
                        'community_posts_today',
                        'community_posts_per_day',
                      ),
                      (
                        'Comments today',
                        'community_comments_today',
                        'community_comments_per_day',
                      ),
                    ])
                      _QuotaUsageCard(
                        title: entry.$1,
                        used: quota[entry.$2],
                        limit: limits[entry.$3],
                      ),
                  ],
                ),
        ),
        const UiGap.v(20),
        AdminSection(
          title: 'Set app access',
          description:
              'An override expires automatically, then billing determines access again. Charges and payment cancellations are managed by the billing provider.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiSelect<String>(
                label: 'Access plan',
                value: _tier,
                options: const [
                  UiOption(value: 'free', label: 'Free'),
                  UiOption(value: 'premium', label: 'Basic'),
                  UiOption(value: 'enterprise', label: 'Pro'),
                ],
                onChanged: (value) => setState(() => _tier = value),
              ),
              const UiGap.v(12),
              UiInput(
                label: 'Access duration (days)',
                value: _days,
                keyboardType: TextInputType.number,
                onChanged: (value) => setState(() => _days = value),
              ),
              if (previewExpiry != null) ...[
                const UiGap.v(12),
                UiCallout(
                  title: 'Override preview',
                  message:
                      'Will grant ${adminLabel(_tier)} access until ${adminDate(previewExpiry.toIso8601String())} ($parsedDays days).',
                  intent: UiIntent.info,
                ),
              ],
              if (_error != null) ...[
                const UiGap.v(12),
                UiCallout(
                  title: 'Check duration',
                  message: _error!,
                  intent: UiIntent.danger,
                ),
              ],
              const UiGap.v(16),
              Wrap(
                spacing: context.sp(context.ui.spacing.sm),
                runSpacing: context.sp(context.ui.spacing.sm),
                children: [
                  UiButton(label: 'Save access override', onPressed: _save),
                  if (override.isNotEmpty)
                    UiButton(
                      label: 'Use billing subscription',
                      variant: UiVariant.outline,
                      onPressed: () async {
                        if (await runAdminAction(
                          context,
                          title: 'Remove access override',
                          description:
                              'App access will follow the current billing subscription.',
                          submit: (reason) => widget.repository.apply(
                            action: 'clear_subscription_access',
                            userId: widget.user.profile.id,
                            reason: reason,
                          ),
                        )) {
                          widget.onSaved();
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuotaUsageCard extends StatelessWidget {
  const _QuotaUsageCard({
    required this.title,
    required this.used,
    required this.limit,
  });

  final String title;
  final Object? used;
  final Object? limit;

  @override
  Widget build(BuildContext context) {
    final usedNum = used is num ? used as num : 0;
    final limitNum = limit is num ? limit as num : null;
    final ratio = limitNum != null && limitNum > 0
        ? (usedNum / limitNum).clamp(0.0, 1.0)
        : 0.0;
    final intent = ratio >= 0.95
        ? UiIntent.danger
        : ratio >= 0.75
        ? UiIntent.warning
        : UiIntent.primary;

    return UiCard(
      variant: UiCardVariant.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.uiText.label),
          const UiGap.v(6),
          Text('${used ?? 0}', style: context.uiText.heading),
          const UiGap.v(4),
          Text(
            'Allowance: ${limit ?? 'Unavailable'}',
            style: context.uiText.caption,
          ),
          if (limitNum != null && limitNum > 0) ...[
            const UiGap.v(8),
            UiProgressBar(value: ratio, showValue: false, intent: intent),
          ],
        ],
      ),
    );
  }
}
