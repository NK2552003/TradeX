import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/app_constants.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/presentation/pages/shared/settings_root_page.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    this.userRole = UserRole.customer,
    this.userEmail = 'nitish@tradex.ai',
    this.onLogout,
    this.onRoleChanged,
    this.onReturnToAuth,
  });

  final UserRole userRole;
  final String userEmail;
  final VoidCallback? onLogout;
  final ValueChanged<UserRole>? onRoleChanged;
  final VoidCallback? onReturnToAuth;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  String _selectedId = 'overview';

  @override
  void didUpdateWidget(AppScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userRole != widget.userRole) {
      _selectedId = 'overview';
    }
  }

  List<AppNavSection> _getNavSections(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return const <AppNavSection>[
          AppNavSection(
            title: 'Trading & Workspace',
            items: <AppNavItem>[
              AppNavItem(
                id: 'overview',
                label: 'Dashboard',
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
              ),
              AppNavItem(
                id: 'journal',
                label: 'Trade Journal',
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long,
              ),
              AppNavItem(
                id: 'watchlists',
                label: 'Watchlists & Scanner',
                icon: Icons.visibility_outlined,
                selectedIcon: Icons.visibility,
              ),
              AppNavItem(
                id: 'portfolio',
                label: 'Portfolio',
                icon: Icons.pie_chart_outline,
                selectedIcon: Icons.pie_chart,
              ),
              AppNavItem(
                id: 'community',
                label: 'Community',
                icon: Icons.forum_outlined,
                selectedIcon: Icons.forum_rounded,
              ),
              AppNavItem(
                id: 'ai_copilot',
                label: 'AI Assistant',
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome_rounded,
              ),
            ],
          ),
          AppNavSection(
            title: 'Preferences & Account',
            items: <AppNavItem>[
              AppNavItem(
                id: 'settings',
                label: 'Settings & Profile',
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                subItems: <AppNavItem>[
                  AppNavItem(
                    id: 'settings_profile',
                    label: 'Profile',
                    icon: Icons.person_outline_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_security',
                    label: 'Email & Security',
                    icon: Icons.lock_outline_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_trading',
                    label: 'Trading Rules',
                    icon: Icons.candlestick_chart_outlined,
                  ),
                  AppNavItem(
                    id: 'settings_billing',
                    label: 'Subscription & Billing',
                    icon: Icons.credit_card_outlined,
                  ),
                  AppNavItem(
                    id: 'settings_notifications',
                    label: 'Notifications',
                    icon: Icons.notifications_none_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_privacy',
                    label: 'Privacy & Data',
                    icon: Icons.security_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_appearance',
                    label: 'Appearance',
                    icon: Icons.palette_outlined,
                  ),
                  AppNavItem(
                    id: 'settings_help',
                    label: 'Help & Support',
                    icon: Icons.help_outline_rounded,
                  ),
                ],
              ),
            ],
          ),
        ];

      case UserRole.affiliate:
        return const <AppNavSection>[
          AppNavSection(
            title: 'Partner Portal',
            items: <AppNavItem>[
              AppNavItem(
                id: 'overview',
                label: 'Partner Hub',
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
              ),
              AppNavItem(
                id: 'referrals',
                label: 'Referrals & Clicks',
                icon: Icons.trending_up_rounded,
                selectedIcon: Icons.trending_up,
              ),
              AppNavItem(
                id: 'marketing',
                label: 'Media Kit & Creatives',
                icon: Icons.campaign_outlined,
                selectedIcon: Icons.campaign,
              ),
              AppNavItem(
                id: 'payouts',
                label: 'Payout History',
                icon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet,
              ),
              AppNavItem(
                id: 'community',
                label: 'Community',
                icon: Icons.forum_outlined,
                selectedIcon: Icons.forum_rounded,
              ),
              AppNavItem(
                id: 'ai_copilot',
                label: 'AI Assistant',
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome_rounded,
              ),
            ],
          ),
          AppNavSection(
            title: 'Preferences & Account',
            items: <AppNavItem>[
              AppNavItem(
                id: 'settings',
                label: 'Partner Settings',
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                subItems: <AppNavItem>[
                  AppNavItem(
                    id: 'settings_profile',
                    label: 'Partner Profile',
                    icon: Icons.person_outline_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_affiliate',
                    label: 'Affiliate & Payouts',
                    icon: Icons.handshake_outlined,
                  ),
                  AppNavItem(
                    id: 'settings_security',
                    label: 'Email & Security',
                    icon: Icons.lock_outline_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_notifications',
                    label: 'Referral Alerts',
                    icon: Icons.notifications_none_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_privacy',
                    label: 'Privacy & Data',
                    icon: Icons.security_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_appearance',
                    label: 'Appearance',
                    icon: Icons.palette_outlined,
                  ),
                  AppNavItem(
                    id: 'settings_help',
                    label: 'Partner Help & FAQ',
                    icon: Icons.help_outline_rounded,
                  ),
                ],
              ),
            ],
          ),
        ];

      case UserRole.userAdmin:
        return const <AppNavSection>[
          AppNavSection(
            title: 'Institutional Desk',
            items: <AppNavItem>[
              AppNavItem(
                id: 'overview',
                label: 'Desk Console',
                icon: Icons.corporate_fare_outlined,
                selectedIcon: Icons.corporate_fare,
              ),
              AppNavItem(
                id: 'org_team',
                label: 'Traders & Seats',
                icon: Icons.groups_outlined,
                selectedIcon: Icons.groups,
              ),
              AppNavItem(
                id: 'org_risk',
                label: 'Risk Limits & Compliance',
                icon: Icons.shield_outlined,
                selectedIcon: Icons.shield,
              ),
              AppNavItem(
                id: 'org_audit',
                label: 'Execution Audit Log',
                icon: Icons.history_edu_outlined,
                selectedIcon: Icons.history_edu,
              ),
              AppNavItem(
                id: 'community',
                label: 'Community',
                icon: Icons.forum_outlined,
                selectedIcon: Icons.forum_rounded,
              ),
              AppNavItem(
                id: 'ai_copilot',
                label: 'AI Assistant',
                icon: Icons.auto_awesome_outlined,
                selectedIcon: Icons.auto_awesome_rounded,
              ),
            ],
          ),
          AppNavSection(
            title: 'Preferences & Account',
            items: <AppNavItem>[
              AppNavItem(
                id: 'settings',
                label: 'Desk Settings',
                icon: Icons.admin_panel_settings_outlined,
                selectedIcon: Icons.admin_panel_settings,
                subItems: <AppNavItem>[
                  AppNavItem(
                    id: 'settings_profile',
                    label: 'Admin Profile',
                    icon: Icons.person_outline_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_organization',
                    label: 'Desk & Team',
                    icon: Icons.corporate_fare_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_desk_risk',
                    label: 'Risk & Compliance',
                    icon: Icons.shield_outlined,
                  ),
                  AppNavItem(
                    id: 'settings_security',
                    label: 'Admin Security & Auth',
                    icon: Icons.lock_outline_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_notifications',
                    label: 'Desk Alerts & Audit',
                    icon: Icons.notifications_none_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_privacy',
                    label: 'Privacy & Audit Export',
                    icon: Icons.security_rounded,
                  ),
                  AppNavItem(
                    id: 'settings_appearance',
                    label: 'Appearance',
                    icon: Icons.palette_outlined,
                  ),
                  AppNavItem(
                    id: 'settings_help',
                    label: 'Institutional Support',
                    icon: Icons.help_outline_rounded,
                  ),
                ],
              ),
            ],
          ),
        ];
    }
  }

  String _getTitleForTab(String id) {
    switch (id) {
      case 'overview':
        return switch (widget.userRole) {
          UserRole.customer => 'Dashboard',
          UserRole.affiliate => 'Partner Hub',
          UserRole.userAdmin => 'Desk Console',
        };
      case 'journal':
        return 'Trade Journal';
      case 'watchlists':
        return 'Watchlists & Scanner';
      case 'portfolio':
        return 'Portfolio';
      case 'community':
        return 'Community';
      case 'ai_copilot':
      case 'insights':
        return 'AI Assistant';
      case 'referrals':
        return 'Referrals & Clicks';
      case 'marketing':
        return 'Media Kit & Creatives';
      case 'payouts':
        return 'Payout History';
      case 'org_team':
        return 'Traders & Seats';
      case 'org_risk':
        return 'Risk Limits & Compliance';
      case 'org_audit':
        return 'Execution Audit Log';
      default:
        return id.toUpperCase();
    }
  }

  Widget _buildActivePage() {
    if (_selectedId.startsWith('settings')) {
      final sectionId = _selectedId == 'settings'
          ? 'profile'
          : _selectedId.replaceFirst('settings_', '');

      return SettingsRootPage(
        key: ValueKey<String>('settings_${widget.userRole.id}_$sectionId'),
        userRole: widget.userRole,
        initialSectionId: sectionId,
        onLogout: widget.onLogout,
      );
    }

    // Keep all non-settings pages empty (for all users) - only clean text
    final title = _getTitleForTab(_selectedId);
    return Center(
      child: Text(
        title,
        style: context.uiText.heading.copyWith(
          color: context.ui.colors.foregroundMuted,
          fontWeight: FontWeight.w600,
          fontSize: 22.0,
        ),
      ),
    );
  }

  void _showRoleSwitcherDialog() {
    showDialog(
      context: context,
      builder: (ctx) => UiDialog(
        title: 'Switch User Role',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: UserRole.values.map((role) {
            final isSelected = widget.userRole == role;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: UiInteractive(
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onRoleChanged?.call(role);
                  UiToast.show(
                    context,
                    title: 'Role Switch',
                    message: 'Switched session to ${role.label} mode.',
                    intent: UiIntent.info,
                  );
                },
                builder: (context, state) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.ui.colors.primary.withValues(alpha: 0.12)
                        : (state.hovered
                            ? context.ui.colors.surfaceHover
                            : Colors.transparent),
                    borderRadius: context.radius(context.ui.radii.md),
                    border: Border.all(
                      color: isSelected
                          ? context.ui.colors.primary
                          : context.ui.colors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(role.icon, color: context.ui.colors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role.label,
                              style: context.uiText.bodyStrong,
                            ),
                            Text(
                              role.subtitle,
                              style: context.uiText.caption.copyWith(
                                color: context.ui.colors.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      UiBadge(
                        label: role.shortTitle,
                        intent: role.badgeIntent,
                        size: UiSize.xs,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          UiButton(
            label: 'Close',
            variant: UiVariant.outline,
            intent: UiIntent.neutral,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final navSections = _getNavSections(widget.userRole);

    return Column(
      children: [
        // Redesigned Static Session Header Bar (for Admin / Partner mode)
        if (widget.userRole != UserRole.customer)
          Container(
            height: context.sz(36),
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.sm),
            ),
            decoration: BoxDecoration(
              color: widget.userRole == UserRole.userAdmin
                  ? colors.bearish.withValues(alpha: 0.08)
                  : colors.warning.withValues(alpha: 0.08),
              border: Border(
                bottom: BorderSide(
                  color: widget.userRole == UserRole.userAdmin
                      ? colors.bearish.withValues(alpha: 0.22)
                      : colors.warning.withValues(alpha: 0.22),
                  width: theme.borders.hairline,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.xs),
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (widget.userRole == UserRole.userAdmin
                            ? colors.bearish
                            : colors.warning)
                        .withValues(alpha: 0.16),
                    borderRadius: context.radius(theme.radii.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.userRole.icon,
                        size: context.sz(12),
                        color: widget.userRole == UserRole.userAdmin
                            ? colors.bearish
                            : colors.warning,
                      ),
                      SizedBox(width: context.sp(theme.spacing.xxs)),
                      Text(
                        widget.userRole.label.toUpperCase(),
                        style: context.uiText.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.userRole == UserRole.userAdmin
                              ? colors.bearish
                              : colors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  child: Text(
                    widget.userRole.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.foregroundMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                UiButton(
                  label: 'Switch Role',
                  leadingIcon: Icons.swap_horiz_rounded,
                  variant: UiVariant.ghost,
                  intent: UiIntent.primary,
                  size: UiSize.xs,
                  onPressed: _showRoleSwitcherDialog,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                UiButton(
                  label: 'Logout',
                  leadingIcon: Icons.logout_rounded,
                  variant: UiVariant.soft,
                  intent: UiIntent.danger,
                  size: UiSize.xs,
                  onPressed: widget.onLogout,
                ),
              ],
            ),
          ),

        // Main App Shell with Role-Specific Dock & Sidebar
        Expanded(
          child: AppShell(
            key: ValueKey<String>('${AppConstants.appName}_${widget.userRole.id}'),
            sections: navSections,
            selectedId: _selectedId,
            onSelect: (id) => setState(() => _selectedId = id),
            onSettings: () => setState(() => _selectedId = 'settings_profile'),
            trader: AppTrader(
              id: 'u1',
              handle: widget.userEmail,
              displayName: 'Nitish Kumar (${widget.userRole.shortTitle})',
              tier: widget.userRole == UserRole.customer
                  ? AppTier.premium
                  : AppTier.free,
            ),
            workspaceName: switch (widget.userRole) {
              UserRole.customer => 'TradeX Pro Terminal',
              UserRole.affiliate => 'Affiliate Partner Hub',
              UserRole.userAdmin => 'Institutional Desk',
            },
            tierLabel: switch (widget.userRole) {
              UserRole.customer => 'Active Trader',
              UserRole.affiliate => 'Affiliate Partner',
              UserRole.userAdmin => 'Desk Administrator',
            },
            unreadNotifications: 4,
            child: _buildActivePage(),
          ),
        ),
      ],
    );
  }
}
