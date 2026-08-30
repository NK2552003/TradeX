import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:tradex/features/auth/models/pricing_models.dart';
import 'package:tradex/features/auth/presentation/widgets/tradex_footer.dart';

/// Claude-inspired Subscription & Pricing Page for TradeX.
///
/// Fully dynamic, backend-ready, priced in INR (₹) with zero hardcoded
/// values. Designed for both post-signup onboarding and standalone review.
class SubscriptionPricingPage extends StatefulWidget {
  const SubscriptionPricingPage({
    super.key,
    required this.onContinue,
    this.onBack,
    this.onSelectPlan,
    this.repository,
    this.isPostSignup = true,
  });

  /// Called when the user continues to the main dashboard / app shell.
  final VoidCallback onContinue;

  /// Optional back navigation callback.
  final VoidCallback? onBack;

  /// Optional callback when a specific plan is chosen.
  final void Function(PricingPlanModel plan, bool isAnnual)? onSelectPlan;

  /// Injected repository or fallback default instance.
  final SubscriptionPricingRepository? repository;

  /// Whether this page is presented as part of the post-signup onboarding flow.
  final bool isPostSignup;

  @override
  State<SubscriptionPricingPage> createState() =>
      _SubscriptionPricingPageState();
}

class _SubscriptionPricingPageState extends State<SubscriptionPricingPage> {
  late final SubscriptionPricingRepository _repository;
  late Future<PricingCatalogueResponse> _catalogueFuture;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _plansKey = GlobalKey();
  final GlobalKey _matrixKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  bool _isAnnual = true;
  String _selectedFaqCategory = 'all';
  String? _selectedPlanId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SubscriptionPricingRepositoryImpl();
    _catalogueFuture = _repository.getPricingCatalogue(annual: _isAnnual);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    final BuildContext? currentContext = key.currentContext;
    if (currentContext != null) {
      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _toggleCycle(String cycle) {
    final bool annual = cycle == 'annual';
    if (annual == _isAnnual) return;
    setState(() {
      _isAnnual = annual;
      // Re-fetch catalogue dynamically if needed
      _catalogueFuture = _repository.getPricingCatalogue(annual: _isAnnual);
    });
  }

  Future<void> _handlePlanSelection(PricingPlanModel plan) async {
    setState(() {
      _selectedPlanId = plan.id;
      _isProcessing = true;
    });

    try {
      await _repository.selectPlan(
        tierId: plan.id,
        billingCycle: _isAnnual ? 'annual' : 'monthly',
      );

      if (!mounted) return;

      widget.onSelectPlan?.call(plan, _isAnnual);

      UiToast.show(
        context,
        title: '${plan.name} Plan Selected',
        message: plan.monthlyAmount == 0
            ? 'Welcome to TradeX Free Plan.'
            : 'Subscribed to ${plan.name} (${_isAnnual ? 'Annual' : 'Monthly'}).',
        intent: UiIntent.success,
      );

      widget.onContinue();
    } catch (e) {
      if (!mounted) return;
      UiToast.show(
        context,
        title: 'Subscription Error',
        message: 'Could not process plan selection: $e',
        intent: UiIntent.danger,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final UiResponsive responsive = context.uiRes;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            // Scrollable Main Content
            Positioned.fill(
              child: FutureBuilder<PricingCatalogueResponse>(
                future: _catalogueFuture,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<PricingCatalogueResponse> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const CircularProgressIndicator(),
                          SizedBox(height: context.sp(theme.spacing.md)),
                          Text(
                            'Loading plan catalogue…',
                            style: context.uiText.body.copyWith(
                              color: colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
                        child: UiCallout(
                          title: 'Unable to load pricing catalogue',
                          message:
                              'Please verify your connection and try again.',
                          intent: UiIntent.danger,
                        ),
                      ),
                    );
                  }

                  final PricingCatalogueResponse catalogue = snapshot.data!;

                  return SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: context.sp(
                        responsive.isMobile
                            ? theme.spacing.lg
                            : theme.spacing.xxxl,
                      ),
                      right: context.sp(
                        responsive.isMobile
                            ? theme.spacing.lg
                            : theme.spacing.xxxl,
                      ),
                      top: context.sp(
                        responsive.isMobile
                            ? theme.spacing.xxxl * 2
                            : theme.spacing.xxxl * 2.5,
                      ),
                      bottom: context.sp(theme.spacing.xxl),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: context.sz(1180)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            // Hero Title & Description
                            _buildHeroHeader(context, theme, colors),
                            SizedBox(height: context.sp(theme.spacing.xl)),

                            // Billing Cycle Toggle (Monthly vs Annual)
                            _buildCycleToggle(
                              context,
                              theme,
                              colors,
                              catalogue.annualDiscountPercent,
                            ),
                            SizedBox(height: context.sp(theme.spacing.xxxl)),

                            // 3 Pricing Cards Grid (Claude style)
                            KeyedSubtree(
                              key: _plansKey,
                              child: _buildPricingCardsGrid(
                                context,
                                theme,
                                colors,
                                responsive,
                                catalogue.plans,
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.xxxl) * 2),

                            // Compare Features Across Plans Section
                            KeyedSubtree(
                              key: _matrixKey,
                              child: _buildFeatureMatrixSection(
                                context,
                                theme,
                                colors,
                                responsive,
                                catalogue.categories,
                                catalogue.plans,
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.xxxl) * 2),

                            // Frequently Asked Questions Section
                            KeyedSubtree(
                              key: _faqKey,
                              child: _buildFaqSection(
                                context,
                                theme,
                                colors,
                                responsive,
                                catalogue.faqs,
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.xxxl) * 2),

                            // Bottom Detailed 4-Column Footer & Regulatory Disclaimer
                            TradeXFooter(
                              onNavigateToSection: (section) {
                                if (section == 'pricing' || section == 'plans') {
                                  _scrollToKey(_plansKey);
                                } else if (section == 'features' ||
                                    section == 'compare') {
                                  _scrollToKey(_matrixKey);
                                } else if (section == 'faq') {
                                  _scrollToKey(_faqKey);
                                } else {
                                  _scrollController.animateTo(
                                    0.0,
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOutCubic,
                                  );
                                }
                              },
                            ),
                            SizedBox(height: context.sp(theme.spacing.xl)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Top Blurred Backdrop Shader Layer (Matching GetStartedPage)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 72,
              child: IgnorePointer(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        color: colors.background.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top Sticky Navigation Bar (Matching GetStartedPage layout)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: _buildTopNavBar(context, theme, colors, responsive),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Top Navigation Bar (Matching GetStartedPage modern layout & clean design)
  // ---------------------------------------------------------------------------
  Widget _buildTopNavBar(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(
          responsive.isMobile ? theme.spacing.lg : theme.spacing.xl,
        ),
        vertical: context.sp(
          responsive.isMobile ? theme.spacing.sm : theme.spacing.md,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Left: Brand Logo + Back Button
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.onBack != null) ...<Widget>[
                  UiIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back to Overview',
                    size: UiSize.sm,
                    variant: UiVariant.ghost,
                    onPressed: widget.onBack!,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                ],
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _scrollController.animateTo(
                        0.0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOutCubic,
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const AppLogoMark(size: 24),
                        SizedBox(width: context.sp(theme.spacing.sm)),
                        Text(
                          'TRADEX',
                          style: context.uiText.display.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Center: Navigation Links (Desktop)
            if (!responsive.isMobile)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _HeaderNavLink(
                    label: 'overview',
                    onTap: () {
                      _scrollController.animateTo(
                        0.0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOutCubic,
                      );
                    },
                  ),
                  SizedBox(width: context.sp(theme.spacing.xl)),
                  _HeaderNavLink(
                    label: 'plans',
                    onTap: () => _scrollToKey(_plansKey),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xl)),
                  _HeaderNavLink(
                    label: 'compare',
                    onTap: () => _scrollToKey(_matrixKey),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xl)),
                  _HeaderNavLink(
                    label: 'faq',
                    onTap: () => _scrollToKey(_faqKey),
                  ),
                ],
              ),

            // Right: Primary Action Button
            UiButton(
              label: widget.isPostSignup ? 'Skip to Dashboard' : '+ GET TRADEX',
              variant: UiVariant.primary,
              intent: UiIntent.primary,
              size: UiSize.sm,
              onPressed: widget.onContinue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionBadge(
    BuildContext context,
    UiTheme theme,
    UiColors colors, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.xs),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: context.radius(theme.radii.pill),
        border: Border.all(
          color: const Color(0xFF84CC16).withValues(alpha: 0.35),
          width: theme.borders.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: context.sz(14), color: const Color(0xFF84CC16)),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Text(
            label,
            style: context.uiText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.foreground,
              fontSize: 12.0,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Hero Header
  // ---------------------------------------------------------------------------
  Widget _buildHeroHeader(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
  ) {
    final bool isMobile = context.uiRes.isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _buildSectionBadge(
          context,
          theme,
          colors,
          icon: Icons.workspace_premium_outlined,
          label: 'Simple & Transparent Pricing (INR ₹)',
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Text(
          'Choose Your Trading Plan',
          textAlign: TextAlign.center,
          style: context.uiText.display.copyWith(
            fontSize: isMobile ? 26.0 : 36.0,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(620)),
          child: Text(
            'Choose the right plan to power your trading edge. From disciplined quantitative journaling to institutional prop desk execution.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: 14.0,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Cycle Switcher Toggle (Monthly vs Annual)
  // ---------------------------------------------------------------------------
  Widget _buildCycleToggle(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    int discountPercent,
  ) {
    return Container(
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
            badge: 'Save $discountPercent%',
            isSelected: _isAnnual,
            onTap: () => _toggleCycle('annual'),
          ),
        ],
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
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
                    color: Colors.black.withValues(alpha: 0.15),
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

  // ---------------------------------------------------------------------------
  // 4. 3 Pricing Cards Grid (Claude Style)
  // ---------------------------------------------------------------------------
  Widget _buildPricingCardsGrid(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
    List<PricingPlanModel> plans,
  ) {
    if (responsive.isMobile) {
      return Column(
        children: <Widget>[
          for (int i = 0; i < plans.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: context.sp(theme.spacing.lg)),
            _buildSinglePricingCard(
              context,
              theme,
              colors,
              plans[i],
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
            if (i > 0) SizedBox(width: context.sp(theme.spacing.lg)),
            Expanded(
              child: _buildSinglePricingCard(
                context,
                theme,
                colors,
                plans[i],
                isMobile: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSinglePricingCard(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    PricingPlanModel plan, {
    required bool isMobile,
  }) {
    final bool isFeatured = plan.highlighted;
    final bool isSelected = _selectedPlanId == plan.id;

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
          color: isFeatured
              ? colors.primary
              : colors.border.withValues(alpha: 0.8),
          width: isFeatured ? 1.5 : theme.borders.hairline,
        ),
        boxShadow: isFeatured
            ? <BoxShadow>[
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header: Icon + Optional Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
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
                  size: context.sz(20),
                  color: isFeatured ? colors.primary : colors.foreground,
                ),
              ),
              if (plan.badgeLabel != null)
                UiBadge(
                  label: plan.badgeLabel!,
                  intent: UiIntent.primary,
                  variant: UiBadgeVariant.solid,
                  size: UiSize.xs,
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Plan Title & Subtitle
          Text(
            plan.name,
            style: context.uiText.display.copyWith(
              fontSize: 20.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          SizedBox(
            height: context.sz(38),
            child: Text(
              plan.subtitle,
              style: context.uiText.caption.copyWith(
                color: colors.foregroundMuted,
                fontSize: 13.0,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Pricing Number
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                plan.priceLabel(isAnnual: _isAnnual),
                style: context.uiText.display.copyWith(
                  fontSize: 32.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Text(
                plan.monthlyAmount == 0 ? '' : (_isAnnual ? '/ mo' : '/ mo'),
                style: context.uiText.caption.copyWith(
                  color: colors.foregroundMuted,
                  fontSize: 13.0,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            plan.periodLabel(isAnnual: _isAnnual),
            style: context.uiText.caption.copyWith(
              color: colors.foregroundSubtle,
              fontSize: 12.0,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),

          // Main CTA Button
          UiButton(
            label: _isProcessing && isSelected
                ? 'Processing…'
                : plan.ctaLabel,
            variant: isFeatured ? UiVariant.primary : UiVariant.outline,
            intent: isFeatured ? UiIntent.primary : UiIntent.neutral,
            size: UiSize.lg,
            onPressed: _isProcessing
                ? null
                : () => _handlePlanSelection(plan),
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),

          const UiDivider(),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Feature Checklist Header
          Text(
            plan.tier == AppTier.free
                ? 'Plan includes:'
                : 'Everything in ${plan.tier == AppTier.premium ? 'Free' : 'Pro'}, plus:',
            style: context.uiText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.foreground,
              fontSize: 13.0,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),

          // Feature Checklist
          if (!isMobile)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final String feature in plan.featuresSummary) ...<Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.sp(theme.spacing.xxs),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.check_rounded,
                            size: context.sz(15),
                            color: isFeatured ? colors.primary : colors.bullish,
                          ),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          Expanded(
                            child: Text(
                              feature,
                              style: context.uiText.caption.copyWith(
                                color: colors.foregroundMuted,
                                fontSize: 13.0,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final String feature in plan.featuresSummary) ...<Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: context.sp(theme.spacing.xxs),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.check_rounded,
                          size: context.sz(15),
                          color: isFeatured ? colors.primary : colors.bullish,
                        ),
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        Expanded(
                          child: Text(
                            feature,
                            style: context.uiText.caption.copyWith(
                              color: colors.foregroundMuted,
                              fontSize: 13.0,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Compare Features Across Plans Matrix
  // ---------------------------------------------------------------------------
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
        // Pill Badge
        _buildSectionBadge(
          context,
          theme,
          colors,
          icon: Icons.compare_arrows_rounded,
          label: 'Detailed Feature Matrix',
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Text(
          'Compare Features Across Plans',
          textAlign: TextAlign.center,
          style: context.uiText.display.copyWith(
            fontSize: responsive.isMobile ? 24.0 : 32.0,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(620)),
          child: Text(
            'Transparent breakdown of quantitative tools, data limits, broker connectors, and institutional prop desk capabilities.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: 14.0,
              height: 1.5,
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.lg)),

        // Mobile Swipe Hint
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
          SizedBox(height: context.sp(theme.spacing.md)),
        ],

        // Comparison Table Container (Scrollable horizontally on mobile)
        UiCard(
          variant: UiCardVariant.surface,
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: responsive.isMobile ? context.sz(700) : context.sz(920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                    // Sticky Column Header
                    Padding(
                      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
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
                                style: context.uiText.bodyStrong.copyWith(fontSize: 13),
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
                                style: context.uiText.bodyStrong.copyWith(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const UiDivider(),

              // Feature Categories & Rows
              for (final PlanFeatureCategory category in categories) ...<Widget>[
                // Category Headline
                Container(
                  color: colors.surfaceMuted.withValues(alpha: 0.3),
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.lg),
                    vertical: context.sp(theme.spacing.sm),
                  ),
                  child: Text(
                    category.name.toUpperCase(),
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: colors.foregroundSubtle,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                UiDivider(),

                for (final PlanComparisonRow row in category.rows) ...<Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.lg),
                      vertical: context.sp(theme.spacing.md),
                    ),
                    child: Row(
                      children: <Widget>[
                        // Feature Name + Tooltip
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  row.title,
                                  style: context.uiText.body.copyWith(
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (row.tooltip != null) ...<Widget>[
                                SizedBox(width: context.sp(theme.spacing.xxs)),
                                Tooltip(
                                  message: row.tooltip!,
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    size: context.sz(13),
                                    color: colors.foregroundSubtle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Free Value
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

                        // Pro Value
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

                        // Enterprise Value
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
          size: context.sz(18),
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
        fontSize: 12.5,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Frequently Asked Questions Section (FAQ)
  // ---------------------------------------------------------------------------
  Widget _buildFaqSection(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
    List<PricingFaqItem> faqs,
  ) {
    final List<PricingFaqItem> filteredFaqs = _selectedFaqCategory == 'all'
        ? faqs
        : faqs.where((f) => f.category == _selectedFaqCategory).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Pill Badge
        _buildSectionBadge(
          context,
          theme,
          colors,
          icon: Icons.help_outline_rounded,
          label: 'Knowledge & FAQs',
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Text(
          'Frequently Asked Questions',
          textAlign: TextAlign.center,
          style: context.uiText.display.copyWith(
            fontSize: responsive.isMobile ? 24.0 : 32.0,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(620)),
          child: Text(
            'Everything you need to know about TradeX, quantitative journaling, Indian broker connections, security, and AI capabilities.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: 14.0,
              height: 1.5,
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),

        // Category Filter Pills
        Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          alignment: WrapAlignment.center,
          children: <Widget>[
            _buildFaqCategoryFilter(context, 'all', 'All Questions'),
            _buildFaqCategoryFilter(context, 'billing', 'Billing & Plans'),
            _buildFaqCategoryFilter(context, 'features', 'Features & AI'),
            _buildFaqCategoryFilter(context, 'enterprise', 'Enterprise & Desks'),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),

        // Dynamic Accordion List
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(840)),
          child: UiAccordion(
            items: <UiAccordionItem>[
              for (final PricingFaqItem item in filteredFaqs)
                UiAccordionItem(
                  title: item.question,
                  content: Text(
                    item.answer,
                    style: context.uiText.body.copyWith(
                      color: colors.foregroundMuted,
                      height: 1.6,
                      fontSize: 13.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFaqCategoryFilter(
    BuildContext context,
    String categoryKey,
    String label,
  ) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isSelected = _selectedFaqCategory == categoryKey;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedFaqCategory = categoryKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.md),
          vertical: context.sp(theme.spacing.xs),
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : colors.surfaceMuted.withValues(alpha: 0.4),
          borderRadius: context.radius(theme.radii.pill),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Text(
          label,
          style: context.uiText.caption.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colors.foreground : colors.foregroundMuted,
          ),
        ),
      ),
    );
  }
}

class _HeaderNavLink extends StatefulWidget {
  const _HeaderNavLink({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<_HeaderNavLink> createState() => _HeaderNavLinkState();
}

class _HeaderNavLinkState extends State<_HeaderNavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.xxs),
              vertical: context.sp(theme.spacing.xxs),
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _isHovered ? colors.foreground : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              widget.label,
              style: context.uiText.body.copyWith(
                color: _isHovered
                    ? colors.foreground
                    : colors.foregroundMuted.withValues(alpha: 0.75),
                fontWeight: _isHovered ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15.0,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

