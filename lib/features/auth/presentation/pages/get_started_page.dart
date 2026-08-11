import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/widgets/auth_background.dart';
import 'package:tradex/core/showcase/numbered_component_showcase_page.dart';
import 'package:tradex/features/auth/widgets/auth_carousel_panel.dart';

final AppTrader _mockTrader = AppTrader(
  id: 'u1',
  handle: 'quantqueen',
  displayName: 'Ava Chen',
  avatarUrl: 'https://i.pravatar.cc/150?img=32',
  tier: AppTier.premium,
  verified: true,
  bio: 'Swing trading tech and semis.',
);

final List<UiCandle> _mockCandles = List.generate(24, (i) {
  final double open = 220.0 + (i % 5) * 2 - (i % 3) * 1.5;
  final double close = open + (i % 2 == 0 ? 3.5 : -2.5);
  final double high = (open > close ? open : close) + 2.0;
  final double low = (open < close ? open : close) - 1.5;
  return UiCandle(
    time: DateTime.now().subtract(Duration(days: 24 - i)),
    open: open,
    high: high,
    low: low,
    close: close,
    volume: 1000.0 + (i * 200),
  );
});

final AppPost _mockPost = AppPost(
  id: 'p1',
  author: _mockTrader,
  body: 'Rotated out of TSLA into AAPL today. Structure is incredibly clean on the 4H.',
  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  tickers: const <String>['AAPL', 'TSLA'],
  attachments: [
    AppPostChartAttachment(_mockCandles),
    const AppPostStrategyAttachment('ORB Breakout Masterclass', locked: true),
  ],
  likes: 214,
  comments: 18,
  liked: true,
);

final AppTrade _aaplTrade = AppTrade(
  id: 't_aapl',
  ticker: 'AAPL',
  side: AppSide.long,
  entry: 220.10,
  exit: 227.40,
  size: 100.00,
  pnl: 730.00,
  pnlPercent: 3.30,
  rMultiple: 2.10,
  openedAt: DateTime.now().subtract(const Duration(days: 1)),
  tags: const ['Opening range breakout', 'breakout', 'tech'],
);

final AppTrade _tslaTrade = AppTrade(
  id: 't_tsla',
  ticker: 'TSLA',
  side: AppSide.short,
  entry: 182.50,
  exit: 189.20,
  size: 40.00,
  pnl: -268.00,
  pnlPercent: -3.60,
  rMultiple: -0.90,
  openedAt: DateTime.now().subtract(const Duration(days: 1)),
  tags: const ['Fade the gap', 'gap', 'ev'],
);

final AppTrade _msftTrade = AppTrade(
  id: 't_msft',
  ticker: 'MSFT',
  side: AppSide.long,
  entry: 411.20,
  exit: 413.20,
  size: 60.00,
  pnl: 96.00,
  pnlPercent: 0.40,
  openedAt: DateTime.now().subtract(const Duration(days: 1)),
  tags: const ['Trend continuation', 'trend'],
);

final AppStrategy _mockStrategy = AppStrategy(
  id: 's1',
  name: 'ORB Breakout',
  category: 'bullish',
  summary: '',
  isPublic: true,
  trades: 128,
  winRate: 61,
  avgR: 2.1,
  netPnl: 8420,
  updatedAt: DateTime.now(),
  equityCurve: const [2, 3, 4, 3, 5, 6, 8, 7, 9, 12, 11, 15],
);

final AppStrategy _mockStrategy2 = AppStrategy(
  id: 's2',
  name: 'Gap Fade',
  category: 'bearish',
  summary: '',
  isPublic: true,
  trades: 40,
  winRate: 35,
  avgR: -0.4,
  netPnl: -1120,
  updatedAt: DateTime.now(),
  equityCurve: const [15, 14, 14.5, 13, 11, 10, 11, 9, 8, 7, 6, 4],
);

final AppNewsItem _mockNews = AppNewsItem(
  id: 'n1',
  headline: 'Federal Reserve holds interest rates steady, signals potential cuts later this year.',
  source: 'Bloomberg',
  publishedAt: DateTime.now().subtract(const Duration(minutes: 45)),
  sentimentScore: 0.65,
  tickers: const ['SPY', 'QQQ'],
  summary: 'In a widely expected move, the central bank maintained its benchmark rate at 5.25%-5.50%.',
);

final AppAiInsight _mockInsight = AppAiInsight(
  id: 'ai1',
  title: 'Pattern Detected: Bull Flag',
  body: 'NVDA is forming a tight bull flag on the 1H chart with decreasing volume. Watch for a breakout above \$120 with high volume confirmation.',
  confidence: 0.88,
  sentimentScore: 0.8,
  tickers: const ['NVDA'],
  createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
);

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
      'desc': 'Join a curated social feed where verified traders share high-signal ideas. Follow leading strategies, engage in direct messaging, and climb the leaderboard.',
      'icon': 'forum',
    },
    {
      'title': 'Quantitative Journaling',
      'desc': 'Move beyond simple notes. Track precise execution data, visualize your equity curve, and utilize smart auto-fill that automatically pulls screenshot charts.',
      'icon': 'book',
    },
    {
      'title': 'Live Market News',
      'desc': 'Stay ahead of the curve with real-time news alerts. Get instant notifications on macroeconomic events, earnings reports, and breaking sector updates.',
      'icon': 'donut',
    },
    {
      'title': 'AI Trading Assistant',
      'desc': 'Leverage cutting-edge LLMs to analyze your market setups in real-time. Upload charts, instantly receive risk/reward insights, and decode complex market structure.',
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
                          constraints: BoxConstraints(maxWidth: context.sz(1400)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildHero(context, theme, colors, responsive),
                              SizedBox(height: context.sp(theme.spacing.xxxl) * 2),
                              
                              // Real App Components Showcase Grid
                              _buildShowcaseGrid(context, theme, colors, responsive),
                              
                              SizedBox(height: context.sp(theme.spacing.xxxl) * 2),
                              
                              // Feature Cards below showcase
                              _buildFeaturesGrid(context, theme, colors, responsive),
                              
                              SizedBox(height: context.sp(theme.spacing.xxxl) * 2),
                              // Footer
                              _buildFooter(context, theme, colors),
                              
                              SizedBox(height: context.sp(theme.spacing.xxxl) * 2), // extra bottom padding for the fade
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

  Widget _buildMobileView(BuildContext context, UiTheme theme, UiColors colors, UiResponsive responsive) {
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
        const Expanded(
          child: AuthCarouselPanel(),
        ),
        
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

  Widget _buildTopNav(BuildContext context, UiTheme theme, UiColors colors, UiResponsive responsive) {
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
              if (responsive.isMobile)
                UiIconButton(
                  icon: Icons.style_outlined,
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const NumberedComponentShowcasePage(),
                    ));
                  },
                )
              else ...[
                UiButton(
                  label: 'Components Showcase',
                  variant: UiVariant.ghost,
                  intent: UiIntent.primary,
                  size: UiSize.sm,
                  leadingIcon: Icons.style_outlined,
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const NumberedComponentShowcasePage(),
                    ));
                  },
                ),
                SizedBox(width: context.sp(theme.spacing.md)),
                Text(
                  'Already have an account?',
                  style: context.uiText.body.copyWith(
                    color: colors.foregroundMuted,
                  ),
                ),
              ],
              SizedBox(width: context.sp(theme.spacing.md)),
              UiButton(
                label: 'Sign In',
                variant: UiVariant.outline,
                intent: UiIntent.neutral,
                size: UiSize.sm,
                onPressed: widget.onSignIn,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, UiTheme theme, UiColors colors, UiResponsive responsive) {
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
                style: context.uiText.caption.copyWith(fontWeight: FontWeight.w500),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Icon(Icons.arrow_forward_rounded, size: 12, color: colors.foreground),
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
        )
      ],
    );
  }

  Widget _buildShowcaseGrid(BuildContext context, UiTheme theme, UiColors colors, UiResponsive responsive) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = context.sp(theme.spacing.lg);
        final int cols = responsive.isMobile ? 1 : 3;
        final double colWidth = (constraints.maxWidth - (spacing * (cols - 1))) / cols;
        
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
                children: [
                  AppPostCard(post: _mockPost),
                ],
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
                      UiToggleOption<String>(label: '1D', value: '1d', icon: Icons.today),
                      UiToggleOption<String>(label: '1W', value: '1w'),
                      UiToggleOption<String>(label: '1M', value: '1m'),
                      UiToggleOption<String>(label: '1Y', value: '1y', badge: 'new'),
                    ],
                    value: '1m',
                    variant: UiToggleGroupVariant.segmented,
                    onChanged: (v) {},
                  ),
                  SizedBox(height: spacing),
                  AppStrategyPerformanceCard(strategy: _mockStrategy),
                  SizedBox(height: spacing),
                  AppStrategyPerformanceCard(strategy: _mockStrategy2),
                ],
              ),
            ),
            
            // Column 3
            SizedBox(
              width: colWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppNewsCard(item: _mockNews),
                  SizedBox(height: spacing),
                  AppAiInsightCard(insight: _mockInsight),
                ],
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildFeaturesGrid(BuildContext context, UiTheme theme, UiColors colors, UiResponsive responsive) {
    return Column(
      children: [
        Center(
          child: Text(
            'Core Features',
            style: context.uiText.display.copyWith(fontSize: 32, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),
        LayoutBuilder(
          builder: (context, constraints) {
            final double spacing = context.sp(theme.spacing.lg);
            final int cols = responsive.isMobile ? 1 : (responsive.isDesktop ? 4 : 2);
            final double colWidth = (constraints.maxWidth - (spacing * (cols - 1))) / cols;
            
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
                  style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {},
                  child: Text('Privacy Policy', style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                ),
                SizedBox(width: context.sp(theme.spacing.md)),
                TextButton(
                  onPressed: () {},
                  child: Text('Terms of Service', style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                ),
                SizedBox(width: context.sp(theme.spacing.md)),
                TextButton(
                  onPressed: () {},
                  child: Text('System Status', style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                ),
              ],
            )
          ],
        ),
      ],
    );
  }
}

