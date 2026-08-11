import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import 'package:tradex/core/config/mock_data.dart';

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
      AppPostCard(post: mockPost),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppStrategyPerformanceCard(strategy: mockStrategy),
          SizedBox(height: context.sp(theme.spacing.lg)),
          AppStrategyPerformanceCard(strategy: mockStrategy2),
        ],
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNewsCard(item: mockNews),
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
      AppAiInsightCard(insight: mockInsight),
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
                    height: 480,
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 440,
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
