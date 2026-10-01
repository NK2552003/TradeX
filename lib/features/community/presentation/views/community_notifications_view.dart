import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/widgets/community_widgets.dart';

import 'package:tradex/features/community/presentation/views/community_notification_settings_page.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';

/// Notification center — all community activity for the current user.
class CommunityNotificationsView extends StatefulWidget {
  const CommunityNotificationsView({
    super.key,
    required this.repository,
    this.onAuthorTap,
  });

  final CommunityRepository repository;
  final ValueChanged<CommunityAuthor>? onAuthorTap;

  @override
  State<CommunityNotificationsView> createState() =>
      _CommunityNotificationsViewState();
}

class _CommunityNotificationsViewState
    extends State<CommunityNotificationsView> {
  int _selectedFilter = 0; // 0: All, 1: Likes, 2: Replies, 3: Reposts, 4: Signals

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onData);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onData);
    super.dispose();
  }

  void _onData() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final allNotifications = widget.repository.notifications;

    final filtered = allNotifications.where((n) {
      if (_selectedFilter == 1) return n.type == CommunityNotificationType.like;
      if (_selectedFilter == 2) return n.type == CommunityNotificationType.reply;
      if (_selectedFilter == 3) return n.type == CommunityNotificationType.repost;
      if (_selectedFilter == 4) return n.type == CommunityNotificationType.signal;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.sm),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text('Notifications', style: context.uiText.subheading),
              ),
              UiIconButton(
                icon: Icons.settings_outlined,
                size: UiSize.sm,
                variant: UiVariant.ghost,
                tooltip: 'Notification preferences',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CommunityNotificationSettingsPage(),
                    ),
                  );
                },
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              if (widget.repository.unreadNotifications > 0)
                UiButton(
                  label: 'Mark all read',
                  variant: UiVariant.ghost,
                  size: UiSize.sm,
                  expandOnMobile: false,
                  onPressed: widget.repository.markAllNotificationsRead,
                ),
            ],
          ),
        ),

        // Filter chips
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.md)),
          child: UiTabs(
            tabs: const ['All', 'Likes', 'Replies', 'Reposts', 'Signals'],
            selectedIndex: _selectedFilter,
            onChanged: (idx) => setState(() => _selectedFilter = idx),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        if (context.uiRes.isMobile) const UiDivider(),

        Expanded(
          child: _NotificationsList(
            notifications: filtered,
            repository: widget.repository,
            onAuthorTap: widget.onAuthorTap,
          ),
        ),
      ],
    );
  }
}


class _NotificationsList extends StatelessWidget {
  const _NotificationsList({
    required this.notifications,
    required this.repository,
    this.onAuthorTap,
  });

  final List<CommunityNotificationItem> notifications;
  final CommunityRepository repository;
  final ValueChanged<CommunityAuthor>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    if (notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: UiEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No notifications',
            message:
                'Mentions, likes, and replies to your setups will appear here.',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      itemCount: notifications.length,
      itemBuilder: (BuildContext context, int index) {
        final item = notifications[index];
        return Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
          child: CommunityNotificationCard(
            notification: item,
            onTap: () {
              if (item.postSnippet != null && repository.feedPosts.isNotEmpty) {
                final post = repository.feedPosts.firstWhere(
                  (p) => p.author.handle == item.actor.handle,
                  orElse: () => repository.feedPosts.first,
                );
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommunityPostDetailView(
                      post: post,
                      repository: repository,
                      currentUser: repository.currentAuthor,
                    ),
                  ),
                );
              } else {
                onAuthorTap?.call(item.actor);
              }
            },
          ),
        );
      },
    );
  }
}

