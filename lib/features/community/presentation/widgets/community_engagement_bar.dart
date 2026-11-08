import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// LinkedIn-grade engagement action bar for community posts with floating emoji
/// reactions support (👍, 🚀, 💡, 🔥, ❤️).
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
    this.shares = 0,
    this.shared = false,
    this.userReaction,
    this.reactions = const <String>[],
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
  final int shares;
  final bool shared;
  final String? userReaction;
  final List<String> reactions;
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
  final GlobalKey _likeButtonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;

  void _showOverlay() {
    _hideTimer?.cancel();
    if (_overlayEntry != null) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final isMobile = context.uiRes.isMobile;
    if (isMobile) {
      HapticFeedback.lightImpact();
    }

    final RenderBox? box = _likeButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset globalPos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final Size boxSize = box?.size ?? const Size(44, 44);
    final Size screenSize = MediaQuery.sizeOf(context);

    const double pillWidth = 216.0;
    const double pillHeight = 44.0;

    // Center pill horizontally on the like button, clamped to screen edges
    final double left = (globalPos.dx + boxSize.width / 2 - pillWidth / 2)
        .clamp(8.0, (screenSize.width - pillWidth - 8.0).clamp(8.0, 9999.0));

    // Position above like button; if too close to top of screen, flip below
    final double top = globalPos.dy > pillHeight + 12
        ? globalPos.dy - pillHeight - 8
        : globalPos.dy + boxSize.height + 8;

    final DateTime openedAt = DateTime.now();

    _overlayEntry = OverlayEntry(
      builder: (BuildContext ctx) {
        return Stack(
          children: <Widget>[
            // Mobile tap-outside barrier to dismiss cleanly without closing on initial touch release
            if (isMobile)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (DateTime.now().difference(openedAt).inMilliseconds > 350) {
                      _hideOverlay();
                    }
                  },
                ),
              ),
            Positioned(
              left: left,
              top: top,
              width: pillWidth,
              child: _LinkedInReactionPill(
                selectedEmoji: widget.liked ? widget.userReaction : null,
                onSelect: (String emoji) {
                  widget.onReact?.call(emoji);
                  _hideOverlay();
                },
                onHoverEnter: () => _hideTimer?.cancel(),
                onHoverExit: isMobile ? () {} : _scheduleHide,
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 250), () {
      _hideOverlay();
    });
  }

  void _hideOverlay({bool rebuild = true}) {
    _hideTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (rebuild && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _hideOverlay(rebuild: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;

    final List<String> effectiveReactions = <String>[];
    if (widget.liked &&
        widget.userReaction != null &&
        widget.userReaction!.trim().isNotEmpty) {
      effectiveReactions.add(widget.userReaction!.trim());
    }
    for (final r in widget.reactions) {
      final clean = r.trim();
      if (clean.isNotEmpty && !effectiveReactions.contains(clean)) {
        effectiveReactions.add(clean);
      }
    }
    if (effectiveReactions.isEmpty && widget.liked) {
      effectiveReactions.add('👍');
    }
    if (widget.likes > effectiveReactions.length &&
        !effectiveReactions.contains('👍')) {
      effectiveReactions.add('👍');
    }

    final String? primaryEmoji =
        effectiveReactions.isNotEmpty ? effectiveReactions.first : null;

    final Color activeColor = switch (primaryEmoji) {
      '❤️' => Colors.redAccent,
      '🔥' => Colors.deepOrangeAccent,
      '🚀' => theme.colors.bullish,
      '💡' => Colors.amber,
      _ => theme.colors.primary,
    };

    // Single unified LinkedIn Like / Reaction button
    final Widget likeButton = KeyedSubtree(
      key: _likeButtonKey,
      child: MouseRegion(
        onEnter: isMobile ? null : (_) => _showOverlay(),
        onExit: isMobile ? null : (_) => _scheduleHide(),
        child: CommunityEngagementButton(
          icon: widget.liked
              ? Icons.thumb_up_alt_rounded
              : Icons.thumb_up_alt_outlined,
          emojis: (widget.liked || widget.likes > 0)
              ? effectiveReactions
              : const <String>[],
          emoji: primaryEmoji,
          count: widget.likes > 0 ? uiCompactNumber(widget.likes) : '',
          tooltip: _overlayEntry != null
              ? ''
              : (widget.liked ? 'Unlike' : 'Like'),
          isActive: widget.liked,
          activeColor: activeColor,
          hoverColor: activeColor.withValues(alpha: 0.08),
          onTap: () {
            _hideOverlay();
            if (widget.liked) {
              widget.onLike?.call();
            } else {
              widget.onReact?.call('👍');
            }
          },
          onLongPress: _showOverlay,
          isMobile: isMobile,
        ),
      ),
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

      // Like / Reaction (Single LinkedIn button)
      likeButton,

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
      count: widget.shares > 0 ? uiCompactNumber(widget.shares) : '',
      tooltip: 'Share',
      isActive: widget.shared,
      activeColor: theme.colors.primary,
      hoverColor: theme.colors.primary.withValues(alpha: 0.06),
      onTap: widget.onShare,
      isMobile: isMobile,
    );

    return Container(
      constraints: BoxConstraints(
        minHeight: isMobile ? 44.0 : 36.0,
        maxHeight: isMobile ? 54.0 : 48.0,
      ),
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
                Expanded(child: primaryMetrics[2]),
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
                    width: 440,
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
    );
  }
}

/// Floating LinkedIn-style reaction pill overlay with smooth hover scale effects.
class _LinkedInReactionPill extends StatefulWidget {
  const _LinkedInReactionPill({
    required this.onSelect,
    required this.onHoverEnter,
    required this.onHoverExit,
    this.selectedEmoji,
  });

  final ValueChanged<String> onSelect;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final String? selectedEmoji;

  @override
  State<_LinkedInReactionPill> createState() => _LinkedInReactionPillState();
}

class _LinkedInReactionPillState extends State<_LinkedInReactionPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  int? _hoveredIndex;

  static const List<Map<String, String>> _reactions = [
    {'emoji': '👍', 'label': 'Like'},
    {'emoji': '🚀', 'label': 'Bullish'},
    {'emoji': '💡', 'label': 'Insightful'},
    {'emoji': '🔥', 'label': 'Fire'},
    {'emoji': '❤️', 'label': 'Love'},
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _opacity = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return MouseRegion(
      onEnter: (_) => widget.onHoverEnter(),
      onExit: (_) => widget.onHoverExit(),
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colors.border.withValues(alpha: 0.8),
                  width: theme.borders.hairline,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(_reactions.length, (int index) {
                  final r = _reactions[index];
                  final emoji = r['emoji']!;
                  final label = r['label']!;
                  final isHovered = _hoveredIndex == index;
                  final isSelected = widget.selectedEmoji == emoji;

                  return MouseRegion(
                    onEnter: (_) => setState(() => _hoveredIndex = index),
                    onExit: (_) => setState(() => _hoveredIndex = null),
                    child: Tooltip(
                      message: label,
                      verticalOffset: 24,
                      child: GestureDetector(
                        onTap: () => widget.onSelect(emoji),
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              curve: Curves.easeOutCubic,
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              transform: Matrix4.diagonal3Values(
                                isHovered ? 1.35 : 1.0,
                                isHovered ? 1.35 : 1.0,
                                1.0,
                              ),
                              transformAlignment: Alignment.center,
                              decoration: isSelected
                                  ? BoxDecoration(
                                      color: theme.colors.foreground.withValues(
                                        alpha: 0.12,
                                      ),
                                      shape: BoxShape.circle,
                                    )
                                  : null,
                              child: Text(
                                emoji,
                                style: const TextStyle(
                                  fontSize: 19,
                                  height: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual action button inside the engagement bar.
class CommunityEngagementButton extends StatelessWidget {
  const CommunityEngagementButton({
    super.key,
    required this.icon,
    this.emoji,
    this.emojis = const <String>[],
    required this.count,
    required this.tooltip,
    required this.activeColor,
    this.hoverColor,
    this.isActive = false,
    this.onTap,
    this.onLongPress,
    this.isMobile = false,
  });

  final IconData icon;
  final String? emoji;
  final List<String> emojis;
  final String count;
  final String tooltip;
  final Color activeColor;
  final Color? hoverColor;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color color = isActive ? activeColor : theme.colors.foregroundMuted;
    final List<String> displayEmojis = emojis.isNotEmpty
        ? emojis
        : (emoji != null && emoji!.isNotEmpty ? <String>[emoji!] : const <String>[]);

    return UiInteractive(
      onTap: onTap,
      onLongPress: onLongPress,
      builder: (BuildContext ctx, UiInteractiveState state) {
        final bool isHovered = state.hovered;
        final Color effectiveColor =
            (isActive || isHovered) ? activeColor : color;

        return Tooltip(
          triggerMode: isMobile
              ? TooltipTriggerMode.manual
              : TooltipTriggerMode.longPress,
          message: tooltip,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 2 : 8,
              vertical: 4,
            ),
            constraints: isMobile
                ? const BoxConstraints(minHeight: 44, minWidth: 44)
                : const BoxConstraints(minHeight: 36, minWidth: 36),
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
                  if (displayEmojis.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (int i = 0; i < displayEmojis.take(3).length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: 2),
                          Text(
                            displayEmojis[i],
                            style: TextStyle(
                              fontSize: isMobile ? ctx.fs(13.5) : ctx.fs(14.5),
                            ),
                          ),
                        ],
                      ],
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
