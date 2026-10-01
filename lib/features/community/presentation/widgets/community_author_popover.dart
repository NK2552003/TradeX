import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/models/community_models.dart';

/// Interactive profile popover card displayed on author hover or long-press.
class CommunityAuthorPopover extends StatelessWidget {
  const CommunityAuthorPopover({
    super.key,
    required this.author,
    this.onFollow,
    this.onViewProfile,
  });

  final CommunityAuthor author;
  final VoidCallback? onFollow;
  final VoidCallback? onViewProfile;

  static void show(
    BuildContext context, {
    required CommunityAuthor author,
    VoidCallback? onFollow,
    VoidCallback? onViewProfile,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Container(
        padding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
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
        child: SafeArea(
          child: CommunityAuthorPopover(
            author: author,
            onFollow: () {
              onFollow?.call();
              Navigator.of(ctx).pop();
            },
            onViewProfile: () {
              Navigator.of(ctx).pop();
              onViewProfile?.call();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color verifiedColor = author.verifiedColor(theme);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Top header: Avatar + Name + Follow button
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            UiAvatar(
              name: author.displayName,
              imageUrl: author.avatarUrl,
              size: UiSize.lg,
              verified: author.verified,
              verifiedColor: verifiedColor,
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          author.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.bodyStrong.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: context.fs(15),
                            color: theme.colors.foreground,
                          ),
                        ),
                      ),
                      if (author.verified) ...<Widget>[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          color: verifiedColor,
                          size: context.sz(16),
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
                  Text(
                    '@${author.handle}',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                      fontSize: context.fs(12),
                    ),
                  ),
                ],
              ),
            ),
            if (onFollow != null)
              UiIconButton(
                icon: author.isFollowing
                    ? Icons.check_rounded
                    : Icons.person_add_rounded,
                variant: author.isFollowing
                    ? UiVariant.outline
                    : UiVariant.primary,
                size: UiSize.sm,
                tooltip: author.isFollowing
                    ? 'Following @${author.handle}'
                    : 'Follow @${author.handle}',
                onPressed: onFollow,
              ),
          ],
        ),

        // Bio
        if (author.bio != null && author.bio!.isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(
            author.bio!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.body.copyWith(
              fontSize: context.fs(13),
              height: 1.4,
              color: theme.colors.foreground,
            ),
          ),
        ],

        // Performance / stats row
        SizedBox(height: context.sp(theme.spacing.md)),
        Row(
          children: <Widget>[
            Text(
              '${uiCompactNumber(author.followers)} Followers',
              style: context.uiText.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colors.foreground,
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.md)),
            Text(
              '${uiCompactNumber(author.following)} Following',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
            const Spacer(),
            if (author.winRate != null)
              UiBadge(
                label: '${author.winRate!.toStringAsFixed(0)}% Win Rate',
                intent: UiIntent.success,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
              ),
          ],
        ),

        // Full profile action
        if (onViewProfile != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.md)),
          UiButton(
            label: 'View Full Profile',
            variant: UiVariant.secondary,
            size: UiSize.sm,
            onPressed: onViewProfile,
          ),
        ],
      ],
    );
  }
}
