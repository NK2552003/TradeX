import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/utils/app_visibility.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_design.dart';

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

/// A timed segment in the audio room's agenda.
class _AgendaSegment {
  const _AgendaSegment({required this.time, required this.title});

  final String time;
  final String title;
}

/// Modal bottom sheet representing a full-featured live trading audio space / trading floor.
class CommunityLiveRoomSheet extends StatefulWidget {
  const CommunityLiveRoomSheet({
    super.key,
    this.roomId,
    this.roomTitle = 'Live Trading Floor',
    this.hostName = 'Space Host',
    this.listenerCount = 1,
    this.pinnedSetup,
    this.repository,
    this.onMinimize,
    this.onLeave,
  });

  final String? roomId;
  final String roomTitle;
  final String hostName;
  final int listenerCount;
  final LivePinnedSetup? pinnedSetup;
  final CommunityRepository? repository;
  final VoidCallback? onMinimize;
  final VoidCallback? onLeave;

  static Future<void> show(
    BuildContext context, {
    String? roomId,
    String? roomTitle,
    String? hostName,
    int? listenerCount,
    LivePinnedSetup? pinnedSetup,
    CommunityRepository? repository,
    VoidCallback? onMinimize,
    VoidCallback? onLeave,
  }) {
    if (repository != null && roomId != null) {
      repository.tuneIntoRoom(roomId);
    }
    final LiveAudioRoom? activeRoom =
        repository?.allLiveRooms.where((r) => r.id == roomId).firstOrNull ??
        repository?.activeTunedRoom;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => CommunityDensityScope(
        child: CommunityLiveRoomSheet(
          roomId: roomId ?? activeRoom?.id,
          roomTitle: roomTitle ?? activeRoom?.title ?? 'Live Trading Floor',
          hostName: hostName ?? activeRoom?.host.displayName ?? 'Space Host',
          listenerCount: listenerCount ?? activeRoom?.listenerCount ?? 1,
          pinnedSetup: pinnedSetup ?? activeRoom?.pinnedSetup,
          repository: repository,
          onMinimize: onMinimize,
          onLeave: onLeave,
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

  // Real room participants
  List<LiveRoomParticipant> _participants = <LiveRoomParticipant>[];

  // Real room messages
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  List<LiveRoomMessage> _chatMessages = <LiveRoomMessage>[];

  // Real room questions
  final TextEditingController _qnaController = TextEditingController();
  List<LiveRoomQuestion> _questions = <LiveRoomQuestion>[];

  // Live Sentiment Poll state
  int? _userPollVote;
  int _pollVotesBullish = 0;
  int _pollVotesBearish = 0;

  // Audio Device state
  String _audioDevice = 'Phone Speaker';
  bool _isRecordingReplay = true;

  // Active speaker + talk-time tracking
  late AnimationController _pulseController;
  Timer? _stageTimer;
  Timer? _syncTimer;
  int _stageTick = 0;
  int _activeSpeakerIndex = 0;
  final Map<String, int> _talkSeconds = <String, int>{};

  // Live AI captions
  bool _captionsEnabled = false;

  // Connection quality

  // Host moderation state
  bool _roomLocked = false;
  bool _requestsEnabled = true;
  final Set<String> _coHosts = <String>{};
  final Set<String> _mutedSpeakers = <String>{};

  // AI recap state
  bool _recapLoading = false;
  List<String> _recapPoints = <String>[];
  final TextEditingController _clipNameController = TextEditingController();
  int _syncFailures = 0;
  bool _syncInFlight = false;
  static const Duration _baseSyncInterval = Duration(seconds: 10);
  static const int _maxSyncFailures = 4;

  List<LiveRoomParticipant> get _speakers =>
      _participants.where((p) => p.isStage).toList();

  List<LiveRoomParticipant> get _raisedHandsQueue =>
      _participants.where((p) => p.isHandRaised).toList();

  List<LiveRoomParticipant> get _listeners =>
      _participants.where((p) => p.isListener).toList();

  List<String> get _captionPhrases {
    final setup = widget.pinnedSetup;
    return <String>[
      if (setup != null)
        'monitoring ${setup.ticker} (${setup.side}) closely around ₹${setup.entry.toStringAsFixed(1)}…',
      'watching order blocks and liquidity sweeps at the key levels…',
      'volume delta and tape momentum showing constructive absorption…',
      'remember to manage risk and honor your trailing stop loss…',
      'open interest shift indicates institutional positioning into close…',
      'keeping sizing disciplined and waiting for high-conviction trigger…',
    ];
  }

  @override
  void initState() {
    super.initState();
    _soundwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _initializeFallbackParticipants();
    AppVisibility.instance.addListener(_onVisibilityChanged);
    _loadRoomData();

    // Stage simulation timer
    _stageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !AppVisibility.instance.isVisible) return;
      setState(() {
        final speakers = _speakers;
        if (speakers.isNotEmpty) {
          final LiveRoomParticipant active =
              speakers[_activeSpeakerIndex % speakers.length];
          if (!active.isMuted && !_mutedSpeakers.contains(active.userId)) {
            _talkSeconds[active.userId] =
                (_talkSeconds[active.userId] ?? 0) + 1;
          }
        }
        _stageTick++;
        if (_stageTick % 7 == 0 && speakers.isNotEmpty) {
          _activeSpeakerIndex = (_activeSpeakerIndex + 1) % speakers.length;
        }
      });
    });

    // Visibility-aware polling sync timer with exponential backoff
    _scheduleSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _soundwaveController.stop();
      _pulseController.stop();
    } else {
      if (!_soundwaveController.isAnimating) {
        _soundwaveController.repeat(reverse: true);
      }
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  void _onVisibilityChanged(bool isVisible) {
    if (!mounted) return;
    if (!isVisible) {
      _syncTimer?.cancel();
      _syncTimer = null;
    } else {
      _syncFailures = 0;
      _syncDataSilently();
    }
  }

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    if (!mounted || !AppVisibility.instance.isVisible) return;
    if (_syncFailures >= _maxSyncFailures) return;
    final multiplier = _syncFailures == 0 ? 1 : (1 << _syncFailures);
    final delaySecs = (_baseSyncInterval.inSeconds * multiplier).clamp(10, 60);
    _syncTimer = Timer(Duration(seconds: delaySecs), _syncDataSilently);
  }

  void _initializeFallbackParticipants() {
    final current = widget.repository?.currentAuthor;
    _participants = <LiveRoomParticipant>[
      LiveRoomParticipant(
        roomId: widget.roomId ?? 'live_room',
        userId: 'host_id',
        displayName: widget.hostName,
        role: 'host',
        isMuted: false,
        isHandRaised: false,
        joinedAt: DateTime.now(),
      ),
      if (current != null && current.displayName != widget.hostName)
        LiveRoomParticipant(
          roomId: widget.roomId ?? 'live_room',
          userId: current.id,
          displayName: current.displayName,
          avatarUrl: current.avatarUrl,
          role: 'listener',
          isMuted: _isMuted,
          isHandRaised: _isHandRaised,
          joinedAt: DateTime.now(),
        ),
    ];
  }

  Future<void> _loadRoomData() async {
    final roomId = widget.roomId;
    final repo = widget.repository;
    if (repo == null || roomId == null) {
      return;
    }

    try {
      final activeRoom = repo.allLiveRooms
          .where((r) => r.id == roomId)
          .firstOrNull;
      if (activeRoom != null) {
        _pollVotesBullish = activeRoom.pollBullishVotes;
        _pollVotesBearish = activeRoom.pollBearishVotes;
        _isRecordingReplay = activeRoom.recordingAvailable;
      }

      final participants = await repo.fetchRoomParticipants(roomId);
      final messages = await repo.fetchRoomMessages(roomId);
      final questions = await repo.fetchRoomQuestions(roomId);

      if (!mounted) return;
      setState(() {
        if (participants.isNotEmpty) {
          _participants = participants;
        }
        _chatMessages = messages;
        _questions = questions;
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _syncDataSilently() async {
    final roomId = widget.roomId;
    final repo = widget.repository;
    if (repo == null || roomId == null || !mounted || _syncInFlight) {
      _scheduleSync();
      return;
    }
    _syncInFlight = true;
    try {
      final (participants, messages, questions) = await (
        repo.fetchRoomParticipants(roomId),
        repo.fetchRoomMessages(roomId),
        repo.fetchRoomQuestions(roomId),
      ).wait;

      _syncFailures = 0;
      if (!mounted) return;
      setState(() {
        if (participants.isNotEmpty) {
          _participants = participants;
        }
        _chatMessages = messages;
        _questions = questions;
      });
    } catch (_) {
      _syncFailures++;
    } finally {
      _syncInFlight = false;
      if (mounted) _scheduleSync();
    }
  }

  @override
  void dispose() {
    AppVisibility.instance.removeListener(_onVisibilityChanged);
    _soundwaveController.dispose();
    _pulseController.dispose();
    _stageTimer?.cancel();
    _syncTimer?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    _qnaController.dispose();
    _clipNameController.dispose();
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

  void _toggleHand() async {
    final next = !_isHandRaised;
    setState(() {
      _isHandRaised = next;
      final currentUserId = widget.repository?.currentAuthor.id;
      final idx = _participants.indexWhere((p) => p.userId == currentUserId);
      if (idx >= 0) {
        _participants[idx] = _participants[idx].copyWith(isHandRaised: next);
      }
    });

    UiToast.show(
      context,
      title: 'Live Space',
      message: next
          ? 'Hand raised! The host has been notified.'
          : 'Hand lowered.',
    );

    if (widget.repository != null && widget.roomId != null) {
      await widget.repository!.toggleHandRaised(widget.roomId!);
    }
  }

  void _acceptSpeaker(LiveRoomParticipant participant) async {
    setState(() {
      final idx = _participants.indexWhere(
        (p) => p.userId == participant.userId,
      );
      if (idx >= 0) {
        _participants[idx] = _participants[idx].copyWith(
          role: 'speaker',
          isHandRaised: false,
          isMuted: false,
        );
      }
    });

    UiToast.success(
      context,
      title: 'Speaker Added',
      message: '${participant.displayName} has been invited to speak.',
    );

    if (widget.repository != null && widget.roomId != null) {
      await widget.repository!.updateParticipantRole(
        widget.roomId!,
        participant.userId,
        'speaker',
      );
    }
  }

  void _dismissSpeaker(LiveRoomParticipant participant) async {
    setState(() {
      final idx = _participants.indexWhere(
        (p) => p.userId == participant.userId,
      );
      if (idx >= 0) {
        _participants[idx] = _participants[idx].copyWith(isHandRaised: false);
      }
    });

    if (widget.repository != null && widget.roomId != null) {
      await widget.repository!.toggleHandRaised(widget.roomId!);
    }
  }

  void _muteParticipant(LiveRoomParticipant participant, bool mute) async {
    setState(() {
      final idx = _participants.indexWhere(
        (p) => p.userId == participant.userId,
      );
      if (idx >= 0) {
        _participants[idx] = _participants[idx].copyWith(isMuted: mute);
      }
      if (mute) {
        _mutedSpeakers.add(participant.userId);
      } else {
        _mutedSpeakers.remove(participant.userId);
      }
    });

    UiToast.info(
      context,
      title: 'Moderation',
      message: mute
          ? '${participant.displayName} muted.'
          : '${participant.displayName} unmuted.',
    );

    if (widget.repository != null && widget.roomId != null) {
      await widget.repository!.setParticipantMute(
        widget.roomId!,
        participant.userId,
        mute,
      );
    }
  }

  void _updateParticipantRole(
    LiveRoomParticipant participant,
    String role,
  ) async {
    setState(() {
      final idx = _participants.indexWhere(
        (p) => p.userId == participant.userId,
      );
      if (idx >= 0) {
        _participants[idx] = _participants[idx].copyWith(role: role);
      }
      if (role == 'co_host' || role == 'cohost') {
        _coHosts.add(participant.userId);
      } else {
        _coHosts.remove(participant.userId);
      }
    });

    UiToast.success(
      context,
      title: 'Role Updated',
      message: '${participant.displayName} role set to $role.',
    );

    if (widget.repository != null && widget.roomId != null) {
      await widget.repository!.updateParticipantRole(
        widget.roomId!,
        participant.userId,
        role,
      );
    }
  }

  void _sendChatMessage() async {
    final String text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();
    final author = widget.repository?.currentAuthor;
    final userRole =
        _participants.where((p) => p.userId == author?.id).firstOrNull?.role ??
        'listener';

    final LiveRoomMessage optimisticMsg = LiveRoomMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      roomId: widget.roomId ?? '',
      senderId: author?.id ?? 'user',
      senderName: author?.displayName ?? 'You',
      senderAvatarUrl: author?.avatarUrl ?? '',
      senderRole: userRole,
      message: text,
      isPinned: false,
      createdAt: DateTime.now(),
    );

    setState(() {
      _chatMessages.add(optimisticMsg);
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

    if (widget.repository != null && widget.roomId != null) {
      final saved = await widget.repository!.sendRoomMessage(
        widget.roomId!,
        text,
      );
      if (saved != null && mounted) {
        setState(() {
          final idx = _chatMessages.indexWhere((m) => m.id == optimisticMsg.id);
          if (idx >= 0) {
            _chatMessages[idx] = saved;
          }
        });
      }
    }
  }

  void _handleLeave() {
    Navigator.of(context).pop();
    if (widget.repository != null) {
      widget.repository!.leaveRoom();
    }
    widget.onLeave?.call();
  }

  void _votePoll(int choice) async {
    if (_userPollVote == choice) return;

    setState(() {
      if (_userPollVote == 0) {
        _pollVotesBullish = math.max(0, _pollVotesBullish - 1);
      }
      if (_userPollVote == 1) {
        _pollVotesBearish = math.max(0, _pollVotesBearish - 1);
      }

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

    if (widget.repository != null && widget.roomId != null) {
      await widget.repository!.voteLiveRoomPoll(
        widget.roomId!,
        choice == 0 ? 'bullish' : 'bearish',
      );
    }
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
      message: 'Live space link copied for "${widget.roomTitle}".',
    );
  }

  void _submitQuestion() async {
    final String text = _qnaController.text.trim();
    if (text.isEmpty) return;

    _qnaController.clear();
    final author = widget.repository?.currentAuthor;
    final optimisticQ = LiveRoomQuestion(
      id: 'local_q_${DateTime.now().millisecondsSinceEpoch}',
      roomId: widget.roomId ?? '',
      authorId: author?.id ?? 'user',
      authorName: author?.displayName ?? 'You',
      authorAvatarUrl: author?.avatarUrl ?? '',
      question: text,
      upvotesCount: 1,
      isAnswered: false,
      createdAt: DateTime.now(),
      hasUpvoted: true,
    );

    setState(() {
      _questions.insert(0, optimisticQ);
    });

    UiToast.success(
      context,
      title: 'Question Submitted',
      message: 'Your question was pushed to the speakers queue.',
    );

    if (widget.repository != null && widget.roomId != null) {
      final saved = await widget.repository!.submitRoomQuestion(
        widget.roomId!,
        text,
      );
      if (saved != null && mounted) {
        setState(() {
          final idx = _questions.indexWhere((q) => q.id == optimisticQ.id);
          if (idx >= 0) {
            _questions[idx] = saved.copyWith(hasUpvoted: true);
          }
        });
      }
    }
  }

  void _toggleQuestionUpvote(LiveRoomQuestion q) async {
    final nextHasUpvoted = !q.hasUpvoted;
    final nextCount = nextHasUpvoted
        ? q.upvotesCount + 1
        : math.max(0, q.upvotesCount - 1);
    setState(() {
      final idx = _questions.indexWhere((item) => item.id == q.id);
      if (idx >= 0) {
        _questions[idx] = q.copyWith(
          hasUpvoted: nextHasUpvoted,
          upvotesCount: nextCount,
        );
      }
    });

    if (widget.repository != null) {
      await widget.repository!.toggleQuestionUpvote(q.id);
    }
  }

  void _toggleQuestionAnswered(LiveRoomQuestion q) async {
    final next = !q.isAnswered;
    setState(() {
      final idx = _questions.indexWhere((item) => item.id == q.id);
      if (idx >= 0) {
        _questions[idx] = q.copyWith(
          isAnswered: next,
          answeredAt: next ? DateTime.now() : null,
        );
      }
    });

    UiToast.info(
      context,
      title: 'Q&A Updated',
      message: next ? 'Marked as answered.' : 'Moved back to queue.',
    );

    if (widget.repository != null) {
      await widget.repository!.markQuestionAnswered(q.id, next);
    }
  }

  void _toggleCaptions() {
    setState(() => _captionsEnabled = !_captionsEnabled);
    UiToast.info(
      context,
      title: 'AI Captions',
      message: _captionsEnabled
          ? 'Live AI speech-to-text captions enabled.'
          : 'Live captions turned off.',
    );
  }

  void _showAiRecapModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext sCtx, StateSetter setModalState) {
            final UiTheme theme = sCtx.ui;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sCtx).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: theme.colors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(theme.radii.lg),
                ),
                border: Border.all(color: theme.colors.border),
              ),
              padding: EdgeInsets.all(sCtx.sp(theme.spacing.md)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.auto_awesome,
                        size: sCtx.sz(18),
                        color: theme.colors.primary,
                      ),
                      SizedBox(width: sCtx.sp(theme.spacing.xs)),
                      Expanded(
                        child: Text(
                          'AI Live Space Intelligence Recap',
                          style: sCtx.uiText.label.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: sCtx.fs(15),
                          ),
                        ),
                      ),
                      UiIconButton(
                        icon: Icons.close_rounded,
                        size: UiSize.xs,
                        variant: UiVariant.ghost,
                        onPressed: () => Navigator.of(sCtx).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: sCtx.sp(theme.spacing.sm)),
                  if (_recapLoading) ...<Widget>[
                    UiCard(
                      variant: UiCardVariant.surface,
                      padding: EdgeInsets.all(sCtx.sp(theme.spacing.md)),
                      child: Column(
                        children: <Widget>[
                          const UiTypingIndicator(),
                          SizedBox(height: sCtx.sp(theme.spacing.sm)),
                          Text(
                            'Synthesizing audio space discussion & trade ideas…',
                            style: sCtx.uiText.caption.copyWith(
                              color: theme.colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_recapPoints.isEmpty) ...<Widget>[
                    UiCard(
                      variant: UiCardVariant.surface,
                      padding: EdgeInsets.all(sCtx.sp(theme.spacing.md)),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            Icons.psychology_outlined,
                            size: sCtx.sz(32),
                            color: theme.colors.primary,
                          ),
                          SizedBox(height: sCtx.sp(theme.spacing.xs)),
                          Text(
                            'Generate Instant AI Audio Space Summary',
                            style: sCtx.uiText.label.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: sCtx.sp(theme.spacing.xxs)),
                          Text(
                            'Extracts key support/resistance levels, consensus bias, pinned trades, and options gamma analysis discussed by the speakers.',
                            style: sCtx.uiText.caption.copyWith(
                              color: theme.colors.foregroundMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: sCtx.sp(theme.spacing.md)),
                          UiButton(
                            label: 'Generate Audio Recap',
                            leadingIcon: Icons.auto_awesome,
                            variant: UiVariant.primary,
                            onPressed: () async {
                              setModalState(() => _recapLoading = true);
                              await Future<void>.delayed(
                                const Duration(milliseconds: 600),
                              );
                              if (!mounted) return;
                              final setup = widget.pinnedSetup;
                              final totalVotes =
                                  _pollVotesBullish + _pollVotesBearish;
                              final pctBullish = totalVotes > 0
                                  ? (_pollVotesBullish / totalVotes)
                                  : 0.5;
                              final bias = pctBullish >= 0.5
                                  ? 'Bullish (${(pctBullish * 100).toStringAsFixed(0)}%)'
                                  : 'Bearish (${((1 - pctBullish) * 100).toStringAsFixed(0)}%)';
                              setState(() {
                                _recapPoints = <String>[
                                  '🎯 Floor Consensus: $bias market bias for "${widget.roomTitle}".',
                                  if (setup != null)
                                    '📈 Pinned Alpha: ${setup.ticker} (${setup.side}) Entry ₹${setup.entry} · Target ₹${setup.target} · SL ₹${setup.stopLoss} (1:${setup.rrRatio.toStringAsFixed(1)} R:R).',
                                  if (setup?.note.isNotEmpty == true)
                                    '📝 Strategy Note: ${setup!.note}',
                                  if (_speakers.isNotEmpty)
                                    '👥 Stage Speakers: ${_speakers.map((s) => s.displayName).join(', ')} leading execution debrief.',
                                  if (_questions.isNotEmpty)
                                    '❓ Top In-Floor Question: "${_questions.first.question}"',
                                  '⚡ Risk Discipline: Honor predefined invalidation levels. Position sizing calibrated for current volatility.',
                                ];
                                _recapLoading = false;
                              });
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else ...<Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (final String pt in _recapPoints) ...<Widget>[
                              Container(
                                margin: EdgeInsets.only(
                                  bottom: sCtx.sp(theme.spacing.xs),
                                ),
                                padding: EdgeInsets.all(
                                  sCtx.sp(theme.spacing.sm),
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colors.surfaceMuted,
                                  borderRadius: sCtx.radius(theme.radii.sm),
                                  border: Border.all(
                                    color: theme.colors.border,
                                  ),
                                ),
                                child: Text(
                                  pt,
                                  style: sCtx.uiText.body.copyWith(
                                    fontSize: sCtx.fs(12.5),
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: sCtx.sp(theme.spacing.sm)),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: UiButton(
                            label: 'Copy Recap',
                            leadingIcon: Icons.copy_rounded,
                            variant: UiVariant.outline,
                            onPressed: () {
                              UiToast.info(
                                context,
                                title: 'Copied',
                                message: 'Recap copied to clipboard.',
                              );
                            },
                          ),
                        ),
                        SizedBox(width: sCtx.sp(theme.spacing.xs)),
                        Expanded(
                          child: UiButton(
                            label: 'Share to Feed',
                            leadingIcon: Icons.share_rounded,
                            variant: UiVariant.primary,
                            onPressed: () {
                              Navigator.of(sCtx).pop();
                              UiToast.success(
                                context,
                                title: 'Shared to Feed',
                                message: 'AI Recap posted to community feed.',
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTippingModal(BuildContext context, {String? targetName}) {
    final String receiver = targetName ?? widget.hostName;
    final List<int> tipPresets = <int>[100, 500, 1000, 2500];

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.favorite_rounded,
                    color: theme.colors.danger,
                    size: ctx.sz(20),
                  ),
                  SizedBox(width: ctx.sp(theme.spacing.xs)),
                  Expanded(
                    child: Text(
                      'Tip / Superchat to $receiver',
                      style: ctx.uiText.label.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: ctx.fs(15),
                      ),
                    ),
                  ),
                  UiIconButton(
                    icon: Icons.close_rounded,
                    size: UiSize.xs,
                    variant: UiVariant.ghost,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              SizedBox(height: ctx.sp(theme.spacing.xs)),
              Text(
                'Show appreciation and support high-conviction live alpha with instant superchat tips.',
                style: ctx.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              SizedBox(height: ctx.sp(theme.spacing.md)),
              Row(
                children: tipPresets.map((int amount) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ctx.sp(theme.spacing.xxs),
                      ),
                      child: UiButton(
                        label: '₹$amount',
                        size: UiSize.sm,
                        variant: UiVariant.outline,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() {
                            for (int i = 0; i < 5; i++) {
                              _floatingEmojis.add(
                                _FloatingEmoji(
                                  id: DateTime.now().microsecondsSinceEpoch + i,
                                  emoji: i.isEven ? '🔥' : '❤️',
                                  horizontalOffset:
                                      (_random.nextDouble() - 0.5) * 160,
                                ),
                              );
                            }
                          });
                          UiToast.success(
                            context,
                            title: 'Superchat Sent!',
                            message: 'You sent ₹$amount tip to $receiver.',
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: ctx.sp(theme.spacing.md)),
              UiButton(
                label: 'Custom Superchat (₹5,000+)',
                leadingIcon: Icons.volunteer_activism_outlined,
                variant: UiVariant.soft,
                intent: UiIntent.primary,
                expand: true,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  UiToast.success(
                    context,
                    title: 'Whale Patron',
                    message: 'Custom superchat tier enabled.',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHostControlsModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext sCtx, StateSetter setModalState) {
            final UiTheme theme = sCtx.ui;
            return Container(
              decoration: BoxDecoration(
                color: theme.colors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(theme.radii.lg),
                ),
                border: Border.all(color: theme.colors.border),
              ),
              padding: EdgeInsets.all(sCtx.sp(theme.spacing.md)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.shield_outlined,
                        size: sCtx.sz(18),
                        color: theme.colors.primary,
                      ),
                      SizedBox(width: sCtx.sp(theme.spacing.xs)),
                      Expanded(
                        child: Text(
                          'Host Space Moderation Controls',
                          style: sCtx.uiText.label.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: sCtx.fs(15),
                          ),
                        ),
                      ),
                      UiIconButton(
                        icon: Icons.close_rounded,
                        size: UiSize.xs,
                        variant: UiVariant.ghost,
                        onPressed: () => Navigator.of(sCtx).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: sCtx.sp(theme.spacing.md)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Lock Live Room', style: sCtx.uiText.bodyStrong),
                          Text(
                            'Prevent new listeners from entering the space',
                            style: sCtx.uiText.caption.copyWith(
                              color: theme.colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                      UiSwitch(
                        value: _roomLocked,
                        onChanged: (bool val) {
                          setState(() => _roomLocked = val);
                          setModalState(() {});
                          UiToast.info(
                            context,
                            title: 'Room Lock',
                            message: val ? 'Room locked' : 'Room unlocked',
                          );
                        },
                        size: UiSize.sm,
                      ),
                    ],
                  ),
                  Divider(height: sCtx.sp(theme.spacing.md)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Allow Speaking Requests',
                            style: sCtx.uiText.bodyStrong,
                          ),
                          Text(
                            'Listeners can raise hands to request mic access',
                            style: sCtx.uiText.caption.copyWith(
                              color: theme.colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                      UiSwitch(
                        value: _requestsEnabled,
                        onChanged: (bool val) {
                          setState(() => _requestsEnabled = val);
                          setModalState(() {});
                          UiToast.info(
                            context,
                            title: 'Speaker Requests',
                            message: val
                                ? 'Requests enabled'
                                : 'Requests paused',
                          );
                        },
                        size: UiSize.sm,
                      ),
                    ],
                  ),
                  Divider(height: sCtx.sp(theme.spacing.md)),
                  UiButton(
                    label: 'Mute All Speakers',
                    leadingIcon: Icons.mic_off_rounded,
                    variant: UiVariant.soft,
                    intent: UiIntent.warning,
                    expand: true,
                    onPressed: () {
                      setState(() {
                        for (final s in _speakers) {
                          _mutedSpeakers.add(s.userId);
                        }
                      });
                      Navigator.of(sCtx).pop();
                      UiToast.warning(
                        context,
                        title: 'All Speakers Muted',
                        message: 'Speakers muted by host.',
                      );
                    },
                  ),
                  SizedBox(height: sCtx.sp(theme.spacing.xs)),
                  UiButton(
                    label: 'Unmute All Speakers',
                    leadingIcon: Icons.mic_rounded,
                    variant: UiVariant.soft,
                    intent: UiIntent.success,
                    expand: true,
                    onPressed: () {
                      setState(() {
                        _mutedSpeakers.clear();
                      });
                      Navigator.of(sCtx).pop();
                      UiToast.success(
                        context,
                        title: 'All Speakers Unmuted',
                        message: 'Speakers unmuted.',
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSpeakerModal(LiveRoomParticipant speaker) {
    final String name = speaker.displayName;
    final bool isHost = speaker.isHost || name == widget.hostName;
    final bool isMuted =
        speaker.isMuted || _mutedSpeakers.contains(speaker.userId);
    final bool isCoHost = speaker.isCoHost || _coHosts.contains(speaker.userId);

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
                          isHost
                              ? 'Room Host & Founder'
                              : (isCoHost
                                    ? 'Co-Host Moderator'
                                    : 'Featured Speaker'),
                          style: ctx.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiBadge(
                    label: isHost ? 'HOST' : (isCoHost ? 'CO-HOST' : 'SPEAKER'),
                    intent: isHost
                        ? UiIntent.primary
                        : (isCoHost ? UiIntent.info : UiIntent.success),
                    size: UiSize.xs,
                  ),
                ],
              ),
              SizedBox(height: ctx.sp(theme.spacing.md)),
              UiButton(
                label: 'Send Tip / Superchat',
                leadingIcon: Icons.favorite_rounded,
                variant: UiVariant.soft,
                intent: UiIntent.danger,
                expand: true,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showTippingModal(context, targetName: name);
                },
              ),
              SizedBox(height: ctx.sp(theme.spacing.xs)),
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
                    message: 'Viewing verified trader profile for $name',
                  );
                },
              ),
              SizedBox(height: ctx.sp(theme.spacing.xs)),
              if (!isHost) ...<Widget>[
                UiButton(
                  label: isMuted ? 'Unmute Speaker' : 'Mute Speaker',
                  leadingIcon: isMuted
                      ? Icons.mic_rounded
                      : Icons.mic_off_outlined,
                  variant: UiVariant.soft,
                  intent: isMuted ? UiIntent.success : UiIntent.warning,
                  expand: true,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _muteParticipant(speaker, !isMuted);
                  },
                ),
                SizedBox(height: ctx.sp(theme.spacing.xs)),
                UiButton(
                  label: isCoHost ? 'Remove Co-Host Role' : 'Make Co-Host',
                  leadingIcon: Icons.admin_panel_settings_outlined,
                  variant: UiVariant.soft,
                  intent: UiIntent.primary,
                  expand: true,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _updateParticipantRole(
                      speaker,
                      isCoHost ? 'speaker' : 'co_host',
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
                    _updateParticipantRole(speaker, 'listener');
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showListenerModal(LiveRoomParticipant listener) {
    final String name = listener.displayName;
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
                  _acceptSpeaker(listener);
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

              // Preview controls wrap inside narrow mobile sheets.
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xxs),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const UiBadge(
                    label: 'SIMULATED AUDIO (BETA)',
                    intent: UiIntent.warning,
                    size: UiSize.xs,
                  ),
                  Text(
                    '${widget.listenerCount} participants',
                    style: context.uiText.caption,
                  ),
                  if (_roomLocked) ...<Widget>[
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiBadge(
                      label: 'LOCKED',
                      intent: UiIntent.warning,
                      size: UiSize.xs,
                    ),
                  ],
                  if (_captionsEnabled) ...<Widget>[
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiBadge(
                      label: 'CC ON',
                      intent: UiIntent.info,
                      variant: UiBadgeVariant.soft,
                      size: UiSize.xs,
                    ),
                  ],
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
                    tooltip: 'Leave Room',
                    onPressed: _handleLeave,
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
                  'Q&A (${_questions.length})',
                  'Poll & Setup',
                  'Room Info',
                ],
                selectedIndex: _roomTabIndex,
                onChanged: (int idx) => setState(() => _roomTabIndex = idx),
                variant: UiTabsVariant.pill,
                size: UiSize.sm,
                showPanel: false,
                scrollable: true,
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
                  2 => _buildQnaTab(context),
                  3 => _buildPollAndSetupTab(context),
                  4 => _buildRoomInfoTab(context),
                  _ => _buildStageTab(context),
                },
              ),

              SizedBox(height: context.sp(theme.spacing.xs)),

              // Floating Emojis Reaction Quick Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <String>['🔥', '🚀', '👏', '💯', '❤️', '🐂'].map((
                  emoji,
                ) {
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
                          borderRadius: BorderRadius.circular(theme.radii.pill),
                          border: Border.all(color: theme.colors.border),
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
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: context.sp(theme.spacing.xs),
                  runSpacing: context.sp(theme.spacing.xs),
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
                    UiButton(
                      label: 'Leave Quietly',
                      leadingIcon: Icons.logout_rounded,
                      variant: UiVariant.outline,
                      size: UiSize.sm,
                      onPressed: _handleLeave,
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
            left:
                (MediaQuery.sizeOf(context).width / 2) + item.horizontalOffset,
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
            SizedBox(height: context.sp(theme.spacing.sm)),
          ],

          // Stage Actions Quick Toolbar
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.sm),
              vertical: context.sp(theme.spacing.xs),
            ),
            margin: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(theme.radii.lg),
              border: Border.all(color: theme.colors.border),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                // Live AI Captions Toggle Button
                UiButton(
                  label: 'Preview captions',
                  leadingIcon: Icons.closed_caption_rounded,
                  size: UiSize.xs,
                  variant: UiVariant.soft,
                  onPressed: _toggleCaptions,
                ),

                // AI Space Recap Button
                UiButton(
                  label: 'AI Recap',
                  leadingIcon: Icons.auto_awesome,
                  size: UiSize.xs,
                  variant: UiVariant.soft,
                  intent: UiIntent.primary,
                  onPressed: () => _showAiRecapModal(context),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),

                // Tip Host Button
                UiButton(
                  label: 'Tip Host',
                  leadingIcon: Icons.favorite_rounded,
                  size: UiSize.xs,
                  variant: UiVariant.soft,
                  intent: UiIntent.danger,
                  onPressed: () =>
                      _showTippingModal(context, targetName: widget.hostName),
                ),

                // Host Moderation / Settings Button
                UiIconButton(
                  icon: Icons.shield_outlined,
                  size: UiSize.xs,
                  variant: UiVariant.ghost,
                  tooltip: 'Host Controls & Roles',
                  onPressed: () => _showHostControlsModal(context),
                ),
              ],
            ),
          ),

          // Live AI Captions Banner (when enabled)
          if (_captionsEnabled) ...<Widget>[
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              margin: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              decoration: BoxDecoration(
                color: theme.colors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(theme.radii.md),
                border: Border.all(
                  color: theme.colors.info.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.all(context.sp(theme.spacing.xxs)),
                    decoration: BoxDecoration(
                      color: theme.colors.info.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_none_rounded,
                      size: context.sz(14),
                      color: theme.colors.info,
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              'LIVE AI SPEECH CAPTION',
                              style: context.uiText.label.copyWith(
                                fontSize: context.fs(10),
                                fontWeight: FontWeight.w800,
                                color: theme.colors.info,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.xxs)),
                            Text(
                              '• ${_speakers.isNotEmpty ? _speakers[_activeSpeakerIndex % _speakers.length] : widget.hostName}',
                              style: context.uiText.label.copyWith(
                                fontSize: context.fs(10),
                                color: theme.colors.foregroundMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            UiBadge(
                              label: 'AUTO STT',
                              intent: UiIntent.info,
                              variant: UiBadgeVariant.soft,
                              size: UiSize.xs,
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        Text(
                          '"${_captionPhrases[_stageTick % _captionPhrases.length]}"',
                          style: context.uiText.bodyStrong.copyWith(
                            fontSize: context.fs(13),
                            fontStyle: FontStyle.italic,
                            color: theme.colors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Speakers Stage Section
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.xxs),
            children: <Widget>[
              Text(
                'SPEAKERS (${_speakers.length})',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colors.foregroundMuted,
                  letterSpacing: 0.6,
                ),
              ),
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
              final LiveRoomParticipant speaker = entry.value;
              final String name = speaker.displayName;
              final bool isHost = speaker.isHost || idx == 0;
              final bool isCoHost =
                  speaker.isCoHost || _coHosts.contains(speaker.userId);
              final bool isMuted =
                  speaker.isMuted || _mutedSpeakers.contains(speaker.userId);
              final bool isSpeaking =
                  idx ==
                      (_activeSpeakerIndex % math.max(1, _speakers.length)) &&
                  !isMuted;
              final int talkSec =
                  _talkSeconds[speaker.userId] ?? _talkSeconds[name] ?? 0;
              final String talkFormatted = '${talkSec ~/ 60}m ${talkSec % 60}s';

              return InkWell(
                onTap: () => _showSpeakerModal(speaker),
                borderRadius: BorderRadius.circular(theme.radii.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: <Widget>[
                        // Speaking glow ring with pulse
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (BuildContext c, Widget? child) {
                              return Container(
                                padding: EdgeInsets.all(
                                  context.sp(theme.spacing.xxs),
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSpeaking
                                        ? theme.colors.success.withValues(
                                            alpha:
                                                0.5 +
                                                (_pulseController.value * 0.5),
                                          )
                                        : Colors.transparent,
                                    width: isSpeaking ? 3.0 : 1.0,
                                  ),
                                  boxShadow: isSpeaking
                                      ? <BoxShadow>[
                                          BoxShadow(
                                            color: theme.colors.success
                                                .withValues(
                                                  alpha:
                                                      0.3 *
                                                      _pulseController.value,
                                                ),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: child,
                              );
                            },
                            child: UiAvatar(name: name, size: UiSize.lg),
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
                            border: Border.all(color: theme.colors.border),
                          ),
                          child: Icon(
                            isMuted
                                ? Icons.mic_off
                                : (isSpeaking ? Icons.mic : Icons.mic_none),
                            size: context.sz(12),
                            color: isMuted
                                ? theme.colors.danger
                                : (isSpeaking
                                      ? theme.colors.success
                                      : theme.colors.foregroundMuted),
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
                    SizedBox(height: 2),
                    // Talk time pill
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.xxs),
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(theme.radii.sm),
                      ),
                      child: Text(
                        talkFormatted,
                        style: context.uiText.label.copyWith(
                          fontSize: context.fs(9.5),
                          color: theme.colors.foregroundMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.xxs)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (isSpeaking) ...<Widget>[
                          _buildSoundwave(context),
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                        ],
                        Text(
                          isHost
                              ? 'Host'
                              : (isCoHost
                                    ? 'Co-Host'
                                    : (isMuted ? 'Muted' : 'Speaker')),
                          style: context.uiText.label.copyWith(
                            fontSize: context.fs(10),
                            color: isHost
                                ? theme.colors.primary
                                : (isCoHost
                                      ? theme.colors.info
                                      : (isMuted
                                            ? theme.colors.danger
                                            : theme.colors.foregroundMuted)),
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
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              decoration: BoxDecoration(
                color: theme.colors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(theme.radii.md),
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
                      SizedBox(width: context.sp(theme.spacing.xs)),
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
                  for (final LiveRoomParticipant person
                      in _raisedHandsQueue) ...<Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.sp(theme.spacing.xxs),
                      ),
                      child: Row(
                        children: <Widget>[
                          UiAvatar(name: person.displayName, size: UiSize.xs),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          Expanded(
                            child: Text(
                              person.displayName,
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
                          SizedBox(width: context.sp(theme.spacing.xxs)),
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
            'LISTENERS (${math.max(_listeners.length, widget.listenerCount)})',
            style: context.uiText.label.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colors.foregroundMuted,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          if (_listeners.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: context.sp(theme.spacing.sm),
              ),
              child: Text(
                'No other listeners yet. Invite fellow traders to join!',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            )
          else
            Wrap(
              spacing: context.sp(theme.spacing.sm),
              runSpacing: context.sp(theme.spacing.xs),
              children: _listeners.map((listener) {
                return InkWell(
                  onTap: () => _showListenerModal(listener),
                  borderRadius: BorderRadius.circular(theme.radii.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      UiAvatar(name: listener.displayName, size: UiSize.sm),
                      SizedBox(height: context.sp(theme.spacing.xxs)),
                      SizedBox(
                        width: context.sz(52),
                        child: Text(
                          listener.displayName.split(' ').first,
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

  String _formatTimeAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatScheduledTime(DateTime dt) {
    final int hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final String minute = dt.minute.toString().padLeft(2, '0');
    final String ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  List<_AgendaSegment> get _roomAgenda => const <_AgendaSegment>[
    _AgendaSegment(time: '00:00', title: 'Floor Opening & Macro Bias'),
    _AgendaSegment(time: '15:00', title: 'Live Order Flow & Liquidity Heatmap'),
    _AgendaSegment(time: '30:00', title: 'Open Stage Alpha & Shared Setups'),
    _AgendaSegment(time: '45:00', title: 'Community Q&A & Invalidation Levels'),
  ];

  // -------------------------------------------------------------------------
  // Tab 1: Live Chat & Stream
  // -------------------------------------------------------------------------
  Widget _buildLiveChatTab(BuildContext context) {
    final UiTheme theme = context.ui;

    return Column(
      children: <Widget>[
        Expanded(
          child: _chatMessages.isEmpty
              ? Center(
                  child: UiEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No chat messages yet',
                    message:
                        'Be the first to share your market view or ask a question!',
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  itemCount: _chatMessages.length,
                  padding: EdgeInsets.symmetric(
                    vertical: context.sp(theme.spacing.xs),
                  ),
                  itemBuilder: (BuildContext ctx, int index) {
                    final LiveRoomMessage msg = _chatMessages[index];
                    return Container(
                      margin: EdgeInsets.only(
                        bottom: context.sp(theme.spacing.xs),
                      ),
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
                          UiAvatar(name: msg.senderName, size: UiSize.xs),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Text(
                                      msg.senderName,
                                      style: context.uiText.caption.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: theme.colors.foreground,
                                      ),
                                    ),
                                    if (msg.isHost) ...<Widget>[
                                      SizedBox(
                                        width: context.sp(theme.spacing.xxs),
                                      ),
                                      UiBadge(
                                        label: 'HOST',
                                        intent: UiIntent.primary,
                                        size: UiSize.xs,
                                      ),
                                    ] else if (msg.isSpeaker) ...<Widget>[
                                      SizedBox(
                                        width: context.sp(theme.spacing.xxs),
                                      ),
                                      UiBadge(
                                        label: 'SPEAKER',
                                        intent: UiIntent.success,
                                        size: UiSize.xs,
                                      ),
                                    ],
                                    const Spacer(),
                                    Text(
                                      _formatTimeAgo(msg.createdAt),
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
  // Tab 2: Q&A Queue Tab
  // -------------------------------------------------------------------------
  Widget _buildQnaTab(BuildContext context) {
    final UiTheme theme = context.ui;
    final int unansweredCount = _questions.where((q) => !q.isAnswered).length;

    return Column(
      children: <Widget>[
        // Q&A Status Header Banner
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.xs),
          ),
          margin: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
          decoration: BoxDecoration(
            color: theme.colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(theme.radii.md),
            border: Border.all(
              color: theme.colors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.help_outline_rounded,
                size: context.sz(16),
                color: theme.colors.primary,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: Text(
                  'Community Q&A Queue ($unansweredCount pending)',
                  style: context.uiText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colors.foreground,
                  ),
                ),
              ),
              UiBadge(
                label: 'UPVOTED FIRST',
                intent: UiIntent.primary,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
              ),
            ],
          ),
        ),

        // Questions List
        Expanded(
          child: _questions.isEmpty
              ? Center(
                  child: UiEmptyState(
                    icon: Icons.help_outline_rounded,
                    title: 'No questions in queue',
                    message:
                        'Ask the host or speakers a trading question below!',
                  ),
                )
              : ListView.builder(
                  itemCount: _questions.length,
                  padding: EdgeInsets.symmetric(
                    vertical: context.sp(theme.spacing.xxs),
                  ),
                  itemBuilder: (BuildContext ctx, int index) {
                    final LiveRoomQuestion q = _questions[index];
                    return Container(
                      margin: EdgeInsets.only(
                        bottom: context.sp(theme.spacing.xs),
                      ),
                      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                      decoration: BoxDecoration(
                        color: q.isAnswered
                            ? theme.colors.surfaceMuted.withValues(alpha: 0.5)
                            : theme.colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(theme.radii.md),
                        border: Border.all(
                          color: q.hasUpvoted
                              ? theme.colors.primary.withValues(alpha: 0.4)
                              : theme.colors.border,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Upvote column
                          InkWell(
                            onTap: () => _toggleQuestionUpvote(q),
                            borderRadius: BorderRadius.circular(theme.radii.sm),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.sp(theme.spacing.xs),
                                vertical: context.sp(theme.spacing.xxs),
                              ),
                              decoration: BoxDecoration(
                                color: q.hasUpvoted
                                    ? theme.colors.primary.withValues(
                                        alpha: 0.15,
                                      )
                                    : theme.colors.surface,
                                borderRadius: BorderRadius.circular(
                                  theme.radii.sm,
                                ),
                                border: Border.all(
                                  color: q.hasUpvoted
                                      ? theme.colors.primary
                                      : theme.colors.border,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.arrow_drop_up_rounded,
                                    size: context.sz(20),
                                    color: q.hasUpvoted
                                        ? theme.colors.primary
                                        : theme.colors.foregroundMuted,
                                  ),
                                  Text(
                                    '${q.upvotesCount}',
                                    style: context.uiText.label.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: q.hasUpvoted
                                          ? theme.colors.primary
                                          : theme.colors.foreground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: context.sp(theme.spacing.sm)),

                          // Question Body
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Text(
                                      q.authorName,
                                      style: context.uiText.caption.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(
                                      width: context.sp(theme.spacing.xs),
                                    ),
                                    if (q.isAnswered)
                                      UiBadge(
                                        label: 'ANSWERED ON STAGE',
                                        intent: UiIntent.success,
                                        size: UiSize.xs,
                                      )
                                    else
                                      UiBadge(
                                        label: 'IN QUEUE',
                                        intent: UiIntent.info,
                                        variant: UiBadgeVariant.soft,
                                        size: UiSize.xs,
                                      ),
                                    const Spacer(),
                                    // Host/Moderator answer toggle
                                    UiIconButton(
                                      icon: q.isAnswered
                                          ? Icons.undo_rounded
                                          : Icons.check_circle_outline_rounded,
                                      size: UiSize.xs,
                                      variant: UiVariant.ghost,
                                      tooltip: q.isAnswered
                                          ? 'Mark Unanswered'
                                          : 'Mark Answered on Stage',
                                      onPressed: () =>
                                          _toggleQuestionAnswered(q),
                                    ),
                                  ],
                                ),
                                SizedBox(height: context.sp(theme.spacing.xxs)),
                                Text(
                                  q.question,
                                  style: context.uiText.body.copyWith(
                                    fontSize: context.fs(13),
                                    color: q.isAnswered
                                        ? theme.colors.foregroundMuted
                                        : theme.colors.foreground,
                                    decoration: q.isAnswered
                                        ? TextDecoration.lineThrough
                                        : null,
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

        // Ask Question input composer
        Container(
          padding: EdgeInsets.only(top: context.sp(theme.spacing.xs)),
          child: Row(
            children: <Widget>[
              Expanded(
                child: UiInput(
                  controller: _qnaController,
                  hintText: 'Ask the host or speakers a trading question...',
                  size: UiSize.sm,
                  onSubmitted: (_) => _submitQuestion(),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiIconButton(
                icon: Icons.send_rounded,
                variant: UiVariant.primary,
                intent: UiIntent.primary,
                size: UiSize.sm,
                tooltip: 'Submit Question',
                onPressed: _submitQuestion,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Tab 3: Poll & Trade Setup
  // -------------------------------------------------------------------------
  Widget _buildPollAndSetupTab(BuildContext context) {
    final UiTheme theme = context.ui;
    final int totalVotes = _pollVotesBullish + _pollVotesBearish;
    final double pctBullish = totalVotes > 0
        ? (_pollVotesBullish / totalVotes)
        : 0.5;
    final double pctBearish = totalVotes > 0
        ? (_pollVotesBearish / totalVotes)
        : 0.5;

    final LiveAudioRoom? activeRoom =
        widget.repository?.allLiveRooms
            .where((r) => r.id == widget.roomId)
            .firstOrNull ??
        widget.repository?.activeTunedRoom;

    final String pollQuestion =
        (activeRoom != null && activeRoom.topic.isNotEmpty)
        ? 'Floor Poll: ${activeRoom.topic}'
        : 'Floor Poll: What is your market bias into the session close?';

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
                  pollQuestion,
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
                            Text(
                              '🟢 Bullish (Call Bias)',
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
                            Text(
                              '🔴 Bearish (Put Bias)',
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
          ] else ...<Widget>[
            UiCard(
              variant: UiCardVariant.surface,
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              child: UiEmptyState(
                icon: Icons.push_pin_outlined,
                title: 'No Pinned Setup',
                message:
                    'The space host has not pinned an active trade setup for this room yet.',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Tab 4: Room Info & Details
  // -------------------------------------------------------------------------
  Widget _buildRoomInfoTab(BuildContext context) {
    final UiTheme theme = context.ui;
    final int currentAgendaIndex = (_stageTick ~/ 60).clamp(
      0,
      _roomAgenda.length - 1,
    );

    final LiveAudioRoom? activeRoom =
        widget.repository?.allLiveRooms
            .where((r) => r.id == widget.roomId)
            .firstOrNull ??
        widget.repository?.activeTunedRoom;

    final List<LiveAudioRoom> upcomingRooms =
        (widget.repository?.allLiveRooms ?? <LiveAudioRoom>[])
            .where(
              (r) =>
                  r.id != widget.roomId && r.status == LiveRoomStatus.scheduled,
            )
            .toList();

    final List<String> roomTickers = <String>[
      if (widget.pinnedSetup?.ticker != null &&
          widget.pinnedSetup!.ticker.isNotEmpty)
        widget.pinnedSetup!.ticker,
      ...?activeRoom?.tags,
    ];
    final List<String> tickersToDisplay = roomTickers.isNotEmpty
        ? roomTickers.toSet().toList()
        : <String>['NIFTY', 'BANKNIFTY'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Room Agenda Timeline
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            margin: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(theme.radii.lg),
              border: Border.all(color: theme.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule_rounded,
                      size: context.sz(16),
                      color: theme.colors.primary,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    Text(
                      'ROOM AGENDA & TIMELINE',
                      style: context.uiText.label.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                for (int i = 0; i < _roomAgenda.length; i++) ...<Widget>[
                  Builder(
                    builder: (BuildContext aCtx) {
                      final _AgendaSegment seg = _roomAgenda[i];
                      final bool isCurrent = i == currentAgendaIndex;
                      final bool isPast = i < currentAgendaIndex;
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: context.sp(theme.spacing.xxs),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.sp(theme.spacing.xs),
                                vertical: context.sp(theme.spacing.xxs),
                              ),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? theme.colors.primary.withValues(
                                        alpha: 0.15,
                                      )
                                    : theme.colors.surface,
                                borderRadius: BorderRadius.circular(
                                  theme.radii.sm,
                                ),
                                border: Border.all(
                                  color: isCurrent
                                      ? theme.colors.primary
                                      : theme.colors.border,
                                ),
                              ),
                              child: Text(
                                seg.time,
                                style: context.uiText.label.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: context.fs(11),
                                  color: isCurrent
                                      ? theme.colors.primary
                                      : theme.colors.foregroundMuted,
                                ),
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            Expanded(
                              child: Text(
                                seg.title,
                                style: context.uiText.caption.copyWith(
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isPast
                                      ? theme.colors.foregroundMuted
                                      : theme.colors.foreground,
                                ),
                              ),
                            ),
                            if (isCurrent)
                              UiBadge(
                                label: 'LIVE NOW',
                                intent: UiIntent.success,
                                size: UiSize.xs,
                              )
                            else if (isPast)
                              Icon(
                                Icons.check_circle_rounded,
                                size: context.sz(14),
                                color: theme.colors.success,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          // Upcoming Spaces
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            margin: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(theme.radii.lg),
              border: Border.all(color: theme.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.event_available_rounded,
                      size: context.sz(16),
                      color: theme.colors.info,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    Text(
                      'UPCOMING SPACES',
                      style: context.uiText.label.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colors.info,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                if (upcomingRooms.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: context.sp(theme.spacing.sm),
                    ),
                    child: Center(
                      child: Text(
                        'No upcoming scheduled spaces at this time.',
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                    ),
                  )
                else
                  for (final LiveAudioRoom room in upcomingRooms) ...<Widget>[
                    Container(
                      margin: EdgeInsets.only(
                        bottom: context.sp(theme.spacing.xs),
                      ),
                      padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                      decoration: BoxDecoration(
                        color: theme.colors.surface,
                        borderRadius: BorderRadius.circular(theme.radii.md),
                        border: Border.all(color: theme.colors.border),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  room.title,
                                  style: context.uiText.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: context.sp(theme.spacing.xxs)),
                                Text(
                                  '${room.host.displayName} • ${room.scheduledFor != null ? _formatScheduledTime(room.scheduledFor!) : "Scheduled"}',
                                  style: context.uiText.label.copyWith(
                                    fontSize: context.fs(11),
                                    color: theme.colors.foregroundMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          UiButton(
                            label: 'Remind Me',
                            leadingIcon: Icons.notifications_none_rounded,
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            onPressed: () {
                              widget.repository?.toggleRoomReminder(room.id);
                              UiToast.success(
                                context,
                                title: 'Reminder Set',
                                message:
                                    'We will notify you when "${room.title}" goes live.',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
              ],
            ),
          ),

          // Room Specifications Container
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
                    Text(
                      'Opus HD (48 kHz)',
                      style: context.uiText.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Divider(height: context.sp(theme.spacing.sm)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Host Latency', style: context.uiText.caption),
                    Text(
                      '24 ms (Direct Mesh)',
                      style: context.uiText.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colors.success,
                      ),
                    ),
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
                  children: tickersToDisplay.map((t) {
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
    return RepaintBoundary(
      child: AnimatedBuilder(
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
      ),
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

    final double gainPct = setup.entry > 0
        ? (((setup.target - setup.entry).abs() / setup.entry) * 100)
        : 0.0;
    final bool isLong = setup.side.toUpperCase() == 'LONG';
    final String targetLabel =
        '${isLong ? "+" : "-"}${gainPct.toStringAsFixed(1)}% Target';

    return Container(
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      decoration: BoxDecoration(
        color: theme.colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(theme.radii.md),
        border: Border.all(color: theme.colors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.xxs),
            runSpacing: context.sp(theme.spacing.xxs),
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
                label: targetLabel,
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
    _translateY = Tween<double>(
      begin: 0,
      end: -160,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
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
            child: Text(widget.emoji, style: const TextStyle(fontSize: 32)),
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
        border: Border.all(color: theme.colors.danger.withValues(alpha: 0.4)),
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
