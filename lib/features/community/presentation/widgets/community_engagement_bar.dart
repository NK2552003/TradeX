import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Reusable Twitter/Threads-grade engagement action bar for community posts
/// with rich emoji reactions support (👍, 🚀, 💡, 🔥, ❤️).
class CommunityEngagementBar extends StatefulWidget {
  const CommunityEngagementBar({
    super.key,
    required this.comments,
    required this.reposts,
    required this.likes,
    required this.views,
    required this.liked,
    required this.reposted,
    required this.bookmarked,
    this.userReaction,
    this.onReply,
    this.onRepost,
    this.onLike,
    this.onReact,
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
  final String? userReaction;
  final VoidCallback? onReply;
  final VoidCallback? onRepost;
  final VoidCallback? onLike;
  final ValueChanged<String>? onReact;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onViewStats;
  final bool showBorder;

  @override
  State<CommunityEngagementBar> createState() => _CommunityEngagementBarState();
}

class _CommunityEngagementBarState extends State<CommunityEngagementBar> {
  bool _showReactionPicker = false;

  static const List<Map<String, String>> _availableReactions = [
    {'emoji': '👍', 'label': 'Like'},
    {'emoji': '🚀', 'label': 'Bullish'},
    {'emoji': '💡', 'label': 'Insightful'},
    {'emoji': '🔥', 'label': 'Fire'},
    {'emoji': '❤️', 'label': 'Love'},
  ];

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;

    final String? activeEmoji =
        (widget.liked &&
            widget.userReaction != null &&
            widget.userReaction != '👍')
        ? widget.userReaction
        : null;

    final likeButton = CommunityEngagementButton(
      icon: widget.liked
          ? Icons.favorite_rounded
          : Icons.favorite_border_rounded,
      emoji: activeEmoji,
      count: widget.likes > 0 ? uiCompactNumber(widget.likes) : '',
      tooltip: widget.liked ? 'Unlike' : 'Like',
      isActive: widget.liked,
      activeColor: Colors.redAccent,
      hoverColor: Colors.redAccent.withValues(alpha: 0.06),
      onTap: widget.onLike,
      isMobile: isMobile,
    );
    final reactionButton = CommunityEngagementButton(
      icon: _showReactionPicker
          ? Icons.close_rounded
          : Icons.add_reaction_outlined,
      count: '',
      tooltip: 'React',
      activeColor: theme.colors.primary,
      isActive: _showReactionPicker,
      onTap: () => setState(() => _showReactionPicker = !_showReactionPicker),
      isMobile: isMobile,
    );

    final List<Widget> primaryMetrics = <Widget>[
      // Reply / Comments
      CommunityEngagementButton(
        icon: Icons.chat_bubble_outline_rounded,
        count: widget.comments > 0 ? uiCompactNumber(widget.comments) : '',
        tooltip: 'Reply',
        activeColor: theme.colors.primary,
        hoverColor: theme.colors.primary.withValues(alpha: 0.06),
        onTap: widget.onReply,
        isMobile: isMobile,
      ),

      // Repost / Retweet
      CommunityEngagementButton(
        icon: Icons.repeat_rounded,
        count: widget.reposts > 0 ? uiCompactNumber(widget.reposts) : '',
        tooltip: 'Repost',
        isActive: widget.reposted,
        activeColor: theme.colors.bullish,
        hoverColor: theme.colors.bullish.withValues(alpha: 0.06),
        onTap: widget.onRepost,
        isMobile: isMobile,
      ),

      // Like / Reaction
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [likeButton, reactionButton],
      ),

      // Views / Impressions
      CommunityEngagementButton(
        icon: Icons.bar_chart_rounded,
        count: widget.views > 0 ? uiCompactNumber(widget.views) : '',
        tooltip: 'Views',
        activeColor: theme.colors.primary,
        hoverColor: theme.colors.primary.withValues(alpha: 0.06),
        onTap: widget.onViewStats,
        isMobile: isMobile,
      ),
    ];

    final Widget bookmarkButton = CommunityEngagementButton(
      icon: widget.bookmarked
          ? Icons.bookmark_rounded
          : Icons.bookmark_border_rounded,
      count: '',
      tooltip: widget.bookmarked ? 'Remove bookmark' : 'Bookmark',
      isActive: widget.bookmarked,
      activeColor: theme.colors.warning,
      hoverColor: theme.colors.warning.withValues(alpha: 0.06),
      onTap: widget.onBookmark,
      isMobile: isMobile,
    );

    final Widget shareButton = CommunityEngagementButton(
      icon: Icons.ios_share_rounded,
      count: '',
      tooltip: 'Share',
      activeColor: theme.colors.primary,
      hoverColor: theme.colors.primary.withValues(alpha: 0.06),
      onTap: widget.onShare,
      isMobile: isMobile,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showReactionPicker) ...[
          Container(
            margin: EdgeInsets.only(bottom: context.sp(theme.spacing.xxs)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colors.surface,
              borderRadius: context.radius(theme.radii.pill),
              border: Border.all(
                color: theme.colors.border.withValues(alpha: 0.8),
                width: theme.borders.hairline,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _availableReactions.map((r) {
                final emoji = r['emoji']!;
                final label = r['label']!;
                final isSelected = widget.liked && widget.userReaction == emoji;
                return Tooltip(
                  message: label,
                  child: InkWell(
                    onTap: () {
                      widget.onReact?.call(emoji);
                      setState(() => _showReactionPicker = false);
                    },
                    borderRadius: context.radius(theme.radii.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: isSelected
                          ? BoxDecoration(
                              color: theme.colors.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: context.radius(theme.radii.pill),
                            )
                          : null,
                      child: Text(
                        emoji,
                        style: TextStyle(
                          fontSize: isMobile ? context.fs(16) : context.fs(18),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        Container(
          padding: EdgeInsets.only(
            top: context.sp(theme.spacing.xs),
            bottom: context.sp(theme.spacing.xxs),
          ),
          decoration: widget.showBorder
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
                    Expanded(child: likeButton),
                    Expanded(child: reactionButton),
                    Expanded(child: primaryMetrics[3]),
                    Expanded(child: bookmarkButton),
                    Expanded(child: shareButton),
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 460,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: primaryMetrics,
                        ),
                      ),
                    ),
                  ),
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
        ),
      ],
    );
  }
}

/// Individual action button inside the engagement bar.
class CommunityEngagementButton extends StatelessWidget {
  const CommunityEngagementButton({
    super.key,
    required this.icon,
    this.emoji,
    required this.count,
    required this.tooltip,
    required this.activeColor,
    this.hoverColor,
    this.isActive = false,
    this.onTap,
    this.isMobile = false,
  });

  final IconData icon;
  final String? emoji;
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
                  if (emoji != null && emoji!.isNotEmpty)
                    Text(
                      emoji!,
                      style: TextStyle(
                        fontSize: isMobile ? ctx.fs(14) : ctx.fs(15),
                      ),
                    )
                  else
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
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
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
