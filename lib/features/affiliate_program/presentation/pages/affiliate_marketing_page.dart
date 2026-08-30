import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Marketing: Unique tracking links, campaign slugs, QR codes, and promotional banners.
class AffiliateMarketingPage extends StatelessWidget {
  const AffiliateMarketingPage({
    super.key,
    this.onOpenReferrals,
    this.onOpenPayouts,
  });

  final VoidCallback? onOpenReferrals;
  final VoidCallback? onOpenPayouts;

  @override
  Widget build(BuildContext context) => AppPageBlock(
    title: 'Marketing Assets',
    subtitle: 'Campaign Links & Banners',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: const UiEmptyState(
          icon: Icons.campaign_rounded,
          title: 'Marketing & Tracking Links',
          message:
              'This screen will provide customizable tracking links, promo banners, social share buttons, and QR codes for affiliate campaigns.',
        ),
      ),
    ),
  );
}
