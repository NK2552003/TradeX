import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../../data/community_repository.dart';
import '../../models/community_activity.dart';
import '../../models/community_models.dart';
import 'community_post_discussion.dart';

/// The same discussion layout for posts, notes, journals, and strategies.
class UniversalCommentsSection extends StatelessWidget {
  const UniversalCommentsSection({
    super.key,
    required this.targetId,
    required this.targetType,
    required this.comments,
    required this.currentUser,
    required this.onAddComment,
    this.onLikeComment,
    this.onAuthorTap,
    this.onTagTap,
    this.title = 'Trader Discussion',
    this.showPrimaryComposer = true,
    this.isPublic = true,
    this.canToggleVisibility = true,
    this.onToggleVisibility,
    this.repository,
    this.postAuthorId,
  });
  final String targetId;
  final String targetType;
  final List<CommunityComment> comments;
  final CommunityAuthor currentUser;
  final Future<void> Function(
    String text, {
    String? parentCommentId,
    String? sentiment,
  })
  onAddComment;
  final void Function(String commentId, {String? reaction})? onLikeComment;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<String>? onTagTap;
  final String title;
  final bool showPrimaryComposer;
  final bool isPublic;
  final bool canToggleVisibility;
  final ValueChanged<bool>? onToggleVisibility;
  final CommunityRepository? repository;
  final String? postAuthorId;

  String get _targetLabel => switch (targetType) {
    'note' => 'Note',
    'strategy' || 'strategy_playbook' => 'Playbook',
    'journal' || 'trade_journal' => 'Trade Review',
    'post' => 'Post',
    _ => 'Record',
  };

  int _count(List<CommunityComment> items) =>
      items.fold(0, (total, item) => total + 1 + _count(item.replies));

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isPublic) ...[
          UiCallout(
            title: 'Private $_targetLabel Discussion',
            message: canToggleVisibility
                ? 'This ${_targetLabel.toLowerCase()} is private. Make it public to invite feedback from the trader network.'
                : 'This ${_targetLabel.toLowerCase()} is private. Discussion is visible only to authorized collaborators.',
            intent: UiIntent.warning,
            icon: Icons.lock_outline,
          ),
          UiGap.v(theme.spacing.sm),
        ],
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: context.sp(theme.spacing.sm),
          runSpacing: context.sp(theme.spacing.xs),
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: context.sp(theme.spacing.xs),
              children: [
                Text(title, style: context.uiText.heading),
                UiBadge(
                  label: '${_count(buildCommunityCommentTree(comments))}',
                  size: UiSize.xs,
                ),
                UiBadge(
                  label: isPublic ? 'Public' : 'Private',
                  size: UiSize.xs,
                  intent: isPublic ? UiIntent.success : UiIntent.warning,
                ),
              ],
            ),
            if (canToggleVisibility && onToggleVisibility != null)
              UiButton(
                label: isPublic ? 'Make Private' : 'Make Public',
                size: UiSize.xs,
                variant: UiVariant.ghost,
                onPressed: () => onToggleVisibility!(!isPublic),
              ),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        CommunityPostDiscussion(
          key: ValueKey('$targetType:$targetId'),
          comments: comments,
          currentUser: currentUser,
          onAddComment: onAddComment,
          onLikeComment: onLikeComment,
          onAuthorTap: onAuthorTap,
          onTagTap: onTagTap,
          repository: repository,
          postAuthorId: postAuthorId,
          showComposer: showPrimaryComposer,
        ),
      ],
    );
  }
}
