import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';

class MarketArticleMeta extends StatelessWidget {
  const MarketArticleMeta({
    super.key,
    required this.article,
    required this.snapshot,
  });
  final MarketArticle article;
  final MarketSnapshot snapshot;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: context.sp(context.ui.spacing.xs),
    runSpacing: context.sp(context.ui.spacing.xs),
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        '${article.publisher}${article.publishedAt == null ? '' : ' · ${AppTokens.relativeTime(article.publishedAt!)}'}',
        style: context.uiText.caption.copyWith(
          color: context.ui.colors.foregroundMuted,
        ),
      ),
      for (final symbol in article.tickers.take(3)) ...[
        for (final quote in snapshot.instruments.where(
          (q) => q.symbol == symbol,
        ))
          UiBadge(
            label:
                '${quote.symbol} ${quote.changePercent >= 0 ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
            intent: quote.changePercent >= 0
                ? UiIntent.success
                : UiIntent.danger,
            variant: UiBadgeVariant.outline,
            size: UiSize.xs,
          ),
      ],
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
  });
  final MarketArticle article;
  final MarketSnapshot snapshot;
  final VoidCallback onTap;
  final bool featured, row;
  Widget _image(BuildContext context) => ClipRRect(
    borderRadius: context.radius(context.ui.radii.md),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: UiRemoteImage(
        url: article.thumbnailUrl,
        semanticLabel: article.title,
      ),
    ),
  );
  Widget _copy(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        article.title,
        maxLines: featured ? null : 3,
        overflow: featured ? null : TextOverflow.ellipsis,
        style: (featured ? context.uiText.heading : context.uiText.bodyStrong)
            .copyWith(
              fontSize: featured
                  ? context.fs(context.uiRes.isMobile ? 24 : 32)
                  : null,
              height: 1.3,
            ),
      ),
      if (featured && article.summary.isNotEmpty) ...[
        UiGap.v(context.ui.spacing.sm),
        Text(article.summary, style: context.uiText.body),
      ],
      UiGap.v(context.ui.spacing.sm),
      MarketArticleMeta(article: article, snapshot: snapshot),
    ],
  );
  @override
  Widget build(BuildContext context) => UiCard(
    variant: UiCardVariant.ghost,
    borderless: true,
    hoverLift: false,
    onTap: onTap,
    padding: EdgeInsets.symmetric(vertical: context.sp(context.ui.spacing.sm)),
    child: LayoutBuilder(
      builder: (context, box) {
        if ((featured || row) && box.maxWidth >= 550) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: box.maxWidth * (featured ? .46 : .28),
                child: _image(context),
              ),
              UiGap.h(context.ui.spacing.md),
              Expanded(child: _copy(context)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _image(context),
            UiGap.v(context.ui.spacing.sm),
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
  });
  final MarketSnapshot snapshot;
  final ValueChanged<MarketArticle> onArticle;
  final int limit;
  final VoidCallback? onMore;
  @override
  Widget build(BuildContext context) {
    final articles = snapshot.articles;
    if (articles.isEmpty) {
      return const UiEmptyState(title: 'No articles available');
    }
    Widget latest() => UiCard(
      variant: UiCardVariant.ghost,
      borderless: true,
      title: 'Latest headlines',
      child: Column(
        children: [
          for (final article in articles.skip(1).take(6)) ...[
            UiCard(
              variant: UiCardVariant.ghost,
              borderless: true,
              hoverLift: false,
              padding: EdgeInsets.zero,
              onTap: () => onArticle(article),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title, style: context.uiText.bodyStrong),
                  UiGap.v(context.ui.spacing.xs),
                  MarketArticleMeta(article: article, snapshot: snapshot),
                ],
              ),
            ),
            UiGap.v(context.ui.spacing.md),
          ],
        ],
      ),
    );
    Widget main() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarketNewsCard(
          article: articles.first,
          snapshot: snapshot,
          onTap: () => onArticle(articles.first),
          featured: true,
        ),
        UiGap.v(context.ui.spacing.md),
        UiDivider(),
        UiGap.v(context.ui.spacing.md),
        UiCardGrid(
          intrinsicHeight: true,
          desktopColumns: 3,
          largeColumns: 3,
          children: [
            for (final section in {
              'Top Stories': articles.skip(1).take(3).toList(),
              'Markets & Economy':
                  snapshot.topics['stock_market_general'] ?? [],
              'Tech & AI': snapshot.topics['magnificent_seven'] ?? [],
            }.entries)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(section.key, style: context.uiText.heading),
                  UiGap.v(context.ui.spacing.sm),
                  for (final article in section.value.take(2)) ...[
                    MarketNewsCard(
                      article: article,
                      snapshot: snapshot,
                      onTap: () => onArticle(article),
                    ),
                    UiDivider(),
                  ],
                ],
              ),
          ],
        ),
        UiGap.v(context.ui.spacing.lg),
        Text('All market news', style: context.uiText.heading),
        for (final article in articles.skip(1).take(limit)) ...[
          UiDeferred(
            key: ValueKey(article.link.isEmpty ? article.title : article.link),
            estimatedHeight: context.uiRes.isMobile ? 320 : 180,
            builder: (_) => MarketNewsCard(
              article: article,
              snapshot: snapshot,
              row: true,
              onTap: () => onArticle(article),
            ),
          ),
          UiDivider(),
        ],
        if (articles.length > limit + 1)
          UiButton(
            label: 'More stories',
            variant: UiVariant.outline,
            onPressed: onMore,
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 1080
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: main()),
                UiGap.h(context.ui.spacing.lg),
                Expanded(child: latest()),
              ],
            )
          : main(),
    );
  }
}

class MarketArticleView extends StatelessWidget {
  const MarketArticleView({
    super.key,
    required this.article,
    required this.snapshot,
    this.onArticle,
  });
  final MarketArticle article;
  final MarketSnapshot snapshot;
  final ValueChanged<MarketArticle>? onArticle;
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MarketNewsCard(
        article: article,
        snapshot: snapshot,
        featured: true,
        onTap: () {},
      ),
      UiGap.v(context.ui.spacing.md),
      Align(
        alignment: Alignment.centerLeft,
        child: UiButton(
          label: 'Read original article',
          leadingIcon: Icons.open_in_new,
          onPressed: article.link.isEmpty ? null : () => _source(context),
        ),
      ),
      UiGap.v(context.ui.spacing.lg),
      UiDivider(),
      UiGap.v(context.ui.spacing.md),
      Text('More stories', style: context.uiText.heading),
      for (final related
          in snapshot.articles
              .where((a) => a.link != article.link)
              .take(6)) ...[
        MarketNewsCard(
          article: related,
          snapshot: snapshot,
          row: true,
          onTap: () => onArticle?.call(related),
        ),
        UiDivider(),
      ],
    ],
  );
}
