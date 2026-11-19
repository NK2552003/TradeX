import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_live_room_sheet.dart';

/// Shared responsive presentation for live, scheduled and completed spaces.
class CommunityLiveSpaceCard extends StatelessWidget {
  const CommunityLiveSpaceCard({
    super.key,
    required this.room,
    required this.repository,
  });
  final LiveAudioRoom room;
  final CommunityRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final ended = room.status == LiveRoomStatus.ended;
    return UiCard(
      accentColor: room.isLive ? theme.colors.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: [
              UiBadge(
                label: ended
                    ? 'ENDED'
                    : room.isLive
                    ? 'SIMULATED AUDIO (BETA)'
                    : 'SCHEDULED',
                intent: room.isLive ? UiIntent.warning : UiIntent.neutral,
                size: UiSize.xs,
              ),
              UiBadge(
                label: room.category,
                variant: UiBadgeVariant.outline,
                size: UiSize.xs,
              ),
              UiBadge(
                label:
                    '${room.listenerCount} ${ended ? 'attended' : 'listening'}',
                icon: Icons.headphones_rounded,
                size: UiSize.xs,
              ),
            ],
          ),
          UiGap.v(theme.spacing.sm),
          Text(room.title, style: context.uiText.bodyStrong),
          if (room.endedAt != null)
            Text(
              'Ended: ${room.endedAt!.toLocal()}',
              style: context.uiText.caption,
            ),
          UiGap.v(theme.spacing.xs),
          Text(room.topic, style: context.uiText.body),
          if (room.scheduledFor != null && room.isScheduled) ...[
            UiGap.v(theme.spacing.xs),
            Text(
              'Scheduled: ${room.scheduledFor!.toLocal()}',
              style: context.uiText.caption,
            ),
          ],
          if (room.pinnedSetup != null) ...[
            UiGap.v(theme.spacing.sm),
            UiCard(
              variant: UiCardVariant.surface,
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              child: Wrap(
                spacing: context.sp(theme.spacing.sm),
                runSpacing: context.sp(theme.spacing.xs),
                children: [
                  UiBadge(
                    label: room.pinnedSetup!.side,
                    intent: room.pinnedSetup!.side == 'LONG'
                        ? UiIntent.success
                        : UiIntent.danger,
                    size: UiSize.xs,
                  ),
                  Text(
                    room.pinnedSetup!.ticker,
                    style: context.uiText.bodyStrong,
                  ),
                  Text(
                    'Entry: ₹${room.pinnedSetup!.entry.toStringAsFixed(1)}',
                    style: context.uiText.caption,
                  ),
                  Text(
                    'Target: ₹${room.pinnedSetup!.target.toStringAsFixed(1)}',
                    style: context.uiText.caption,
                  ),
                ],
              ),
            ),
          ],
          UiGap.v(theme.spacing.sm),
          Row(
            children: [
              UiAvatar(
                name: room.host.displayName,
                imageUrl: room.host.avatarUrl,
                size: UiSize.sm,
              ),
              UiGap.h(theme.spacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hosted by ${room.host.displayName}',
                      style: context.uiText.bodyStrong,
                    ),
                    if (room.speakers.isNotEmpty)
                      Text(
                        'Stage: ${room.speakers.join(', ')}',
                        style: context.uiText.caption,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (room.isLive && room.host.id == repository.currentAuthor.id) ...[
            UiGap.v(theme.spacing.sm),
            UiButton(
              label: 'End Space',
              size: UiSize.sm,
              variant: UiVariant.outline,
              intent: UiIntent.danger,
              onPressed: () => repository.endLiveRoom(room.id),
            ),
          ],
          if (!ended) ...[
            UiGap.v(theme.spacing.sm),
            UiButton(
              label: room.isScheduled
                  ? room.hasReminder
                        ? 'Reminder Set'
                        : 'Remind Me'
                  : 'Tune In',
              leadingIcon: room.isScheduled
                  ? Icons.notifications_outlined
                  : Icons.volume_up_rounded,
              size: UiSize.sm,
              expand: true,
              onPressed: room.isScheduled
                  ? () => repository.toggleRoomReminder(room.id)
                  : () => CommunityLiveRoomSheet.show(
                      context,
                      roomId: room.id,
                      roomTitle: room.title,
                      hostName: room.host.displayName,
                      listenerCount: room.listenerCount,
                      pinnedSetup: room.pinnedSetup,
                      repository: repository,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
