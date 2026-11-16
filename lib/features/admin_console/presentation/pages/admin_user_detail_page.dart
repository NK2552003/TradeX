import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../../data/admin_repository.dart';
import '../../models/admin_records.dart';
import '../widgets/admin_access_form.dart';
import '../widgets/admin_action_dialog.dart';
import '../widgets/admin_affiliate_form.dart';
import '../widgets/admin_facts.dart';
import '../widgets/admin_preview_cards.dart';
import '../widgets/admin_records_panel.dart';
import '../widgets/admin_subscription_form.dart';
import 'admin_record_detail_page.dart';

class AdminUserDetailPage extends StatefulWidget {
  const AdminUserDetailPage({
    super.key,
    required this.userId,
    required this.repository,
    required this.onBack,
    this.initialTab = 'Overview',
  });

  final String userId;
  final AdminRepository repository;
  final VoidCallback onBack;
  final String initialTab;

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage> {
  static const _tabs = [
    'Overview',
    'Permissions',
    'Subscription',
    'Affiliate',
    'Posts',
    'Comments',
    'Notes',
    'Journal',
    'Strategies',
    'Messages',
    'AI',
    'AI requests',
    'Activity',
  ];

  AdminUserDetail? _user;
  String? _error;
  bool _loading = true;
  int _revision = 0;
  late int _tab = _tabs.indexOf(widget.initialTab).clamp(0, _tabs.length - 1);
  (AdminResource, AdminRecord)? _record;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await widget.repository.user(widget.userId);
      if (mounted) {
        setState(() {
          _user = user;
          _loading = false;
          _revision++;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = adminError(error);
          _loading = false;
        });
      }
    }
  }

  void _openRecord(AdminResource resource, AdminRecord row) =>
      setState(() => _record = (resource, row));

  @override
  Widget build(BuildContext context) {
    final opened = _record;
    if (opened != null) {
      return AdminRecordDetailPage(
        resource: opened.$1,
        recordId: opened.$2.id,
        repository: widget.repository,
        onBack: () {
          setState(() => _record = null);
          _load();
        },
      );
    }
    return UiPage(
      title: _user?.profile.title ?? 'User details',
      subtitle: 'Account records, permissions and activity',
      actions: [
        UiButton(
          label: 'Back',
          leadingIcon: Icons.arrow_back,
          variant: UiVariant.ghost,
          onPressed: widget.onBack,
        ),
        UiButton(
          label: 'Refresh',
          leadingIcon: Icons.refresh,
          variant: UiVariant.outline,
          onPressed: _loading ? null : _load,
        ),
      ],
      child: UiAsyncView<AdminUserDetail>(
        loading: _loading,
        error: _error,
        data: _user,
        onRetry: _load,
        loadingMessage: 'Loading user details…',
        dataBuilder: (context, user) {
          final colors = context.ui.colors;
          final handle = user.profile.text('handle');
          final email = user.profile.text('email');
          final avatarUrl = user.profile.values['avatar_url']?.toString();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiCard(
                variant: UiCardVariant.surface,
                accentColor: user.profile.status == 'active'
                    ? colors.success
                    : colors.danger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UiAvatar(
                              name: user.profile.title,
                              imageUrl: avatarUrl?.isNotEmpty == true
                                  ? avatarUrl
                                  : null,
                              size: UiSize.md,
                            ),
                            const UiGap.h(12),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.profile.title,
                                    style: context.uiText.title,
                                  ),
                                  if (handle.isNotEmpty || email.isNotEmpty)
                                    Text(
                                      [
                                        if (handle.isNotEmpty) '@$handle',
                                        if (email.isNotEmpty) email,
                                      ].join(' · '),
                                      style: context.uiText.caption,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: context.sp(context.ui.spacing.sm),
                          runSpacing: context.sp(context.ui.spacing.sm),
                          children: [
                            UiBadge(
                              label: adminLabel(user.profile.status),
                              intent: adminStatusIntent(user.profile.status),
                            ),
                            UiBadge(label: adminLabel(user.profile.text('role'))),
                            UiBadge(
                              label: adminLabel(user.tier),
                              intent: UiIntent.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const UiGap.v(12),
                    Text(
                      'Joined ${adminDate(user.profile.values['created_at'])} · Last sign-in ${adminDate(user.values['last_sign_in_at'])}',
                      style: context.uiText.caption,
                    ),
                  ],
                ),
              ),
              const UiGap.v(16),
              UiTabs(
                tabs: _tabs,
                selectedIndex: _tab,
                scrollable: true,
                onChanged: (value) => setState(() => _tab = value),
              ),
              const UiGap.v(20),
              if (_tab == 0)
                _UserOverview(
                  user: user,
                  repository: widget.repository,
                  onSaved: _load,
                ),
              if (_tab == 1)
                AdminAccessForm(
                  key: ValueKey('permissions-$_revision'),
                  user: user,
                  repository: widget.repository,
                  onSaved: _load,
                ),
              if (_tab == 2)
                AdminSubscriptionForm(
                  key: ValueKey('subscription-$_revision'),
                  user: user,
                  repository: widget.repository,
                  onSaved: _load,
                ),
              if (_tab == 3)
                AdminAffiliateForm(
                  key: ValueKey('affiliate-$_revision'),
                  user: user,
                  repository: widget.repository,
                  onSaved: _load,
                  onOpen: _openRecord,
                ),
              if (_tab >= 4)
                AdminRecordsPanel(
                  key: ValueKey('$_tab-$_revision'),
                  resource: _resource,
                  repository: widget.repository,
                  userId: widget.userId,
                  onOpen: (row) => _openRecord(_resource, row),
                ),
            ],
          );
        },
      ),
    );
  }

  AdminResource get _resource => switch (_tabs[_tab]) {
    'Posts' => AdminResource.posts,
    'Comments' => AdminResource.comments,
    'Notes' => AdminResource.notes,
    'Journal' => AdminResource.journal,
    'Strategies' => AdminResource.strategies,
    'Messages' => AdminResource.messages,
    'AI' => AdminResource.ai,
    'AI requests' => AdminResource.aiRequests,
    _ => AdminResource.activity,
  };
}

class _UserOverview extends StatelessWidget {
  const _UserOverview({
    required this.user,
    required this.repository,
    required this.onSaved,
  });

  final AdminUserDetail user;
  final AdminRepository repository;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    final profile = user.profile;
    final isSelf = profile.id == repository.currentUserId;
    final isAdmin = profile.text('role') == 'user_admin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCardGrid(
          minTileWidth: 180,
          children: [
            for (final count in user.counts.entries)
              UiMetricCard(
                title: adminLabel(count.key),
                value: '${count.value}',
                caption: 'Stored records',
              ),
          ],
        ),
        if (user.counts.isNotEmpty) ...[
          const UiGap.v(20),
          AdminSection(
            title: 'Activity footprint',
            description: 'Relative volume across workspace modules.',
            child: UiCard(
              variant: UiCardVariant.surface,
              child: UiBarList(
                valueFormatter: (v) => v.toStringAsFixed(0),
                items: [
                  for (final count in user.counts.entries)
                    UiBarListItem(
                      label: adminLabel(count.key),
                      value: count.value,
                    ),
                ],
              ),
            ),
          ),
        ],
        const UiGap.v(20),
        AdminSection(
          title: 'Account',
          child: AdminFacts(
            values: {
              'User ID': profile.id,
              'Handle': profile.text('handle'),
              'Email': profile.text('email'),
              'Created': adminDate(profile.values['created_at']),
              'Last sign-in': adminDate(user.values['last_sign_in_at']),
              'Last profile change': adminDate(profile.values['updated_at']),
            },
          ),
        ),
        const UiGap.v(20),
        AdminSection(
          title: 'Account controls',
          child: Wrap(
            spacing: context.sp(context.ui.spacing.sm),
            runSpacing: context.sp(context.ui.spacing.sm),
            children: [
              UiButton(
                label: profile.status == 'active'
                    ? 'Suspend account'
                    : 'Restore access',
                intent: profile.status == 'active'
                    ? UiIntent.danger
                    : UiIntent.success,
                onPressed: isSelf || isAdmin
                    ? null
                    : () async {
                        final suspend = profile.status == 'active';
                        if (await runAdminAction(
                          context,
                          title: suspend
                              ? 'Suspend account'
                              : 'Restore account access',
                          confirmation: profile.text('handle'),
                          destructive: suspend,
                          description: suspend
                              ? 'This account will be blocked from private data and new activity.'
                              : 'Allow this account to use its enabled features again.',
                          submit: (reason) => repository.apply(
                            action: 'account_status',
                            userId: profile.id,
                            value: {'status': suspend ? 'suspended' : 'active'},
                            reason: reason,
                          ),
                        )) {
                          onSaved();
                        }
                      },
              ),
              UiButton(
                label: 'Add internal note',
                variant: UiVariant.outline,
                onPressed: () async {
                  if (await runAdminAction(
                    context,
                    title: 'Add internal note',
                    description:
                        'The note is stored in this user’s administrator activity history.',
                    submit: (reason) => repository.apply(
                      action: 'admin_note',
                      userId: profile.id,
                      reason: reason,
                    ),
                  )) {
                    onSaved();
                  }
                },
              ),
              UiButton(
                label: 'Request account deletion',
                variant: UiVariant.outline,
                intent: UiIntent.danger,
                onPressed: isSelf || isAdmin
                    ? null
                    : () async {
                        if (await runAdminAction(
                          context,
                          title: 'Request account deletion',
                          confirmation: profile.text('handle'),
                          destructive: true,
                          description:
                              'Suspend this account and add it to the deletion queue. Permanent deletion is a separate confirmed action.',
                          submit: (reason) => repository.apply(
                            action: 'request_deletion',
                            userId: profile.id,
                            reason: reason,
                          ),
                        )) {
                          onSaved();
                        }
                      },
              ),
            ],
          ),
        ),
        if (isAdmin) ...[
          const UiGap.v(12),
          const UiCallout(
            title: 'Administrator account',
            message:
                'Another administrator must change this account’s role before suspension or deletion.',
          ),
        ],
      ],
    );
  }
}
