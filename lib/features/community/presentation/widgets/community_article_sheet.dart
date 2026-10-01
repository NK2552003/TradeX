import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';

MarketArticle communityMarketArticle(CommunityNewsItem article) =>
    MarketArticle.fromJson({
      'title': article.headline,
      'summary': article.summary,
      'publisher': article.source,
      'link': article.articleUrl,
      'published_at': article.publishedAt.toIso8601String(),
      'thumbnail_url': article.thumbnail,
      'related_tickers': article.relatedTickers,
    });

/// Full-width editorial reader shared with the Market Intelligence feature.
class CommunityArticleSheet extends StatelessWidget {
  const CommunityArticleSheet({
    super.key,
    required this.article,
    this.onShareToPost,
    this.snapshot,
  });
  final CommunityNewsItem article;
  final ValueChanged<CommunityNewsItem>? onShareToPost;
  final MarketSnapshot? snapshot;
  static Future<void> show(
    BuildContext context, {
    required CommunityNewsItem article,
    ValueChanged<CommunityNewsItem>? onShareToPost,
    MarketSnapshot? snapshot,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Market News')),
        body: CommunityArticleSheet(
          article: article,
          onShareToPost: onShareToPost,
          snapshot: snapshot,
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MarketArticleView(
              article: communityMarketArticle(article),
              snapshot:
                  snapshot ??
                  const MarketSnapshot(instruments: [], articles: []),
              onArticle: (selected) => show(
                context,
                article: CommunityNewsItem(
                  id: selected.link,
                  headline: selected.title,
                  source: selected.publisher,
                  publishedAt: selected.publishedAt ?? DateTime(1970),
                  summary: selected.summary,
                  articleUrl: selected.link,
                  thumbnail: selected.thumbnailUrl,
                  relatedTickers: selected.tickers,
                ),
                snapshot: snapshot,
              ),
            ),
            if (onShareToPost != null) ...[
              UiGap.v(context.ui.spacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: UiButton(
                  label: 'Share to Post',
                  leadingIcon: Icons.share_outlined,
                  onPressed: () {
                    Navigator.of(context).pop();
                    onShareToPost!(article);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
