import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/presentation/pages/admin/desk_risk_page.dart';
import 'package:tradex/features/settings/presentation/pages/admin/organization_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/affiliate/affiliate_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/account_security_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/appearance_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/help_about_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/notifications_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/privacy_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/profile_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/trader/billing_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/trader/trader_affiliate_perks_page.dart';
import 'package:tradex/features/settings/presentation/pages/trader/trading_preferences_page.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_nav_row.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

class SettingsRootPage extends StatefulWidget {
  const SettingsRootPage({
    super.key,
    this.userRole = UserRole.customer,
    this.initialSectionId,
    this.showNavigationPane = false,
    this.onLogout,
  });

  final UserRole userRole;
  final String? initialSectionId;
  final bool showNavigationPane;
  final VoidCallback? onLogout;

  @override
  State<SettingsRootPage> createState() => _SettingsRootPageState();
}

class _SettingsRootPageState extends State<SettingsRootPage> {
  late String _selectedSectionId;

  @override
  void initState() {
    super.initState();
    _selectedSectionId = widget.initialSectionId ?? 'profile';
  }

  @override
  void didUpdateWidget(SettingsRootPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userRole != widget.userRole ||
        (widget.initialSectionId != null &&
            widget.initialSectionId != oldWidget.initialSectionId)) {
      _selectedSectionId = widget.initialSectionId ?? 'profile';
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => UiDialog(
        title: 'Confirm Log Out',
        content: Text(
          'Are you sure you want to end your current session? You will need to sign in again to access live charts and journals.',
          style: context.uiText.body,
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          UiButton(
            label: 'Log Out',
            intent: UiIntent.danger,
            variant: UiVariant.primary,
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onLogout?.call();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPane(String sectionId) {
    return switch (sectionId) {
      'profile' => ProfileSettingsPage(userRole: widget.userRole),
      'affiliate_perks' => const TraderAffiliatePerksPage(),
      'security' => const AccountSecurityPage(),
      'affiliate' => const AffiliateSettingsPage(),
      'organization' => const OrganizationSettingsPage(),
      'desk_risk' => const DeskRiskPage(),
      'notifications' => const NotificationsSettingsPage(),
      'privacy' => const PrivacySettingsPage(),
      'appearance' => const AppearanceSettingsPage(),
      'trading' => const TradingPreferencesPage(),
      'billing' => BillingSettingsPage(userRole: widget.userRole),
      'help' => const HelpAboutPage(),
      _ => ProfileSettingsPage(userRole: widget.userRole),
    };
  }

  void _navigateToSubpage(Widget page, String title) {
    showSettingsSideSheet(
      context,
      title: title,
      child: page,
    );
  }

  List<Map<String, dynamic>> _getSectionsForRole() {
    switch (widget.userRole) {
      case UserRole.customer:
        return [
          {'id': 'profile', 'title': 'Profile', 'icon': Icons.person_outline_rounded, 'subtitle': 'Avatar, bio, and trading experience'},
          {'id': 'security', 'title': 'Email & Security', 'icon': Icons.lock_outline_rounded, 'subtitle': 'Password, connected accounts, and sessions'},
          {'id': 'trading', 'title': 'Personal Trading Rules', 'icon': Icons.candlestick_chart_outlined, 'subtitle': 'Personal risk limits, checklist gates, watchlists'},
          {'id': 'billing', 'title': 'Subscription & Billing', 'icon': Icons.credit_card_outlined, 'subtitle': 'Plan tier, payment methods, invoices'},
          {'id': 'notifications', 'title': 'Notifications', 'icon': Icons.notifications_none_rounded, 'subtitle': 'Push, email alerts, and quiet hours'},
          {'id': 'privacy', 'title': 'Privacy & Data', 'icon': Icons.security_rounded, 'subtitle': 'Journal visibility, blocked users, export'},
          {'id': 'appearance', 'title': 'Appearance & Charts', 'icon': Icons.palette_outlined, 'subtitle': 'Theme mode, chart defaults, density'},
          {'id': 'help', 'title': 'Help & Support', 'icon': Icons.help_outline_rounded, 'subtitle': 'Contact desk, changelog, legal disclosures'},
        ];

      case UserRole.affiliate:
        return [
          {'id': 'profile', 'title': 'Partner Profile', 'icon': Icons.person_outline_rounded, 'subtitle': 'Creator alias, channels, bio'},
          {'id': 'affiliate', 'title': 'Affiliate & Payouts', 'icon': Icons.handshake_outlined, 'subtitle': 'Referral link, slug, commission rates, payout method'},
          {'id': 'security', 'title': 'Email & Security', 'icon': Icons.lock_outline_rounded, 'subtitle': 'Password and OAuth providers'},
          {'id': 'notifications', 'title': 'Referral & Alert Prefs', 'icon': Icons.notifications_none_rounded, 'subtitle': 'New signup alerts, payout notices'},
          {'id': 'privacy', 'title': 'Privacy & Data', 'icon': Icons.security_rounded, 'subtitle': 'Leaderboard display, GDPR export'},
          {'id': 'appearance', 'title': 'Appearance', 'icon': Icons.palette_outlined, 'subtitle': 'Dark/Light mode preference'},
          {'id': 'help', 'title': 'Partner Help & FAQ', 'icon': Icons.help_outline_rounded, 'subtitle': 'Affiliate support, terms, payouts guide'},
        ];

      case UserRole.userAdmin:
        return [
          {'id': 'profile', 'title': 'Admin Profile', 'icon': Icons.person_outline_rounded, 'subtitle': 'Administrator credentials and desk division'},
          {'id': 'organization', 'title': 'Desk Workspace & Team', 'icon': Icons.corporate_fare_rounded, 'subtitle': 'Desk branding, seats, member directory, roles'},
          {'id': 'desk_risk', 'title': 'Desk Risk & Compliance', 'icon': Icons.shield_outlined, 'subtitle': 'Firm drawdown circuit breakers and capital limits'},
          {'id': 'security', 'title': 'Admin Security & Auth', 'icon': Icons.lock_outline_rounded, 'subtitle': 'Root credential security and auth keys'},
          {'id': 'notifications', 'title': 'Desk Alerts & Audit', 'icon': Icons.notifications_none_rounded, 'subtitle': 'Risk breach alerts, member join requests'},
          {'id': 'privacy', 'title': 'Privacy & Audit Export', 'icon': Icons.security_rounded, 'subtitle': 'Compliance archiving and log export'},
          {'id': 'appearance', 'title': 'Appearance & Charts', 'icon': Icons.palette_outlined, 'subtitle': 'Terminal theme, workstation density'},
          {'id': 'help', 'title': 'Institutional Support', 'icon': Icons.help_outline_rounded, 'subtitle': 'Priority desk support and SLA hotline'},
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final isDesktop = !context.uiRes.isMobile && !context.uiRes.isTablet;
    final sections = _getSectionsForRole();

    // Ensure selectedSectionId exists in active role's sections
    if (!sections.any((s) => s['id'] == _selectedSectionId)) {
      _selectedSectionId = sections.first['id'] as String;
    }

    // When embedded inside AppShell, render detail pane full-width directly
    if (!widget.showNavigationPane) {
      return _buildDetailPane(_selectedSectionId);
    }

    // STANDALONE DESKTOP LAYOUT (2-Pane within 980px max-width column)
    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // In-Page Navigation Pane (~240px)
              SizedBox(
                width: 250,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: context.sp(theme.spacing.lg),
                    horizontal: context.sp(theme.spacing.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(theme.spacing.sm),
                          vertical: context.sp(theme.spacing.xs),
                        ),
                        child: Row(
                          children: [
                            Text('Settings', style: context.uiText.heading),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            UiBadge(
                              label: widget.userRole.shortTitle,
                              intent: widget.userRole.badgeIntent,
                              size: UiSize.xs,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.sm)),
                      Expanded(
                        child: ListView.separated(
                          itemCount: sections.length,
                          separatorBuilder: (context, index) => SizedBox(height: context.sp(theme.spacing.xxs)),
                          itemBuilder: (context, index) {
                            final s = sections[index];
                            final isSelected = _selectedSectionId == s['id'];

                            return UiInteractive(
                              onTap: () => setState(() => _selectedSectionId = s['id'] as String),
                              builder: (context, state) => Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.sp(theme.spacing.sm),
                                  vertical: context.sp(theme.spacing.xs + 2),
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primary.withValues(alpha: 0.12)
                                      : (state.hovered ? colors.surfaceHover : Colors.transparent),
                                  borderRadius: context.radius(theme.radii.md),
                                  border: Border.all(
                                    color: isSelected ? colors.primary : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      s['icon'] as IconData,
                                      size: context.sz(18),
                                      color: isSelected ? colors.primary : colors.foregroundMuted,
                                    ),
                                    SizedBox(width: context.sp(theme.spacing.sm)),
                                    Expanded(
                                      child: Text(
                                        s['title'] as String,
                                        style: context.uiText.bodyStrong.copyWith(
                                          color: isSelected ? colors.primary : colors.foreground,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      UiDivider(),
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      UiButton(
                        label: 'Log Out',
                        leadingIcon: Icons.logout_rounded,
                        variant: UiVariant.ghost,
                        intent: UiIntent.danger,
                        size: UiSize.sm,
                        onPressed: _showLogoutDialog,
                      ),
                    ],
                  ),
                ),
              ),

              // Divider between left nav and detail pane
              Container(
                width: 1,
                color: colors.border,
                margin: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.md)),
              ),

              // Detail Pane
              Expanded(
                child: _buildDetailPane(_selectedSectionId),
              ),
            ],
          ),
        ),
      );
    }

    // MOBILE / TABLET LAYOUT (Stacked Sections pushing Sub-pages tailored by role)
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Account & Identity Section
          AppSettingsSectionBlock(
            title: 'Account & Security (${widget.userRole.label})',
            children: [
              SettingsNavRow(
                title: widget.userRole == UserRole.customer
                    ? 'Personal Profile'
                    : (widget.userRole == UserRole.affiliate ? 'Partner Identity' : 'Admin Profile'),
                subtitle: widget.userRole == UserRole.customer
                    ? 'Avatar, bio, and trading experience'
                    : (widget.userRole == UserRole.affiliate ? 'Creator alias and promotional bio' : 'Administrator credentials and desk division'),
                icon: Icons.person_outline_rounded,
                onTap: () => _navigateToSubpage(ProfileSettingsPage(userRole: widget.userRole), 'Profile'),
              ),
              SettingsNavRow(
                title: 'Email & Password Security',
                subtitle: 'Password, sessions, and connected OAuth',
                icon: Icons.lock_outline_rounded,
                onTap: () => _navigateToSubpage(const AccountSecurityPage(), 'Email & Security'),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Role-specific primary blocks
          if (widget.userRole == UserRole.affiliate) ...[
            AppSettingsSectionBlock(
              title: 'Affiliate Portal & Payouts',
              children: [
                SettingsNavRow(
                  title: 'Referral Links & Payout Settings',
                  subtitle: 'Custom referral slug, 30% RevShare, PayPal/ACH routing',
                  icon: Icons.handshake_outlined,
                  badgeLabel: 'GOLD PARTNER',
                  onTap: () => _navigateToSubpage(const AffiliateSettingsPage(), 'Affiliate & Payouts'),
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),
          ] else if (widget.userRole == UserRole.userAdmin) ...[
            AppSettingsSectionBlock(
              title: 'Institutional Workspace & Governance',
              children: [
                SettingsNavRow(
                  title: 'Organization Workspace & Team',
                  subtitle: 'Desk branding, seats, roles, and trader directory',
                  icon: Icons.corporate_fare_rounded,
                  badgeLabel: '25 SEATS',
                  onTap: () => _navigateToSubpage(const OrganizationSettingsPage(), 'Organization Settings'),
                ),
                SettingsNavRow(
                  title: 'Desk Risk & Compliance Policies',
                  subtitle: 'Firm drawdown limits and pre-trade gates',
                  icon: Icons.shield_outlined,
                  badgeLabel: 'RISK GATES',
                  onTap: () => _navigateToSubpage(const DeskRiskPage(), 'Desk Risk Policies'),
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),
          ],

          // Platform Preferences
          AppSettingsSectionBlock(
            title: 'Platform Preferences',
            children: [
              if (widget.userRole == UserRole.customer)
                SettingsNavRow(
                  title: 'Personal Trading & Risk Rules',
                  subtitle: 'Personal position sizing %, checklist gates, watchlist defaults',
                  icon: Icons.candlestick_chart_outlined,
                  onTap: () => _navigateToSubpage(
                    const TradingPreferencesPage(),
                    'Personal Trading Rules',
                  ),
                ),
              SettingsNavRow(
                title: 'Notifications & Alerts',
                subtitle: widget.userRole == UserRole.affiliate
                    ? 'Referral alerts, monthly payout notifications'
                    : 'Push notifications, price alert emails, quiet hours',
                icon: Icons.notifications_none_rounded,
                onTap: () => _navigateToSubpage(const NotificationsSettingsPage(), 'Notifications'),
              ),
              SettingsNavRow(
                title: 'Privacy & Data Export',
                subtitle: 'Public journals, statistics sharing, blocked users',
                icon: Icons.security_rounded,
                onTap: () => _navigateToSubpage(const PrivacySettingsPage(), 'Privacy & Data'),
              ),
              SettingsNavRow(
                title: 'Appearance & Chart Theme',
                subtitle: 'Dark / light mode, chart range, density',
                icon: Icons.palette_outlined,
                onTap: () => _navigateToSubpage(const AppearanceSettingsPage(), 'Appearance'),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Subscriptions & Billing (Exclusively for paying Customer / Trader)
          if (widget.userRole == UserRole.customer) ...[
            AppSettingsSectionBlock(
              title: 'Subscription & Billing',
              children: [
                SettingsNavRow(
                  title: 'Subscription & Usage Quotas',
                  subtitle: 'Membership tier, renewal date, payment cards, invoices',
                  icon: Icons.credit_card_outlined,
                  badgeLabel: 'PRO TIER',
                  onTap: () => _navigateToSubpage(
                    BillingSettingsPage(userRole: widget.userRole),
                    'Subscription & Billing',
                  ),
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),
          ],

          // Help & Legal
          AppSettingsSectionBlock(
            title: 'Support & Legal',
            children: [
              SettingsNavRow(
                title: 'Help, Support & Changelog',
                subtitle: 'Desk ticketing, release notes, terms & privacy',
                icon: Icons.help_outline_rounded,
                onTap: () => _navigateToSubpage(const HelpAboutPage(), 'Help & Support'),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Logout Action Row
          SettingsNavRow(
            title: 'Log Out of Account',
            subtitle: 'End active session securely',
            icon: Icons.logout_rounded,
            isDestructive: true,
            onTap: _showLogoutDialog,
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
        ],
      ),
    );
  }
}
