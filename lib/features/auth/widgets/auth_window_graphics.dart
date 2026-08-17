import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

/// Which slice of TraderHub the showcase panel previews. Every scene is
/// built entirely out of real `app-ui` domain cards and charts — there are
/// no illustrations, icons-as-art, or image/SVG assets anywhere here.
enum AuthScene {
  /// Portfolio + market view: equity curve, headline stats, watchlist.
  markets,

  /// AI + community view: an AI insight, a logged trade, a community post.
  social,
}

/// Live "window" preview shown beside the auth forms on wide screens.
///
/// Every element inside is a genuine TraderHub component (`AppStatCard`,
/// `AppTickerCard`, `UiAreaChartCard`, `AppAiInsightCard`, `AppTradeCard`,
/// `AppPostCard`) wired to lightweight mock data — the goal is that this
/// panel reads like an actual screenshot of the product, not decoration
/// bolted on next to it.
class AuthWindowGraphics extends StatefulWidget {
  const AuthWindowGraphics({
    super.key,
    this.role = UserRole.customer,
    this.title = 'TradeX',
    this.scene = AuthScene.markets,
    this.height,
    this.compact = false,
  });

  final UserRole role;
  final String title;
  final AuthScene scene;
  final double? height;

  /// Tightens padding/typography for use inside a narrower column
  /// (e.g. a hero panel on mobile) rather than a full split-screen column.
  final bool compact;

  @override
  State<AuthWindowGraphics> createState() => _AuthWindowGraphicsState();
}

class _AuthWindowGraphicsState extends State<AuthWindowGraphics> {
  late final List<UiChartPoint> _areaData = <UiChartPoint>[
    for (int i = 0; i < 36; i++)
      UiChartPoint(
        label: 'D$i',
        values: <double>[
          50 + math.sin(i * 0.8) * 26 + (i * 0.9),
          30 + math.sin(i * 0.6) * 14 + (i * 0.45),
        ],
      ),
  ];

  static final List<AppTicker> _tickers = <AppTicker>[
    const AppTicker(
      symbol: 'AAPL',
      name: 'Apple Inc.',
      price: 221.44,
      changePercent: 1.8,
      spark: [10, 12, 11, 14, 16, 15, 18, 20],
    ),
    const AppTicker(
      symbol: 'NVDA',
      name: 'NVIDIA Corp.',
      price: 138.92,
      changePercent: -0.9,
      spark: [22, 20, 21, 18, 17, 19, 16, 15],
    ),
    const AppTicker(
      symbol: 'BTC',
      name: 'Bitcoin',
      price: 94210.0,
      changePercent: 3.2,
      currencySymbol: '₹',
      spark: [40, 42, 41, 45, 48, 46, 50, 54],
    ),
  ];

  static final AppStat _statPnl = AppStat(
    label: 'Total P/L',
    value: 12480,
    delta: 8.4,
    icon: Icons.trending_up_rounded,
    spark: const [4, 6, 5, 8, 10, 9, 12, 14],
    formatter: (v) => '₹${v.toStringAsFixed(0)}',
  );

  static const AppStat _statWinRate = AppStat(
    label: 'Win Rate',
    value: 68,
    delta: 3.2,
    icon: Icons.emoji_events_outlined,
    suffix: '%',
  );

  static final AppTrade _trade = AppTrade(
    id: 'trd-01',
    ticker: 'NVDA',
    side: AppSide.long,
    entry: 128.40,
    exit: 138.92,
    openedAt: DateTime.now().subtract(const Duration(days: 4)),
    closedAt: DateTime.now().subtract(const Duration(hours: 6)),
    stopLoss: 124.0,
    target: 140.0,
    size: 40,
    pnl: 420.80,
    pnlPercent: 8.2,
    rMultiple: 2.4,
    outcome: AppOutcome.win,
    strategy: 'Breakout',
    tags: const ['earnings', 'momentum'],
  );

  static final AppAiInsight _insight = AppAiInsight(
    id: 'ai-01',
    title: 'NVDA setup looks extended',
    body:
        'Price is 6% above the 20-day average with RSI near overbought. '
        'Consider trimming size or tightening the stop before the next print.',
    confidence: 0.78,
    sentimentScore: 0.4,
    tickers: const ['NVDA'],
    createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
  );

  static const AppTrader _trader = AppTrader(
    id: 'usr-01',
    handle: 'maya.trades',
    displayName: 'Maya Chen',
    tier: AppTier.premium,
    followers: 2840,
    winRate: 0.71,
    verified: true,
    tradingStyle: 'Swing · Options',
  );

  late final AppPost _post = AppPost(
    id: 'post-01',
    author: _trader,
    body:
        'Trimmed half my NVDA position into strength today — locking in gains '
        'ahead of earnings while letting the rest ride with a raised stop.',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    type: 'Trade Analysis',
    tickers: const ['NVDA'],
    likes: 128,
    comments: 24,
  );

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final bool isMobile = context.uiRes.isMobile;
    final double pad = context.sp(widget.compact ? theme.spacing.md : theme.spacing.lg);

    final List<UiChartSeries> areaSeries = <UiChartSeries>[
      UiChartSeries(name: 'Equity', color: colors.primary),
      UiChartSeries(name: 'Benchmark', color: colors.borderStrong),
    ];

    return Container(
      height: widget.height ?? (isMobile ? 420 : 520),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.6),
          width: theme.borders.hairline,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 40,
            spreadRadius: -8,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Window chrome header.
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: pad,
              vertical: context.sp(theme.spacing.sm),
            ),
            decoration: BoxDecoration(
              color: colors.surfaceMuted.withValues(alpha: 0.5),
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const AppLogoMark(size: 14),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(widget.title, style: context.uiText.bodyStrong),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: context.sz(6),
                      height: context.sz(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.bullish,
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      'Live',
                      style: context.uiText.caption.copyWith(
                        color: colors.foregroundSubtle,
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    UiBadge(
                      label: widget.role.shortTitle,
                      intent: widget.role.badgeIntent,
                      size: UiSize.xs,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.all(pad),
              child: widget.scene == AuthScene.markets
                  ? _MarketsScene(
                      areaData: _areaData,
                      areaSeries: areaSeries,
                      tickers: _tickers,
                      statPnl: _statPnl,
                      statWinRate: _statWinRate,
                      gap: context.sp(theme.spacing.md),
                    )
                  : _SocialScene(
                      insight: _insight,
                      trade: _trade,
                      post: _post,
                      gap: context.sp(theme.spacing.md),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketsScene extends StatelessWidget {
  const _MarketsScene({
    required this.areaData,
    required this.areaSeries,
    required this.tickers,
    required this.statPnl,
    required this.statWinRate,
    required this.gap,
  });

  final List<UiChartPoint> areaData;
  final List<UiChartSeries> areaSeries;
  final List<AppTicker> tickers;
  final AppStat statPnl;
  final AppStat statWinRate;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: AppStatCard(stat: statPnl, dense: true)),
            SizedBox(width: gap),
            Expanded(child: AppStatCard(stat: statWinRate, dense: true)),
          ],
        ),
        SizedBox(height: gap),
        UiAreaChartCard(
          title: 'Equity Curve',
          subtitle: 'Last 3 months',
          data: areaData,
          series: areaSeries,
          height: 190,
          showGrid: false,
          showAxisLabels: false,
          interactive: false,
          curved: true,
          glow: true,
        ),
        SizedBox(height: gap),
        Text('Watchlist', style: context.uiText.label.copyWith(
          color: context.ui.colors.foregroundSubtle,
        )),
        SizedBox(height: gap * 0.5),
        for (final t in tickers) ...[
          AppTickerCard(ticker: t, dense: true),
          if (t != tickers.last) SizedBox(height: gap * 0.5),
        ],
      ],
    );
  }
}

class _SocialScene extends StatelessWidget {
  const _SocialScene({
    required this.insight,
    required this.trade,
    required this.post,
    required this.gap,
  });

  final AppAiInsight insight;
  final AppTrade trade;
  final AppPost post;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppAiInsightCard(insight: insight),
        SizedBox(height: gap),
        AppTradeCard(trade: trade, dense: true),
        SizedBox(height: gap),
        AppPostCard(post: post),
      ],
    );
  }
}
