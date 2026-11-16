import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../../data/admin_repository.dart';
import '../../models/admin_records.dart';
import 'admin_action_dialog.dart';
import 'admin_facts.dart';
import 'admin_preview_cards.dart';
import 'admin_records_panel.dart';

class AdminAffiliateForm extends StatefulWidget {
  const AdminAffiliateForm({
    super.key,
    required this.user,
    required this.repository,
    required this.onSaved,
    required this.onOpen,
  });

  final AdminUserDetail user;
  final AdminRepository repository;
  final VoidCallback onSaved;
  final void Function(AdminResource resource, AdminRecord record) onOpen;

  @override
  State<AdminAffiliateForm> createState() => _AdminAffiliateFormState();
}

class _AdminAffiliateFormState extends State<AdminAffiliateForm> {
  int _tab = 0;
  late String _status = widget.user.affiliate['status']?.toString() ?? 'active';
  late String _tier = widget.user.affiliate['tier']?.toString() ?? 'standard';
  late String _rate =
      ((widget.user.affiliate['commission_rate'] as num? ?? 0) * 100)
          .toStringAsFixed(2);
  String? _error;

  Future<void> _save() async {
    final rate = double.tryParse(_rate);
    if (rate == null || !rate.isFinite || rate < 0 || rate > 100) {
      setState(() => _error = 'Commission must be a percentage from 0 to 100.');
      return;
    }
    if (await runAdminAction(
      context,
      title: 'Update affiliate controls',
      description:
          'Set ${widget.user.profile.title} to $_status with a $_rate% commission rate.',
      submit: (reason) => widget.repository.apply(
        action: 'affiliate_controls',
        reason: reason,
        userId: widget.user.profile.id,
        value: {
          'status': _status,
          'tier': _tier,
          'commission_rate': rate / 100,
        },
      ),
    )) {
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final resource = switch (_tab) {
      1 => AdminResource.applications,
      2 => AdminResource.referrals,
      _ => AdminResource.payouts,
    };
    final parsedRate = double.tryParse(_rate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiTabs(
          tabs: const [
            'Partner controls',
            'Applications',
            'Referrals',
            'Payout history',
          ],
          selectedIndex: _tab,
          scrollable: true,
          onChanged: (value) => setState(() => _tab = value),
        ),
        const UiGap.v(16),
        if (_tab != 0)
          AdminRecordsPanel(
            key: ValueKey(resource),
            resource: resource,
            userId: widget.user.profile.id,
            repository: widget.repository,
            onOpen: (row) => widget.onOpen(resource, row),
          )
        else if (widget.user.affiliate.isEmpty)
          const UiEmptyState(
            title: 'No affiliate profile',
            message:
                'Review this user’s application in the Applications tab to enable partner access.',
            icon: Icons.handshake_outlined,
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiCard(
                variant: UiCardVariant.surface,
                accentColor: context.ui.colors.primary,
                child: UiStatStrip(
                  minCellWidth: 140,
                  stats: [
                    UiStat(
                      label: 'Partner access status',
                      value: adminLabel(_status),
                      intent: adminStatusIntent(_status),
                      icon: Icons.verified_user_outlined,
                    ),
                    UiStat(
                      label: 'Partner tier',
                      value: adminLabel(_tier),
                      intent: UiIntent.primary,
                      icon: Icons.workspace_premium_outlined,
                    ),
                    UiStat(
                      label: 'Rate preview',
                      value: parsedRate == null
                          ? '—'
                          : '${parsedRate.toStringAsFixed(1)}%',
                      hint: 'Applied to converted referrals',
                      intent: UiIntent.info,
                      icon: Icons.percent_outlined,
                    ),
                    UiStat(
                      label: 'Referral share',
                      value:
                          '${widget.user.affiliate['active_referrals'] ?? 0}/${widget.user.affiliate['total_referrals'] ?? 0}',
                      hint: 'Active of total referrals',
                      intent: UiIntent.success,
                      icon: Icons.group_add_outlined,
                    ),
                  ],
                ),
              ),
              const UiGap.v(20),
              AdminSection(
                title: 'Partner controls',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdminFacts(
                      values: {
                        'Affiliate code': adminValue(
                          widget.user.affiliate['affiliate_code'],
                        ),
                        'Custom slug': adminValue(
                          widget.user.affiliate['custom_slug'],
                        ),
                        'Total referrals': adminValue(
                          widget.user.affiliate['total_referrals'],
                        ),
                        'Active referrals': adminValue(
                          widget.user.affiliate['active_referrals'],
                        ),
                        'Payout method': adminValue(
                          widget.user.affiliate['payout_method'],
                        ),
                      },
                    ),
                    const UiGap.v(16),
                    UiSelect<String>(
                      label: 'Partner access',
                      value: _status,
                      options: const [
                        UiOption(value: 'active', label: 'Active'),
                        UiOption(value: 'suspended', label: 'Suspended'),
                      ],
                      onChanged: (value) => setState(() => _status = value),
                    ),
                    const UiGap.v(12),
                    UiSelect<String>(
                      label: 'Commission tier',
                      value: _tier,
                      options: [
                        for (final value in [
                          'standard',
                          'silver',
                          'gold',
                          'platinum',
                        ])
                          UiOption(value: value, label: adminLabel(value)),
                      ],
                      onChanged: (value) => setState(() => _tier = value),
                    ),
                    const UiGap.v(12),
                    UiInput(
                      label: 'Commission rate (%)',
                      value: _rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) => setState(() => _rate = value),
                    ),
                    if (_error != null) ...[
                      const UiGap.v(12),
                      UiCallout(
                        title: 'Check commission rate',
                        message: _error!,
                        intent: UiIntent.danger,
                      ),
                    ],
                    const UiGap.v(16),
                    UiButton(
                      label: 'Save affiliate controls',
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
