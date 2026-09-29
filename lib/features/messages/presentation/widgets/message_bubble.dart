import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/models/messages_models.dart';

/// One chat bubble.
///
/// Renders every [ChatMessage] variant from the model alone: plain text, an
/// image/chart/document/voice [MessageAttachment], a shared [AppLinkRef] record
/// card, emoji reactions, delivery ticks and system notices. No literal copy
/// lives here — the composer and repository decide what a message contains.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.senderName,
    this.showTail = true,
    this.maxWidthFraction = 0.74,
    this.onOpenRef,
    this.onOpenAttachment,
    this.onLongPress,
    this.onReactionTap,
    this.replyMessage,
  });

  final ChatMessage message;
  final ChatMessage? replyMessage;

  /// Sender label shown above inbound bubbles in group threads.
  final String? senderName;

  /// Last bubble in a same-sender run gets the delivery footer.
  final bool showTail;

  final double maxWidthFraction;
  final void Function(AppLinkRef ref)? onOpenRef;
  final void Function(MessageAttachment attachment)? onOpenAttachment;
  final VoidCallback? onLongPress;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    if (message.systemNotice) return _SystemNotice(text: message.body);

    final UiTheme theme = context.ui;
    final bool me = message.fromMe;
    final double maxWidth =
        MediaQuery.sizeOf(context).width * maxWidthFraction;

    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(showTail ? theme.spacing.sm : theme.spacing.xxs)),
      child: Column(
        crossAxisAlignment:
            me ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          if (senderName != null && !me)
            Padding(
              padding: EdgeInsets.only(
                left: context.sp(theme.spacing.sm),
                bottom: context.sp(theme.spacing.xxs),
              ),
              child: Text(
                senderName!,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: GestureDetector(
              onLongPress: onLongPress,
              child: _bubble(context),
            ),
          ),
          if (message.hasReactions)
            Padding(
              padding: EdgeInsets.only(top: context.sp(theme.spacing.xxs)),
              child: _reactions(context),
            ),
          if (showTail)
            Padding(
              padding: EdgeInsets.only(top: context.sp(theme.spacing.xxs)),
              child: _footer(context),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _bubble(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool me = message.fromMe;
    final Color bg = me ? colors.primary : colors.surfaceMuted;
    final Color fg = me ? colors.onPrimary : colors.foreground;

    final List<Widget> parts = <Widget>[];
    if (replyMessage != null) {
      final String sender = replyMessage!.fromMe ? 'You' : (senderName ?? 'Trader');
      parts.add(
        Container(
          margin: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.xs),
            vertical: context.sp(theme.spacing.xxs),
          ),
          decoration: BoxDecoration(
            color: me ? Colors.black.withValues(alpha: 0.15) : colors.surfaceHover,
            borderRadius: context.radius(theme.radii.sm),
            border: Border(
              left: BorderSide(
                color: me ? colors.onPrimary : colors.primary,
                width: context.sz(3),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sender,
                style: context.uiText.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: me ? colors.onPrimary : colors.primary,
                ),
              ),
              Text(
                replyMessage!.body.isNotEmpty
                    ? replyMessage!.body
                    : (replyMessage!.sharedRef?.title ?? replyMessage!.attachment?.title ?? 'Attachment'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: (me ? colors.onPrimary : colors.foreground).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (message.attachment != null) {
      parts.add(_attachment(context, message.attachment!, fg));
    }
    if (message.sharedRef != null) {
      parts.add(_sharedRef(context, message.sharedRef!));
    }
    if (message.hasText) {
      if (parts.isNotEmpty) {
        parts.add(SizedBox(height: context.sp(theme.spacing.xs)));
      }
      parts.add(
        Text(
          message.body,
          style: context.uiText.body.copyWith(color: fg, height: 1.35),
        ),
      );
    }

    // A media/record-only bubble uses tighter padding so the card fills it.
    final bool mediaOnly =
        !message.hasText && (message.attachment != null || message.sharedRef != null);
    final double padH = context.sp(mediaOnly ? theme.spacing.xs : theme.spacing.sm);
    final double padV = context.sp(mediaOnly ? theme.spacing.xs : theme.spacing.sm);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: _bubbleRadius(context, me),
        border: me
            ? null
            : Border.all(
                color: colors.border,
                width: theme.borders.hairline,
              ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: parts,
        ),
      ),
    );
  }

  BorderRadius _bubbleRadius(BuildContext context, bool me) {
    final Radius r = Radius.circular(context.sz(18));
    final Radius tail = Radius.circular(context.sz(6));
    return BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: me ? r : tail,
      bottomRight: me ? tail : r,
    );
  }

  // ---------------------------------------------------------------------------

  Widget _sharedRef(BuildContext context, AppLinkRef ref) {
    final UiTheme theme = context.ui;
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: context.sz(240)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.surface,
          borderRadius: context.radius(theme.radii.md),
          border: Border.all(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: AppLinkRefTile(
          ref: ref,
          onTap: onOpenRef == null ? null : () => onOpenRef!(ref),
        ),
      ),
    );
  }

  Widget _attachment(
    BuildContext context,
    MessageAttachment attachment,
    Color fg,
  ) {
    if (attachment.kind == MessageAttachmentKind.voice) {
      return _VoiceAttachmentPlayer(
        attachment: attachment,
        fromMe: message.fromMe,
        fgColor: fg,
      );
    }
    final bool visual = attachment.kind == MessageAttachmentKind.image ||
        attachment.kind == MessageAttachmentKind.chart;
    if (visual && attachment.thumbnailUrl != null) {
      return _imageAttachment(context, attachment);
    }
    return _fileAttachment(context, attachment, fg);
  }

  Widget _imageAttachment(BuildContext context, MessageAttachment attachment) {
    final UiTheme theme = context.ui;
    return GestureDetector(
      onTap: onOpenAttachment == null
          ? null
          : () => onOpenAttachment!(attachment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: context.radius(theme.radii.md),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(
                attachment.thumbnailUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (
                  BuildContext ctx,
                  Widget child,
                  ImageChunkEvent? progress,
                ) {
                  if (progress == null) return child;
                  return _mediaFallback(context, loading: true);
                },
                errorBuilder: (BuildContext ctx, Object e, StackTrace? s) =>
                    _mediaFallback(context),
              ),
            ),
          ),
          if (attachment.subtitle != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Text(
              attachment.subtitle!,
              style: context.uiText.caption.copyWith(
                color: message.fromMe
                    ? theme.colors.onPrimary.withValues(alpha: 0.8)
                    : theme.colors.foregroundMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mediaFallback(BuildContext context, {bool loading = false}) {
    final UiColors colors = context.uiColors;
    return ColoredBox(
      color: colors.surfaceMuted,
      child: Center(
        child: loading
            ? const UiProgressCircle(size: 22, showLabel: false)
            : Icon(
                Icons.broken_image_outlined,
                color: colors.foregroundSubtle,
                size: context.sz(28),
              ),
      ),
    );
  }

  Widget _fileAttachment(
    BuildContext context,
    MessageAttachment attachment,
    Color fg,
  ) {
    final UiTheme theme = context.ui;
    final bool me = message.fromMe;
    final Color chipBg = me
        ? theme.colors.onPrimary.withValues(alpha: 0.14)
        : theme.colors.surface;
    return GestureDetector(
      onTap: onOpenAttachment == null
          ? null
          : () => onOpenAttachment!(attachment),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: context.sz(220)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: context.sz(38),
              height: context.sz(38),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: context.radius(theme.radii.sm),
              ),
              child: Icon(attachment.kind.icon, size: context.sz(18), color: fg),
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    attachment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.bodyStrong.copyWith(color: fg),
                  ),
                  Text(
                    attachment.sizeLabel ?? attachment.subtitle ?? attachment.kind.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: me
                          ? theme.colors.onPrimary.withValues(alpha: 0.75)
                          : theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _reactions(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return Wrap(
      spacing: context.sp(theme.spacing.xxs),
      children: <Widget>[
        for (final MapEntry<String, int> e in message.reactions.entries)
          _ReactionPill(
            emoji: e.key,
            count: e.value,
            mine: message.myReactions.contains(e.key),
            onTap: onReactionTap == null ? null : () => onReactionTap!(e.key),
          ),
        if (message.edited)
          Padding(
            padding: EdgeInsets.only(left: context.sp(theme.spacing.xxs)),
            child: Text(
              'edited',
              style: context.uiText.caption.copyWith(
                color: colors.foregroundSubtle,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.xs)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (message.edited && !message.hasReactions) ...<Widget>[
            Text(
              'edited',
              style: context.uiText.caption.copyWith(
                color: colors.foregroundSubtle,
                fontSize: context.fs(10),
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.xxs)),
          ],
          Text(
            _clock(message.sentAt),
            style: context.uiText.caption.copyWith(
              color: colors.foregroundSubtle,
              fontSize: context.fs(10),
            ),
          ),
          if (message.fromMe) ...<Widget>[
            SizedBox(width: context.sp(theme.spacing.xxs)),
            Icon(
              message.status.icon,
              size: context.sz(13),
              color: message.status == MessageStatus.read
                  ? colors.primary
                  : message.status == MessageStatus.failed
                  ? colors.destructive
                  : colors.foregroundSubtle,
            ),
          ],
        ],
      ),
    );
  }

  String _clock(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    final int h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final String period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:${two(dt.minute)} $period';
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.emoji,
    required this.count,
    required this.mine,
    this.onTap,
  });

  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.xs),
          vertical: context.sz(2),
        ),
        decoration: BoxDecoration(
          color: mine
              ? colors.primary.withValues(alpha: 0.12)
              : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(context.sz(999)),
          border: Border.all(
            color: mine ? colors.primary.withValues(alpha: 0.4) : colors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(emoji, style: TextStyle(fontSize: context.fs(12))),
            if (count > 1) ...<Widget>[
              SizedBox(width: context.sz(3)),
              Text(
                '$count',
                style: context.uiText.caption.copyWith(
                  color: mine ? colors.primary : colors.foregroundMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: context.fs(10.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SystemNotice extends StatelessWidget {
  const _SystemNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.xs),
          ),
          decoration: BoxDecoration(
            color: theme.colors.surfaceMuted,
            borderRadius: BorderRadius.circular(context.sz(999)),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceAttachmentPlayer extends StatefulWidget {
  const _VoiceAttachmentPlayer({
    required this.attachment,
    required this.fromMe,
    required this.fgColor,
  });

  final MessageAttachment attachment;
  final bool fromMe;
  final Color fgColor;

  @override
  State<_VoiceAttachmentPlayer> createState() => _VoiceAttachmentPlayerState();
}

class _VoiceAttachmentPlayerState extends State<_VoiceAttachmentPlayer> {
  bool _isPlaying = false;
  double _progress = 0.0;
  double _speed = 1.0;
  Timer? _timer;

  static const List<double> _waveformHeights = <double>[
    6, 10, 16, 22, 14, 8, 18, 24, 20, 12, 16, 26, 18, 14, 22, 12, 8, 20, 24, 16, 10, 18, 14, 6
  ];

  int get _totalSeconds {
    final String label = widget.attachment.sizeLabel ?? '0:12';
    final List<String> parts = label.split(':');
    if (parts.length == 2) {
      final int m = int.tryParse(parts[0]) ?? 0;
      final int s = int.tryParse(parts[1]) ?? 12;
      return (m * 60 + s).clamp(1, 600);
    }
    return 12;
  }

  void _togglePlay() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  void _play() {
    _timer?.cancel();
    setState(() => _isPlaying = true);
    final int totalSec = _totalSeconds;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _progress += (0.1 * _speed) / totalSec;
        if (_progress >= 1.0) {
          _progress = 0.0;
          _isPlaying = false;
          t.cancel();
        }
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _cycleSpeed() {
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.5;
      } else if (_speed == 1.5) {
        _speed = 2.0;
      } else {
        _speed = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color fg = widget.fgColor;
    final int currentSec = (_progress * _totalSeconds).floor();
    final String timeDisplay = _isPlaying
        ? '${_formatTime(currentSec)} / ${widget.attachment.sizeLabel ?? _formatTime(_totalSeconds)}'
        : (widget.attachment.sizeLabel ?? _formatTime(_totalSeconds));

    final Color playBtnBg = widget.fromMe
        ? theme.colors.onPrimary.withValues(alpha: 0.2)
        : theme.colors.primary.withValues(alpha: 0.12);
    final Color playIconColor = widget.fromMe
        ? theme.colors.onPrimary
        : theme.colors.primary;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: context.sz(240),
        maxWidth: context.sz(310),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xxs)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: context.sz(38),
                height: context.sz(38),
                decoration: BoxDecoration(
                  color: playBtnBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: context.sz(22),
                  color: playIconColor,
                ),
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    height: context.sz(26),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List<Widget>.generate(_waveformHeights.length, (int index) {
                        final double barFraction = (index + 1) / _waveformHeights.length;
                        final bool played = _progress >= barFraction;
                        final double h = _waveformHeights[index];
                        return Container(
                          width: context.sz(2.5),
                          height: context.sz(h),
                          decoration: BoxDecoration(
                            color: played
                                ? fg
                                : fg.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(context.sz(2)),
                          ),
                        );
                      }),
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    timeDisplay,
                    style: context.uiText.caption.copyWith(
                      color: fg.withValues(alpha: 0.8),
                      fontSize: context.fs(11),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            GestureDetector(
              onTap: _cycleSpeed,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.xxs),
                  vertical: context.sz(2),
                ),
                decoration: BoxDecoration(
                  color: playBtnBg,
                  borderRadius: BorderRadius.circular(context.sz(8)),
                ),
                child: Text(
                  '${_speed == 1.0 ? '1' : _speed.toString()}x',
                  style: context.uiText.caption.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: context.fs(10.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
