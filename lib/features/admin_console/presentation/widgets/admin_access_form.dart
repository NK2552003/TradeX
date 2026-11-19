import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import '../../data/admin_repository.dart';
import '../../models/admin_records.dart';
import 'admin_action_dialog.dart';
import 'admin_facts.dart';

const adminFeatureLabels = <String, String>{
  'posts': 'Create and edit posts',
  'comments': 'Write comments',
  'notes': 'Create and edit notes',
  'journal': 'Create and edit journal entries',
  'strategies': 'Create and edit strategies',
  'messages': 'Send messages',
  'ai': 'Use AI',
  'affiliate': 'Manage affiliate campaigns',
};

class AdminAccessForm extends StatefulWidget {
  const AdminAccessForm({
    super.key,
    required this.user,
    required this.repository,
    required this.onSaved,
  });

  final AdminUserDetail user;
  final AdminRepository repository;
  final VoidCallback onSaved;

  @override
  State<AdminAccessForm> createState() => _AdminAccessFormState();
}

class _AdminAccessFormState extends State<AdminAccessForm> {
  late final Map<String, bool> _features = {
    for (final key in adminFeatureLabels.keys)
      key: adminMap(widget.user.controls['features'])[key] != false,
  };

  static const _quotaLabels = {
    'notes': 'Notes (total)',
    'trades': 'Journal entries (total)',
    'live_playbooks': 'Live strategies',
    'watchlists': 'Watchlists',
    'alerts': 'Price alerts',
    'posts_per_day': 'Posts per day',
    'community_comments_per_day': 'Comments per day',
    'ai_queries_per_month': 'AI requests per month',
    'ai_queries_per_day': 'AI requests per day',
  };

  late final Map<String, String> _limits = {
    for (final key in _quotaLabels.keys)
      key: adminMap(widget.user.controls['limits'])[key]?.toString() ?? '',
  };

  late String _role = widget.user.profile.text('role');
  String? _error;

  bool get _isSelf => widget.repository.currentUserId == widget.user.profile.id;

  Future<void> _save() async {
    final limits = <String, int>{};
    for (final entry in _limits.entries) {
      if (entry.value.trim().isEmpty) continue;
      final parsed = int.tryParse(entry.value.trim());
      if (parsed == null || parsed < 0 || parsed > 1000000) {
        setState(
          () => _error =
              '${_quotaLabels[entry.key]} must be a whole number from 0 to 1000000.',
        );
        return;
      }
      limits[entry.key] = parsed;
    }
    setState(() => _error = null);
    if (await runAdminAction(
      context,
      title: 'Save user permissions',
      description:
          'These permissions apply to ${widget.user.profile.title}. Platform-wide restrictions also apply.',
      submit: (reason) => widget.repository.apply(
        action: 'controls',
        userId: widget.user.profile.id,
        reason: reason,
        value: {'features': _features, 'limits': limits},
      ),
    )) {
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ui.colors;
    final enabledCount = _features.values.where((v) => v).length;
    final blockedCount = _features.length - enabledCount;
    final customQuotaCount = _limits.values
        .where((v) => v.trim().isNotEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          variant: UiCardVariant.surface,
          accentColor: blockedCount > 0 ? colors.warning : colors.success,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Effective access preview', style: context.uiText.title),
                  UiBadge(
                    label: '$customQuotaCount custom quota overrides',
                    intent: customQuotaCount > 0
                        ? UiIntent.info
                        : UiIntent.neutral,
                    variant: UiBadgeVariant.soft,
                  ),
                ],
              ),
              const UiGap.v(12),
              UiCategoryBar(
                categories: [
                  UiCategorySegment(
                    label: 'Allowed ($enabledCount)',
                    value: enabledCount.toDouble(),
                    color: colors.success,
                  ),
                  UiCategorySegment(
                    label: 'Restricted ($blockedCount)',
                    value: blockedCount.toDouble(),
                    color: colors.danger,
                  ),
                ],
              ),
            ],
          ),
        ),
        const UiGap.v(20),
        AdminSection(
          title: 'Feature permissions',
          description:
              'Disabling a feature blocks new writes. Existing records remain available unless they are individually restricted.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiCardGrid(
                minTileWidth: 270,
                children: [
                  for (final feature in adminFeatureLabels.entries)
                    UiSwitch(
                      label: feature.value,
                      value: _features[feature.key]!,
                      asCard: true,
                      enabled: !_isSelf,
                      description:
                          adminMap(
                                    widget.user.values['features'],
                                  )[feature.key] ==
                                  false &&
                              _features[feature.key]!
                          ? 'Currently blocked by account or platform settings'
                          : null,
                      onChanged: (value) =>
                          setState(() => _features[feature.key] = value),
                    ),
                ],
              ),
              const UiGap.v(20),
              Text('Per-user limits', style: context.uiText.subheading),
              const UiGap.v(6),
              Text(
                'Leave a field empty to use the plan allowance. Zero prevents new records or requests.',
                style: context.uiText.body,
              ),
              const UiGap.v(12),
              UiCardGrid(
                minTileWidth: 230,
                children: [
                  for (final entry in _quotaLabels.entries)
                    UiInput(
                      label: entry.value,
                      value: _limits[entry.key],
                      hintText: 'Plan allowance',
                      enabled: !_isSelf,
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          setState(() => _limits[entry.key] = value),
                    ),
                ],
              ),
              if (_error != null) ...[
                const UiGap.v(12),
                UiCallout(
                  title: 'Check the limits',
                  message: _error!,
                  intent: UiIntent.danger,
                ),
              ],
              const UiGap.v(16),
              UiButton(
                label: 'Save permissions and limits',
                onPressed: _isSelf ? null : _save,
              ),
            ],
          ),
        ),
        const UiGap.v(20),
        AdminSection(
          title: 'Account role',
          description:
              'Affiliate access requires an approved application. An administrator cannot change their own role.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiSelect<String>(
                label: 'Role',
                value: _role,
                enabled: !_isSelf,
                options: const [
                  UiOption(value: 'customer', label: 'Customer'),
                  UiOption(value: 'affiliate', label: 'Affiliate'),
                  UiOption(value: 'user_admin', label: 'Administrator'),
                ],
                onChanged: (value) => setState(() => _role = value),
              ),
              const UiGap.v(12),
              UiButton(
                label: 'Update role',
                variant: UiVariant.outline,
                onPressed: _isSelf
                    ? null
                    : () async {
                        if (await runAdminAction(
                          context,
                          title: 'Change account role',
                          confirmation: widget.user.profile.text('handle'),
                          description:
                              'Set ${widget.user.profile.title} to ${adminLabel(_role)}.',
                          submit: (reason) => widget.repository.apply(
                            action: 'role',
                            reason: reason,
                            userId: widget.user.profile.id,
                            value: {'role': _role},
                          ),
                        )) {
                          widget.onSaved();
                        }
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
