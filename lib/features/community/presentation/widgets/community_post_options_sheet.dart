import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_edit_post_dialog.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_insights_sheet.dart';
import 'package:tradex/features/community/presentation/widgets/community_report_dialog.dart';

/// Contextual bottom sheet for post management and moderation options.
class CommunityPostOptionsSheet extends StatelessWidget {
  const CommunityPostOptionsSheet({
    super.key,
    required this.post,
    required this.repository,
    required this.isAuthor,
    this.onDelete,
    this.onEdit,
  });

  final CommunityPost post;
  final CommunityRepository repository;
  final bool isAuthor;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  static Future<void> show(
    BuildContext context, {
    required CommunityPost post,
    required CommunityRepository repository,
    required bool isAuthor,
    VoidCallback? onDelete,
    VoidCallback? onEdit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Container(
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
        padding: EdgeInsets.fromLTRB(
          ctx.sp(ctx.ui.spacing.md),
          ctx.sp(ctx.ui.spacing.sm),
          ctx.sp(ctx.ui.spacing.md),
          ctx.sp(ctx.ui.spacing.lg),
        ),
        child: SafeArea(
          child: CommunityPostOptionsSheet(
            post: post,
            repository: repository,
            isAuthor: isAuthor,
            onDelete: onDelete,
            onEdit: onEdit,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return Column(
      mainAxisSize: MainAxisSize.min,
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

        // Author Options
        if (isAuthor) ...<Widget>[
          _optionRow(
            context,
            icon: Icons.insights_rounded,
            title: 'View Post Insights',
            onTap: () {
              Navigator.of(context).pop();
              CommunityPostInsightsSheet.show(
                context,
                post: post,
                repository: repository,
              );
            },
          ),
          _optionRow(
            context,
            icon: Icons.edit_outlined,
            title: 'Edit Post',
            onTap: () {
              Navigator.of(context).pop();
              if (onEdit != null) {
                onEdit!();
              } else {
                CommunityEditPostDialog.show(
                  context,
                  post: post,
                  repository: repository,
                );
              }
            },
          ),
          _optionRow(
            context,
            icon: post.isPinned
                ? Icons.push_pin_outlined
                : Icons.push_pin_rounded,
            title: post.isPinned ? 'Unpin from Profile' : 'Pin to Profile',
            onTap: () {
              Navigator.of(context).pop();
              repository.pinPost(post.id);
              UiToast.show(
                context,
                title: post.isPinned ? 'Unpinned' : 'Pinned to Profile',
                message: post.isPinned
                    ? 'Post unpinned from your profile.'
                    : 'Post pinned to the top of your profile.',
                intent: UiIntent.success,
              );
            },
          ),
          UiDivider(),
          _optionRow(
            context,
            icon: Icons.delete_outline_rounded,
            title: 'Delete Post',
            isDestructive: true,
            onTap: () {
              Navigator.of(context).pop();
              _confirmDelete(context);
            },
          ),
        ] else ...<Widget>[
          // Viewer Options
          _optionRow(
            context,
            icon: Icons.visibility_off_outlined,
            title: 'Not Interested in this post',
            onTap: () {
              Navigator.of(context).pop();
              UiToast.show(
                context,
                title: 'Feedback Received',
                message: 'We will show fewer posts like this.',
                intent: UiIntent.info,
              );
            },
          ),
          _optionRow(
            context,
            icon: Icons.volume_off_outlined,
            title: 'Mute @${post.author.handle}',
            onTap: () {
              Navigator.of(context).pop();
              repository.muteUser(post.author.id);
              UiToast.show(
                context,
                title: 'User Muted',
                message: 'You will no longer see posts from @${post.author.handle}.',
                intent: UiIntent.info,
              );
            },
          ),
          _optionRow(
            context,
            icon: Icons.block_flipped,
            title: 'Block @${post.author.handle}',
            isDestructive: true,
            onTap: () {
              Navigator.of(context).pop();
              repository.blockUser(post.author.id);
              UiToast.show(
                context,
                title: 'User Blocked',
                message: '@${post.author.handle} has been blocked.',
                intent: UiIntent.danger,
              );
            },
          ),
          UiDivider(),
          _optionRow(
            context,
            icon: Icons.flag_outlined,
            title: 'Report Post',
            isDestructive: true,
            onTap: () {
              Navigator.of(context).pop();
              CommunityReportDialog.show(
                context,
                postId: post.id,
                repository: repository,
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _optionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final UiTheme theme = context.ui;
    final color = isDestructive ? theme.colors.danger : theme.colors.foreground;

    return InkWell(
      onTap: onTap,
      borderRadius: context.radius(theme.radii.md),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.sm),
          vertical: context.sp(theme.spacing.sm),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: context.sz(20), color: color),
            SizedBox(width: context.sp(theme.spacing.md)),
            Text(
              title,
              style: context.uiText.bodyStrong.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: ctx.uiColors.surface,
        title: const Text('Delete Post?'),
        content: const Text(
          'This action cannot be undone. This post will be permanently removed from your feed and profile.',
        ),
        actions: <Widget>[
          UiButton(
            label: 'Cancel',
            variant: UiVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          UiButton(
            label: 'Delete',
            variant: UiVariant.destructive,
            onPressed: () {
              repository.deletePost(post.id);
              Navigator.of(ctx).pop();
              onDelete?.call();
              UiToast.show(
                context,
                title: 'Post Deleted',
                message: 'Post was removed.',
                intent: UiIntent.info,
              );
            },
          ),
        ],
      ),
    );
  }
}
