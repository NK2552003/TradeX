import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

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

class AuthCarouselPanel extends StatefulWidget {
  const AuthCarouselPanel({super.key});

  @override
  State<AuthCarouselPanel> createState() => _AuthCarouselPanelState();
}

class _AuthCarouselPanelState extends State<AuthCarouselPanel> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentFeatureIndex = 0;
  bool _carouselForward = true;
  Timer? _carouselTimer;

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

  @override
  void initState() {
    super.initState();
    _startCarouselTimer();
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      if (_pageController.hasClients && _pageController.position.hasContentDimensions) {
        if (_carouselForward) {
          if (_currentFeatureIndex < _features.length - 1) {
            _pageController.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
          } else {
            _carouselForward = false;
            _pageController.previousPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
          }
        } else {
          if (_currentFeatureIndex > 0) {
            _pageController.previousPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
          } else {
            _carouselForward = true;
            _pageController.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final List<Widget> carouselCards = [
      AppPostCard(post: _mockPost),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppStrategyPerformanceCard(strategy: _mockStrategy),
          SizedBox(height: context.sp(theme.spacing.lg)),
          AppStrategyPerformanceCard(strategy: _mockStrategy2),
        ],
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNewsCard(item: _mockNews),
          SizedBox(height: context.sp(theme.spacing.lg)),
          AppNewsCard(item: AppNewsItem(
            id: 'n2',
            headline: 'Tech sector sees massive inflows as AI rally continues.',
            source: 'Reuters',
            publishedAt: DateTime.now().subtract(const Duration(minutes: 90)),
            sentimentScore: 0.85,
            tickers: const ['NVDA', 'MSFT'],
            summary: 'Institutional investors are piling into semiconductors and cloud infrastructure...',
          )),
        ],
      ),
      AppAiInsightCard(insight: _mockInsight),
    ];

    return Column(
      children: [
        // Carousel
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) {
              setState(() {
                _currentFeatureIndex = idx;
              });
            },
            itemCount: _features.length,
            itemBuilder: (context, idx) {
              final card = carouselCards[idx % carouselCards.length];
              
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.sm)),
                child: Center(
                  child: SizedBox(
                    height: 360,
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 360,
                        child: card,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Text & Dots Area
        Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Feature Title & Description
              Text(
                _features[_currentFeatureIndex]['title']!,
                style: context.uiText.heading,
                textAlign: TextAlign.left,
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),
              Text(
                _features[_currentFeatureIndex]['desc']!,
                style: context.uiText.body.copyWith(color: colors.foregroundMuted, height: 1.5),
                textAlign: TextAlign.left,
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),
              
              // Carousel Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_features.length, (index) {
                  final isActive = index == _currentFeatureIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.only(right: context.sp(theme.spacing.sm)),
                    height: 8,
                    width: isActive ? 24 : 8,
                    decoration: BoxDecoration(
                      color: isActive ? colors.primary : colors.borderStrong,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
