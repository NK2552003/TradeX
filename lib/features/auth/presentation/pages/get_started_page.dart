import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/widgets/auth_carousel_panel.dart';

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
  });

  final void Function(UserRole role) onGetStarted;
  final VoidCallback onSignIn;

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  final ScrollController _scrollController = ScrollController();

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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final responsive = context.uiRes;

    if (responsive.isMobile) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: _buildMobileView(context, theme, colors, responsive),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNav(context, theme, colors, responsive),
            Expanded(
              child: Stack(
                children: [
                  RawScrollbar(
                    controller: _scrollController,
                    thumbVisibility: false,
                    thickness: 6,
                    radius: Radius.circular(context.sp(theme.radii.pill)),
                    thumbColor: colors.borderStrong,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.xl),
                        vertical: context.sp(theme.spacing.xxxl),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: context.sz(1400),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildHero(context, theme, colors, responsive),
                              SizedBox(
                                height: context.sp(theme.spacing.xxxl) * 2,
                              ),

                              // Real App Components Showcase Grid
                              _buildShowcaseGrid(
                                context,
                                theme,
                                colors,
                                responsive,
                              ),

                              SizedBox(
                                height: context.sp(theme.spacing.xxxl) * 2,
                              ),

                              // Feature Cards below showcase
                              _buildFeaturesGrid(
                                context,
                                theme,
                                colors,
                                responsive,
                              ),

                              SizedBox(
                                height: context.sp(theme.spacing.xxxl) * 2,
                              ),
                              // Footer
                              _buildFooter(context, theme, colors),

                              SizedBox(
                                height: context.sp(theme.spacing.xxxl) * 2,
                              ), // extra bottom padding for the fade
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Faded Dark Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colors.background.withValues(alpha: 0.0),
                              colors.background,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
    return Column(
      children: [
        // Top section
        Padding(
          padding: EdgeInsets.only(
            top: context.sp(theme.spacing.xxl),
            left: context.sp(theme.spacing.xl),
            right: context.sp(theme.spacing.xl),
            bottom: context.sp(theme.spacing.lg),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogoMark(size: 24),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Text(
                'TradeX',
                style: context.uiText.bodyStrong.copyWith(fontSize: 18),
              ),
            ],
          ),
        ),

        // Carousel
        const Expanded(child: AuthCarouselPanel()),

        // Bottom Action buttons
        Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: UiButton(
                  label: 'Get Started',
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
                  label: 'Sign In / Sign Up',
                  variant: UiVariant.outline,
                  intent: UiIntent.neutral,
                  size: UiSize.lg,
                  onPressed: () => widget.onGetStarted(UserRole.customer),
                ),
              ),
            ],
          ),
        ),
      ],
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
        horizontal: context.sp(theme.spacing.xl),
        vertical: context.sp(theme.spacing.md),
      ),
      // Removed the bottom border to keep it clean
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const AppLogoMark(size: 24), // Same as splash screen
              SizedBox(width: context.sp(theme.spacing.sm)),
              Text(
                'TradeX',
                style: context.uiText.bodyStrong.copyWith(fontSize: 18),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(width: context.sp(theme.spacing.md)),
              Text(
                'Already have an account?',
                style: context.uiText.body.copyWith(
                  color: colors.foregroundMuted,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              UiButton(
                label: 'Sign In',
                variant: UiVariant.outline,
                intent: UiIntent.neutral,
                size: UiSize.sm,
                onPressed: widget.onSignIn,
              ),
            ],
          ),
        ],
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
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.xs),
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: context.radius(theme.radii.pill),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TradeX Intelligence v1.0',
                style: context.uiText.caption.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Icon(
                Icons.arrow_forward_rounded,
                size: 12,
                color: colors.foreground,
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),
        Text(
          'The Foundation for your\nTrading System',
          textAlign: TextAlign.center,
          style: context.uiText.display.copyWith(
            fontSize: responsive.isMobile ? 40 : 72,
            fontWeight: FontWeight.w700,
            letterSpacing: -2.0,
            height: 1.1,
            color: colors.foreground,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.lg)),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(700)),
          child: Text(
            'A complete ecosystem combining AI analysis, quantitative journaling, and community. Built for precision, clarity, and intelligent execution. Open for traders.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: responsive.isMobile ? 16 : 20,
              height: 1.6,
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            UiButton(
              label: 'Get Started',
              variant: UiVariant.primary,
              intent: UiIntent.primary,
              size: UiSize.lg,
              onPressed: () => widget.onGetStarted(UserRole.customer),
            ),
            SizedBox(width: context.sp(theme.spacing.md)),
            UiButton(
              label: 'Explore Features',
              variant: UiVariant.outline,
              intent: UiIntent.neutral,
              size: UiSize.lg,
              leadingIcon: Icons.explore_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShowcaseGrid(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = context.sp(theme.spacing.lg);
        final int cols = responsive.isMobile ? 1 : 3;
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
                      UiToggleOption<String>(
                        label: '1D',
                        value: '1d',
                        icon: Icons.today,
                      ),
                      UiToggleOption<String>(label: '1W', value: '1w'),
                      UiToggleOption<String>(label: '1M', value: '1m'),
                      UiToggleOption<String>(
                        label: '1Y',
                        value: '1y',
                        badge: 'new',
                      ),
                    ],
                    value: '1m',
                    variant: UiToggleGroupVariant.segmented,
                    onChanged: (v) {},
                  ),
                  SizedBox(height: spacing),
                  for (int i = 0; i < _previewStrategies.length; i++) ...[
                    if (i > 0) SizedBox(height: spacing),
                    AppStrategyPerformanceCard(strategy: _previewStrategies[i]),
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
    );
  }

  Widget _buildFeaturesGrid(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
  ) {
    return Column(
      children: [
        Center(
          child: Text(
            'Core Features',
            style: context.uiText.display.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),
        LayoutBuilder(
          builder: (context, constraints) {
            final double spacing = context.sp(theme.spacing.lg);
            final int cols = responsive.isMobile
                ? 1
                : (responsive.isDesktop ? 4 : 2);
            final double colWidth =
                (constraints.maxWidth - (spacing * (cols - 1))) / cols;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List.generate(_features.length, (idx) {
                final item = _features[idx];

                return SizedBox(
                  width: colWidth,
                  height: 320,
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
                            size: context.sz(22),
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.xl)),
                        Text(
                          item['title']!,
                          style: context.uiText.bodyStrong.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        Text(
                          item['desc']!,
                          style: context.uiText.body.copyWith(
                            color: colors.foregroundMuted,
                            height: 1.5,
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

  Widget _buildFooter(BuildContext context, UiTheme theme, UiColors colors) {
    return Column(
      children: [
        const UiDivider(),
        SizedBox(height: context.sp(theme.spacing.xl)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const AppLogoMark(size: 20),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Text(
                  'TradeX © ${DateTime.now().year}',
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundMuted,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Privacy Policy',
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundMuted,
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.md)),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Terms of Service',
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundMuted,
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.md)),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'System Status',
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
