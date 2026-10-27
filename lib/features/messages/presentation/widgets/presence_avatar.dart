import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/models/messages_models.dart';

/// Thread avatar: a presence-dot avatar for direct messages, or a small stacked
/// cluster for groups. Built on the shared [AppPresenceAvatar] so presence reads
/// the same here as everywhere else.
class MessagesThreadAvatar extends StatelessWidget {
  const MessagesThreadAvatar({
    super.key,
    required this.thread,
    this.size = UiSize.md,
    this.showPresence = true,
    this.onTap,
  });

  final MessageThread thread;
  final UiSize size;
  final bool showPresence;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (thread.isGroup) {
      return _GroupCluster(thread: thread, size: size, onTap: onTap);
    }
    return AppPresenceAvatar(
      imageUrl: thread.avatarUrl,
      name: thread.title,
      size: size,
      verified: thread.peer.verified,
      presenceColor: showPresence ? thread.presence.color(context) : null,
      presenceLabel: showPresence ? thread.presence.label : null,
      onTap: onTap,
    );
  }
}

class _GroupCluster extends StatelessWidget {
  const _GroupCluster({required this.thread, required this.size, this.onTap});

  final MessageThread thread;
  final UiSize size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final List<AppTrader> members = thread.participants.take(2).toList();
    final double dim = size.avatar(context);
    final double small = dim * 0.62;

    Widget cluster = SizedBox(
      width: dim,
      height: dim,
      child: Stack(
        children: <Widget>[
          if (members.isNotEmpty)
            Positioned(
              left: 0,
              top: 0,
              child: UiAvatar(
                imageUrl: members.first.avatarUrl,
                name: members.first.displayName ?? members.first.handle,
                size: UiSize.sm,
              ),
            ),
          if (members.length > 1)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.uiColors.surface,
                    width: context.sz(1.5),
                  ),
                ),
                child: UiAvatar(
                  imageUrl: members[1].avatarUrl,
                  name: members[1].displayName ?? members[1].handle,
                  size: UiSize.xs,
                ),
              ),
            ),
          SizedBox(width: small, height: small),
        ],
      ),
    );

    if (onTap != null) {
      cluster = GestureDetector(onTap: onTap, child: cluster);
    }
    return cluster;
  }
}
