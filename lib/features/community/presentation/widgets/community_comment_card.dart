import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_composer_pickers.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_highlighted_text.dart';

/// Reusable comment / reply row supporting threaded indents, author verification,
/// highlighted text ($TICKER, #tags), like action with counter, and reply button.
class CommunityCommentCard extends StatelessWidget {
  const CommunityCommentCard({
    super.key,
    required this.comment,
    this.onLike,
    this.onReply,
    this.onAuthorTap,
    this.onTagTap,
    this.indent = 0,
  });

  final CommunityComment comment;
  final VoidCallback? onLike;
  final VoidCallback? onReply;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<String>? onTagTap;
  final int indent;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final author = comment.author;
    final verifiedColor = author.verifiedColor(theme);
    final double indentPadding = indent > 0 ? (indent.clamp(1, 4) * 16.0) : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        left: indentPadding,
        top: context.sp(theme.spacing.xxs),
        bottom: context.sp(theme.spacing.xxs),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Threads-style indent guide if indented
              if (indent > 0) ...<Widget>[
                Container(
                  width: 2,
                  height: context.sz(32),
                  margin: EdgeInsets.only(right: context.sp(theme.spacing.xs)),
                  color: theme.colors.border.withValues(alpha: 0.5),
                ),
              ],

              // Author Avatar
              UiAvatar(
                name: author.displayName,
                imageUrl: author.avatarUrl,
                size: indent > 0 ? UiSize.xs : UiSize.sm,
                verified: author.verified,
                verifiedColor: verifiedColor,
                onTap: onAuthorTap == null ? null : () => onAuthorTap!(author),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),

              // Content Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Author Header Row
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: context.sp(theme.spacing.xxs),
                      children: <Widget>[
                        UiInteractive(
                          onTap: onAuthorTap == null
                              ? null
                              : () => onAuthorTap!(author),
                          builder: (context, _) => Text(
                            author.displayHandle,
                            style: context.uiText.bodyStrong.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: context.fs(13),
                              color: theme.colors.foreground,
                            ),
                          ),
                        ),
                        if (author.verified)
                          Icon(
                            Icons.verified_rounded,
                            color: verifiedColor,
                            size: context.sz(14),
                          ),
                        if (author.userRole != UserRole.customer)
                          UiBadge(
                            label: author.roleBadgeText,
                            intent: author.userRole == UserRole.userAdmin
                                ? UiIntent.danger
                                : UiIntent.warning,
                            variant: UiBadgeVariant.solid,
                            size: UiSize.xs,
                          ),
                        Text(
                          '·',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundSubtle,
                          ),
                        ),
                        Text(
                          AppTokens.relativeTime(comment.createdAt),
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundSubtle,
                            fontSize: context.fs(12),
                          ),
                        ),
                      ],
                    ),

                    // Comment Body
                    Padding(
                      padding: EdgeInsets.only(
                        top: context.sp(theme.spacing.xxs),
                      ),
                      child: CommunityHighlightedText(
                        text: CommunityCommentLinkCodec.strip(comment.body),
                        style: context.uiText.body.copyWith(
                          fontSize: context.fs(13),
                          height: 1.4,
                        ),
                        onTagTap: onTagTap,
                      ),
                    ),

                    // Actions Row (Like & Reply)
                    Padding(
                      padding: EdgeInsets.only(
                        top: context.sp(theme.spacing.xxs),
                      ),
                      child: Row(
                        children: <Widget>[
                          // Like button
                          InkWell(
                            onTap: onLike,
                            borderRadius: context.radius(theme.radii.sm),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.sp(theme.spacing.xxs),
                                vertical: context.sp(theme.spacing.xxs),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    comment.liked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: context.sz(14),
                                    color: comment.liked
                                        ? theme.colors.danger
                                        : theme.colors.foregroundMuted,
                                  ),
                                  if (comment.likes > 0) ...<Widget>[
                                    const SizedBox(width: 4),
                                    Text(
                                      '${comment.likes}',
                                      style: context.uiText.caption.copyWith(
                                        color: comment.liked
                                            ? theme.colors.danger
                                            : theme.colors.foregroundMuted,
                                        fontSize: context.fs(11),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: context.sp(theme.spacing.md)),

                          // Reply button
                          if (onReply != null)
                            InkWell(
                              onTap: onReply,
                              borderRadius: context.radius(theme.radii.sm),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.sp(theme.spacing.xxs),
                                  vertical: context.sp(theme.spacing.xxs),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: context.sz(13),
                                      color: theme.colors.foregroundMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Reply',
                                      style: context.uiText.caption.copyWith(
                                        color: theme.colors.foregroundMuted,
                                        fontSize: context.fs(11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Render nested replies if present
          if (comment.replies.isNotEmpty) ...<Widget>[
            for (final reply in comment.replies)
              CommunityCommentCard(
                comment: reply,
                onLike: onLike,
                onReply: onReply,
                onAuthorTap: onAuthorTap,
                onTagTap: onTagTap,
                indent: indent + 1,
              ),
          ],
        ],
      ),
    );
  }
}
