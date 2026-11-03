import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/models/messages_models.dart';

/// The thread composer.
///
/// Symmetrically balanced, modern messaging input dock with inline quick action
/// pills for charts, trade setups, voice memos, and media attachments.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.threadId,
    this.initialDraft = '',
    this.shareableRefs = const <AppLinkRef>[],
    this.quickReactions = const <String>[],
    this.onSendText,
    this.onSendAttachment,
    this.onSendVoice,
    this.onSendRef,
    this.onQuickReaction,
    this.onDraftChanged,
    this.replyTo,
    this.onCancelReply,
    this.autofocus = false,
  });

  final String threadId;
  final String initialDraft;
  final List<AppLinkRef> shareableRefs;
  final List<String> quickReactions;
  final ChatMessage? replyTo;
  final VoidCallback? onCancelReply;

  final void Function(String body)? onSendText;
  final void Function(MessageAttachmentKind kind)? onSendAttachment;
  final void Function(String durationLabel, Uint8List? audioBytes)? onSendVoice;
  final void Function(AppLinkRef ref)? onSendRef;
  final void Function(String emoji)? onQuickReaction;
  final void Function(String draft)? onDraftChanged;
  final bool autofocus;

  @override
  State<MessageComposer> createState() => MessageComposerState();
}

class MessageComposerState extends State<MessageComposer>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  bool _hasText = false;
  bool _showQuickBar = false;
  final bool _showAttachmentPills = true;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  late final AnimationController _pulseController;
  AudioRecorder? _audioRecorder;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDraft);
    _hasText = widget.initialDraft.trim().isNotEmpty;
    _controller.addListener(_onChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    try {
      _audioRecorder = AudioRecorder();
    } catch (e) {
      debugPrint('[MessageComposer] AudioRecorder init: $e');
    }
  }

  @override
  void didUpdateWidget(covariant MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadId != widget.threadId) {
      _controller.value = TextEditingValue(
        text: widget.initialDraft,
        selection: TextSelection.collapsed(offset: widget.initialDraft.length),
      );
      _showQuickBar = false;
      _hasText = widget.initialDraft.trim().isNotEmpty;
    }
  }

  void _onChanged() {
    final bool has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    widget.onDraftChanged?.call(_controller.text);
  }

  void _send() {
    final String body = _controller.text.trim();
    if (body.isEmpty) return;
    widget.onSendText?.call(body);
    _controller.clear();
    widget.onDraftChanged?.call('');
    _focus.requestFocus();
  }

  void startRecording() => _startRecording();

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();
    _pulseController.repeat(reverse: true);
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _recordSeconds++);
    });

    _audioRecorder ??= AudioRecorder();
    try {
      // 1. Explicitly check permissions on mobile/desktop where native dialogs are used
      bool hasPermission = true;
      if (!kIsWeb) {
        try {
          hasPermission = await _audioRecorder!.hasPermission();
        } catch (e) {
          debugPrint('[MessageComposer] Mic permission check fallback: $e');
          hasPermission = true;
        }
      }

      if (!hasPermission && !kIsWeb) {
        _cancelRecording();
        if (mounted) {
          UiToastScope.maybeOf(context)?.show(
            UiToastData(
              title: 'Microphone permission required',
              message:
                  'Please allow microphone access in your device settings to record voice notes.',
              intent: UiIntent.warning,
            ),
          );
        }
        return;
      }

      // 2. Start recording with platform-optimal audio encoder
      try {
        if (kIsWeb) {
          AudioEncoder effectiveEncoder = AudioEncoder.opus;
          try {
            final isOpus = await _audioRecorder!.isEncoderSupported(AudioEncoder.opus);
            if (!isOpus) {
              final isAac = await _audioRecorder!.isEncoderSupported(AudioEncoder.aacLc);
              effectiveEncoder = isAac ? AudioEncoder.aacLc : AudioEncoder.wav;
            }
          } catch (_) {}

          await _audioRecorder!.start(
            RecordConfig(encoder: effectiveEncoder),
            path: '',
          );
        } else {
          final tempDir = await getTemporaryDirectory();
          final path =
              '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder!.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: path,
          );
        }
      } catch (e) {
        debugPrint('[MessageComposer] AudioRecorder start error: $e');
        _cancelRecording();
        if (mounted) {
          UiToastScope.maybeOf(context)?.show(
            UiToastData(
              title: 'Microphone access required',
              message:
                  'Please click the lock or microphone icon in your browser address bar to allow audio recording.',
              intent: UiIntent.warning,
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('[MessageComposer] Error starting voice recording: $e');
      _cancelRecording();
      if (mounted) {
        UiToastScope.maybeOf(context)?.show(
          UiToastData(
            title: 'Could not record audio',
            message: '$e',
            intent: UiIntent.danger,
          ),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    HapticFeedback.selectionClick();
    _pulseController.stop();
    _pulseController.reset();
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
    try {
      if (_audioRecorder != null && await _audioRecorder!.isRecording()) {
        await _audioRecorder!.stop();
      }
    } catch (_) {}
  }

  Future<void> _sendVoiceRecording() async {
    _recordTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    final int sec = _recordSeconds < 1 ? 1 : _recordSeconds;
    final int m = sec ~/ 60;
    final int s = sec % 60;
    final String durationLabel = '$m:${s.toString().padLeft(2, '0')}';

    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
    HapticFeedback.lightImpact();

    Uint8List? audioBytes;
    try {
      if (_audioRecorder != null && await _audioRecorder!.isRecording()) {
        final String? path = await _audioRecorder!.stop();
        if (path != null && path.isNotEmpty) {
          if (kIsWeb) {
            final resp = await http.get(Uri.parse(path));
            if (resp.statusCode == 200) {
              audioBytes = resp.bodyBytes;
            }
          } else {
            final file = io.File(path);
            if (await file.exists()) {
              audioBytes = await file.readAsBytes();
              unawaited(file.delete());
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[MessageComposer] Error stopping audio recorder: $e');
    }

    if (widget.onSendVoice != null) {
      widget.onSendVoice!(durationLabel, audioBytes);
    } else {
      widget.onSendAttachment?.call(MessageAttachmentKind.voice);
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder?.dispose();
    _pulseController.dispose();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border, width: theme.borders.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 1. Reply to bar
              if (widget.replyTo != null && !_isRecording)
                _replyBar(context, widget.replyTo!),

              // 2. Quick reactions drawer
              if (_showQuickBar && !_isRecording) _quickBar(context),

              // 3. Quick Feature Pills Row (Chart, Trade Setup, Photo, Doc, Voice)
              if (_showAttachmentPills && !_isRecording && !_hasText)
                _quickAttachmentPills(context),

              // 4. Main Balanced Row
              if (_isRecording)
                _recordingBar(context)
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    // Left Attach Button (40x40 circle)
                    _attachButton(context),

                    SizedBox(width: context.sp(theme.spacing.xs)),

                    // Centered Text Input Capsule
                    Expanded(
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: context.sz(40),
                          maxHeight: context.sz(140),
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(context.sz(20)),
                          border: Border.all(
                            color: _focus.hasFocus
                                ? colors.primary.withValues(alpha: 0.7)
                                : colors.border.withValues(alpha: 0.6),
                            width: _focus.hasFocus ? 1.5 : theme.borders.hairline,
                          ),
                        ),
                        padding: EdgeInsets.only(
                          left: context.sp(theme.spacing.sm),
                          right: context.sp(theme.spacing.xxs),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focus,
                                autofocus: widget.autofocus,
                                minLines: 1,
                                maxLines: 5,
                                style: context.uiText.body.copyWith(
                                  color: colors.foreground,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Message…',
                                  hintStyle: context.uiText.body.copyWith(
                                    color: colors.foregroundMuted,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: context.sp(theme.spacing.xs),
                                  ),
                                ),
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                              ),
                            ),
                            _emojiToggle(context),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(width: context.sp(theme.spacing.xs)),

                    // Right Send / Mic Action Button (40x40 circle)
                    _actionButton(context),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAttachmentPills(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _quickPill(
              context,
              label: 'Chart',
              icon: Icons.candlestick_chart_rounded,
              color: colors.primary,
              onTap: () => widget.onSendAttachment?.call(MessageAttachmentKind.chart),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            _quickPill(
              context,
              label: 'Trade Setup',
              icon: Icons.trending_up_rounded,
              color: colors.success,
              onTap: () => widget.onSendAttachment?.call(MessageAttachmentKind.tradeSetup),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            _quickPill(
              context,
              label: 'Photo',
              icon: Icons.image_outlined,
              color: colors.warning,
              onTap: () => widget.onSendAttachment?.call(MessageAttachmentKind.image),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            _quickPill(
              context,
              label: 'Document',
              icon: Icons.description_outlined,
              color: colors.info,
              onTap: () => widget.onSendAttachment?.call(MessageAttachmentKind.document),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            _quickPill(
              context,
              label: 'Voice Note',
              icon: Icons.mic_rounded,
              color: colors.destructive,
              onTap: _startRecording,
            ),
            if (widget.shareableRefs.isNotEmpty) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xs)),
              for (final AppLinkRef ref in widget.shareableRefs.take(2)) ...<Widget>[
                _quickPill(
                  context,
                  label: ref.title,
                  icon: ref.effectiveIcon,
                  color: colors.foreground,
                  onTap: () => widget.onSendRef?.call(ref),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickPill(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = context.ui;
    final colors = theme.colors;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.xs),
          vertical: context.sz(5),
        ),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(context.sz(14)),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.8),
            width: theme.borders.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: context.sz(14), color: color),
            SizedBox(width: context.sp(theme.spacing.xxs)),
            Text(
              label,
              style: context.uiText.caption.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: context.fs(11.5),
                color: colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordingBar(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final int m = _recordSeconds ~/ 60;
    final int s = _recordSeconds % 60;
    final String timeStr = '$m:${s.toString().padLeft(2, '0')}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Discard Button (40x40 circle)
        GestureDetector(
          onTap: _cancelRecording,
          child: Container(
            width: context.sz(40),
            height: context.sz(40),
            decoration: BoxDecoration(
              color: colors.destructive.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              color: colors.destructive,
              size: context.sz(20),
            ),
          ),
        ),

        SizedBox(width: context.sp(theme.spacing.xs)),

        // Recording Studio Pill
        Expanded(
          child: Container(
            height: context.sz(40),
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.sm),
            ),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(context.sz(20)),
              border: Border.all(
                color: colors.destructive.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Row(
              children: <Widget>[
                // Pulsating red indicator dot
                FadeTransition(
                  opacity: _pulseController,
                  child: Container(
                    width: context.sz(10),
                    height: context.sz(10),
                    decoration: BoxDecoration(
                      color: colors.destructive,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                SizedBox(width: context.sp(theme.spacing.xs)),

                // Counter
                Text(
                  timeStr,
                  style: context.uiText.bodyStrong.copyWith(
                    color: colors.destructive,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(width: context.sp(theme.spacing.sm)),

                // Dynamic Oscillating Soundwave Bars
                Expanded(
                  child: SizedBox(
                    height: context.sz(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List<Widget>.generate(18, (int i) {
                        final double h = 4.0 +
                            ((i * 3 + _recordSeconds * 4) % 18).toDouble();
                        return Container(
                          width: context.sz(2.5),
                          height: context.sz(h),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(context.sz(2)),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(width: context.sp(theme.spacing.xs)),

        // Send Voice Button (40x40 circle)
        GestureDetector(
          onTap: _sendVoiceRecording,
          child: Container(
            width: context.sz(40),
            height: context.sz(40),
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_upward_rounded,
              color: colors.onPrimary,
              size: context.sz(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _attachButton(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return UiDropdownMenu(
      alignRight: false,
      items: <UiMenuItem>[
        const UiMenuItem.section('Attach to message'),
        UiMenuItem(
          label: 'Technical Chart',
          icon: Icons.candlestick_chart_rounded,
          description: 'Share live candlestick setup',
          onPressed: () => widget.onSendAttachment?.call(MessageAttachmentKind.chart),
        ),
        UiMenuItem(
          label: 'Trade Setup',
          icon: Icons.trending_up_rounded,
          description: 'Entry, stop loss & profit target',
          onPressed: () => widget.onSendAttachment?.call(MessageAttachmentKind.tradeSetup),
        ),
        UiMenuItem(
          label: 'Photo / Image',
          icon: Icons.image_outlined,
          description: 'Upload from device photo library',
          onPressed: () => widget.onSendAttachment?.call(MessageAttachmentKind.image),
        ),
        UiMenuItem(
          label: 'Document',
          icon: Icons.description_outlined,
          description: 'PDF or analysis reports',
          onPressed: () => widget.onSendAttachment?.call(MessageAttachmentKind.document),
        ),
        UiMenuItem(
          label: 'Voice Note',
          icon: Icons.mic_none_rounded,
          description: 'Record an audio note',
          onPressed: _startRecording,
        ),
        if (widget.shareableRefs.isNotEmpty) ...<UiMenuItem>[
          const UiMenuItem.divider(),
          const UiMenuItem.section('Share Desk Record'),
          for (final AppLinkRef ref in widget.shareableRefs)
            UiMenuItem(
              label: ref.title,
              icon: ref.effectiveIcon,
              description: ref.subtitle,
              onPressed: () => widget.onSendRef?.call(ref),
            ),
        ],
      ],
      child: Tooltip(
        message: 'Attach or share',
        child: Container(
          width: context.sz(40),
          height: context.sz(40),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.border.withValues(alpha: 0.8),
              width: theme.borders.hairline,
            ),
          ),
          child: Icon(
            Icons.add_rounded,
            color: colors.foreground,
            size: context.sz(20),
          ),
        ),
      ),
    );
  }

  Widget _emojiToggle(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return Tooltip(
      message: 'Quick reactions',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _showQuickBar = !_showQuickBar);
        },
        child: Container(
          width: context.sz(32),
          height: context.sz(32),
          alignment: Alignment.center,
          child: Icon(
            _showQuickBar
                ? Icons.keyboard_arrow_down_rounded
                : Icons.sentiment_satisfied_alt_outlined,
            size: context.sz(20),
            color: _showQuickBar ? colors.primary : colors.foregroundMuted,
          ),
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    if (_hasText) {
      return Tooltip(
        message: 'Send',
        child: GestureDetector(
          onTap: _send,
          child: Container(
            width: context.sz(40),
            height: context.sz(40),
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_upward_rounded,
              color: colors.onPrimary,
              size: context.sz(20),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: 'Record voice note',
      child: GestureDetector(
        onTap: _startRecording,
        child: Container(
          width: context.sz(40),
          height: context.sz(40),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.border.withValues(alpha: 0.8),
              width: theme.borders.hairline,
            ),
          ),
          child: Icon(
            Icons.mic_rounded,
            color: colors.foreground,
            size: context.sz(20),
          ),
        ),
      ),
    );
  }

  Widget _quickBar(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Wrap(
              spacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                for (final String emoji in widget.quickReactions)
                  _QuickEmoji(
                    emoji: emoji,
                    onTap: () {
                      widget.onQuickReaction?.call(emoji);
                      setState(() => _showQuickBar = false);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _replyBar(BuildContext context, ChatMessage reply) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final String senderLabel = reply.fromMe ? 'You' : 'Trader';
    return Container(
      margin: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xxs),
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: context.radius(theme.radii.sm),
        border: Border(
          left: BorderSide(color: colors.primary, width: context.sz(3)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Replying to $senderLabel',
                  style: context.uiText.caption.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  reply.body.isNotEmpty
                      ? reply.body
                      : (reply.sharedRef?.title ??
                            reply.attachment?.title ??
                            'Attachment'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onCancelReply != null)
            UiIconButton(
              icon: Icons.close_rounded,
              size: UiSize.xs,
              tooltip: 'Cancel reply',
              onPressed: widget.onCancelReply,
            ),
        ],
      ),
    );
  }
}

class _QuickEmoji extends StatelessWidget {
  const _QuickEmoji({required this.emoji, this.onTap});

  final String emoji;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Container(
        width: context.sz(34),
        height: context.sz(34),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colors.surfaceMuted,
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: TextStyle(fontSize: context.fs(18))),
      ),
    );
  }
}
