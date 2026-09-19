import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Modal bottom sheet representing a live trading audio space / trading floor.
class CommunityLiveRoomSheet extends StatefulWidget {
  const CommunityLiveRoomSheet({
    super.key,
    this.roomTitle = 'Nifty & BankNifty Live Expiry Floor',
    this.hostName = 'Rajesh Sharma, CMT',
    this.listenerCount = 142,
  });

  final String roomTitle;
  final String hostName;
  final int listenerCount;

  static Future<void> show(
    BuildContext context, {
    String? roomTitle,
    String? hostName,
    int? listenerCount,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommunityLiveRoomSheet(
        roomTitle: roomTitle ?? 'Nifty & BankNifty Live Expiry Floor',
        hostName: hostName ?? 'Rajesh Sharma, CMT',
        listenerCount: listenerCount ?? 142,
      ),
    );
  }

  @override
  State<CommunityLiveRoomSheet> createState() => _CommunityLiveRoomSheetState();
}

class _CommunityLiveRoomSheetState extends State<CommunityLiveRoomSheet> {
  bool _isMuted = true;
  bool _isHandRaised = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final speakers = [
      (name: widget.hostName, role: 'Host', isSpeaking: true),
      (name: 'Sarah Chen, Quant', role: 'Speaker', isSpeaking: false),
      (name: 'Vikram Joshi', role: 'Speaker', isSpeaking: false),
    ];

    final listeners = [
      'Aman Gupta', 'Deepak K.', 'Priya Patel', 'Rahul M.', 'Aditya V.',
      'Meera S.', 'Kunal S.', 'Rohan Roy', 'Tanvi B.', 'Arun K.'
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.sz(20))),
        border: Border.all(color: colors.border),
      ),
      padding: EdgeInsets.fromLTRB(
        context.sp(20),
        context.sp(12),
        context.sp(20),
        context.sp(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: context.sz(40),
              height: context.sz(4),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(context.sz(2)),
              ),
            ),
          ),
          SizedBox(height: context.sp(16)),

          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: context.sp(8), vertical: context.sp(4)),
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(context.sz(6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: context.sz(6),
                      height: context.sz(6),
                      decoration: BoxDecoration(
                        color: colors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: context.sp(6)),
                    Text(
                      'LIVE SPACE',
                      style: context.uiText.label.copyWith(
                        color: colors.danger,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.sp(10)),
              Row(
                children: [
                  Icon(Icons.people_outline, size: context.sz(16), color: colors.foregroundMuted),
                  SizedBox(width: context.sp(4)),
                  Text(
                    '${widget.listenerCount} listening',
                    style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
                  ),
                ],
              ),
              const Spacer(),
              UiIconButton(
                icon: Icons.close,
                size: UiSize.sm,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(height: context.sp(12)),

          Text(
            widget.roomTitle,
            style: context.uiText.heading.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.foreground,
            ),
          ),
          SizedBox(height: context.sp(20)),

          // Speakers Stage
          Text(
            'SPEAKERS',
            style: context.uiText.label.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.foregroundMuted,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: context.sp(12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: speakers.map((s) {
              return Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.sp(3)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: s.isSpeaking ? colors.success : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: UiAvatar(
                          name: s.name,
                          size: UiSize.lg,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(context.sp(4)),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(
                          s.isSpeaking ? Icons.mic : Icons.mic_off,
                          size: context.sz(12),
                          color: s.isSpeaking ? colors.success : colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(6)),
                  Text(
                    s.name.split(' ').first,
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                  Text(
                    s.role,
                    style: context.uiText.label.copyWith(
                      color: colors.foregroundMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          SizedBox(height: context.sp(24)),

          // Listeners preview
          Text(
            'LISTENERS',
            style: context.uiText.label.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.foregroundMuted,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: context.sp(12)),
          Wrap(
            spacing: context.sp(12),
            runSpacing: context.sp(12),
            children: listeners.take(8).map((name) {
              return Column(
                children: [
                  UiAvatar(name: name, size: UiSize.sm),
                  SizedBox(height: context.sp(4)),
                  SizedBox(
                    width: context.sz(52),
                    child: Text(
                      name.split(' ').first,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.label.copyWith(
                        color: colors.foregroundMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          SizedBox(height: context.sp(28)),

          // Controls
          Container(
            padding: EdgeInsets.all(context.sp(12)),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(context.sz(14)),
            ),
            child: Row(
              children: [
                UiIconButton(
                  icon: _isMuted ? Icons.mic_off_outlined : Icons.mic,
                  intent: _isMuted ? UiIntent.primary : UiIntent.success,
                  tooltip: _isMuted ? 'Unmute' : 'Mute',
                  onPressed: () => setState(() => _isMuted = !_isMuted),
                ),
                SizedBox(width: context.sp(8)),
                UiIconButton(
                  icon: _isHandRaised ? Icons.pan_tool : Icons.pan_tool_outlined,
                  intent: _isHandRaised ? UiIntent.primary : UiIntent.info,
                  tooltip: 'Raise Hand',
                  onPressed: () {
                    setState(() => _isHandRaised = !_isHandRaised);
                    UiToast.show(
                      context,
                      title: 'Live Space',
                      message: _isHandRaised ? 'Hand raised to speak' : 'Hand lowered',
                    );
                  },
                ),
                const Spacer(),
                UiButton(
                  label: 'Leave Room',
                  variant: UiVariant.outline,
                  icon: Icons.logout,
                  size: UiSize.sm,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
