import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Payouts: Withdrawal requests, payment schedules, and commission statements.
class AffiliatePayoutsPage extends StatelessWidget {
  const AffiliatePayoutsPage({
    super.key,
    this.onOpenReferrals,
    this.onOpenSettings,
  });

  final VoidCallback? onOpenReferrals;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) => AppPageBlock(
    title: 'Payouts',
    subtitle: 'Withdrawals & Payment History',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: const UiEmptyState(
          icon: Icons.payments_rounded,
          title: 'Payouts & Settlement',
          message:
              'This screen will manage withdrawal requests, invoice generation, payout schedules, and bank/crypto payout methods.',
        ),
      ),
    ),
  );
}
