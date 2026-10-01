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
    this.notificationTargets = const <String, String>{},
    this.upgradeSectionId = 'settings_billing',
  });

  final UserRole role;
  final String workspaceName;
  final String workspaceLabel;
  final List<AppNavSection> sections;
  final List<AppNavItem> mobilePrimaryItems;
  final List<AppNavItem> mobileMoreItems;
  final List<AppNavItem> userMenuItems;

  /// Notification category to the destination id that answers it. Navigation is
  /// this model's job, so the inbox asks here rather than deciding for itself; a
  /// category with no entry simply has nowhere to go for this role.
  final Map<String, String> notificationTargets;

  /// Where an upgrade prompt lands for this role. Plan gates appear on several
  /// surfaces, and every one of them should arrive at the same place.
  final String upgradeSectionId;

  /// Every destination this role can reach, including nested settings items.
  Iterable<AppNavItem> get destinations {
    Iterable<AppNavItem> flatten(Iterable<AppNavItem> items) sync* {
      for (final AppNavItem item in items) {
        yield item;
        if (item.subItems != null) yield* flatten(item.subItems!);
      }
    }

    return flatten(sections.expand((AppNavSection section) => section.items));
  }

  bool allows(String destinationId) =>
      destinations.any((AppNavItem item) => item.id == destinationId);

  /// Sidebar label of a destination, or null when this role cannot reach it.
  /// Used to describe a jump in the reader's own vocabulary instead of a
  /// second, hand-written copy of the same name.
  String? labelFor(String destinationId) {
    for (final AppNavItem item in destinations) {
      if (item.id == destinationId) return item.label;
    }
    return null;
  }

  /// Notification categories this role can act on, mapped to the label of the
  /// surface they open.
  Map<String, String> get notificationDestinations => <String, String>{
    for (final MapEntry<String, String> entry in notificationTargets.entries)
      if (labelFor(entry.value) != null) entry.key: labelFor(entry.value)!,
  };

  static RoleNavigationConfig forRole(UserRole role) {
    final base = switch (role) {
      UserRole.customer => _trader,
      UserRole.affiliate => _affiliate,
      UserRole.userAdmin => _admin,
    };
    return RoleNavigationConfig(
      role: base.role,
      workspaceName: base.workspaceName,
      workspaceLabel: base.workspaceLabel,
      sections: [
        ...base.sections.take(base.sections.length - 1),
        _marketSection,
        base.sections.last,
      ],
      mobilePrimaryItems: base.mobilePrimaryItems,
      mobileMoreItems: [...base.mobileMoreItems, _marketItem],
      userMenuItems: base.userMenuItems,
      notificationTargets: base.notificationTargets,
      upgradeSectionId: base.upgradeSectionId,
    );
  }

  static const _marketItem = AppNavItem(
    id: 'market',
    label: 'Market Intelligence',
    icon: Icons.public_outlined,
    selectedIcon: Icons.public,
    subItems: [
      AppNavItem(
        id: 'market_news',
        label: 'News',
        icon: Icons.newspaper_outlined,
      ),
      AppNavItem(
        id: 'market_movers',
        label: 'Gainers & Losers',
        icon: Icons.trending_up,
      ),
      AppNavItem(
        id: 'market_instruments',
        label: 'Instruments',
        icon: Icons.candlestick_chart_outlined,
      ),
      AppNavItem(
        id: 'market_screeners',
        label: 'Screeners',
        icon: Icons.filter_alt_outlined,
      ),
    ],
  );
  static const _marketSection = AppNavSection(
    title: 'Markets',
    items: [_marketItem],
  );

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
    upgradeSectionId: 'settings_billing',
    notificationTargets: <String, String>{
      'Alerts': 'community_feed',
      'AI': 'ai_copilot',
      'Community': 'community',
      'Strategies': 'strategies',
      'Billing': 'settings_billing',
      'Notes': 'notes',
    },
    mobilePrimaryItems: <AppNavItem>[
      AppNavItem(
        id: 'workspace',
        label: 'Writing Desk',
        icon: Icons.edit_note_outlined,
        selectedIcon: Icons.edit_note_rounded,
      ),
      AppNavItem(
        id: 'community',
        label: 'Community',
        icon: Icons.forum_outlined,
        selectedIcon: Icons.forum_rounded,
      ),
      AppNavItem(
        id: 'calculators',
        label: 'Calculators',
        icon: Icons.calculate_outlined,
        selectedIcon: Icons.calculate_rounded,
      ),
      _settingsDock,
    ],
    mobileMoreItems: <AppNavItem>[
      AppNavItem(
        id: 'calculators',
        label: 'Calculators',
        icon: Icons.calculate_outlined,
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
            id: 'workspace',
            label: 'Writing Desk',
            icon: Icons.edit_note_outlined,
            selectedIcon: Icons.edit_note_rounded,
            subItems: <AppNavItem>[
              AppNavItem(
                id: 'journal',
                label: 'Journal',
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
              ),
              AppNavItem(
                id: 'strategies',
                label: 'Strategies',
                icon: Icons.account_tree_outlined,
                selectedIcon: Icons.account_tree_rounded,
              ),
              AppNavItem(
                id: 'notes',
                label: 'Notes',
                icon: Icons.note_alt_outlined,
                selectedIcon: Icons.note_alt_rounded,
              ),
            ],
          ),
          AppNavItem(
            id: 'calculators',
            label: 'Calculators',
            icon: Icons.calculate_outlined,
            selectedIcon: Icons.calculate_rounded,
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
            subItems: <AppNavItem>[
              AppNavItem(
                id: 'community_feed',
                label: 'Feed',
                icon: Icons.dynamic_feed_outlined,
                selectedIcon: Icons.dynamic_feed_rounded,
              ),
              AppNavItem(
                id: 'community_explore',
                label: 'Explore',
                icon: Icons.explore_outlined,
                selectedIcon: Icons.explore_rounded,
              ),
              AppNavItem(
                id: 'community_network',
                label: 'Network',
                icon: Icons.group_outlined,
                selectedIcon: Icons.group_rounded,
              ),
              AppNavItem(
                id: 'community_profile',
                label: 'My Profile',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
              ),
              AppNavItem(
                id: 'community_bookmarks',
                label: 'Bookmarks',
                icon: Icons.bookmark_border_rounded,
                selectedIcon: Icons.bookmark_rounded,
              ),
            ],
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
    upgradeSectionId: 'settings_affiliate',
    notificationTargets: <String, String>{
      'AI': 'ai_copilot',
      'Community': 'community',
      'Billing': 'payouts',
      'Notes': 'notes',
    },
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
      AppNavItem(id: 'notes', label: 'Notes', icon: Icons.note_alt_outlined),
      AppNavItem(
        id: 'strategies',
        label: 'Strategies',
        icon: Icons.account_tree_outlined,
      ),
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
          AppNavItem(
            id: 'notes',
            label: 'Notes',
            icon: Icons.note_alt_outlined,
            selectedIcon: Icons.note_alt_rounded,
          ),
          AppNavItem(
            id: 'strategies',
            label: 'Strategies',
            icon: Icons.account_tree_outlined,
            selectedIcon: Icons.account_tree_rounded,
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
            subItems: <AppNavItem>[
              AppNavItem(
                id: 'community_feed',
                label: 'Feed',
                icon: Icons.dynamic_feed_outlined,
                selectedIcon: Icons.dynamic_feed_rounded,
              ),
              AppNavItem(
                id: 'community_explore',
                label: 'Explore',
                icon: Icons.explore_outlined,
                selectedIcon: Icons.explore_rounded,
              ),
              AppNavItem(
                id: 'community_network',
                label: 'Network',
                icon: Icons.group_outlined,
                selectedIcon: Icons.group_rounded,
              ),
              AppNavItem(
                id: 'community_profile',
                label: 'My Profile',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
              ),
              AppNavItem(
                id: 'community_bookmarks',
                label: 'Bookmarks',
                icon: Icons.bookmark_border_rounded,
                selectedIcon: Icons.bookmark_rounded,
              ),
            ],
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
    upgradeSectionId: 'settings_organization',
    notificationTargets: <String, String>{
      'AI': 'ai_copilot',
      'Risk': 'org_risk',
      'Alerts': 'org_audit',
      'Billing': 'settings_organization',
      'Notes': 'notes',
    },
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
        id: 'notes',
        label: 'Desk Notes',
        icon: Icons.note_alt_outlined,
      ),
      AppNavItem(
        id: 'strategies',
        label: 'Strategies',
        icon: Icons.account_tree_outlined,
      ),
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
        id: 'messages',
        label: 'Messages',
        icon: Icons.chat_bubble_outline_rounded,
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
          AppNavItem(
            id: 'notes',
            label: 'Desk Notes',
            icon: Icons.note_alt_outlined,
            selectedIcon: Icons.note_alt_rounded,
          ),
          AppNavItem(
            id: 'strategies',
            label: 'Strategies',
            icon: Icons.account_tree_outlined,
            selectedIcon: Icons.account_tree_rounded,
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
          AppNavItem(
            id: 'messages',
            label: 'Messages',
            icon: Icons.chat_bubble_outline_rounded,
            selectedIcon: Icons.chat_bubble_rounded,
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
