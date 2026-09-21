import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../cards/community_cards.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';

/// Composer for a new post.
class AppComposerBlock extends StatelessWidget {
  const AppComposerBlock({
    super.key,
    required this.me,
    this.value,
    this.onChanged,
    this.onSubmit,
    this.onAttach,
    this.submitting = false,
  });

  final AppTrader me;
  final String? value;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmit;
  final VoidCallback? onAttach;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UiAvatar(imageUrl: me.avatarUrl, name: me.displayName ?? me.handle),
          SizedBox(width: context.sp(theme.spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                UiTextarea(
                  value: value,
                  hintText: 'Share a setup, thesis or lesson…',
                  rows: 2,
                  maxRows: 6,
                  onChanged: onChanged,
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                Row(
                  children: <Widget>[
                    UiIconButton(
                      icon: Icons.image_outlined,
                      size: UiSize.sm,
                      tooltip: 'Attach chart',
                      onPressed: onAttach,
                    ),
                    const Spacer(),
                    UiButton(
                      label: 'Post',
                      size: UiSize.sm,
                      loading: submitting,
                      expandOnMobile: false,
                      onPressed: onSubmit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Social feed list with loading and empty states.
class AppFeedBlock extends StatelessWidget {
  const AppFeedBlock({
    super.key,
    required this.posts,
    this.onLike,
    this.onComment,
    this.onSave,
    this.onOpen,
    this.onAuthorTap,
    this.loading = false,
  });

  final List<AppPost> posts;
  final ValueChanged<AppPost>? onLike;
  final ValueChanged<AppPost>? onComment;
  final ValueChanged<AppPost>? onSave;
  final ValueChanged<AppPost>? onOpen;
  final ValueChanged<AppTrader>? onAuthorTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    if (loading) {
      return Column(
        children: <Widget>[
          for (int i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
              child: UiCard(child: UiSkeleton(height: context.sz(110))),
            ),
        ],
      );
    }
    if (posts.isEmpty) {
      return const UiEmptyState(
        title: 'Nothing here yet',
        message: 'Follow traders to fill your feed.',
        icon: Icons.forum_outlined,
      );
    }
    return Column(
      children: <Widget>[
        for (int i = 0; i < posts.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
            child: AppFadeIn(
              delay: Duration(milliseconds: 40 * i),
              child: AppPostCard(
                post: posts[i],
                onTap: onOpen == null ? null : () => onOpen!(posts[i]),
                onLike: onLike == null ? null : () => onLike!(posts[i]),
                onComment: onComment == null
                    ? null
                    : () => onComment!(posts[i]),
                onSave: onSave == null ? null : () => onSave!(posts[i]),
                onAuthorTap: onAuthorTap == null
                    ? null
                    : () => onAuthorTap!(posts[i].author),
              ),
            ),
          ),
      ],
    );
  }
}

/// Suggested traders to follow.
class AppSuggestedTradersBlock extends StatelessWidget {
  const AppSuggestedTradersBlock({
    super.key,
    required this.traders,
    this.title = 'Traders to follow',
    this.onFollow,
    this.onOpen,
  });

  final List<AppTrader> traders;
  final String title;
  final ValueChanged<AppTrader>? onFollow;
  final ValueChanged<AppTrader>? onOpen;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: title,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < traders.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
              child: AppTraderRow(
                trader: traders[i],
                onTap: onOpen == null ? null : () => onOpen!(traders[i]),
                trailing: UiIconButton(
                  icon: traders[i].isFollowing
                      ? Icons.check_rounded
                      : Icons.person_add_rounded,
                  variant: traders[i].isFollowing
                      ? UiVariant.outline
                      : UiVariant.primary,
                  size: UiSize.sm,
                  tooltip: traders[i].isFollowing
                      ? 'Following @${traders[i].handle}'
                      : 'Follow @${traders[i].handle}',
                  onPressed: onFollow == null
                      ? null
                      : () => onFollow!(traders[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Leaderboard with a period switcher.
class AppLeaderboardBlock extends StatelessWidget {
  const AppLeaderboardBlock({
    super.key,
    required this.entries,
    required this.period,
    this.periods = const <String>['Day', 'Week', 'Month', 'All'],
    this.onPeriodChanged,
    this.onOpen,
  });

  /// Trader + performance value, already sorted best first.
  final List<MapEntry<AppTrader, double>> entries;
  final String period;
  final List<String> periods;
  final ValueChanged<String>? onPeriodChanged;
  final ValueChanged<AppTrader>? onOpen;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Leaderboard',
      trailing: UiToggleGroup<String>(
        value: period,
        onChanged: onPeriodChanged,
        options: <UiToggleOption<String>>[
          for (final String p in periods)
            UiToggleOption<String>(value: p, label: p),
        ],
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < entries.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: AppLeaderboardCard(
                rank: i + 1,
                trader: entries[i].key,
                value: entries[i].value,
                onTap: onOpen == null ? null : () => onOpen!(entries[i].key),
              ),
            ),
        ],
      ),
    );
  }
}

/// Comment thread with an inline reply composer.
class AppCommentThreadBlock extends StatelessWidget {
  const AppCommentThreadBlock({
    super.key,
    required this.comments,
    this.draft,
    this.onDraftChanged,
    this.onSend,
    this.onLike,
  });

  final List<AppComment> comments;
  final String? draft;
  final ValueChanged<String>? onDraftChanged;
  final VoidCallback? onSend;
  final ValueChanged<AppComment>? onLike;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final AppComment c in comments)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
            child: AppCommentCard(
              comment: c,
              onLike: onLike == null ? null : () => onLike!(c),
            ),
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: UiInput(
                value: draft,
                hintText: 'Add a comment',
                onChanged: onDraftChanged,
                onSubmitted: (_) => onSend?.call(),
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            UiIconButton(icon: Icons.send, onPressed: onSend, tooltip: 'Send'),
          ],
        ),
      ],
    );
  }
}

/// Direct-message inbox list.
class AppInboxBlock extends StatelessWidget {
  const AppInboxBlock({super.key, required this.conversations, this.onOpen});

  final List<AppConversation> conversations;
  final ValueChanged<AppConversation>? onOpen;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    if (conversations.isEmpty) {
      return const UiEmptyState(
        title: 'No messages',
        message: 'Start a conversation from any trader profile.',
        icon: Icons.chat_bubble_outline,
      );
    }
    return Column(
      children: <Widget>[
        for (final AppConversation c in conversations)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            child: AppConversationCard(
              conversation: c,
              onTap: onOpen == null ? null : () => onOpen!(c),
            ),
          ),
      ],
    );
  }
}

/// Chat thread: bubbles + composer, sized for every device.
class AppChatThreadBlock extends StatelessWidget {
  const AppChatThreadBlock({
    super.key,
    required this.peer,
    required this.messages,
    this.draft,
    this.onDraftChanged,
    this.onSend,
  });

  final AppTrader peer;
  final List<AppChatMessage> messages;
  final String? draft;
  final ValueChanged<String>? onDraftChanged;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      children: <Widget>[
        AppTraderRow(trader: peer),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiDivider(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.md),
            ),
            children: <Widget>[
              for (final AppChatMessage m in messages)
                AppMessageBubble(message: m),
            ],
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: UiInput(
                value: draft,
                hintText: 'Message @${peer.handle}',
                onChanged: onDraftChanged,
                onSubmitted: (_) => onSend?.call(),
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            UiIconButton(icon: Icons.send, onPressed: onSend, tooltip: 'Send'),
          ],
        ),
      ],
    );
  }
}

/// Notification center list, grouped by read state.
class AppNotificationsBlock extends StatelessWidget {
  const AppNotificationsBlock({
    super.key,
    required this.notifications,
    this.onOpen,
    this.onDismiss,
    this.onMarkAllRead,
  });

  final List<AppNotification> notifications;
  final ValueChanged<AppNotification>? onOpen;
  final ValueChanged<AppNotification>? onDismiss;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Notifications', style: context.uiText.subheading),
            ),
            UiButton(
              label: 'Mark all read',
              variant: UiVariant.ghost,
              size: UiSize.sm,
              expandOnMobile: false,
              onPressed: onMarkAllRead,
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        if (notifications.isEmpty)
          const UiEmptyState(
            title: 'All caught up',
            icon: Icons.notifications_none,
          )
        else
          for (final AppNotification n in notifications)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: AppNotificationCard(
                notification: n,
                onTap: onOpen == null ? null : () => onOpen!(n),
                onDismiss: onDismiss == null ? null : () => onDismiss!(n),
              ),
            ),
      ],
    );
  }
}
