import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/public_workspace_attachment.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';
import 'package:tradex/features/community/presentation/widgets/community_highlighted_text.dart';

/// Boxed nested-post preview widget representing a quoted tweet/post.
class CommunityQuoteCard extends StatelessWidget {
  const CommunityQuoteCard({
    super.key,
    required this.post,
    this.onTap,
    this.onAuthorTap,
    this.onOpenRef,
    this.onTagTap,
  });

  final CommunityPost post;
  final VoidCallback? onTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final ValueChanged<String>? onTagTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final author = post.author;
    final verifiedColor = author.verifiedColor(theme);
    final String timeAgo = AppTokens.relativeTime(post.createdAt);

    return CommunityTile(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Mini Author Row
          Row(
            children: <Widget>[
              UiAvatar(
                name: author.displayName,
                imageUrl: author.avatarUrl,
                size: UiSize.xs,
                verified: author.verified,
                verifiedColor: verifiedColor,
                onTap: onAuthorTap == null ? null : () => onAuthorTap!(author),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Flexible(
                child: GestureDetector(
                  onTap: onAuthorTap == null
                      ? null
                      : () => onAuthorTap!(author),
                  child: Text(
                    author.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.bodyStrong.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: context.fs(12),
                      color: theme.colors.foreground,
                    ),
                  ),
                ),
              ),
              if (author.verified) ...<Widget>[
                const SizedBox(width: 3),
                Icon(
                  Icons.verified_rounded,
                  color: verifiedColor,
                  size: context.sz(13),
                ),
              ],
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Text(
                '@${author.handle} · $timeAgo',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                  fontSize: context.fs(11),
                ),
              ),
            ],
          ),

          // Quoted post text
          if (post.body.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            CommunityHighlightedText(
              text: post.body,
              onTagTap: onTagTap,
              style: context.uiText.body.copyWith(
                fontSize: context.fs(13),
                height: 1.35,
                color: theme.colors.foreground,
              ),
            ),
          ],

          // Quoted attachment (if any)
          if (post.attachment != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            PublicWorkspaceAttachment(
              attachment: post.attachment!,
              dense: true,
              onTap: onOpenRef != null
                  ? () => onOpenRef!(
                      post.attachment!.source.copyWith(isPublicContext: true),
                    )
                  : onTap,
            ),
          ],

          // Quoted image (if any)
          if (post.imageUrl != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            ClipRRect(
              borderRadius: context.radius(theme.radii.sm),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: UiRemoteImage(
                  url: post.imageUrl!,
                  semanticLabel: 'Quoted image by @${author.handle}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
