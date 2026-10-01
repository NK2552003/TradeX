import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';

/// Renders a Twitter/Threads-grade flat feed timeline with hairline dividers and
/// continuous vertical thread-lines between posts.
class CommunityFeedList extends StatelessWidget {
  const CommunityFeedList({
    super.key,
    required this.posts,
    this.header,
    this.controller,
    this.repository,
    this.currentUser,
    this.onPostTap,
    this.onLike,
    this.onRepost,
    this.onBookmark,
    this.onAuthorTap,
    this.onTagTap,
    this.onOpenRef,
    this.onRefresh,
    this.padding,
    this.emptyState,
  });

  final List<CommunityPost> posts;
  final Widget? header;
  final ScrollController? controller;
  final CommunityRepository? repository;
  final CommunityAuthor? currentUser;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<String>? onLike;
  final ValueChanged<String>? onRepost;
  final ValueChanged<String>? onBookmark;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry? padding;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {

    final double topEdgeOffset = (padding is EdgeInsets)
        ? (padding as EdgeInsets).top
        : 0.0;

    if (posts.isEmpty && header == null) {
      final empty =
          emptyState ??
          const CommunityEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No posts in this feed yet',
            message:
                'Be the first to share a thesis, trade setup or market insight.',
          );

      if (onRefresh != null) {
        return RefreshIndicator(
          edgeOffset: topEdgeOffset,
          onRefresh: onRefresh!,
          child: ListView(
            controller: controller,
            padding: padding,
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[empty],
          ),
        );
      }
      return empty;
    }

    Widget list = UiLazyList(
      controller: controller,
      padding: padding ?? EdgeInsets.zero,
      headerBuilder: header == null ? null : (_) => header!,
      itemCount: posts.length,
      itemBuilder: (BuildContext ctx, int index) {
        final post = posts[index];
        return Column(
          children: [
            if (index > 0) const UiDivider(spacing: 0),
            CommunityPostCard(
              key: ValueKey<String>(post.id),
              post: post,
              variant: CommunityPostCardVariant.feed,
              repository: repository,
              currentUser: currentUser,
              onTap: () => onPostTap?.call(post),
              onLike: () => onLike?.call(post.id),
              onRepost: () => onRepost?.call(post.id),
              onBookmark: () => onBookmark?.call(post.id),
              onAuthorTap: onAuthorTap,
              onTagTap: onTagTap,
              onOpenRef: onOpenRef,
            ),
          ],
        );
      },
    );

    if (onRefresh != null) {
      list = RefreshIndicator(
        edgeOffset: topEdgeOffset,
        onRefresh: onRefresh!,
        child: list,
      );
    }

    return list;
  }
}
