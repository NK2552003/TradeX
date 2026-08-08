import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../cards/community_cards.dart';
import '../cards/watchlist_cards.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Watchlist grid — responsive columns, empty and loading states.
class AppWatchlistBlock extends StatelessWidget {
  const AppWatchlistBlock({
    super.key,
    required this.tickers,
    this.onTickerTap,
    this.onFavorite,
    this.onAdd,
    this.loading = false,
  });

  final List<AppTicker> tickers;
  final ValueChanged<AppTicker>? onTickerTap;
  final ValueChanged<AppTicker>? onFavorite;
  final VoidCallback? onAdd;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return UiCardGrid(
        children: List<Widget>.generate(
          6,
          (_) => UiCard(child: UiSkeleton(height: context.sz(96))),
        ),
      );
    }
    if (tickers.isEmpty) {
      return UiEmptyState(
        title: 'Watchlist is empty',
        message: 'Add symbols to track prices, alerts and sentiment.',
        icon: Icons.visibility_outlined,
        action: UiButton(
          label: 'Add symbol',
          leadingIcon: Icons.add,
          expandOnMobile: false,
          onPressed: onAdd,
        ),
      );
    }
    return UiCardGrid(
      childAspectRatio: context.uiRes.pick<double>(
        mobile: 1.7,
        tablet: 1.45,
        desktop: 1.5,
      ),
      children: <Widget>[
        for (int i = 0; i < tickers.length; i++)
          AppFadeIn(
            delay: Duration(milliseconds: 40 * i),
            child: AppTickerCard(
              ticker: tickers[i],
              onTap: onTickerTap == null ? null : () => onTickerTap!(tickers[i]),
              onFavorite:
                  onFavorite == null ? null : () => onFavorite!(tickers[i]),
            ),
          ),
      ],
    );
  }
}

/// Sector / symbol heatmap grid.
class AppHeatmapBlock extends StatelessWidget {
  const AppHeatmapBlock({
    super.key,
    required this.entries,
    this.title = 'Market heatmap',
    this.onTap,
  });

  final List<AppTicker> entries;
  final String title;
  final ValueChanged<AppTicker>? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final int cols =
        context.uiRes.columns(mobile: 2, tablet: 3, desktop: 4, large: 6);
    return UiCard(
      title: title,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: entries.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: context.sp(theme.spacing.sm),
          crossAxisSpacing: context.sp(theme.spacing.sm),
          childAspectRatio: 1.5,
        ),
        itemBuilder: (BuildContext _, int i) => AppHeatTile(
          label: entries[i].symbol,
          changePercent: entries[i].changePercent,
          onTap: onTap == null ? null : () => onTap!(entries[i]),
        ),
      ),
    );
  }
}

/// Price alert manager.
class AppAlertsBlock extends StatelessWidget {
  const AppAlertsBlock({
    super.key,
    required this.alerts,
    this.onToggle,
    this.onDelete,
    this.onCreate,
  });

  final List<AppPriceAlert> alerts;
  final void Function(AppPriceAlert alert, bool active)? onToggle;
  final ValueChanged<AppPriceAlert>? onDelete;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Price alerts',
      trailing: UiButton(
        label: 'New',
        leadingIcon: Icons.add,
        size: UiSize.sm,
        variant: UiVariant.outline,
        expandOnMobile: false,
        onPressed: onCreate,
      ),
      child: alerts.isEmpty
          ? const UiEmptyState(
              title: 'No alerts',
              message: 'Get notified when price crosses your levels.',
              icon: Icons.notifications_active_outlined,
            )
          : Column(
              children: <Widget>[
                for (int i = 0; i < alerts.length; i++)
                  Padding(
                    padding:
                        EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                    child: AppPriceAlertCard(
                      alert: alerts[i],
                      onToggle: onToggle == null
                          ? null
                          : (bool v) => onToggle!(alerts[i], v),
                      onDelete:
                          onDelete == null ? null : () => onDelete!(alerts[i]),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Market news feed with sentiment filter.
class AppNewsFeedBlock extends StatelessWidget {
  const AppNewsFeedBlock({
    super.key,
    required this.items,
    this.title = 'Market news',
    this.onTap,
  });

  final List<AppNewsItem> items;
  final String title;
  final ValueChanged<AppNewsItem>? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: context.uiText.subheading),
        SizedBox(height: context.sp(theme.spacing.md)),
        if (items.isEmpty)
          const UiEmptyState(
            title: 'No headlines',
            icon: Icons.newspaper_outlined,
          )
        else
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: AppNewsCard(
                item: items[i],
                onTap: onTap == null ? null : () => onTap!(items[i]),
              ),
            ),
      ],
    );
  }
}

/// Aggregate market sentiment gauge with bullish/neutral/bearish split.
class AppSentimentBlock extends StatelessWidget {
  const AppSentimentBlock({
    super.key,
    required this.bullish,
    required this.neutral,
    required this.bearish,
    this.title = 'Crowd sentiment',
  });

  final double bullish;
  final double neutral;
  final double bearish;
  final String title;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double total = bullish + neutral + bearish;
    final double score = total == 0 ? 0 : (bullish - bearish) / total;
    return UiCard(
      title: title,
      trailing: UiBadge(
        label: AppTokens.sentimentLabel(score),
        intent: AppTokens.plIntent(score),
        filled: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UiCategoryBar(
            marker: ((score + 1) / 2).clamp(0, 1),
            segments: <UiCategorySegment>[
              UiCategorySegment(
                  value: bearish, label: 'Bearish', color: theme.colors.bearish),
              UiCategorySegment(
                  value: neutral,
                  label: 'Neutral',
                  color: theme.colors.foregroundSubtle),
              UiCategorySegment(
                  value: bullish, label: 'Bullish', color: theme.colors.bullish),
            ],
          ),
        ],
      ),
    );
  }
}

/// AI insights rail / list.
class AppAiInsightsBlock extends StatelessWidget {
  const AppAiInsightsBlock({
    super.key,
    required this.insights,
    this.title = 'AI insights',
    this.onTap,
    this.loading = false,
  });

  final List<AppAiInsight> insights;
  final String title;
  final ValueChanged<AppAiInsight>? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.auto_awesome,
                size: context.sz(theme.sizes.iconSm),
                color: theme.colors.primary),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Text(title, style: context.uiText.subheading),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        if (loading)
          UiCard(child: UiSkeleton(height: context.sz(72)))
        else
          for (int i = 0; i < insights.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: AppAiInsightCard(
                insight: insights[i],
                onTap: onTap == null ? null : () => onTap!(insights[i]),
              ),
            ),
      ],
    );
  }
}

/// Symbol detail header: price, change, range and timeframe switcher.
class AppSymbolHeaderBlock extends StatelessWidget {
  const AppSymbolHeaderBlock({
    super.key,
    required this.ticker,
    required this.timeframe,
    this.timeframes = const <String>['1D', '1W', '1M', '1Y'],
    this.onTimeframeChanged,
    this.onAddToWatchlist,
  });

  final AppTicker ticker;
  final String timeframe;
  final List<String> timeframes;
  final ValueChanged<String>? onTimeframeChanged;
  final VoidCallback? onAddToWatchlist;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(ticker.symbol, style: context.uiText.heading),
                    Text(
                      ticker.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption
                          .copyWith(color: theme.colors.foregroundMuted),
                    ),
                  ],
                ),
              ),
              UiIconButton(
                icon: ticker.isFavorite ? Icons.star : Icons.star_border,
                tooltip: 'Watchlist',
                onPressed: onAddToWatchlist,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              AppCountUp(
                value: ticker.price,
                formatter: (num v) =>
                    AppTokens.money(v, symbol: ticker.currencySymbol),
                style: context.uiText.display,
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              UiBadge.delta(ticker.changePercent, size: UiSize.md),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiToggleGroup<String>(
            value: timeframe,
            expand: context.uiRes.isMobile,
            onChanged: onTimeframeChanged,
            options: <UiToggleOption<String>>[
              for (final String t in timeframes)
                UiToggleOption<String>(value: t, label: t),
            ],
          ),
        ],
      ),
    );
  }
}
