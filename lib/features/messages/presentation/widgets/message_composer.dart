import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/models/messages_models.dart';

/// The thread composer.
///
/// Owns its text controller and focus, persists the draft back to the caller,
/// and emits a fully-formed intent (text, an attachment or a shared record).
/// The attach menu, quick-share suggestions and quick-reaction row are all fed
/// from data — the attachment kinds come from [MessageAttachmentKind], the
/// shareable records from [shareableRefs], the emoji from [quickReactions].
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
  final void Function(String durationLabel)? onSendVoice;
  final void Function(AppLinkRef ref)? onSendRef;
  final void Function(String emoji)? onQuickReaction;
  final void Function(String draft)? onDraftChanged;
  final bool autofocus;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  bool _hasText = false;
  bool _showQuickBar = false;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDraft);
    _hasText = widget.initialDraft.trim().isNotEmpty;
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching threads swaps in that thread's saved draft.
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

  void _startRecording() {
    HapticFeedback.mediumImpact();
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
  }

  void _cancelRecording() {
    HapticFeedback.selectionClick();
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
  }

  void _sendVoiceRecording() {
    _recordTimer?.cancel();
    final int sec = _recordSeconds < 1 ? 3 : _recordSeconds;
    final int m = sec ~/ 60;
    final int s = sec % 60;
    final String durationLabel = '$m:${s.toString().padLeft(2, '0')}';
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
    HapticFeedback.lightImpact();
    if (widget.onSendVoice != null) {
      widget.onSendVoice!(durationLabel);
    } else {
      widget.onSendAttachment?.call(MessageAttachmentKind.voice);
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
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
              if (widget.replyTo != null && !_isRecording)
                _replyBar(context, widget.replyTo!),
              if (_showQuickBar && !_isRecording) _quickBar(context),
              if (_isRecording)
                _recordingBar(context)
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    _attachButton(context),
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    Expanded(
                      child: UiInput(
                        controller: _controller,
                        focusNode: _focus,
                        autofocus: widget.autofocus,
                        hintText: 'Message…',
                        minLines: 1,
                        maxLines: 5,
                        variant: UiInputVariant.filled,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        trailing: _emojiToggle(context),
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    _sendButton(context),
                  ],
                ),
            ],
          ),
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

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.xs),
        vertical: context.sp(theme.spacing.xxs),
      ),
      child: Row(
        children: <Widget>[
          UiIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Discard',
            intent: UiIntent.danger,
            size: UiSize.md,
            onPressed: _cancelRecording,
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.sm),
                vertical: context.sp(theme.spacing.xs),
              ),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: context.radius(theme.radii.lg),
                border: Border.all(
                  color: colors.destructive.withValues(alpha: 0.3),
                  width: theme.borders.hairline,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: context.sz(10),
                    height: context.sz(10),
                    decoration: BoxDecoration(
                      color: colors.destructive,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Text(
                    timeStr,
                    style: context.uiText.bodyStrong.copyWith(
                      color: colors.destructive,
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: SizedBox(
                      height: context.sz(18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List<Widget>.generate(16, (int i) {
                          final double h =
                              4.0 + ((i + _recordSeconds) % 5) * 3.0;
                          return Container(
                            width: context.sz(2.5),
                            height: context.sz(h),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(
                                context.sz(2),
                              ),
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
          UiIconButton(
            icon: Icons.send_rounded,
            tooltip: 'Send voice note',
            variant: UiVariant.solid,
            intent: UiIntent.primary,
            size: UiSize.md,
            onPressed: _sendVoiceRecording,
          ),
        ],
      ),
    );
  }

  Widget _attachButton(BuildContext context) {
    return UiDropdownMenu(
      alignRight: false,
      items: <UiMenuItem>[
        const UiMenuItem.section('Attach'),
        for (final MessageAttachmentKind kind in MessageAttachmentKind.values)
          UiMenuItem(
            label: kind.label,
            icon: kind.icon,
            onPressed: () => widget.onSendAttachment?.call(kind),
          ),
        if (widget.shareableRefs.isNotEmpty) ...<UiMenuItem>[
          const UiMenuItem.divider(),
          const UiMenuItem.section('Share a record'),
          for (final AppLinkRef ref in widget.shareableRefs)
            UiMenuItem(
              label: ref.title,
              icon: ref.effectiveIcon,
              description: ref.subtitle,
              onPressed: () => widget.onSendRef?.call(ref),
            ),
        ],
      ],
      child: UiIconButton(
        icon: Icons.add_circle_outline_rounded,
        tooltip: 'Attach or share',
        size: UiSize.md,
      ),
    );
  }

  Widget _emojiToggle(BuildContext context) {
    return UiIconButton(
      icon: _showQuickBar
          ? Icons.keyboard_arrow_down_rounded
          : Icons.mood_outlined,
      tooltip: 'Quick reactions',
      size: UiSize.sm,
      onPressed: () => setState(() => _showQuickBar = !_showQuickBar),
    );
  }

  Widget _sendButton(BuildContext context) {
    if (_hasText) {
      return UiIconButton(
        icon: Icons.send_rounded,
        tooltip: 'Send',
        variant: UiVariant.solid,
        intent: UiIntent.primary,
        size: UiSize.md,
        onPressed: _send,
      );
    }
    // Nothing typed → a mic affordance. Tapping it activates live voice note recording.
    return UiIconButton(
      icon: Icons.mic_none_rounded,
      tooltip: 'Record voice note',
      size: UiSize.md,
      onPressed: _startRecording,
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
