import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/settings/data/repositories/organization_settings_repository.dart';
import 'package:tradex/features/settings/models/org_models.dart';

class TeamRolesPage extends StatefulWidget {
  const TeamRolesPage({super.key, this.repository});

  final OrganizationSettingsRepository? repository;

  @override
  State<TeamRolesPage> createState() => _TeamRolesPageState();
}

class _TeamRolesPageState extends State<TeamRolesPage> {
  late final OrganizationSettingsRepository _repo;
  List<OrgMember> _members = [];
  String _search = '';
  String _roleFilter = 'all';
  bool _loading = true;
  String? _error;

  final List<String> _roleOptions = const <String>[
    'owner',
    'admin',
    'trader',
    'viewer',
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? OrganizationSettingsRepositoryImpl();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.getMembers();
      if (mounted) {
        setState(() {
          _members = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Team directory could not be loaded. Try again.';
        });
      }
    }
  }

  List<OrgMember> get _filteredMembers {
    final query = _search.trim().toLowerCase();
    return _members.where((m) {
      if (_roleFilter != 'all' && m.role.toLowerCase() != _roleFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return m.displayName.toLowerCase().contains(query) ||
          m.handle.toLowerCase().contains(query) ||
          m.role.toLowerCase().contains(query);
    }).toList();
  }

  void _showInviteMemberDialog() {
    final emailController = TextEditingController();
    String selectedRole = 'trader';
    bool inviting = false;
    String? invitationError;

    UiDialog.present(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => UiDialog(
          title: 'Invite Team Member',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Send an invitation to join your institutional trading desk workspace.',
                style: context.uiText.caption.copyWith(
                  color: context.ui.colors.foregroundMuted,
                ),
              ),
              SizedBox(height: context.sp(context.ui.spacing.md)),
              UiField(
                label: 'Email Address',
                error: invitationError,
                child: UiInput(
                  hintText: 'colleague@firm.com',
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (v) => emailController.text = v,
                ),
              ),
              SizedBox(height: context.sp(context.ui.spacing.sm)),
              UiField(
                label: 'Desk Role',
                child: UiSelect<String>(
                  value: selectedRole,
                  options: _roleOptions
                      .map(
                        (r) =>
                            UiOption<String>(label: r.toUpperCase(), value: r),
                      )
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() => selectedRole = v);
                  },
                ),
              ),
            ],
          ),
          actions: [
            UiButton(
              label: 'Cancel',
              variant: UiVariant.outline,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            UiButton(
              label: 'Send Invitation',
              intent: UiIntent.primary,
              loading: inviting,
              onPressed: () async {
                final email = emailController.text.trim();
                if (inviting) return;
                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                  setDialogState(
                    () => invitationError = 'Enter a valid email address.',
                  );
                  return;
                }
                setDialogState(() => inviting = true);
                try {
                  await _repo.inviteMember(email: email, role: selectedRole);
                  await _loadMembers();
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    UiToast.show(
                      context,
                      title: 'Invitation Sent',
                      message:
                          'Invited $email as ${selectedRole.toUpperCase()}.',
                      intent: UiIntent.success,
                    );
                  }
                } catch (error) {
                  if (dialogCtx.mounted) {
                    setDialogState(() {
                      inviting = false;
                      invitationError = error is StateError
                          ? error.message
                          : 'Invitation could not be saved. Try again.';
                    });
                  }
                }
              },
            ),
          ],
        ),
      ),
    ).whenComplete(emailController.dispose);
  }

  void _showRemoveMemberDialog(OrgMember member) {
    UiDialog.present(
      context: context,
      builder: (ctx) => UiDialog(
        title: 'Remove ${member.displayName}?',
        content: Text(
          'This will revoke their access to shared journals, strategies, and desk order execution.',
          style: context.uiText.body,
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          UiButton(
            label: 'Remove Member',
            intent: UiIntent.danger,
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _repo.removeMember(member.userId);
                await _loadMembers();
                if (mounted) {
                  UiToast.show(
                    context,
                    title: 'Member Removed',
                    message:
                        '${member.displayName} has been removed from the team.',
                    intent: UiIntent.info,
                  );
                }
              } catch (_) {
                if (mounted) {
                  UiToast.show(
                    context,
                    title: 'Removal Failed',
                    message: 'Could not remove team member. Try again.',
                    intent: UiIntent.danger,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  UiIntent _getRoleBadgeIntent(String role) {
    return switch (role.toLowerCase()) {
      'owner' => UiIntent.primary,
      'admin' => UiIntent.warning,
      'trader' => UiIntent.bullish,
      _ => UiIntent.neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return UiSkeleton.settingsList(rows: 4);
    final colors = context.ui.colors;
    final ownerCount = _members.where((m) => m.role == 'owner').length;
    final adminCount = _members.where((m) => m.role == 'admin').length;
    final traderCount = _members.where((m) => m.role == 'trader').length;
    final viewerCount = _members.where((m) => m.role == 'viewer').length;
    final filtered = _filteredMembers;

    return UiPage(
      title: 'Team directory & roles',
      subtitle:
          '${_members.length} desk members. Review access or invite a colleague.',
      actions: [
        UiButton(
          label: 'Refresh',
          variant: UiVariant.outline,
          leadingIcon: Icons.refresh,
          onPressed: _loadMembers,
        ),
        UiButton(
          label: 'Invite Member',
          leadingIcon: Icons.person_add_alt_1_rounded,
          onPressed: _showInviteMemberDialog,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            UiCallout(
              title: 'Directory sync issue',
              message: _error!,
              intent: UiIntent.warning,
            ),
            const UiGap.v(16),
          ],
          UiCard(
            variant: UiCardVariant.surface,
            accentColor: colors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiStatStrip(
                  minCellWidth: 120,
                  stats: [
                    UiStat(
                      label: 'Owners',
                      value: '$ownerCount',
                      intent: UiIntent.primary,
                    ),
                    UiStat(
                      label: 'Admins',
                      value: '$adminCount',
                      intent: UiIntent.warning,
                    ),
                    UiStat(
                      label: 'Traders',
                      value: '$traderCount',
                      intent: UiIntent.success,
                    ),
                    UiStat(
                      label: 'Viewers',
                      value: '$viewerCount',
                      intent: UiIntent.neutral,
                    ),
                  ],
                ),
                if (_members.isNotEmpty) ...[
                  const UiGap.v(12),
                  UiCategoryBar(
                    categories: [
                      if (ownerCount > 0)
                        UiCategorySegment(
                          label: 'Owner ($ownerCount)',
                          value: ownerCount.toDouble(),
                          color: colors.primary,
                        ),
                      if (adminCount > 0)
                        UiCategorySegment(
                          label: 'Admin ($adminCount)',
                          value: adminCount.toDouble(),
                          color: colors.warning,
                        ),
                      if (traderCount > 0)
                        UiCategorySegment(
                          label: 'Trader ($traderCount)',
                          value: traderCount.toDouble(),
                          color: colors.success,
                        ),
                      if (viewerCount > 0)
                        UiCategorySegment(
                          label: 'Viewer ($viewerCount)',
                          value: viewerCount.toDouble(),
                          color: colors.foregroundMuted,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const UiGap.v(16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: UiInput.search(
                  value: _search,
                  hintText: 'Search member name or @handle',
                  onChanged: (v) => setState(() => _search = v),
                  onClear: () => setState(() => _search = ''),
                ),
              ),
              UiToggleGroup<String>(
                value: _roleFilter,
                options: const [
                  UiOption(value: 'all', label: 'All'),
                  UiOption(value: 'owner', label: 'Owner'),
                  UiOption(value: 'admin', label: 'Admin'),
                  UiOption(value: 'trader', label: 'Trader'),
                  UiOption(value: 'viewer', label: 'Viewer'),
                ],
                onChanged: (role) => setState(() => _roleFilter = role),
              ),
            ],
          ),
          const UiGap.v(16),
          UiTable<OrgMember>(
            rows: filtered,
            rowKey: (member) => member.userId,
            stackOnMobile: true,
            pageSize: 12,
            emptyLabel: _members.isEmpty
                ? 'No team members yet. Invite a colleague to get started.'
                : 'No team members match the current filter.',
            columns: [
              UiTableColumn(
                header: 'Member',
                flex: 2,
                cell: (context, member) => Row(
                  children: [
                    UiAvatar(
                      name: member.displayName,
                      imageUrl: member.avatarUrl,
                    ),
                    UiGap.h(context.ui.spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName,
                            style: context.uiText.bodyStrong,
                          ),
                          Text(
                            '@${member.handle}',
                            style: context.uiText.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              UiTableColumn(
                header: 'Joined',
                cell: (context, member) =>
                    Text(AppTokens.shortDate(member.joinedAt)),
              ),
              UiTableColumn(
                header: 'Desk role',
                cell: (context, member) => member.role == 'owner'
                    ? UiBadge(
                        label: 'Owner',
                        intent: _getRoleBadgeIntent(member.role),
                      )
                    : UiSelect<String>(
                        value: member.role,
                        options: [
                          for (final role in _roleOptions.where(
                            (role) => role != 'owner',
                          ))
                            UiOption(value: role, label: role),
                        ],
                        onChanged: (role) async {
                          try {
                            await _repo.updateMemberRole(
                              userId: member.userId,
                              role: role,
                            );
                            if (mounted) await _loadMembers();
                          } catch (_) {
                            if (context.mounted) {
                              UiToast.show(
                                context,
                                title: 'Role could not be updated',
                                intent: UiIntent.danger,
                              );
                            }
                          }
                        },
                      ),
              ),
              UiTableColumn(
                header: 'Access',
                cell: (context, member) => member.role == 'owner'
                    ? const Text('Organization owner')
                    : UiButton(
                        label: 'Remove',
                        variant: UiVariant.ghost,
                        intent: UiIntent.danger,
                        size: UiSize.sm,
                        onPressed: () => _showRemoveMemberDialog(member),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
