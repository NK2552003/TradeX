import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// User roles in TraderHub TradeX platform.
enum UserRole {
  customer(
    id: 'customer',
    label: 'Customer',
    shortTitle: 'Trader',
    subtitle: 'Standard trading account & portfolio tools',
    icon: Icons.person_outline_rounded,
    badgeIntent: UiIntent.primary,
  ),
  affiliate(
    id: 'affiliate',
    label: 'Affiliate',
    shortTitle: 'Affiliate',
    subtitle: 'Referral tracking, payouts & partner portal',
    icon: Icons.handshake_outlined,
    badgeIntent: UiIntent.warning,
  ),
  userAdmin(
    id: 'user_admin',
    label: 'User Admin',
    shortTitle: 'Admin',
    subtitle: 'Administrative dashboard & security management',
    icon: Icons.admin_panel_settings_outlined,
    badgeIntent: UiIntent.danger,
  );

  const UserRole({
    required this.id,
    required this.label,
    required this.shortTitle,
    required this.subtitle,
    required this.icon,
    required this.badgeIntent,
  });

  final String id;
  String get dbValue => id;
  final String label;
  final String shortTitle;
  final String subtitle;
  final IconData icon;
  final UiIntent badgeIntent;

  static UserRole fromId(String id) {
    return UserRole.values.firstWhere(
      (r) => r.id == id,
      orElse: () => UserRole.customer,
    );
  }
}
