import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';

/// Pinned trade setup shared inside the live audio space.
class LivePinnedSetup {
  const LivePinnedSetup({
    required this.ticker,
    required this.side,
    required this.entry,
    required this.stopLoss,
    required this.target,
    required this.note,
  });

  final String ticker;
  final String side; // 'LONG' or 'SHORT'
  final double entry;
  final double stopLoss;
  final double target;
  final String note;

  double get risk => (entry - stopLoss).abs();
  double get reward => (target - entry).abs();
  double get rrRatio => risk > 0 ? (reward / risk) : 1.0;
}

/// Floating reaction item for the upward floating animation.
class _FloatingEmoji {
  _FloatingEmoji({
    required this.id,
    required this.emoji,
    required this.horizontalOffset,
  });

  final int id;
  final String emoji;
  final double horizontalOffset;
}

/// A single live chat message inside the Live Space audio room.
class _LiveRoomChatMessage {
  const _LiveRoomChatMessage({
    required this.id,
    required this.author,
    required this.message,
    required this.time,
    this.isHost = false,
    this.isSpeaker = false,
  });

  final String id;
  final String author;
  final String message;
  final String time;
  final bool isHost;
  final bool isSpeaker;
}

/// Modal bottom sheet representing a full-featured live trading audio space / trading floor.
class CommunityLiveRoomSheet extends StatefulWidget {
  const CommunityLiveRoomSheet({
    super.key,
    this.roomTitle = 'Nifty & BankNifty Live Expiry Floor',
    this.hostName = 'Rajesh Sharma, CMT',
    this.listenerCount = 142,
    this.pinnedSetup = const LivePinnedSetup(
      ticker: 'NIFTY 24,850 CE',
      side: 'LONG',
      entry: 142.50,
      stopLoss: 118.00,
      target: 210.00,
      note: 'VWAP breakout with strong CE OI unwinding at 24,800 strike.',
    ),
    this.onMinimize,
  });

  final String roomTitle;
  final String hostName;
  final int listenerCount;
  final LivePinnedSetup? pinnedSetup;
  final VoidCallback? onMinimize;

  static Future<void> show(
    BuildContext context, {
    String? roomTitle,
    String? hostName,
    int? listenerCount,
    LivePinnedSetup? pinnedSetup,
    VoidCallback? onMinimize,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => CommunityDensityScope(
        child: CommunityLiveRoomSheet(
          roomTitle: roomTitle ?? 'Nifty & BankNifty Live Expiry Floor',
          hostName: hostName ?? 'Rajesh Sharma, CMT',
          listenerCount: listenerCount ?? 142,
          pinnedSetup: pinnedSetup ??
              const LivePinnedSetup(
                ticker: 'NIFTY 24,850 CE',
                side: 'LONG',
                entry: 142.50,
                stopLoss: 118.00,
                target: 210.00,
                note:
                    'VWAP breakout with strong CE OI unwinding at 24,800 strike.',
              ),
          onMinimize: onMinimize,
        ),
      ),
    );
  }

  @override
  State<CommunityLiveRoomSheet> createState() => _CommunityLiveRoomSheetState();
}

class _CommunityLiveRoomSheetState extends State<CommunityLiveRoomSheet>
    with TickerProviderStateMixin {
  int _roomTabIndex = 0;
  bool _isMuted = true;
  bool _isHandRaised = false;
  late AnimationController _soundwaveController;

  // Floating emojis list
  final List<_FloatingEmoji> _floatingEmojis = <_FloatingEmoji>[];
  final math.Random _random = math.Random();

  // Raised hands queue
  final List<String> _raisedHandsQueue = <String>[
    'Aman Gupta',
    'Priya Patel',
    'Deepak K.',
  ];

  // Stage speakers
  final List<String> _speakers = <String>[
    'Rajesh Sharma, CMT',
    'Sarah Chen, Quant',
    'Vikram Joshi',
  ];

  // Room Listeners
  final List<String> _listeners = <String>[
    'Aman Gupta',
    'Deepak K.',
    'Priya Patel',
    'Rahul M.',
    'Aditya V.',
    'Meera S.',
    'Kunal S.',
    'Rohan Roy',
    'Tanvi B.',
    'Arun K.',
    'Neha V.',
    'Suresh P.',
  ];

  // Live Sentiment Poll state
  int? _userPollVote;
  int _pollVotesBullish = 98;
  int _pollVotesBearish = 44;

  // Live Chat state
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<_LiveRoomChatMessage> _chatMessages = <_LiveRoomChatMessage>[
    const _LiveRoomChatMessage(
      id: 'c1',
      author: 'Vikram Joshi',
      message:
          'VWAP breakout holding firmly above 24,840. CE volumes accelerating!',
      time: '2m ago',
      isSpeaker: true,
    ),
    const _LiveRoomChatMessage(
      id: 'c2',
      author: 'Priya Patel',
      message: 'Should we book 50% at 180 or hold for 210 target?',
      time: '1m ago',
    ),
    const _LiveRoomChatMessage(
      id: 'c3',
      author: 'Rajesh Sharma, CMT',
      message: 'Trail SL to 125 immediately. Lock in partial risk-free gains.',
      time: 'Just now',
      isHost: true,
    ),
    const _LiveRoomChatMessage(
      id: 'c4',
      author: 'Aman Gupta',
      message: 'Loaded 4 lots on paper desk. Great risk-reward setup!',
      time: 'Just now',
    ),
  ];

  // Audio Device state
  String _audioDevice = 'Phone Speaker';
  bool _isRecordingReplay = true;

  @override
  void initState() {
    super.initState();
    _soundwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _soundwaveController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _triggerReaction(String emoji) {
    final int id = DateTime.now().microsecondsSinceEpoch;
    final double offset = (_random.nextDouble() * 120) - 60;
    setState(() {
      _floatingEmojis.add(
        _FloatingEmoji(id: id, emoji: emoji, horizontalOffset: offset),
      );
    });

    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _floatingEmojis.removeWhere((e) => e.id == id);
        });
      }
    });
  }

  void _toggleHand() {
    setState(() {
      _isHandRaised = !_isHandRaised;
      if (_isHandRaised) {
        _raisedHandsQueue.add('You (Alex Vance)');
      } else {
        _raisedHandsQueue.remove('You (Alex Vance)');
      }
    });
    UiToast.show(
      context,
      title: 'Live Space',
      message: _isHandRaised
          ? 'Hand raised! The host has been notified.'
          : 'Hand lowered.',
    );
  }

  void _acceptSpeaker(String name) {
    setState(() {
      _raisedHandsQueue.remove(name);
      _listeners.remove(name);
      if (!_speakers.contains(name)) {
        _speakers.add(name);
      }
    });
    UiToast.success(
      context,
      title: 'Speaker Added',
      message: '$name has been invited to speak.',
    );
  }

  void _dismissSpeaker(String name) {
    setState(() {
      _raisedHandsQueue.remove(name);
    });
  }

  void _sendChatMessage() {
    final String text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add(
        _LiveRoomChatMessage(
          id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
          author: 'You (Alex Vance)',
          message: text,
          time: 'Just now',
        ),
      );
      _chatController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _votePoll(int choice) {
    if (_userPollVote == choice) return;

    setState(() {
      if (_userPollVote == 0) _pollVotesBullish--;
      if (_userPollVote == 1) _pollVotesBearish--;

      _userPollVote = choice;
      if (choice == 0) _pollVotesBullish++;
      if (choice == 1) _pollVotesBearish++;
    });

    UiToast.success(
      context,
      title: 'Live Poll',
      message: choice == 0
          ? 'Bullish vote recorded!'
          : 'Bearish vote recorded!',
    );
  }

  void _toggleAudioDevice() {
    setState(() {
      _audioDevice = switch (_audioDevice) {
        'Phone Speaker' => 'Headset',
        'Headset' => 'Bluetooth HD',
        _ => 'Phone Speaker',
      };
    });
    UiToast.info(
      context,
      title: 'Audio Output',
      message: 'Audio output set to $_audioDevice',
    );
  }

  void _shareSpace() {
    UiToast.success(
      context,
      title: 'Share Space',
      message: 'Live space link copied: tradex.ai/spaces/nifty-expiry-104',
    );
  }

  void _showSpeakerModal(String name) {
    final bool isHost = name == widget.hostName;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final UiTheme theme = ctx.ui;
        return Container(
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radii.lg),
            ),
            border: Border.all(color: theme.colors.border),
          ),
          padding: EdgeInsets.all(ctx.sp(theme.spacing.md)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  UiAvatar(name: name, size: UiSize.md),
                  SizedBox(width: ctx.sp(theme.spacing.sm)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(name, style: ctx.uiText.bodyStrong),
                        Text(
                          isHost ? 'Room Host & Founder' : 'Featured Speaker',
                          style: ctx.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiBadge(
                    label: isHost ? 'HOST' : 'SPEAKER',
                    intent: isHost ? UiIntent.primary : UiIntent.success,
                    size: UiSize.xs,
                  ),
                ],
              ),
              SizedBox(height: ctx.sp(theme.spacing.md)),
              UiButton(
                label: 'View Trader Profile',
                leadingIcon: Icons.person_outline_rounded,
                variant: UiVariant.outline,
                expand: true,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  UiToast.info(
                    context,
                    title: name,
                    message: 'Opening $name\'s public verified profile',
                  );
                },
              ),
              SizedBox(height: ctx.sp(theme.spacing.xs)),
              if (!isHost) ...<Widget>[
                UiButton(
                  label: 'Mute Speaker',
                  leadingIcon: Icons.mic_off_outlined,
                  variant: UiVariant.soft,
                  intent: UiIntent.warning,
                  expand: true,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    UiToast.info(
                      context,
                      title: 'Moderation',
                      message: '$name has been muted.',
                    );
                  },
                ),
                SizedBox(height: ctx.sp(theme.spacing.xs)),
                UiButton(
                  label: 'Move Back to Listeners',
                  leadingIcon: Icons.group_outlined,
                  variant: UiVariant.ghost,
                  intent: UiIntent.danger,
                  expand: true,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _speakers.remove(name);
                      if (!_listeners.contains(name)) _listeners.add(name);
                    });
                    UiToast.show(
                      context,
                      title: 'Stage',
                      message: '$name moved to listeners.',
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showListenerModal(String name) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final UiTheme theme = ctx.ui;
        return Container(
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radii.lg),
            ),
            border: Border.all(color: theme.colors.border),
          ),
          padding: EdgeInsets.all(ctx.sp(theme.spacing.md)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  UiAvatar(name: name, size: UiSize.md),
                  SizedBox(width: ctx.sp(theme.spacing.sm)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(name, style: ctx.uiText.bodyStrong),
                        Text(
                          'Community Trader · Listener',
                          style: ctx.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ctx.sp(theme.spacing.md)),
              UiButton(
                label: 'Invite to Speak on Stage',
                leadingIcon: Icons.mic_rounded,
                variant: UiVariant.primary,
                intent: UiIntent.primary,
                expand: true,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _acceptSpeaker(name);
                },
              ),
              SizedBox(height: ctx.sp(theme.spacing.xs)),
              UiButton(
                label: 'Send Direct Message',
                leadingIcon: Icons.chat_bubble_outline_rounded,
                variant: UiVariant.outline,
                expand: true,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  UiToast.info(
                    context,
                    title: 'Chat',
                    message: 'Opening direct chat with $name',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;

    return Stack(
      children: <Widget>[
        Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radii.xl),
            ),
            border: Border.all(color: theme.colors.border),
          ),
          padding: EdgeInsets.fromLTRB(
            context.sp(theme.spacing.md),
            context.sp(theme.spacing.xs),
            context.sp(theme.spacing.md),
            context.sp(theme.spacing.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Drag Handle
              Center(
                child: Container(
                  width: context.sz(40),
                  height: context.sz(4),
                  margin: EdgeInsets.symmetric(
                    vertical: context.sp(theme.spacing.xs),
                  ),
                  decoration: BoxDecoration(
                    color: theme.colors.border,
                    borderRadius: BorderRadius.circular(theme.radii.pill),
                  ),
                ),
              ),

              // Header bar
              Row(
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.xs),
                      vertical: context.sp(theme.spacing.xxs),
                    ),
                    decoration: BoxDecoration(
                      color: theme.colors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(theme.radii.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: context.sz(6),
                          height: context.sz(6),
                          decoration: BoxDecoration(
                            color: theme.colors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: context.sp(theme.spacing.xxs)),
                        Text(
                          'LIVE SPACE',
                          style: context.uiText.label.copyWith(
                            color: theme.colors.danger,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.headphones_rounded,
                        size: context.sz(14),
                        color: theme.colors.foregroundMuted,
                      ),
                      SizedBox(width: context.sp(theme.spacing.xxs)),
                      Text(
                        '${widget.listenerCount} listening',
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Share Space
                  UiIconButton(
                    icon: Icons.share_rounded,
                    variant: UiVariant.ghost,
                    size: UiSize.sm,
                    tooltip: 'Share Space',
                    onPressed: _shareSpace,
                  ),
                  // Minimize button
                  UiIconButton(
                    icon: Icons.minimize_rounded,
                    variant: UiVariant.ghost,
                    size: UiSize.sm,
                    tooltip: 'Minimize Space',
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onMinimize?.call();
                    },
                  ),
                  UiIconButton(
                    icon: Icons.close_rounded,
                    variant: UiVariant.ghost,
                    size: UiSize.sm,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),

              // Room Title & Recording Chip
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.roomTitle,
                      style: context.uiText.heading.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: isMobile ? context.fs(16) : context.fs(18),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isRecordingReplay)
                    UiBadge(
                      label: 'REC',
                      intent: UiIntent.danger,
                      variant: UiBadgeVariant.soft,
                      size: UiSize.xs,
                    ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),

              // In-Room Sub Tabs
              UiTabs(
                tabs: <String>[
                  'Stage',
                  'Live Chat (${_chatMessages.length})',
                  'Poll & Setup',
                  'Room Info',
                ],
                selectedIndex: _roomTabIndex,
                onChanged: (int idx) => setState(() => _roomTabIndex = idx),
                variant: UiTabsVariant.pill,
                size: UiSize.sm,
                showPanel: false,
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),

              // Active Speaking Indicator Banner (when user un-mutes)
              if (!_isMuted) ...<Widget>[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.sm),
                    vertical: context.sp(theme.spacing.xs),
                  ),
                  margin: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
                  decoration: BoxDecoration(
                    color: theme.colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(theme.radii.sm),
                    border: Border.all(
                      color: theme.colors.success.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      _buildSoundwave(context),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Expanded(
                        child: Text(
                          'You are speaking live to ${widget.listenerCount} traders',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      UiBadge(
                        label: 'LIVE MIC',
                        intent: UiIntent.success,
                        size: UiSize.xs,
                      ),
                    ],
                  ),
                ),
              ],

              // Main Tab Content Area
              Expanded(
                child: switch (_roomTabIndex) {
                  0 => _buildStageTab(context),
                  1 => _buildLiveChatTab(context),
                  2 => _buildPollAndSetupTab(context),
                  3 => _buildRoomInfoTab(context),
                  _ => _buildStageTab(context),
                },
              ),

              SizedBox(height: context.sp(theme.spacing.xs)),

              // Floating Emojis Reaction Quick Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <String>['🔥', '🚀', '👏', '💯', '❤️', '🐂']
                    .map((emoji) {
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.xxs),
                    ),
                    child: InkWell(
                      onTap: () => _triggerReaction(emoji),
                      borderRadius: BorderRadius.circular(theme.radii.pill),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(theme.spacing.xs),
                          vertical: context.sp(theme.spacing.xxs),
                        ),
                        decoration: BoxDecoration(
                          color: theme.colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(
                            theme.radii.pill,
                          ),
                          border: Border.all(
                            color: theme.colors.border,
                          ),
                        ),
                        child: Text(
                          emoji,
                          style: TextStyle(fontSize: context.fs(18)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: context.sp(theme.spacing.xs)),

              // Bottom Audio Controls Bar
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.sm),
                  vertical: context.sp(theme.spacing.xs),
                ),
                decoration: BoxDecoration(
                  color: theme.colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(theme.radii.lg),
                  border: Border.all(color: theme.colors.border),
                ),
                child: Row(
                  children: <Widget>[
                    UiIconButton(
                      icon: _isMuted ? Icons.mic_off_outlined : Icons.mic,
                      intent: _isMuted ? UiIntent.primary : UiIntent.success,
                      tooltip: _isMuted ? 'Unmute' : 'Mute',
                      onPressed: () => setState(() => _isMuted = !_isMuted),
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiIconButton(
                      icon: _isHandRaised
                          ? Icons.pan_tool_rounded
                          : Icons.pan_tool_outlined,
                      intent: _isHandRaised ? UiIntent.primary : UiIntent.info,
                      tooltip: _isHandRaised ? 'Lower Hand' : 'Raise Hand',
                      onPressed: _toggleHand,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    // Audio output switcher
                    UiIconButton(
                      icon: switch (_audioDevice) {
                        'Headset' => Icons.headphones_rounded,
                        'Bluetooth HD' => Icons.bluetooth_audio_rounded,
                        _ => Icons.volume_up_rounded,
                      },
                      variant: UiVariant.ghost,
                      tooltip: 'Output: $_audioDevice',
                      onPressed: _toggleAudioDevice,
                    ),
                    const Spacer(),
                    UiButton(
                      label: 'Leave Quietly',
                      leadingIcon: Icons.logout_rounded,
                      variant: UiVariant.outline,
                      size: UiSize.sm,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Floating dynamic emoji overlay
        for (final _FloatingEmoji item in _floatingEmojis)
          Positioned(
            bottom: context.sz(140),
            left: (MediaQuery.sizeOf(context).width / 2) + item.horizontalOffset,
            child: _FloatingReactionWidget(emoji: item.emoji),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Tab 0: Stage View
  // -------------------------------------------------------------------------
  Widget _buildStageTab(BuildContext context) {
    final UiTheme theme = context.ui;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Pinned Trade Setup Banner
          if (widget.pinnedSetup != null) ...<Widget>[
            _buildPinnedSetupCard(context, widget.pinnedSetup!),
            SizedBox(height: context.sp(theme.spacing.md)),
          ],

          // Speakers Stage Section
          Row(
            children: <Widget>[
              Text(
                'SPEAKERS (${_speakers.length})',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colors.foregroundMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                'Host: ${widget.hostName}',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),

          // Speakers Stage Grid
          Wrap(
            spacing: context.sp(theme.spacing.lg),
            runSpacing: context.sp(theme.spacing.md),
            alignment: WrapAlignment.spaceAround,
            children: _speakers.asMap().entries.map((entry) {
              final int idx = entry.key;
              final String name = entry.value;
              final bool isHost = idx == 0;
              final bool isSpeaking = idx == 0 || idx == 1;

              return InkWell(
                onTap: () => _showSpeakerModal(name),
                borderRadius: BorderRadius.circular(theme.radii.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: <Widget>[
                        // Speaking glow ring
                        Container(
                          padding: EdgeInsets.all(
                            context.sp(theme.spacing.xxs),
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSpeaking
                                  ? theme.colors.success
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: UiAvatar(
                            name: name,
                            size: UiSize.lg,
                          ),
                        ),
                        // Mic status badge
                        Container(
                          padding: EdgeInsets.all(
                            context.sp(theme.spacing.xxs),
                          ),
                          decoration: BoxDecoration(
                            color: theme.colors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colors.border,
                            ),
                          ),
                          child: Icon(
                            isSpeaking ? Icons.mic : Icons.mic_off,
                            size: context.sz(12),
                            color: isSpeaking
                                ? theme.colors.success
                                : theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(theme.spacing.xxs)),
                    Text(
                      name.split(' ').first,
                      style: context.uiText.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (isSpeaking) ...<Widget>[
                          _buildSoundwave(context),
                          SizedBox(
                            width: context.sp(theme.spacing.xxs),
                          ),
                        ],
                        Text(
                          isHost ? 'Host' : 'Speaker',
                          style: context.uiText.label.copyWith(
                            fontSize: context.fs(10),
                            color: isHost
                                ? theme.colors.primary
                                : theme.colors.foregroundMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Raised Hands Queue (for host/moderators)
          if (_raisedHandsQueue.isNotEmpty) ...<Widget>[
            Container(
              padding: EdgeInsets.all(
                context.sp(theme.spacing.sm),
              ),
              decoration: BoxDecoration(
                color: theme.colors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(
                  theme.radii.md,
                ),
                border: Border.all(
                  color: theme.colors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.pan_tool_rounded,
                        size: context.sz(14),
                        color: theme.colors.primary,
                      ),
                      SizedBox(
                        width: context.sp(theme.spacing.xs),
                      ),
                      Text(
                        'HANDS RAISED (${_raisedHandsQueue.length})',
                        style: context.uiText.label.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  for (final String person in _raisedHandsQueue) ...<Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.sp(theme.spacing.xxs),
                      ),
                      child: Row(
                        children: <Widget>[
                          UiAvatar(name: person, size: UiSize.xs),
                          SizedBox(
                            width: context.sp(theme.spacing.xs),
                          ),
                          Expanded(
                            child: Text(
                              person,
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          UiButton(
                            label: 'Invite',
                            size: UiSize.xs,
                            variant: UiVariant.primary,
                            onPressed: () => _acceptSpeaker(person),
                          ),
                          SizedBox(
                            width: context.sp(theme.spacing.xxs),
                          ),
                          UiIconButton(
                            icon: Icons.close_rounded,
                            size: UiSize.xs,
                            variant: UiVariant.ghost,
                            onPressed: () => _dismissSpeaker(person),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
          ],

          // Listeners Grid
          Text(
            'LISTENERS (${widget.listenerCount})',
            style: context.uiText.label.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colors.foregroundMuted,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Wrap(
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.xs),
            children: _listeners.map((name) {
              return InkWell(
                onTap: () => _showListenerModal(name),
                borderRadius: BorderRadius.circular(theme.radii.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    UiAvatar(name: name, size: UiSize.sm),
                    SizedBox(height: context.sp(theme.spacing.xxs)),
                    SizedBox(
                      width: context.sz(52),
                      child: Text(
                        name.split(' ').first,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.label.copyWith(
                          color: theme.colors.foregroundMuted,
                          fontSize: context.fs(10),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Tab 1: Live Chat & Q&A
  // -------------------------------------------------------------------------
  Widget _buildLiveChatTab(BuildContext context) {
    final UiTheme theme = context.ui;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            itemCount: _chatMessages.length,
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.xs),
            ),
            itemBuilder: (BuildContext ctx, int index) {
              final _LiveRoomChatMessage msg = _chatMessages[index];
              return Container(
                margin: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
                padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                decoration: BoxDecoration(
                  color: msg.isHost
                      ? theme.colors.primary.withValues(alpha: 0.08)
                      : theme.colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(theme.radii.md),
                  border: Border.all(
                    color: msg.isHost
                        ? theme.colors.primary.withValues(alpha: 0.25)
                        : theme.colors.border,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    UiAvatar(name: msg.author, size: UiSize.xs),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                msg.author,
                                style: context.uiText.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colors.foreground,
                                ),
                              ),
                              if (msg.isHost) ...<Widget>[
                                SizedBox(width: context.sp(theme.spacing.xxs)),
                                UiBadge(
                                  label: 'HOST',
                                  intent: UiIntent.primary,
                                  size: UiSize.xs,
                                ),
                              ] else if (msg.isSpeaker) ...<Widget>[
                                SizedBox(width: context.sp(theme.spacing.xxs)),
                                UiBadge(
                                  label: 'SPEAKER',
                                  intent: UiIntent.success,
                                  size: UiSize.xs,
                                ),
                              ],
                              const Spacer(),
                              Text(
                                msg.time,
                                style: context.uiText.label.copyWith(
                                  color: theme.colors.foregroundMuted,
                                  fontSize: context.fs(10),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: context.sp(theme.spacing.xxs)),
                          Text(
                            msg.message,
                            style: context.uiText.body.copyWith(
                              fontSize: context.fs(12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Live Chat Composer
        Container(
          padding: EdgeInsets.only(top: context.sp(theme.spacing.xs)),
          child: Row(
            children: <Widget>[
              Expanded(
                child: UiInput(
                  controller: _chatController,
                  hintText: 'Ask host or share a live ticker thought...',
                  size: UiSize.sm,
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiIconButton(
                icon: Icons.send_rounded,
                variant: UiVariant.primary,
                intent: UiIntent.primary,
                size: UiSize.sm,
                tooltip: 'Send Message',
                onPressed: _sendChatMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Tab 2: Poll & Trade Setup
  // -------------------------------------------------------------------------
  Widget _buildPollAndSetupTab(BuildContext context) {
    final UiTheme theme = context.ui;
    final int totalVotes = _pollVotesBullish + _pollVotesBearish;
    final double pctBullish = totalVotes > 0 ? (_pollVotesBullish / totalVotes) : 0.5;
    final double pctBearish = totalVotes > 0 ? (_pollVotesBearish / totalVotes) : 0.5;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Interactive Live Sentiment Poll Card
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(theme.radii.lg),
              border: Border.all(color: theme.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.poll_rounded,
                      size: context.sz(16),
                      color: theme.colors.primary,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    Text(
                      'LIVE SENTIMENT POLL',
                      style: context.uiText.label.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$totalVotes votes cast',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  'Expiry View: Will NIFTY hold 24,800 strike support into 3:00 PM?',
                  style: context.uiText.bodyStrong.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),

                // Option A: Bullish
                InkWell(
                  onTap: () => _votePoll(0),
                  borderRadius: BorderRadius.circular(theme.radii.md),
                  child: Container(
                    padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                    decoration: BoxDecoration(
                      color: _userPollVote == 0
                          ? theme.colors.success.withValues(alpha: 0.15)
                          : theme.colors.surface,
                      borderRadius: BorderRadius.circular(theme.radii.md),
                      border: Border.all(
                        color: _userPollVote == 0
                            ? theme.colors.success
                            : theme.colors.border,
                        width: _userPollVote == 0 ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text('🟢 Bullish (Call Buying)',
                                style: context.uiText.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                )),
                            const Spacer(),
                            Text(
                              '${(pctBullish * 100).toStringAsFixed(1)}% ($_pollVotesBullish)',
                              style: context.uiText.caption.copyWith(
                                color: theme.colors.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(theme.radii.pill),
                          child: LinearProgressIndicator(
                            value: pctBullish,
                            backgroundColor: theme.colors.surfaceMuted,
                            color: theme.colors.success,
                            minHeight: context.sz(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),

                // Option B: Bearish
                InkWell(
                  onTap: () => _votePoll(1),
                  borderRadius: BorderRadius.circular(theme.radii.md),
                  child: Container(
                    padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                    decoration: BoxDecoration(
                      color: _userPollVote == 1
                          ? theme.colors.danger.withValues(alpha: 0.15)
                          : theme.colors.surface,
                      borderRadius: BorderRadius.circular(theme.radii.md),
                      border: Border.all(
                        color: _userPollVote == 1
                            ? theme.colors.danger
                            : theme.colors.border,
                        width: _userPollVote == 1 ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text('🔴 Bearish (Put Buying)',
                                style: context.uiText.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                )),
                            const Spacer(),
                            Text(
                              '${(pctBearish * 100).toStringAsFixed(1)}% ($_pollVotesBearish)',
                              style: context.uiText.caption.copyWith(
                                color: theme.colors.danger,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(theme.radii.pill),
                          child: LinearProgressIndicator(
                            value: pctBearish,
                            backgroundColor: theme.colors.surfaceMuted,
                            color: theme.colors.danger,
                            minHeight: context.sz(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: context.sp(theme.spacing.md)),

          // Pinned Setup Card (Interactive)
          if (widget.pinnedSetup != null) ...<Widget>[
            _buildPinnedSetupCard(context, widget.pinnedSetup!),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Tab 3: Room Info & Details
  // -------------------------------------------------------------------------
  Widget _buildRoomInfoTab(BuildContext context) {
    final UiTheme theme = context.ui;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(theme.radii.lg),
              border: Border.all(color: theme.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ROOM SPECIFICATIONS',
                  style: context.uiText.label.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colors.primary,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Audio Stream Codec', style: context.uiText.caption),
                    Text('Opus HD (48 kHz)',
                        style: context.uiText.caption.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
                Divider(height: context.sp(theme.spacing.sm)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Host Latency', style: context.uiText.caption),
                    Text('24 ms (Direct Mesh)',
                        style: context.uiText.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colors.success,
                        )),
                  ],
                ),
                UiDivider(spacing: theme.spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Record Space Podcast', style: context.uiText.caption),
                    UiSwitch(
                      value: _isRecordingReplay,
                      onChanged: (val) {
                        setState(() => _isRecordingReplay = val);
                        UiToast.show(
                          context,
                          title: 'Replay Recording',
                          message: val
                              ? 'Space podcast replay enabled'
                              : 'Replay recording disabled',
                        );
                      },
                      size: UiSize.sm,
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: context.sp(theme.spacing.sm)),

          // Tickers Discussed in Room
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(theme.radii.lg),
              border: Border.all(color: theme.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'TICKERS IN THIS SPACE',
                  style: context.uiText.label.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colors.foregroundMuted,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Wrap(
                  spacing: context.sp(theme.spacing.xs),
                  runSpacing: context.sp(theme.spacing.xs),
                  children: <String>[
                    'NIFTY 24850 CE',
                    'BANKNIFTY 53200 PE',
                    'RELIANCE',
                    'HDFCBANK',
                  ].map((t) {
                    return UiBadge(
                      label: t,
                      intent: UiIntent.primary,
                      variant: UiBadgeVariant.soft,
                      size: UiSize.sm,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiButton(
            label: 'Copy Space Invitation Link',
            leadingIcon: Icons.link_rounded,
            variant: UiVariant.outline,
            expand: true,
            onPressed: _shareSpace,
          ),
        ],
      ),
    );
  }

  Widget _buildSoundwave(BuildContext context) {
    final UiTheme theme = context.ui;
    return AnimatedBuilder(
      animation: _soundwaveController,
      builder: (BuildContext ctx, Widget? child) {
        final double v = _soundwaveController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _waveBar(4 + (v * 8), theme.colors.success),
            const SizedBox(width: 1.5),
            _waveBar(10 - (v * 6), theme.colors.success),
            const SizedBox(width: 1.5),
            _waveBar(6 + (v * 7), theme.colors.success),
          ],
        );
      },
    );
  }

  Widget _waveBar(double height, Color color) {
    return Container(
      width: 2.5,
      height: height.clamp(3, 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildPinnedSetupCard(BuildContext context, LivePinnedSetup setup) {
    final UiTheme theme = context.ui;

    return Container(
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      decoration: BoxDecoration(
        color: theme.colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(theme.radii.md),
        border: Border.all(
          color: theme.colors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.push_pin_rounded,
                size: context.sz(14),
                color: theme.colors.primary,
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Text(
                'PINNED SETUP BY HOST',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              UiBadge(
                label: setup.side,
                intent: setup.side.toUpperCase() == 'LONG'
                    ? UiIntent.success
                    : UiIntent.danger,
                variant: UiBadgeVariant.solid,
                size: UiSize.xs,
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              UiBadge(
                label: '1 : ${setup.rrRatio.toStringAsFixed(2)} R:R',
                intent: UiIntent.primary,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  setup.ticker,
                  style: context.uiText.subheading.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              UiBadge(
                label: '+₹14,200 (+18.4%)',
                intent: UiIntent.success,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            'Entry: ₹${setup.entry.toStringAsFixed(2)} · SL: ₹${setup.stopLoss.toStringAsFixed(2)} · Target: ₹${setup.target.toStringAsFixed(2)}',
            style: context.uiText.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            setup.note,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Row(
            children: <Widget>[
              Expanded(
                child: UiButton(
                  label: 'Save to Journal',
                  leadingIcon: Icons.bookmark_add_outlined,
                  variant: UiVariant.outline,
                  size: UiSize.xs,
                  onPressed: () {
                    UiToast.success(
                      context,
                      title: 'Trading Journal',
                      message:
                          'Saved ${setup.ticker} trade setup to your Trading Journal!',
                    );
                  },
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: UiButton(
                  label: 'Order Desk',
                  leadingIcon: Icons.bolt_rounded,
                  variant: UiVariant.primary,
                  size: UiSize.xs,
                  onPressed: () {
                    UiToast.success(
                      context,
                      title: 'Order Ticket',
                      message:
                          'Pre-filled ${setup.ticker} (${setup.side}) on Order Desk.',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Floating Reaction Widget that ascends and fades out.
class _FloatingReactionWidget extends StatefulWidget {
  const _FloatingReactionWidget({required this.emoji});

  final String emoji;

  @override
  State<_FloatingReactionWidget> createState() =>
      _FloatingReactionWidgetState();
}

class _FloatingReactionWidgetState extends State<_FloatingReactionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _translateY;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _translateY = Tween<double>(begin: 0, end: -160).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (BuildContext ctx, Widget? child) {
        return Transform.translate(
          offset: Offset(0, _translateY.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Text(
              widget.emoji,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        );
      },
    );
  }
}

/// Minimized floating pill player showing active Live Space status.
class CommunityLiveSpaceMiniPlayer extends StatelessWidget {
  const CommunityLiveSpaceMiniPlayer({
    super.key,
    required this.roomTitle,
    required this.hostName,
    required this.onExpand,
    required this.onLeave,
    this.isMuted = true,
    this.onToggleMute,
  });

  final String roomTitle;
  final String hostName;
  final VoidCallback onExpand;
  final VoidCallback onLeave;
  final bool isMuted;
  final VoidCallback? onToggleMute;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xs),
      ),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: BorderRadius.circular(theme.radii.pill),
        border: Border.all(
          color: theme.colors.danger.withValues(alpha: 0.4),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: context.sz(8),
            height: context.sz(8),
            decoration: BoxDecoration(
              color: theme.colors.danger,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          UiAvatar(name: hostName, size: UiSize.xs),
          SizedBox(width: context.sp(theme.spacing.xs)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.sz(180)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  roomTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  hostName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.label.copyWith(
                    color: theme.colors.foregroundMuted,
                    fontSize: context.fs(10),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          UiIconButton(
            icon: isMuted ? Icons.mic_off_outlined : Icons.mic,
            size: UiSize.xs,
            intent: isMuted ? UiIntent.primary : UiIntent.success,
            tooltip: isMuted ? 'Unmute' : 'Mute',
            onPressed: onToggleMute,
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
          UiIconButton(
            icon: Icons.open_in_full_rounded,
            size: UiSize.xs,
            variant: UiVariant.ghost,
            tooltip: 'Expand Room',
            onPressed: onExpand,
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
          UiIconButton(
            icon: Icons.close_rounded,
            size: UiSize.xs,
            variant: UiVariant.ghost,
            tooltip: 'Leave',
            onPressed: onLeave,
          ),
        ],
      ),
    );
  }
}
