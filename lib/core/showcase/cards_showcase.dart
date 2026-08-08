import 'package:flutter/material.dart';

import '../app-ui/app_ui.dart';
import 'state_gallery.dart';

/// Total number of [UiStateGallery] instances rendered by this section.
const int kCardsGalleryCount = 42;

/// Batch — brand, motion and every domain card from `app-ui/cards`, each
/// across its realistic state matrix (populated, selected, dense, loading,
/// empty, error where supported).
class CardsShowcaseSection extends StatefulWidget {
  const CardsShowcaseSection({super.key, required this.startIndex});

  final int startIndex;

  @override
  State<CardsShowcaseSection> createState() => _CardsShowcaseSectionState();
}

class _CardsShowcaseSectionState extends State<CardsShowcaseSection> {
  @override
  Widget build(BuildContext context) {
    final double gap = context.sp(context.ui.spacing.lg);
    int i = widget.startIndex;
    int next() => i++;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiShowcaseSection(
          title: 'Brand',
          subtitle: 'The TraderHub mark, wordmark, lockup and splash intro.',
        ),
        SizedBox(height: gap),
        _BrandGallery(index: next()),
        SizedBox(height: gap),
        const UiShowcaseSection(
          title: 'Motion',
          subtitle:
              'Shared entrance, hover, reveal and counting primitives used by '
              'every card in the kit.',
        ),
        SizedBox(height: gap),
        _MotionGallery(index: next()),
        SizedBox(height: gap),
        const UiShowcaseSection(
          title: 'Journal cards',
          subtitle: 'Trade logging, P/L summaries, lessons and checklists.',
        ),
        SizedBox(height: gap),
        _TradeCardGallery(index: next()),
        SizedBox(height: gap),
        _PnlSummaryCardGallery(index: next()),
        SizedBox(height: gap),
        _LessonCardGallery(index: next()),
        SizedBox(height: gap),
        _ScreenshotImportCardGallery(index: next()),
        SizedBox(height: gap),
        _ChecklistCardGallery(index: next()),
        SizedBox(height: gap),
        _PsychologyCardGallery(index: next()),
        SizedBox(height: gap),
        const UiShowcaseSection(
          title: 'Strategy cards',
          subtitle: 'Playbooks, performance, version history and comparisons.',
        ),
        SizedBox(height: gap),
        _StrategyCardGallery(index: next()),
        SizedBox(height: gap),
        _StrategyPerformanceCardGallery(index: next()),
        SizedBox(height: gap),
        _VersionCardGallery(index: next()),
        SizedBox(height: gap),
        _StrategyComparisonCardGallery(index: next()),
        SizedBox(height: gap),
        _StrategySummaryCardGallery(index: next()),
        SizedBox(height: gap),
        const UiShowcaseSection(
          title: 'Watchlist cards',
          subtitle: 'Tickers, price alerts, movers and sector heat tiles.',
        ),
        SizedBox(height: gap),
        _TickerCardGallery(index: next()),
        SizedBox(height: gap),
        _PriceAlertCardGallery(index: next()),
        SizedBox(height: gap),
        _MoverCardGallery(index: next()),
        SizedBox(height: gap),
        _HeatTileGallery(index: next()),
        SizedBox(height: gap),
        const UiShowcaseSection(
          title: 'Portfolio cards',
          subtitle:
              'KPIs, win rate, extremes, risk/reward, drawdown, streaks and '
              'the P/L calendar.',
        ),
        SizedBox(height: gap),
        _StatCardGallery(index: next()),
        SizedBox(height: gap),
        _WinRateCardGallery(index: next()),
        SizedBox(height: gap),
        _ExtremeTradeCardGallery(index: next()),
        SizedBox(height: gap),
        _RiskRewardCardGallery(index: next()),
        SizedBox(height: gap),
        _DrawdownCardGallery(index: next()),
        SizedBox(height: gap),
        _StreakCardGallery(index: next()),
        SizedBox(height: gap),
        _CalendarDayCardGallery(index: next()),
        SizedBox(height: gap),
        const UiShowcaseSection(
          title: 'Community cards',
          subtitle:
              'Social feed, traders, leaderboard, comments, DMs, insights, '
              'news and notifications.',
        ),
        SizedBox(height: gap),
        _PostCardGallery(index: next()),
        SizedBox(height: gap),
        _TraderRowGallery(index: next()),
        SizedBox(height: gap),
        _TraderCardGallery(index: next()),
        SizedBox(height: gap),
        _LeaderboardCardGallery(index: next()),
        SizedBox(height: gap),
        _CommentCardGallery(index: next()),
        SizedBox(height: gap),
        _ConversationCardGallery(index: next()),
        SizedBox(height: gap),
        _MessageBubbleGallery(index: next()),
        SizedBox(height: gap),
        _AiInsightCardGallery(index: next()),
        SizedBox(height: gap),
        _NewsCardGallery(index: next()),
        SizedBox(height: gap),
        _NotificationCardGallery(index: next()),
        SizedBox(height: gap),
        const UiShowcaseSection(
          title: 'Account cards',
          subtitle: 'Plans, usage meters, tier gates, achievements, settings.',
        ),
        SizedBox(height: gap),
        _PlanCardGallery(index: next()),
        SizedBox(height: gap),
        _UsageCardGallery(index: next()),
        SizedBox(height: gap),
        _TierGateCardGallery(index: next()),
        SizedBox(height: gap),
        _AchievementCardGallery(index: next()),
        SizedBox(height: gap),
        _SettingCardGallery(index: next()),
        SizedBox(height: gap),
        const UiShowcaseSection(
          title: 'AI cards',
          subtitle: 'Assistant thread bubbles, analysis cards and prompt chips.',
        ),
        SizedBox(height: gap),
        _AiMessageBubbleGallery(index: next()),
        SizedBox(height: gap),
        _AiAnalysisCardGallery(index: next()),
        SizedBox(height: gap),
        _AiPromptChipsGallery(index: next()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Brand
// ---------------------------------------------------------------------------

class _BrandGallery extends StatelessWidget {
  const _BrandGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppLogo family',
      description:
          'Mark, wordmark, full lockup (row/stacked) and the animated splash '
          'mark, painted in pure Dart with no image assets.',
      tags: const <String>['brand', 'animated'],
      minCaseWidth: 220,
      cases: <UiStateCase>[
        const UiStateCase.of('mark', AppLogoMark(size: 40)),
        const UiStateCase.of(
          'mark · draw-in 40%',
          AppLogoMark(size: 40, progress: 0.4),
        ),
        const UiStateCase.of(
          'mark · unrounded',
          AppLogoMark(size: 40, rounded: false),
        ),
        const UiStateCase.of('wordmark', AppWordmark()),
        const UiStateCase.of('logo · row', AppLogo()),
        const UiStateCase.of(
          'logo · stacked + tagline',
          AppLogo(stacked: true, tagline: 'Trade with clarity'),
        ),
        const UiStateCase.of('logo · compact', AppLogo(compact: true)),
        const UiStateCase.of(
          'splash mark',
          AppSplashMark(size: 56, tagline: 'Loading your dashboard…'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Motion
// ---------------------------------------------------------------------------

class _MotionGallery extends StatelessWidget {
  const _MotionGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'Motion primitives',
      description:
          'Fade-in entrances, hover lift, reveal-driven charts, animated '
          'counters and expand/collapse — the building blocks every card '
          'above composes with.',
      tags: const <String>['motion', 'entrance', 'hover'],
      minCaseWidth: 220,
      cases: <UiStateCase>[
        UiStateCase(
          'AppFadeIn',
          builder: (BuildContext _) => AppFadeIn(
            child: UiBadge(label: 'Fades + slides in', icon: Icons.arrow_upward),
          ),
        ),
        UiStateCase(
          'AppReveal',
          builder: (BuildContext _) => AppReveal(
            builder: (BuildContext ctx, double t) =>
                UiSparkChart(values: _sparkA.map((double v) => v * t).toList(), filled: true),
          ),
        ),
        UiStateCase(
          'AppHoverLift',
          builder: (BuildContext _) => const AppHoverLift(
            child: UiBadge(label: 'Hover me (desktop)', icon: Icons.mouse),
          ),
        ),
        UiStateCase(
          'AppCountUp',
          builder: (BuildContext ctx) => AppCountUp(
            value: 18452.37,
            formatter: (num v) => AppTokens.money(v),
            style: ctx.uiText.title,
          ),
        ),
        UiStateCase(
          'AppCollapse · expanded',
          builder: (BuildContext _) => const AppCollapse(
            expanded: true,
            child: UiBadge(label: 'Visible content'),
          ),
        ),
        UiStateCase(
          'AppCollapse · collapsed',
          builder: (BuildContext _) => const AppCollapse(
            expanded: false,
            child: UiBadge(label: 'Hidden content'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Journal
// ---------------------------------------------------------------------------

class _TradeCardGallery extends StatelessWidget {
  const _TradeCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppTradeCard',
      description:
          'A single logged trade: ticker, side, animated P/L, entry/exit '
          'meta, strategy and tags.',
      tags: const <String>['journal', 'trade'],
      minCaseWidth: 300,
      cases: <UiStateCase>[
        UiStateCase.of('bullish · win', AppTradeCard(trade: _winningTrade)),
        UiStateCase.of('bearish · loss', AppTradeCard(trade: _losingTrade)),
        UiStateCase.of(
          'selected',
          AppTradeCard(trade: _winningTrade, selected: true),
        ),
        UiStateCase.of(
          'dense',
          AppTradeCard(trade: _winningTrade, dense: true),
        ),
        const UiStateCase.of('loading', AppTradeCardSkeleton()),
      ],
    );
  }
}

class _PnlSummaryCardGallery extends StatelessWidget {
  const _PnlSummaryCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppPnlSummaryCard',
      description: 'Compact P/L rollup for a day, week or ticker group.',
      tags: const <String>['journal', 'summary'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        UiStateCase.of(
          'bullish',
          AppPnlSummaryCard(
            title: 'This week',
            pnl: 1284.55,
            trades: 14,
            winRate: 64,
            spark: _sparkA,
          ),
        ),
        UiStateCase.of(
          'bearish',
          AppPnlSummaryCard(
            title: 'Last week',
            pnl: -320.10,
            trades: 9,
            winRate: 33,
            spark: _sparkB,
          ),
        ),
        UiStateCase.of(
          'empty',
          AppPnlSummaryCard(title: 'Today', pnl: 0, trades: 0),
        ),
      ],
    );
  }
}

class _LessonCardGallery extends StatelessWidget {
  const _LessonCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppLessonCard',
      description: 'Free-form lesson/note tied to a trade or tag.',
      tags: const <String>['journal', 'notes'],
      minCaseWidth: 280,
      cases: <UiStateCase>[
        UiStateCase.of(
          'info',
          const AppLessonCard(
            title: 'Wait for confirmation',
            body: 'Entered before the retest held — patience pays.',
            tags: <String>['discipline', 'entries'],
          ),
        ),
        UiStateCase.of(
          'bullish',
          const AppLessonCard(
            title: 'Let winners run',
            body: 'Trailed the stop instead of taking profit early.',
            intent: UiIntent.bullish,
            tags: <String>['exits'],
          ),
        ),
        UiStateCase.of(
          'bearish',
          const AppLessonCard(
            title: 'Revenge trade',
            body: 'Re-entered right after a loss without a plan.',
            intent: UiIntent.bearish,
          ),
        ),
      ],
    );
  }
}

class _ScreenshotImportCardGallery extends StatelessWidget {
  const _ScreenshotImportCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppScreenshotImportCard',
      description: 'Drop zone for chart screenshots that AI parses into a trade.',
      tags: const <String>['journal', 'ai', 'upload'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        const UiStateCase.of('empty', AppScreenshotImportCard()),
        const UiStateCase.of(
          'loading · parsing',
          AppScreenshotImportCard(
            imageUrl: 'https://picsum.photos/seed/chart/400/225',
            parsing: true,
          ),
        ),
        const UiStateCase.of(
          'populated',
          AppScreenshotImportCard(
            imageUrl: 'https://picsum.photos/seed/chart2/400/225',
            parsedSummary: 'Detected AAPL long, entry 227.10, stop 224.50.',
          ),
        ),
      ],
    );
  }
}

class _ChecklistCardGallery extends StatelessWidget {
  const _ChecklistCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppChecklistCard',
      description: 'Pre-trade / post-trade checklist with progress bar.',
      tags: const <String>['journal', 'checklist'],
      minCaseWidth: 280,
      cases: <UiStateCase>[
        UiStateCase.of(
          'in progress',
          AppChecklistCard(title: 'Pre-trade checklist', items: _checklist),
        ),
        UiStateCase.of(
          'complete',
          AppChecklistCard(
            title: 'Pre-trade checklist',
            items: _checklist.map((AppChecklistItem c) => AppChecklistItem(
              id: c.id, label: c.label, description: c.description, done: true, icon: c.icon,
            )).toList(),
          ),
        ),
        UiStateCase.of(
          'empty',
          const AppChecklistCard(title: 'Post-trade checklist', items: <AppChecklistItem>[]),
        ),
        const UiStateCase.of(
          'loading',
          AppChecklistCard(title: 'Pre-trade checklist', items: <AppChecklistItem>[], loading: true),
        ),
      ],
    );
  }
}

class _PsychologyCardGallery extends StatelessWidget {
  const _PsychologyCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppPsychologyCard',
      description: 'Mindset / discipline rating attached to an entry.',
      tags: const <String>['journal', 'psychology'],
      minCaseWidth: 240,
      cases: <UiStateCase>[
        const UiStateCase.of(
          'high score',
          AppPsychologyCard(score: 5, note: 'Calm, followed the plan exactly.'),
        ),
        const UiStateCase.of(
          'mid score',
          AppPsychologyCard(score: 3, note: 'A little rushed on the entry.'),
        ),
        const UiStateCase.of(
          'low score',
          AppPsychologyCard(score: 1, note: 'Traded angry after the last loss.'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Strategy
// ---------------------------------------------------------------------------

class _StrategyCardGallery extends StatelessWidget {
  const _StrategyCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppStrategyCard',
      description: 'Strategy playbook summary with visibility and version badges.',
      tags: const <String>['strategy'],
      minCaseWidth: 280,
      cases: <UiStateCase>[
        UiStateCase.of('public + favorite', AppStrategyCard(strategy: _strategyA)),
        UiStateCase.of('private', AppStrategyCard(strategy: _strategyB)),
        UiStateCase.of('selected', AppStrategyCard(strategy: _strategyA, selected: true)),
        UiStateCase.of('dense', AppStrategyCard(strategy: _strategyA, dense: true)),
        UiStateCase.of('loading', AppStrategyCard(strategy: _strategyA, loading: true)),
      ],
    );
  }
}

class _StrategyPerformanceCardGallery extends StatelessWidget {
  const _StrategyPerformanceCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppStrategyPerformanceCard',
      description: 'Win-rate ring, net P/L and equity spark for one strategy.',
      tags: const <String>['strategy', 'performance'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase.of('bullish', AppStrategyPerformanceCard(strategy: _strategyA)),
        UiStateCase.of('bearish', AppStrategyPerformanceCard(strategy: _strategyC)),
      ],
    );
  }
}

class _VersionCardGallery extends StatelessWidget {
  const _VersionCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppVersionCard',
      description: 'One entry in a strategy revision history.',
      tags: const <String>['strategy', 'history'],
      minCaseWidth: 280,
      cases: <UiStateCase>[
        UiStateCase.of(
          'current',
          AppVersionCard(
            version: AppStrategyVersion(
              id: 'v3', version: 3, savedAt: _now, author: 'You', isCurrent: true,
            ),
          ),
        ),
        UiStateCase.of(
          'restorable',
          AppVersionCard(
            version: AppStrategyVersion(
              id: 'v2', version: 2, savedAt: _daysAgo(4),
              author: 'You', note: 'Tightened stop rules',
            ),
            onRestore: () {},
          ),
        ),
      ],
    );
  }
}

class _StrategyComparisonCardGallery extends StatelessWidget {
  const _StrategyComparisonCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppStrategyComparisonCard',
      description: 'Head-to-head comparison of two strategies.',
      tags: const <String>['strategy', 'comparison'],
      minCaseWidth: 420,
      cases: <UiStateCase>[
        UiStateCase(
          'default',
          fill: true,
          builder: (BuildContext _) =>
              AppStrategyComparisonCard(a: _strategyA, b: _strategyC),
        ),
      ],
    );
  }
}

class _StrategySummaryCardGallery extends StatelessWidget {
  const _StrategySummaryCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppStrategySummaryCard',
      description: 'AI-generated plain-English summary of a strategy document.',
      tags: const <String>['strategy', 'ai'],
      minCaseWidth: 280,
      cases: <UiStateCase>[
        const UiStateCase.of(
          'populated',
          AppStrategySummaryCard(
            summary: 'A momentum breakout strategy that enters on volume '
                'expansion above the opening range, with a 2R target.',
          ),
        ),
        const UiStateCase.of(
          'loading',
          AppStrategySummaryCard(summary: '', loading: true),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Watchlist
// ---------------------------------------------------------------------------

class _TickerCardGallery extends StatelessWidget {
  const _TickerCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppTickerCard',
      description: 'Watched ticker: price, % change, sparkline, optional note.',
      tags: const <String>['watchlist'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        UiStateCase.of('bullish', AppTickerCard(ticker: _tickerA, onFavorite: () {})),
        UiStateCase.of('bearish', AppTickerCard(ticker: _tickerB, onFavorite: () {})),
        UiStateCase.of('selected', AppTickerCard(ticker: _tickerA, selected: true)),
        UiStateCase.of('dense', AppTickerCard(ticker: _tickerA, dense: true)),
        UiStateCase.of('loading', AppTickerCard(ticker: _tickerA, loading: true)),
      ],
    );
  }
}

class _PriceAlertCardGallery extends StatelessWidget {
  const _PriceAlertCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppPriceAlertCard',
      description: 'Price alert with target, direction and distance progress.',
      tags: const <String>['watchlist', 'alerts'],
      minCaseWidth: 300,
      cases: <UiStateCase>[
        UiStateCase.of(
          'active · above',
          AppPriceAlertCard(
            alert: AppPriceAlert(
              id: '1', symbol: 'AAPL', targetPrice: 240, above: true,
              currentPrice: 227.10, active: true,
            ),
          ),
        ),
        UiStateCase.of(
          'triggered',
          AppPriceAlertCard(
            alert: AppPriceAlert(
              id: '2', symbol: 'TSLA', targetPrice: 180, above: false,
              currentPrice: 176.20, active: false, triggeredAt: _daysAgo(1),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoverCardGallery extends StatelessWidget {
  const _MoverCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppMoverCard',
      description: 'Compact gainer/loser tile for horizontal-scroll rails.',
      tags: const <String>['watchlist', 'movers'],
      minCaseWidth: 180,
      cases: <UiStateCase>[
        UiStateCase.of('gainer', AppMoverCard(ticker: _tickerA)),
        UiStateCase.of('loser', AppMoverCard(ticker: _tickerB)),
      ],
    );
  }
}

class _HeatTileGallery extends StatelessWidget {
  const _HeatTileGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppHeatTile',
      description: 'Sector heatmap tile with intensity-scaled tint.',
      tags: const <String>['watchlist', 'heatmap'],
      minCaseWidth: 160,
      cases: <UiStateCase>[
        UiStateCase.of(
          'strong gain',
          AppHeatTile(label: 'Tech', changePercent: 3.8, onTap: () {}),
        ),
        UiStateCase.of(
          'mild loss',
          AppHeatTile(label: 'Energy', changePercent: -1.1, onTap: () {}),
        ),
        UiStateCase.of(
          'flat',
          AppHeatTile(label: 'Utilities', changePercent: 0.1),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Portfolio
// ---------------------------------------------------------------------------

class _StatCardGallery extends StatelessWidget {
  const _StatCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppStatCard',
      description: 'Headline KPI tile with animated value and optional spark.',
      tags: const <String>['portfolio', 'kpi'],
      minCaseWidth: 240,
      cases: <UiStateCase>[
        UiStateCase.of('bullish', AppStatCard(stat: _statBullish)),
        UiStateCase.of('bearish', AppStatCard(stat: _statBearish)),
        UiStateCase.of('selected', AppStatCard(stat: _statBullish, selected: true)),
        UiStateCase.of('dense', AppStatCard(stat: _statBullish, dense: true)),
        const UiStateCase.of('loading', AppStatCardSkeleton()),
      ],
    );
  }
}

class _WinRateCardGallery extends StatelessWidget {
  const _WinRateCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppWinRateCard',
      description: 'Radial win-rate gauge with wins/losses breakdown.',
      tags: const <String>['portfolio'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        const UiStateCase.of(
          'bullish',
          AppWinRateCard(winRate: 64, wins: 32, losses: 16, breakeven: 2),
        ),
        const UiStateCase.of(
          'bearish',
          AppWinRateCard(winRate: 38, wins: 9, losses: 15),
        ),
      ],
    );
  }
}

class _ExtremeTradeCardGallery extends StatelessWidget {
  const _ExtremeTradeCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppExtremeTradeCard',
      description: 'Best / worst trade highlight for a period.',
      tags: const <String>['portfolio'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        UiStateCase.of('best', AppExtremeTradeCard(trade: _winningTrade, best: true)),
        UiStateCase.of('worst', AppExtremeTradeCard(trade: _losingTrade, best: false)),
      ],
    );
  }
}

class _RiskRewardCardGallery extends StatelessWidget {
  const _RiskRewardCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppRiskRewardCard',
      description: 'Average R against a target R, with progress bar.',
      tags: const <String>['portfolio'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        const UiStateCase.of('above target', AppRiskRewardCard(avgR: 2.4, targetR: 2)),
        const UiStateCase.of('below target', AppRiskRewardCard(avgR: 1.1, targetR: 2)),
      ],
    );
  }
}

class _DrawdownCardGallery extends StatelessWidget {
  const _DrawdownCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppDrawdownCard',
      description: 'Max drawdown with an inverted area sparkline.',
      tags: const <String>['portfolio'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        UiStateCase.of(
          'populated',
          AppDrawdownCard(maxDrawdownPercent: -8.4, series: _sparkB),
        ),
        const UiStateCase.of(
          'empty',
          AppDrawdownCard(maxDrawdownPercent: 0, series: <double>[]),
        ),
      ],
    );
  }
}

class _StreakCardGallery extends StatelessWidget {
  const _StreakCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppStreakCard',
      description: 'Trading discipline streak tracker.',
      tags: const <String>['portfolio'],
      minCaseWidth: 300,
      cases: <UiStateCase>[
        UiStateCase.of(
          'winning streak',
          AppStreakCard(days: _streakGood, currentStreak: 5),
        ),
        UiStateCase.of(
          'mixed',
          AppStreakCard(days: _streakMixed),
        ),
      ],
    );
  }
}

class _CalendarDayCardGallery extends StatelessWidget {
  const _CalendarDayCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppCalendarDayCard',
      description: 'One day of the P/L calendar heatmap.',
      tags: const <String>['portfolio', 'calendar'],
      minCaseWidth: 96,
      cases: <UiStateCase>[
        UiStateCase.of(
          'profitable day',
          AppCalendarDayCard(
            day: AppDayPnl(date: _now, pnl: 420, trades: 5),
            maxAbsPnl: 500,
          ),
        ),
        UiStateCase.of(
          'losing day',
          AppCalendarDayCard(
            day: AppDayPnl(date: _daysAgo(1), pnl: -180, trades: 3),
            maxAbsPnl: 500,
          ),
        ),
        UiStateCase.of(
          'no trades',
          AppCalendarDayCard(
            day: AppDayPnl(date: _daysAgo(2), pnl: 0, trades: 0),
            maxAbsPnl: 500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Community
// ---------------------------------------------------------------------------

class _PostCardGallery extends StatelessWidget {
  const _PostCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppPostCard',
      description: 'Social feed post with tickers, media and engagement bar.',
      tags: const <String>['community', 'feed'],
      minCaseWidth: 360,
      cases: <UiStateCase>[
        UiStateCase('with media', fill: true, builder: (BuildContext _) => AppPostCard(post: _postWithMedia)),
        UiStateCase('text only', fill: true, builder: (BuildContext _) => AppPostCard(post: _postTextOnly)),
        UiStateCase('loading', fill: true, builder: (BuildContext _) => AppPostCard(post: _postTextOnly, loading: true)),
      ],
    );
  }
}

class _TraderRowGallery extends StatelessWidget {
  const _TraderRowGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppTraderRow',
      description: 'Avatar + handle + tier row reused in feeds and lists.',
      tags: const <String>['community'],
      minCaseWidth: 280,
      cases: <UiStateCase>[
        UiStateCase.of('verified · premium', AppTraderRow(trader: _traderA)),
        UiStateCase.of('free · trailing label', AppTraderRow(trader: _traderB, trailingLabel: '2h')),
      ],
    );
  }
}

class _TraderCardGallery extends StatelessWidget {
  const _TraderCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppTraderCard',
      description: 'Full trader profile with follow action and key stats.',
      tags: const <String>['community', 'profile'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase.of('not following', AppTraderCard(trader: _traderA, onFollow: () {}, onMessage: () {})),
        UiStateCase.of('following', AppTraderCard(trader: _traderB, onFollow: () {})),
        UiStateCase.of('selected', AppTraderCard(trader: _traderA, selected: true)),
        UiStateCase.of('loading', AppTraderCard(trader: _traderA, loading: true)),
      ],
    );
  }
}

class _LeaderboardCardGallery extends StatelessWidget {
  const _LeaderboardCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppLeaderboardCard',
      description: 'Ranked row with podium accent and performance value.',
      tags: const <String>['community', 'leaderboard'],
      minCaseWidth: 300,
      cases: <UiStateCase>[
        UiStateCase.of('podium', AppLeaderboardCard(rank: 1, trader: _traderA, value: 42.8)),
        UiStateCase.of('regular', AppLeaderboardCard(rank: 14, trader: _traderB, value: -3.2)),
      ],
    );
  }
}

class _CommentCardGallery extends StatelessWidget {
  const _CommentCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppCommentCard',
      description: 'Threaded comment with like/reply actions.',
      tags: const <String>['community'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase('top-level', fill: true, builder: (BuildContext _) => AppCommentCard(comment: _commentA, onLike: () {}, onReply: () {})),
        UiStateCase('reply · indented', fill: true, builder: (BuildContext _) => AppCommentCard(comment: _commentB, indent: 1, onLike: () {})),
      ],
    );
  }
}

class _ConversationCardGallery extends StatelessWidget {
  const _ConversationCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppConversationCard',
      description: 'Direct-message conversation row with unread count.',
      tags: const <String>['community', 'messaging'],
      minCaseWidth: 300,
      cases: <UiStateCase>[
        UiStateCase.of('unread', AppConversationCard(conversation: _conversationUnread)),
        UiStateCase.of('read', AppConversationCard(conversation: _conversationRead)),
      ],
    );
  }
}

class _MessageBubbleGallery extends StatelessWidget {
  const _MessageBubbleGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppMessageBubble',
      description: 'DM thread chat bubble, mine vs. theirs, pending state.',
      tags: const <String>['community', 'messaging'],
      minCaseWidth: 240,
      cases: <UiStateCase>[
        UiStateCase.of(
          'from me',
          AppMessageBubble(
            message: AppChatMessage(id: '1', body: 'Are you long AAPL here?', fromMe: true, sentAt: _now),
          ),
        ),
        UiStateCase.of(
          'from them',
          AppMessageBubble(
            message: AppChatMessage(id: '2', body: 'Yep, trimmed half at 230.', fromMe: false, sentAt: _daysAgo(0)),
          ),
        ),
        UiStateCase.of(
          'pending',
          AppMessageBubble(
            message: AppChatMessage(id: '3', body: 'Sending chart…', fromMe: true, sentAt: _now, pending: true),
          ),
        ),
      ],
    );
  }
}

class _AiInsightCardGallery extends StatelessWidget {
  const _AiInsightCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppAiInsightCard',
      description: 'AI insight with confidence meter and sentiment badge.',
      tags: const <String>['community', 'ai'],
      minCaseWidth: 300,
      cases: <UiStateCase>[
        UiStateCase.of('bullish', AppAiInsightCard(insight: _insightBullish)),
        UiStateCase.of('bearish', AppAiInsightCard(insight: _insightBearish)),
      ],
    );
  }
}

class _NewsCardGallery extends StatelessWidget {
  const _NewsCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppNewsCard',
      description: 'News headline with sentiment-tinted accent.',
      tags: const <String>['community', 'news'],
      minCaseWidth: 300,
      cases: <UiStateCase>[
        UiStateCase.of('bullish', AppNewsCard(item: _newsBullish)),
        UiStateCase.of('bearish', AppNewsCard(item: _newsBearish)),
      ],
    );
  }
}

class _NotificationCardGallery extends StatelessWidget {
  const _NotificationCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppNotificationCard',
      description: 'Notification row: read/unread tint and optional dismiss.',
      tags: const <String>['community', 'notifications'],
      minCaseWidth: 300,
      cases: <UiStateCase>[
        UiStateCase.of('unread', AppNotificationCard(notification: _notifUnread, onDismiss: () {})),
        UiStateCase.of('read', AppNotificationCard(notification: _notifRead)),
        UiStateCase(
          'empty',
          builder: (BuildContext _) => const UiEmptyState(
            title: 'All caught up',
            message: 'You have no new notifications.',
            icon: Icons.notifications_none,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Account
// ---------------------------------------------------------------------------

class _PlanCardGallery extends StatelessWidget {
  const _PlanCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppPlanCard',
      description: 'Subscription plan tile used on pricing / upgrade screens.',
      tags: const <String>['account', 'pricing'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        UiStateCase.of('current', AppPlanCard(plan: _planFree)),
        UiStateCase.of('highlighted', AppPlanCard(plan: _planPremium, onSelect: () {})),
        UiStateCase.of('enterprise', AppPlanCard(plan: _planEnterprise, onSelect: () {})),
      ],
    );
  }
}

class _UsageCardGallery extends StatelessWidget {
  const _UsageCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppUsageCard',
      description: 'Quota meter for tier-limited features.',
      tags: const <String>['account', 'usage'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        const UiStateCase.of(
          'healthy',
          AppUsageCard(label: 'Screenshot imports', used: 12, limit: 50, icon: Icons.image_outlined),
        ),
        UiStateCase.of(
          'near limit',
          AppUsageCard(label: 'AI credits', used: 46, limit: 50, icon: Icons.auto_awesome, onUpgrade: () {}),
        ),
      ],
    );
  }
}

class _TierGateCardGallery extends StatelessWidget {
  const _TierGateCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppTierGateCard',
      description: 'Locked-feature block shown when a tier gate blocks content.',
      tags: const <String>['account', 'paywall'],
      minCaseWidth: 300,
      cases: <UiStateCase>[
        UiStateCase.of(
          'premium required',
          AppTierGateCard(
            requiredTier: AppTier.premium,
            title: 'Strategy backtesting',
            message: 'Upgrade to premium to simulate strategies on history.',
            onUpgrade: () {},
          ),
        ),
        UiStateCase.of(
          'enterprise required',
          AppTierGateCard(
            requiredTier: AppTier.enterprise,
            title: 'Team workspaces',
            onUpgrade: () {},
          ),
        ),
      ],
    );
  }
}

class _AchievementCardGallery extends StatelessWidget {
  const _AchievementCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppAchievementCard',
      description: 'Gamified achievement badge, locked and unlocked.',
      tags: const <String>['account', 'gamification'],
      minCaseWidth: 200,
      cases: <UiStateCase>[
        UiStateCase.of(
          'unlocked',
          AppAchievementCard(
            achievement: AppAchievement(
              id: '1', title: '10 win streak', icon: Icons.local_fire_department,
              description: 'Win ten trades in a row.', unlocked: true,
            ),
          ),
        ),
        UiStateCase.of(
          'in progress',
          AppAchievementCard(
            achievement: AppAchievement(
              id: '2', title: '100 trades logged', icon: Icons.checklist,
              description: 'Log 100 trades in your journal.', progress: 0.62,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingCardGallery extends StatelessWidget {
  const _SettingCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppSettingCard',
      description: 'Settings row: label, description and a trailing control.',
      tags: const <String>['account', 'settings'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase(
          'switch',
          fill: true,
          builder: (BuildContext _) => AppSettingCard(
            title: 'Push notifications',
            description: 'Get alerted on price targets and mentions.',
            icon: Icons.notifications_outlined,
            control: UiSwitch(value: true, onChanged: (_) {}),
          ),
        ),
        UiStateCase(
          'button',
          fill: true,
          builder: (BuildContext _) => AppSettingCard(
            title: 'Two-factor authentication',
            icon: Icons.lock_outline,
            control: UiButton(
              label: 'Enable',
              size: UiSize.sm,
              variant: UiVariant.outline,
              expandOnMobile: false,
              onPressed: () {},
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// AI
// ---------------------------------------------------------------------------

class _AiMessageBubbleGallery extends StatelessWidget {
  const _AiMessageBubbleGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppAiMessageBubble',
      description: 'Assistant thread bubble: user, assistant, pending, error, system.',
      tags: const <String>['ai', 'chat'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase.of(
          'user',
          AppAiMessageBubble(
            message: AppAiMessage(id: '1', role: AppAiRole.user, body: 'How did my week look?', sentAt: _now),
          ),
        ),
        UiStateCase.of(
          'assistant · sources',
          AppAiMessageBubble(
            message: AppAiMessage(
              id: '2', role: AppAiRole.assistant,
              body: 'You closed the week up +\$1,284 across 14 trades.',
              sentAt: _now, sources: const <String>['journal', 'trades'],
            ),
          ),
        ),
        UiStateCase.of(
          'loading',
          AppAiMessageBubble(
            message: const AppAiMessage(id: '3', role: AppAiRole.assistant, body: '', pending: true),
          ),
        ),
        UiStateCase.of(
          'error',
          AppAiMessageBubble(
            message: AppAiMessage(
              id: '4', role: AppAiRole.assistant, body: '', sentAt: _now,
              error: 'Could not reach the assistant. Try again.',
            ),
          ),
        ),
        UiStateCase.of(
          'system',
          const AppAiMessageBubble(
            message: AppAiMessage(id: '5', role: AppAiRole.system, body: 'New conversation started'),
          ),
        ),
      ],
    );
  }
}

class _AiAnalysisCardGallery extends StatelessWidget {
  const _AiAnalysisCardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppAiAnalysisCard',
      description: 'AI verdict on a trade/strategy/ticker with confidence meter.',
      tags: const <String>['ai', 'analysis'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase(
          'populated',
          fill: true,
          builder: (BuildContext _) => AppAiAnalysisCard(
            insight: _insightBullish,
            observations: const <String>['Volume confirms the breakout', 'Risk/reward favors longs'],
            onAsk: () {},
            onDismiss: () {},
          ),
        ),
        UiStateCase(
          'loading',
          fill: true,
          builder: (BuildContext _) => AppAiAnalysisCard(insight: _insightBullish, loading: true),
        ),
        UiStateCase(
          'error',
          fill: true,
          builder: (BuildContext _) => AppAiAnalysisCard(
            insight: _insightBullish,
            error: 'Analysis failed — the model timed out.',
          ),
        ),
      ],
    );
  }
}

class _AiPromptChipsGallery extends StatelessWidget {
  const _AiPromptChipsGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'AppAiPromptChips',
      description: 'Suggested prompt chips shown above the AI composer.',
      tags: const <String>['ai', 'chips'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase(
          'default',
          fill: true,
          builder: (BuildContext _) => AppAiPromptChips(prompts: _prompts, onSelect: (_) {}),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final DateTime _now = DateTime.now();
DateTime _daysAgo(int d) => _now.subtract(Duration(days: d));

const List<double> _sparkA = <double>[10, 12, 11, 14, 16, 15, 19, 22, 20, 24];
const List<double> _sparkB = <double>[20, 18, 19, 15, 13, 14, 10, 8, 9, 6];
const List<double> _streakGood = <double>[120, 80, -40, 60, 90, 30, 150];
const List<double> _streakMixed = <double>[-30, 0, 40, -60, 20, -10, 0];

final AppTrade _winningTrade = AppTrade(
  id: 't1',
  ticker: 'AAPL',
  side: AppSide.long,
  entry: 224.50,
  exit: 231.80,
  openedAt: _daysAgo(1),
  closedAt: _now,
  rMultiple: 2.4,
  pnl: 730,
  pnlPercent: 3.25,
  size: 100,
  outcome: AppOutcome.win,
  strategy: 'Breakout',
  tags: const <String>['earnings', 'momentum'],
);

final AppTrade _losingTrade = AppTrade(
  id: 't2',
  ticker: 'TSLA',
  side: AppSide.short,
  entry: 182.10,
  exit: 188.40,
  openedAt: _daysAgo(2),
  closedAt: _daysAgo(2),
  rMultiple: -1.1,
  pnl: -320,
  pnlPercent: -3.46,
  size: 50,
  outcome: AppOutcome.loss,
  strategy: 'Mean reversion',
  tags: const <String>['fomo'],
);

final List<AppChecklistItem> _checklist = <AppChecklistItem>[
  const AppChecklistItem(id: 'c1', label: 'Market in trend', description: 'Above 20 EMA on daily', done: true, icon: Icons.trending_up),
  const AppChecklistItem(id: 'c2', label: 'Risk sized to 1%', done: true, icon: Icons.shield_outlined),
  const AppChecklistItem(id: 'c3', label: 'Catalyst confirmed', icon: Icons.newspaper_outlined),
];

final AppStrategy _strategyA = AppStrategy(
  id: 's1', name: 'ORB Breakout', category: 'Momentum', summary:
      'Enters on a break of the opening range with volume confirmation.',
  isPublic: true, isFavorite: true, trades: 128, winRate: 61,
  avgR: 2.1, netPnl: 8420, versionCount: 4, updatedAt: _daysAgo(3),
  equityCurve: _sparkA,
);

final AppStrategy _strategyB = AppStrategy(
  id: 's2', name: 'VWAP Reversion', category: 'Mean reversion',
  summary: 'Fades extended moves back toward VWAP on low-float names.',
  isPublic: false, trades: 54, winRate: 48, avgR: 1.3, netPnl: 640,
  versionCount: 2, updatedAt: _daysAgo(10),
);

final AppStrategy _strategyC = AppStrategy(
  id: 's3', name: 'Gap Fade', category: 'Reversal', trades: 40,
  winRate: 35, avgR: -0.4, netPnl: -1120, versionCount: 1,
  equityCurve: _sparkB,
);

final AppTicker _tickerA = AppTicker(
  symbol: 'AAPL', name: 'Apple Inc.', price: 227.10, changePercent: 1.84,
  spark: _sparkA, note: 'Watching for a break above 230.', isFavorite: true,
);

final AppTicker _tickerB = AppTicker(
  symbol: 'TSLA', name: 'Tesla, Inc.', price: 176.20, changePercent: -2.35,
  spark: _sparkB,
);

const AppStat _statBullish = AppStat(
  label: 'Net P/L (30d)', value: 8420.55, delta: 12.4,
  icon: Icons.account_balance_wallet_outlined, spark: _sparkA,
);

const AppStat _statBearish = AppStat(
  label: 'Max drawdown', value: -1120, delta: -8.1,
  icon: Icons.trending_down, spark: _sparkB,
);

final AppTrader _traderA = AppTrader(
  id: 'u1', handle: 'quantqueen', displayName: 'Ava Chen',
  avatarUrl: 'https://i.pravatar.cc/150?img=32', bio: 'Swing trading tech and semis.',
  tier: AppTier.premium, followers: 12400, following: 210, winRate: 58,
  verified: true, tradingStyle: 'Swing',
);

final AppTrader _traderB = AppTrader(
  id: 'u2', handle: 'daytraderdan', displayName: 'Dan Ruiz',
  followers: 340, following: 890, winRate: 41, isFollowing: true,
  tradingStyle: 'Day trading',
);

final AppPost _postWithMedia = AppPost(
  id: 'p1', author: _traderA,
  body: 'Rotated out of TSLA into AAPL ahead of earnings. Chart looks clean.',
  createdAt: _daysAgo(0), tickers: const <String>['AAPL', 'TSLA'],
  imageUrl: 'https://picsum.photos/seed/post1/640/360', likes: 214, comments: 18, liked: true,
);

final AppPost _postTextOnly = AppPost(
  id: 'p2', author: _traderB,
  body: 'Discipline over conviction. Cut the loser fast today.',
  createdAt: _daysAgo(1), likes: 42, comments: 5,
);

final AppComment _commentA = AppComment(
  id: 'c1', author: _traderB, body: 'Great trade management!', createdAt: _daysAgo(0), likes: 6,
);

final AppComment _commentB = AppComment(
  id: 'c2', author: _traderA, body: 'Thanks — trailed the stop once it cleared VWAP.',
  createdAt: _daysAgo(0), likes: 2, liked: true,
);

final AppConversation _conversationUnread = AppConversation(
  id: 'conv1', peer: _traderA, lastMessage: 'Are you long AAPL here?',
  lastMessageAt: _now, unread: 3,
);

final AppConversation _conversationRead = AppConversation(
  id: 'conv2', peer: _traderB, lastMessage: 'Sounds good, talk tomorrow.',
  lastMessageAt: _daysAgo(1),
);

final AppAiInsight _insightBullish = AppAiInsight(
  id: 'i1', title: 'AAPL breakout intact', body:
      'Price is holding above the breakout level with rising volume, '
      'suggesting continuation toward the next resistance zone.',
  confidence: 0.78, sentimentScore: 0.4, tickers: const <String>['AAPL'],
  createdAt: _now,
);

final AppAiInsight _insightBearish = AppAiInsight(
  id: 'i2', title: 'TSLA losing momentum', body:
      'Momentum is fading on declining volume; consider tightening stops.',
  confidence: 0.55, sentimentScore: -0.3, tickers: const <String>['TSLA'],
  createdAt: _daysAgo(1),
);

final AppNewsItem _newsBullish = AppNewsItem(
  id: 'n1', headline: 'Apple beats on revenue, raises guidance',
  source: 'MarketWire', publishedAt: _daysAgo(0), sentimentScore: 0.5,
  tickers: const <String>['AAPL'], summary: 'Strong services growth drove the beat.',
);

final AppNewsItem _newsBearish = AppNewsItem(
  id: 'n2', headline: 'Tesla deliveries miss estimates',
  source: 'Reuters', publishedAt: _daysAgo(1), sentimentScore: -0.4,
  tickers: const <String>['TSLA'],
);

final AppNotification _notifUnread = AppNotification(
  id: 'not1', title: 'AAPL crossed \$227.10', createdAt: _now,
  body: 'Your price alert just triggered.', icon: Icons.notifications_active,
);

final AppNotification _notifRead = AppNotification(
  id: 'not2', title: 'Weekly recap is ready', createdAt: _daysAgo(2),
  body: 'You closed the week up 3.1%.', icon: Icons.summarize_outlined, read: true,
);

const AppPlan _planFree = AppPlan(
  tier: AppTier.free, priceLabel: '\$0', features: <String>['1 watchlist', 'Manual journal'],
  current: true,
);

const AppPlan _planPremium = AppPlan(
  tier: AppTier.premium, priceLabel: '\$19', highlighted: true,
  description: 'For active traders who want AI insights.',
  features: <String>['Unlimited watchlists', 'AI trade analysis', 'Strategy backtesting'],
);

const AppPlan _planEnterprise = AppPlan(
  tier: AppTier.enterprise, priceLabel: '\$99',
  description: 'For trading teams and prop desks.',
  features: <String>['Team workspaces', 'Audit log', 'Dedicated support'],
);

final List<AppAiPrompt> _prompts = <AppAiPrompt>[
  const AppAiPrompt(label: 'Summarize my week', prompt: 'Summarize my trading week', icon: Icons.summarize_outlined),
  const AppAiPrompt(label: 'Find my best setup', prompt: 'Which setup performs best for me?', icon: Icons.query_stats),
  const AppAiPrompt(label: 'Review AAPL', prompt: 'Analyze my AAPL trades', icon: Icons.show_chart),
];
