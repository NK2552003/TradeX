import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/dashboard/data/repositories/dashboard_repository.dart';

/// Trader home surface: the session snapshot, equity, calendar, movers, news
/// and the pre-trade checklist. Desktop gets a two-column dashboard layout;
/// mobile stacks the same blocks in priority order.
class TraderOverviewPage extends StatefulWidget {
  const TraderOverviewPage({
    super.key,
    this.repository,
    this.displayName,
    this.onOpenJournal,
    this.onOpenTrade,
    this.onOpenWatchlists,
    this.onOpenTicker,
    this.onOpenAi,
    this.onOpenPortfolio,
  });

  final DashboardRepository? repository;
  final String? displayName;
  final VoidCallback? onOpenJournal;
  final ValueChanged<AppTrade>? onOpenTrade;
  final VoidCallback? onOpenWatchlists;
  final ValueChanged<AppTicker>? onOpenTicker;
  final VoidCallback? onOpenAi;
  final VoidCallback? onOpenPortfolio;

  @override
  State<TraderOverviewPage> createState() => _TraderOverviewPageState();
}

class _TraderOverviewPageState extends State<TraderOverviewPage> {
  late final DashboardRepository _repo =
      widget.repository ?? DashboardRepositoryImpl();

  TraderDashboardSnapshot? _snapshot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final TraderDashboardSnapshot snapshot = await _repo.getTraderSnapshot();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  Future<void> _toggleChecklistItem(String id) async {
    await _repo.toggleChecklistItem(id);
    final TraderDashboardSnapshot snapshot = await _repo.getTraderSnapshot();
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  String get _greeting {
    final int hour = DateTime.now().hour;
    final String part = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final String? name = widget.displayName?.split(' ').first;
    return name == null || name.isEmpty ? part : '$part, $name';
  }

  @override
  Widget build(BuildContext context) {
    final TraderDashboardSnapshot? snapshot = _snapshot;
    final bool isMobile = context.uiRes.isMobile;

    return AppPageBlock(
      title: _greeting,
      subtitle: 'Your desk for ${AppTokens.shortDate(DateTime.now())}',
      actions: <Widget>[
        UiButton(
          label: 'Log a trade',
          leadingIcon: Icons.add_rounded,
          size: UiSize.sm,
          onPressed: widget.onOpenJournal,
        ),
        UiButton(
          label: 'Ask the copilot',
          variant: UiVariant.secondary,
          leadingIcon: Icons.auto_awesome_rounded,
          size: UiSize.sm,
          hideLabelOnMobile: true,
          onPressed: widget.onOpenAi,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppFadeIn(
            child: AppStatGridBlock(
              stats: snapshot?.stats ?? const <AppStat>[],
              loading: _loading,
            ),
          ),
          UiGap.v(context.ui.spacing.lg),
          if (snapshot != null)
            AppFadeIn(
              delay: AppMotion.step * 2,
              child: _RiskMeter(
                usedPercent: snapshot.dailyLossUsedPercent,
                openPositions: snapshot.openTrades.length,
                onReview: widget.onOpenPortfolio,
              ),
            ),
          if (snapshot != null) UiGap.v(context.ui.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step * 4,
            child: AppDashboardLayoutBlock(
              main: <Widget>[
                AppEquityCurveBlock(
                  series: snapshot?.equity ?? const <AppSeriesPoint>[],
                ),
                AppRecentTradesBlock(
                  trades: snapshot?.recentTrades ?? const <AppTrade>[],
                  onViewAll: widget.onOpenJournal,
                  onTradeTap: widget.onOpenTrade,
                  limit: isMobile ? 4 : 6,
                ),
                AppPnlCalendarBlock(
                  days: snapshot?.days ?? const <AppDayPnl>[],
                  onDayTap: (AppDayPnl day) => UiToast.show(
                    context,
                    title: AppTokens.shortDate(day.date),
                    message:
                        '${day.trades} trade${day.trades == 1 ? '' : 's'} · ${AppTokens.signedMoney(day.pnl)}',
                    intent: AppTokens.plIntent(day.pnl),
                  ),
                ),
              ],
              side: <Widget>[
                if (snapshot != null && snapshot.openTrades.isNotEmpty)
                  UiCard(
                    title: 'Open positions',
                    subtitle:
                        '${snapshot.openTrades.length} live · tap to review',
                    child: Column(
                      children: <Widget>[
                        for (final AppTrade trade in snapshot.openTrades)
                          Padding(
                            padding: EdgeInsets.only(bottom: context.sp(2)),
                            child: AppTradeCard(
                              trade: trade,
                              dense: true,
                              onTap: () => widget.onOpenTrade?.call(trade),
                            ),
                          ),
                      ],
                    ),
                  ),
                AppPreTradeChecklistBlock(
                  items: snapshot?.checklist ?? const <AppChecklistItem>[],
                  onToggle: (AppChecklistItem item, bool _) =>
                      _toggleChecklistItem(item.id),
                  onConfirm: () => UiToast.show(
                    context,
                    title: 'Checklist cleared',
                    message: 'You are green-lit for the next entry.',
                    intent: UiIntent.success,
                  ),
                ),
                AppMoversRailBlock(
                  tickers: snapshot?.movers ?? const <AppTicker>[],
                  onTickerTap: widget.onOpenTicker,
                ),
                AppAiInsightsBlock(
                  insights: snapshot?.insights ?? const <AppAiInsight>[],
                  loading: _loading,
                  onAsk: (AppAiInsight insight) => widget.onOpenAi?.call(),
                  onGenerate: widget.onOpenAi,
                ),
                AppNewsFeedBlock(
                  items: snapshot?.news ?? const <AppNewsItem>[],
                  onTap: (AppNewsItem item) => UiToast.show(
                    context,
                    title: item.source,
                    message: item.headline,
                    intent: switch (AppTokens.sentimentOf(item.sentimentScore)) {
                      AppSentiment.bullish => UiIntent.success,
                      AppSentiment.bearish => UiIntent.danger,
                      AppSentiment.neutral => UiIntent.neutral,
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact daily-loss budget meter. Reads from the snapshot so the desk risk
/// rule stays a single source of truth.
class _RiskMeter extends StatelessWidget {
  const _RiskMeter({
    required this.usedPercent,
    required this.openPositions,
    this.onReview,
  });

  final double usedPercent;
  final int openPositions;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final UiIntent intent = usedPercent >= 90
        ? UiIntent.danger
        : (usedPercent >= 60 ? UiIntent.warning : UiIntent.success);
    return UiCard(
      title: 'Daily risk budget',
      subtitle:
          '$openPositions open position${openPositions == 1 ? '' : 's'} against today\'s loss cap',
      trailing: UiBadge(
        label: '${AppTokens.percent(usedPercent)} used',
        intent: intent,
      ),
      actions: <Widget>[
        UiButton(
          label: 'Review exposure',
          variant: UiVariant.ghost,
          size: UiSize.sm,
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: onReview,
        ),
      ],
      child: UiProgressBar(value: (usedPercent / 100).clamp(0, 1), intent: intent),
    );
  }
}
