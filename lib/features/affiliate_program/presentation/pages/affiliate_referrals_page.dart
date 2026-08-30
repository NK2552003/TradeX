import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Referrals: Complete list and analytics for referred traders, signup dates,
/// account status, and generated revenue.
class AffiliateReferralsPage extends StatelessWidget {
  const AffiliateReferralsPage({
    super.key,
    this.onOpenPayouts,
    this.onOpenMarketing,
  });

  final VoidCallback? onOpenPayouts;
  final VoidCallback? onOpenMarketing;

  @override
  Widget build(BuildContext context) => AppPageBlock(
    title: 'Referrals',
    subtitle: 'Referred Traders & Accounts',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: const UiEmptyState(
          icon: Icons.people_alt_rounded,
          title: 'Referral Accounts',
          message:
              'This screen will display detailed records of all traders who registered using your referral code, their trading volume, and commission generated.',
        ),
      ),
    ),
  );
}
