import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import '../../data/community_repository.dart';
import '../../models/community_activity.dart';
import '../../models/community_models.dart';
import 'community_discussion_comment.dart';
import 'community_comment_composer.dart';

class CommunityPostDiscussion extends StatefulWidget {
  const CommunityPostDiscussion({
    super.key,
    required this.comments,
    required this.currentUser,
    required this.onAddComment,
    this.onLikeComment,
    this.onAuthorTap,
    this.onTagTap,
    this.repository,
    this.postAuthorId,
    this.showComposer = true,
  });
  final List<CommunityComment> comments;
  final CommunityAuthor currentUser;
  final Future<void> Function(
    String text, {
    String? parentCommentId,
    String? sentiment,
  })
  onAddComment;
  final void Function(String id, {String? reaction})? onLikeComment;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<String>? onTagTap;
  final CommunityRepository? repository;
  final String? postAuthorId;
  final bool showComposer;

  @override
  State<CommunityPostDiscussion> createState() =>
      _CommunityPostDiscussionState();
}

class _CommunityPostDiscussionState extends State<CommunityPostDiscussion> {
  CommunityComment? _replyTo;
  String _sort = 'Most relevant';
  int _visible = 5;

  void _reply(CommunityComment comment) => setState(() => _replyTo = comment);

  Widget? _replyComposer(CommunityComment comment) {
    if (_replyTo?.id != comment.id) return null;
    return CommunityCommentComposer(
      key: ValueKey('reply-editor-${comment.id}'),
      author: widget.currentUser,
      repository: widget.repository,
      currentPostId: comment.postId,
      replyTo: comment.author,
      onCancel: () => setState(() => _replyTo = null),
      onSubmit: (text) =>
          widget.onAddComment(text, parentCommentId: comment.id),
      onSubmitted: () => setState(() => _replyTo = null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final comments = buildCommunityCommentTree(widget.comments)
      ..sort((a, b) {
        if (_sort == 'Most relevant') {
          final score = (b.likes + b.replies.length).compareTo(
            a.likes + a.replies.length,
          );
          if (score != 0) return score;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showComposer) ...[
          CommunityCommentComposer(
            key: const ValueKey('root-comment-editor'),
            author: widget.currentUser,
            repository: widget.repository,
            onSubmit: (text) => widget.onAddComment(text),
            onSubmitted: () => setState(() {
              _sort = 'Newest';
              _visible = 5;
            }),
          ),
          UiGap.v(theme.spacing.sm),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: UiDropdownMenu(
            items: [
              for (final sort in ['Most relevant', 'Newest'])
                UiMenuItem(
                  label: sort,
                  onTap: () => setState(() {
                    _sort = sort;
                    _visible = 5;
                  }),
                ),
            ],
            child: UiButton(
              label: _sort,
              trailingIcon: Icons.arrow_drop_down,
              variant: UiVariant.ghost,
              size: UiSize.sm,
            ),
          ),
        ),
        if (comments.isEmpty)
          const UiEmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No comments yet',
            message: 'Start the conversation.',
          )
        else ...[
          for (final comment in comments.take(_visible))
            CommunityDiscussionComment(
              key: ValueKey(comment.id),
              comment: comment,
              currentUserId: widget.currentUser.id,
              postAuthorId: widget.postAuthorId,
              repository: widget.repository,
              onReply: _reply,
              replyComposerBuilder: _replyComposer,
              onLike: widget.onLikeComment,
              onAuthorTap: widget.onAuthorTap,
              onTagTap: widget.onTagTap,
            ),
          if (_visible < comments.length)
            Align(
              alignment: Alignment.centerLeft,
              child: UiButton(
                label: 'See ${comments.length - _visible} more comments',
                leadingIcon: Icons.unfold_more,
                variant: UiVariant.ghost,
                onPressed: () => setState(() => _visible += 5),
              ),
            ),
        ],
      ],
    );
  }
}
