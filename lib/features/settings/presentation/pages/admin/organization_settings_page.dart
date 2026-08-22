import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/data/repositories/organization_settings_repository.dart';
import 'package:tradex/features/settings/models/org_models.dart';
import 'package:tradex/features/settings/presentation/pages/admin/team_roles_page.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_nav_row.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

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
      if (mounted) {
        setState(() {
          _branding = b;
          _nameController.text = b.displayName;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveBranding() async {
    setState(() => _saving = true);
    try {
      final updated = await _repo.updateBranding(
        displayName: _nameController.text.trim(),
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
    final theme = context.ui;
    final colors = theme.colors;
    final isMobile = context.uiRes.isMobile;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Column(
          children: const [
            UiSkeleton(height: 140),
            SizedBox(height: 16),
            UiSkeleton(height: 180),
          ],
        ),
      );
    }
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : 108.0)
        : context.sp(theme.spacing.lg);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        bottomInset,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Enterprise Badge Header
              UiCard(
                accentColor: colors.primary,
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: context.radius(theme.radii.md),
                      ),
                      child: Icon(
                        Icons.corporate_fare_rounded,
                        color: colors.primary,
                        size: context.sz(28),
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: context.sp(theme.spacing.xs),
                            runSpacing: context.sp(theme.spacing.xxs),
                            children: [
                              Text(
                                _branding.displayName,
                                style: context.uiText.heading,
                              ),
                              const UiBadge(
                                label: 'ENTERPRISE DESK',
                                intent: UiIntent.primary,
                                size: UiSize.xs,
                              ),
                            ],
                          ),
                          Text(
                            'Active Institutional Tier · 3 of 10 Trader Seats Used',
                            style: context.uiText.caption.copyWith(
                              color: colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Team & Roles Navigation Row
              AppSettingsSectionBlock(
                title: 'Team Directory & Access Control',
                description:
                    'Manage institutional trader accounts, role privileges, and invite colleagues.',
                children: [
                  SettingsNavRow(
                    title: 'Team & Roles',
                    subtitle: '3 Active Members (1 Owner, 1 Admin, 1 Trader)',
                    icon: Icons.group_outlined,
                    badgeLabel: '3 Seats',
                    onTap: () {
                      showSettingsSideSheet(
                        context,
                        title: 'Team Directory & Roles',
                        subtitle:
                            'Manage trader seats, role privileges and invites',
                        child: TeamRolesPage(repository: _repo),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Branding Customization
              AppSettingsSectionBlock(
                title: 'Organization Identity & White-labeling',
                description:
                    'Customize firm branding across shared playbooks and client exports.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UiField(
                          label: 'Organization Display Name',
                          child: UiInput(
                            value: _nameController.text,
                            hintText: 'e.g. Apex Alpha Capital',
                            onChanged: (v) => _nameController.text = v,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        UiField(
                          label: 'Desk Logo',
                          helper:
                              'Upload high-resolution transparent SVG or PNG logo.',
                          child: UiDropzone(
                            message: 'Drag & drop firm logo or click to upload',
                            onPick: () {
                              UiToast.show(
                                context,
                                title: 'Logo Uploaded',
                                message: 'New organization logo uploaded.',
                                intent: UiIntent.success,
                              );
                            },
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.lg)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: isMobile ? double.infinity : null,
                            child: UiButton(
                              label: 'Save Branding',
                              intent: UiIntent.primary,
                              loading: _saving,
                              onPressed: _saveBranding,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
