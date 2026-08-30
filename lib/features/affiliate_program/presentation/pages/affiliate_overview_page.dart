import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Partner Hub: The affiliate's primary dashboard for tracking performance,
/// earnings, conversions, and referral links.
class AffiliateOverviewPage extends StatelessWidget {
  const AffiliateOverviewPage({
    super.key,
    this.onOpenReferrals,
    this.onOpenPayouts,
    this.onOpenMarketing,
  });

  final VoidCallback? onOpenReferrals;
  final VoidCallback? onOpenPayouts;
  final VoidCallback? onOpenMarketing;

  @override
  Widget build(BuildContext context) => AppPageBlock(
    title: 'Affiliate Overview',
    subtitle: 'Partner Performance & Earnings Hub',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: UiEmptyState(
          icon: Icons.insights_rounded,
          title: 'Affiliate Overview',
          message:
              'This screen will display your live commission earnings, referral link metrics, conversion rates, and channel performance summaries.',
          action: onOpenMarketing != null
              ? UiButton(
                  label: 'View Marketing Assets',
                  leadingIcon: Icons.campaign_rounded,
                  onPressed: onOpenMarketing,
                  expandOnMobile: false,
                )
              : null,
        ),
      ),
    ),
  );
}
