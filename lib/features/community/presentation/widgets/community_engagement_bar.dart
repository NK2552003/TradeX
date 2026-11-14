import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'community_emoji_picker.dart';

/// LinkedIn-grade engagement action bar for community posts with floating emoji
/// reactions support (👍, 🚀, 💡, 🔥, ❤️).
class CommunityEngagementBar extends StatefulWidget {
  const CommunityEngagementBar({
    super.key,
    required this.comments,
    required this.likes,
    required this.liked,
    required this.reposted,
    this.shared = false,
    this.commentsExpanded = false,
    this.userReaction,
    this.reactions = const <String>[],
    this.onReply,
    this.onRepost,
    this.onLike,
    this.onReact,
    this.onShare,
    this.onShowReactions,
    this.showBorder = true,
  });

  final int comments;
  final int likes;
  final bool liked;
  final bool reposted;
  final bool shared;
  final bool commentsExpanded;
  final String? userReaction;
  final List<String> reactions;
  final VoidCallback? onReply;
  final VoidCallback? onRepost;
  final VoidCallback? onLike;
  final ValueChanged<String>? onReact;
  final VoidCallback? onShare;
  final VoidCallback? onShowReactions;
  final bool showBorder;

  @override
  State<CommunityEngagementBar> createState() => _CommunityEngagementBarState();
}

class _CommunityEngagementBarState extends State<CommunityEngagementBar>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(vsync: this);
  late final _progress = _motion.drive(CurveTween(curve: Curves.easeOutCubic));
  bool _closing = false;
  final GlobalKey _likeButtonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;

  void _showOverlay() {
    _hideTimer?.cancel();
    if (_overlayEntry != null) {
      if (_closing) {
        _closing = false;
        _motion.forward();
        _overlayEntry?.markNeedsBuild();
      }
      return;
    }

    final reduced = MediaQuery.disableAnimationsOf(context);
    _motion.duration = reduced ? Duration.zero : context.ui.motion.normal;
    _motion.reverseDuration = reduced ? Duration.zero : context.ui.motion.fast;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final isMobile = context.uiRes.isMobile;
    if (isMobile) {
      HapticFeedback.lightImpact();
    }

    final RenderBox? box =
        _likeButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlayBox =
        overlay.context.findRenderObject() as RenderBox?;
    final Size boxSize = box?.size ?? const Size(44, 44);
    // Convert into the overlay's own coordinate space. Posts shown inside
    // drawers / side panels live in an offset overlay, so raw global
    // coordinates would place the pill over the blurred page behind them.
    final Offset anchor = (box != null && overlayBox != null)
        ? box.localToGlobal(Offset.zero, ancestor: overlayBox)
        : (box?.localToGlobal(Offset.zero) ?? Offset.zero);
    final Size screenSize = overlayBox?.size ?? MediaQuery.sizeOf(context);

    final double pillWidth = context.sz(240).clamp(0, screenSize.width - 16);
    final double pillHeight =
        context.sz(context.ui.sizes.controlHeightLg) +
        context.sp(context.ui.spacing.xs) * 2 +
        context.ui.borders.hairline * 2;

    // Center pill horizontally on the like button, clamped to overlay edges
    final double left = (anchor.dx + boxSize.width / 2 - pillWidth / 2).clamp(
      8.0,
      (screenSize.width - pillWidth - 8.0).clamp(8.0, 9999.0),
    );

    // Position above like button; if too close to top, flip below
    final double top = anchor.dy > pillHeight + 12
        ? anchor.dy - pillHeight - 8
        : anchor.dy + boxSize.height + 8;

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
                    if (DateTime.now().difference(openedAt).inMilliseconds >
                        350) {
                      _hideOverlay();
                    }
                  },
                ),
              ),
            Positioned(
              left: left,
              top: top,
              width: pillWidth,
              child: FadeTransition(
                opacity: _progress,
                child: ScaleTransition(
                  scale: _progress.drive(Tween(begin: .92, end: 1.0)),
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    ignoring: _closing,
                    child: _LinkedInReactionPill(
                      selectedEmoji: widget.liked ? widget.userReaction : null,
                      onSelect: (String emoji) {
                        widget.onReact?.call(emoji);
                        _hideOverlay();
                      },
                      onHoverEnter: _showOverlay,
                      onHoverExit: isMobile ? () {} : _scheduleHide,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
    _motion.forward(from: 0);
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 250), () {
      _hideOverlay();
    });
  }

  Future<void> _hideOverlay() async {
    _hideTimer?.cancel();
    if (_overlayEntry == null || _closing) return;
    _closing = true;
    _overlayEntry?.markNeedsBuild();
    try {
      await _motion.reverse().orCancel;
      if (!mounted) return;
      _removeOverlay();
      setState(() {});
    } on TickerCanceled {
      // Hovering again or leaving the screen cancels the reverse animation.
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    _closing = false;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeOverlay();
    _motion.dispose();
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
    if (effectiveReactions.isEmpty && (widget.liked || widget.likes > 0)) {
      effectiveReactions.add('👍');
    }

    final activeColor = _reactionColor(context, widget.userReaction ?? '👍');

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
              if (widget.onReact != null) {
                widget.onReact!('👍');
              } else {
                widget.onLike?.call();
              }
            }
          },
          onLongPress: _showOverlay,
          isMobile: isMobile,
        ),
      ),
    );

    final actions = [
      likeButton,
      CommunityEngagementButton(
        icon: widget.commentsExpanded
            ? Icons.chat_bubble_rounded
            : Icons.chat_bubble_outline_rounded,
        count: widget.comments > 0 ? uiCompactNumber(widget.comments) : '',
        tooltip: 'Reply',
        isActive: widget.commentsExpanded,
        activeColor: theme.colors.primary,
        onTap: widget.onReply,
        isMobile: isMobile,
      ),
      CommunityEngagementButton(
        icon: Icons.repeat_rounded,
        count: '',
        tooltip: 'Repost',
        isActive: widget.reposted,
        activeColor: theme.colors.bullish,
        onTap: widget.onRepost,
        isMobile: isMobile,
      ),
      CommunityEngagementButton(
        icon: CupertinoIcons.paperplane,
        count: '',
        tooltip: 'Share',
        isActive: widget.shared,
        activeColor: theme.colors.primary,
        onTap: widget.onShare,
        isMobile: isMobile,
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showBorder) UiDivider(spacing: theme.spacing.none),
        Row(
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ),
            if (widget.likes > 0 && effectiveReactions.isNotEmpty)
              UiButton(
                label: '',
                semanticLabel: 'View reactions',
                leading: SizedBox(
                  height: context.sz(20),
                  child: FittedBox(
                    child: UiAvatarGroup(
                      overlapFraction: .24,
                      avatars: [
                        for (final emoji in effectiveReactions.take(3))
                          _reactionBadge(context, emoji),
                      ],
                    ),
                  ),
                ),
                tooltip: 'View reactions',
                variant: UiVariant.ghost,
                size: UiSize.xs,
                onPressed: widget.onShowReactions,
              ),
          ],
        ),
      ],
    );
  }

  UiAvatar _reactionBadge(BuildContext context, String emoji) {
    final theme = context.ui;
    final colors = theme.colors;
    final (icon, accent) = switch (emoji) {
      '👍' => (Icons.thumb_up_outlined, colors.info),
      '🚀' => (Icons.rocket_launch_outlined, colors.bullish),
      '💡' => (Icons.lightbulb_outline_rounded, colors.warning),
      '🔥' => (
        Icons.local_fire_department_outlined,
        Color.lerp(colors.warning, colors.destructive, 0.5)!,
      ),
      '❤️' || '❤' => (Icons.favorite_border_rounded, colors.destructive),
      _ => (Icons.emoji_emotions_outlined, colors.foregroundMuted),
    };
    final isDark = theme.brightness == Brightness.dark;
    final lightBase = isDark ? colors.foreground : colors.surface;
    return UiAvatar(
      size: UiSize.sm,
      backgroundColor: Color.lerp(lightBase, accent, 0.16),
      child: Icon(
        icon,
        size: context.sz(theme.sizes.iconSm),
        color: isDark ? Color.lerp(accent, colors.background, 0.35) : accent,
        applyTextScaling: false,
      ),
    );
  }

  Color _reactionColor(BuildContext context, String emoji) => switch (emoji) {
    '❤️' => context.uiColors.destructive,
    '🔥' || '💡' => context.uiColors.warning,
    '🚀' => context.uiColors.bullish,
    _ => context.uiColors.primary,
  };
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

class _LinkedInReactionPillState extends State<_LinkedInReactionPill> {
  int? _hoveredIndex;
  static const _reactions = [
    ('👍', 'Like'),
    ('🚀', 'Bullish'),
    ('💡', 'Insightful'),
    ('🔥', 'Fire'),
    ('❤️', 'Love'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) => widget.onHoverEnter(),
      onExit: (_) => widget.onHoverExit(),
      child: Material(
        type: MaterialType.transparency,
        child: UiCard(
          variant: UiCardVariant.elevated,
          radius: theme.radii.pill,
          padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var index = 0; index < _reactions.length; index++)
                Expanded(
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredIndex = index),
                    onExit: (_) => setState(() => _hoveredIndex = null),
                    child: AnimatedScale(
                      scale: !reduced && _hoveredIndex == index ? 1.08 : 1,
                      duration: reduced ? Duration.zero : theme.motion.fast,
                      curve: theme.motion.curve,
                      child: UiButton(
                        label: _reactions[index].$1,
                        leading: CommunityReactionGlyph(
                          emoji: _reactions[index].$1,
                        ),
                        iconOnly: true,
                        alignment: Alignment.center,
                        rounded: true,
                        tooltip: _reactions[index].$2,
                        semanticLabel: _reactions[index].$2,
                        variant: UiVariant.ghost,
                        size: UiSize.lg,
                        selected: widget.selectedEmoji == _reactions[index].$1,
                        onPressed: () => widget.onSelect(_reactions[index].$1),
                      ),
                    ),
                  ),
                ),
            ],
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
    return UiInteractive(
      pressScale: .9,
      selected: isActive,
      onTap: onTap,
      onLongPress: onLongPress,
      builder: (BuildContext ctx, UiInteractiveState state) {
        final bool isHovered = state.hovered;
        final Color effectiveColor = (isActive || isHovered)
            ? activeColor
            : color;

        return Tooltip(
          triggerMode: isMobile
              ? TooltipTriggerMode.manual
              : TooltipTriggerMode.longPress,
          message: tooltip,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : theme.motion.fast,
            curve: theme.motion.curve,
            padding: EdgeInsets.symmetric(
              horizontal: ctx.sp(
                isMobile ? theme.spacing.xs : theme.spacing.sm,
              ),
              vertical: ctx.sp(theme.spacing.xs),
            ),
            constraints: isMobile
                ? const BoxConstraints(minHeight: 44, minWidth: 44)
                : const BoxConstraints(minHeight: 36, minWidth: 36),
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
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : theme.motion.normal,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: animation.drive(Tween(begin: .8, end: 1.0)),
                        child: child,
                      ),
                    ),
                    child: Icon(
                      icon,
                      key: ValueKey((icon, isActive)),
                      size: ctx.sz(20),
                      color: effectiveColor,
                    ),
                  ),
                  if (count.isNotEmpty) ...<Widget>[
                    SizedBox(width: isMobile ? 3 : ctx.sp(theme.spacing.xxs)),
                    Text(
                      count,
                      style: ctx.uiText.caption.copyWith(
                        color: effectiveColor,
                        fontSize: ctx.fs(14),
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
