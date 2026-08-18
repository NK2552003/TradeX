import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required unified primitive import for navigation UI configuration.
// ignore: unused_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

/// Single source of truth for every role-aware navigation surface.
///
/// Sidebar sections, the four persistent mobile destinations, and the mobile
/// More hub all resolve from this model so a role cannot accidentally inherit
/// another role's controls.
@immutable
class RoleNavigationConfig {
  const RoleNavigationConfig({
    required this.role,
    required this.workspaceName,
    required this.workspaceLabel,
    required this.sections,
    required this.mobilePrimaryItems,
    required this.mobileMoreItems,
    required this.userMenuItems,
  });

  final UserRole role;
  final String workspaceName;
  final String workspaceLabel;
  final List<AppNavSection> sections;
  final List<AppNavItem> mobilePrimaryItems;
  final List<AppNavItem> mobileMoreItems;
  final List<AppNavItem> userMenuItems;

  bool allows(String destinationId) {
    Iterable<AppNavItem> flatten(Iterable<AppNavItem> items) sync* {
      for (final AppNavItem item in items) {
        yield item;
        if (item.subItems != null) yield* flatten(item.subItems!);
      }
    }

    return flatten(
      sections.expand((AppNavSection section) => section.items),
    ).any((AppNavItem item) => item.id == destinationId);
  }

  static RoleNavigationConfig forRole(UserRole role) => switch (role) {
    UserRole.customer => _trader,
    UserRole.affiliate => _affiliate,
    UserRole.userAdmin => _admin,
  };

  static const AppNavItem _profile = AppNavItem(
    id: 'settings_profile',
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  );

  static const AppNavItem _settingsDock = AppNavItem(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  );

  static const RoleNavigationConfig _trader = RoleNavigationConfig(
    role: UserRole.customer,
    workspaceName: 'TradeX Pro Terminal',
    workspaceLabel: 'Active Trader',
    mobilePrimaryItems: <AppNavItem>[
      AppNavItem(
        id: 'overview',
        label: 'Home',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
      ),
      AppNavItem(
        id: 'journal',
        label: 'Journal',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
      ),
      AppNavItem(
        id: 'community',
        label: 'Community',
        icon: Icons.forum_outlined,
        selectedIcon: Icons.forum_rounded,
      ),
      _settingsDock,
    ],
    mobileMoreItems: <AppNavItem>[
      AppNavItem(
        id: 'strategies',
        label: 'Strategy Notes',
        icon: Icons.account_tree_outlined,
      ),
      AppNavItem(
        id: 'watchlists',
        label: 'Watchlist',
        icon: Icons.visibility_outlined,
      ),
      AppNavItem(
        id: 'portfolio',
        label: 'Portfolio',
        icon: Icons.pie_chart_outline_rounded,
      ),
      AppNavItem(
        id: 'ai_copilot',
        label: 'AI Assistant',
        icon: Icons.auto_awesome_outlined,
      ),
      AppNavItem(
        id: 'messages',
        label: 'Messages',
        icon: Icons.chat_bubble_outline_rounded,
      ),
      AppNavItem(
        id: 'settings_billing',
        label: 'Subscription',
        icon: Icons.credit_card_outlined,
      ),
      AppNavItem(
        id: 'settings_affiliate_perks',
        label: 'Become Affiliate',
        icon: Icons.handshake_outlined,
      ),
    ],
    userMenuItems: <AppNavItem>[
      AppNavItem(
        id: 'settings_profile',
        label: 'Trader Profile',
        icon: Icons.person_outline_rounded,
      ),
      AppNavItem(
        id: 'settings_billing',
        label: 'Subscription & Billing',
        icon: Icons.credit_card_outlined,
      ),
    ],
    sections: <AppNavSection>[
      AppNavSection(
        title: 'Workspace',
        items: <AppNavItem>[
          AppNavItem(
            id: 'overview',
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
          ),
          AppNavItem(
            id: 'journal',
            label: 'Trade Journal',
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
          ),
          AppNavItem(
            id: 'strategies',
            label: 'Strategy Notes',
            icon: Icons.account_tree_outlined,
            selectedIcon: Icons.account_tree_rounded,
          ),
          AppNavItem(
            id: 'watchlists',
            label: 'Watchlist',
            icon: Icons.visibility_outlined,
            selectedIcon: Icons.visibility_rounded,
          ),
          AppNavItem(
            id: 'portfolio',
            label: 'Portfolio',
            icon: Icons.pie_chart_outline_rounded,
            selectedIcon: Icons.pie_chart_rounded,
          ),
        ],
      ),
      AppNavSection(
        title: 'Connect & Intelligence',
        items: <AppNavItem>[
          AppNavItem(
            id: 'community',
            label: 'Community',
            icon: Icons.forum_outlined,
            selectedIcon: Icons.forum_rounded,
          ),
          AppNavItem(
            id: 'messages',
            label: 'Messages',
            icon: Icons.chat_bubble_outline_rounded,
            selectedIcon: Icons.chat_bubble_rounded,
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
        title: 'Account',
        items: <AppNavItem>[
          AppNavItem(
            id: 'settings',
            label: 'Settings',
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            subItems: <AppNavItem>[
              _profile,
              AppNavItem(
                id: 'settings_security',
                label: 'Email & Security',
                icon: Icons.lock_outline_rounded,
              ),
              AppNavItem(
                id: 'settings_affiliate_perks',
                label: 'Become an Affiliate',
                icon: Icons.handshake_outlined,
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
                icon: Icons.security_outlined,
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
    ],
  );

  static const RoleNavigationConfig _affiliate = RoleNavigationConfig(
    role: UserRole.affiliate,
    workspaceName: 'Affiliate Partner Hub',
    workspaceLabel: 'Affiliate Partner',
    mobilePrimaryItems: <AppNavItem>[
      AppNavItem(
        id: 'overview',
        label: 'Hub',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
      ),
      AppNavItem(
        id: 'referrals',
        label: 'Referrals',
        icon: Icons.trending_up_rounded,
      ),
      AppNavItem(
        id: 'community',
        label: 'Community',
        icon: Icons.forum_outlined,
        selectedIcon: Icons.forum_rounded,
      ),
      _settingsDock,
    ],
    mobileMoreItems: <AppNavItem>[
      AppNavItem(
        id: 'marketing',
        label: 'Media Kit',
        icon: Icons.campaign_outlined,
      ),
      AppNavItem(
        id: 'payouts',
        label: 'Payouts',
        icon: Icons.account_balance_wallet_outlined,
      ),
      AppNavItem(
        id: 'ai_copilot',
        label: 'AI Assistant',
        icon: Icons.auto_awesome_outlined,
      ),
      AppNavItem(
        id: 'messages',
        label: 'Messages',
        icon: Icons.chat_bubble_outline_rounded,
      ),
      AppNavItem(
        id: 'settings_affiliate',
        label: 'Affiliate Settings',
        icon: Icons.handshake_outlined,
      ),
      AppNavItem(
        id: 'settings_security',
        label: 'Security',
        icon: Icons.lock_outline_rounded,
      ),
      AppNavItem(
        id: 'settings_help',
        label: 'Partner Help',
        icon: Icons.help_outline_rounded,
      ),
    ],
    userMenuItems: <AppNavItem>[
      AppNavItem(
        id: 'settings_profile',
        label: 'Partner Profile',
        icon: Icons.person_outline_rounded,
      ),
      AppNavItem(
        id: 'settings_affiliate',
        label: 'Affiliate & Payouts',
        icon: Icons.account_balance_wallet_outlined,
      ),
    ],
    sections: <AppNavSection>[
      AppNavSection(
        title: 'Partner Workspace',
        items: <AppNavItem>[
          AppNavItem(
            id: 'overview',
            label: 'Partner Hub',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
          ),
          AppNavItem(
            id: 'referrals',
            label: 'Referrals & Clicks',
            icon: Icons.trending_up_rounded,
          ),
          AppNavItem(
            id: 'marketing',
            label: 'Media Kit & Creatives',
            icon: Icons.campaign_outlined,
          ),
          AppNavItem(
            id: 'payouts',
            label: 'Payout History',
            icon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
      AppNavSection(
        title: 'Connect & Intelligence',
        items: <AppNavItem>[
          AppNavItem(
            id: 'community',
            label: 'Community',
            icon: Icons.forum_outlined,
            selectedIcon: Icons.forum_rounded,
          ),
          AppNavItem(
            id: 'messages',
            label: 'Messages',
            icon: Icons.chat_bubble_outline_rounded,
            selectedIcon: Icons.chat_bubble_rounded,
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
        title: 'Account',
        items: <AppNavItem>[
          AppNavItem(
            id: 'settings',
            label: 'Partner Settings',
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
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
                icon: Icons.security_outlined,
              ),
              AppNavItem(
                id: 'settings_appearance',
                label: 'Appearance',
                icon: Icons.palette_outlined,
              ),
              AppNavItem(
                id: 'settings_help',
                label: 'Partner Help',
                icon: Icons.help_outline_rounded,
              ),
            ],
          ),
        ],
      ),
    ],
  );

  static const RoleNavigationConfig _admin = RoleNavigationConfig(
    role: UserRole.userAdmin,
    workspaceName: 'Institutional Desk',
    workspaceLabel: 'Desk Administrator',
    mobilePrimaryItems: <AppNavItem>[
      AppNavItem(
        id: 'overview',
        label: 'Desk',
        icon: Icons.corporate_fare_outlined,
        selectedIcon: Icons.corporate_fare_rounded,
      ),
      AppNavItem(
        id: 'org_team',
        label: 'Team',
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups_rounded,
      ),
      AppNavItem(
        id: 'org_risk',
        label: 'Risk',
        icon: Icons.shield_outlined,
        selectedIcon: Icons.shield_rounded,
      ),
      _settingsDock,
    ],
    mobileMoreItems: <AppNavItem>[
      AppNavItem(
        id: 'org_audit',
        label: 'Execution Audit',
        icon: Icons.history_edu_outlined,
      ),
      AppNavItem(
        id: 'org_analytics',
        label: 'Desk Analytics',
        icon: Icons.analytics_outlined,
      ),
      AppNavItem(
        id: 'affiliate_reviews',
        label: 'Affiliate Reviews',
        icon: Icons.fact_check_outlined,
      ),
      AppNavItem(
        id: 'ai_copilot',
        label: 'AI Risk Assistant',
        icon: Icons.auto_awesome_outlined,
      ),
      AppNavItem(
        id: 'settings_organization',
        label: 'Organization',
        icon: Icons.apartment_outlined,
      ),
      AppNavItem(
        id: 'settings_desk_risk',
        label: 'Compliance',
        icon: Icons.policy_outlined,
      ),
      AppNavItem(
        id: 'settings_security',
        label: 'Admin Security',
        icon: Icons.admin_panel_settings_outlined,
      ),
      AppNavItem(
        id: 'settings_help',
        label: 'Priority Support',
        icon: Icons.support_agent_outlined,
      ),
    ],
    userMenuItems: <AppNavItem>[
      AppNavItem(
        id: 'settings_profile',
        label: 'Admin Profile',
        icon: Icons.person_outline_rounded,
      ),
      AppNavItem(
        id: 'settings_organization',
        label: 'Organization & Team',
        icon: Icons.apartment_outlined,
      ),
    ],
    sections: <AppNavSection>[
      AppNavSection(
        title: 'Institutional Desk',
        items: <AppNavItem>[
          AppNavItem(
            id: 'overview',
            label: 'Desk Console',
            icon: Icons.corporate_fare_outlined,
            selectedIcon: Icons.corporate_fare_rounded,
          ),
          AppNavItem(
            id: 'org_team',
            label: 'Traders & Seats',
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups_rounded,
          ),
          AppNavItem(
            id: 'org_risk',
            label: 'Risk Limits & Compliance',
            icon: Icons.shield_outlined,
            selectedIcon: Icons.shield_rounded,
          ),
          AppNavItem(
            id: 'org_audit',
            label: 'Execution Audit Log',
            icon: Icons.history_edu_outlined,
          ),
          AppNavItem(
            id: 'org_analytics',
            label: 'Organization Analytics',
            icon: Icons.analytics_outlined,
          ),
          AppNavItem(
            id: 'affiliate_reviews',
            label: 'Affiliate Applications',
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check_rounded,
          ),
        ],
      ),
      AppNavSection(
        title: 'Operations',
        items: <AppNavItem>[
          AppNavItem(
            id: 'ai_copilot',
            label: 'AI Risk Assistant',
            icon: Icons.auto_awesome_outlined,
            selectedIcon: Icons.auto_awesome_rounded,
          ),
        ],
      ),
      AppNavSection(
        title: 'Administration',
        items: <AppNavItem>[
          AppNavItem(
            id: 'settings',
            label: 'Admin Settings',
            icon: Icons.admin_panel_settings_outlined,
            selectedIcon: Icons.admin_panel_settings_rounded,
            subItems: <AppNavItem>[
              AppNavItem(
                id: 'settings_profile',
                label: 'Admin Profile',
                icon: Icons.person_outline_rounded,
              ),
              AppNavItem(
                id: 'settings_organization',
                label: 'Organization & Team',
                icon: Icons.apartment_outlined,
              ),
              AppNavItem(
                id: 'settings_desk_risk',
                label: 'Risk & Compliance',
                icon: Icons.policy_outlined,
              ),
              AppNavItem(
                id: 'settings_security',
                label: 'Admin Security',
                icon: Icons.lock_outline_rounded,
              ),
              AppNavItem(
                id: 'settings_notifications',
                label: 'Desk Alerts',
                icon: Icons.notifications_active_outlined,
              ),
              AppNavItem(
                id: 'settings_privacy',
                label: 'Audit Export',
                icon: Icons.inventory_2_outlined,
              ),
              AppNavItem(
                id: 'settings_appearance',
                label: 'Appearance',
                icon: Icons.palette_outlined,
              ),
              AppNavItem(
                id: 'settings_help',
                label: 'Institutional Support',
                icon: Icons.support_agent_outlined,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
