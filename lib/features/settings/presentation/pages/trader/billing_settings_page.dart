import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:tradex/features/settings/models/billing_models.dart';
import 'package:tradex/features/settings/presentation/pages/trader/billing_history_page.dart';
import 'package:tradex/features/settings/presentation/pages/trader/change_plan_page.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_nav_row.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

class BillingSettingsPage extends StatefulWidget {
  const BillingSettingsPage({
    super.key,
    this.userRole = UserRole.customer,
    this.repository,
  });

  final UserRole userRole;
  final BillingSettingsRepository? repository;

  @override
  State<BillingSettingsPage> createState() => _BillingSettingsPageState();
}

class _BillingSettingsPageState extends State<BillingSettingsPage> {
  late final BillingSettingsRepository _repo;
  SubscriptionSummary? _subscription;
  PaymentMethodSummary? _paymentMethod;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BillingSettingsRepositoryImpl();
    _loadBillingData();
  }

  Future<void> _loadBillingData() async {
    setState(() => _loading = true);
    try {
      final sub = await _repo.getSubscription();
      final pm = await _repo.getPaymentMethod();
      if (mounted) {
        setState(() {
          _subscription = sub;
          _paymentMethod = pm;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showUpdatePaymentMethodDialog() {
    final cardNumberController = TextEditingController(text: '4242 •••• •••• 4242');
    final expController = TextEditingController(text: '12/28');
    final cvcController = TextEditingController(text: '•••');
    bool updating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => UiDialog(
          title: 'Update Payment Card',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your payment details are stored and encrypted securely by Stripe.',
                style: context.uiText.caption.copyWith(color: context.ui.colors.foregroundMuted),
              ),
              SizedBox(height: context.sp(context.ui.spacing.md)),
              UiField(
                label: 'Card Number',
                child: UiInput(
                  value: cardNumberController.text,
                  hintText: '4242 4242 4242 4242',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => cardNumberController.text = v,
                ),
              ),
              SizedBox(height: context.sp(context.ui.spacing.sm)),
              Row(
                children: [
                  Expanded(
                    child: UiField(
                      label: 'Expires (MM/YY)',
                      child: UiInput(
                        value: expController.text,
                        hintText: 'MM/YY',
                        onChanged: (v) => expController.text = v,
                      ),
                    ),
                  ),
                  SizedBox(width: context.sp(context.ui.spacing.sm)),
                  Expanded(
                    child: UiField(
                      label: 'CVC / CVV',
                      child: UiInput(
                        value: cvcController.text,
                        hintText: '123',
                        onChanged: (v) => cvcController.text = v,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            UiButton(
              label: 'Cancel',
              variant: UiVariant.outline,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            UiButton(
              label: 'Save Card',
              intent: UiIntent.primary,
              loading: updating,
              onPressed: () async {
                setDialogState(() => updating = true);
                await Future<void>.delayed(const Duration(milliseconds: 600));
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  UiToast.show(
                    context,
                    title: 'Card Saved',
                    message: 'Your default payment method has been updated.',
                    intent: UiIntent.success,
                  );
                  _loadBillingData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelSubscriptionRetentionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => UiDialog(
        title: 'Before you cancel your membership...',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiCallout(
              title: 'Special Retention Offer: 50% Off for 3 Months',
              message:
                  'We value your trading journey. Stay on TradeX Pro for just ₹1,249/month for the next 3 billing cycles.',
              intent: UiIntent.bullish,
            ),
            SizedBox(height: context.sp(context.ui.spacing.md)),
            Text(
              'If you proceed with cancellation, you will lose access to unlimited AI trade setups and high-speed scanner feeds at the end of your billing cycle on ${_subscription?.currentPeriodEnd.year}-${_subscription?.currentPeriodEnd.month}-${_subscription?.currentPeriodEnd.day}.',
              style: context.uiText.body,
            ),
          ],
        ),
        actions: [
          UiButton(
            label: 'Claim 50% Discount',
            intent: UiIntent.primary,
            variant: UiVariant.primary,
            onPressed: () {
              Navigator.of(ctx).pop();
              UiToast.show(
                context,
                title: 'Discount Applied!',
                message: 'Your 50% promotion will apply to your next 3 renewals.',
                intent: UiIntent.success,
              );
            },
          ),
          UiButton(
            label: 'Confirm Cancellation',
            variant: UiVariant.ghost,
            intent: UiIntent.danger,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _repo.cancelSubscription(reason: 'User elected to cancel from settings');
              await _loadBillingData();
              if (mounted) {
                UiToast.show(
                  context,
                  title: 'Subscription Canceled',
                  message: 'Your subscription has been canceled and will end at the current period end.',
                  intent: UiIntent.warning,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Column(
          children: const [
            UiSkeleton(height: 180),
            SizedBox(height: 16),
            UiSkeleton(height: 140),
          ],
        ),
      );
    }

    final sub = _subscription!;
    final isAffiliate = widget.userRole == UserRole.affiliate;
    final isAdmin = widget.userRole == UserRole.userAdmin;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // Plan overview card
          UiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: context.radius(theme.radii.md),
                      ),
                      child: Icon(
                        isAffiliate
                            ? Icons.handshake_rounded
                            : (isAdmin ? Icons.corporate_fare_rounded : Icons.workspace_premium_rounded),
                        size: context.sz(32),
                        color: colors.primary,
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isAffiliate
                                    ? 'Affiliate Partner Plan'
                                    : (isAdmin ? 'Enterprise Desk Plan (25 Seats)' : '${sub.planName} Plan'),
                                style: context.uiText.heading,
                              ),
                              SizedBox(width: context.sp(theme.spacing.xs)),
                              UiBadge(
                                label: isAffiliate
                                    ? 'PARTNER'
                                    : (isAdmin ? 'ENTERPRISE' : sub.status.toUpperCase()),
                                intent: isAffiliate
                                    ? UiIntent.warning
                                    : (isAdmin ? UiIntent.danger : UiIntent.bullish),
                                size: UiSize.xs,
                              ),
                            ],
                          ),
                          SizedBox(height: context.sp(theme.spacing.xxs)),
                          Text(
                            isAffiliate
                                ? '100% Complimentary lifetime creator tier with all Pro tools unlocked.'
                                : (isAdmin
                                    ? 'Custom enterprise contract · 18/25 active trader seats utilized.'
                                    : '₹${sub.amount.toInt()}/${sub.billingCycle} · Renews on ${sub.currentPeriodEnd.year}-${sub.currentPeriodEnd.month.toString().padLeft(2, '0')}-${sub.currentPeriodEnd.day.toString().padLeft(2, '0')}'),
                            style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
                          ),
                        ],
                      ),
                    ),
                    if (!isAffiliate && !isAdmin)
                      UiButton(
                        label: 'Change Plan',
                        variant: UiVariant.outline,
                        size: UiSize.sm,
                        onPressed: () {
                          showSettingsSideSheet(
                            context,
                            title: 'Choose Subscription Plan',
                            subtitle: 'Select an execution tier tailored to your volume',
                            child: ChangePlanPage(repository: _repo),
                          );
                        },
                      ),
                    if (isAdmin)
                      UiButton(
                        label: 'Add Trader Seats',
                        leadingIcon: Icons.add_circle_outline_rounded,
                        intent: UiIntent.primary,
                        size: UiSize.sm,
                        onPressed: () {
                          UiToast.show(
                            context,
                            title: 'Seat Expansion',
                            message: 'Enterprise license expansion requested. Account manager will follow up.',
                            intent: UiIntent.info,
                          );
                        },
                      ),
                  ],
                ),
                if (!isAffiliate) ...[
                  SizedBox(height: context.sp(theme.spacing.lg)),
                  UiDivider(),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final p1 = UiProgressBar(
                        value: isAdmin ? 0.72 : (sub.tradesLoggedThisMonth / sub.maxTradesPerMonth),
                        label: isAdmin
                            ? 'Active Desk Seats (18 of 25)'
                            : 'Monthly Trades Logged (${sub.tradesLoggedThisMonth} of ${sub.maxTradesPerMonth})',
                      );
                      final p2 = UiProgressBar(
                        value: isAdmin ? 0.45 : (sub.aiTokensUsed / sub.maxAiTokens),
                        label: isAdmin
                            ? 'Enterprise API Capacity (45% of 10M)'
                            : 'AI Market Queries (${sub.aiTokensUsed} of ${sub.maxAiTokens})',
                      );

                      if (constraints.maxWidth >= 600) {
                        return Row(
                          children: [
                            Expanded(child: p1),
                            SizedBox(width: context.sp(theme.spacing.lg)),
                            Expanded(child: p2),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            p1,
                            SizedBox(height: context.sp(theme.spacing.md)),
                            p2,
                          ],
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Payment method & Invoices
          if (!isAffiliate) ...[
            AppSettingsSectionBlock(
              title: isAdmin ? 'Payment Method & Invoicing Terms' : 'Payment Method',
              description: isAdmin
                  ? 'Manage corporate card and net-30 enterprise invoicing terms.'
                  : 'Manage credit or debit card used for automatic recurring renewals.',
              children: [
                if (_paymentMethod != null)
                  AppSettingCard(
                    title: '${_paymentMethod!.brand} ending in ${_paymentMethod!.last4}',
                    description: 'Expires ${_paymentMethod!.expMonth}/${_paymentMethod!.expYear}',
                    icon: Icons.credit_card_rounded,
                    control: UiButton(
                      label: 'Update Card',
                      variant: UiVariant.outline,
                      size: UiSize.sm,
                      onPressed: _showUpdatePaymentMethodDialog,
                    ),
                  ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),

            // Invoices and Cancellation
            AppSettingsSectionBlock(
              title: 'Billing History & Tax Receipts',
              description: 'Download PDF tax invoices and itemized payment breakdowns.',
              children: [
                SettingsNavRow(
                  title: 'Invoices & Payment Receipts',
                  subtitle: 'View itemized transaction history and download official PDFs',
                  icon: Icons.receipt_long_outlined,
                  onTap: () {
                    showSettingsSideSheet(
                      context,
                      title: 'Invoices & Receipts',
                      subtitle: 'Download official transaction receipts and tax invoices',
                      child: BillingHistoryPage(repository: _repo),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),

            if (!isAdmin) ...[
              AppSettingsSectionBlock(
                title: 'Cancel Membership',
                description: 'End subscription renewals and downgrade to the free tier.',
                children: [
                  SettingsNavRow(
                    title: 'Cancel Subscription',
                    subtitle: 'Keep active features until the end of the current billing cycle',
                    icon: Icons.cancel_outlined,
                    isDestructive: true,
                    onTap: _showCancelSubscriptionRetentionDialog,
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    ),
  ),
);
  }
}
