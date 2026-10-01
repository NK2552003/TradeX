import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_live_space_card.dart';

/// Hosted spaces for the same author shown in every public profile preview.
class CommunitySpaceHistory extends StatefulWidget {
  const CommunitySpaceHistory({
    super.key,
    required this.handle,
    this.authorId,
    this.repository,
  });
  final String handle;
  final String? authorId;
  final CommunityRepository? repository;
  @override
  State<CommunitySpaceHistory> createState() => _CommunitySpaceHistoryState();
}

class _CommunitySpaceHistoryState extends State<CommunitySpaceHistory> {
  late final CommunityRepository _repository =
      widget.repository ?? CommunityRepository();
  @override
  void dispose() {
    if (widget.repository == null) _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _repository,
    builder: (context, _) {
      final theme = context.ui;
      final rooms =
          _repository.allLiveRooms
              .where(
                (room) =>
                    room.host.id == widget.authorId ||
                    room.host.handle.toLowerCase().replaceFirst('@', '') ==
                        widget.handle.toLowerCase().replaceFirst('@', ''),
              )
              .toList()
            ..sort(
              (a, b) =>
                  (b.endedAt ?? b.startedAt ?? b.scheduledFor ?? DateTime(1970))
                      .compareTo(
                        a.endedAt ??
                            a.startedAt ??
                            a.scheduledFor ??
                            DateTime(1970),
                      ),
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final status in [
            LiveRoomStatus.live,
            LiveRoomStatus.scheduled,
            LiveRoomStatus.ended,
          ]) ...[
            UiGap.v(theme.spacing.md),
            Text(switch (status) {
              LiveRoomStatus.live => 'Live now',
              LiveRoomStatus.scheduled => 'Upcoming spaces',
              LiveRoomStatus.ended => 'Space history',
            }, style: context.uiText.bodyStrong),
            UiGap.v(theme.spacing.sm),
            if (!rooms.any((room) => room.status == status))
              UiEmptyState(
                icon: Icons.podcasts_rounded,
                title: switch (status) {
                  LiveRoomStatus.live => 'No active spaces',
                  LiveRoomStatus.scheduled => 'No scheduled spaces',
                  LiveRoomStatus.ended => 'No completed spaces yet',
                },
              ),
            for (final room in rooms.where(
              (room) => room.status == status,
            )) ...[
              CommunityLiveSpaceCard(room: room, repository: _repository),
              UiGap.v(theme.spacing.sm),
            ],
          ],
        ],
      );
    },
  );
}
