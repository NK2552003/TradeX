import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/models/community_models.dart';

/// Desktop-grade trader profile card with full bio, stats, and follow action.
class CommunityTraderCard extends StatelessWidget {
  const CommunityTraderCard({
    super.key,
    required this.trader,
    this.onTap,
    this.onFollow,
  });

  final CommunityAuthor trader;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final verifiedColor = trader.verifiedColor(theme);

    return UiCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Mutual connection indicator
          if (trader.mutualFollowers.isNotEmpty) ...<Widget>[
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.people_outline_rounded,
                    size: context.sz(14),
                    color: theme.colors.foregroundSubtle,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  Expanded(
                    child: Text(
                      '${trader.mutualFollowers.first} and others follow',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                        fontSize: context.fs(11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Profile row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              UiAvatar(
                name: trader.displayName,
                imageUrl: trader.avatarUrl,
                size: UiSize.md,
                verified: trader.verified,
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
                            trader.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.bodyStrong.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colors.foreground,
                            ),
                          ),
                        ),
                        if (trader.verified) ...<Widget>[
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                          Icon(
                            Icons.verified_rounded,
                            color: verifiedColor,
                            size: context.sz(15),
                          ),
                        ],
                        if (trader.userRole != UserRole.customer) ...<Widget>[
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                          UiBadge(
                            label: trader.roleBadgeText,
                            intent: trader.userRole == UserRole.userAdmin
                                ? UiIntent.danger
                                : UiIntent.warning,
                            variant: UiBadgeVariant.solid,
                            size: UiSize.xs,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '@${trader.handle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (onFollow != null)
                UiIconButton(
                  icon: trader.isFollowing
                      ? Icons.check_rounded
                      : Icons.person_add_rounded,
                  variant: trader.isFollowing
                      ? UiVariant.outline
                      : UiVariant.primary,
                  size: UiSize.sm,
                  tooltip: trader.isFollowing
                      ? 'Following @${trader.handle}'
                      : 'Follow @${trader.handle}',
                  onPressed: onFollow,
                ),
            ],
          ),

          if (trader.bio != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Text(
              trader.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.body.copyWith(
                color: theme.colors.foregroundMuted,
                fontSize: context.fs(13),
              ),
            ),
          ],

          SizedBox(height: context.sp(theme.spacing.sm)),
          Row(
            children: <Widget>[
              Text(
                '${uiCompactNumber(trader.followers)} Followers',
                style: context.uiText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colors.foreground,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              Text(
                '${uiCompactNumber(trader.following)} Following',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              const Spacer(),
              if (trader.winRate != null)
                UiBadge(
                  label: '${trader.winRate!.toStringAsFixed(0)}% Win Rate',
                  intent: UiIntent.success,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact trader row designed for mobile lists, sidebar widgets, and leaderboard rankings.
class CommunityTraderRow extends StatelessWidget {
  const CommunityTraderRow({
    super.key,
    required this.trader,
    this.rank,
    this.winRate,
    this.onTap,
    this.onFollow,
    this.showBio = true,
  });

  final CommunityAuthor trader;
  final int? rank;
  final double? winRate;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;
  final bool showBio;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final verifiedColor = trader.verifiedColor(theme);

    return InkWell(
      onTap: onTap,
      borderRadius: context.radius(theme.radii.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Mutual connection indicator if available
          if (trader.mutualFollowers.isNotEmpty && rank == null) ...<Widget>[
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xxs)),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.person_outline_rounded,
                    size: context.sz(13),
                    color: theme.colors.foregroundSubtle,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  Expanded(
                    child: Text(
                      '${trader.mutualFollowers.first} and others follow',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                        fontSize: context.fs(11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Leaderboard Rank number
              if (rank != null) ...<Widget>[
                SizedBox(
                  width: context.sz(32),
                  child: Text(
                    '#$rank',
                    style: context.uiText.heading.copyWith(
                      color: _rankColor(theme, rank!),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
              ],

              // Avatar
              UiAvatar(
                name: trader.displayName,
                imageUrl: trader.avatarUrl,
                size: UiSize.sm,
                verified: trader.verified,
                verifiedColor: verifiedColor,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),

              // Trader Name & Handle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            trader.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.bodyStrong.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colors.foreground,
                            ),
                          ),
                        ),
                        if (trader.verified) ...<Widget>[
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                          Icon(
                            Icons.verified_rounded,
                            color: verifiedColor,
                            size: context.sz(14),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '@${trader.handle}${trader.tradingStyle != null ? " · ${trader.tradingStyle}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                        fontSize: context.fs(11),
                      ),
                    ),
                  ],
                ),
              ),

              // Action button or Win Rate Badge
              if (winRate != null) ...<Widget>[
                UiBadge(
                  label: '${winRate!.toStringAsFixed(1)}% Win',
                  intent: (rank != null && rank! <= 3)
                      ? UiIntent.success
                      : UiIntent.primary,
                  variant: UiBadgeVariant.solid,
                  size: UiSize.sm,
                ),
              ] else if (onFollow != null) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.xs)),
                UiIconButton(
                  icon: trader.isFollowing
                      ? Icons.check_rounded
                      : Icons.person_add_rounded,
                  variant: trader.isFollowing
                      ? UiVariant.outline
                      : UiVariant.primary,
                  size: UiSize.sm,
                  tooltip: trader.isFollowing
                      ? 'Following @${trader.handle}'
                      : 'Follow @${trader.handle}',
                  onPressed: onFollow,
                ),
              ],
            ],
          ),

          if (showBio && trader.bio != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xxs)),
            Text(
              trader.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
                fontSize: context.fs(11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _rankColor(UiTheme theme, int rank) {
    return rank == 1
        ? const Color(0xFFFFD700)
        : (rank == 2
              ? const Color(0xFFC0C0C0)
              : (rank == 3
                    ? const Color(0xFFCD7F32)
                    : theme.colors.foregroundMuted));
  }
}
