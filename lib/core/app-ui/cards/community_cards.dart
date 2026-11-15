import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Social feed post: author, body, tickers, media and engagement actions.
class AppPostCard extends StatelessWidget {
  const AppPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onSave,
    this.onShare,
    this.onAuthorTap,
    this.onTickerTap,
    this.loading = false,
  });

  final AppPost post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onAuthorTap;
  final ValueChanged<String>? onTickerTap;

  /// Renders the built-in [UiCard] skeleton instead of the post body.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      onTap: onTap,
      loading: loading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppTraderRow(
            trader: post.author,
            onTap: onAuthorTap,
            trailingLabel: AppTokens.relativeTime(post.createdAt),
          ),
          if (post.isPendingApproval) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            const UiBadge(
              label: 'Pending Approval',
              intent: UiIntent.warning,
              variant: UiBadgeVariant.soft,
            ),
          ],
          SizedBox(height: context.sp(theme.spacing.md)),
          Text(post.body, style: context.uiText.body),
          if (post.tickers.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: post.tickers
                  .map(
                    (String t) => UiBadge(
                      label: '\$$t',
                      intent: UiIntent.primary,
                      onTap: onTickerTap == null ? null : () => onTickerTap!(t),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (post.imageUrl != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            ClipRRect(
              borderRadius: context.radius(theme.radii.lg),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: UiRemoteImage(
                  url: post.imageUrl,
                  semanticLabel: 'Image attached by @${post.author.handle}',
                ),
              ),
            ),
          ],
          for (final AppPostAttachment attachment
              in post.attachments) ...<Widget>[
            if (attachment is AppPostImageAttachment) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.md)),
              ClipRRect(
                borderRadius: context.radius(theme.radii.lg),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: UiRemoteImage(
                    url: attachment.url,
                    semanticLabel: 'Image attached by @${post.author.handle}',
                  ),
                ),
              ),
            ] else if (attachment is AppPostChartAttachment) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.md)),
              UiCard(
                padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                child: UiCandleChart(
                  candles: (attachment.candles as List<dynamic>)
                      .cast<UiCandle>(),
                  // Taller on a wide screen, where the post column is wide enough
                  // that a 140pt strip would read as a sliver rather than a chart.
                  height: context.uiRes.isMobile ? 140 : 180,
                  showVolume: false,
                  showGrid: false,
                  interactive: false,
                ),
              ),
            ] else if (attachment is AppPostStrategyAttachment) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.md)),
              UiCard(
                variant: UiCardVariant.surface,
                onTap: onTap,
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.md),
                  vertical: context.sp(theme.spacing.xs),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.auto_graph_rounded,
                      color: theme.colors.primary,
                      size: context.sz(theme.sizes.iconMd),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: Text(
                        attachment.name,
                        style: context.uiText.bodyStrong,
                      ),
                    ),
                    if (attachment.locked) ...[
                      Icon(
                        Icons.lock_outline_rounded,
                        color: theme.colors.warning,
                        size: context.sz(theme.sizes.iconSm),
                      ),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                    ],
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colors.borderStrong,
                      size: context.sz(theme.sizes.iconSm),
                    ),
                  ],
                ),
              ),
            ],
          ],
          SizedBox(height: context.sp(theme.spacing.md)),
          UiDivider(),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _action(
                    context,
                    icon: post.liked ? Icons.favorite : Icons.favorite_border,
                    label: AppTokens.count(post.likes),
                    tooltip: post.liked ? 'Unlike' : 'Like',
                    active: post.liked,
                    onTap: onLike,
                  ),
                  _action(
                    context,
                    icon: Icons.mode_comment_outlined,
                    label: AppTokens.count(post.comments),
                    tooltip: 'Reply',
                    onTap: onComment,
                  ),
                  _action(
                    context,
                    icon: Icons.remove_red_eye_outlined,
                    label: AppTokens.count(post.views),
                    tooltip: 'Views',
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  UiIconButton(
                    icon: post.saved ? Icons.bookmark : Icons.bookmark_border,
                    size: UiSize.sm,
                    tooltip: 'Save',
                    onPressed: onSave,
                  ),
                  UiIconButton(
                    icon: Icons.ios_share,
                    size: UiSize.sm,
                    tooltip: 'Share',
                    onPressed:
                        onShare ?? () => AppPostShareModal.showForPost(context, post),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String tooltip,
    VoidCallback? onTap,
    bool active = false,
  }) {
    final UiTheme theme = context.ui;
    final Color color = active
        ? theme.colors.bearish
        : theme.colors.foregroundMuted;
    return UiInteractive(
      onTap: onTap,
      builder: (BuildContext ctx, UiInteractiveState s) => Tooltip(
        message: tooltip,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: ctx.sp(theme.spacing.sm),
            vertical: ctx.sp(theme.spacing.xs),
          ),
          // Padding alone left these at roughly 26pt tall — the two most-tapped
          // controls on the feed, both under the 44pt a thumb needs. The floor
          // only applies on touch so the desktop row stays tight.
          constraints: ctx.uiRes.isMobile
              ? BoxConstraints(
                  minWidth: ctx.sz(theme.sizes.minTapTarget),
                  minHeight: ctx.sz(theme.sizes.minTapTarget),
                )
              : const BoxConstraints(),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: ctx.sz(theme.sizes.iconSm), color: color),
              SizedBox(width: ctx.sp(theme.spacing.xs)),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ctx.uiText.caption.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar + handle + verification + tier, reused in feeds, lists and headers.
class AppTraderRow extends StatelessWidget {
  const AppTraderRow({
    super.key,
    required this.trader,
    this.onTap,
    this.trailingLabel,
    this.trailing,
    this.size = UiSize.md,
  });

  final AppTrader trader;
  final VoidCallback? onTap;
  final String? trailingLabel;
  final Widget? trailing;
  final UiSize size;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Row(
      children: <Widget>[
        UiAvatar(
          imageUrl: trader.avatarUrl,
          name: trader.displayName ?? trader.handle,
          size: size,
          verified: trader.verified,
          onTap: onTap,
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
                      trader.displayName ?? trader.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.bodyStrong,
                    ),
                  ),
                  if (trader.tier != AppTier.free) ...<Widget>[
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Icon(
                      AppTokens.tierIcon(trader.tier),
                      size: context.sz(theme.sizes.iconSm),
                      color: AppTokens.tierColor(context, trader.tier),
                    ),
                  ],
                ],
              ),
              Text(
                '@${trader.handle}'
                '${trailingLabel == null ? '' : ' · $trailingLabel'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Full trader profile card with follow action and key stats.
class AppTraderCard extends StatelessWidget {
  const AppTraderCard({
    super.key,
    required this.trader,
    this.onFollow,
    this.onTap,
    this.onMessage,
    this.selected = false,
    this.loading = false,
  });

  final AppTrader trader;
  final VoidCallback? onFollow;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;

  /// Highlights the card as the active/selected trader.
  final bool selected;

  /// Renders the built-in [UiCard] skeleton instead of the profile body.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return AppHoverLift(
      child: UiCard(
        onTap: onTap,
        selected: selected,
        loading: loading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppTraderRow(
              trader: trader,
              size: UiSize.lg,
              trailingLabel: trader.tradingStyle,
              trailing: UiIconButton(
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
            ),
            if (trader.bio != null) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.md)),
              Text(
                trader.bio!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
            SizedBox(height: context.sp(theme.spacing.md)),
            Wrap(
              spacing: context.sp(theme.spacing.lg),
              runSpacing: context.sp(theme.spacing.sm),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _stat(context, 'Followers', uiCompactNumber(trader.followers)),
                _stat(context, 'Following', uiCompactNumber(trader.following)),
                if (trader.winRate != null)
                  _stat(
                    context,
                    'Win rate',
                    '${trader.winRate!.toStringAsFixed(0)}%',
                  ),
                if (onMessage != null)
                  UiIconButton(
                    icon: Icons.chat_bubble_outline,
                    size: UiSize.sm,
                    tooltip: 'Message',
                    onPressed: onMessage,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(value, style: context.uiText.bodyStrong),
        Text(
          label,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
      ],
    );
  }
}

/// Leaderboard row with rank medal and performance value.
class AppLeaderboardCard extends StatelessWidget {
  const AppLeaderboardCard({
    super.key,
    required this.rank,
    required this.trader,
    required this.value,
    this.onTap,
    this.valueLabel,
  });

  final int rank;
  final AppTrader trader;
  final double value;
  final VoidCallback? onTap;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool podium = rank <= 3;
    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      accentColor: podium ? theme.colors.warning : null,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: context.sz(28),
            child: Text(
              '#$rank',
              style: context.uiText.bodyStrong.copyWith(
                color: podium
                    ? theme.colors.warning
                    : theme.colors.foregroundMuted,
              ),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Expanded(
            child: AppTraderRow(trader: trader, size: UiSize.sm),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Flexible(
            child: Text(
              valueLabel ?? AppTokens.signedPercent(value, decimals: 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: context.uiText.numeric.copyWith(
                color: AppTokens.pl(context, value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Threaded comment.
class AppCommentCard extends StatelessWidget {
  const AppCommentCard({
    super.key,
    required this.comment,
    this.onLike,
    this.onReply,
    this.indent = 0,
  });

  final AppComment comment;
  final VoidCallback? onLike;
  final VoidCallback? onReply;
  final int indent;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    // A thread can nest arbitrarily deep, but the indent cannot: past a few levels
    // every reply would be a one-word column down the right of a phone screen.
    // Beyond the cap, replies keep their nesting in the data and stack visually.
    final int steps = indent.clamp(0, context.uiRes.isMobile ? 2 : 4);
    return Padding(
      padding: EdgeInsets.only(left: context.sp(theme.spacing.lg) * steps),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UiAvatar(
            imageUrl: comment.author.avatarUrl,
            name: comment.author.displayName ?? comment.author.handle,
            size: UiSize.sm,
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                  decoration: BoxDecoration(
                    color: theme.colors.surfaceMuted,
                    borderRadius: context.radius(theme.radii.lg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '@${comment.author.handle}',
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.xxs)),
                      Text(comment.body, style: context.uiText.body),
                    ],
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: context.sp(theme.spacing.sm),
                  runSpacing: context.sp(theme.spacing.xxs),
                  children: <Widget>[
                    Text(
                      AppTokens.relativeTime(comment.createdAt),
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                      ),
                    ),
                    UiButton(
                      label: '${AppTokens.count(comment.likes)} likes',
                      variant: UiVariant.ghost,
                      size: UiSize.sm,
                      expandOnMobile: false,
                      onPressed: onLike,
                    ),
                    UiButton(
                      label: 'Reply',
                      variant: UiVariant.ghost,
                      size: UiSize.sm,
                      expandOnMobile: false,
                      onPressed: onReply,
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

/// Direct-message conversation row with unread count.
class AppConversationCard extends StatelessWidget {
  const AppConversationCard({
    super.key,
    required this.conversation,
    this.onTap,
  });

  final AppConversation conversation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Row(
        children: <Widget>[
          UiAvatar(
            imageUrl: conversation.peer.avatarUrl,
            name: conversation.peer.displayName ?? conversation.peer.handle,
            online: true,
          ),
          SizedBox(width: context.sp(theme.spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  conversation.peer.displayName ??
                      '@${conversation.peer.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.bodyStrong,
                ),
                Text(
                  conversation.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          // The timestamp column has no flex of its own, so it claimed its
          // intrinsic width before the message preview got any — "yesterday" at
          // a large text scale left the preview a few characters wide.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  AppTokens.relativeTime(conversation.lastMessageAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                if (conversation.unread > 0)
                  UiBadge(
                    // Abbreviated: an inbox left alone for a week must not widen
                    // the row until the message preview beside it disappears.
                    label: AppTokens.count(conversation.unread),
                    intent: UiIntent.primary,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single chat bubble for the DM thread.
class AppMessageBubble extends StatelessWidget {
  const AppMessageBubble({super.key, required this.message});

  final AppChatMessage message;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool mine = message.fromMe;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.uiRes.pick<double>(
            mobile: 280,
            tablet: 380,
            desktop: 460,
          ),
        ),
        child: Container(
          margin: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.sm),
          ),
          decoration: BoxDecoration(
            color: mine ? theme.colors.primary : theme.colors.surfaceMuted,
            borderRadius: context.radius(theme.radii.lg),
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message.body,
                style: context.uiText.body.copyWith(
                  color: mine
                      ? theme.colors.onPrimary
                      : theme.colors.foreground,
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                message.pending
                    ? 'Sending…'
                    : AppTokens.relativeTime(message.sentAt),
                style: context.uiText.caption.copyWith(
                  color:
                      (mine
                              ? theme.colors.onPrimary
                              : theme.colors.foregroundMuted)
                          .withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AI insight card with confidence meter and sentiment badge.
class AppAiInsightCard extends StatelessWidget {
  const AppAiInsightCard({super.key, required this.insight, this.onTap});

  final AppAiInsight insight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      onTap: onTap,
      accentColor: theme.colors.primary,
      title: insight.title,
      subtitle: insight.createdAt == null
          ? null
          : AppTokens.relativeTime(insight.createdAt!),
      trailing: insight.sentimentScore == null
          ? null
          : UiBadge(
              label: AppTokens.sentimentLabel(insight.sentimentScore!),
              intent: AppTokens.plIntent(insight.sentimentScore!),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            insight.body,
            style: context.uiText.body.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          if (insight.confidence != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            // The label belongs to the bar rather than sitting beside it: the bar
            // renders its own percentage above the track, so a sibling label
            // ended up vertically adrift of the figure it described.
            UiProgressBar(
              label: 'Confidence',
              value: insight.confidence!.clamp(0, 1),
              intent: UiIntent.primary,
            ),
          ],
          if (insight.tickers.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: insight.tickers
                  .map((String t) => UiBadge(label: '\$$t'))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// News headline with sentiment tint.
class AppNewsCard extends StatelessWidget {
  const AppNewsCard({super.key, required this.item, this.onTap});

  final AppNewsItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      accentColor: AppTokens.sentimentColor(context, item.sentimentScore),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.bodyStrong,
          ),
          if (item.summary != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Text(
              item.summary!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
          SizedBox(height: context.sp(theme.spacing.sm)),
          Row(
            children: <Widget>[
              // Publication names run long ("Business Standard Markets"), so the
              // byline yields to the sentiment badge rather than pushing it off.
              Expanded(
                child: Text(
                  '${item.source} · ${AppTokens.relativeTime(item.publishedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              UiBadge(
                label: AppTokens.sentimentLabel(item.sentimentScore),
                intent: AppTokens.plIntent(item.sentimentScore),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Notification row.
class AppNotificationCard extends StatelessWidget {
  const AppNotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: notification.read
                  ? theme.colors.surfaceMuted
                  : theme.colors.primary.withValues(alpha: 0.14),
              borderRadius: context.radius(theme.radii.md),
            ),
            child: Icon(
              notification.icon ?? Icons.notifications_none,
              size: context.sz(theme.sizes.iconSm),
              color: notification.read
                  ? theme.colors.foregroundMuted
                  : theme.colors.primary,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(notification.title, style: context.uiText.bodyStrong),
                if (notification.body != null)
                  Text(
                    notification.body!,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  AppTokens.relativeTime(notification.createdAt),
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            UiIconButton(
              icon: Icons.close,
              size: UiSize.sm,
              tooltip: 'Dismiss',
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}

/// Built-in real sharing sheet for [AppPostCard] and domain [CommunityPostCard].
class AppPostShareModal extends StatefulWidget {
  const AppPostShareModal({
    super.key,
    required this.postId,
    required this.authorName,
    required this.authorHandle,
    this.authorAvatarUrl,
    this.authorBadge,
    required this.body,
    this.tickers = const <String>[],
  });

  final String postId;
  final String authorName;
  final String authorHandle;
  final String? authorAvatarUrl;
  final String? authorBadge;
  final String body;
  final List<String> tickers;

  static String postUrlFor(String postId) =>
      'https://community.alphajournal.in/community/post/$postId?public=true';

  static String formatShareText({
    required String postId,
    required String authorName,
    required String authorHandle,
    required String body,
    List<String> tickers = const <String>[],
  }) {
    final StringBuffer buf = StringBuffer();
    final String handle = authorHandle.startsWith('@')
        ? authorHandle
        : '@$authorHandle';
    final String clean = body.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');
    final String excerpt = clean.length <= 280
        ? clean
        : '${clean.substring(0, 280).trimRight()}…';
    buf.writeln('$authorName ($handle) on alphajournal');
    buf.writeln();
    buf.writeln('“$excerpt”');
    if (tickers.isNotEmpty) {
      buf.writeln();
      buf.writeln(
        tickers.map((t) => t.startsWith('\$') ? t : '\$$t').join(' '),
      );
    }
    buf.writeln();
    buf.writeln('View on alphajournal Community:');
    buf.write(postUrlFor(postId));
    return buf.toString();
  }

  static Future<void> showForPost(BuildContext context, AppPost post) {
    return _present(
      context,
      AppPostShareModal(
        postId: post.id,
        authorName: post.author.displayName ?? post.author.handle,
        authorHandle: post.author.handle,
        authorAvatarUrl: post.author.avatarUrl,
        body: post.body,
        tickers: post.tickers,
      ),
    );
  }

  static Future<void> showSimple(
    BuildContext context, {
    String? postId,
    required String authorName,
    String? authorHandle,
    String? authorBadge,
    required String body,
    List<String> tickers = const <String>[],
  }) {
    final String resolvedHandle =
        authorHandle ??
        authorName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final String resolvedId =
        postId ?? 'post-${authorName.hashCode.abs()}';
    return _present(
      context,
      AppPostShareModal(
        postId: resolvedId,
        authorName: authorName,
        authorHandle: resolvedHandle,
        authorBadge: authorBadge,
        body: body,
        tickers: tickers,
      ),
    );
  }

  static Future<void> _present(BuildContext context, Widget child) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ctx.sz(520),
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: Container(
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
            padding: EdgeInsets.fromLTRB(
              ctx.sp(ctx.ui.spacing.md),
              ctx.sp(ctx.ui.spacing.sm),
              ctx.sp(ctx.ui.spacing.md),
              ctx.sp(ctx.ui.spacing.lg),
            ),
            child: SafeArea(top: false, child: child),
          ),
        ),
      ),
    );
  }

  @override
  State<AppPostShareModal> createState() => _AppPostShareModalState();
}

class _AppPostShareModalState extends State<AppPostShareModal> {
  bool _copied = false;

  String get _url => AppPostShareModal.postUrlFor(widget.postId);

  String get _shareText => AppPostShareModal.formatShareText(
    postId: widget.postId,
    authorName: widget.authorName,
    authorHandle: widget.authorHandle,
    body: widget.body,
    tickers: widget.tickers,
  );

  Future<void> _launchExternal(
    BuildContext hostContext, {
    required Uri uri,
    required String label,
  }) async {
    await Clipboard.setData(ClipboardData(text: _shareText));
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      try {
        await SharePlus.instance.share(ShareParams(text: _shareText));
      } catch (_) {}
    }
    if (hostContext.mounted) {
      UiToast.show(
        hostContext,
        title: launched ? 'Opening $label' : 'Ready to share on $label',
        message: 'Post text & link copied to clipboard.',
        intent: UiIntent.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String cleanHandle = widget.authorHandle.replaceFirst(
      RegExp(r'^@'),
      '',
    );

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: context.sz(36),
              height: context.sz(4),
              margin: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              decoration: BoxDecoration(
                color: theme.colors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Share Post',
                  style: context.uiText.heading.copyWith(
                    fontSize: context.fs(16),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              UiIconButton(
                icon: Icons.close_rounded,
                size: UiSize.xs,
                variant: UiVariant.ghost,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiCard(
            variant: UiCardVariant.outlined,
            density: UiDensity.compact,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    UiAvatar(
                      name: widget.authorName,
                      imageUrl: widget.authorAvatarUrl,
                      size: UiSize.xs,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Expanded(
                      child: Text(
                        '${widget.authorName} · @$cleanHandle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.authorBadge != null)
                      UiBadge(
                        label: widget.authorBadge!,
                        size: UiSize.xs,
                        intent: UiIntent.primary,
                      ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  widget.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          UiCard(
            variant: UiCardVariant.surface,
            density: UiDensity.compact,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.link_rounded,
                  size: context.sz(16),
                  color: theme.colors.primary,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  child: Text(
                    _url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.mono.copyWith(
                      fontSize: context.fs(11.5),
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                UiButton(
                  key: const ValueKey('app-post-share-copy-link'),
                  label: _copied ? 'Copied' : 'Copy Link',
                  icon: _copied
                      ? Icons.check_rounded
                      : Icons.content_copy_rounded,
                  size: UiSize.xs,
                  variant: _copied ? UiVariant.solid : UiVariant.soft,
                  intent: _copied ? UiIntent.success : UiIntent.primary,
                  onPressed: () {
                    unawaited(
                      Clipboard.setData(
                        ClipboardData(text: _url),
                      ).catchError((_) {}),
                    );
                    setState(() => _copied = true);
                    UiToast.show(
                      context,
                      title: 'Link Copied',
                      message: _url,
                      intent: UiIntent.success,
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              UiButton(
                key: const ValueKey('app-post-share-whatsapp'),
                label: 'WhatsApp',
                icon: Icons.chat_rounded,
                size: UiSize.xs,
                variant: UiVariant.outline,
                onPressed: () async {
                  final BuildContext host = Navigator.of(context).context;
                  Navigator.of(context).pop();
                  await _launchExternal(
                    host,
                    uri: Uri.parse(
                      'https://wa.me/?text=${Uri.encodeComponent(_shareText)}',
                    ),
                    label: 'WhatsApp',
                  );
                },
              ),
              UiButton(
                key: const ValueKey('app-post-share-x'),
                label: 'X / Twitter',
                icon: Icons.alternate_email_rounded,
                size: UiSize.xs,
                variant: UiVariant.outline,
                onPressed: () async {
                  final BuildContext host = Navigator.of(context).context;
                  Navigator.of(context).pop();
                  final String text = '${widget.body} — via @$cleanHandle';
                  await _launchExternal(
                    host,
                    uri: Uri.parse(
                      'https://x.com/intent/tweet?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(_url)}',
                    ),
                    label: 'X / Twitter',
                  );
                },
              ),
              UiButton(
                key: const ValueKey('app-post-share-telegram'),
                label: 'Telegram',
                icon: Icons.near_me_rounded,
                size: UiSize.xs,
                variant: UiVariant.outline,
                onPressed: () async {
                  final BuildContext host = Navigator.of(context).context;
                  Navigator.of(context).pop();
                  await _launchExternal(
                    host,
                    uri: Uri.parse(
                      'https://t.me/share/url?url=${Uri.encodeComponent(_url)}&text=${Uri.encodeComponent(widget.body)}',
                    ),
                    label: 'Telegram',
                  );
                },
              ),
              UiButton(
                key: const ValueKey('app-post-share-native'),
                label: 'System Share...',
                icon: Icons.ios_share_rounded,
                size: UiSize.xs,
                variant: UiVariant.soft,
                intent: UiIntent.primary,
                onPressed: () async {
                  final BuildContext host = Navigator.of(context).context;
                  Navigator.of(context).pop();
                  await Clipboard.setData(ClipboardData(text: _shareText));
                  try {
                    await SharePlus.instance.share(
                      ShareParams(
                        text: _shareText,
                        subject: 'Post by @$cleanHandle on alphajournal',
                      ),
                    );
                  } catch (_) {}
                  if (host.mounted) {
                    UiToast.show(
                      host,
                      title: 'Post Shared',
                      message: 'Shared post and copied to clipboard.',
                      intent: UiIntent.success,
                    );
                  }
                },
              ),
              UiButton(
                key: const ValueKey('app-post-share-copy-text'),
                label: 'Copy Formatted Text',
                icon: Icons.copy_rounded,
                size: UiSize.xs,
                variant: UiVariant.ghost,
                onPressed: () async {
                  final BuildContext host = Navigator.of(context).context;
                  await Clipboard.setData(ClipboardData(text: _shareText));
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  if (host.mounted) {
                    UiToast.show(
                      host,
                      title: 'Copied to Clipboard',
                      message: 'Formatted post text & link copied.',
                      intent: UiIntent.success,
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
