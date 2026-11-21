import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/public_site/data/public_site_repository.dart';
import 'package:alphajournal/features/public_site/models/public_site_content.dart';
import 'package:alphajournal/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/models/pricing_models.dart';
import 'package:alphajournal/features/auth/presentation/widgets/alphajournal_footer.dart';
import 'package:alphajournal/features/auth/presentation/widgets/landing_apple_showcases.dart';
import 'package:alphajournal/features/auth/widgets/auth_carousel_panel.dart';

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
    this.onViewFullPricing,
    this.repository,
  });

  final void Function(UserRole role) onGetStarted;
  final VoidCallback onSignIn;
  final VoidCallback? onViewFullPricing;
  final PublicSiteRepository? repository;

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _platformKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _devicesKey = GlobalKey();
  final GlobalKey _pricingKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  late final PublicSiteRepository _content =
      widget.repository ?? publicSiteRepository();
  late final SubscriptionPricingRepository _pricingRepo =
      SubscriptionPricingRepositoryImpl(content: _content);
  PublicSiteContent? _page;
  bool _isAnnualPricing = true;
  Future<PricingCatalogueResponse>? _pricingRequest;
  Future<PricingCatalogueResponse> get _pricingFuture => _pricingRequest ??=
      _pricingRepo.getPricingCatalogue(annual: _isAnnualPricing);
  set _pricingFuture(Future<PricingCatalogueResponse> value) =>
      _pricingRequest = value;

  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _showHeaderCtaNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> _activeSectionNotifier = ValueNotifier<String>(
    'home',
  );
  String? _pinnedScrollTarget;
  Timer? _pinnedScrollResetTimer;
  ThemeMode? _fallbackThemeMode;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _content
        .landing()
        .then((page) {
          if (mounted) setState(() => _page = page);
        })
        .catchError((Object _) {
          /* Keep the restored page usable if editorial content is unavailable. */
        });
  }

  @override
  void dispose() {
    _pinnedScrollResetTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _isScrolledNotifier.dispose();
    _showHeaderCtaNotifier.dispose();
    _activeSectionNotifier.dispose();
    super.dispose();
  }

  void _toggleTheme(BuildContext context) {
    final bool currentlyDark = context.ui.brightness == Brightness.dark;
    final ThemeMode nextMode = currentlyDark ? ThemeMode.light : ThemeMode.dark;
    final AppThemeController? controller = AppThemeController.maybeOf(context);
    if (controller != null) {
      controller.setMode(nextMode);
    } else {
      setState(() => _fallbackThemeMode = nextMode);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double offset = _scrollController.offset;
    final bool scrolled = offset > 40.0;
    if (_isScrolledNotifier.value != scrolled) {
      _isScrolledNotifier.value = scrolled;
    }
    final bool showHeaderCta = offset > 360.0;
    if (_showHeaderCtaNotifier.value != showHeaderCta) {
      _showHeaderCtaNotifier.value = showHeaderCta;
    }
    _updateActiveSection(offset);
  }

  void _updateActiveSection(double offset) {
    if (_pinnedScrollTarget != null || !mounted) return;
    if (offset <= 120.0) {
      if (_activeSectionNotifier.value != 'home') {
        _activeSectionNotifier.value = 'home';
      }
      return;
    }

    final ScrollPosition pos = _scrollController.position;
    if (pos.hasContentDimensions &&
        pos.maxScrollExtent > 200 &&
        offset >= pos.maxScrollExtent - 140.0) {
      if (_activeSectionNotifier.value != 'faq') {
        _activeSectionNotifier.value = 'faq';
      }
      return;
    }

    final double viewportHeight = MediaQuery.sizeOf(context).height;
    final double activationLine = (viewportHeight * 0.34).clamp(160.0, 320.0);

    final List<({String id, GlobalKey key})> sections =
        <({String id, GlobalKey key})>[
          (id: 'faq', key: _faqKey),
          (id: 'pricing', key: _pricingKey),
          (id: 'devices', key: _devicesKey),
          (id: 'features', key: _featuresKey),
          (id: 'platform', key: _platformKey),
        ];

    String nextSection = 'home';
    for (final section in sections) {
      final BuildContext? ctx = section.key.currentContext;
      if (ctx == null) continue;
      final RenderObject? ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      final double topY = ro.localToGlobal(Offset.zero).dy;
      if (topY <= activationLine) {
        nextSection = section.id;
        break;
      }
    }

    if (_activeSectionNotifier.value != nextSection) {
      _activeSectionNotifier.value = nextSection;
    }
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    final BuildContext? ctx = key.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
        alignment: 0.06,
      );
      if (mounted && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 150),
          alignment: 0.06,
        );
      }
    }
  }

  void _pinActiveSection(String section) {
    _pinnedScrollTarget = section;
    if (_activeSectionNotifier.value != section) {
      _activeSectionNotifier.value = section;
    }
    _pinnedScrollResetTimer?.cancel();
    _pinnedScrollResetTimer = Timer(const Duration(milliseconds: 900), () {
      _pinnedScrollTarget = null;
      if (mounted && _scrollController.hasClients) {
        _updateActiveSection(_scrollController.offset);
      }
    });
  }

  void _scrollToSection(String section) {
    switch (section) {
      case 'platform':
      case 'showcase':
        _pinActiveSection('platform');
        _scrollToKey(_platformKey);
        break;
      case 'features':
        _pinActiveSection('features');
        _scrollToKey(_featuresKey);
        break;
      case 'devices':
        _pinActiveSection('devices');
        _scrollToKey(_devicesKey);
        break;
      case 'pricing':
        _pinActiveSection('pricing');
        _scrollToKey(_pricingKey);
        break;
      case 'faq':
        _pinActiveSection('faq');
        _scrollToKey(_faqKey);
        break;
      default:
        _pinActiveSection('home');
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget page = Builder(
      builder: (BuildContext themedContext) {
        final theme = themedContext.ui;
        final colors = theme.colors;
        final responsive = themedContext.uiRes;

        if (responsive.isMobile ||
            (responsive.isLandscape && responsive.height < 500)) {
          return Scaffold(
            backgroundColor: colors.background,
            body: AlphaThreadBackdrop(
              animate: true,
              phase: 47.229,
              thickness: 76,
              mobileHeight: 220,
              child: SafeArea(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: _buildMobileView(
                        themedContext,
                        theme,
                        colors,
                        responsive,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 12,
                      child: RepaintBoundary(
                        child: _HeaderThemeToggleButton(
                          isDark: theme.brightness == Brightness.dark,
                          frostedPill: true,
                          onTap: () => _toggleTheme(themedContext),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _buildDesktopScaffold(themedContext, theme, colors, responsive);
      },
    );

    // Keep tree depth stable when no AppThemeController is in scope so
    // toggling _fallbackThemeMode never unmounts SingleChildScrollView or
    // resets UiDeferred sections back to skeletons.
    if (AppThemeController.maybeOf(context) == null) {
      final UiTheme effectiveTheme = _fallbackThemeMode == null
          ? UiThemeScope.of(context)
          : (_fallbackThemeMode == ThemeMode.light
                ? UiTheme.light()
                : UiTheme.dark());
      return UiThemeScope(theme: effectiveTheme, child: page);
    }
    return page;
  }

  Widget _buildDesktopScaffold(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // Scrollable Content
            Positioned.fill(
              child: RawScrollbar(
                controller: _scrollController,
                thumbVisibility: false,
                thickness: 6,
                radius: Radius.circular(context.sp(theme.radii.pill)),
                thumbColor: colors.borderStrong,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Full-bleed Hero Section with Precision Grid + Scrolling Top AlphaThread
                      _buildHero(
                        context,
                        theme,
                        colors,
                        responsive,
                      ),

                      SizedBox(
                        height: context.sp(theme.spacing.xxxl),
                      ),

                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.sp(theme.spacing.xl),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: context.sz(1400),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                  // Apple-style Horizontal Feature Carousel (Platform Overview)
                                  KeyedSubtree(
                                    key: _platformKey,
                                    child: UiDeferred(
                                      estimatedHeight: 620,
                                      builder: (_) => UiScrollReveal(
                                        slideOffset: const Offset(0, 0.04),
                                        child: LandingAppleFeatureCarousel(
                                          onGetStarted: () => widget
                                              .onGetStarted(
                                                UserRole.customer,
                                              ),
                                          onExplorePricing: () =>
                                              _scrollToSection('pricing'),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          height: context.sp(theme.spacing.xxxl) * 2,
                        ),

                        // Full-bleed Apple-style 5-iPhone SVG Gallery with live reusable widgets & QuietDock
                        KeyedSubtree(
                          key: _featuresKey,
                          child: UiDeferred(
                            estimatedHeight: 680,
                            builder: (_) => const RepaintBoundary(
                              child: LandingAppleIphoneGallery(),
                            ),
                          ),
                        ),

                        SizedBox(
                          height: context.sp(theme.spacing.xxxl) * 2,
                        ),

                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.sp(theme.spacing.xl),
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: context.sz(1400),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Apple-style Center iPad Pro SVG + Flanking 2×2 Mosaic
                                  UiDeferred(
                                    estimatedHeight: 660,
                                    builder: (_) => const UiScrollReveal(
                                      slideOffset: Offset(0, 0.04),
                                      child: LandingAppleIpadMosaicSection(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          height: context.sp(theme.spacing.xxxl) * 2,
                        ),

                        // Full-bleed Apple-style Center iPhone SVG + Flanking AI Result Strip
                        UiDeferred(
                          estimatedHeight: 640,
                          builder: (_) => const UiScrollReveal(
                            slideOffset: Offset(0, 0.04),
                            child: LandingAppleCenterPhoneStripSection(),
                          ),
                        ),

                        SizedBox(
                          height: context.sp(theme.spacing.xxxl) * 2,
                        ),

                        // Available on Every Device — 5-Device Baseline Showcase
                        KeyedSubtree(
                          key: _devicesKey,
                          child: UiDeferred(
                            estimatedHeight: 580,
                            builder: (_) => RepaintBoundary(
                              child: LandingAvailableDevicesSection(
                                onLaunchWeb: () =>
                                    widget.onGetStarted(UserRole.customer),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          height: context.sp(theme.spacing.xxxl) * 2,
                        ),

                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.sp(theme.spacing.xl),
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: context.sz(1400),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Dedicated Desktop Pricing Section
                                  KeyedSubtree(
                                    key: _pricingKey,
                                    child: UiDeferred(
                                      estimatedHeight: 500,
                                      builder: (_) => UiScrollReveal(
                                        slideOffset: const Offset(0, 0.04),
                                        child: _buildPricingSection(
                                          context,
                                          theme,
                                          colors,
                                          responsive,
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(
                                    height: context.sp(theme.spacing.xxxl) * 2,
                                  ),

                                  // Landing Page FAQ Section
                                  KeyedSubtree(
                                    key: _faqKey,
                                    child: UiDeferred(
                                      estimatedHeight: 400,
                                      builder: (_) => UiScrollReveal(
                                        slideOffset: const Offset(0, 0.04),
                                        child: _buildFaqSection(
                                          context,
                                          theme,
                                          colors,
                                          responsive,
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(
                                    height: context.sp(theme.spacing.xxxl) * 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Full-width Bottom Bookend: Precision pulse grid (faded bottom-to-top)
                        // behind BOTH the lower AlphaThread ribbon and AlphaJournalFooter
                        Stack(
                          children: <Widget>[
                            const Positioned.fill(
                              child: LandingHeroGridBackdrop(fadeFromTop: true),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                // Full-width Bottom-originating AlphaThread ribbon (flush above footer)
                                LayoutBuilder(
                                  builder:
                                      (
                                        BuildContext ctx,
                                        BoxConstraints constraints,
                                      ) {
                                        final bool isDesktop =
                                            constraints.maxWidth >= 900;
                                        if (!isDesktop) {
                                          return const SizedBox.shrink();
                                        }
                                        final height = context.sz(220);
                                        return UiDeferred(
                                          estimatedHeight: height,
                                          preloadExtent: 0,
                                          builder: (_) => RepaintBoundary(
                                            child: SizedBox(
                                              height: height,
                                              width: double.infinity,
                                              child: const RotatedBox(
                                                quarterTurns: 2,
                                                child: AlphaThread(
                                                  phase: 84.6,
                                                  thickness: 60,
                                                  animate: true,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                ),

                                // Bottom Bar: Copyright & Legal quick actions (transparent over pulse grid)
                                const UiScrollReveal(
                                  slideOffset: Offset(0, 0.04),
                                  scaleFrom: 1.0,
                                  child: AlphaJournalFooter(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Floating Frosted-Glass Desktop Pill Header (sleek, concentric, dock-matched)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.sp(theme.spacing.md),
                      context.sp(theme.spacing.sm),
                      context.sp(theme.spacing.md),
                      0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: context.sz(1080),
                        ),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _isScrolledNotifier,
                          builder: (
                            BuildContext context,
                            bool isScrolled,
                            Widget? child,
                          ) {
                            final bool isDark =
                                theme.brightness == Brightness.dark;
                            final BorderRadius pillRadius =
                                BorderRadius.circular(999);
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                borderRadius: pillRadius,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark
                                          ? (isScrolled ? 0.44 : 0.26)
                                          : (isScrolled ? 0.11 : 0.06),
                                    ),
                                    blurRadius: isScrolled ? 24 : 16,
                                    offset: const Offset(0, 6),
                                  ),
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isScrolled ? 0.04 : 0.02,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: pillRadius,
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: 12,
                                    sigmaY: 12,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    decoration: BoxDecoration(
                                      color: colors.surface.withValues(
                                        alpha: isDark
                                            ? (isScrolled ? 0.78 : 0.64)
                                            : (isScrolled ? 0.92 : 0.82),
                                      ),
                                      borderRadius: pillRadius,
                                      border: Border.all(
                                        color: colors.borderStrong.withValues(
                                          alpha: isDark
                                              ? (isScrolled ? 0.76 : 0.52)
                                              : (isScrolled ? 0.74 : 0.54),
                                        ),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: child,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: RepaintBoundary(
                            child: _buildTopNav(
                              context,
                              theme,
                              colors,
                              responsive,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildMobileView(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLandscapeOrCompact = constraints.maxHeight < 650;
        final double horizontalPadding = constraints.maxWidth < 360
            ? context.sp(theme.spacing.md)
            : context.sp(theme.spacing.xl);

        final Widget actionButtons = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: context.sp(
              isLandscapeOrCompact ? theme.spacing.sm : theme.spacing.md,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: UiButton(
                  label: 'Continue as Trader',
                  variant: UiVariant.primary,
                  intent: UiIntent.primary,
                  size: UiSize.lg,
                  onPressed: () => widget.onGetStarted(UserRole.customer),
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              SizedBox(
                width: double.infinity,
                child: UiButton(
                  label: 'Join as Affiliate',
                  variant: UiVariant.outline,
                  intent: UiIntent.primary,
                  size: UiSize.lg,
                  leadingIcon: Icons.handshake_outlined,
                  onPressed: () => widget.onGetStarted(UserRole.affiliate),
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              SizedBox(
                width: double.infinity,
                child: UiButton(
                  label: 'Already have an account? Sign in',
                  expand: true,
                  alignment: Alignment.center,
                  variant: UiVariant.ghost,
                  intent: UiIntent.neutral,
                  size: UiSize.sm,
                  leadingIcon: Icons.login_rounded,
                  onPressed: widget.onSignIn,
                ),
              ),
            ],
          ),
        );

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top clearance for the prominent AlphaThread header (thread replaces the logo)
                SizedBox(height: context.sz(isLandscapeOrCompact ? 16 : 72)),

                // Carousel with text & dots positioned directly above the action buttons
                AuthCarouselPanel(bottomAction: actionButtons),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopNav(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    final bool showNavLinks = responsive.width >= 768;
    final Widget vDivider = Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: colors.borderStrong.withValues(alpha: 0.45),
    );

    final Widget brandLogo = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _scrollToSection('home'),
        child: const AppLogo(size: 19, markRounded: false),
      ),
    );

    final Widget navLinksScroll = ValueListenableBuilder<String>(
      valueListenable: _activeSectionNotifier,
      builder: (BuildContext context, String activeSection, Widget? _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: _SlidingHeaderNavBar(
            activeSection: activeSection,
            items: const <({String id, String label})>[
              (id: 'home', label: 'home'),
              (id: 'platform', label: 'platform'),
              (id: 'features', label: 'features'),
              (id: 'devices', label: 'devices'),
              (id: 'pricing', label: 'pricing'),
              (id: 'faq', label: 'faq'),
            ],
            onSelect: _scrollToSection,
          ),
        );
      },
    );

    final bool isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<bool>(
      valueListenable: _showHeaderCtaNotifier,
      builder: (BuildContext context, bool showCta, Widget? _) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(16, 5, showCta ? 6 : 8, 5),
          child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                brandLogo,
                if (showNavLinks) ...<Widget>[
                  vDivider,
                  Flexible(child: navLinksScroll),
                  vDivider,
                ] else
                  const SizedBox(width: 14),
                // Right: Theme Toggle + Concentric Ghost Sign In + Scroll-Expanded Pill CTA
                _HeaderThemeToggleButton(
                  isDark: isDark,
                  onTap: () => _toggleTheme(context),
                ),
                const SizedBox(width: 4),
                UiButton(
                  label: 'Sign in',
                  variant: UiVariant.ghost,
                  intent: UiIntent.neutral,
                  size: UiSize.xs,
                  rounded: true,
                  style: UiButtonStyle(
                    height: 32,
                    radius: 999,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: context.uiText.caption.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: widget.onSignIn,
                ),
                _DynamicHeaderCtaSlot(
                  visible: showCta,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: UiButton(
                      label: 'Get started',
                      variant: UiVariant.primary,
                      intent: UiIntent.primary,
                      size: UiSize.xs,
                      rounded: true,
                      style: UiButtonStyle(
                        height: 32,
                        radius: 999,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: context.uiText.caption.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => widget.onGetStarted(UserRole.customer),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    final bool isDark = theme.brightness == Brightness.dark;
    final String? cmsTitle = _page?.text('title').trim();
    final bool hasCustomCmsTitle =
        cmsTitle != null &&
        cmsTitle.isNotEmpty &&
        !cmsTitle.toLowerCase().contains('foundation for your');
    final String? cmsDesc = _page?.text('description').trim();
    final bool hasCustomCmsDesc =
        cmsDesc != null &&
        cmsDesc.isNotEmpty &&
        !cmsDesc.toLowerCase().contains('a complete ecosystem combining');

    final double heroFontSize = responsive.isMobile
        ? 34.0
        : (responsive.isTablet ? 48.0 : 66.0);
    final Color accent = colors.series.first;

    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: <Widget>[
          // 1. Precision coordinate grid + live traveling track pulses + scattered trading vector glyphs
          const Positioned.fill(
            child: LandingHeroGridBackdrop(),
          ),
          // 2. Top AlphaThread ribbon rendered ABOVE the hero grid & scrolling with the hero
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: context.sz(210),
            child: RepaintBoundary(
              child: IgnorePointer(
                child: Opacity(
                  opacity: isDark ? 0.34 : 0.40,
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (Rect rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: <double>[0.0, 0.48, 1.0],
                    ).createShader(rect),
                    child: const AlphaThread(
                      animate: true,
                      phase: 29.5,
                      thickness: 54,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 3. Foreground Hero editorial typography & pill CTAs
          Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.sp(theme.spacing.xl),
                context.sz(responsive.isTablet ? 124.0 : 154.0),
                context.sp(theme.spacing.xl),
                context.sz(responsive.isTablet ? 76.0 : 108.0),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.sz(1060)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    // Top "New | AI Copilot for NSE and BSE traders" pill
                    UiScrollReveal(
                      slideOffset: const Offset(0, 0.08),
                      scaleFrom: 1.0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(
                            alpha: isDark ? 0.52 : 0.76,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: colors.borderStrong.withValues(alpha: 0.65),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'New',
                                style: context.uiText.caption.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'AI Copilot for NSE and BSE traders',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.uiText.caption.copyWith(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: colors.foregroundMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.xl)),

                    // Signature Editorial Display Headline with Figma-style Selection Bounding Box
                    if (hasCustomCmsTitle)
                      Text(
                        cmsTitle,
                        textAlign: TextAlign.center,
                        style: context.uiText.display.copyWith(
                          fontSize: heroFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.6,
                          height: 1.12,
                          color: colors.foreground,
                        ),
                      )
                    else ...<Widget>[
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: responsive.isMobile ? 8 : 14,
                        runSpacing: 8,
                        children: <Widget>[
                          Text(
                            'Your',
                            style: context.uiText.display.copyWith(
                              fontSize: heroFontSize,
                              fontWeight: FontWeight.w300,
                              letterSpacing: -1.8,
                              height: 1.08,
                              color: colors.foreground,
                            ),
                          ),
                          _HeroSelectionFrame(
                            accent: accent,
                            phrases: const <String>[
                              'Trading Edge',
                              'Execution Desk',
                              'AI Research Lab',
                              'Playbook System',
                              'Risk Command',
                              'Market Terminal',
                            ],
                            textStyle: context.uiText.display.copyWith(
                              fontSize: heroFontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.8,
                              height: 1.06,
                              color: colors.foreground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'engineered to compound.',
                        textAlign: TextAlign.center,
                        style: context.uiText.display.copyWith(
                          fontSize: heroFontSize,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1.8,
                          height: 1.1,
                          color: colors.foreground,
                        ),
                      ),
                    ],
                    SizedBox(height: context.sp(theme.spacing.xxl)),

                    // Clean 2-line Subtitle
                    UiScrollReveal(
                      delay: const Duration(milliseconds: 110),
                      slideOffset: const Offset(0, 0.06),
                      scaleFrom: 1.0,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: context.sz(640)),
                        child: Text(
                          hasCustomCmsDesc
                              ? cmsDesc
                              : 'Free, in your browser. Sync your broker, journal every trade, and\nlet AI show which setups make you money.',
                          textAlign: TextAlign.center,
                          style: context.uiText.body.copyWith(
                            color: colors.foregroundMuted,
                            fontSize: responsive.isMobile ? 14.5 : 17.0,
                            height: 1.58,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.xxxl)),

                    // Dual Pill CTAs
                    UiScrollReveal(
                      delay: const Duration(milliseconds: 200),
                      slideOffset: const Offset(0, 0.06),
                      scaleFrom: 1.0,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: context.sp(theme.spacing.md),
                        runSpacing: context.sp(theme.spacing.sm),
                        children: <Widget>[
                          UiButton(
                            label: 'Get started free',
                            variant: UiVariant.primary,
                            intent: UiIntent.primary,
                            size: UiSize.lg,
                            rounded: true,
                            style: const UiButtonStyle(
                              height: 48,
                              radius: 999,
                              padding: EdgeInsets.symmetric(horizontal: 26),
                            ),
                            onPressed: () =>
                                widget.onGetStarted(UserRole.customer),
                          ),
                          UiButton(
                            label: 'See how it works',
                            variant: UiVariant.outline,
                            intent: UiIntent.neutral,
                            size: UiSize.lg,
                            rounded: true,
                            style: UiButtonStyle(
                              height: 48,
                              radius: 999,
                              background: colors.surface.withValues(
                                alpha: isDark ? 0.35 : 0.90,
                              ),
                              borderColor: colors.borderStrong,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                            ),
                            onPressed: () => _scrollToSection('platform'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Landing Page FAQ Section
  // ---------------------------------------------------------------------------
  static const List<({String key, String title, List<PricingFaqItem> defaults})>
  _landingFaqCategories = <({
    String key,
    String title,
    List<PricingFaqItem> defaults,
  })>[
    (
      key: 'trading',
      title: 'Trading & Brokers',
      defaults: <PricingFaqItem>[
        PricingFaqItem(
          id: 'default_trading_brokers',
          category: 'trading',
          question: 'Which Indian brokers and segments are supported?',
          answer:
              'AlphaJournal supports NSE & BSE equity, futures, and options journaling with fast CSV tradebook imports and automated broker sync workflows across major Indian brokers.',
        ),
        PricingFaqItem(
          id: 'default_trading_linking',
          category: 'trading',
          question: 'How do playbooks, notes, and trades connect?',
          answer:
              'Every trade log can link directly to your strategy playbooks, research notes, nested backlinks, and NSE tickers so your entire trading thesis is searchable in one workspace.',
        ),
      ],
    ),
    (
      key: 'billing',
      title: 'Pricing & Plans',
      defaults: <PricingFaqItem>[
        PricingFaqItem(
          id: 'default_billing_gst',
          category: 'billing',
          question: 'Are prices shown in INR inclusive of GST?',
          answer:
              'Yes. All subscription prices are displayed transparently in Indian Rupees (₹) inclusive of 18% GST, with full tax invoices available inside Settings → Billing.',
        ),
        PricingFaqItem(
          id: 'default_billing_switch',
          category: 'billing',
          question: 'Can I switch plans or cancel anytime?',
          answer:
              'You can start on the Free tier with no credit card required, upgrade to Basic or Pro whenever you need full Market Intelligence and higher AI quotas, and cancel or switch billing cycles anytime.',
        ),
      ],
    ),
    (
      key: 'features',
      title: 'AI & Quant Tools',
      defaults: <PricingFaqItem>[
        PricingFaqItem(
          id: 'default_features_ai',
          category: 'features',
          question: 'How does the AlphaJournal AI Copilot analyze my trades?',
          answer:
              'The unified multi-provider AI Copilot synthesizes your logged trades, strategy expectancy, and live market context into structured trade setups, bull/bear matrices, sizing formulas, and cited source cards.',
        ),
        PricingFaqItem(
          id: 'default_features_calculators',
          category: 'features',
          question: 'What calculators and risk analytics are included?',
          answer:
              'Core position sizing, risk-reward, and expectancy trackers are available on Free, while Basic and Pro unlock advanced drawdown guardrails, strategy attribution, and multi-scenario quant calculators.',
        ),
      ],
    ),
    (
      key: 'security',
      title: 'Security & Compliance',
      defaults: <PricingFaqItem>[
        PricingFaqItem(
          id: 'default_security_custody',
          category: 'security',
          question: 'Does AlphaJournal have access to my funds or order execution?',
          answer:
              'Never. AlphaJournal operates strictly in read-only / execution-audit mode with zero custody of funds and no withdrawal or order-placing permissions.',
        ),
        PricingFaqItem(
          id: 'default_security_isolation',
          category: 'security',
          question: 'How are my private notes and trade logs protected?',
          answer:
              'All traffic is encrypted over modern TLS, sessions are stored in platform secure storage, and every record is protected by strict database Row Level Security (RLS) so only you can access private entries.',
        ),
      ],
    ),
    (
      key: 'general',
      title: 'Account & Support',
      defaults: <PricingFaqItem>[
        PricingFaqItem(
          id: 'default_general_platforms',
          category: 'general',
          question: 'Which devices can I use AlphaJournal on?',
          answer:
              'Your workspace stays synced across Web (alphajournal.in), macOS, Windows, iOS, and Android with seamless cross-subdomain sessions and native deep links.',
        ),
        PricingFaqItem(
          id: 'default_general_support',
          category: 'general',
          question: 'How do I contact the AlphaJournal team?',
          answer:
              'Reach our support and desk onboarding team anytime via the Support center in Settings or at support@alphajournal.in.',
        ),
      ],
    ),
  ];

  String _normalizeFaqCategory(String raw) {
    final String k = raw.trim().toLowerCase();
    if (k == 'trading' || k == 'brokers' || k == 'markets') return 'trading';
    if (k == 'billing' || k == 'pricing' || k == 'plans') return 'billing';
    if (k == 'features' || k == 'ai' || k == 'quant') return 'features';
    if (k == 'security' || k == 'enterprise' || k == 'compliance' || k == 'tax') {
      return 'security';
    }
    return 'general';
  }

  Widget _buildFaqSection(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    final Widget faqHeadingBlock = Column(
      crossAxisAlignment: responsive.isMobile
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          'Frequently Asked Questions',
          textAlign: responsive.isMobile ? TextAlign.left : TextAlign.right,
          style: context.uiText.display.copyWith(
            fontSize: responsive.isMobile ? 24.0 : 34.0,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.lg)),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(580)),
          child: Text(
            'Everything you need to know about AlphaJournal, quantitative journaling, Indian broker connections, security, and AI capabilities.',
            textAlign: responsive.isMobile ? TextAlign.left : TextAlign.right,
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: 14.0,
              height: 1.55,
            ),
          ),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext ctx, BoxConstraints headerConstraints) {
              if (headerConstraints.maxWidth < 900) {
                return faqHeadingBlock;
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const Expanded(
                    flex: 5,
                    child: LandingFadedGridAccent(height: 164, seed: 2),
                  ),
                  const SizedBox(width: 28),
                  Expanded(flex: 6, child: faqHeadingBlock),
                ],
              );
            },
          ),
          SizedBox(height: context.sp(theme.spacing.xxxl) + 8),

          // Numbered Editorial Hairline FAQ Accordion with smooth open/close animation
          FutureBuilder<PricingCatalogueResponse>(
            future: _pricingFuture,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<PricingCatalogueResponse> snapshot,
                ) {
                  final List<PricingFaqItem> liveFaqs = <PricingFaqItem>[
                    if (snapshot.hasData) ...snapshot.data!.faqs,
                    ...?_page?.faqs,
                  ];

                  final Map<String, List<PricingFaqItem>> grouped =
                      <String, List<PricingFaqItem>>{
                        for (final cat in _landingFaqCategories)
                          cat.key: <PricingFaqItem>[],
                      };

                  final Set<String> seenQuestions = <String>{};
                  for (final PricingFaqItem item in liveFaqs) {
                    final String qNorm = item.question.trim().toLowerCase();
                    if (qNorm.isEmpty || !seenQuestions.add(qNorm)) continue;
                    final String bucket = _normalizeFaqCategory(item.category);
                    grouped[bucket]!.add(item);
                  }

                  return UiAccordion(
                    variant: UiAccordionVariant.editorial,
                    allowMultiple: true,
                    items: <UiAccordionItem>[
                      for (final cat in _landingFaqCategories)
                        UiAccordionItem(
                          title: cat.title,
                          content: _buildEditorialFaqGroupContent(
                            context,
                            colors,
                            grouped[cat.key]!.isNotEmpty
                                ? grouped[cat.key]!
                                : cat.defaults,
                          ),
                        ),
                    ],
                  );
                },
          ),
        ],
      ),
    );
  }

  Widget _buildEditorialFaqGroupContent(
    BuildContext context,
    UiColors colors,
    List<PricingFaqItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 20),
          Text(
            items[i].question,
            style: context.uiText.bodyStrong.copyWith(
              fontSize: 15.0,
              fontWeight: FontWeight.w700,
              color: colors.foreground,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            items[i].answer,
            style: context.uiText.body.copyWith(
              fontSize: 14.0,
              color: colors.foregroundMuted,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPricingSection(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    final bool compact = responsive.isMobile;

    final Widget pricingHeadingBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _page?.text('pricing_title') ??
              'One subscription. Access to everything.',
          textAlign: TextAlign.left,
          style: context.uiText.display.copyWith(
            fontSize: compact ? 24.0 : 34.0,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
            color: colors.foreground,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.lg)),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(620)),
          child: Text(
            'Manage your AlphaJournal subscription tier and workspace quotas in Indian Rupees (₹) inclusive of 18% GST. Switch between monthly and annual billing anytime.',
            textAlign: TextAlign.left,
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: 14.0,
              height: 1.55,
            ),
          ),
        ),
      ],
    );

    final bool isDarkTheme = theme.brightness == Brightness.dark;
    final List<BoxShadow> activePillShadow = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: isDarkTheme ? 0.32 : 0.16),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
    final Widget billingCycleToggle = Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: context.radius(theme.radii.pill),
        border: Border.all(
          color: colors.borderStrong,
          width: theme.borders.hairline,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            button: true,
            selected: !_isAnnualPricing,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!_isAnnualPricing) return;
                setState(() {
                  _isAnnualPricing = false;
                  _pricingFuture = _pricingRepo.getPricingCatalogue(
                    annual: false,
                  );
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: !_isAnnualPricing
                      ? colors.primary
                      : Colors.transparent,
                  borderRadius: context.radius(theme.radii.pill),
                  border: !_isAnnualPricing
                      ? Border.all(
                          color: colors.primary,
                          width: theme.borders.hairline,
                        )
                      : null,
                  boxShadow: !_isAnnualPricing ? activePillShadow : null,
                ),
                child: Text(
                  'Monthly',
                  style: context.uiText.bodyStrong.copyWith(
                    fontSize: 13,
                    color: !_isAnnualPricing
                        ? colors.onPrimary
                        : colors.foregroundMuted,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            selected: _isAnnualPricing,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_isAnnualPricing) return;
                setState(() {
                  _isAnnualPricing = true;
                  _pricingFuture = _pricingRepo.getPricingCatalogue(
                    annual: true,
                  );
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _isAnnualPricing ? colors.primary : Colors.transparent,
                  borderRadius: context.radius(theme.radii.pill),
                  border: _isAnnualPricing
                      ? Border.all(
                          color: colors.primary,
                          width: theme.borders.hairline,
                        )
                      : null,
                  boxShadow: _isAnnualPricing ? activePillShadow : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Billed annually',
                      style: context.uiText.bodyStrong.copyWith(
                        fontSize: 13,
                        color: _isAnnualPricing
                            ? colors.onPrimary
                            : colors.foregroundMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    UiBadge(
                      label: 'Save 20%',
                      intent: UiIntent.success,
                      variant: _isAnnualPricing
                          ? UiBadgeVariant.solid
                          : UiBadgeVariant.soft,
                      size: UiSize.xs,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (compact || responsive.width < 920) ...<Widget>[
            pricingHeadingBlock,
            const SizedBox(height: 18),
            Align(alignment: Alignment.centerLeft, child: billingCycleToggle),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(child: pricingHeadingBlock),
                const SizedBox(width: 24),
                billingCycleToggle,
              ],
            ),
          SizedBox(height: context.sp(theme.spacing.xxxl)),

          // 3 Overlay-Styled Cards FutureBuilder (Full Width, 1:1 Skeleton Loader)
          FutureBuilder<PricingCatalogueResponse>(
            future: _pricingFuture,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<PricingCatalogueResponse> snapshot,
                ) {
                  final Widget content;
                  if (!snapshot.hasData) {
                    if (snapshot.hasError) {
                      content = UiEmptyState(
                        key: const ValueKey<String>('pricing_error'),
                        title: 'Pricing unavailable',
                        actionLabel: 'Try again',
                        onActionPressed: () => setState(
                          () => _pricingFuture = _pricingRepo
                              .getPricingCatalogue(annual: _isAnnualPricing),
                        ),
                      );
                    } else {
                      content = _buildLandingPricingSkeletonGrid(
                        context,
                        theme,
                        colors,
                      );
                    }
                  } else {
                    final List<PricingPlanModel> plans = snapshot.data!.plans;
                    content = UiCardGrid(
                      key: ValueKey<String>(
                        'pricing_cards_${_isAnnualPricing ? 'annual' : 'monthly'}',
                      ),
                      equalHeight: true,
                      intrinsicHeight: true,
                      tabletColumns: 1,
                      desktopColumns: 3,
                      largeColumns: 3,
                      children: [
                        for (int i = 0; i < plans.length; i++)
                          UiScrollReveal(
                            delay: Duration(milliseconds: 90 * i),
                            slideOffset: const Offset(0, 0.06),
                            scaleFrom: 0.97,
                            child: _buildLandingPricingCard(
                              context,
                              theme,
                              colors,
                              plans[i],
                            ),
                          ),
                      ],
                    );
                  }

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: content,
                  );
                },
          ),
          const SizedBox(height: 20),
          Text(
            'Prices shown in INR inclusive of 18% GST. Cancel or change your plan anytime from Settings → Billing.',
            textAlign: TextAlign.center,
            style: context.uiText.caption.copyWith(
              fontSize: 12,
              color: colors.foregroundSubtle,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              UiButton(
                label: 'See Whole Details & Feature Matrix',
                leading: const Icon(Icons.table_chart_outlined, size: 16),
                trailing: const Icon(Icons.arrow_forward_rounded, size: 15),
                variant: UiVariant.outline,
                intent: UiIntent.primary,
                size: UiSize.lg,
                rounded: true,
                style: const UiButtonStyle(
                  radius: 999,
                  padding: EdgeInsets.symmetric(horizontal: 24),
                ),
                onPressed: () {
                  if (widget.onViewFullPricing != null) {
                    widget.onViewFullPricing!();
                  } else {
                    widget.onGetStarted(UserRole.customer);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<({String heading, List<({IconData icon, String label})> items})>
  _landingSectionsForTier(AppTier tier) {
    final CustomerTierQuota q = CustomerTierQuota.forTier(tier);
    String formatQuota(int value, String singular, String plural) {
      if (value >= 100000) return 'Unlimited $plural';
      return '$value ${value == 1 ? singular : plural}';
    }

    return switch (tier) {
      AppTier.free => [
        (
          heading: 'Workspace & Journaling',
          items: [
            (
              icon: Icons.edit_note_rounded,
              label: formatQuota(q.maxNotes, 'note', 'notes'),
            ),
            (
              icon: Icons.candlestick_chart_rounded,
              label: formatQuota(q.maxTrades, 'trade log', 'trade logs'),
            ),
            (
              icon: Icons.track_changes_rounded,
              label: formatQuota(
                q.maxLiveStrategies,
                'live strategy',
                'live strategies',
              ),
            ),
            (
              icon: Icons.bookmark_border_rounded,
              label: formatQuota(q.maxWatchlists, 'watchlist', 'watchlists'),
            ),
            (
              icon: Icons.notifications_none_rounded,
              label: formatQuota(q.maxAlerts, 'price alert', 'price alerts'),
            ),
          ],
        ),
        (
          heading: 'Community & Markets',
          items: [
            (
              icon: Icons.forum_outlined,
              label:
                  '${q.maxCommunityPostsPerDay} posts & ${q.maxCommunityCommentsPerDay} replies / day',
            ),
            (
              icon: Icons.show_chart_rounded,
              label: 'Market previews & basic calculators',
            ),
          ],
        ),
      ],
      AppTier.premium => [
        (
          heading: 'Markets & Desk',
          items: [
            (
              icon: Icons.candlestick_chart_rounded,
              label:
                  '${formatQuota(q.maxNotes, 'note', 'notes')} & ${formatQuota(q.maxTrades, 'trade', 'trades')}',
            ),
            (
              icon: Icons.track_changes_rounded,
              label:
                  '${formatQuota(q.maxLiveStrategies, 'strategy', 'strategies')} & ${formatQuota(q.maxWatchlists, 'watchlist', 'watchlists')}',
            ),
            (
              icon: Icons.insights_rounded,
              label: 'Full Market Intelligence & screeners',
            ),
            (
              icon: Icons.calculate_outlined,
              label: 'Advanced risk & position calculators',
            ),
            (
              icon: Icons.mail_outline_rounded,
              label: 'Direct messages & trader network',
            ),
          ],
        ),
        (
          heading: 'AI & Alerts',
          items: [
            (
              icon: Icons.auto_awesome_rounded,
              label: '${q.maxAiQueriesPerMonth} AI Copilot queries / mo',
            ),
            (
              icon: Icons.notifications_active_outlined,
              label: formatQuota(q.maxAlerts, 'active alert', 'active alerts'),
            ),
            (
              icon: Icons.forum_outlined,
              label:
                  '${q.maxCommunityPostsPerDay} posts & ${q.maxCommunityCommentsPerDay} replies / day',
            ),
          ],
        ),
      ],
      AppTier.enterprise => [
        (
          heading: 'Institutional Desk',
          items: [
            (
              icon: Icons.layers_outlined,
              label:
                  '${formatQuota(q.maxNotes, 'note', 'notes')} & ${formatQuota(q.maxTrades, 'trade', 'trades')}',
            ),
            (
              icon: Icons.picture_as_pdf_outlined,
              label: 'CSV & PDF performance exports',
            ),
            (
              icon: Icons.science_outlined,
              label: 'Advanced strategy backtesting',
            ),
            (
              icon: Icons.query_stats_rounded,
              label: 'Deep expectancy & drawdown analytics',
            ),
          ],
        ),
        (
          heading: 'AI & Priority',
          items: [
            (
              icon: Icons.bolt_rounded,
              label: '${q.maxAiQueriesPerMonth} AI Copilot queries / mo',
            ),
            (
              icon: Icons.notifications_active_rounded,
              label: formatQuota(q.maxAlerts, 'active alert', 'active alerts'),
            ),
            (
              icon: Icons.verified_outlined,
              label:
                  '${q.maxCommunityPostsPerDay} posts & ${q.maxCommunityCommentsPerDay} replies / day',
            ),
          ],
        ),
      ],
    };
  }

  Widget _buildLandingPricingSkeletonGrid(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
  ) {
    return UiCardGrid(
      key: const ValueKey<String>('pricing_skeleton'),
      equalHeight: true,
      intrinsicHeight: true,
      tabletColumns: 1,
      desktopColumns: 3,
      largeColumns: 3,
      children: <Widget>[
        _buildLandingPricingSkeletonCard(
          context,
          theme,
          colors,
          highlighted: false,
          hasBadge: false,
          sectionRowCounts: const <int>[5, 2],
        ),
        _buildLandingPricingSkeletonCard(
          context,
          theme,
          colors,
          highlighted: true,
          hasBadge: true,
          sectionRowCounts: const <int>[5, 3],
        ),
        _buildLandingPricingSkeletonCard(
          context,
          theme,
          colors,
          highlighted: false,
          hasBadge: true,
          sectionRowCounts: const <int>[4, 3],
        ),
      ],
    );
  }

  Widget _buildLandingPricingSkeletonCard(
    BuildContext context,
    UiTheme theme,
    UiColors colors, {
    required bool highlighted,
    required bool hasBadge,
    required List<int> sectionRowCounts,
  }) {
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardBg = isDark
        ? colors.surfaceMuted.withValues(alpha: 0.38)
        : colors.surface;
    const List<double> rowWidthFactors = <double>[0.74, 0.86, 0.68, 0.82, 0.72];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlighted
            ? (isDark
                  ? colors.surfaceMuted.withValues(alpha: 0.55)
                  : colors.surface)
            : cardBg,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(
          color: highlighted
              ? colors.primary.withValues(alpha: isDark ? 0.45 : 0.65)
              : colors.border,
          width: highlighted ? 1.25 : theme.borders.hairline,
        ),
        boxShadow: isDark ? null : theme.shadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Plan name + optional badge pill
          Row(
            children: <Widget>[
              UiSkeleton(
                width: highlighted ? 62 : 54,
                height: 18,
                borderRadius: BorderRadius.circular(6),
              ),
              const Spacer(),
              if (hasBadge)
                UiSkeleton.badge(
                  width: highlighted ? 88 : 68,
                  height: 22,
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Price figure + /month suffix
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              UiSkeleton(
                width: highlighted ? 96 : 84,
                height: 34,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: UiSkeleton(
                  width: 44,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Billing caption
          Align(
            alignment: Alignment.centerLeft,
            child: UiSkeleton(
              width: highlighted ? 186 : 168,
              height: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          // Full-width pill CTA skeleton matching _LandingOverlayCtaButton (42px)
          UiSkeleton(
            width: double.infinity,
            height: 42,
            borderRadius: context.radius(theme.radii.pill),
          ),
          const SizedBox(height: 18),
          // Intro line
          Align(
            alignment: Alignment.centerLeft,
            child: UiSkeleton(
              width: 138,
              height: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          // Feature sections matching real divider + icon + label rows
          for (int s = 0; s < sectionRowCounts.length; s++) ...<Widget>[
            if (s > 0) const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: UiSkeleton(
                width: s == 0 ? 124 : 108,
                height: 11,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Divider(height: 1, thickness: 1, color: colors.border),
            const SizedBox(height: 10),
            for (int r = 0; r < sectionRowCounts[s]; r++)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: <Widget>[
                    UiSkeleton(
                      width: 15,
                      height: 15,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            rowWidthFactors[(r + s * 2) % rowWidthFactors.length],
                        child: UiSkeleton(
                          height: 13,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLandingPricingCard(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    PricingPlanModel plan,
  ) {
    final bool isDark = theme.brightness == Brightness.dark;
    final bool highlighted =
        plan.highlighted || plan.tier == AppTier.premium;
    final sections = _landingSectionsForTier(plan.tier);
    final Color cardBg = isDark
        ? colors.surfaceMuted.withValues(alpha: 0.38)
        : colors.surface;

    final String introLine = switch (plan.tier) {
      AppTier.free => 'Our introductory plan:',
      AppTier.premium => 'Everything in Free, and:',
      AppTier.enterprise => 'Everything in Basic, and:',
    };

    final String? badgeText = highlighted
        ? 'Most popular'
        : (plan.tier == AppTier.enterprise ? 'Full desk' : null);

    final UiIntent badgeIntent = highlighted
        ? UiIntent.primary
        : UiIntent.neutral;

    final String ctaLabel = plan.tier == AppTier.free
        ? 'Start Free'
        : 'Get ${plan.name}';

    final double annualTotal = plan.annualMonthlyAmount * 12;
    final String billingCaption = plan.monthlyAmount <= 0
        ? 'Free forever · No credit card required'
        : (_isAnnualPricing
              ? '${plan.currencySymbol}${annualTotal.toStringAsFixed(0)} billed annually · Save 20%'
              : 'Billed monthly · Cancel anytime');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlighted
            ? (isDark
                  ? colors.surfaceMuted.withValues(alpha: 0.55)
                  : colors.surface)
            : cardBg,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(
          color: highlighted
              ? colors.primary.withValues(alpha: isDark ? 0.45 : 0.72)
              : colors.border,
          width: highlighted ? 1.5 : theme.borders.hairline,
        ),
        boxShadow: isDark
            ? null
            : (highlighted ? theme.shadows.md : theme.shadows.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                plan.name,
                style: context.uiText.heading.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const Spacer(),
              if (badgeText != null)
                UiBadge(
                  label: badgeText,
                  intent: badgeIntent,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                plan.priceLabel(isAnnual: _isAnnualPricing),
                style: context.uiText.display.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/month',
                style: context.uiText.caption.copyWith(
                  fontSize: 12,
                  color: colors.foregroundSubtle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            billingCaption,
            style: context.uiText.caption.copyWith(
              fontSize: 11.5,
              color: _isAnnualPricing && plan.monthlyAmount > 0
                  ? colors.bullish
                  : colors.foregroundSubtle,
              fontWeight: _isAnnualPricing && plan.monthlyAmount > 0
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          _LandingOverlayCtaButton(
            label: ctaLabel,
            highlighted: highlighted,
            onTap: () => widget.onGetStarted(UserRole.customer),
          ),
          const SizedBox(height: 18),
          Text(
            introLine,
            style: context.uiText.caption.copyWith(
              fontSize: 12,
              color: colors.foregroundMuted,
            ),
          ),
          const SizedBox(height: 14),
          for (int s = 0; s < sections.length; s++) ...<Widget>[
            if (s > 0) const SizedBox(height: 14),
            Text(
              sections[s].heading,
              style: context.uiText.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.foregroundSubtle,
              ),
            ),
            const SizedBox(height: 6),
            Divider(height: 1, thickness: 1, color: colors.border),
            const SizedBox(height: 10),
            for (final item in sections[s].items)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        item.icon,
                        size: 15,
                        color: colors.foregroundMuted,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        item.label,
                        style: context.uiText.caption.copyWith(
                          fontSize: 12.5,
                          color: colors.foreground,
                          height: 1.32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LandingOverlayCtaButton extends StatefulWidget {
  const _LandingOverlayCtaButton({
    required this.label,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  State<_LandingOverlayCtaButton> createState() =>
      _LandingOverlayCtaButtonState();
}

class _LandingOverlayCtaButtonState extends State<_LandingOverlayCtaButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color bgColor = widget.highlighted
        ? (_hovered ? theme.colors.primaryHover : theme.colors.primary)
        : (_hovered ? theme.colors.surfaceHover : theme.colors.surface);

    final Color textColor = widget.highlighted
        ? theme.colors.onPrimary
        : theme.colors.foreground;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: context.radius(theme.radii.pill),
            border: widget.highlighted
                ? null
                : Border.all(
                    color: _hovered
                        ? theme.colors.foregroundMuted
                        : theme.colors.borderStrong,
                  ),
          ),
          child: Text(
            widget.label,
            style: context.uiText.body.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Floating header navigation strip with a single gliding frosted pill
/// indicator that smoothly slides & morphs width behind the active item.
class _SlidingHeaderNavBar extends StatefulWidget {
  const _SlidingHeaderNavBar({
    required this.activeSection,
    required this.items,
    required this.onSelect,
  });

  final String activeSection;
  final List<({String id, String label})> items;
  final ValueChanged<String> onSelect;

  @override
  State<_SlidingHeaderNavBar> createState() => _SlidingHeaderNavBarState();
}

class _SlidingHeaderNavBarState extends State<_SlidingHeaderNavBar> {
  final GlobalKey _stackKey = GlobalKey();
  late final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{
    for (final item in widget.items) item.id: GlobalKey(),
  };

  double? _pillLeft;
  double? _pillWidth;
  bool _hasAnimatedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPillGeometry());
  }

  @override
  void didUpdateWidget(covariant _SlidingHeaderNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeSection != widget.activeSection) {
      _syncPillGeometry();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPillGeometry());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPillGeometry());
  }

  void _syncPillGeometry() {
    if (!mounted) return;
    final BuildContext? stackCtx = _stackKey.currentContext;
    final BuildContext? itemCtx =
        _itemKeys[widget.activeSection]?.currentContext;
    if (stackCtx == null || itemCtx == null) return;

    final RenderObject? stackRo = stackCtx.findRenderObject();
    final RenderObject? itemRo = itemCtx.findRenderObject();
    if (stackRo is! RenderBox ||
        itemRo is! RenderBox ||
        !stackRo.attached ||
        !itemRo.attached ||
        !itemRo.hasSize) {
      return;
    }

    final Offset offset = itemRo.localToGlobal(Offset.zero, ancestor: stackRo);
    final double nextLeft = offset.dx;
    final double nextWidth = itemRo.size.width;

    if (_pillLeft == null ||
        (_pillLeft! - nextLeft).abs() > 0.25 ||
        (_pillWidth! - nextWidth).abs() > 0.25) {
      final bool wasInitialized = _pillLeft != null;
      setState(() {
        _pillLeft = nextLeft;
        _pillWidth = nextWidth;
        if (wasInitialized) _hasAnimatedOnce = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isDark = theme.brightness == Brightness.dark;
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);
    final Duration slideDuration = (!_hasAnimatedOnce || reducedMotion)
        ? Duration.zero
        : const Duration(milliseconds: 300);

    final Color pillFill = isDark
        ? colors.foreground.withValues(alpha: 0.13)
        : colors.foreground.withValues(alpha: 0.10);
    final Color pillBorder = isDark
        ? colors.foreground.withValues(alpha: 0.15)
        : colors.borderStrong.withValues(alpha: 0.68);

    return RepaintBoundary(
      child: Stack(
        key: _stackKey,
        alignment: Alignment.centerLeft,
        children: <Widget>[
          if (_pillLeft != null && _pillWidth != null)
            AnimatedPositioned(
              key: const ValueKey<String>('landing-header-sliding-pill'),
              duration: slideDuration,
              curve: Curves.easeOutCubic,
              left: _pillLeft,
              top: 0,
              bottom: 0,
              width: _pillWidth,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: pillFill,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: pillBorder, width: 1.0),
                    boxShadow: !isDark
                        ? <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < widget.items.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 2),
                _HeaderNavLink(
                  key: _itemKeys[widget.items[i].id],
                  label: widget.items[i].label,
                  isActive: widget.activeSection == widget.items[i].id,
                  onTap: () => widget.onSelect(widget.items[i].id),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderNavLink extends StatefulWidget {
  const _HeaderNavLink({
    super.key,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  State<_HeaderNavLink> createState() => _HeaderNavLinkState();
}

class _HeaderNavLinkState extends State<_HeaderNavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isDark = theme.brightness == Brightness.dark;
    final bool active = widget.isActive;
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);

    // Hover background only shows when inactive; active state is rendered by
    // the shared gliding pill underneath in [_SlidingHeaderNavBar].
    final Color hoverFill = !active && _isHovered
        ? colors.foreground.withValues(alpha: isDark ? 0.07 : 0.06)
        : colors.foreground.withValues(alpha: 0.0);

    final Color regularColor = _isHovered
        ? colors.foreground
        : (isDark
              ? colors.foregroundMuted.withValues(alpha: 0.88)
              : colors.foregroundMuted);

    return Semantics(
      button: true,
      selected: active,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: hoverFill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: _SmoothBoldNavLabel(
              label: widget.label,
              active: active,
              regularColor: regularColor,
              boldColor: colors.foreground,
              reducedMotion: reducedMotion,
            ),
          ),
        ),
      ),
    );
  }
}

/// Crossfades smoothly between Regular (400) and Bold (700) inside a fixed
/// bold-measured box so there is zero horizontal jitter and zero discrete
/// weight-snap on non-variable font families.
class _SmoothBoldNavLabel extends StatelessWidget {
  const _SmoothBoldNavLabel({
    required this.label,
    required this.active,
    required this.regularColor,
    required this.boldColor,
    required this.reducedMotion,
  });

  final String label;
  final bool active;
  final Color regularColor;
  final Color boldColor;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    final TextStyle base = context.uiText.caption.copyWith(
      fontSize: 13.0,
      letterSpacing: -0.1,
      height: 1.25,
    );
    final TextStyle regularStyle = base.copyWith(
      fontWeight: FontWeight.w400,
      color: regularColor,
    );
    final TextStyle boldStyle = base.copyWith(
      fontWeight: FontWeight.w700,
      color: boldColor,
    );

    // Measure the exact bold width once so item geometry never shifts when
    // switching between regular and bold (keeping the gliding pill rock-solid).
    final TextPainter boldMeasure = TextPainter(
      text: TextSpan(text: label, style: boldStyle),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final double measuredWidth = boldMeasure.width.ceilToDouble();
    final double measuredHeight = boldMeasure.height.ceilToDouble();
    boldMeasure.dispose();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: active ? 1.0 : 0.0),
      duration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? _) {
        final Color blendedRegular = Color.lerp(regularColor, boldColor, t)!;
        return SizedBox(
          width: measuredWidth,
          height: measuredHeight,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Single semantic Text widget for accessibility & widget tests.
              Opacity(
                opacity: (1.0 - t).clamp(0.0, 1.0),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: regularStyle.copyWith(color: blendedRegular),
                ),
              ),
              if (t > 0.01)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CrossfadeBoldTextPainter(
                        label: label,
                        style: boldStyle.copyWith(
                          color: boldColor.withValues(alpha: t),
                        ),
                        textDirection: Directionality.of(context),
                        textScaler: textScaler,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CrossfadeBoldTextPainter extends CustomPainter {
  const _CrossfadeBoldTextPainter({
    required this.label,
    required this.style,
    required this.textDirection,
    required this.textScaler,
  });

  final String label;
  final TextStyle style;
  final TextDirection textDirection;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) * 0.5, (size.height - tp.height) * 0.5),
    );
    tp.dispose();
  }

  @override
  bool shouldRepaint(covariant _CrossfadeBoldTextPainter oldDelegate) =>
      oldDelegate.label != label ||
      oldDelegate.style != style ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.textScaler != textScaler;
}

/// Concentric circular Light/Dark theme toggle button for the landing header.
class _HeaderThemeToggleButton extends StatefulWidget {
  const _HeaderThemeToggleButton({
    required this.isDark,
    required this.onTap,
    this.frostedPill = false,
  });

  final bool isDark;
  final VoidCallback onTap;
  final bool frostedPill;

  @override
  State<_HeaderThemeToggleButton> createState() =>
      _HeaderThemeToggleButtonState();
}

class _HeaderThemeToggleButtonState extends State<_HeaderThemeToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isDark = widget.isDark;
    final String label = isDark
        ? 'Switch to light theme'
        : 'Switch to dark theme';
    final double size = widget.frostedPill ? 44.0 : 32.0;

    final Color bgColor = widget.frostedPill
        ? colors.surface.withValues(alpha: isDark ? 0.72 : 0.88)
        : (_hovered
              ? (isDark
                    ? colors.foreground.withValues(alpha: 0.11)
                    : colors.foreground.withValues(alpha: 0.08))
              : (isDark
                    ? colors.foreground.withValues(alpha: 0.05)
                    : colors.foreground.withValues(alpha: 0.04)));

    final Color borderColor = widget.frostedPill
        ? colors.borderStrong.withValues(alpha: isDark ? 0.65 : 0.75)
        : (_hovered
              ? colors.borderStrong.withValues(alpha: isDark ? 0.72 : 0.68)
              : colors.borderStrong.withValues(alpha: isDark ? 0.34 : 0.36));

    final Color iconColor = _hovered
        ? colors.foreground
        : colors.foreground.withValues(alpha: isDark ? 0.86 : 0.82);

    final Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: widget.frostedPill
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return RotationTransition(
              turns: Tween<double>(begin: 0.82, end: 1.0).animate(animation),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.72, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
            );
          },
          child: AppThemeGlyph(
            key: ValueKey<bool>(isDark),
            isDark: isDark,
            size: widget.frostedPill ? 19 : 16,
            color: iconColor,
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: widget.frostedPill
                  ? ClipOval(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: button,
                      ),
                    )
                  : button,
            ),
          ),
        ),
      ),
    );
  }
}

/// Editorial Figma-style selection bounding box with 4 crisp corner anchor
/// handles that animates AlphaJournal capability phrases letter-by-letter
/// (live typing & backspacing with an accent caret while the selection frame
/// hugs the text width dynamically).
class _HeroSelectionFrame extends StatefulWidget {
  const _HeroSelectionFrame({
    required this.accent,
    required this.phrases,
    required this.textStyle,
  });

  final Color accent;
  final List<String> phrases;
  final TextStyle textStyle;

  @override
  State<_HeroSelectionFrame> createState() => _HeroSelectionFrameState();
}

enum _HeroTypingPhase { holding, deleting, pausingEmpty, typing }

class _HeroSelectionFrameState extends State<_HeroSelectionFrame> {
  int _phraseIndex = 0;
  late int _visibleChars = widget.phrases.first.length;
  _HeroTypingPhase _phase = _HeroTypingPhase.holding;
  bool _hovered = false;
  bool _caretVisible = true;
  Timer? _stepTimer;
  Timer? _caretTimer;

  static const Duration _holdDuration = Duration(milliseconds: 2300);
  static const Duration _deleteCharDuration = Duration(milliseconds: 34);
  static const Duration _emptyPauseDuration = Duration(milliseconds: 120);
  static const Duration _typeCharDuration = Duration(milliseconds: 52);

  @override
  void initState() {
    super.initState();
    _scheduleNextStep(_holdDuration);
    _caretTimer = Timer.periodic(const Duration(milliseconds: 520), (_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        if (!_caretVisible) setState(() => _caretVisible = true);
        return;
      }
      setState(() => _caretVisible = !_caretVisible);
    });
  }

  void _scheduleNextStep(Duration delay) {
    _stepTimer?.cancel();
    if (widget.phrases.length < 2) return;
    _stepTimer = Timer(delay, _tick);
  }

  void _tick() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scheduleNextStep(_holdDuration);
      return;
    }
    if (_hovered && _phase == _HeroTypingPhase.holding) {
      _scheduleNextStep(const Duration(milliseconds: 400));
      return;
    }

    final String currentPhrase =
        widget.phrases[_phraseIndex % widget.phrases.length];

    switch (_phase) {
      case _HeroTypingPhase.holding:
        setState(() {
          _phase = _HeroTypingPhase.deleting;
          _caretVisible = true;
          if (_visibleChars > 0) _visibleChars--;
        });
        _scheduleNextStep(_deleteCharDuration);
      case _HeroTypingPhase.deleting:
        if (_visibleChars > 0) {
          setState(() {
            _visibleChars--;
            _caretVisible = true;
          });
          _scheduleNextStep(_deleteCharDuration);
        } else {
          setState(() {
            _phraseIndex = (_phraseIndex + 1) % widget.phrases.length;
            _phase = _HeroTypingPhase.pausingEmpty;
          });
          _scheduleNextStep(_emptyPauseDuration);
        }
      case _HeroTypingPhase.pausingEmpty:
        setState(() {
          _phase = _HeroTypingPhase.typing;
          _visibleChars = 1;
          _caretVisible = true;
        });
        _scheduleNextStep(_typeCharDuration);
      case _HeroTypingPhase.typing:
        if (_visibleChars < currentPhrase.length) {
          setState(() {
            _visibleChars++;
            _caretVisible = true;
          });
          _scheduleNextStep(_typeCharDuration);
        } else {
          setState(() => _phase = _HeroTypingPhase.holding);
          _scheduleNextStep(_holdDuration);
        }
    }
  }

  void _advanceManually() {
    if (widget.phrases.length < 2) return;
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _phraseIndex = (_phraseIndex + 1) % widget.phrases.length;
      if (reduced) {
        _visibleChars = widget.phrases[_phraseIndex].length;
        _phase = _HeroTypingPhase.holding;
      } else {
        _visibleChars = 1;
        _phase = _HeroTypingPhase.typing;
        _caretVisible = true;
      }
    });
    _scheduleNextStep(reduced ? _holdDuration : _typeCharDuration);
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _caretTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);
    final Color handleFill = context.ui.colors.background;
    final String fullPhrase =
        widget.phrases[_phraseIndex % widget.phrases.length];
    final int clampedLen = reducedMotion
        ? fullPhrase.length
        : _visibleChars.clamp(0, fullPhrase.length);
    final String displayed = fullPhrase.substring(0, clampedLen);
    final double fontSize = widget.textStyle.fontSize ?? 48.0;
    final double lineHeight = fontSize * (widget.textStyle.height ?? 1.06);
    final bool isActivelyAnimating =
        _phase == _HeroTypingPhase.typing || _phase == _HeroTypingPhase.deleting;

    Widget handle() => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _hovered ? 8 : 7,
      height: _hovered ? 8 : 7,
      decoration: BoxDecoration(
        color: handleFill,
        border: Border.all(color: widget.accent, width: 1.5),
      ),
    );

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advanceManually,
        child: Semantics(
          button: true,
          liveRegion: true,
          label: fullPhrase,
          hint: 'Tap to cycle AlphaJournal capabilities',
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _hovered
                      ? widget.accent.withValues(alpha: 0.08)
                      : widget.accent.withValues(alpha: 0.0),
                  border: Border.all(
                    color: widget.accent.withValues(
                      alpha: _hovered ? 1.0 : 0.85,
                    ),
                    width: 1.5,
                  ),
                ),
                child: SizedBox(
                  height: lineHeight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        displayed,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: widget.textStyle,
                      ),
                      if (!reducedMotion)
                        AnimatedOpacity(
                          opacity: (isActivelyAnimating || _caretVisible)
                              ? 1.0
                              : 0.0,
                          duration: const Duration(milliseconds: 120),
                          child: Container(
                            width: 2.5,
                            height: fontSize * 0.86,
                            margin: const EdgeInsets.only(left: 3),
                            decoration: BoxDecoration(
                              color: widget.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(top: -3.5, left: -3.5, child: handle()),
              Positioned(top: -3.5, right: -3.5, child: handle()),
              Positioned(bottom: -3.5, left: -3.5, child: handle()),
              Positioned(bottom: -3.5, right: -3.5, child: handle()),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Smoothly expands/contracts the floating pill header horizontally to reveal
/// the primary CTA button once the user scrolls past the Hero section.
class _DynamicHeaderCtaSlot extends StatefulWidget {
  const _DynamicHeaderCtaSlot({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<_DynamicHeaderCtaSlot> createState() => _DynamicHeaderCtaSlotState();
}

class _DynamicHeaderCtaSlotState extends State<_DynamicHeaderCtaSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    reverseDuration: const Duration(milliseconds: 260),
    value: widget.visible ? 1.0 : 0.0,
  );
  late final Animation<double> _sizeCurve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<double> _fadeCurve = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.22, 1.0, curve: Curves.easeOut),
    reverseCurve: const Interval(0.0, 0.65, curve: Curves.easeIn),
  );
  late final Animation<double> _scaleCurve = Tween<double>(
    begin: 0.88,
    end: 1.0,
  ).animate(_sizeCurve);

  @override
  void didUpdateWidget(covariant _DynamicHeaderCtaSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      final bool reduced = MediaQuery.disableAnimationsOf(context);
      if (reduced) {
        _controller.value = widget.visible ? 1.0 : 0.0;
      } else if (widget.visible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        if (_controller.isDismissed) {
          return const SizedBox.shrink();
        }
        return ClipRect(
          child: SizeTransition(
            axis: Axis.horizontal,
            sizeFactor: _sizeCurve,
            alignment: Alignment.centerLeft,
            child: FadeTransition(
              opacity: _fadeCurve,
              child: ScaleTransition(
                scale: _scaleCurve,
                alignment: Alignment.centerRight,
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
