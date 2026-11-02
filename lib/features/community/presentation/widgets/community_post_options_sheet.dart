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
    this.onQuote,
  });

  final CommunityPost post;
  final CommunityRepository repository;
  final bool isAuthor;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final ValueChanged<CommunityPost>? onQuote;

  static Future<void> show(
    BuildContext context, {
    required CommunityPost post,
    required CommunityRepository repository,
    required bool isAuthor,
    VoidCallback? onDelete,
    VoidCallback? onEdit,
    ValueChanged<CommunityPost>? onQuote,
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
            onQuote: onQuote,
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
              final host = Navigator.of(context).context;
              Navigator.of(context).pop();
              _confirmDelete(host);
            },
          ),
        ] else ...<Widget>[
          // Viewer Options
          _optionRow(
            context,
            icon: Icons.format_quote_rounded,
            title: 'Quote Post',
            onTap: () {
              Navigator.of(context).pop();
              onQuote?.call(post);
            },
          ),
          _optionRow(
            context,
            icon: Icons.visibility_off_outlined,
            title: 'Not Interested in this post',
            subtitle: 'Unavailable in preview',
            isUnavailable: true,
            onTap: null,
          ),
          () {
            final isMuted = repository.mutedUsers.contains(post.author.id);
            return _optionRow(
              context,
              icon: isMuted ? Icons.volume_up_outlined : Icons.volume_off_outlined,
              title: isMuted
                  ? 'Unmute ${post.author.displayHandle}'
                  : 'Mute ${post.author.displayHandle}',
              onTap: () {
                Navigator.of(context).pop();
                if (isMuted) {
                  repository.unmuteUser(post.author.id);
                  UiToast.show(
                    context,
                    title: 'Unmuted',
                    message: '${post.author.displayHandle} has been unmuted.',
                    intent: UiIntent.info,
                  );
                } else {
                  repository.muteUser(post.author.id);
                  UiToast.show(
                    context,
                    title: 'Muted for this session',
                    message:
                        'You will no longer see posts from ${post.author.displayHandle}.',
                    intent: UiIntent.info,
                  );
                }
              },
            );
          }(),
          _optionRow(
            context,
            icon: Icons.block_flipped,
            title: 'Block ${post.author.displayHandle}',
            isDestructive: true,
            onTap: () async {
              Navigator.of(context).pop();
              try {
                await repository.blockUser(post.author.id);
                if (!context.mounted) return;
                UiToast.show(
                  context,
                  title: 'User Blocked',
                  message:
                      'Posts from ${post.author.displayHandle} are hidden.',
                  intent: UiIntent.danger,
                );
              } catch (e) {
                if (!context.mounted) return;
                UiToast.show(
                  context,
                  title: 'Action Failed',
                  message: 'Failed to block user: $e',
                  intent: UiIntent.danger,
                );
              }
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
    String? subtitle,
    VoidCallback? onTap,
    bool isDestructive = false,
    bool isUnavailable = false,
  }) {
    final UiTheme theme = context.ui;
    final color = isUnavailable
        ? theme.colors.foregroundMuted.withValues(alpha: 0.5)
        : (isDestructive ? theme.colors.danger : theme.colors.foreground);

    return InkWell(
      onTap: isUnavailable ? null : onTap,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: context.uiText.bodyStrong.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: context.sp(theme.spacing.xxs)),
                    Text(
                      subtitle,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted.withValues(alpha: 0.6),
                        fontSize: context.fs(11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isUnavailable)
              UiBadge(
                label: 'Unavailable',
                size: UiSize.xs,
                intent: UiIntent.neutral,
                variant: UiBadgeVariant.soft,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final accepted = await UiDialog.confirm(
      context,
      title: 'Delete this post?',
      description:
          'The post and its discussion will be removed. Attached workspace records are kept.',
      confirmLabel: 'Delete',
    );
    if (!accepted || !context.mounted) return;
    try {
      await repository.deletePost(post.id);
      onDelete?.call();
      if (context.mounted) {
        UiToast.success(
          context,
          title: 'Post deleted',
          message: 'The post has been removed.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        UiToast.error(
          context,
          title: 'Post was not deleted',
          message: '$error',
        );
      }
    }
  }
}
