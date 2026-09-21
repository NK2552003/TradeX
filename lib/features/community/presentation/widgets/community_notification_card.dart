import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';

/// Redesigned notification item card with unread accent indicator, type icon container,
/// actor attribution, and relative timestamp.
class CommunityNotificationCard extends StatelessWidget {
  const CommunityNotificationCard({
    super.key,
    required this.notification,
    this.onTap,
  });

  final CommunityNotificationItem notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isUnread = !notification.read;

    return CommunityTile(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      intent: UiIntent.primary,
      selected: isUnread,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Type Icon Container
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: isUnread
                  ? theme.colors.primary.withValues(alpha: 0.12)
                  : theme.colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.md),
            ),
            child: Icon(
              notification.icon,
              size: context.sz(theme.sizes.iconSm),
              color: isUnread
                  ? theme.colors.primary
                  : theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.md)),

          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foreground,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: notification.actor.displayName,
                        style: context.uiText.bodyStrong.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colors.foreground,
                        ),
                      ),
                      TextSpan(
                        text: ' ${notification.label}',
                        style: TextStyle(color: theme.colors.foregroundMuted),
                      ),
                    ],
                  ),
                ),
                if (notification.postSnippet != null) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    notification.postSnippet!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  AppTokens.relativeTime(notification.createdAt),
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                    fontSize: context.fs(11),
                  ),
                ),
              ],
            ),
          ),

          // Unread indicator dot
          if (isUnread)
            Container(
              width: context.sz(8),
              height: context.sz(8),
              margin: EdgeInsets.only(
                top: context.sp(theme.spacing.xs),
                left: context.sp(theme.spacing.xs),
              ),
              decoration: BoxDecoration(
                color: theme.colors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
