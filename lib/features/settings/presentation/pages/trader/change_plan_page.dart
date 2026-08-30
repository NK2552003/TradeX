import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:tradex/features/settings/models/billing_models.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_subpage_scope.dart';

/// The plan chooser: a billing-cycle toggle above the catalogue, and a checkout
/// sheet for the plan the reader picks.
///
/// Every number on this page is priced by the repository. Flipping the cycle
/// re-fetches the catalogue rather than doing arithmetic here, so the amount on
/// a card, the amount in the checkout sheet and the amount on the next invoice
/// are the same figure travelling from one place.
class ChangePlanPage extends StatefulWidget {
  const ChangePlanPage({super.key, this.repository, this.onPlanChanged});

  final BillingSettingsRepository? repository;
  final ValueChanged<AppTier>? onPlanChanged;

  @override
  State<ChangePlanPage> createState() => _ChangePlanPageState();
}

class _ChangePlanPageState extends State<ChangePlanPage> {
  late final BillingSettingsRepository _repo;
  SubscriptionSummary? _subscription;
  List<AppPlan> _plans = const <AppPlan>[];
  bool _loading = true;

  /// Set while the catalogue is being re-priced for a newly picked cycle. The
  /// plans already on screen stay put — only the toggle shows the wait, so the
  /// page does not blink back to skeletons on every tap.
  bool _repricing = false;

  /// 'monthly' | 'annual'. Starts monthly: it is the cycle the catalogue quotes
  /// its headline price in, so the reader is not shown a yearly total first.
  String _billingCycle = 'monthly';

  bool get _annual => _billingCycle == 'annual';

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BillingSettingsRepositoryImpl();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final List<Object?> results = await Future.wait<Object?>(
        <Future<Object?>>[
          _repo.getSubscription(),
          _repo.getAvailablePlans(annual: _annual),
        ],
      );
      if (!mounted) return;
      setState(() {
        _subscription = results[0]! as SubscriptionSummary;
        _plans = results[1]! as List<AppPlan>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Re-prices the catalogue for [cycle]. The prices are the repository's to
  /// quote, so the toggle asks for them again instead of multiplying the ones
  /// already on screen.
  Future<void> _setCycle(String cycle) async {
    if (cycle == _billingCycle || _repricing) return;
    setState(() {
      _billingCycle = cycle;
      _repricing = true;
    });
    try {
      final List<AppPlan> list = await _repo.getAvailablePlans(annual: _annual);
      if (!mounted) return;
      setState(() {
        _plans = list;
        _repricing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _repricing = false);
    }
  }

  /// What picking [plan] does to the current subscription — the checkout sheet
  /// is titled by this rather than always saying "upgrade".
  String _checkoutTitle(AppPlan plan) {
    final AppTier? from = _subscription?.tier;
    if (from == null || plan.tier == from) {
      return 'Switch to ${_annual ? 'annual' : 'monthly'} billing';
    }
    return plan.tier.index > from.index
        ? 'Upgrade to ${AppTokens.tierLabel(plan.tier)}'
        : 'Change to ${AppTokens.tierLabel(plan.tier)}';
  }

  void _showCheckoutDialog(AppPlan plan) {
    // Amount charged for the cycle being bought, with whatever coupon has been
    // accepted so far taken off. Both live in the sheet's own state so the page
    // behind it is not rewritten while the reader is still deciding.
    int discountPercent = _subscription?.discountPercent ?? 0;
    String? discountCode = _subscription?.discountCode;
    final TextEditingController coupon = TextEditingController();
    String? couponError;
    bool redeeming = false;
    bool processing = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, StateSetter setDialogState) {
          final double due = plan.amount * (1 - discountPercent / 100);
          final bool payable = plan.amount > 0;

          return UiDialog(
            title: _checkoutTitle(plan),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                UiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  AppTokens.tierLabel(plan.tier),
                                  style: context.uiText.bodyStrong,
                                ),
                                Text(
                                  payable
                                      ? 'Billed ${_annual ? 'yearly' : 'monthly'}'
                                      : 'No card required',
                                  style: context.uiText.caption.copyWith(
                                    color: context.ui.colors.foregroundMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${plan.priceLabel}${plan.period}',
                            style: context.uiText.heading.copyWith(
                              color: context.ui.colors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (discountPercent > 0) ...<Widget>[
                        UiGap.v(context.ui.spacing.sm),
                        UiDivider(),
                        UiGap.v(context.ui.spacing.sm),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Coupon $discountCode',
                                style: context.uiText.caption,
                              ),
                            ),
                            Text(
                              '-${AppTokens.price(plan.amount - due)}',
                              style: context.uiText.caption.copyWith(
                                color: context.ui.colors.bullish,
                              ),
                            ),
                          ],
                        ),
                        UiGap.v(context.ui.spacing.xs),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Due today',
                                style: context.uiText.bodyStrong,
                              ),
                            ),
                            Text(
                              AppTokens.price(due),
                              style: context.uiText.bodyStrong,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (payable) ...<Widget>[
                  UiGap.v(context.ui.spacing.md),
                  UiField(
                    label: 'Coupon code',
                    helper: couponError,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: UiInput(
                            controller: coupon,
                            hintText: 'Enter a code',
                            enabled: !redeeming,
                          ),
                        ),
                        UiGap.h(context.ui.spacing.sm),
                        UiButton(
                          label: 'Apply',
                          variant: UiVariant.outline,
                          loading: redeeming,
                          onPressed: () async {
                            final String code = coupon.text.trim();
                            if (code.isEmpty) return;
                            setDialogState(() {
                              redeeming = true;
                              couponError = null;
                            });
                            final int? percent = await _repo.redeemCoupon(code);
                            if (!dialogCtx.mounted) return;
                            setDialogState(() {
                              redeeming = false;
                              if (percent == null) {
                                couponError = 'That code is not valid.';
                              } else {
                                discountPercent = percent;
                                discountCode = code.toUpperCase();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  UiGap.v(context.ui.spacing.md),
                  Text(
                    'Payment details',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  UiGap.v(context.ui.spacing.xs),
                  UiField(
                    label: 'Card number',
                    child: UiInput(
                      hintText: '4242 4242 4242 4242',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  UiGap.v(context.ui.spacing.xs),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: UiField(
                          label: 'MM / YY',
                          child: UiInput(hintText: '12/28'),
                        ),
                      ),
                      UiGap.h(context.ui.spacing.sm),
                      Expanded(
                        child: UiField(
                          label: 'CVC',
                          child: UiInput(
                            hintText: '123',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                UiGap.v(context.ui.spacing.md),
                UiCallout(
                  title: payable ? 'Instant activation' : 'Downgrade to Free',
                  message: payable
                      ? 'Features unlock as soon as the payment clears. Cancel any time — access runs to the end of the period you paid for.'
                      : 'Paid features stay available until the end of the period you have already paid for.',
                  intent: payable ? UiIntent.info : UiIntent.warning,
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
                label: payable
                    ? 'Confirm & pay ${AppTokens.price(due)}'
                    : 'Confirm change',
                intent: UiIntent.primary,
                loading: processing,
                onPressed: () async {
                  setDialogState(() => processing = true);
                  try {
                    await _repo.startCheckout(plan.tier.name, _billingCycle);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (!mounted) return;
                    widget.onPlanChanged?.call(plan.tier);
                    UiToast.show(
                      context,
                      title: payable ? 'Plan active' : 'Plan changed',
                      message:
                          'You are now on TradeX ${AppTokens.tierLabel(plan.tier)}.',
                      intent: UiIntent.success,
                    );
                    closeSettingsSubpage(context);
                  } catch (_) {
                    if (!dialogCtx.mounted) return;
                    setDialogState(() => processing = false);
                    if (!mounted) return;
                    UiToast.show(
                      context,
                      title: 'Payment failed',
                      message:
                          'That card could not be charged. Try another card.',
                      intent: UiIntent.danger,
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    ).whenComplete(coupon.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    if (_loading) {
      return UiSkeleton.plans(count: 3);
    }

    final SubscriptionSummary? sub = _subscription;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool isMobile = context.uiRes.isMobile;
    final double bottomInset = isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : context.uiDockInset)
        : context.sp(theme.spacing.lg);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        bottomInset,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: UiToggleGroup<String>(
              value: _billingCycle,
              size: UiSize.sm,
              options: <UiToggleOption<String>>[
                const UiToggleOption<String>(
                  value: 'monthly',
                  label: 'Monthly',
                ),
                UiToggleOption<String>(
                  value: 'annual',
                  // The saving is the repository's figure, derived from the
                  // months an annual plan is actually billed for.
                  label: sub == null
                      ? 'Annual'
                      : 'Annual · save ${sub.annualSavingPercent}%',
                ),
              ],
              onChanged: _setCycle,
            ),
          ),
          if (_repricing) ...<Widget>[
            UiGap.v(theme.spacing.md),
            Center(
              child: Text(
                'Re-pricing plans…',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ),
          ],
          UiGap.v(theme.spacing.xl),
          AppPricingBlock(
            plans: _plans,
            title: 'Unlock next-gen institutional tools',
            onSelect: _repricing ? null : _showCheckoutDialog,
          ),
        ],
      ),
    );
  }
}
