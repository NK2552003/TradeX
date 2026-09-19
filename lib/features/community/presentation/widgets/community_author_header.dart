import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_author_popover.dart';

/// Reusable author header atom for community posts, quotes, and comments.
///
/// Adapts responsively: renders an inline flow on desktop/wide views and a stacked
/// layout (author name over handle · time) on mobile compact screens.
class CommunityAuthorHeader extends StatelessWidget {
  const CommunityAuthorHeader({
    super.key,
    required this.author,
    required this.createdAt,
    this.showAvatar = true,
    this.avatarSize = UiSize.md,
    this.onAuthorTap,
    this.onShare,
    this.onBookmark,
    this.bookmarked = false,
    this.onMute,
    this.onReport,
    this.onMoreTap,
  });

  final CommunityAuthor author;
  final DateTime createdAt;
  final bool showAvatar;
  final UiSize avatarSize;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final VoidCallback? onShare;
  final VoidCallback? onBookmark;
  final bool bookmarked;
  final VoidCallback? onMute;
  final VoidCallback? onReport;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    final Color verifiedColor = author.verifiedColor(theme);
    final String timeAgo = AppTokens.relativeTime(createdAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showAvatar) ...<Widget>[
          GestureDetector(
            onLongPress: () {
              CommunityAuthorPopover.show(
                context,
                author: author,
                onViewProfile: onAuthorTap == null ? null : () => onAuthorTap!(author),
              );
            },
            child: UiAvatar(
              name: author.displayName,
              imageUrl: author.avatarUrl,
              size: avatarSize,
              verified: author.verified,
              verifiedColor: verifiedColor,
              onTap: onAuthorTap == null ? null : () => onAuthorTap!(author),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
        ],
        Expanded(
          child: isMobile
              ? _buildStackedMeta(context, theme, verifiedColor, timeAgo)
              : _buildInlineMeta(context, theme, verifiedColor, timeAgo),
        ),
        if (onMoreTap != null)
          UiIconButton(
            icon: Icons.more_horiz_rounded,
            size: UiSize.xs,
            tooltip: 'More options',
            onPressed: onMoreTap,
          )
        else
          _buildOverflowMenu(context),
      ],
    );
  }


  Widget _buildInlineMeta(
    BuildContext context,
    UiTheme theme,
    Color verifiedColor,
    String timeAgo,
  ) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: <Widget>[
        GestureDetector(
          onTap: onAuthorTap == null ? null : () => onAuthorTap!(author),
          child: Text(
            author.displayName,
            style: context.uiText.bodyStrong.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colors.foreground,
            ),
          ),
        ),
        if (author.verified)
          Icon(
            Icons.verified_rounded,
            color: verifiedColor,
            size: context.sz(15),
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
          '@${author.handle}',
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
        Text(
          '· $timeAgo',
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStackedMeta(
    BuildContext context,
    UiTheme theme,
    Color verifiedColor,
    String timeAgo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: GestureDetector(
                onTap: onAuthorTap == null ? null : () => onAuthorTap!(author),
                child: Text(
                  author.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.bodyStrong.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colors.foreground,
                  ),
                ),
              ),
            ),
            if (author.verified) ...<Widget>[
              const SizedBox(width: 4),
              Icon(
                Icons.verified_rounded,
                color: verifiedColor,
                size: context.sz(14),
              ),
            ],
            if (author.userRole != UserRole.customer) ...<Widget>[
              const SizedBox(width: 4),
              UiBadge(
                label: author.roleBadgeText,
                intent: author.userRole == UserRole.userAdmin
                    ? UiIntent.danger
                    : UiIntent.warning,
                variant: UiBadgeVariant.solid,
                size: UiSize.xs,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '@${author.handle} · $timeAgo',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
            fontSize: context.fs(11),
          ),
        ),
      ],
    );
  }

  Widget _buildOverflowMenu(BuildContext context) {
    return UiDropdownMenu(
      actions: <UiMenuItem>[
        if (onShare != null)
          UiMenuItem(
            label: 'Copy link to post',
            icon: Icons.link_rounded,
            onPressed: onShare!,
          ),
        if (onBookmark != null)
          UiMenuItem(
            label: bookmarked ? 'Remove bookmark' : 'Bookmark post',
            icon: bookmarked
                ? Icons.bookmark_remove_rounded
                : Icons.bookmark_add_rounded,
            onPressed: onBookmark!,
          ),
        UiMenuItem(
          label: 'Mute @${author.handle}',
          icon: Icons.volume_off_outlined,
          onPressed: onMute ?? () {},
        ),
        UiMenuItem(
          label: 'Report post',
          icon: Icons.flag_outlined,
          onPressed: onReport ?? () {},
        ),
      ],
      child: UiIconButton(
        icon: Icons.more_horiz_rounded,
        size: UiSize.xs,
        tooltip: 'More options',
        onPressed: null,
      ),
    );
  }
}
