import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../models/market_snapshot.dart';
import 'market_movers_panel.dart';
import 'market_news_widgets.dart';
import 'market_layout.dart';
import 'market_visuals.dart';

String marketSnapshotDate(Map<String, dynamic> manifest) {
  final date = DateTime.tryParse('${manifest['generated_at']}')?.toLocal();
  if (date == null) return 'Snapshot time unavailable';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class MarketOverviewView extends StatelessWidget {
  const MarketOverviewView({
    super.key,
    required this.snapshot,
    required this.onInstrument,
    required this.onArticle,
    required this.onSection,
  });
  final MarketSnapshot snapshot;
  final ValueChanged<MarketInstrument> onInstrument;
  final ValueChanged<MarketArticle> onArticle;
  final ValueChanged<int> onSection;

  @override
  Widget build(BuildContext context) {
    final advancing = snapshot.instruments
        .where((q) => q.changePercent > 0)
        .length;
    final declining = snapshot.instruments
        .where((q) => q.changePercent < 0)
        .length;
    final unchanged = snapshot.instruments.length - advancing - declining;
    final total = snapshot.instruments.length;
    final exportedQuotes = (snapshot.manifest['quote_count'] as num? ?? total);
    final breadthRatio = total == 0 ? 0.0 : advancing / total;
    final isRisingMarket = advancing > declining;
    final breadthIntent = advancing > declining
        ? UiIntent.success
        : (declining > advancing ? UiIntent.danger : UiIntent.neutral);
    final sectors = <String, num>{};
    final markets = <String, num>{};
    for (final q in snapshot.instruments) {
      markets.update(
        q.market.isEmpty ? 'Other' : q.market,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
      final sector = '${q.raw['sector'] ?? ''}'.trim();
      if (sector.isNotEmpty) {
        sectors.update(sector, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    return MarketTwoPanel(
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Market Breadth Hero Card
          UiCard(
            accentColor: isRisingMarket
                ? context.ui.colors.success
                : context.ui.colors.danger,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.monitor_heart_outlined,
                                size: context.sz(16),
                                color: context.ui.colors.foregroundMuted,
                              ),
                              UiGap.h(context.ui.spacing.xs),
                              Flexible(
                                child: Text(
                                  'Market Pulse',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.uiText.caption.copyWith(
                                    color: context.ui.colors.foregroundMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          UiGap.v(context.ui.spacing.xs),
                          Text(
                            isRisingMarket
                                ? 'Broadly Rising'
                                : (declining > advancing
                                      ? 'Broadly Declining'
                                      : 'Mixed Session'),
                            style: context.uiText.heading,
                          ),
                          UiGap.v(context.ui.spacing.xs),
                          Text(
                            '$total instruments tracked · ${marketSnapshotDate(snapshot.manifest)}',
                            style: context.uiText.caption.copyWith(
                              color: context.ui.colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    UiBadge(
                      label: isRisingMarket
                          ? 'Risk On'
                          : (declining > advancing ? 'Risk Off' : 'Neutral'),
                      intent: breadthIntent,
                      variant: UiBadgeVariant.soft,
                    ),
                  ],
                ),
                UiGap.v(context.ui.spacing.lg),
                UiStatStrip(
                  stats: [
                    UiStat(
                      label: 'Advancing',
                      value: '$advancing',
                      intent: UiIntent.success,
                    ),
                    UiStat(
                      label: 'Declining',
                      value: '$declining',
                      intent: UiIntent.danger,
                    ),
                    UiStat(label: 'Unchanged', value: '$unchanged'),
                    UiStat(
                      label: 'A/D Ratio',
                      value: declining == 0
                          ? '∞'
                          : (advancing / declining).toStringAsFixed(2),
                    ),
                  ],
                ),
                if (snapshot.instruments.isNotEmpty) ...[
                  UiGap.v(context.ui.spacing.md),
                  UiProgressBar(value: breadthRatio, intent: breadthIntent),
                  UiGap.v(context.ui.spacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${(breadthRatio * 100).toStringAsFixed(0)}% advancing',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.caption.copyWith(
                            color: context.ui.colors.success,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${((declining / (total == 0 ? 1 : total)) * 100).toStringAsFixed(0)}% declining',
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.caption.copyWith(
                            color: context.ui.colors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          UiGap.v(context.ui.spacing.md),

          MarketChangeDistribution(instruments: snapshot.instruments),
          UiGap.v(context.ui.spacing.md),

          // Session Leaders — Top Gainer & Loser
          if (snapshot.gainers.isNotEmpty || snapshot.losers.isNotEmpty) ...[
            UiCard(
              title: 'Session leaders',
              subtitle: 'Biggest movers this session',
              actions: [
                UiButton(
                  label: 'All movers',
                  variant: UiVariant.ghost,
                  size: UiSize.sm,
                  trailingIcon: Icons.chevron_right,
                  onPressed: () => onSection(2),
                ),
              ],
              child: LayoutBuilder(
                builder: (context, c) {
                  Widget leaderCard(MarketInstrument q, bool isGainer) {
                    final color = isGainer
                        ? context.ui.colors.success
                        : context.ui.colors.danger;
                    final intent = isGainer
                        ? UiIntent.success
                        : UiIntent.danger;
                    return UiCard(
                      variant: UiCardVariant.ghost,
                      onTap: () => onInstrument(q),
                      padding: EdgeInsets.all(
                        context.sp(context.ui.spacing.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              UiBadge(
                                label: isGainer ? '▲ Gainer' : '▼ Loser',
                                intent: intent,
                                variant: UiBadgeVariant.soft,
                                size: UiSize.xs,
                              ),
                              const Spacer(),
                              if (q.spark.isNotEmpty)
                                SizedBox(
                                  width: context.sz(60),
                                  height: context.sz(28),
                                  child: UiSparkChart(
                                    data: q.spark,
                                    color: color,
                                  ),
                                ),
                            ],
                          ),
                          UiGap.v(context.ui.spacing.sm),
                          Text(q.symbol, style: context.uiText.title),
                          Text(
                            q.name,
                            style: context.uiText.caption.copyWith(
                              color: context.ui.colors.foregroundMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          UiGap.v(context.ui.spacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${q.currency} ${q.price.toStringAsFixed(2)}',
                                style: context.uiText.bodyStrong,
                              ),
                              UiBadge(
                                label:
                                    '${isGainer ? '+' : ''}${q.changePercent.toStringAsFixed(2)}%',
                                intent: intent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  final gainer = snapshot.gainers.firstOrNull;
                  final loser = snapshot.losers.firstOrNull;
                  if (c.maxWidth < 500) {
                    return Column(
                      children: [
                        if (gainer != null) leaderCard(gainer, true),
                        if (gainer != null && loser != null)
                          UiGap.v(context.ui.spacing.sm),
                        if (loser != null) leaderCard(loser, false),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (gainer != null)
                        Expanded(child: leaderCard(gainer, true)),
                      if (gainer != null && loser != null)
                        UiGap.h(context.ui.spacing.sm),
                      if (loser != null)
                        Expanded(child: leaderCard(loser, false)),
                    ],
                  );
                },
              ),
            ),
            UiGap.v(context.ui.spacing.md),
          ],

          // Most Active with Sparklines
          UiCard(
            title: 'Most active',
            subtitle: 'Ranked by trading volume',
            actions: [
              UiButton(
                label: 'Explore all',
                variant: UiVariant.ghost,
                size: UiSize.sm,
                trailingIcon: Icons.chevron_right,
                onPressed: () => onSection(3),
              ),
            ],
            padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snapshot.mostActive.isEmpty)
                  const UiEmptyState(title: 'No quotes in this snapshot'),
                for (final quote in snapshot.mostActive.take(8)) ...[
                  _ActiveQuoteRow(
                    quote: quote,
                    onTap: () => onInstrument(quote),
                  ),
                  const UiDivider(spacing: 0),
                ],
              ],
            ),
          ),
        ],
      ),
      secondary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MarketDistributionCard(
            title: 'Market coverage',
            subtitle: 'Quoted instruments by market',
            values: markets,
          ),
          UiGap.v(context.ui.spacing.md),
          if (sectors.isNotEmpty) ...[
            MarketDistributionCard(
              title: 'Profiled sectors',
              subtitle:
                  '${sectors.values.fold<num>(0, (a, b) => a + b)} instruments with a sector label',
              values: sectors,
            ),
            UiGap.v(context.ui.spacing.md),
          ],
          // Top 3 Gainers & Losers mini cards
          UiCard(
            title: 'Quick movers',
            subtitle: 'Top 3 gainers and losers',
            actions: [
              UiButton(
                label: 'All',
                variant: UiVariant.ghost,
                size: UiSize.sm,
                onPressed: () => onSection(2),
              ),
            ],
            padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(context.ui.spacing.sm),
                    vertical: context.sp(context.ui.spacing.xs),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: context.sz(14),
                        color: context.ui.colors.success,
                      ),
                      UiGap.h(context.ui.spacing.xs),
                      Text(
                        'Gainers',
                        style: context.uiText.caption.copyWith(
                          color: context.ui.colors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final q in snapshot.gainers.take(3)) ...[
                  MarketQuoteRow(quote: q, onTap: () => onInstrument(q)),
                  const UiDivider(spacing: 0),
                ],
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(context.ui.spacing.sm),
                    vertical: context.sp(context.ui.spacing.xs),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_down,
                        size: context.sz(14),
                        color: context.ui.colors.danger,
                      ),
                      UiGap.h(context.ui.spacing.xs),
                      Text(
                        'Losers',
                        style: context.uiText.caption.copyWith(
                          color: context.ui.colors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final q in snapshot.losers.take(3)) ...[
                  MarketQuoteRow(quote: q, onTap: () => onInstrument(q)),
                  const UiDivider(spacing: 0),
                ],
              ],
            ),
          ),
          UiGap.v(context.ui.spacing.md),

          // Research Briefing
          UiCard(
            title: 'Research briefing',
            subtitle: 'Latest headlines',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snapshot.articles.isEmpty)
                  const UiEmptyState(title: 'No articles available'),
                if (snapshot.articles.isNotEmpty)
                  MarketNewsCard(
                    article: snapshot.articles.first,
                    snapshot: snapshot,
                    onTap: () => onArticle(snapshot.articles.first),
                  ),
                for (final article in snapshot.articles.skip(1).take(2)) ...[
                  const UiDivider(),
                  MarketNewsCard(
                    article: article,
                    snapshot: snapshot,
                    textOnly: true,
                    onTap: () => onArticle(article),
                  ),
                ],
                UiGap.v(context.ui.spacing.sm),
                UiButton(
                  label: 'Open newsroom',
                  trailingIcon: Icons.arrow_forward,
                  variant: UiVariant.outline,
                  onPressed: () => onSection(1),
                ),
              ],
            ),
          ),
          UiGap.v(context.ui.spacing.md),

          // Snapshot Coverage
          UiCard(
            title: 'Snapshot coverage',
            subtitle: 'What this snapshot includes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiStatStrip(
                  stats: [
                    UiStat(
                      label: 'Quotes',
                      value: '${snapshot.instruments.length}',
                    ),
                    UiStat(
                      label: 'Screeners',
                      value: '${snapshot.screeners.length}',
                    ),
                    UiStat(
                      label: 'Stories',
                      value: '${snapshot.articles.length}',
                    ),
                    UiStat(
                      label: 'Profiles',
                      value: '${snapshot.manifest['detail_count'] ?? 0}',
                    ),
                  ],
                ),
                UiGap.v(context.ui.spacing.md),
                UiProgressBar(
                  value: exportedQuotes == 0
                      ? 0
                      : ((snapshot.manifest['history_count'] as num? ?? 0) /
                                exportedQuotes)
                            .clamp(0.0, 1.0),
                  label: 'Quotes with packaged history',
                ),
                UiGap.v(context.ui.spacing.sm),
                UiProgressBar(
                  value: exportedQuotes == 0
                      ? 0
                      : ((snapshot.manifest['detail_count'] as num? ?? 0) /
                                exportedQuotes)
                            .clamp(0.0, 1.0),
                  label: 'Quotes with full profiles',
                ),
                const UiDivider(),
                Row(
                  children: [
                    Expanded(
                      child: UiButton(
                        label: 'Screeners',
                        leadingIcon: Icons.filter_alt_outlined,
                        variant: UiVariant.soft,
                        onPressed: () => onSection(4),
                      ),
                    ),
                    UiGap.h(context.ui.spacing.sm),
                    Expanded(
                      child: UiButton(
                        label: 'Coverage',
                        leadingIcon: Icons.dataset_outlined,
                        variant: UiVariant.ghost,
                        onPressed: () => onSection(5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveQuoteRow extends StatelessWidget {
  const _ActiveQuoteRow({required this.quote, required this.onTap});
  final MarketInstrument quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final intent = AppTokens.plIntent(quote.changePercent);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(context.ui.spacing.sm),
          vertical: context.sp(context.ui.spacing.md),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quote.symbol, style: context.uiText.bodyStrong),
                  Text(
                    quote.name,
                    style: context.uiText.caption.copyWith(
                      color: context.ui.colors.foregroundMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (quote.spark.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(context.ui.spacing.sm),
                ),
                child: SizedBox(
                  width: context.sz(56),
                  height: context.sz(24),
                  child: UiSparkChart(
                    data: quote.spark,
                    color: intent.color(context),
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${quote.currency} ${quote.price.toStringAsFixed(2)}',
                  style: context.uiText.body,
                ),
                UiBadge(
                  label: AppTokens.signedPercent(quote.changePercent),
                  intent: intent,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
