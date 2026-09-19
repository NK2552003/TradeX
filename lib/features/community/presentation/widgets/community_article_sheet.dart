import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/models/community_models.dart';

/// In-app clean reader bottom sheet for financial market wire articles.
class CommunityArticleSheet extends StatelessWidget {
  const CommunityArticleSheet({
    super.key,
    required this.article,
    this.onShareToPost,
  });

  final CommunityNewsItem article;
  final ValueChanged<CommunityNewsItem>? onShareToPost;

  static Future<void> show(
    BuildContext context, {
    required CommunityNewsItem article,
    ValueChanged<CommunityNewsItem>? onShareToPost,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => FractionallySizedBox(
        heightFactor: 0.8,
        child: Container(
          decoration: BoxDecoration(
            color: ctx.uiColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(ctx.sp(ctx.ui.radii.lg)),
            ),
            border: Border.all(
              color: ctx.uiColors.border,
              width: ctx.ui.borders.hairline,
            ),
          ),
          padding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
          child: SafeArea(
            child: CommunityArticleSheet(
              article: article,
              onShareToPost: onShareToPost,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiIntent sentimentIntent = article.sentimentScore > 0.3
        ? UiIntent.success
        : (article.sentimentScore < -0.2 ? UiIntent.danger : UiIntent.info);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Drag handle
        Center(
          child: Container(
            width: context.sz(36),
            height: context.sz(4),
            margin: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header meta
        Row(
          children: <Widget>[
            UiBadge(
              label: article.category,
              intent: sentimentIntent,
              variant: UiBadgeVariant.soft,
              size: UiSize.sm,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Text(
              '${article.source} · ${AppTokens.relativeTime(article.publishedAt)}',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundSubtle,
                fontSize: context.fs(12),
              ),
            ),
            const Spacer(),
            UiIconButton(
              icon: Icons.close_rounded,
              size: UiSize.xs,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),

        // Headline
        Text(
          article.headline,
          style: context.uiText.heading.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: context.fs(18),
            height: 1.35,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        UiDivider(),
        SizedBox(height: context.sp(theme.spacing.sm)),

        // Body Content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  article.summary ??
                      'The Reserve Bank of India Monetary Policy Committee has decided to maintain the policy repo rate unchanged. Governor highlighted that inflation risks remain sticky in food components, while overall macroeconomic growth momentum in the domestic economy continues to remain robust.\n\nInstitutional analysts point out that liquidity conditions in the banking system are projected to remain in neutral to deficit territory over the next fortnight. Commercial banks may see net interest margin compression over the coming quarters as funding costs adjust.',
                  style: context.uiText.body.copyWith(
                    fontSize: context.fs(14),
                    height: 1.6,
                    color: theme.colors.foreground,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.md)),

                // Related tickers section
                if (article.relatedTickers.isNotEmpty) ...<Widget>[
                  Text(
                    'Impacted Assets & Tickers',
                    style: context.uiText.bodyStrong.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  Wrap(
                    spacing: context.sp(theme.spacing.xs),
                    children: <Widget>[
                      for (final t in article.relatedTickers)
                        UiBadge(
                          label: '\$$t',
                          intent: UiIntent.primary,
                          variant: UiBadgeVariant.soft,
                          size: UiSize.sm,
                        ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                ],

                // Disclaimer box
                UiCard(
                  variant: UiCardVariant.surface,
                  padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.info_outline_rounded,
                        size: context.sz(16),
                        color: theme.colors.foregroundMuted,
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Expanded(
                        child: Text(
                          'Market wire news is curated for educational and informational purposes only and does not constitute financial advice.',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundSubtle,
                            fontSize: context.fs(11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: context.sp(theme.spacing.sm)),

        // Bottom actions
        Row(
          children: <Widget>[
            Expanded(
              child: UiButton(
                label: 'Share to Post',
                variant: UiVariant.outline,
                icon: Icons.post_add_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  onShareToPost?.call(article);
                },
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: UiButton(
                label: 'Open Source',
                variant: UiVariant.primary,
                icon: Icons.open_in_new_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  UiToast.show(
                    context,
                    title: article.source,
                    message: 'Opening external news source...',
                    intent: UiIntent.info,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
