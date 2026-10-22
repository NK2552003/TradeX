import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:tradex/features/auth/models/pricing_models.dart';
import 'package:tradex/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:tradex/features/settings/models/billing_models.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_subpage_scope.dart';

/// Redesigned Claude-styled plan changer for Settings > Billing.
///
/// Features dynamic INR pricing, animated billing cycle toggle, 3 equal-height
/// tier cards, interactive checkout dialog with coupon redemption, and a
/// horizontally scrollable feature comparison matrix on mobile.
class ChangePlanPage extends StatefulWidget {
  const ChangePlanPage({
    super.key,
    this.repository,
    this.pricingRepository,
    this.onPlanChanged,
  });

  final BillingSettingsRepository? repository;
  final SubscriptionPricingRepository? pricingRepository;
  final ValueChanged<AppTier>? onPlanChanged;

  @override
  State<ChangePlanPage> createState() => _ChangePlanPageState();
}

class _ChangePlanPageState extends State<ChangePlanPage> {
  late final BillingSettingsRepository _billingRepo;
  late final SubscriptionPricingRepository _pricingRepo;

  SubscriptionSummary? _subscription;
  PricingCatalogueResponse? _catalogue;
  bool _loading = true;
  bool _repricing = false;
  bool _isAnnual = true;
  String? _processingTierId;

  @override
  void initState() {
    super.initState();
    _billingRepo = widget.repository ?? BillingSettingsRepositoryImpl();
    _pricingRepo =
        widget.pricingRepository ?? SubscriptionPricingRepositoryImpl();
    _isAnnual = AppSession.instance.billingCycle == 'annual';
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final List<Object?> results = await Future.wait<Object?>([
        _billingRepo.getSubscription(),
        _pricingRepo.getPricingCatalogue(annual: _isAnnual),
      ]);
      if (!mounted) return;
      setState(() {
        _subscription = results[0] as SubscriptionSummary?;
        _catalogue = results[1] as PricingCatalogueResponse?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleCycle(String cycle) async {
    final bool annual = cycle == 'annual';
    if (annual == _isAnnual || _repricing) return;

    setState(() {
      _isAnnual = annual;
      _repricing = true;
    });

    try {
      final PricingCatalogueResponse res = await _pricingRepo
          .getPricingCatalogue(annual: _isAnnual);
      if (!mounted) return;
      setState(() {
        _catalogue = res;
        _repricing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _repricing = false);
    }
  }

  void _showCheckoutDialog(PricingPlanModel plan) {
    int discountPercent = _subscription?.discountPercent ?? 0;
    String? discountCode = _subscription?.discountCode;
    final TextEditingController coupon = TextEditingController();
    String? couponError;
    bool redeeming = false;
    bool processing = false;

    final AppTier currentTier =
        _subscription?.tier ?? AppSession.instance.tier.value;
    final bool isCurrent = plan.tier == currentTier;
    final bool isUpgrade = plan.tier.index > currentTier.index;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, StateSetter setDialogState) {
          final double baseAmount = _isAnnual
              ? plan.annualMonthlyAmount * 12
              : plan.monthlyAmount;
          final double due = baseAmount * (1 - discountPercent / 100);
          final bool payable = baseAmount > 0;

          final String title = isCurrent
              ? 'Switch to ${_isAnnual ? 'annual' : 'monthly'} billing'
              : (isUpgrade
                    ? 'Upgrade to ${plan.name}'
                    : 'Change to ${plan.name}');

          return UiDialog(
            title: title,
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
                                  plan.name,
                                  style: context.uiText.bodyStrong,
                                ),
                                Text(
                                  payable
                                      ? 'Billed ${_isAnnual ? 'annually' : 'monthly'}'
                                      : 'Free forever · No credit card required',
                                  style: context.uiText.caption.copyWith(
                                    color: context.ui.colors.foregroundMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            plan.priceLabel(isAnnual: _isAnnual),
                            style: context.uiText.heading.copyWith(
                              color: context.ui.colors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (discountPercent > 0) ...<Widget>[
                        SizedBox(height: context.sp(context.ui.spacing.sm)),
                        const UiDivider(),
                        SizedBox(height: context.sp(context.ui.spacing.sm)),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Coupon $discountCode',
                                style: context.uiText.caption,
                              ),
                            ),
                            Text(
                              '-${plan.currencySymbol}${(baseAmount - due).toStringAsFixed(0)}',
                              style: context.uiText.caption.copyWith(
                                color: context.ui.colors.bullish,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(context.ui.spacing.xs)),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Total due today',
                                style: context.uiText.bodyStrong,
                              ),
                            ),
                            Text(
                              '${plan.currencySymbol}${due.toStringAsFixed(0)}',
                              style: context.uiText.bodyStrong,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (payable) ...<Widget>[
                  SizedBox(height: context.sp(context.ui.spacing.md)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: UiField(
                          label: 'Coupon code',
                          error: couponError,
                          child: UiInput(
                            controller: coupon,
                            hintText: 'PROMO20',
                            onChanged: (_) {
                              if (couponError != null) {
                                setDialogState(() => couponError = null);
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: context.sp(context.ui.spacing.sm)),
                      UiButton(
                        label: 'Apply',
                        variant: UiVariant.outline,
                        loading: redeeming,
                        onPressed: () async {
                          final String raw = coupon.text.trim();
                          if (raw.isEmpty) return;
                          setDialogState(() => redeeming = true);
                          final int? pct = await _billingRepo.redeemCoupon(raw);
                          setDialogState(() {
                            redeeming = false;
                            if (pct == null) {
                              couponError = 'Invalid coupon';
                            } else {
                              discountPercent = pct;
                              discountCode = raw;
                              couponError = null;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(context.ui.spacing.md)),
                  const UiCallout(
                    title: 'Paid checkout unavailable',
                    message:
                        'A secure payment provider is not connected. Paid plan activation is disabled until checkout is available.',
                    intent: UiIntent.info,
                  ),
                ],
                SizedBox(height: context.sp(context.ui.spacing.md)),
                UiCallout(
                  title: payable ? 'Instant activation' : 'Downgrade to Free',
                  message: payable
                      ? 'Features unlock as soon as payment is confirmed. Indian 18% GST itemized transparently. Cancel anytime.'
                      : 'Paid features remain accessible until the end of your prepaid period.',
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
                    ? 'Confirm & Pay ${plan.currencySymbol}${due.toStringAsFixed(0)}'
                    : 'Confirm Change',
                intent: UiIntent.primary,
                loading: processing,
                onPressed: payable
                    ? null
                    : () async {
                        setDialogState(() => processing = true);
                        try {
                          await _pricingRepo.selectPlan(
                            tierId: plan.id,
                            billingCycle: _isAnnual ? 'annual' : 'monthly',
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (!mounted) return;

                          widget.onPlanChanged?.call(plan.tier);

                          UiToast.show(
                            context,
                            title: payable ? 'Plan Active' : 'Plan Changed',
                            message: 'You are now on TradeX ${plan.name}.',
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
                                'Could not process card payment. Please try another method.',
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
    final UiColors colors = theme.colors;
    final UiResponsive responsive = context.uiRes;

    if (_loading || _catalogue == null) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final PricingCatalogueResponse catalogue = _catalogue!;
    final AppTier currentTier =
        _subscription?.tier ?? AppSession.instance.tier.value;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(
          responsive.isMobile ? theme.spacing.md : theme.spacing.xl,
        ),
        vertical: context.sp(theme.spacing.lg),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(1100)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Pricing & Plans',
                    textAlign: TextAlign.center,
                    style: context.uiText.display.copyWith(
                      fontSize: responsive.isMobile ? 26 : 34,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: context.sz(540)),
                    child: Text(
                      'Upgrade or adjust your billing cycle to scale quantitative journaling, live scanners, and prop desk limits.',
                      textAlign: TextAlign.center,
                      style: context.uiText.body.copyWith(
                        color: colors.foregroundMuted,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Billing Cycle Switcher Toggle
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted.withValues(alpha: 0.5),
                    borderRadius: context.radius(theme.radii.pill),
                    border: Border.all(
                      color: colors.border,
                      width: theme.borders.hairline,
                    ),
                  ),
                  padding: EdgeInsets.all(context.sp(theme.spacing.xxs)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _buildCyclePill(
                        context,
                        label: 'Monthly',
                        isSelected: !_isAnnual,
                        onTap: () => _toggleCycle('monthly'),
                      ),
                      _buildCyclePill(
                        context,
                        label: 'Billed annually',
                        badge: 'Save ${catalogue.annualDiscountPercent}%',
                        isSelected: _isAnnual,
                        onTap: () => _toggleCycle('annual'),
                      ),
                    ],
                  ),
                ),
              ),

              if (_repricing) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.sm)),
                Center(
                  child: Text(
                    'Re-pricing plans…',
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              SizedBox(height: context.sp(theme.spacing.xl)),

              // 3 Pricing Cards Grid (Equal Heights)
              _buildPricingCardsGrid(
                context,
                theme,
                colors,
                responsive,
                catalogue.plans,
                currentTier,
              ),
              SizedBox(height: context.sp(theme.spacing.xxxl)),

              // Comparison Table Matrix
              _buildFeatureMatrixSection(
                context,
                theme,
                colors,
                responsive,
                catalogue.categories,
                catalogue.plans,
              ),
              SizedBox(height: context.sp(theme.spacing.xl)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCyclePill(
    BuildContext context, {
    required String label,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.md),
          vertical: context.sp(theme.spacing.xs),
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : Colors.transparent,
          borderRadius: context.radius(theme.radii.pill),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: context.uiText.bodyStrong.copyWith(
                fontSize: 13,
                color: isSelected ? colors.foreground : colors.foregroundMuted,
              ),
            ),
            if (badge != null) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiBadge(
                label: badge,
                intent: UiIntent.success,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCardsGrid(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
    List<PricingPlanModel> plans,
    AppTier currentTier,
  ) {
    if (responsive.isMobile) {
      return Column(
        children: <Widget>[
          for (int i = 0; i < plans.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: context.sp(theme.spacing.md)),
            _buildSingleCard(
              context,
              theme,
              colors,
              plans[i],
              currentTier,
              isMobile: true,
            ),
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < plans.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: context.sp(theme.spacing.md)),
            Expanded(
              child: _buildSingleCard(
                context,
                theme,
                colors,
                plans[i],
                currentTier,
                isMobile: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleCard(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    PricingPlanModel plan,
    AppTier currentTier, {
    required bool isMobile,
  }) {
    final bool isCurrent = plan.tier == currentTier;
    final bool isFeatured = plan.highlighted;
    final bool isProcessing = _processingTierId == plan.id;

    final IconData tierIcon = switch (plan.tier) {
      AppTier.free => Icons.bolt_outlined,
      AppTier.premium => Icons.auto_awesome_rounded,
      AppTier.enterprise => Icons.apartment_rounded,
    };

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(
          color: isCurrent
              ? colors.primary
              : (isFeatured ? colors.primary : colors.border),
          width: isCurrent || isFeatured ? 1.5 : theme.borders.hairline,
        ),
        boxShadow: isFeatured
            ? <BoxShadow>[
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                decoration: BoxDecoration(
                  color: (isFeatured ? colors.primary : colors.surfaceMuted)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tierIcon,
                  size: context.sz(18),
                  color: isFeatured ? colors.primary : colors.foreground,
                ),
              ),
              if (isCurrent)
                const UiBadge(
                  label: 'CURRENT PLAN',
                  intent: UiIntent.success,
                  variant: UiBadgeVariant.solid,
                  size: UiSize.xs,
                )
              else if (plan.badgeLabel != null)
                UiBadge(
                  label: plan.badgeLabel!,
                  intent: UiIntent.primary,
                  variant: UiBadgeVariant.solid,
                  size: UiSize.xs,
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Title & Subtitle
          Text(
            plan.name,
            style: context.uiText.display.copyWith(
              fontSize: 20.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          SizedBox(
            height: context.sz(34),
            child: Text(
              plan.subtitle,
              style: context.uiText.caption.copyWith(
                color: colors.foregroundMuted,
                fontSize: 12.0,
                height: 1.35,
              ),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                plan.priceLabel(isAnnual: _isAnnual),
                style: context.uiText.display.copyWith(
                  fontSize: 30.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Text(
                plan.monthlyAmount == 0 ? '' : '/ mo',
                style: context.uiText.caption.copyWith(
                  color: colors.foregroundMuted,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            plan.periodLabel(isAnnual: _isAnnual),
            style: context.uiText.caption.copyWith(
              color: colors.foregroundSubtle,
              fontSize: 11.0,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Action Button
          UiButton(
            label: isProcessing
                ? 'Processing…'
                : (isCurrent ? 'Current Plan' : 'Select ${plan.name}'),
            variant: isCurrent
                ? UiVariant.ghost
                : (isFeatured ? UiVariant.primary : UiVariant.outline),
            intent: isFeatured ? UiIntent.primary : UiIntent.neutral,
            size: UiSize.md,
            onPressed: isCurrent || isProcessing
                ? null
                : () => _showCheckoutDialog(plan),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          const UiDivider(),
          SizedBox(height: context.sp(theme.spacing.sm)),

          // Features Checklist
          Text(
            plan.tier == AppTier.free
                ? 'Plan includes:'
                : 'Everything in ${plan.tier == AppTier.premium ? 'Free' : 'Pro'}, plus:',
            style: context.uiText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.foreground,
              fontSize: 12,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),

          if (!isMobile)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final String f in plan.featuresSummary)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.sp(theme.spacing.xxs),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.check_rounded,
                            size: context.sz(14),
                            color: isFeatured ? colors.primary : colors.bullish,
                          ),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          Expanded(
                            child: Text(
                              f,
                              style: context.uiText.caption.copyWith(
                                color: colors.foregroundMuted,
                                fontSize: 12.0,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final String f in plan.featuresSummary)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: context.sp(theme.spacing.xxs),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.check_rounded,
                          size: context.sz(14),
                          color: isFeatured ? colors.primary : colors.bullish,
                        ),
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        Expanded(
                          child: Text(
                            f,
                            style: context.uiText.caption.copyWith(
                              color: colors.foregroundMuted,
                              fontSize: 12.0,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureMatrixSection(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
    List<PlanFeatureCategory> categories,
    List<PricingPlanModel> plans,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          'Compare features across plans',
          textAlign: TextAlign.center,
          style: context.uiText.display.copyWith(
            fontSize: responsive.isMobile ? 22.0 : 28.0,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        if (responsive.isMobile) ...<Widget>[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.md),
              vertical: context.sp(theme.spacing.xs),
            ),
            decoration: BoxDecoration(
              color: colors.surfaceMuted.withValues(alpha: 0.5),
              borderRadius: context.radius(theme.radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.swap_horiz_rounded,
                  size: context.sz(14),
                  color: colors.primary,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Text(
                  'Scroll table horizontally to view all plans',
                  style: context.uiText.caption.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
        ],
        SizedBox(height: context.sp(theme.spacing.md)),

        // Table
        UiCard(
          variant: UiCardVariant.surface,
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: responsive.isMobile ? context.sz(680) : context.sz(920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Features & Capabilities',
                            style: context.uiText.bodyStrong.copyWith(
                              color: colors.foregroundMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              'Free',
                              style: context.uiText.bodyStrong.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              'Pro',
                              style: context.uiText.bodyStrong.copyWith(
                                fontSize: 13,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              'Enterprise',
                              style: context.uiText.bodyStrong.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const UiDivider(),

                  for (final PlanFeatureCategory cat in categories) ...<Widget>[
                    Container(
                      color: colors.surfaceMuted.withValues(alpha: 0.3),
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.md),
                        vertical: context.sp(theme.spacing.xs),
                      ),
                      child: Text(
                        cat.name.toUpperCase(),
                        style: context.uiText.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: colors.foregroundSubtle,
                          fontSize: 11.0,
                        ),
                      ),
                    ),
                    const UiDivider(),

                    for (final PlanComparisonRow row in cat.rows) ...<Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(theme.spacing.md),
                          vertical: context.sp(theme.spacing.sm),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              flex: 3,
                              child: Text(
                                row.title,
                                style: context.uiText.body.copyWith(
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: _renderMatrixValue(
                                  context,
                                  colors,
                                  row.freeValue,
                                  row.isBoolean,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: _renderMatrixValue(
                                  context,
                                  colors,
                                  row.proValue,
                                  row.isBoolean,
                                  isPrimary: true,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: _renderMatrixValue(
                                  context,
                                  colors,
                                  row.enterpriseValue,
                                  row.isBoolean,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const UiDivider(),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _renderMatrixValue(
    BuildContext context,
    UiColors colors,
    dynamic value,
    bool isBoolean, {
    bool isPrimary = false,
  }) {
    if (isBoolean) {
      final bool checked = value == true;
      if (checked) {
        return Icon(
          Icons.check_circle_rounded,
          size: context.sz(16),
          color: isPrimary ? colors.primary : colors.bullish,
        );
      }
      return Text(
        '—',
        style: context.uiText.body.copyWith(color: colors.foregroundSubtle),
      );
    }

    final String text = value?.toString() ?? '—';
    return Text(
      text,
      textAlign: TextAlign.center,
      style: context.uiText.caption.copyWith(
        color: isPrimary ? colors.foreground : colors.foregroundMuted,
        fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
        fontSize: 11.5,
      ),
    );
  }
}
