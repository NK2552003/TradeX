import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/settings/data/repositories/organization_settings_repository.dart';
import 'package:alphajournal/features/settings/models/org_models.dart';
import 'package:alphajournal/features/settings/presentation/pages/admin/team_roles_page.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_nav_row.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_subpage_scope.dart';

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
    displayName: 'Organization Workspace',
  );
  List<OrgMember> _members = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _logoUrl = '';
  String _draftName = '';
  late final TextEditingController _nameController;
  late final TextEditingController _logoController;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? OrganizationSettingsRepositoryImpl();
    _nameController = TextEditingController();
    _logoController = TextEditingController();
    _loadOrgData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _logoController.dispose();
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
          _draftName = b.displayName;
          _members = members;
          _error = null;
          _nameController.text = b.displayName;
          _logoController.text = _logoUrl;
          _loading = false;
        });
      }
    } catch (_) {
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
          _draftName = updated.displayName;
          _logoUrl = updated.logoUrl ?? '';
          _saving = false;
        });
        UiToast.show(
          context,
          title: 'Branding Updated',
          message: 'Organization profile updated successfully.',
          intent: UiIntent.success,
        );
      }
    } catch (_) {
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

  String? get _validPreviewLogoUrl {
    final trimmed = _logoUrl.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      return trimmed;
    }
    return null;
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
    final colors = theme.colors;
    final previewName = _draftName.trim().isNotEmpty
        ? _draftName.trim()
        : _branding.displayName;
    final adminCount = _members
        .where((m) => m.role == 'owner' || m.role == 'admin')
        .length;
    final traderCount = _members.where((m) => m.role == 'trader').length;
    final dirty =
        _draftName.trim() != _branding.displayName.trim() ||
        _logoUrl.trim() != (_branding.logoUrl ?? '').trim();

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
            variant: UiCardVariant.surface,
            accentColor: dirty ? colors.warning : colors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UiAvatar(
                          name: previewName,
                          imageUrl: _validPreviewLogoUrl,
                          size: UiSize.md,
                        ),
                        const UiGap.h(12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(previewName, style: context.uiText.title),
                              const UiGap.v(2),
                              Text(
                                '${_members.length} desk members',
                                style: context.uiText.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    UiBadge(
                      label: dirty ? 'Live draft preview' : 'Saved workspace',
                      intent: dirty ? UiIntent.warning : UiIntent.success,
                      variant: UiBadgeVariant.soft,
                    ),
                  ],
                ),
                const UiGap.v(14),
                UiStatStrip(
                  minCellWidth: 130,
                  stats: [
                    UiStat(
                      label: 'Total seats',
                      value: '${_members.length}',
                      intent: UiIntent.primary,
                      icon: Icons.groups_outlined,
                    ),
                    UiStat(
                      label: 'Owners & admins',
                      value: '$adminCount',
                      intent: UiIntent.warning,
                      icon: Icons.admin_panel_settings_outlined,
                    ),
                    UiStat(
                      label: 'Active traders',
                      value: '$traderCount',
                      intent: UiIntent.success,
                      icon: Icons.candlestick_chart_outlined,
                    ),
                  ],
                ),
                const UiGap.v(12),
                SettingsNavRow(
                  title: 'Team & Roles',
                  subtitle:
                      'Review access, change roles and invite colleagues.',
                  icon: Icons.group_outlined,
                  badgeLabel: '${_members.length} members',
                  onTap: () => openSettingsSubpage(
                    context,
                    title: 'Team Directory & Roles',
                    subtitle:
                        'Manage trader seats, role privileges and invites',
                    icon: Icons.groups_outlined,
                    page: TeamRolesPage(repository: _repo),
                  ),
                ),
              ],
            ),
          ),
          UiGap.v(theme.spacing.lg),
          UiCard(
            title: 'Firm identity',
            subtitle:
                'Use the name and logo your team recognizes across desk reports.',
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
                    onChanged: (value) => setState(() => _draftName = value),
                  ),
                ),
                UiGap.v(theme.spacing.md),
                UiField(
                  label: 'Logo URL',
                  helper:
                      'An HTTPS link to your published firm logo. Leave blank to use your initials.',
                  child: UiInput(
                    controller: _logoController,
                    hintText: 'https://example.com/logo.png',
                    onChanged: (value) => setState(() => _logoUrl = value),
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
