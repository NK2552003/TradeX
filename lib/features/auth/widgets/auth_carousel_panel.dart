import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/data/demo_data_source.dart';

class AuthCarouselPanel extends StatefulWidget {
  const AuthCarouselPanel({super.key, this.bottomAction});

  final Widget? bottomAction;

  @override
  State<AuthCarouselPanel> createState() => _AuthCarouselPanelState();
}

class _AuthCarouselPanelState extends State<AuthCarouselPanel> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentFeatureIndex = 0;
  bool _carouselForward = true;
  Timer? _carouselTimer;

  /// The sign-in preview renders the same records the signed-in app renders, so
  /// the shop window cannot advertise a post, strategy or headline that does not
  /// exist once the reader is inside.
  final DemoDataSource _demo = DemoDataSource.instance;
  late final AppPost _post = _demo.posts(limit: 1).first;
  late final List<AppStrategy> _strategies = _demo
      .strategies()
      .take(2)
      .toList();
  late final List<AppNewsItem> _news = _demo.news(limit: 2);
  late final AppAiInsight _insight = _demo.insights(limit: 1).first;

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

  @override
  void initState() {
    super.initState();
    _startCarouselTimer();
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      if (_pageController.hasClients &&
          _pageController.position.hasContentDimensions) {
        if (_carouselForward) {
          if (_currentFeatureIndex < _features.length - 1) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            );
          } else {
            _carouselForward = false;
            _pageController.previousPage(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            );
          }
        } else {
          if (_currentFeatureIndex > 0) {
            _pageController.previousPage(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            );
          } else {
            _carouselForward = true;
            _pageController.nextPage(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            );
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
      AppPostCard(post: _post),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _strategies.length; i++) ...[
            if (i > 0) SizedBox(height: context.sp(theme.spacing.lg)),
            AppStrategyPerformanceCard(strategy: _strategies[i]),
          ],
        ],
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _news.length; i++) ...[
            if (i > 0) SizedBox(height: context.sp(theme.spacing.lg)),
            AppNewsCard(item: _news[i]),
          ],
        ],
      ),
      AppAiInsightCard(insight: _insight),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool hasBoundedHeight = constraints.maxHeight.isFinite;

        final Widget carousel = PageView.builder(
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
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.sm),
              ),
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: SizedBox(width: 440, child: card),
                  ),
                ),
              ),
            );
          },
        );

        final Widget textAndDots = Padding(
          padding: EdgeInsets.fromLTRB(
            context.sp(theme.spacing.xl),
            context.sp(theme.spacing.sm),
            context.sp(theme.spacing.xl),
            context.sp(theme.spacing.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                style: context.uiText.body.copyWith(
                  color: colors.foregroundMuted,
                  height: 1.5,
                ),
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
                    margin: EdgeInsets.only(
                      right: context.sp(theme.spacing.sm),
                    ),
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
        );

        if (widget.bottomAction != null) {
          final double screenHeight = MediaQuery.sizeOf(context).height;
          final double carouselHeight = (screenHeight * 0.36).clamp(
            180.0,
            340.0,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: carouselHeight, child: carousel),
              SizedBox(height: context.sp(theme.spacing.xl)),
              textAndDots,
              widget.bottomAction!,
            ],
          );
        }

        final bool shouldExpand =
            hasBoundedHeight && constraints.maxHeight >= 450;

        if (shouldExpand) {
          return Column(
            children: [
              Expanded(child: carousel),
              textAndDots,
            ],
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: (constraints.maxHeight * 0.55).clamp(140.0, 480.0),
                child: carousel,
              ),
              textAndDots,
            ],
          ),
        );
      },
    );
  }
}
