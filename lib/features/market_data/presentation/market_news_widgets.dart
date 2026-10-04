import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../models/market_snapshot.dart';
import 'market_instrument_view.dart' show marketFieldLabel;
import 'market_movers_panel.dart';
import 'market_layout.dart';
import 'market_visuals.dart';

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
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            size: context.sz(12),
            color: context.ui.colors.foregroundMuted,
          ),
          UiGap.h(context.ui.spacing.xs),
          Text(
            article.publishedAt != null
                ? AppTokens.relativeTime(article.publishedAt!)
                : 'Unknown time',
            style: context.uiText.caption.copyWith(
              color: context.ui.colors.foregroundMuted,
            ),
          ),
        ],
      ),
      if (article.publisher.isNotEmpty)
        UiBadge(
          label: article.publisher.length > 22
              ? '${article.publisher.substring(0, 21)}…'
              : article.publisher,
          variant: UiBadgeVariant.outline,
          size: UiSize.xs,
        ),
      if (article.isVideo)
        const UiBadge(
          label: 'Video',
          icon: Icons.play_circle_outline,
          size: UiSize.xs,
        ),
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
                    variant: UiBadgeVariant.soft,
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
    this.isLiked = false,
    this.onLike,
  });
  final MarketArticle article;
  final MarketSnapshot snapshot;
  final VoidCallback onTap;
  final bool featured, row, textOnly;
  final ValueChanged<MarketInstrument>? onInstrument;
  final bool isLiked;
  final VoidCallback? onLike;

  Widget _image(BuildContext context) => ClipRRect(
    borderRadius: context.radius(context.ui.radii.md),
    child: AspectRatio(
      aspectRatio: featured ? 16 / 9 : (row ? 4 / 3 : 16 / 9),
      child: UiRemoteImage(
        url: article.thumbnailUrl,
        semanticLabel: article.title,
      ),
    ),
  );

  Widget _copy(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (featured && article.publisher.isNotEmpty) ...[
        Row(
          children: [
            Icon(
              Icons.newspaper_outlined,
              size: context.sz(14),
              color: context.ui.colors.primary,
            ),
            UiGap.h(context.ui.spacing.xs),
            Expanded(
              child: Text(
                article.publisher.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: context.ui.colors.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.xs),
      ],
      Text(
        article.title,
        maxLines: featured ? 3 : (textOnly ? 2 : 3),
        overflow: TextOverflow.ellipsis,
        style: featured
            ? context.uiText.heading
            : (textOnly ? context.uiText.body : context.uiText.bodyStrong),
      ),
      UiGap.v(context.ui.spacing.sm),
      if (featured && article.summary.isNotEmpty) ...[
        Text(
          article.summary,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: context.uiText.body.copyWith(
            color: context.ui.colors.foregroundMuted,
          ),
        ),
        UiGap.v(context.ui.spacing.sm),
      ],
      MarketArticleMeta(
        article: article,
        snapshot: snapshot,
        onInstrument: onInstrument,
      ),
      if (onLike != null) ...[
        UiGap.v(context.ui.spacing.xs),
        UiButton(
          label: isLiked ? 'Liked' : 'Like',
          leadingIcon: isLiked ? Icons.favorite : Icons.favorite_border,
          size: UiSize.sm,
          variant: UiVariant.ghost,
          intent: isLiked ? UiIntent.danger : UiIntent.neutral,
          onPressed: onLike,
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (textOnly) {
      return InkWell(
        onTap: onTap,
        borderRadius: context.radius(context.ui.radii.md),
        child: Padding(
          padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
          child: _copy(context),
        ),
      );
    }

    return UiCard(
      onTap: onTap,
      variant: featured ? UiCardVariant.surface : UiCardVariant.ghost,
      borderless: !featured,
      hoverLift: featured,
      padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
      child: LayoutBuilder(
        builder: (context, box) {
          if (row && box.maxWidth >= 380) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _copy(context)),
                UiGap.h(context.ui.spacing.md),
                Expanded(child: _image(context)),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (featured || !row) ...[
                _image(context),
                UiGap.v(context.ui.spacing.md),
              ],
              _copy(context),
            ],
          );
        },
      ),
    );
  }
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
    this.selectedTopic = 'all',
    this.isLiked,
    this.onLike,
  });
  final MarketSnapshot snapshot;
  final ValueChanged<MarketArticle> onArticle;
  final int limit;
  final VoidCallback? onMore;
  final ValueChanged<MarketInstrument>? onInstrument;
  final ValueChanged<String>? onTopicSelected;
  final String selectedTopic;
  final bool Function(MarketArticle)? isLiked;
  final ValueChanged<MarketArticle>? onLike;

  @override
  Widget build(BuildContext context) {
    final articles = snapshot.articles;
    final publishers = <String, num>{};
    for (final article in articles) {
      final name = article.publisher.trim();
      if (name.isNotEmpty) {
        publishers.update(name, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return MarketTwoPanel(
      primary: UiCard(
        title: 'Market newsroom',
        subtitle: '${articles.length} stories',
        trailing: UiBadge(
          label: 'Snapshot',
          icon: Icons.archive_outlined,
          intent: UiIntent.neutral,
          variant: UiBadgeVariant.soft,
        ),
        padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (articles.isEmpty)
              const UiEmptyState(
                icon: Icons.newspaper_outlined,
                title: 'No articles available',
                message: 'Try another topic or search term.',
              ),
            if (articles.isNotEmpty) ...[
              // Featured Hero Article
              MarketNewsCard(
                article: articles.first,
                snapshot: snapshot,
                featured: true,
                onInstrument: onInstrument,
                onTap: () => onArticle(articles.first),
                isLiked: isLiked?.call(articles.first) ?? false,
                onLike: onLike == null ? null : () => onLike!(articles.first),
              ),
              UiGap.v(context.ui.spacing.md),
              const UiDivider(),
              UiGap.v(context.ui.spacing.md),

              // Secondary Articles Grid
              for (
                var i = 1;
                i < articles.skip(1).take(limit - 1).length + 1;
                i++
              ) ...[
                MarketNewsCard(
                  article: articles[i],
                  snapshot: snapshot,
                  row: true,
                  onInstrument: onInstrument,
                  onTap: () => onArticle(articles[i]),
                  isLiked: isLiked?.call(articles[i]) ?? false,
                  onLike: onLike == null ? null : () => onLike!(articles[i]),
                ),
                if (i < articles.skip(1).take(limit - 1).length)
                  const UiDivider(),
              ],
            ],
            if (articles.length > limit) ...[
              UiGap.v(context.ui.spacing.md),
              UiButton(
                label: 'Load more stories',
                trailingIcon: Icons.expand_more,
                variant: UiVariant.outline,
                onPressed: onMore,
              ),
            ],
          ],
        ),
      ),
      secondary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MarketDistributionCard(
            title: 'Coverage by publisher',
            subtitle:
                '${articles.length} articles · ${snapshot.videos.length} videos',
            values: publishers,
          ),
          UiGap.v(context.ui.spacing.md),
          // Topic Filters
          UiCard(
            title: 'Topics',
            subtitle: 'Browse by category',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiButton(
                  label: 'All topics',
                  variant: selectedTopic == 'all'
                      ? UiVariant.soft
                      : UiVariant.ghost,
                  intent: selectedTopic == 'all'
                      ? UiIntent.primary
                      : UiIntent.neutral,
                  onPressed: onTopicSelected == null
                      ? null
                      : () => onTopicSelected!('all'),
                ),
                for (final topic in snapshot.topics.entries)
                  UiButton(
                    label:
                        '${topicDisplayLabel(topic.key)} (${topic.value.length})',
                    variant: selectedTopic == topic.key
                        ? UiVariant.soft
                        : UiVariant.ghost,
                    intent: selectedTopic == topic.key
                        ? UiIntent.primary
                        : UiIntent.neutral,
                    onPressed: onTopicSelected == null
                        ? null
                        : () => onTopicSelected!(topic.key),
                  ),
              ],
            ),
          ),
          UiGap.v(context.ui.spacing.md),

          // Trending Companies
          UiCard(
            title: 'Trending companies',
            subtitle: 'Most mentioned in news',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snapshot.trending.isEmpty)
                  Text(
                    'No trending companies',
                    style: context.uiText.caption.copyWith(
                      color: context.ui.colors.foregroundMuted,
                    ),
                  )
                else
                  for (final quote in snapshot.trending.take(6)) ...[
                    MarketQuoteRow(
                      quote: quote,
                      onTap: () => onInstrument?.call(quote),
                    ),
                    const UiDivider(spacing: 0),
                  ],
              ],
            ),
          ),

          // Video Content
          if (snapshot.videos.isNotEmpty) ...[
            UiGap.v(context.ui.spacing.md),
            UiCard(
              title: 'Watch & listen',
              subtitle: 'Video analysis',
              leading: const Icon(Icons.play_circle_outline),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final article in snapshot.videos.take(3)) ...[
                    MarketNewsCard(
                      article: article,
                      snapshot: snapshot,
                      row: true,
                      onTap: () => onArticle(article),
                      isLiked: isLiked?.call(article) ?? false,
                      onLike: onLike == null ? null : () => onLike!(article),
                    ),
                    const UiDivider(),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
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
    this.isLiked = false,
    this.onLike,
  });
  final MarketArticle article;
  final MarketSnapshot snapshot;
  final ValueChanged<MarketArticle>? onArticle;
  final ValueChanged<MarketInstrument>? onInstrument;
  final bool isLiked;
  final VoidCallback? onLike;

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
      accentColor: context.ui.colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Publisher Badge
          Row(
            children: [
              UiBadge(
                label: 'News & Analysis',
                icon: Icons.newspaper_outlined,
                variant: UiBadgeVariant.soft,
                intent: UiIntent.primary,
              ),
              const Spacer(),
              if (article.isVideo)
                const UiBadge(
                  label: 'Video',
                  icon: Icons.play_circle_outline,
                  variant: UiBadgeVariant.outline,
                ),
            ],
          ),
          UiGap.v(context.ui.spacing.lg),

          // Article Title
          Text(article.title, style: context.uiText.display),
          UiGap.v(context.ui.spacing.md),

          // Article Meta
          Wrap(
            spacing: context.sp(context.ui.spacing.sm),
            runSpacing: context.sp(context.ui.spacing.xs),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (article.publisher.isNotEmpty)
                UiBadge(
                  label: article.publisher.length > 22
                      ? '${article.publisher.substring(0, 21)}…'
                      : article.publisher,
                  variant: UiBadgeVariant.soft,
                  intent: UiIntent.primary,
                  size: UiSize.xs,
                ),
              Text(
                article.publishedAt != null
                    ? AppTokens.relativeTime(article.publishedAt!)
                    : 'Unknown time',
                style: context.uiText.caption.copyWith(
                  color: context.ui.colors.foregroundMuted,
                ),
              ),
            ],
          ),
          UiGap.v(context.ui.spacing.lg),

          // Featured Image
          ClipRRect(
            borderRadius: context.radius(context.ui.radii.lg),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: UiRemoteImage(
                url: article.thumbnailUrl,
                semanticLabel: article.title,
              ),
            ),
          ),
          UiGap.v(context.ui.spacing.lg),

          // Article Summary
          if (article.summary.isNotEmpty)
            Container(
              padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
              decoration: BoxDecoration(
                color: context.ui.colors.foreground.withValues(alpha: 0.03),
                borderRadius: context.radius(context.ui.radii.md),
                border: Border.all(color: context.ui.colors.border, width: 1),
              ),
              child: Text(
                article.summary,
                style: context.uiText.body.copyWith(height: 1.6, fontSize: 16),
              ),
            )
          else
            const UiCallout(
              title: 'Summary unavailable',
              message: 'Read the full report at the original source.',
              intent: UiIntent.neutral,
            ),
          UiGap.v(context.ui.spacing.lg),

          // Related Tickers
          if (article.tickers.isNotEmpty) ...[
            Text('Related instruments', style: context.uiText.subheading),
            UiGap.v(context.ui.spacing.sm),
            Wrap(
              spacing: context.sp(context.ui.spacing.xs),
              runSpacing: context.sp(context.ui.spacing.xs),
              children: [
                for (final symbol in article.tickers)
                  Builder(
                    builder: (context) {
                      final quote = snapshot.instruments
                          .where((q) => q.symbol == symbol)
                          .firstOrNull;
                      return quote != null && onInstrument != null
                          ? UiButton(
                              label: symbol,
                              size: UiSize.sm,
                              variant: UiVariant.soft,
                              onPressed: () => onInstrument!(quote),
                            )
                          : UiBadge(
                              label: symbol,
                              variant: UiBadgeVariant.outline,
                            );
                    },
                  ),
              ],
            ),
            UiGap.v(context.ui.spacing.lg),
          ],

          // Read Original CTA
          if (onLike != null) ...[
            UiButton(
              label: isLiked ? 'Liked' : 'Like this story',
              leadingIcon: isLiked ? Icons.favorite : Icons.favorite_border,
              variant: UiVariant.soft,
              intent: isLiked ? UiIntent.danger : UiIntent.neutral,
              onPressed: onLike,
            ),
            UiGap.v(context.ui.spacing.sm),
          ],
          UiButton(
            label: article.isVideo
                ? 'Watch at source'
                : 'Read original article',
            leadingIcon: Icons.open_in_new,
            intent: UiIntent.primary,
            onPressed: article.link.isEmpty ? null : () => _source(context),
          ),
        ],
      ),
    ),
    secondary: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarketRelatedMoves(
          instruments: snapshot.instruments
              .where((q) => article.tickers.contains(q.symbol))
              .toList(),
        ),
        UiGap.v(context.ui.spacing.md),
        // Related Quotes
        UiCard(
          title: 'Related instruments',
          subtitle: 'Companies mentioned',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!snapshot.instruments.any(
                (q) => article.tickers.contains(q.symbol),
              ))
                Text(
                  'No linked quotes in this snapshot.',
                  style: context.uiText.caption.copyWith(
                    color: context.ui.colors.foregroundMuted,
                  ),
                )
              else
                for (final quote in snapshot.instruments.where(
                  (q) => article.tickers.contains(q.symbol),
                )) ...[
                  MarketQuoteRow(
                    quote: quote,
                    onTap: () => onInstrument?.call(quote),
                  ),
                  const UiDivider(spacing: 0),
                ],
            ],
          ),
        ),
        UiGap.v(context.ui.spacing.md),

        // More Stories
        UiCard(
          title: 'More stories',
          subtitle: 'Related coverage',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (snapshot.articles
                  .where((a) => a.link != article.link)
                  .isEmpty)
                Text(
                  'No more articles available.',
                  style: context.uiText.caption.copyWith(
                    color: context.ui.colors.foregroundMuted,
                  ),
                )
              else
                for (final related
                    in snapshot.articles
                        .where((a) => a.link != article.link)
                        .take(5)) ...[
                  MarketNewsCard(
                    article: related,
                    snapshot: snapshot,
                    textOnly: true,
                    onTap: () => onArticle?.call(related),
                  ),
                  const UiDivider(),
                ],
            ],
          ),
        ),
      ],
    ),
  );
}
