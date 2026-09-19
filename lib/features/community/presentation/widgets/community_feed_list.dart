import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';

/// Renders a Twitter/Threads-grade flat feed timeline with hairline dividers and
/// continuous vertical thread-lines between posts.
class CommunityFeedList extends StatelessWidget {
  const CommunityFeedList({
    super.key,
    required this.posts,
    this.header,
    this.controller,
    this.onPostTap,
    this.onLike,
    this.onRepost,
    this.onBookmark,
    this.onAuthorTap,
    this.onTagTap,
    this.onRefresh,
    this.padding,
    this.emptyState,
  });

  final List<CommunityPost> posts;
  final Widget? header;
  final ScrollController? controller;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<String>? onLike;
  final ValueChanged<String>? onRepost;
  final ValueChanged<String>? onBookmark;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<String>? onTagTap;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry? padding;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final int headerCount = header != null ? 1 : 0;
    final int totalCount = headerCount + posts.length;

    if (posts.isEmpty && header == null) {
      final empty =
          emptyState ??
          Center(
            child: Padding(
              padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
              child: UiEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No posts in this feed yet',
                message:
                    'Be the first to share a thesis, trade setup or market insight.',
              ),
            ),
          );

      if (onRefresh != null) {
        return RefreshIndicator(
          onRefresh: onRefresh!,
          child: ListView(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[empty],
          ),
        );
      }
      return empty;
    }

    Widget list = ListView.separated(
      controller: controller,
      padding: padding ?? EdgeInsets.zero,
      itemCount: totalCount,
      separatorBuilder: (BuildContext ctx, int index) {
        return Container(
          height: theme.borders.hairline,
          color: theme.colors.border.withValues(alpha: 0.6),
        );
      },
      itemBuilder: (BuildContext ctx, int index) {
        if (header != null && index == 0) {
          return header!;
        }

        final postIndex = index - headerCount;
        final post = posts[postIndex];

        return CommunityPostCard(
          key: ValueKey<String>(post.id),
          post: post,
          variant: CommunityPostCardVariant.feed,
          onTap: () => onPostTap?.call(post),
          onLike: () => onLike?.call(post.id),
          onRepost: () => onRepost?.call(post.id),
          onBookmark: () => onBookmark?.call(post.id),
          onAuthorTap: onAuthorTap,
          onTagTap: onTagTap,
        );
      },
    );

    if (onRefresh != null) {
      list = RefreshIndicator(onRefresh: onRefresh!, child: list);
    }

    return list;
  }
}
