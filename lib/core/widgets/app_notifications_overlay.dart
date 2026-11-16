import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';

/// Instagram-grade right-side sliding overlay notifications drawer.
///
/// Features:
/// - Smooth right-side overlay drawer sliding over the active application shell.
/// - Instagram-style filter pill tabs: All, People you follow, Comments, Follows, System.
/// - Dynamic time groupings: Today, This week, This month, Earlier.
/// - Device/Security login alerts with status badge.
/// - In-tile "Follow Back" / "Following" actions with live Supabase sync.
/// - Right-side post & trade setup media thumbnails.
/// - Optimistic read tracking and mark-all-read capability.
class AppNotificationsOverlay extends StatefulWidget {
  const AppNotificationsOverlay({
    super.key,
    required this.repository,
    this.currentUser,
    this.onOpenRef,
    this.onOpenPost,
    this.onOpenAuthor,
    this.onOpenSecuritySettings,
    this.onClose,
  });

  final CommunityRepository repository;
  final dynamic currentUser;
  final void Function(AppLinkRef ref)? onOpenRef;
  final ValueChanged<CommunityPost>? onOpenPost;
  final ValueChanged<CommunityAuthor>? onOpenAuthor;
  final VoidCallback? onOpenSecuritySettings;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    required CommunityRepository repository,
    dynamic currentUser,
    void Function(AppLinkRef ref)? onOpenRef,
    ValueChanged<CommunityPost>? onOpenPost,
    ValueChanged<CommunityAuthor>? onOpenAuthor,
    VoidCallback? onOpenSecuritySettings,
  }) {
    final theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: theme.colors.overlay,
      transitionDuration: theme.motion.normal,
      pageBuilder: (BuildContext ctx, _, _) {
        return SafeArea(
          child: Align(
            alignment: isMobile
                ? Alignment.bottomCenter
                : Alignment.centerRight,
            child: SizedBox(
              width: isMobile ? double.infinity : ctx.sz(440),
              height: isMobile
                  ? MediaQuery.sizeOf(ctx).height * 0.94
                  : double.infinity,
              child: UiCard(
                padding: EdgeInsets.zero,
                variant: UiCardVariant.elevated,
                child: Material(
                  type: MaterialType.transparency,
                  child: AppNotificationsOverlay(
                    repository: repository,
                    currentUser: currentUser,
                    onOpenRef: onOpenRef,
                    onOpenPost: onOpenPost,
                    onOpenAuthor: onOpenAuthor,
                    onOpenSecuritySettings: onOpenSecuritySettings,
                    onClose: () => Navigator.of(ctx).maybePop(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (BuildContext ctx, Animation<double> anim, _, Widget child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: isMobile ? const Offset(0, 1) : const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: anim, curve: theme.motion.curve),
                  ),
              child: child,
            );
          },
    );
  }

  @override
  State<AppNotificationsOverlay> createState() =>
      _AppNotificationsOverlayState();
}

class _AppNotificationsOverlayState extends State<AppNotificationsOverlay> {
  // 0: All, 1: People you follow, 2: Comments, 3: Follows, 4: System
  int _selectedFilter = 0;
  CommunityPost? _activePost;
  bool _loadingPost = false;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  CommunityAuthor get _currentAuthor {
    final u = widget.currentUser;
    if (u is CommunityAuthor) return u;
    return widget.repository.currentAuthor;
  }

  List<CommunityNotificationItem> _getFilteredNotifications() {
    final all = widget.repository.notifications;
    final followedIds = widget.repository.followedAuthorIds;

    return all.where((item) {
      if (_selectedFilter == 1) {
        // People you follow
        return item.actor != null && followedIds.contains(item.actor!.id);
      }
      if (_selectedFilter == 2) {
        // Comments & replies
        return item.type == CommunityNotificationType.comment ||
            item.type == CommunityNotificationType.reply;
      }
      if (_selectedFilter == 3) {
        // Follows
        return item.type == CommunityNotificationType.follow;
      }
      if (_selectedFilter == 4) {
        // System & Security
        return item.type == CommunityNotificationType.system ||
            item.type == CommunityNotificationType.security ||
            item.type == CommunityNotificationType.tradeExecution ||
            item.type == CommunityNotificationType.marginAlert;
      }
      return true;
    }).toList();
  }

  Map<String, List<CommunityNotificationItem>> _groupByTime(
    List<CommunityNotificationItem> items,
  ) {
    final now = DateTime.now();
    final today = <CommunityNotificationItem>[];
    final thisWeek = <CommunityNotificationItem>[];
    final thisMonth = <CommunityNotificationItem>[];
    final earlier = <CommunityNotificationItem>[];

    for (final item in items) {
      final diff = now.difference(item.createdAt);
      if (diff.inHours < 24) {
        today.add(item);
      } else if (diff.inDays < 7) {
        thisWeek.add(item);
      } else if (diff.inDays < 30) {
        thisMonth.add(item);
      } else {
        earlier.add(item);
      }
    }

    final groups = <String, List<CommunityNotificationItem>>{};
    if (today.isNotEmpty) groups['Today'] = today;
    if (thisWeek.isNotEmpty) groups['This week'] = thisWeek;
    if (thisMonth.isNotEmpty) groups['This month'] = thisMonth;
    if (earlier.isNotEmpty) groups['Earlier'] = earlier;
    return groups;
  }

  Future<void> _handleItemTap(CommunityNotificationItem item) async {
    await widget.repository.markNotificationRead(item.id);
    if (!mounted) return;

    if (item.postId != null && item.postId!.isNotEmpty) {
      if (item.type == CommunityNotificationType.message) {
        widget.onClose?.call();
        widget.onOpenRef?.call(
          AppLinkRef(
            kind: AppLinkKind.messageThread,
            id: item.postId!,
            title: item.title ?? 'Messages',
          ),
        );
        return;
      }

      if (item.type == CommunityNotificationType.tradeExecution ||
          item.type == CommunityNotificationType.signal ||
          item.type == CommunityNotificationType.marginAlert) {
        widget.onClose?.call();
        widget.onOpenRef?.call(
          AppLinkRef(
            kind: item.type == CommunityNotificationType.tradeExecution
                ? AppLinkKind.journal
                : AppLinkKind.ticker,
            id: item.postId!,
            title: item.title ?? 'Market',
          ),
        );
        return;
      }

      CommunityPost? post = widget.repository.loadPostById(item.postId!);
      if (post == null) {
        setState(() => _loadingPost = true);
        post = await widget.repository.fetchPostById(item.postId!);
        if (!mounted) return;
        setState(() => _loadingPost = false);
      }

      if (post != null) {
        if (widget.onOpenPost != null) {
          widget.onClose?.call();
          widget.onOpenPost!(post);
        } else {
          setState(() => _activePost = post);
        }
        return;
      }

      if (item.actor == null) {
        UiToast.info(
          context,
          title: 'Post unavailable',
          message: 'This post may have been removed or made private.',
        );
        return;
      }
    }

    if (item.type == CommunityNotificationType.security ||
        item.type == CommunityNotificationType.system) {
      await _showSecurityAlertDetails(item);
      return;
    }

    if (item.actor != null && widget.onOpenAuthor != null) {
      widget.onClose?.call();
      widget.onOpenAuthor!(item.actor!);
    }
  }

  Future<void> _showSecurityAlertDetails(CommunityNotificationItem item) async {
    final bool? openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => UiDialog(
        title: item.title ?? 'Security Alert',
        content: Text(
          item.body ??
              'A security event was logged on your account. If this was not you, review your credentials and security settings immediately.',
          style: context.uiText.body,
        ),
        actions: [
          UiButton(
            label: 'Security Settings',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          UiButton(
            label: 'Looks Good',
            intent: UiIntent.primary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
    if (openSettings == true && mounted) {
      widget.onClose?.call();
      widget.onOpenSecuritySettings?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    if (_activePost != null) {
      return CommunityPostDetailView(
        key: ValueKey<String>('overlay_post_${_activePost!.id}'),
        post: _activePost!,
        repository: widget.repository,
        currentUser: _currentAuthor,
        forceSingleColumn: true,
        showHeader: true,
        onBack: () => setState(() => _activePost = null),
        onAuthorTap: (author) {
          widget.onClose?.call();
          widget.onOpenAuthor?.call(author);
        },
        onOpenRef: (ref) {
          widget.onClose?.call();
          widget.onOpenRef?.call(ref);
        },
      );
    }

    final int unreadCount = widget.repository.unreadNotifications;
    final filteredItems = _getFilteredNotifications();
    final grouped = _groupByTime(filteredItems);

    final List<CommunityNotificationItem> followRequests = widget
        .repository
        .notifications
        .where(
          (n) =>
              n.type == CommunityNotificationType.follow &&
              !n.isFollowingBack &&
              n.actor != null,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_loadingPost)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: UiSkeleton(height: 3, width: double.infinity),
          ),
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.sp(theme.spacing.md),
            context.sp(theme.spacing.md),
            context.sp(theme.spacing.sm),
            context.sp(theme.spacing.xs),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Notifications',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.heading.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colors.foreground,
                        ),
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      UiBadge(
                        label: '$unreadCount',
                        intent: UiIntent.primary,
                        size: UiSize.xs,
                      ),
                    ],
                  ],
                ),
              ),
              if (unreadCount > 0) ...[
                UiButton(
                  label: 'Mark all read',
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: widget.repository.markAllNotificationsRead,
                ),
                SizedBox(width: context.sp(theme.spacing.xxs)),
              ],
              UiIconButton(
                icon: Icons.close_rounded,
                size: UiSize.sm,
                tooltip: 'Close notifications',
                onPressed:
                    widget.onClose ?? () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),

        // Instagram-style Filter Chips
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _buildFilterChip(0, 'All', theme),
                SizedBox(width: context.sp(theme.spacing.xs)),
                _buildFilterChip(1, 'People you follow', theme),
                SizedBox(width: context.sp(theme.spacing.xs)),
                _buildFilterChip(2, 'Comments', theme),
                SizedBox(width: context.sp(theme.spacing.xs)),
                _buildFilterChip(3, 'Follows', theme),
                SizedBox(width: context.sp(theme.spacing.xs)),
                _buildFilterChip(4, 'System', theme),
              ],
            ),
          ),
        ),

        Divider(
          height: 1,
          thickness: theme.borders.hairline,
          color: theme.colors.border.withValues(alpha: 0.6),
        ),

        // Body Content
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
                    child: const UiEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No notifications',
                      message: 'You have no activity matching this filter.',
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.symmetric(
                    vertical: context.sp(theme.spacing.xs),
                  ),
                  children: <Widget>[
                    // Follow Requests Bar (Instagram-style)
                    if ((_selectedFilter == 0 || _selectedFilter == 3) &&
                        followRequests.isNotEmpty) ...<Widget>[
                      _buildFollowRequestsBanner(followRequests, theme),
                      Divider(
                        height: 1,
                        thickness: theme.borders.hairline,
                        color: theme.colors.border.withValues(alpha: 0.4),
                      ),
                    ],

                    // Time Grouped Sections
                    for (final entry in grouped.entries) ...<Widget>[
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.sp(theme.spacing.md),
                          context.sp(theme.spacing.md),
                          context.sp(theme.spacing.md),
                          context.sp(theme.spacing.xs),
                        ),
                        child: Text(
                          entry.key,
                          style: context.uiText.subheading.copyWith(
                            fontSize: context.fs(15),
                            fontWeight: FontWeight.w700,
                            color: theme.colors.foreground,
                          ),
                        ),
                      ),
                      for (final item in entry.value)
                        _buildNotificationRow(item, theme),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(int index, String label, UiTheme theme) {
    final bool isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: theme.motion.fast,
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.sm),
          vertical: context.sp(theme.spacing.xxs) + 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colors.foreground
              : theme.colors.surfaceMuted.withValues(alpha: 0.6),
          borderRadius: context.radius(theme.radii.pill),
          border: Border.all(
            color: isSelected
                ? theme.colors.foreground
                : theme.colors.border.withValues(alpha: 0.5),
            width: theme.borders.hairline,
          ),
        ),
        child: Text(
          label,
          style: context.uiText.caption.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? theme.colors.surface
                : theme.colors.foregroundMuted,
            fontSize: context.fs(12),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowRequestsBanner(
    List<CommunityNotificationItem> followRequests,
    UiTheme theme,
  ) {
    final first = followRequests.first.actor;
    final int extraCount = followRequests.length - 1;
    final String label = extraCount > 0
        ? '${first?.handle ?? "trader"} + $extraCount others'
        : (first?.handle ?? '1 new request');

    return InkWell(
      onTap: () => setState(() => _selectedFilter = 3),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.md),
          vertical: context.sp(theme.spacing.sm),
        ),
        child: Row(
          children: <Widget>[
            // Overlapping Avatars Stack
            SizedBox(
              width: context.sz(46),
              height: context.sz(36),
              child: Stack(
                children: [
                  if (followRequests.length > 1 &&
                      followRequests[1].actor != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: UiAvatar(
                        name: followRequests[1].actor!.displayName,
                        imageUrl: followRequests[1].actor!.avatarUrl,
                        size: UiSize.sm,
                      ),
                    ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: UiAvatar(
                      name: first?.displayName ?? 'Trader',
                      imageUrl: first?.avatarUrl,
                      size: UiSize.sm,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Follow requests',
                    style: context.uiText.bodyStrong.copyWith(
                      color: theme.colors.foreground,
                    ),
                  ),
                  Text(
                    label,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: context.sz(7),
              height: context.sz(7),
              decoration: BoxDecoration(
                color: theme.colors.primary,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Icon(
              Icons.chevron_right_rounded,
              size: context.sz(18),
              color: theme.colors.foregroundSubtle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationRow(CommunityNotificationItem item, UiTheme theme) {
    final bool isSystemOrSecurity =
        item.type == CommunityNotificationType.security ||
        item.type == CommunityNotificationType.system ||
        item.type == CommunityNotificationType.tradeExecution ||
        item.type == CommunityNotificationType.marginAlert;

    final String relativeTime = _formatTimeAgo(item.createdAt);

    return InkWell(
      onTap: () => _handleItemTap(item),
      child: Container(
        color: !item.read
            ? theme.colors.primary.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.md),
          vertical: context.sp(theme.spacing.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Left Icon / Avatar
            if (isSystemOrSecurity)
              _buildSystemIcon(item.type, theme)
            else
              UiAvatar(
                name: item.actor?.displayName ?? 'Trader',
                imageUrl: item.actor?.avatarUrl,
                size: UiSize.md,
                verified: item.actor?.verified ?? false,
                verifiedColor: item.actor?.verifiedColor(theme),
                onTap: item.actor != null
                    ? () => widget.onOpenAuthor?.call(item.actor!)
                    : null,
              ),

            SizedBox(width: context.sp(theme.spacing.sm)),

            // Middle: Rich Notification Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildNotificationMessage(item, relativeTime, theme),
                ],
              ),
            ),

            SizedBox(width: context.sp(theme.spacing.xs)),

            // Right Action: Follow Back or Media Thumbnail
            if (item.type == CommunityNotificationType.follow &&
                item.actor != null)
              _buildFollowButton(item, theme)
            else if (item.postImageUrl != null && item.postImageUrl!.isNotEmpty)
              _buildPostThumbnail(item.postImageUrl!, theme)
            else if (item.postSnippet != null &&
                item.postSnippet!.isNotEmpty &&
                item.postId != null)
              _buildSnippetThumbnail(theme)
            else if (isSystemOrSecurity)
              Icon(
                Icons.chevron_right_rounded,
                size: context.sz(16),
                color: theme.colors.foregroundSubtle,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemIcon(CommunityNotificationType type, UiTheme theme) {
    final (IconData icon, Color color, Color bg) = switch (type) {
      CommunityNotificationType.security => (
        Icons.phone_android_rounded,
        theme.colors.primary,
        theme.colors.primary.withValues(alpha: 0.14),
      ),
      CommunityNotificationType.tradeExecution => (
        Icons.check_circle_outline_rounded,
        theme.colors.success,
        theme.colors.success.withValues(alpha: 0.14),
      ),
      CommunityNotificationType.marginAlert => (
        Icons.shield_outlined,
        theme.colors.warning,
        theme.colors.warning.withValues(alpha: 0.14),
      ),
      _ => (
        Icons.info_outline_rounded,
        theme.colors.foregroundSubtle,
        theme.colors.surfaceMuted,
      ),
    };

    return Container(
      width: context.sz(42),
      height: context.sz(42),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: theme.borders.hairline,
        ),
      ),
      child: Center(
        child: Icon(icon, size: context.sz(20), color: color),
      ),
    );
  }

  Widget _buildNotificationMessage(
    CommunityNotificationItem item,
    String relativeTime,
    UiTheme theme,
  ) {
    if (item.type == CommunityNotificationType.security ||
        item.type == CommunityNotificationType.system ||
        item.type == CommunityNotificationType.tradeExecution ||
        item.type == CommunityNotificationType.marginAlert) {
      return Text.rich(
        TextSpan(
          style: context.uiText.body.copyWith(
            fontSize: context.fs(13),
            color: theme.colors.foreground,
            height: 1.35,
          ),
          children: [
            TextSpan(text: item.body ?? item.title ?? 'System Alert'),
            TextSpan(
              text: '  $relativeTime',
              style: TextStyle(
                color: theme.colors.foregroundSubtle,
                fontSize: context.fs(12),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    final String handle = item.actor?.handle ?? 'A trader';
    final String cleanHandle = handle.startsWith('@')
        ? handle.substring(1)
        : handle;

    final String actionText = switch (item.type) {
      CommunityNotificationType.like => ' liked your post.',
      CommunityNotificationType.comment =>
        ' commented: "${item.postSnippet ?? ""}"',
      CommunityNotificationType.reply =>
        ' replied to your post: "${item.postSnippet ?? ""}"',
      CommunityNotificationType.repost => ' reposted your trade setup.',
      CommunityNotificationType.follow => ' started following you.',
      CommunityNotificationType.mention => ' mentioned you in a setup.',
      CommunityNotificationType.signal => ' published a new trade setup.',
      _ => ' interacted with your profile.',
    };

    return Text.rich(
      TextSpan(
        style: context.uiText.body.copyWith(
          fontSize: context.fs(13),
          color: theme.colors.foreground,
          height: 1.35,
        ),
        children: [
          TextSpan(
            text: cleanHandle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: actionText),
          TextSpan(
            text: '  $relativeTime',
            style: TextStyle(
              color: theme.colors.foregroundSubtle,
              fontSize: context.fs(12),
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFollowButton(CommunityNotificationItem item, UiTheme theme) {
    final bool isFollowing = item.isFollowingBack;
    return UiButton(
      label: isFollowing ? 'Following' : 'Follow Back',
      variant: isFollowing ? UiVariant.outline : UiVariant.solid,
      intent: isFollowing ? UiIntent.neutral : UiIntent.primary,
      size: UiSize.xs,
      onPressed: () {
        widget.repository.toggleFollowFromNotification(item);
      },
    );
  }

  Widget _buildPostThumbnail(String imageUrl, UiTheme theme) {
    final double thumbSize = context.sz(42);
    return ClipRRect(
      borderRadius: context.radius(theme.radii.sm),
      child: SizedBox(
        width: thumbSize,
        height: thumbSize,
        child: UiRemoteImage(
          url: imageUrl,
          width: thumbSize,
          height: thumbSize,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildSnippetThumbnail(UiTheme theme) {
    return Container(
      width: context.sz(42),
      height: context.sz(42),
      decoration: BoxDecoration(
        color: theme.colors.surfaceMuted,
        borderRadius: context.radius(theme.radii.sm),
        border: Border.all(
          color: theme.colors.border.withValues(alpha: 0.5),
          width: theme.borders.hairline,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.candlestick_chart_rounded,
          size: context.sz(18),
          color: theme.colors.primary,
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return '${time.day} ${_monthName(time.month)}';
  }

  String _monthName(int month) => switch (month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    12 => 'Dec',
    _ => '',
  };
}
