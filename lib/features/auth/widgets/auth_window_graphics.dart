import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

/// Which slice of TraderHub the showcase panel previews. Every scene is
/// built entirely out of real `app-ui` domain cards and charts — there are
/// no illustrations, icons-as-art, or image/SVG assets anywhere here.
enum AuthScene {
  /// Portfolio + market view: equity curve, headline stats, watchlist.
  /// AI + community view: an AI insight, a logged trade, a community post.
  social,
}

/// Live "window" preview shown beside the auth forms on wide screens.
///
/// Every element inside is a genuine TraderHub component (`AppStatCard`,
/// `AppTickerCard`, `UiAreaChartCard`, `AppAiInsightCard`, `AppTradeCard`,
/// `AppPostCard`) wired to the same [DemoDataSource] the signed-in app reads —
/// the goal is that this panel reads like an actual screenshot of the product,
/// not decoration bolted on next to it.
class AuthWindowGraphics extends StatefulWidget {
  const AuthWindowGraphics({
    super.key,
    this.role = UserRole.customer,
    this.title = 'TradeX',
    this.scene = AuthScene.social,
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
  /// Everything in the window comes from the same source the signed-in app
  /// reads, so a visitor is never shown an instrument, trader or headline that
  /// vanishes the moment they create an account.
  final DemoDataSource _demo = DemoDataSource.instance;

  /// Trades the account has actually closed. Open positions carry no P/L yet, so
  /// they would drag both headline numbers toward zero if counted.
  late final List<AppTrade> _closedTrades = _demo
      .trades()
      .where((AppTrade t) => t.outcome != AppOutcome.open)
      .toList(growable: false);

  late final List<AppSeriesPoint> _equity = _demo.equitySeries(points: 36);

  /// Account equity against the index it trades. Both lines are rebased to 100
  /// so a ₹5,00,000 book and a 24,000-point index can share one axis.
  late final List<UiChartPoint> _areaData = _rebasedEquityVsIndex();

  late final List<AppTicker> _tickers = _demo.tickers(limit: 3);

  late final AppStat _statPnl = AppStat(
    label: 'Total P/L',
    value: _closedTrades.fold<double>(
      0,
      (double sum, AppTrade t) => sum + t.pnl,
    ),
    delta: _equityChangePercent,
    icon: Icons.trending_up_rounded,
    spark: <double>[
      for (final AppSeriesPoint p in _demo.equitySeries(points: 8)) p.value,
    ],
    formatter: (num v) => '₹${v.toStringAsFixed(0)}',
  );

  late final AppStat _statWinRate = AppStat(
    label: 'Win Rate',
    value: _winRate,
    delta: null,
    icon: Icons.emoji_events_outlined,
    suffix: '%',
  );

  /// The account's best closed trade — the one a reader would be shown on the
  /// dashboard, not a hand-written example.
  late final AppTrade _trade = _closedTrades.isEmpty
      ? _demo.trades().first
      : _closedTrades.reduce(
          (AppTrade a, AppTrade b) => a.pnl >= b.pnl ? a : b,
        );

  late final AppAiInsight _insight = _demo.insights(limit: 1).first;

  late final AppPost _post = _demo.posts(limit: 1).first;

  /// Share of closed trades that finished green, to one decimal.
  double get _winRate {
    if (_closedTrades.isEmpty) return 0;
    final int wins = _closedTrades
        .where((AppTrade t) => t.outcome == AppOutcome.win)
        .length;
    return double.parse((wins / _closedTrades.length * 100).toStringAsFixed(1));
  }

  /// Percentage move in equity across the charted window, which is what the
  /// delta on the P/L card is measuring.
  double get _equityChangePercent {
    if (_equity.length < 2) return 0;
    final double first = _equity.first.value;
    if (first == 0) return 0;
    return double.parse(
      ((_equity.last.value - first) / first * 100).toStringAsFixed(1),
    );
  }

  List<UiChartPoint> _rebasedEquityVsIndex() {
    final List<AppCandle> index = _demo.candles(
      'NIFTY50',
      count: _equity.length,
    );
    final int points = _equity.length < index.length
        ? _equity.length
        : index.length;
    if (points == 0) return const <UiChartPoint>[];
    final double equityBase = _equity.first.value == 0
        ? 1
        : _equity.first.value;
    final double indexBase = index.first.close == 0 ? 1 : index.first.close;
    return <UiChartPoint>[
      for (int i = 0; i < points; i++)
        UiChartPoint(
          label: _equity[i].label,
          values: <double>[
            _equity[i].value / equityBase * 100,
            index[i].close / indexBase * 100,
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final bool isMobile = context.uiRes.isMobile;
    final double pad = context.sp(
      widget.compact ? theme.spacing.md : theme.spacing.lg,
    );

    final List<UiChartSeries> areaSeries = <UiChartSeries>[
      UiChartSeries(name: 'Equity', color: colors.primary),
      UiChartSeries(name: 'NIFTY 50', color: colors.borderStrong),
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
              child: _SocialScene(
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
