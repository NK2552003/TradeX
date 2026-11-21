import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_design.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_live_room_sheet.dart';

/// Floating docked mini-player mounted in the community platform when a trader
/// is tuned into an active live audio space.
class CommunityAudioMiniPlayer extends StatefulWidget {
  const CommunityAudioMiniPlayer({super.key, required this.repository});

  final CommunityRepository repository;

  @override
  State<CommunityAudioMiniPlayer> createState() =>
      _CommunityAudioMiniPlayerState();
}

class _CommunityAudioMiniPlayerState extends State<CommunityAudioMiniPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _waveController.stop();
      _waveController.value = 0.5;
    } else if (!_waveController.isAnimating) {
      _waveController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _expandRoom(LiveAudioRoom room) {
    CommunityLiveRoomSheet.show(
      context,
      roomId: room.id,
      roomTitle: room.title,
      hostName: room.host.displayName,
      repository: widget.repository,
      listenerCount: room.listenerCount,
      pinnedSetup: room.pinnedSetup,
      onLeave: () => widget.repository.leaveRoom(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LiveAudioRoom? room = widget.repository.activeTunedRoom;
    if (room == null) return const SizedBox.shrink();

    final theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final isMuted = widget.repository.isAudioMuted;

    return CommunityDensityScope(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _expandRoom(room),
          borderRadius: BorderRadius.circular(theme.radii.pill),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? context.sz(320) : context.sz(380),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.sm),
              vertical: context.sp(theme.spacing.xs),
            ),
            decoration: BoxDecoration(
              color: theme.colors.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(theme.radii.pill),
              border: Border.all(
                color: theme.colors.danger.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: theme.colors.danger.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Animated soundwave bars
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      final v = _waveController.value;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _WaveBar(
                            height: 6 + (v * 10),
                            color: theme.colors.danger,
                          ),
                          const SizedBox(width: 2),
                          _WaveBar(
                            height: 14 - (v * 8),
                            color: theme.colors.danger,
                          ),
                          const SizedBox(width: 2),
                          _WaveBar(
                            height: 8 + (v * 8),
                            color: theme.colors.danger,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),

                // Host Avatar
                UiAvatar(
                  name: room.host.displayName,
                  imageUrl: room.host.avatarUrl,
                  size: UiSize.xs,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),

                // Room details
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          UiBadge(
                            label: 'LIVE',
                            intent: UiIntent.danger,
                            size: UiSize.xs,
                          ),
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                          Expanded(
                            child: Text(
                              room.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${room.host.displayName} · ${room.listenerCount} listening',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.label.copyWith(
                          fontSize: context.fs(10),
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),

                // Mute toggle
                UiIconButton(
                  icon: isMuted ? Icons.mic_off_outlined : Icons.mic_rounded,
                  size: UiSize.xs,
                  intent: isMuted ? UiIntent.primary : UiIntent.success,
                  tooltip: isMuted ? 'Unmute Mic' : 'Mute Mic',
                  onPressed: () => widget.repository.toggleMute(),
                ),
                SizedBox(width: context.sp(theme.spacing.xxs)),

                // Expand sheet
                UiIconButton(
                  icon: Icons.open_in_full_rounded,
                  size: UiSize.xs,
                  variant: UiVariant.ghost,
                  tooltip: 'Expand Room',
                  onPressed: () => _expandRoom(room),
                ),
                SizedBox(width: context.sp(theme.spacing.xxs)),

                // Leave space
                UiIconButton(
                  icon: Icons.close_rounded,
                  size: UiSize.xs,
                  variant: UiVariant.ghost,
                  tooltip: 'Leave Quietly',
                  onPressed: () => widget.repository.leaveRoom(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveBar extends StatelessWidget {
  const _WaveBar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
