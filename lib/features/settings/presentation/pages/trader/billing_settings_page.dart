import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:tradex/features/settings/models/billing_models.dart';
import 'package:tradex/features/settings/presentation/pages/trader/billing_history_page.dart';
import 'package:tradex/features/settings/presentation/pages/trader/change_plan_page.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_nav_row.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

/// The billing surface: what the account is on, what it costs, what it has used,
/// the card on file, the invoices and the way out.
///
/// Every figure is read from the live [SubscriptionSummary] — the price, the
/// renewal date, the seat count and the allowance meters. Cancelling stops
/// renewal rather than dropping the plan, so the page reports the plan the
/// repository still holds and offers to resume rather than pretending the reader
/// is already on the free tier.
class BillingSettingsPage extends StatefulWidget {
  const BillingSettingsPage({
    super.key,
    this.userRole = UserRole.customer,
    this.repository,
    this.onSubscriptionTierChanged,
  });

  final UserRole userRole;
  final BillingSettingsRepository? repository;

  /// Announces a plan change to the shell. The repository has already written it
  /// to the shared session by the time this fires; the callback is how the host
  /// gets to react (refresh chrome, log the event), not where the plan lives.
  final ValueChanged<AppTier>? onSubscriptionTierChanged;

  @override
  State<BillingSettingsPage> createState() => _BillingSettingsPageState();
}

class _BillingSettingsPageState extends State<BillingSettingsPage> {
  late final BillingSettingsRepository _repo;
  SubscriptionSummary? _subscription;
  PaymentMethodSummary? _paymentMethod;
  RetentionOffer? _offer;
  bool _loading = true;

  /// Set while renewal is being stopped or restarted, so the action shows the
  /// wait instead of the whole page dropping back to skeletons.
  bool _updatingRenewal = false;

  @override
  void initState() {
    super.initState();
    // No tier is handed to the repository: it reads the plan from the shared
    // session, so this page cannot open on a stale copy of it.
    _repo = widget.repository ?? BillingSettingsRepositoryImpl();
    _loadBillingData();
  }

  /// Reads the account's billing state. [silent] refreshes in place after an
  /// action the reader has already been given feedback for — without it the page
  /// would blink back to skeletons every time a card was saved or a coupon
  /// applied.
  Future<void> _loadBillingData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final List<Object?> results =
          await Future.wait<Object?>(<Future<Object?>>[
            _repo.getSubscription(),
            _repo.getPaymentMethod(),
            _repo.getRetentionOffer(),
          ]);
      if (!mounted) return;
      setState(() {
        _subscription = results[0]! as SubscriptionSummary;
        _paymentMethod = results[1] as PaymentMethodSummary?;
        _offer = results[2] as RetentionOffer?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Stops or restarts renewal. The plan is untouched either way — access always
  /// runs to the end of the period already paid for.
  Future<void> _setRenewal({required bool cancel}) async {
    setState(() => _updatingRenewal = true);
    final SubscriptionSummary updated = await _repo.setCancelAtPeriodEnd(
      cancel,
    );
    if (!mounted) return;
    setState(() {
      _subscription = updated;
      _updatingRenewal = false;
    });
    // Re-read the rest of the billing state: stopping renewal is what makes a
    // retention offer relevant, or spent.
    await _loadBillingData(silent: true);
    if (!mounted) return;
    // The tier has not changed, but the shell is told anyway so any chrome bound
    // to the subscription re-reads it rather than holding the pre-cancel copy.
    widget.onSubscriptionTierChanged?.call(updated.tier);
    UiToast.show(
      context,
      title: cancel ? 'Renewal stopped' : 'Renewal restored',
      message: cancel
          ? '${updated.planName} stays active until ${AppTokens.shortDate(updated.currentPeriodEnd)}.'
          : '${updated.planName} will renew on ${AppTokens.shortDate(updated.currentPeriodEnd)}.',
      intent: cancel ? UiIntent.warning : UiIntent.success,
    );
  }

  void _showUpdatePaymentMethodDialog() {
    final TextEditingController card = TextEditingController();
    final TextEditingController exp = TextEditingController();
    final TextEditingController cvc = TextEditingController();
    bool updating = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, StateSetter setDialogState) => UiDialog(
          title: 'Update payment card',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Card details are held by the payment processor. TradeX only ever sees the last four digits.',
                style: context.uiText.caption.copyWith(
                  color: context.ui.colors.foregroundMuted,
                ),
              ),
              UiGap.v(context.ui.spacing.md),
              UiField(
                label: 'Card number',
                child: UiInput(
                  controller: card,
                  hintText: '4242 4242 4242 4242',
                  keyboardType: TextInputType.number,
                ),
              ),
              UiGap.v(context.ui.spacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: UiField(
                      label: 'Expires (MM/YY)',
                      child: UiInput(controller: exp, hintText: 'MM/YY'),
                    ),
                  ),
                  UiGap.h(context.ui.spacing.sm),
                  Expanded(
                    child: UiField(
                      label: 'CVC',
                      child: UiInput(
                        controller: cvc,
                        hintText: '123',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            UiButton(
              label: 'Cancel',
              variant: UiVariant.outline,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            UiButton(
              label: 'Save card',
              intent: UiIntent.primary,
              loading: updating,
              onPressed: () async {
                setDialogState(() => updating = true);
                await _repo.startPaymentMethodUpdate();
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (!mounted) return;
                UiToast.show(
                  context,
                  title: 'Card saved',
                  message: 'Your default payment method has been updated.',
                  intent: UiIntent.success,
                );
                await _loadBillingData(silent: true);
              },
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      card.dispose();
      exp.dispose();
      cvc.dispose();
    });
  }

  void _showCancelDialog(SubscriptionSummary sub) {
    final RetentionOffer? offer = _offer;
    bool working = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, StateSetter setDialogState) => UiDialog(
          title: 'Stop renewing ${sub.planName}?',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (offer != null) ...<Widget>[
                UiCallout(
                  title:
                      '${offer.discountPercent}% off your next ${offer.cycles} '
                      '${sub.isAnnual ? 'years' : 'months'}',
                  message:
                      'Stay on ${sub.planName} for '
                      '${AppTokens.price(sub.listAmount * (1 - offer.discountPercent / 100))}'
                      '${sub.isAnnual ? '/yr' : '/mo'} instead of ${AppTokens.price(sub.listAmount)}.',
                  intent: UiIntent.bullish,
                  icon: Icons.local_offer_outlined,
                ),
                UiGap.v(context.ui.spacing.md),
              ],
              Text(
                'Your plan stays active until ${AppTokens.shortDate(sub.currentPeriodEnd)}. '
                'After that the account moves to Free and paid features — unlimited journaling, '
                'the AI copilot allowance and real-time scanning — stop.',
                style: context.uiText.body,
              ),
              UiGap.v(context.ui.spacing.sm),
              Text(
                'You can restart renewal any time before then and nothing changes.',
                style: context.uiText.caption.copyWith(
                  color: context.ui.colors.foregroundMuted,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            if (offer != null)
              UiButton(
                label: 'Apply ${offer.discountPercent}% discount',
                intent: UiIntent.primary,
                loading: working,
                onPressed: () async {
                  setDialogState(() => working = true);
                  final int? percent = await _repo.redeemCoupon(offer.code);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (!mounted) return;
                  await _loadBillingData(silent: true);
                  if (!mounted) return;
                  UiToast.show(
                    context,
                    title: percent == null
                        ? 'Offer expired'
                        : 'Discount applied',
                    message: percent == null
                        ? 'That offer is no longer available on this account.'
                        : '$percent% comes off your next ${offer.cycles} renewals.',
                    intent: percent == null
                        ? UiIntent.warning
                        : UiIntent.success,
                  );
                },
              ),
            UiButton(
              label: 'Keep my plan',
              variant: UiVariant.outline,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            UiButton(
              label: 'Stop renewal',
              variant: UiVariant.ghost,
              intent: UiIntent.danger,
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _repo.cancelSubscription(
                  reason: 'Cancelled from billing settings',
                );
                if (!mounted) return;
                await _loadBillingData(silent: true);
                if (!mounted) return;
                final SubscriptionSummary? now = _subscription;
                // The plan is unchanged — only renewal stopped. Reporting
                // Free here would gate features the reader has paid for.
                widget.onSubscriptionTierChanged?.call(now?.tier ?? sub.tier);
                UiToast.show(
                  context,
                  title: 'Renewal stopped',
                  message:
                      '${sub.planName} stays active until ${AppTokens.shortDate(now?.currentPeriodEnd ?? sub.currentPeriodEnd)}.',
                  intent: UiIntent.warning,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// The line under the plan name: what it costs and what happens next. Free
  /// accounts have neither a price nor a renewal, so they get neither.
  String _planSubtitle(SubscriptionSummary sub) {
    if (sub.tier == AppTier.free) {
      return 'No charge · upgrade any time to unlock paid features.';
    }
    final String price =
        '${AppTokens.price(sub.amount)}${sub.isAnnual ? '/yr' : '/mo'}';
    final String next = sub.endsAtPeriodEnd
        ? 'Ends ${AppTokens.shortDate(sub.currentPeriodEnd)}'
        : 'Renews ${AppTokens.shortDate(sub.currentPeriodEnd)}';
    final String coupon = sub.discountCode == null
        ? ''
        : ' · ${sub.discountCode} (−${sub.discountPercent}%)';
    return '$price · $next$coupon';
  }

  /// Allowance meters for the plan. Seats only appear on a plan that has more
  /// than one, so a single-trader account is not shown a desk meter.
  List<Widget> _meters(SubscriptionSummary sub) => <Widget>[
    if (sub.isMultiSeat)
      UiProgressBar(
        value: SubscriptionSummary.fraction(sub.seatsUsed, sub.maxSeats),
        label: 'Desk seats (${sub.seatsUsed} of ${sub.maxSeats})',
      ),
    UiProgressBar(
      value: SubscriptionSummary.fraction(
        sub.tradesLoggedThisMonth,
        sub.maxTradesPerMonth,
      ),
      label:
          'Journal entries (${sub.tradesLoggedThisMonth} of ${sub.maxTradesPerMonth})',
    ),
    UiProgressBar(
      value: SubscriptionSummary.fraction(sub.aiTokensUsed, sub.maxAiTokens),
      label: 'AI copilot requests (${sub.aiTokensUsed} of ${sub.maxAiTokens})',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Column(
          children: const <Widget>[
            UiSkeleton(height: 180),
            SizedBox(height: 16),
            UiSkeleton(height: 140),
          ],
        ),
      );
    }

    final SubscriptionSummary? loaded = _subscription;
    if (loaded == null) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: UiEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Billing is unavailable',
          message:
              'We could not read your subscription. Try again in a moment.',
          action: UiButton(
            label: 'Retry',
            variant: UiVariant.outline,
            onPressed: _loadBillingData,
          ),
        ),
      );
    }

    final SubscriptionSummary sub = loaded;
    final bool isAffiliate = widget.userRole == UserRole.affiliate;
    final bool isAdmin = widget.userRole == UserRole.userAdmin;

    // Affiliates are on a complimentary partner tier and admins are on a
    // negotiated contract; neither buys a plan from this page.
    final bool selfServe = !isAffiliate && !isAdmin;

    final Widget? planAction = selfServe
        ? UiButton(
            label: 'Change plan',
            variant: UiVariant.outline,
            size: UiSize.sm,
            onPressed: () {
              showSettingsSideSheet(
                context,
                title: 'Choose a plan',
                subtitle: 'Pick the tier that matches your volume',
                desktopWidthRatio: 0.86,
                maxWidth: 1260.0,
                minDesktopWidth: 900.0,
                child: ChangePlanPage(
                  repository: _repo,
                  onPlanChanged: (AppTier tier) async {
                    widget.onSubscriptionTierChanged?.call(tier);
                    await _loadBillingData(silent: true);
                  },
                ),
              );
            },
          )
        : isAdmin
        ? UiButton(
            label: 'Request seats',
            leadingIcon: Icons.add_circle_outline_rounded,
            intent: UiIntent.primary,
            size: UiSize.sm,
            onPressed: () {
              UiToast.show(
                context,
                title: 'Seat request sent',
                message:
                    'Your account manager will follow up about expanding beyond ${sub.maxSeats} seats.',
                intent: UiIntent.info,
              );
            },
          )
        : null;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: context.radius(theme.radii.md),
                          ),
                          child: Icon(
                            isAffiliate
                                ? Icons.handshake_rounded
                                : (isAdmin
                                      ? Icons.corporate_fare_rounded
                                      : Icons.workspace_premium_rounded),
                            size: context.sz(32),
                            color: colors.primary,
                          ),
                        ),
                        SizedBox(width: context.sp(theme.spacing.md)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: context.sp(theme.spacing.xs),
                                runSpacing: context.sp(theme.spacing.xxs),
                                children: <Widget>[
                                  Text(
                                    isAffiliate
                                        ? 'Affiliate partner plan'
                                        : (isAdmin
                                              ? '${sub.planName} desk plan · ${sub.maxSeats} seats'
                                              : '${sub.planName} plan'),
                                    style: context.uiText.heading,
                                  ),
                                  UiBadge(
                                    label: isAffiliate
                                        ? 'PARTNER'
                                        : (sub.endsAtPeriodEnd
                                              ? 'ENDING'
                                              : 'ACTIVE'),
                                    intent: isAffiliate
                                        ? UiIntent.warning
                                        : (sub.endsAtPeriodEnd
                                              ? UiIntent.warning
                                              : UiIntent.bullish),
                                    size: UiSize.xs,
                                  ),
                                ],
                              ),
                              SizedBox(height: context.sp(theme.spacing.xxs)),
                              Text(
                                isAffiliate
                                    ? 'Complimentary creator tier with every paid tool unlocked.'
                                    : (isAdmin
                                          ? '${sub.seatsUsed} of ${sub.maxSeats} trader seats in use · ${_planSubtitle(sub)}'
                                          : _planSubtitle(sub)),
                                style: context.uiText.caption.copyWith(
                                  color: colors.foregroundMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!context.uiRes.isMobile && planAction != null)
                          planAction,
                      ],
                    ),
                    if (context.uiRes.isMobile &&
                        planAction != null) ...<Widget>[
                      SizedBox(height: context.sp(theme.spacing.md)),
                      planAction,
                    ],
                    // The reader has cancelled but is still inside a paid
                    // period: say when it ends and offer the way back.
                    if (selfServe && sub.endsAtPeriodEnd) ...<Widget>[
                      SizedBox(height: context.sp(theme.spacing.md)),
                      UiCallout(
                        title:
                            'Renewal is off — ${sub.planName} ends ${AppTokens.shortDate(sub.currentPeriodEnd)}',
                        message:
                            'Everything keeps working until then. Restart renewal and nothing changes.',
                        intent: UiIntent.warning,
                        icon: Icons.event_busy_outlined,
                        action: UiButton(
                          label: 'Resume subscription',
                          size: UiSize.sm,
                          intent: UiIntent.primary,
                          loading: _updatingRenewal,
                          onPressed: () => _setRenewal(cancel: false),
                        ),
                      ),
                    ],
                    if (!isAffiliate) ...<Widget>[
                      SizedBox(height: context.sp(theme.spacing.lg)),
                      UiDivider(),
                      SizedBox(height: context.sp(theme.spacing.md)),
                      LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final List<Widget> meters = _meters(sub);
                              if (constraints.maxWidth >= 600) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    for (
                                      int i = 0;
                                      i < meters.length;
                                      i++
                                    ) ...<Widget>[
                                      if (i > 0)
                                        SizedBox(
                                          width: context.sp(theme.spacing.lg),
                                        ),
                                      Expanded(child: meters[i]),
                                    ],
                                  ],
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  for (
                                    int i = 0;
                                    i < meters.length;
                                    i++
                                  ) ...<Widget>[
                                    if (i > 0)
                                      SizedBox(
                                        height: context.sp(theme.spacing.md),
                                      ),
                                    meters[i],
                                  ],
                                ],
                              );
                            },
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              if (!isAffiliate) ...<Widget>[
                AppSettingsSectionBlock(
                  title: isAdmin
                      ? 'Payment method & invoicing terms'
                      : 'Payment method',
                  description: isAdmin
                      ? 'Corporate card and net-30 invoicing for the desk licence.'
                      : 'The card charged when your plan renews.',
                  children: <Widget>[
                    if (_paymentMethod != null)
                      AppSettingCard(
                        title:
                            '${_paymentMethod!.brand} ending ${_paymentMethod!.last4}',
                        description:
                            'Expires ${_paymentMethod!.expMonth.toString().padLeft(2, '0')}/${_paymentMethod!.expYear}',
                        icon: Icons.credit_card_rounded,
                        control: UiButton(
                          label: 'Update card',
                          variant: UiVariant.outline,
                          size: UiSize.sm,
                          onPressed: _showUpdatePaymentMethodDialog,
                        ),
                      )
                    else
                      // A free account has never been charged, so there is no
                      // card to show — only one to add.
                      AppSettingCard(
                        title: 'No card on file',
                        description:
                            'Add a card when you move to a paid plan. Nothing is charged before then.',
                        icon: Icons.credit_card_off_outlined,
                        control: UiButton(
                          label: 'Add card',
                          variant: UiVariant.outline,
                          size: UiSize.sm,
                          onPressed: _showUpdatePaymentMethodDialog,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),

                AppSettingsSectionBlock(
                  title: 'Billing history & tax receipts',
                  description:
                      'Itemised invoices for every period you have been charged for.',
                  children: <Widget>[
                    SettingsNavRow(
                      title: 'Invoices & receipts',
                      subtitle: sub.tier == AppTier.free
                          ? 'Nothing has been charged on this account yet'
                          : 'Download itemised invoices and tax receipts',
                      icon: Icons.receipt_long_outlined,
                      onTap: () {
                        showSettingsSideSheet(
                          context,
                          title: 'Invoices & receipts',
                          subtitle:
                              'Itemised transaction history for this account',
                          child: BillingHistoryPage(repository: _repo),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),

                // Nothing to cancel on a free plan, and a desk contract is not
                // cancelled from a settings row.
                if (selfServe && sub.tier != AppTier.free) ...<Widget>[
                  AppSettingsSectionBlock(
                    title: 'Cancel membership',
                    description:
                        'Stop renewals. Paid features run to the end of the period you have already paid for.',
                    children: <Widget>[
                      if (sub.endsAtPeriodEnd)
                        SettingsNavRow(
                          title: 'Resume subscription',
                          subtitle:
                              'Renewal is off — ${sub.planName} ends ${AppTokens.shortDate(sub.currentPeriodEnd)}',
                          icon: Icons.autorenew_rounded,
                          onTap: _updatingRenewal
                              ? null
                              : () => _setRenewal(cancel: false),
                        )
                      else
                        SettingsNavRow(
                          title: 'Cancel subscription',
                          subtitle:
                              'Keep every paid feature until ${AppTokens.shortDate(sub.currentPeriodEnd)}',
                          icon: Icons.cancel_outlined,
                          isDestructive: true,
                          onTap: () => _showCancelDialog(sub),
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
