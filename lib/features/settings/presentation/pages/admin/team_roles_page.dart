import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/data/repositories/organization_settings_repository.dart';
import 'package:tradex/features/settings/models/org_models.dart';

class TeamRolesPage extends StatefulWidget {
  const TeamRolesPage({
    super.key,
    this.repository,
  });

  final OrganizationSettingsRepository? repository;

  @override
  State<TeamRolesPage> createState() => _TeamRolesPageState();
}

class _TeamRolesPageState extends State<TeamRolesPage> {
  late final OrganizationSettingsRepository _repo;
  List<OrgMember> _members = [];
  bool _loading = true;

  final List<String> _roleOptions = const <String>['owner', 'admin', 'trader', 'viewer'];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? OrganizationSettingsRepositoryImpl();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getMembers();
      if (mounted) {
        setState(() {
          _members = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showInviteMemberDialog() {
    final emailController = TextEditingController();
    String selectedRole = 'trader';
    bool inviting = false;

    showDialog(
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
                style: context.uiText.caption.copyWith(color: context.ui.colors.foregroundMuted),
              ),
              SizedBox(height: context.sp(context.ui.spacing.md)),
              UiField(
                label: 'Email Address',
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
                      .map((r) => UiOption<String>(label: r.toUpperCase(), value: r))
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
                if (email.isEmpty) return;
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
                      message: 'Invited $email as ${selectedRole.toUpperCase()}.',
                      intent: UiIntent.success,
                    );
                  }
                } catch (e) {
                  setDialogState(() => inviting = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveMemberDialog(OrgMember member) {
    showDialog(
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
              await _repo.removeMember(member.userId);
              await _loadMembers();
              if (mounted) {
                UiToast.show(
                  context,
                  title: 'Member Removed',
                  message: '${member.displayName} has been removed from the team.',
                  intent: UiIntent.info,
                );
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
    final theme = context.ui;
    final colors = theme.colors;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.sp(theme.spacing.lg),
            context.sp(theme.spacing.sm),
            context.sp(theme.spacing.lg),
            0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_members.length} Active Desk Members',
                style: context.uiText.bodyStrong.copyWith(color: colors.foregroundMuted),
              ),
              UiButton(
                label: 'Invite Member',
                leadingIcon: Icons.person_add_alt_1_rounded,
                size: UiSize.xs,
                onPressed: _showInviteMemberDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Padding(
                  padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                  child: Column(
                    children: const [
                      UiSkeleton(height: 70),
                      SizedBox(height: 12),
                      UiSkeleton(height: 70),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                  itemCount: _members.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(height: context.sp(theme.spacing.sm)),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final isOwner = member.role == 'owner';

                    return UiCard(
                      child: Row(
                        children: [
                          UiAvatar(
                            name: member.displayName,
                            imageUrl: member.avatarUrl,
                            size: UiSize.md,
                          ),
                          SizedBox(width: context.sp(theme.spacing.md)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(member.displayName,
                                        style: context.uiText.bodyStrong),
                                    SizedBox(
                                        width: context.sp(theme.spacing.xs)),
                                    UiBadge(
                                      label: member.role.toUpperCase(),
                                      intent: _getRoleBadgeIntent(member.role),
                                      size: UiSize.xs,
                                    ),
                                  ],
                                ),
                                Text(
                                  '@${member.handle} · Joined ${member.joinedAt.year}-${member.joinedAt.month.toString().padLeft(2, '0')}-${member.joinedAt.day.toString().padLeft(2, '0')}',
                                  style: context.uiText.caption
                                      .copyWith(color: colors.foregroundMuted),
                                ),
                              ],
                            ),
                          ),
                          if (!isOwner) ...[
                            UiSelect<String>(
                              value: member.role,
                              options: _roleOptions
                                  .where((r) => r != 'owner')
                                  .map((r) => UiOption<String>(
                                      label: r.toUpperCase(), value: r))
                                  .toList(),
                              onChanged: (newRole) async {
                                await _repo.updateMemberRole(
                                    userId: member.userId, role: newRole);
                                await _loadMembers();
                              },
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            UiIconButton(
                              icon: Icons.delete_outline_rounded,
                              size: UiSize.xs,
                              variant: UiVariant.destructive,
                              tooltip: 'Remove member',
                              onPressed: () => _showRemoveMemberDialog(member),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
