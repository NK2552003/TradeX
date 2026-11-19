import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/public_site/data/public_site_repository.dart';
import 'package:alphajournal/features/public_site/models/public_site_content.dart';
import 'package:alphajournal/core/data/demo_data_source.dart';
import 'package:alphajournal/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/models/pricing_models.dart';
import 'package:alphajournal/features/auth/presentation/widgets/alphajournal_footer.dart';
import 'package:alphajournal/features/auth/widgets/auth_carousel_panel.dart';

/// Records for the marketing preview. They come from the same source the
/// signed-in app reads, so the landing page cannot show a US ticker or a strategy
/// that does not exist once the reader is inside an Indian-market workspace.
final DemoDataSource _demo = DemoDataSource.instance;
final AppPost _previewPost = _demo.posts(limit: 1).first;
final List<AppStrategy> _previewStrategies = _demo
    .strategies()
    .take(2)
    .toList();
final AppNewsItem _previewNews = _demo.news(limit: 1).first;
final AppAiInsight _previewInsight = _demo.insights(limit: 1).first;

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
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _showcaseKey = GlobalKey();
  final GlobalKey _personasKey = GlobalKey();
  final GlobalKey _pricingKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  late final PublicSiteRepository _content =
      widget.repository ?? publicSiteRepository();
  late final SubscriptionPricingRepository _pricingRepo =
      SubscriptionPricingRepositoryImpl(content: _content);
  PublicSiteContent? _page;
  bool _isAnnualPricing = true;
  String _selectedLandingFaqCategory = 'all';
  Future<PricingCatalogueResponse>? _pricingRequest;
  Future<PricingCatalogueResponse> get _pricingFuture => _pricingRequest ??=
      _pricingRepo.getPricingCatalogue(annual: _isAnnualPricing);
  set _pricingFuture(Future<PricingCatalogueResponse> value) =>
      _pricingRequest = value;

  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);

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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _isScrolledNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final bool scrolled = _scrollController.offset > 40.0;
    if (_isScrolledNotifier.value != scrolled) {
      _isScrolledNotifier.value = scrolled;
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

  void _scrollToSection(String section) {
    switch (section) {
      case 'showcase':
        _scrollToKey(_showcaseKey);
        break;
      case 'personas':
        _scrollToKey(_personasKey);
        break;
      case 'features':
        _scrollToKey(_featuresKey);
        break;
      case 'pricing':
        _scrollToKey(_pricingKey);
        break;
      case 'faq':
        _scrollToKey(_faqKey);
        break;
      default:
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
    }
  }

  static const List<Map<String, String>> _features = [
    {
      'title': 'Institutional Community',
      'desc':
          'Join a curated social feed where verified traders share high-signal ideas. Follow leading strategies, engage in direct messaging, and climb the leaderboard.',
      'icon': 'forum',
    },
    {
      'title': 'Quantitative Journaling',
      'desc':
          'Move beyond simple notes. Track precise execution data, visualize your equity curve, and utilize smart auto-fill that automatically pulls screenshot charts.',
      'icon': 'book',
    },
    {
      'title': 'Live Market News',
      'desc':
          'Stay ahead of the curve with real-time news alerts. Get instant notifications on macroeconomic events, earnings reports, and breaking sector updates.',
      'icon': 'donut',
    },
    {
      'title': 'AI Trading Assistant',
      'desc':
          'Leverage cutting-edge LLMs to analyze your market setups in real-time. Upload charts, instantly receive risk/reward insights, and decode complex market structure.',
      'icon': 'memory',
    },
  ];

  IconData _getIcon(String id) {
    switch (id) {
      case 'memory':
        return Icons.memory_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      case 'donut':
        return Icons.donut_small_rounded;
      case 'forum':
        return Icons.forum_outlined;
      default:
        return Icons.auto_graph_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final responsive = context.uiRes;

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
            child: _buildMobileView(context, theme, colors, responsive),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: AlphaThreadBackdrop(
        animate: true,
        phase: 29.5,
        thickness: 52,
        desktopHeight: 170,
        opacity: 0.18,
        fadeOut: true,
        child: SafeArea(
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
                    padding: EdgeInsets.only(
                      top: context.sz(
                        72,
                      ), // Clearance for sticky frosted header
                      left: 0,
                      right: 0,
                      bottom: 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                                  _buildHero(
                                    context,
                                    theme,
                                    colors,
                                    responsive,
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.xxxl) * 2,
                                  ),

                                  // Real App Components Showcase Grid
                                  KeyedSubtree(
                                    key: _showcaseKey,
                                    child: UiDeferred(
                                      estimatedHeight: 500,
                                      builder: (_) => _buildShowcaseGrid(
                                        context,
                                        theme,
                                        colors,
                                        responsive,
                                      ),
                                    ),
                                  ),

                                  SizedBox(
                                    height: context.sp(theme.spacing.xxxl) * 2,
                                  ),

                                  // 2 Types of Users / Personas Section
                                  KeyedSubtree(
                                    key: _personasKey,
                                    child: UiDeferred(
                                      estimatedHeight: 500,
                                      builder: (_) => _buildUserTypesSection(
                                        context,
                                        theme,
                                        colors,
                                        responsive,
                                      ),
                                    ),
                                  ),

                                  SizedBox(
                                    height: context.sp(theme.spacing.xxxl) * 2,
                                  ),

                                  // Feature Cards below showcase
                                  KeyedSubtree(
                                    key: _featuresKey,
                                    child: UiDeferred(
                                      estimatedHeight: 400,
                                      builder: (_) => _buildFeaturesGrid(
                                        context,
                                        theme,
                                        colors,
                                        responsive,
                                      ),
                                    ),
                                  ),

                                  SizedBox(
                                    height: context.sp(theme.spacing.xxxl) * 2,
                                  ),

                                  // Dedicated Desktop Pricing Section
                                  KeyedSubtree(
                                    key: _pricingKey,
                                    child: UiDeferred(
                                      estimatedHeight: 500,
                                      builder: (_) => _buildPricingSection(
                                        context,
                                        theme,
                                        colors,
                                        responsive,
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
                                      builder: (_) => _buildFaqSection(
                                        context,
                                        theme,
                                        colors,
                                        responsive,
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

                        // Full-width Bottom-originating AlphaThread ribbon (no left/right padding, flush against footer line)
                        LayoutBuilder(
                          builder:
                              (BuildContext ctx, BoxConstraints constraints) {
                                final bool isDesktop =
                                    constraints.maxWidth >= 900;
                                if (!isDesktop) return const SizedBox.shrink();
                                final height = context.sz(220);
                                return UiDeferred(
                                  estimatedHeight: height,
                                  preloadExtent: 0,
                                  builder: (_) => SizedBox(
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
                                );
                              },
                        ),

                        // Bottom Bar: Copyright & Legal quick actions (stuck directly to bottom of ribbon)
                        const AlphaJournalFooter(),
                      ],
                    ),
                  ),
                ),
              ),

              // Top Gradient Backdrop Blur Mask (Matching ultimate-media-downloader h-32 blur with vertical mask gradient)
              ValueListenableBuilder<bool>(
                valueListenable: _isScrolledNotifier,
                builder: (context, isScrolled, child) {
                  return Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: context.sz(128),
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        opacity: isScrolled ? 1.0 : 0.0,
                        child: child,
                      ),
                    ),
                  );
                },
                child: RepaintBoundary(
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

              // Top Sticky Navigation Bar (Matching ultimate-media-downloader layout)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: RepaintBoundary(
                  child: _buildTopNav(context, theme, colors, responsive),
                ),
              ),
            ],
          ),
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
          children: [
            // Left: Brand Logo (UMD Style bold tracking-tight)
            Flexible(
              child: MouseRegion(
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
                  child: const AppLogo(size: 26, markRounded: false),
                ),
              ),
            ),

            // Center: Navigation Links (Desktop / Tablet >= 768)
            if (responsive.width >= 768)
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeaderNavLink(
                          label: 'home',
                          onTap: () => _scrollToSection('home'),
                        ),
                        SizedBox(width: context.sp(theme.spacing.xl)),
                        _HeaderNavLink(
                          label: 'platform',
                          onTap: () => _scrollToSection('showcase'),
                        ),
                        SizedBox(width: context.sp(theme.spacing.xl)),
                        _HeaderNavLink(
                          label: 'solutions',
                          onTap: () => _scrollToSection('personas'),
                        ),
                        SizedBox(width: context.sp(theme.spacing.xl)),
                        _HeaderNavLink(
                          label: 'features',
                          onTap: () => _scrollToSection('features'),
                        ),
                        SizedBox(width: context.sp(theme.spacing.xl)),
                        _HeaderNavLink(
                          label: 'pricing',
                          onTap: () => _scrollToSection('pricing'),
                        ),
                        SizedBox(width: context.sp(theme.spacing.xl)),
                        _HeaderNavLink(
                          label: 'faq',
                          onTap: () => _scrollToSection('faq'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Right: Primary alphajournal CTA Button
            UiButton(
              label: '+ GET ALPHAJOURNAL',
              variant: UiVariant.primary,
              intent: UiIntent.primary,
              size: UiSize.sm,
              onPressed: () => widget.onGetStarted(UserRole.customer),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    return Column(
      children: [
        SizedBox(height: context.sz(responsive.isTablet ? 48.0 : 84.0)),
        Text(
          _page
                  ?.text('title')
                  .replaceFirst('Trading System', '\nTrading System') ??
              'The Foundation for your\nTrading System',
          textAlign: TextAlign.center,
          style: context.uiText.display.copyWith(
            fontSize: responsive.isMobile ? 32.0 : 48.0,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            height: 1.15,
            color: colors.foreground,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(680)),
          child: Text(
            _page?.text('description') ??
                'A complete ecosystem combining AI analysis, quantitative journaling, and community. Built for precision, clarity, and intelligent execution. Open for traders.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: responsive.isMobile ? 14.0 : 16.0,
              height: 1.55,
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),
        Wrap(
          alignment: WrapAlignment.center,
          runSpacing: context.sp(theme.spacing.sm),
          children: [
            UiButton(
              label: 'Get Started Free',
              variant: UiVariant.primary,
              intent: UiIntent.primary,
              size: UiSize.lg,
              onPressed: () => widget.onGetStarted(UserRole.customer),
            ),
            SizedBox(width: context.sp(theme.spacing.md)),
            UiButton(
              label: 'Already a Customer? Sign In',
              variant: UiVariant.outline,
              intent: UiIntent.neutral,
              size: UiSize.lg,
              leadingIcon: Icons.login_rounded,
              onPressed: widget.onSignIn,
            ),
          ],
        ),
      ],
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

  Widget _buildShowcaseGrid(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _buildSectionBadge(
          context,
          theme,
          colors,
          icon: Icons.auto_graph_rounded,
          label: 'Live Market Intelligence',
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Text(
          'Institutional Workspace at Your Fingertips',
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
            'From disciplined quantitative journaling to live NSE/BSE scanner feeds, community strategies, and AI pattern detection.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: 14.0,
              height: 1.5,
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),
        LayoutBuilder(
          builder: (context, constraints) {
            final double spacing = context.sp(theme.spacing.lg);
            final int cols = constraints.maxWidth >= 1100 ? 3 : 1;
            final double colWidth =
                (constraints.maxWidth - (spacing * (cols - 1))) / cols;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                // Column 1
                SizedBox(
                  width: colWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [AppPostCard(post: _previewPost)],
                  ),
                ),

                // Column 2
                SizedBox(
                  width: colWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiToggleGroup<String>(
                        expand: true,
                        options: const [
                          UiToggleOption<String>(label: '1D', value: '1d'),
                          UiToggleOption<String>(label: '1W', value: '1w'),
                          UiToggleOption<String>(label: '1M', value: '1m'),
                          UiToggleOption<String>(label: '1Y', value: '1y'),
                        ],
                        value: '1m',
                        variant: UiToggleGroupVariant.segmented,
                        onChanged: (v) {},
                      ),
                      SizedBox(height: spacing),
                      for (int i = 0; i < _previewStrategies.length; i++) ...[
                        if (i > 0) SizedBox(height: spacing),
                        AppStrategyPerformanceCard(
                          strategy: _previewStrategies[i],
                        ),
                      ],
                    ],
                  ),
                ),

                // Column 3
                SizedBox(
                  width: colWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppNewsCard(item: _previewNews),
                      SizedBox(height: spacing),
                      AppAiInsightCard(insight: _previewInsight),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2 Types of Users / Personas Section
  // ---------------------------------------------------------------------------
  Widget _buildUserTypesSection(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _buildSectionBadge(
          context,
          theme,
          colors,
          icon: Icons.people_outline_rounded,
          label: 'Choose Your Role',
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Text(
          'Built for Traders & Affiliates',
          textAlign: TextAlign.center,
          style: context.uiText.display.copyWith(
            fontSize: responsive.isMobile ? 24.0 : 32.0,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(640)),
          child: Text(
            'Choose the workspace that matches what you do. Trade with more discipline, or grow the AlphaJournal community as an affiliate.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: 14.0,
              height: 1.5,
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),
        LayoutBuilder(
          builder: (BuildContext ctx, BoxConstraints constraints) {
            final double spacing = context.sp(theme.spacing.xl);
            final bool isMobile = responsive.isMobile;
            final double colWidth = isMobile
                ? constraints.maxWidth
                : (constraints.maxWidth - spacing) / 2;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: <Widget>[
                // Role 1: Independent Quantitative Trader (Customer)
                _buildPersonaCard(
                  context,
                  theme,
                  colors,
                  width: colWidth,
                  icon: Icons.candlestick_chart_rounded,
                  iconColor: const Color(0xFF84CC16),
                  badgeText: 'TRADER',
                  badgeIntent: UiIntent.primary,
                  title: 'Trader',
                  subtitle:
                      'For active market participants who want structured risk, sharper execution, and one reliable place for every trade decision.',
                  features: const <String>[
                    '1-Click Auto-Sync with Zerodha, Upstox, Angel One & Dhan',
                    'AI Setup Detection (Double Tops, FVG Gaps, Order Blocks)',
                    'Automated Equity Curve, Drawdown & Sharpe Ratio Analytics',
                    'Audit-Ready ITR-2 / ITR-3 Capital Gains Tax Book Export',
                    'Discipline Rules, Slippage Tracking & Risk Heatmaps',
                  ],
                  ctaLabel: 'Get Started as Trader',
                  ctaPrimary: true,
                  onPressed: () => widget.onGetStarted(UserRole.customer),
                ),

                // Role 2: Affiliate
                _buildPersonaCard(
                  context,
                  theme,
                  colors,
                  width: colWidth,
                  icon: Icons.groups_rounded,
                  iconColor: colors.primary,
                  badgeText: 'AFFILIATE',
                  badgeIntent: UiIntent.success,
                  title: 'Affiliate',
                  subtitle:
                      'For partners who introduce serious traders to AlphaJournal and want transparent referrals, commissions, and campaign reporting.',
                  features: const <String>[
                    'Share Trackable Links Across Your Audience and Community',
                    'Earn Up to 30% Recurring Commission on Referred Traders',
                    'Real-Time Conversion Dashboard & Custom Link Generator',
                    'Campaign-Level Performance and Payout Visibility',
                    'Partner Resources, Creative Assets & Priority Support',
                  ],
                  ctaLabel: 'Apply as Affiliate Partner',
                  ctaPrimary: false,
                  onPressed: () => widget.onGetStarted(UserRole.affiliate),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPersonaCard(
    BuildContext context,
    UiTheme theme,
    UiColors colors, {
    required double width,
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required UiIntent badgeIntent,
    required String title,
    required String subtitle,
    required List<String> features,
    required String ctaLabel,
    required bool ctaPrimary,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: width,
      child: UiCard(
        variant: UiCardVariant.outlined,
        selected: ctaPrimary,
        intent: badgeIntent,
        accentColor: iconColor,
        hoverLift: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Top Row: Icon + Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: context.sz(22), color: iconColor),
                ),
                UiBadge(
                  label: badgeText,
                  intent: badgeIntent,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),

            // Title & Subtitle
            Text(
              title,
              style: context.uiText.display.copyWith(
                fontSize: 22.0,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            Text(
              subtitle,
              style: context.uiText.body.copyWith(
                color: colors.foregroundMuted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),
            const UiDivider(),
            SizedBox(height: context.sp(theme.spacing.md)),

            // Feature Points Checklist
            Text(
              'Key Capabilities:',
              style: context.uiText.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.foreground,
                fontSize: 12.5,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            for (final String f in features)
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: context.sp(theme.spacing.xxs),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_rounded,
                      size: context.sz(16),
                      color: iconColor,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Expanded(
                      child: Text(
                        f,
                        style: context.uiText.body.copyWith(
                          color: colors.foregroundMuted,
                          fontSize: 13.0,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: context.sp(theme.spacing.xl)),

            // Action CTA Button
            SizedBox(
              width: double.infinity,
              child: UiButton(
                label: ctaLabel,
                variant: ctaPrimary ? UiVariant.primary : UiVariant.outline,
                intent: ctaPrimary ? UiIntent.primary : UiIntent.neutral,
                size: UiSize.lg,
                onPressed: onPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSectionBadge(
          context,
          theme,
          colors,
          icon: Icons.widgets_outlined,
          label: 'Engineered for Discipline',
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Text(
          'Core Features Built for Indian Markets',
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
            'Designed to eliminate emotional trading mistakes, enforce strict risk parameters, and automate multi-asset trade analytics.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: 14.0,
              height: 1.5,
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),
        LayoutBuilder(
          builder: (context, constraints) {
            return UiCardGrid(
              intrinsicHeight: true,
              equalHeight: true,
              desktopColumns: 4,
              largeColumns: 4,
              children: List.generate(_features.length, (idx) {
                final item = _features[idx];

                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 320),
                  child: Container(
                    padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: context.radius(theme.radii.lg),
                      border: Border.all(
                        color: colors.border,
                        width: theme.borders.hairline,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                          decoration: BoxDecoration(
                            color: colors.surfaceMuted,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIcon(item['icon']!),
                            color: colors.foreground,
                            size: context.sz(20),
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.lg)),
                        Text(
                          item['title']!,
                          style: context.uiText.bodyStrong.copyWith(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        Text(
                          item['desc']!,
                          style: context.uiText.body.copyWith(
                            color: colors.foregroundMuted,
                            fontSize: 14.0,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Landing Page FAQ Section
  // ---------------------------------------------------------------------------
  Widget _buildFaqSection(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
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
            'Everything you need to know about AlphaJournal, quantitative journaling, Indian broker connections, security, and AI capabilities.',
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
            _buildLandingFaqFilter(context, 'all', 'All Questions'),
            _buildLandingFaqFilter(context, 'trading', 'Trading & Brokers'),
            _buildLandingFaqFilter(context, 'billing', 'Pricing & Plans'),
            _buildLandingFaqFilter(context, 'features', 'AI & Quant Tools'),
            _buildLandingFaqFilter(context, 'security', 'Security & Tax'),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),

        // Accordion from dynamic future
        FutureBuilder<PricingCatalogueResponse>(
          future: _pricingFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<PricingCatalogueResponse> snapshot,
              ) {
                final List<PricingFaqItem> allFaqs = snapshot.hasData
                    ? snapshot.data!.faqs
                    : const <PricingFaqItem>[];

                // Rich categorized FAQs for the landing page
                final List<PricingFaqItem> landingFaqs = [
                  ...allFaqs,
                  ...?_page?.faqs,
                ];

                final List<PricingFaqItem> filtered =
                    _selectedLandingFaqCategory == 'all'
                    ? landingFaqs
                    : landingFaqs
                          .where(
                            (PricingFaqItem f) =>
                                f.category == _selectedLandingFaqCategory,
                          )
                          .toList();

                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: context.sz(860)),
                  child: UiAccordion(
                    items: <UiAccordionItem>[
                      for (final PricingFaqItem item in filtered)
                        UiAccordionItem(
                          title: item.question,
                          content: Text(
                            item.answer,
                            style: context.uiText.body.copyWith(
                              color: colors.foregroundMuted,
                              height: 1.6,
                              fontSize: 14.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
        ),
      ],
    );
  }

  Widget _buildLandingFaqFilter(
    BuildContext context,
    String categoryKey,
    String label,
  ) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isSelected = _selectedLandingFaqCategory == categoryKey;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedLandingFaqCategory = categoryKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.md),
          vertical: context.sp(theme.spacing.xs),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.surface
              : colors.surfaceMuted.withValues(alpha: 0.4),
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

  Widget _buildPricingSection(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Header
        _buildSectionBadge(
          context,
          theme,
          colors,
          icon: Icons.payments_outlined,
          label: 'Simple & Transparent Pricing (INR ₹)',
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Text(
          _page?.text('pricing_title') ?? 'Scale Your Trading Edge',
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
            'Compare the limits available today. Paid tiers are previews while verified checkout is being connected.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: 14.0,
              height: 1.5,
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),

        // Cycle Selector
        Container(
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
              GestureDetector(
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
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.md),
                    vertical: context.sp(theme.spacing.xs),
                  ),
                  decoration: BoxDecoration(
                    color: !_isAnnualPricing
                        ? colors.surface
                        : Colors.transparent,
                    borderRadius: context.radius(theme.radii.pill),
                  ),
                  child: Text(
                    'Monthly',
                    style: context.uiText.bodyStrong.copyWith(
                      fontSize: 13,
                      color: !_isAnnualPricing
                          ? colors.foreground
                          : colors.foregroundMuted,
                    ),
                  ),
                ),
              ),
              GestureDetector(
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
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.md),
                    vertical: context.sp(theme.spacing.xs),
                  ),
                  decoration: BoxDecoration(
                    color: _isAnnualPricing
                        ? colors.surface
                        : Colors.transparent,
                    borderRadius: context.radius(theme.radii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Billed annually',
                        style: context.uiText.bodyStrong.copyWith(
                          fontSize: 13,
                          color: _isAnnualPricing
                              ? colors.foreground
                              : colors.foregroundMuted,
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      const UiBadge(
                        label: 'Save 20%',
                        intent: UiIntent.success,
                        variant: UiBadgeVariant.soft,
                        size: UiSize.xs,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xxl)),

        // 3 Cards FutureBuilder
        FutureBuilder<PricingCatalogueResponse>(
          future: _pricingFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<PricingCatalogueResponse> snapshot,
              ) {
                if (!snapshot.hasData) {
                  if (snapshot.hasError) {
                    return UiEmptyState(
                      title: 'Pricing unavailable',
                      actionLabel: 'Try again',
                      onActionPressed: () => setState(
                        () => _pricingFuture = _pricingRepo.getPricingCatalogue(
                          annual: _isAnnualPricing,
                        ),
                      ),
                    );
                  }
                  return const Center(
                    child: UiSkeleton(width: 240, height: 180),
                  );
                }

                final List<PricingPlanModel> plans = snapshot.data!.plans;

                return UiCardGrid(
                  equalHeight: true,
                  intrinsicHeight: true,
                  tabletColumns: 1,
                  desktopColumns: 3,
                  largeColumns: 3,
                  children: [
                    for (final plan in plans)
                      _buildLandingPricingCard(context, theme, colors, plan),
                  ],
                );
              },
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),
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
    );
  }

  Widget _buildLandingPricingCard(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    PricingPlanModel plan,
  ) {
    final bool isFeatured = plan.highlighted;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(
          color: isFeatured ? colors.primary : colors.border,
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
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              Text(
                plan.name,
                style: context.uiText.display.copyWith(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w600,
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
          SizedBox(height: context.sp(theme.spacing.xs)),
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
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                plan.priceLabel(isAnnual: _isAnnualPricing),
                style: context.uiText.display.copyWith(
                  fontSize: 32.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Text(
                plan.monthlyAmount == 0 ? '' : '/ mo',
                style: context.uiText.caption.copyWith(
                  color: colors.foregroundMuted,
                  fontSize: 13.0,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            plan.periodLabel(isAnnual: _isAnnualPricing),
            style: context.uiText.caption.copyWith(
              color: colors.foregroundSubtle,
              fontSize: 12.0,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiButton(
            label: plan.ctaLabel,
            variant: isFeatured ? UiVariant.primary : UiVariant.outline,
            intent: isFeatured ? UiIntent.primary : UiIntent.neutral,
            size: UiSize.md,
            onPressed: plan.isPurchasable
                ? () => widget.onGetStarted(UserRole.customer)
                : null,
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          const UiDivider(),
          SizedBox(height: context.sp(theme.spacing.sm)),
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
                            fontSize: 13.0,
                            height: 1.4,
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
}

class _HeaderNavLink extends StatefulWidget {
  const _HeaderNavLink({required this.label, required this.onTap});

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
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.xxs),
              vertical: context.sp(theme.spacing.xxs),
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _isHovered
                      ? colors.foreground
                      : colors.foreground.withValues(alpha: 0.0),
                  width: 2,
                ),
              ),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              style: context.uiText.body.copyWith(
                color: _isHovered
                    ? colors.foreground
                    : colors.foregroundMuted.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
                fontSize: 15.0,
                letterSpacing: -0.2,
              ),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}
