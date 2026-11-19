import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';
import 'package:alphajournal/features/market_data/presentation/market_news_widgets.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_side_sheet.dart';

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
  }) {
    final reader = CommunityArticleSheet(
      article: article,
      onShareToPost: onShareToPost,
      snapshot: snapshot,
    );
    if (Navigator.of(context, rootNavigator: true).context.uiRes.isDesktop) {
      return showSettingsSideSheet<void>(
        context,
        title: 'Market News',
        subtitle: article.source,
        desktopWidthRatio: 0.48,
        minDesktopWidth: 540,
        maxWidth: 760,
        child: reader,
      );
    }
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Market News')),
          body: reader,
        ),
      ),
    );
  }

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
