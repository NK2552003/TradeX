import 'package:flutter/material.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/home/presentation/pages/admin/admin_landing_page.dart';
import 'package:tradex/features/home/presentation/pages/affiliate/affiliate_landing_page.dart';
import 'package:tradex/features/home/presentation/pages/trader/trader_landing_page.dart';

/// Role-aware landing page dispatcher.
/// Routes dynamically to the dedicated [TraderLandingPage], [AffiliateLandingPage],
/// or [AdminLandingPage] based on the authenticated user's role.
class UserRoleLandingPage extends StatelessWidget {
  const UserRoleLandingPage({
    super.key,
    required this.userRole,
    required this.userEmail,
    required this.onNavigateToSettings,
  });

  final UserRole userRole;
  final String userEmail;
  final VoidCallback onNavigateToSettings;

  @override
  Widget build(BuildContext context) {
    switch (userRole) {
      case UserRole.customer:
        return TraderLandingPage(
          userEmail: userEmail,
          onNavigateToSettings: onNavigateToSettings,
        );

      case UserRole.affiliate:
        return AffiliateLandingPage(
          userEmail: userEmail,
          onNavigateToSettings: onNavigateToSettings,
        );

      case UserRole.userAdmin:
        return AdminLandingPage(
          userEmail: userEmail,
          onNavigateToSettings: onNavigateToSettings,
        );
    }
  }
}
