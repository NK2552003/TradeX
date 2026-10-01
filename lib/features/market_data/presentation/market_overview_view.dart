import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../models/market_snapshot.dart';
import 'market_movers_panel.dart';
import 'market_news_widgets.dart';

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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Market overview', style: context.uiText.heading),
      UiGap.v(context.ui.spacing.sm),
      Text(
        'Start with market movers, explore a screen, then open a company for its chart, research and news.',
        style: context.uiText.body,
      ),
      UiGap.v(context.ui.spacing.xs),
      Text(
        'Bundled market snapshot · ${marketSnapshotDate(snapshot.manifest)}',
        style: context.uiText.caption,
      ),
      UiGap.v(context.ui.spacing.md),
      UiCardGrid(
        intrinsicHeight: true,
        desktopColumns: 4,
        largeColumns: 4,
        children: [
          UiMetricCard(
            title: 'Priced instruments',
            value: '${snapshot.instruments.length}',
            subtitle: 'US and India',
            onTap: () => onSection(3),
          ),
          UiMetricCard(
            title: 'Market screens',
            value: '${snapshot.screeners.length}',
            subtitle: 'Stocks, funds, crypto & indices',
            onTap: () => onSection(4),
          ),
          UiMetricCard(
            title: 'News articles',
            value: '${snapshot.articles.length}',
            subtitle: '${snapshot.topics.length} research topics',
            onTap: () => onSection(1),
          ),
          UiMetricCard(
            title: 'Full company profiles',
            value: '${snapshot.manifest['detail_count'] ?? 0}',
            subtitle: 'See detailed coverage',
            onTap: () => onSection(5),
          ),
        ],
      ),
      UiGap.v(context.ui.spacing.lg),
      UiCardGrid(
        intrinsicHeight: true,
        desktopColumns: 3,
        largeColumns: 3,
        children: [
          MarketMoversList(
            title: 'Top gainers',
            quotes: snapshot.gainers,
            limit: 5,
            onTap: onInstrument,
          ),
          MarketMoversList(
            title: 'Top losers',
            quotes: snapshot.losers,
            limit: 5,
            onTap: onInstrument,
          ),
          MarketMoversList(
            title: 'Most active',
            quotes: snapshot.mostActive,
            limit: 5,
            onTap: onInstrument,
          ),
        ],
      ),
      UiGap.v(context.ui.spacing.lg),
      UiCard(
        title: 'Explore global markets',
        child: Wrap(
          spacing: context.sp(context.ui.spacing.sm),
          runSpacing: context.sp(context.ui.spacing.sm),
          children: [
            UiButton(
              label: 'All screeners',
              variant: UiVariant.outline,
              leadingIcon: Icons.filter_alt_outlined,
              onPressed: () => onSection(4),
            ),
            UiButton(
              label: 'Instrument directory',
              variant: UiVariant.outline,
              leadingIcon: Icons.search,
              onPressed: () => onSection(3),
            ),
            UiButton(
              label: 'Data coverage',
              variant: UiVariant.ghost,
              onPressed: () => onSection(5),
            ),
          ],
        ),
      ),
      if (snapshot.articles.isNotEmpty) ...[
        UiGap.v(context.ui.spacing.lg),
        Text('Latest market story', style: context.uiText.heading),
        MarketNewsCard(
          article: snapshot.articles.first,
          snapshot: snapshot,
          featured: true,
          onTap: () => onArticle(snapshot.articles.first),
        ),
      ],
    ],
  );
}
