import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/settings/data/repositories/organization_settings_repository.dart';
import 'package:tradex/features/settings/models/org_models.dart';
import 'package:tradex/features/settings/presentation/pages/admin/team_roles_page.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_nav_row.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_subpage_scope.dart';

class OrganizationSettingsPage extends StatefulWidget {
  const OrganizationSettingsPage({super.key, this.repository});

  final OrganizationSettingsRepository? repository;

  @override
  State<OrganizationSettingsPage> createState() =>
      _OrganizationSettingsPageState();
}

class _OrganizationSettingsPageState extends State<OrganizationSettingsPage> {
  late final OrganizationSettingsRepository _repo;
  OrgBranding _branding = const OrgBranding(
    displayName: 'TradeX Institutional Alpha',
  );
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _logoUrl = '';
  int _memberCount = 0;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? OrganizationSettingsRepositoryImpl();
    _nameController = TextEditingController();
    _loadOrgData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadOrgData() async {
    setState(() => _loading = true);
    try {
      final b = await _repo.getBranding();
      final members = await _repo.getMembers();
      if (mounted) {
        setState(() {
          _branding = b;
          _logoUrl = b.logoUrl ?? '';
          _memberCount = members.length;
          _error = null;
          _nameController.text = b.displayName;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Organization details could not be loaded. Try again.';
        });
      }
    }
  }

  Future<void> _saveBranding() async {
    if (_saving) return;
    final logo = Uri.tryParse(_logoUrl.trim());
    if (_nameController.text.trim().isEmpty ||
        (_logoUrl.trim().isNotEmpty &&
            (logo == null || logo.scheme != 'https' || logo.host.isEmpty))) {
      setState(
        () => _error =
            'Enter an organization name and a valid HTTPS logo URL, or leave the logo blank.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await _repo.updateBranding(
        displayName: _nameController.text.trim(),
        logoUrl: _logoUrl.trim(),
      );
      if (mounted) {
        setState(() {
          _branding = updated;
          _saving = false;
        });
        UiToast.show(
          context,
          title: 'Branding Updated',
          message: 'Organization profile updated successfully.',
          intent: UiIntent.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        UiToast.show(
          context,
          title: 'Save Failed',
          message: 'Could not update organization profile.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return UiSkeleton.settingsDetail(
        showIdentity: true,
        sections: 2,
        rowsPerSection: 3,
      );
    }
    final theme = context.ui;
    return UiPage(
      title: 'Organization & team',
      subtitle:
          'Manage your firm identity and the people who can access your desk.',
      actions: [
        UiButton(
          label: 'Refresh',
          variant: UiVariant.outline,
          leadingIcon: Icons.refresh,
          onPressed: _loadOrgData,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            UiCallout(
              title: 'Check organization details',
              message: _error,
              intent: UiIntent.warning,
            ),
            UiGap.v(theme.spacing.md),
          ],
          UiCard(
            title: _branding.displayName,
            subtitle: '$_memberCount desk members',
            leading: UiAvatar(
              name: _branding.displayName,
              imageUrl: _branding.logoUrl?.isEmpty == true
                  ? null
                  : _branding.logoUrl,
            ),
            child: SettingsNavRow(
              title: 'Team & Roles',
              subtitle: 'Review access, change roles and invite colleagues.',
              icon: Icons.group_outlined,
              badgeLabel: '$_memberCount members',
              onTap: () => openSettingsSubpage(
                context,
                title: 'Team Directory & Roles',
                subtitle: 'Manage trader seats, role privileges and invites',
                icon: Icons.groups_outlined,
                page: TeamRolesPage(repository: _repo),
              ),
            ),
          ),
          UiGap.v(theme.spacing.lg),
          UiCard(
            title: 'Firm identity',
            subtitle: 'Use the name and logo your team recognizes.',
            actions: [
              UiButton(
                label: 'Save Branding',
                intent: UiIntent.primary,
                loading: _saving,
                onPressed: _saveBranding,
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiField(
                  label: 'Organization Display Name',
                  required: true,
                  child: UiInput(
                    controller: _nameController,
                    hintText: 'e.g. Apex Alpha Capital',
                  ),
                ),
                UiGap.v(theme.spacing.md),
                UiField(
                  label: 'Logo URL',
                  helper:
                      'An HTTPS link to your published firm logo. Leave blank to use your initials.',
                  child: UiInput(
                    value: _logoUrl,
                    hintText: 'https://example.com/logo.png',
                    onChanged: (value) => _logoUrl = value,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.uiDockInset),
        ],
      ),
    );
  }
}
