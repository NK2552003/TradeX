import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/models/community_models.dart';

/// Modal dialog / sheet prompting the trader between instant Repost and Quote Post.
class CommunityRepostDialog extends StatelessWidget {
  const CommunityRepostDialog({
    super.key,
    required this.post,
    required this.onRepost,
    required this.onQuote,
  });

  final CommunityPost post;
  final VoidCallback onRepost;
  final VoidCallback onQuote;

  static Future<void> show(
    BuildContext context, {
    required CommunityPost post,
    required VoidCallback onRepost,
    required VoidCallback onQuote,
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
          child: CommunityRepostDialog(
            post: post,
            onRepost: () {
              Navigator.of(ctx).pop();
              onRepost();
            },
            onQuote: () {
              Navigator.of(ctx).pop();
              onQuote();
            },
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

        // Repost option
        InkWell(
          onTap: onRepost,
          borderRadius: context.radius(theme.radii.md),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.sm),
              vertical: context.sp(theme.spacing.md),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.repeat_rounded,
                  size: context.sz(20),
                  color: post.reposted
                      ? theme.colors.success
                      : theme.colors.foreground,
                ),
                SizedBox(width: context.sp(theme.spacing.md)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      post.reposted ? 'Undo Repost' : 'Repost',
                      style: context.uiText.bodyStrong.copyWith(
                        fontWeight: FontWeight.w700,
                        color: post.reposted
                            ? theme.colors.success
                            : theme.colors.foreground,
                      ),
                    ),
                    Text(
                      post.reposted
                          ? 'Remove this post from your profile'
                          : 'Instantly share this setup to your followers',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        UiDivider(),

        // Quote option
        InkWell(
          onTap: onQuote,
          borderRadius: context.radius(theme.radii.md),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.sm),
              vertical: context.sp(theme.spacing.md),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.edit_note_rounded,
                  size: context.sz(20),
                  color: theme.colors.foreground,
                ),
                SizedBox(width: context.sp(theme.spacing.md)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Quote Post',
                      style: context.uiText.bodyStrong.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colors.foreground,
                      ),
                    ),
                    Text(
                      'Add your own commentary or analysis before sharing',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
