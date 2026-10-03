import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../models/market_snapshot.dart';
import 'market_instrument_view.dart' show marketFieldLabel;
import 'market_movers_panel.dart';
import 'market_layout.dart';

String topicDisplayLabel(String key) => switch (key) {
  'stock_market_general' => 'Markets & Economy',
  'magnificent_seven' => 'Tech & AI',
  'banks_and_financials' => 'Banks & Financials',
  'enterprise_cloud' => 'Enterprise Cloud',
  'pharma_and_biotech' => 'Pharma & Biotech',
  'clean_energy' => 'Clean Energy',
  'aerospace_and_defense' => 'Aerospace & Defense',
  'oil_and_gas' => 'Oil & Gas',
  'cybersecurity' => 'Cybersecurity',
  'housing' => 'Housing',
  'crypto' => 'Crypto',
  _ => marketFieldLabel(key),
};

class MarketArticleMeta extends StatelessWidget {
  const MarketArticleMeta({
    super.key,
    required this.article,
    required this.snapshot,
    this.onInstrument,
  });
  final MarketArticle article;
  final MarketSnapshot snapshot;
  final ValueChanged<MarketInstrument>? onInstrument;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: context.sp(context.ui.spacing.xs),
    runSpacing: context.sp(context.ui.spacing.xs),
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        article.publisher.isEmpty ? 'Source unavailable' : article.publisher,
        style: context.uiText.caption,
      ),
      if (article.publishedAt != null)
        Text(
          AppTokens.relativeTime(article.publishedAt!),
          style: context.uiText.caption,
        ),
      if (article.isVideo)
        const UiBadge(label: 'Video', icon: Icons.play_circle_outline),
      for (final symbol in article.tickers.take(3))
        Builder(
          builder: (context) {
            final quote = snapshot.instruments
                .where((q) => q.symbol == symbol)
                .firstOrNull;
            return onInstrument != null && quote != null
                ? UiButton(
                    label: symbol,
                    size: UiSize.xs,
                    variant: UiVariant.soft,
                    onPressed: () => onInstrument!(quote),
                  )
                : UiBadge(
                    label: symbol,
                    size: UiSize.xs,
                    variant: UiBadgeVariant.outline,
                  );
          },
        ),
    ],
  );
}

class MarketNewsCard extends StatelessWidget {
  const MarketNewsCard({
    super.key,
    required this.article,
    required this.snapshot,
    required this.onTap,
    this.featured = false,
    this.row = false,
    this.textOnly = false,
    this.onInstrument,
  });
  final MarketArticle article;
  final MarketSnapshot snapshot;
  final VoidCallback onTap;
  final bool featured, row, textOnly;
  final ValueChanged<MarketInstrument>? onInstrument;

  Widget _image() => AspectRatio(
    aspectRatio: 16 / 9,
    child: UiRemoteImage(
      url: article.thumbnailUrl,
      semanticLabel: article.title,
    ),
  );
  Widget _copy(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        article.title,
        maxLines: featured ? null : 3,
        overflow: featured ? null : TextOverflow.ellipsis,
        style: featured ? context.uiText.heading : context.uiText.bodyStrong,
      ),
      UiGap.v(context.ui.spacing.sm),
      MarketArticleMeta(
        article: article,
        snapshot: snapshot,
        onInstrument: onInstrument,
      ),
      if (featured && article.summary.isNotEmpty) ...[
        UiGap.v(context.ui.spacing.md),
        Text(
          article.summary,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: context.uiText.body,
        ),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) => UiCard(
    onTap: onTap,
    hoverLift: false,
    variant: featured ? UiCardVariant.surface : UiCardVariant.ghost,
    padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
    child: LayoutBuilder(
      builder: (context, box) {
        if (textOnly) return _copy(context);
        if (row && box.maxWidth >= 340) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _copy(context)),
              UiGap.h(context.ui.spacing.md),
              Expanded(child: _image()),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (featured || !row) ...[_image(), UiGap.v(context.ui.spacing.md)],
            _copy(context),
          ],
        );
      },
    ),
  );
}

class MarketNewsView extends StatelessWidget {
  const MarketNewsView({
    super.key,
    required this.snapshot,
    required this.onArticle,
    this.limit = 20,
    this.onMore,
    this.onInstrument,
    this.onTopicSelected,
  });
  final MarketSnapshot snapshot;
  final ValueChanged<MarketArticle> onArticle;
  final int limit;
  final VoidCallback? onMore;
  final ValueChanged<MarketInstrument>? onInstrument;
  final ValueChanged<String>? onTopicSelected;
  @override
  Widget build(BuildContext context) {
    final articles = snapshot.articles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MarketPageHeading(
          title: 'Market newsroom',
          description:
              'Headlines, company developments and research themes in one place.',
        ),
        MarketTwoPanel(
          primary: UiCard(
            title: 'The briefing',
            subtitle: '${articles.length} matching stories',
            padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (articles.isEmpty)
                  const UiEmptyState(
                    title: 'No articles available',
                    message: 'Try another topic or search term.',
                  ),
                if (articles.isNotEmpty)
                  MarketNewsCard(
                    article: articles.first,
                    snapshot: snapshot,
                    featured: true,
                    onInstrument: onInstrument,
                    onTap: () => onArticle(articles.first),
                  ),
                for (final article in articles.skip(1).take(limit - 1)) ...[
                  const UiDivider(),
                  MarketNewsCard(
                    article: article,
                    snapshot: snapshot,
                    row: true,
                    onInstrument: onInstrument,
                    onTap: () => onArticle(article),
                  ),
                ],
                if (articles.length > limit)
                  UiButton(
                    label: 'More stories',
                    variant: UiVariant.outline,
                    onPressed: onMore,
                  ),
              ],
            ),
          ),
          secondary: UiCard(
            title: 'Research radar',
            subtitle: 'Topics and companies behind the headlines',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Explore topics', style: context.uiText.bodyStrong),
                UiGap.v(context.ui.spacing.sm),
                for (final topic in snapshot.topics.entries)
                  UiButton(
                    label:
                        '${topicDisplayLabel(topic.key)} · ${topic.value.length}',
                    variant: UiVariant.ghost,
                    onPressed: onTopicSelected == null
                        ? null
                        : () => onTopicSelected!(topic.key),
                  ),
                const UiDivider(),
                Text('Companies in focus', style: context.uiText.bodyStrong),
                for (final quote in snapshot.trending.take(5))
                  MarketQuoteRow(
                    quote: quote,
                    onTap: () => onInstrument?.call(quote),
                  ),
                if (snapshot.videos.isNotEmpty) ...[
                  const UiDivider(),
                  Text('Watch & listen', style: context.uiText.bodyStrong),
                  for (final article in snapshot.videos.take(3))
                    MarketNewsCard(
                      article: article,
                      snapshot: snapshot,
                      textOnly: true,
                      onTap: () => onArticle(article),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MarketArticleView extends StatelessWidget {
  const MarketArticleView({
    super.key,
    required this.article,
    required this.snapshot,
    this.onArticle,
    this.onInstrument,
  });
  final MarketArticle article;
  final MarketSnapshot snapshot;
  final ValueChanged<MarketArticle>? onArticle;
  final ValueChanged<MarketInstrument>? onInstrument;
  Future<void> _source(BuildContext context) async {
    final uri = Uri.tryParse(article.link);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && context.mounted) {
      UiToast.show(
        context,
        title: 'Could not open source',
        intent: UiIntent.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) => MarketTwoPanel(
    primary: UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const UiBadge(
            label: 'News & analysis',
            variant: UiBadgeVariant.outline,
          ),
          UiGap.v(context.ui.spacing.md),
          Text(article.title, style: context.uiText.heading),
          UiGap.v(context.ui.spacing.md),
          MarketArticleMeta(
            article: article,
            snapshot: snapshot,
            onInstrument: onInstrument,
          ),
          UiGap.v(context.ui.spacing.lg),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: UiRemoteImage(
              url: article.thumbnailUrl,
              semanticLabel: article.title,
            ),
          ),
          UiGap.v(context.ui.spacing.lg),
          Text(
            article.summary.isEmpty
                ? 'Read the full report at the original source.'
                : article.summary,
            style: context.uiText.body,
          ),
          UiGap.v(context.ui.spacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: UiButton(
              label: 'Read original article',
              leadingIcon: Icons.open_in_new,
              onPressed: article.link.isEmpty ? null : () => _source(context),
            ),
          ),
        ],
      ),
    ),
    secondary: UiCard(
      title: 'Story context',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Related instruments', style: context.uiText.bodyStrong),
          for (final quote in snapshot.instruments.where(
            (q) => article.tickers.contains(q.symbol),
          ))
            MarketQuoteRow(
              quote: quote,
              onTap: () => onInstrument?.call(quote),
            ),
          if (!snapshot.instruments.any(
            (q) => article.tickers.contains(q.symbol),
          ))
            Text(
              'No linked quotes in this snapshot.',
              style: context.uiText.caption,
            ),
          const UiDivider(),
          Text('More stories', style: context.uiText.subheading),
          for (final related
              in snapshot.articles.where((a) => a.link != article.link).take(5))
            MarketNewsCard(
              article: related,
              snapshot: snapshot,
              textOnly: true,
              onTap: () => onArticle?.call(related),
            ),
        ],
      ),
    ),
  );
}
