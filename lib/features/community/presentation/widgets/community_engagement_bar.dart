import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Reusable Twitter/Threads-grade engagement action bar for community posts.
///
/// Features distinct desktop vs mobile layouts:
/// - Desktop: Spaced layout with clear icons, action tooltips, and counts.
/// - Mobile: 44px minimum touch targets with compact numbers for thumb comfort.
///
/// Colored active & hover styling per action:
/// - Reply: Primary/Info blue
/// - Repost: Bullish green
/// - Like: Heart red / destructive accent
/// - Bookmark: Amber / warning gold
/// - Views & Share: Primary / subtle foreground
class CommunityEngagementBar extends StatelessWidget {
  const CommunityEngagementBar({
    super.key,
    required this.comments,
    required this.reposts,
    required this.likes,
    required this.views,
    required this.liked,
    required this.reposted,
    required this.bookmarked,
    this.onReply,
    this.onRepost,
    this.onLike,
    this.onBookmark,
    this.onShare,
    this.onViewStats,
    this.showBorder = true,
  });

  final int comments;
  final int reposts;
  final int likes;
  final int views;
  final bool liked;
  final bool reposted;
  final bool bookmarked;
  final VoidCallback? onReply;
  final VoidCallback? onRepost;
  final VoidCallback? onLike;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onViewStats;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;

    final List<Widget> primaryMetrics = <Widget>[
      // Reply / Comments
      CommunityEngagementButton(
        icon: Icons.chat_bubble_outline_rounded,
        count: comments > 0 ? uiCompactNumber(comments) : '',
        tooltip: 'Reply',
        activeColor: theme.colors.primary,
        hoverColor: theme.colors.primary.withValues(alpha: 0.06),
        onTap: onReply,
        isMobile: isMobile,
      ),

      // Repost / Retweet
      CommunityEngagementButton(
        icon: Icons.repeat_rounded,
        count: reposts > 0 ? uiCompactNumber(reposts) : '',
        tooltip: 'Repost',
        isActive: reposted,
        activeColor: theme.colors.bullish,
        hoverColor: theme.colors.bullish.withValues(alpha: 0.06),
        onTap: onRepost,
        isMobile: isMobile,
      ),

      // Like / Heart
      CommunityEngagementButton(
        icon: liked
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        count: likes > 0 ? uiCompactNumber(likes) : '',
        tooltip: liked ? 'Unlike' : 'Like',
        isActive: liked,
        activeColor: Colors.redAccent,
        hoverColor: Colors.redAccent.withValues(alpha: 0.06),
        onTap: onLike,
        isMobile: isMobile,
      ),

      // Views / Impressions
      CommunityEngagementButton(
        icon: Icons.bar_chart_rounded,
        count: views > 0 ? uiCompactNumber(views) : '',
        tooltip: 'Views',
        activeColor: theme.colors.primary,
        hoverColor: theme.colors.primary.withValues(alpha: 0.06),
        onTap: onViewStats,
        isMobile: isMobile,
      ),
    ];

    final Widget bookmarkButton = CommunityEngagementButton(
      icon: bookmarked
          ? Icons.bookmark_rounded
          : Icons.bookmark_border_rounded,
      count: '',
      tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
      isActive: bookmarked,
      activeColor: theme.colors.warning,
      hoverColor: theme.colors.warning.withValues(alpha: 0.06),
      onTap: onBookmark,
      isMobile: isMobile,
    );

    final Widget shareButton = CommunityEngagementButton(
      icon: Icons.ios_share_rounded,
      count: '',
      tooltip: 'Share',
      activeColor: theme.colors.primary,
      hoverColor: theme.colors.primary.withValues(alpha: 0.06),
      onTap: onShare,
      isMobile: isMobile,
    );

    return Container(
      padding: EdgeInsets.only(
        top: context.sp(theme.spacing.xs),
        bottom: context.sp(theme.spacing.xxs),
      ),
      decoration: showBorder
          ? BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colors.border.withValues(alpha: 0.6),
                  width: theme.borders.hairline,
                ),
              ),
            )
          : null,
      child: LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints constraints) {
          final bool isCompact = isMobile || constraints.maxWidth < 560;
          if (isCompact) {
            return Row(
              children: <Widget>[
                Expanded(child: primaryMetrics[0]),
                Expanded(child: primaryMetrics[1]),
                Expanded(child: primaryMetrics[2]),
                Expanded(child: primaryMetrics[3]),
                Expanded(child: bookmarkButton),
                Expanded(child: shareButton),
              ],
            );
          }

          return Row(
            children: <Widget>[
              // Primary metrics spaced evenly up to 440px max width
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: primaryMetrics,
                  ),
                ),
              ),
              const Spacer(),
              // Utility actions grouped neatly on the far right
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  bookmarkButton,
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  shareButton,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Individual action button inside the engagement bar.
class CommunityEngagementButton extends StatelessWidget {
  const CommunityEngagementButton({
    super.key,
    required this.icon,
    required this.count,
    required this.tooltip,
    required this.activeColor,
    this.hoverColor,
    this.isActive = false,
    this.onTap,
    this.isMobile = false,
  });

  final IconData icon;
  final String count;
  final String tooltip;
  final Color activeColor;
  final Color? hoverColor;
  final bool isActive;
  final VoidCallback? onTap;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color color = isActive ? activeColor : theme.colors.foregroundMuted;

    return UiInteractive(
      onTap: onTap,
      builder: (BuildContext ctx, UiInteractiveState state) {
        final bool isHovered = state.hovered;
        final Color effectiveColor = (isActive || isHovered)
            ? activeColor
            : color;

        return Tooltip(
          message: tooltip,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 2 : 8,
              vertical: 4,
            ),
            constraints: isMobile
                ? const BoxConstraints(minHeight: 38)
                : const BoxConstraints(minHeight: 32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isHovered
                  ? (hoverColor ?? activeColor.withValues(alpha: 0.05))
                  : Colors.transparent,
              borderRadius: context.radius(theme.radii.sm),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    icon,
                    size: isMobile ? ctx.sz(16) : ctx.sz(17),
                    color: effectiveColor,
                  ),
                  if (count.isNotEmpty) ...<Widget>[
                    SizedBox(width: isMobile ? 3 : ctx.sp(theme.spacing.xxs)),
                    Text(
                      count,
                      style: ctx.uiText.caption.copyWith(
                        color: effectiveColor,
                        fontSize: isMobile ? ctx.fs(11.5) : ctx.fs(12),
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
