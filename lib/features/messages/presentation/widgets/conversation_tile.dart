import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/widgets/presence_avatar.dart';

/// A single thread row in the inbox list.
///
/// Presence, unread count, pin/mute markers, a delivery tick on the last
/// outgoing message and a "typing…" state all render from the [thread] — no
/// literal content lives here.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.thread,
    required this.typing,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  final MessageThread thread;
  final bool typing;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool unread = thread.hasUnread;

    return UiInteractive(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      builder: (BuildContext context, UiInteractiveState state) {
        final bool active = state.hovered || state.pressed;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.sm),
          ),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.08)
                : active
                ? colors.surfaceHover
                : Colors.transparent,
            borderRadius: context.radius(theme.radii.md),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.35)
                  : Colors.transparent,
              width: theme.borders.hairline,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              MessagesThreadAvatar(thread: thread, size: UiSize.md),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(child: _body(context, unread)),
              SizedBox(width: context.sp(theme.spacing.xs)),
              _trailing(context, unread),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, bool unread) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                thread.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.bodyStrong.copyWith(
                  fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
            if (thread.peer.verified && !thread.isGroup) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Icon(
                Icons.verified_rounded,
                size: context.sz(13),
                color: colors.primary,
              ),
            ],
            if (thread.pinned) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Icon(
                Icons.push_pin_rounded,
                size: context.sz(12),
                color: colors.foregroundSubtle,
              ),
            ],
            if (thread.muted) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Icon(
                Icons.notifications_off_rounded,
                size: context.sz(12),
                color: colors.foregroundSubtle,
              ),
            ],
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Row(
          children: <Widget>[
            if (thread.lastFromMe && !typing) ...<Widget>[
              Icon(
                thread.lastStatus.icon,
                size: context.sz(14),
                color: thread.lastStatus == MessageStatus.read
                    ? colors.primary
                    : colors.foregroundSubtle,
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
            ],
            Expanded(
              child: typing
                  ? Text(
                      'typing…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: colors.bullish,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Text(
                      thread.lastMessagePreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: unread
                            ? colors.foreground
                            : colors.foregroundMuted,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _trailing(BuildContext context, bool unread) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          AppTokens.relativeTime(thread.lastMessageAt),
          style: context.uiText.caption.copyWith(
            color: unread ? colors.primary : colors.foregroundSubtle,
            fontSize: context.fs(10.5),
            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        if (unread)
          Container(
            constraints: BoxConstraints(minWidth: context.sz(18)),
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.xxs),
              vertical: context.sz(1),
            ),
            decoration: BoxDecoration(
              color: thread.muted ? colors.foregroundSubtle : colors.primary,
              borderRadius: BorderRadius.circular(context.sz(999)),
            ),
            child: Text(
              thread.unread > 99 ? '99+' : '${thread.unread}',
              textAlign: TextAlign.center,
              style: context.uiText.caption.copyWith(
                color: colors.onPrimary,
                fontSize: context.fs(10),
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          )
        else
          SizedBox(height: context.sz(18)),
      ],
    );
  }
}
