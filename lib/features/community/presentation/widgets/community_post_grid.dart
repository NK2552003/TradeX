import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';

/// Responsive Pinterest/X-media style masonry grid for community posts.
///
/// Dynamically adjusts columns based on available width:
/// - `w > 1100`: 3 columns
/// - `w > 700`: 2 columns
/// - `w <= 700`: 1 column
///
/// Uses shortest-column-first distribution based on content height estimation to keep
/// column heights balanced without external layout dependencies.
class CommunityPostGrid extends StatelessWidget {
  const CommunityPostGrid({
    super.key,
    required this.posts,
    this.onPostTap,
    this.onLike,
    this.onRepost,
    this.onBookmark,
    this.onAuthorTap,
    this.onTagTap,
    this.onOpenRef,
    this.padding,
    this.emptyState,
  });

  final List<CommunityPost> posts;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<String>? onLike;
  final ValueChanged<String>? onRepost;
  final ValueChanged<String>? onBookmark;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final EdgeInsetsGeometry? padding;
  final Widget? emptyState;

  double _estimateHeight(CommunityPost post) {
    double h = 130.0;
    h += post.body.length * 0.45;
    if (post.tradeSetup != null) h += 180.0;
    if (post.attachment != null) h += 95.0;
    if (post.imageUrl != null) h += 180.0;
    if (post.linkPreview != null) h += 120.0;
    if (post.quoted != null) h += 120.0;
    if (post.tickers.isNotEmpty || post.tags.isNotEmpty) h += 30.0;
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    if (posts.isEmpty) {
      return emptyState ??
          const CommunityEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No posts found',
            message: 'Try exploring other categories or clearing your search.',
          );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int cols = width > 1100 ? 3 : (width > 700 ? 2 : 1);
        final double gap = context.sp(theme.spacing.sm);

        if (cols == 1) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: padding ?? EdgeInsets.zero,
            itemCount: posts.length,
            separatorBuilder: (BuildContext ctx, int i) =>
                SizedBox(height: gap),
            itemBuilder: (BuildContext ctx, int index) {
              final post = posts[index];
              return UiDeferred(
                key: ValueKey(post.id),
                estimatedHeight: _estimateHeight(post),
                builder: (_) => CommunityPostCard(
                  key: ValueKey<String>(post.id),
                  post: post,
                  variant: CommunityPostCardVariant.boxed,
                  onTap: () => onPostTap?.call(post),
                  onLike: () => onLike?.call(post.id),
                  onRepost: () => onRepost?.call(post.id),
                  onBookmark: () => onBookmark?.call(post.id),
                  onAuthorTap: onAuthorTap,
                  onTagTap: onTagTap,
                  onOpenRef: onOpenRef,
                ),
              );
            },
          );
        }

        // Distribute posts across columns with shortest-column-first heuristic
        final List<List<CommunityPost>> columnBuckets =
            List<List<CommunityPost>>.generate(cols, (_) => <CommunityPost>[]);
        final List<double> columnHeights = List<double>.filled(cols, 0.0);

        for (final post in posts) {
          int shortestCol = 0;
          double minHeight = columnHeights[0];
          for (int c = 1; c < cols; c++) {
            if (columnHeights[c] < minHeight) {
              minHeight = columnHeights[c];
              shortestCol = c;
            }
          }

          columnBuckets[shortestCol].add(post);
          columnHeights[shortestCol] += _estimateHeight(post) + gap;
        }

        return Padding(
          padding: padding ?? EdgeInsets.zero,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int c = 0; c < cols; c++) ...<Widget>[
                if (c > 0) SizedBox(width: gap),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      for (
                        int i = 0;
                        i < columnBuckets[c].length;
                        i++
                      ) ...<Widget>[
                        if (i > 0) SizedBox(height: gap),
                        UiDeferred(
                          key: ValueKey(columnBuckets[c][i].id),
                          estimatedHeight: _estimateHeight(columnBuckets[c][i]),
                          builder: (_) => CommunityPostCard(
                            key: ValueKey<String>(columnBuckets[c][i].id),
                            post: columnBuckets[c][i],
                            variant: CommunityPostCardVariant.boxed,
                            onTap: () => onPostTap?.call(columnBuckets[c][i]),
                            onLike: () => onLike?.call(columnBuckets[c][i].id),
                            onRepost: () =>
                                onRepost?.call(columnBuckets[c][i].id),
                            onBookmark: () =>
                                onBookmark?.call(columnBuckets[c][i].id),
                            onAuthorTap: onAuthorTap,
                            onTagTap: onTagTap,
                            onOpenRef: onOpenRef,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
