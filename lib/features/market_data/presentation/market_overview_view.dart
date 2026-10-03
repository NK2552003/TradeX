import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../models/market_snapshot.dart';
import 'market_movers_panel.dart';
import 'market_news_widgets.dart';
import 'market_layout.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarketPageHeading(
          title: 'Market overview',
          description:
              'Your research starting point · ${marketSnapshotDate(snapshot.manifest)}',
          action: const UiBadge(
            label: 'Bundled snapshot',
            icon: Icons.schedule,
            variant: UiBadgeVariant.outline,
          ),
        ),
        MarketTwoPanel(
          primary: UiCard(
            title: 'Market pulse',
            subtitle: 'Breadth across the instruments in this snapshot',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  ],
                ),
                UiGap.v(context.ui.spacing.md),
                if (snapshot.instruments.isNotEmpty)
                  UiCategoryBar(
                    segments: [
                      UiCategorySegment(
                        label: 'Advancing',
                        value: advancing.toDouble(),
                        color: context.ui.colors.success,
                      ),
                      UiCategorySegment(
                        label: 'Declining',
                        value: declining.toDouble(),
                        color: context.ui.colors.danger,
                      ),
                      UiCategorySegment(
                        label: 'Unchanged',
                        value: unchanged.toDouble(),
                        color: context.ui.colors.foregroundMuted,
                      ),
                    ],
                  ),
                UiGap.v(context.ui.spacing.lg),
                UiHeader(
                  title: 'Session leaders',
                  actions: [
                    UiButton(
                      label: 'All movers',
                      variant: UiVariant.ghost,
                      onPressed: () => onSection(2),
                    ),
                  ],
                ),
                UiGap.v(context.ui.spacing.sm),
                UiCardGrid(
                  intrinsicHeight: true,
                  desktopColumns: 2,
                  largeColumns: 2,
                  children: [
                    if (snapshot.gainers.isNotEmpty)
                      UiMetricCard(
                        title: 'Top gainer · ${snapshot.gainers.first.symbol}',
                        value:
                            '${snapshot.gainers.first.changePercent.toStringAsFixed(2)}%',
                        isPositive: true,
                        subtitle: snapshot.gainers.first.name,
                        onTap: () => onInstrument(snapshot.gainers.first),
                      ),
                    if (snapshot.losers.isNotEmpty)
                      UiMetricCard(
                        title: 'Top loser · ${snapshot.losers.first.symbol}',
                        value:
                            '${snapshot.losers.first.changePercent.toStringAsFixed(2)}%',
                        isPositive: false,
                        subtitle: snapshot.losers.first.name,
                        onTap: () => onInstrument(snapshot.losers.first),
                      ),
                  ],
                ),
                UiGap.v(context.ui.spacing.lg),
                UiHeader(
                  title: 'Most active',
                  subtitle: 'Ranked by reported trading volume',
                  actions: [
                    UiButton(
                      label: 'Explore',
                      variant: UiVariant.ghost,
                      onPressed: () => onSection(3),
                    ),
                  ],
                ),
                for (final quote in snapshot.mostActive.take(8)) ...[
                  MarketQuoteRow(
                    quote: quote,
                    onTap: () => onInstrument(quote),
                  ),
                  const UiDivider(spacing: 0),
                ],
                if (snapshot.instruments.isEmpty)
                  const UiEmptyState(title: 'No quotes in this snapshot'),
              ],
            ),
          ),
          secondary: UiCard(
            title: 'Research briefing',
            subtitle: 'Headlines and the scope of your data',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snapshot.articles.isNotEmpty)
                  MarketNewsCard(
                    article: snapshot.articles.first,
                    snapshot: snapshot,
                    onTap: () => onArticle(snapshot.articles.first),
                  ),
                for (final article in snapshot.articles.skip(1).take(2))
                  MarketNewsCard(
                    article: article,
                    snapshot: snapshot,
                    textOnly: true,
                    onTap: () => onArticle(article),
                  ),
                UiButton(
                  label: 'Open newsroom',
                  trailingIcon: Icons.arrow_forward,
                  variant: UiVariant.outline,
                  onPressed: () => onSection(1),
                ),
                const UiDivider(),
                Text('Research coverage', style: context.uiText.subheading),
                UiGap.v(context.ui.spacing.sm),
                UiStatStrip(
                  stats: [
                    UiStat(
                      label: 'Priced instruments',
                      value: '${snapshot.instruments.length}',
                    ),
                    UiStat(
                      label: 'Market screens',
                      value: '${snapshot.screeners.length}',
                    ),
                    UiStat(
                      label: 'News articles',
                      value: '${snapshot.articles.length}',
                    ),
                    UiStat(
                      label: 'Full company profiles',
                      value: '${snapshot.manifest['detail_count'] ?? 0}',
                    ),
                  ],
                ),
                UiGap.v(context.ui.spacing.md),
                UiButton(
                  label: 'Explore screeners',
                  leadingIcon: Icons.filter_alt_outlined,
                  variant: UiVariant.soft,
                  onPressed: () => onSection(4),
                ),
                UiGap.v(context.ui.spacing.sm),
                UiButton(
                  label: 'Data coverage',
                  leadingIcon: Icons.dataset_outlined,
                  variant: UiVariant.ghost,
                  onPressed: () => onSection(5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
