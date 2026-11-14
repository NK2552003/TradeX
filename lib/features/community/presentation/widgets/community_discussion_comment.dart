import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../../data/community_repository.dart';
import '../../models/community_models.dart';
import 'community_highlighted_text.dart';
import 'community_reactions_dialog.dart';
import 'community_follow_button.dart';
import 'community_emoji_picker.dart';
import 'community_reply_branch.dart';

class CommunityDiscussionComment extends StatefulWidget {
  const CommunityDiscussionComment({
    super.key,
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    this.postAuthorId,
    this.repository,
    this.onLike,
    this.onAuthorTap,
    this.onTagTap,
    this.depth = 0,
    this.replyComposerBuilder,
  });
  final CommunityComment comment;
  final String currentUserId;
  final String? postAuthorId;
  final CommunityRepository? repository;
  final ValueChanged<CommunityComment> onReply;
  final void Function(String id, {String? reaction})? onLike;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<String>? onTagTap;
  final int depth;
  final Widget? Function(CommunityComment)? replyComposerBuilder;

  @override
  State<CommunityDiscussionComment> createState() =>
      _CommunityDiscussionCommentState();
}

class _CommunityDiscussionCommentState
    extends State<CommunityDiscussionComment> {
  bool _expanded = true;
  bool _reacting = false;

  Future<void> _react([String? reaction]) async {
    if (_reacting) return;
    final repo = widget.repository;
    if (repo == null) {
      widget.onLike?.call(widget.comment.id, reaction: reaction);
      return;
    }
    setState(() => _reacting = true);
    final saved = await repo.likeComment(
      widget.comment.postId,
      widget.comment.id,
      reaction: reaction,
    );
    if (!mounted) return;
    setState(() => _reacting = false);
    if (!saved) {
      UiToast.show(
        context,
        title: 'Reaction not saved',
        message: 'Please sign in and try again.',
        intent: UiIntent.warning,
      );
    }
  }

  int _visibleReplies = 2;

  @override
  void didUpdateWidget(CommunityDiscussionComment oldWidget) {
    super.didUpdateWidget(oldWidget);
    final added =
        widget.comment.replies.length - oldWidget.comment.replies.length;
    if (added > 0) {
      _visibleReplies += added;
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final comment = widget.comment;
    final author = comment.author;
    final repo = widget.repository;
    final replyComposer = widget.replyComposerBuilder?.call(comment);
    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UiAvatar(
                name: author.displayName,
                imageUrl: author.avatarUrl,
                size: UiSize.sm,
                verified: author.verified,
                onTap: widget.onAuthorTap == null
                    ? null
                    : () => widget.onAuthorTap!(author),
              ),
              UiGap.h(theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: context.sp(theme.spacing.xs),
                                children: [
                                  UiInteractive(
                                    onTap: widget.onAuthorTap == null
                                        ? null
                                        : () => widget.onAuthorTap!(author),
                                    builder: (context, _) => Text(
                                      author.displayName,
                                      style: context.uiText.bodyStrong,
                                    ),
                                  ),
                                  if (author.id == widget.postAuthorId)
                                    const UiBadge(
                                      label: 'Author',
                                      size: UiSize.xs,
                                    ),
                                  Text(
                                    AppTokens.relativeTime(comment.createdAt),
                                    style: context.uiText.caption,
                                  ),
                                ],
                              ),
                              Text(
                                author.bio?.trim().isNotEmpty == true
                                    ? author.bio!
                                    : author.displayHandle,
                                style: context.uiText.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (repo != null && author.id != widget.currentUserId)
                          CommunityFollowButton(
                            repository: repo,
                            authorId: author.id,
                            size: UiSize.xs,
                          ),
                      ],
                    ),
                    UiGap.v(theme.spacing.xs),
                    CommunityHighlightedText(
                      text: comment.body,
                      style: context.uiText.body,
                      onTagTap: widget.onTagTap,
                    ),
                    UiGap.v(theme.spacing.xs),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < context.sz(320);
                        return Row(
                          children: [
                            UiButton(
                              label: comment.liked ? 'Liked' : 'Like',
                              tooltip: comment.liked ? 'Liked' : 'Like',
                              leadingIcon: comment.liked
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_outlined,
                              iconOnly: compact,
                              size: UiSize.sm,
                              variant: UiVariant.ghost,
                              onPressed:
                                  _reacting ||
                                      (widget.onLike == null && repo == null)
                                  ? null
                                  : () => _react(),
                            ),
                            UiButton(
                              label: 'Reply',
                              tooltip: 'Reply',
                              leadingIcon: Icons.chat_bubble_outline,
                              iconOnly: compact,
                              size: UiSize.sm,
                              variant: UiVariant.ghost,
                              onPressed: () {
                                setState(() => _expanded = true);
                                widget.onReply(comment);
                              },
                            ),
                            CommunityEmojiPicker(
                              enabled: !_reacting,
                              onSelected: _react,
                            ),
                            const Spacer(),
                            if (comment.likes > 0)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * .4,
                                ),
                                child: UiButton(
                                  key: ValueKey(
                                    'comment-reactions-${comment.id}',
                                  ),
                                  label:
                                      '${comment.displayReactions.take(3).join(' ')} ${comment.likes}',
                                  variant: UiVariant.ghost,
                                  size: UiSize.xs,
                                  tooltip: 'View comment reactions',
                                  onPressed: repo == null
                                      ? null
                                      : () => CommunityReactionsDialog.show(
                                          context,
                                          repository: repo,
                                          targetId: comment.id,
                                          comment: true,
                                          onAuthorTap: widget.onAuthorTap,
                                        ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.replies.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: UiButton(
                label: _expanded
                    ? 'Hide replies'
                    : 'Show ${comment.replies.length} replies',
                variant: UiVariant.ghost,
                size: UiSize.xs,
                leadingIcon: _expanded ? Icons.expand_less : Icons.expand_more,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ),
          UiReveal(
            child:
                ((_expanded && comment.replies.isNotEmpty) ||
                    replyComposer != null)
                ? CommunityReplyBranch(
                    depth: widget.depth,
                    children: [
                      UiReveal(
                        child: _expanded
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final reply in comment.replies.take(
                                    _visibleReplies,
                                  ))
                                    CommunityDiscussionComment(
                                      key: ValueKey(reply.id),
                                      comment: reply,
                                      currentUserId: widget.currentUserId,
                                      postAuthorId: widget.postAuthorId,
                                      repository: repo,
                                      onReply: widget.onReply,
                                      onLike: widget.onLike,
                                      onAuthorTap: widget.onAuthorTap,
                                      onTagTap: widget.onTagTap,
                                      depth: widget.depth + 1,
                                      replyComposerBuilder:
                                          widget.replyComposerBuilder,
                                    ),
                                  if (_visibleReplies < comment.replies.length)
                                    UiButton(
                                      label: 'See more replies',
                                      variant: UiVariant.ghost,
                                      onPressed: () =>
                                          setState(() => _visibleReplies += 5),
                                    ),
                                ],
                              )
                            : null,
                      ),
                      UiReveal(
                        child: replyComposer == null
                            ? null
                            : Padding(
                                padding: EdgeInsets.only(
                                  top: context.sp(theme.spacing.xs),
                                ),
                                child: replyComposer,
                              ),
                      ),
                    ],
                  )
                : null,
          ),
        ],
      ),
    );
    return content;
  }
}
