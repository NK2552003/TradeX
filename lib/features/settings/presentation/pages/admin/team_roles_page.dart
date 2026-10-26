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
  bool _loading = true;

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
                } catch (e) {
                  if (dialogCtx.mounted) {
                    setDialogState(() {
                      inviting = false;
                      invitationError =
                          'Invitation could not be saved. Try again.';
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
    return UiPage(
      title: 'Team directory & roles',
      subtitle:
          '${_members.length} desk members. Review access or invite a colleague.',
      actions: [
        UiButton(
          label: 'Invite Member',
          leadingIcon: Icons.person_add_alt_1_rounded,
          onPressed: _showInviteMemberDialog,
        ),
      ],
      child: UiTable<OrgMember>(
        rows: _members,
        rowKey: (member) => member.userId,
        stackOnMobile: true,
        pageSize: 12,
        emptyLabel: 'No team members yet. Invite a colleague to get started.',
        columns: [
          UiTableColumn(
            header: 'Member',
            flex: 2,
            cell: (context, member) => Row(
              children: [
                UiAvatar(name: member.displayName, imageUrl: member.avatarUrl),
                UiGap.h(context.ui.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: context.uiText.bodyStrong,
                      ),
                      Text('@${member.handle}', style: context.uiText.caption),
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
    );
  }
}
