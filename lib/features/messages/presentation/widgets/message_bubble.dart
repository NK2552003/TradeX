import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
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
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double maxWidth = screenWidth > 640
        ? 440.0
        : screenWidth * maxWidthFraction;

    return Padding(
      padding: EdgeInsets.only(
        bottom: context.sp(showTail ? theme.spacing.sm : theme.spacing.xxs),
      ),
      child: Column(
        crossAxisAlignment: me
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
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
      final String sender = replyMessage!.fromMe
          ? 'You'
          : (senderName ?? 'Trader');
      parts.add(
        Container(
          margin: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.xs),
            vertical: context.sp(theme.spacing.xxs),
          ),
          decoration: BoxDecoration(
            color: me
                ? Colors.black.withValues(alpha: 0.15)
                : colors.surfaceHover,
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
                    : (replyMessage!.sharedRef?.title ??
                          replyMessage!.attachment?.title ??
                          'Attachment'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: (me ? colors.onPrimary : colors.foreground).withValues(
                    alpha: 0.8,
                  ),
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
      parts.add(_buildMessageBodyText(context, fg, me));
    }

    // A media/record-only bubble uses tighter padding so the card fills it.
    final bool mediaOnly =
        !message.hasText &&
        (message.attachment != null || message.sharedRef != null);
    final double padH = context.sp(
      mediaOnly ? theme.spacing.xs : theme.spacing.sm,
    );
    final double padV = context.sp(
      mediaOnly ? theme.spacing.xs : theme.spacing.sm,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: _bubbleRadius(context, me),
        border: me
            ? null
            : Border.all(color: colors.border, width: theme.borders.hairline),
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

  static final RegExp _inlineTokenRegex = RegExp(
    r'(tradex://[^\s\)]+|https?://[^\s\)]+|(?<![\$\w])\$([A-Za-z\^][A-Za-z0-9\.\-\_\^\=]{0,9})\b(?!\$))',
  );

  Widget _buildMessageBodyText(BuildContext context, Color fg, bool me) {
    final TextStyle baseStyle = context.uiText.body.copyWith(
      color: fg,
      height: 1.35,
    );
    final String text = message.body;

    final Iterable<Match> matches = _inlineTokenRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final UiColors colors = context.uiColors;
    final Color linkColor = me ? colors.onPrimary : colors.primary;
    final List<InlineSpan> spans = <InlineSpan>[];
    int lastIndex = 0;

    for (final Match match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }
      final String rawToken = match.group(0)!;
      final String? tickerSymbol = match.group(2);
      spans.add(
        TextSpan(
          text: rawToken,
          style: baseStyle.copyWith(
            color: linkColor,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor: linkColor.withValues(alpha: 0.5),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (tickerSymbol != null && tickerSymbol.isNotEmpty) {
                final String sym = tickerSymbol.toUpperCase();
                onOpenRef?.call(
                  AppLinkRef(kind: AppLinkKind.ticker, id: sym, title: sym),
                );
                return;
              }
              final AppLinkRef? deepTarget = AppDeepLink.tryParseUrl(rawToken);
              if (deepTarget != null && onOpenRef != null) {
                onOpenRef!(deepTarget.copyWith(isPublicContext: true));
                return;
              }
              Clipboard.setData(ClipboardData(text: rawToken));
              UiToast.info(context, title: 'Link Copied', message: rawToken);
            },
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return Text.rich(TextSpan(children: spans), style: baseStyle);
  }

  // ---------------------------------------------------------------------------

  Widget _sharedRef(BuildContext context, AppLinkRef ref) {
    final UiTheme theme = context.ui;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: context.sz(200),
        maxWidth: context.sz(260),
      ),
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
        threadId: message.threadId,
        fromMe: message.fromMe,
        fgColor: fg,
      );
    }
    if (attachment.kind == MessageAttachmentKind.tradeSetup) {
      return _tradeSetupAttachment(context, attachment);
    }
    if (attachment.kind == MessageAttachmentKind.chart &&
        attachment.candles.isNotEmpty) {
      return _chartAttachment(context, attachment);
    }
    final bool visual =
        attachment.kind == MessageAttachmentKind.image ||
        attachment.kind == MessageAttachmentKind.chart;
    if (visual && attachment.thumbnailUrl != null) {
      return _imageAttachment(context, attachment);
    }
    return _fileAttachment(context, attachment, fg);
  }

  /// A shared trade idea: direction + entry / stop / target levels and the
  /// derived reward:risk, rendered as a self-contained surface card so it reads
  /// correctly on both incoming and outgoing (filled) bubbles.
  Widget _tradeSetupAttachment(BuildContext context, MessageAttachment a) {
    final UiTheme theme = context.ui;
    final bool isLong = (a.direction ?? 'long').toLowerCase() != 'short';
    double? rr;
    if (a.entry != null && a.stop != null && a.target != null) {
      final double risk = (a.entry! - a.stop!).abs();
      final double reward = (a.target! - a.entry!).abs();
      if (risk > 0) rr = reward / risk;
    }
    final List<UiStat> stats = <UiStat>[
      if (a.entry != null)
        UiStat(label: 'Entry', value: a.entry!.toStringAsFixed(2)),
      if (a.stop != null)
        UiStat(
          label: 'Stop',
          value: a.stop!.toStringAsFixed(2),
          intent: UiIntent.bearish,
        ),
      if (a.target != null)
        UiStat(
          label: 'Target',
          value: a.target!.toStringAsFixed(2),
          intent: UiIntent.bullish,
        ),
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: context.sz(200),
        maxWidth: context.sz(260),
      ),
      child: Container(
        padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
        decoration: BoxDecoration(
          color: theme.colors.surface,
          borderRadius: context.radius(theme.radii.md),
          border: Border.all(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  a.kind.icon,
                  size: context.sz(theme.sizes.iconSm),
                  color: theme.colors.foregroundMuted,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  child: Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.bodyStrong,
                  ),
                ),
                UiBadge(
                  label: isLong ? 'Long' : 'Short',
                  intent: isLong ? UiIntent.bullish : UiIntent.bearish,
                  size: UiSize.xs,
                ),
              ],
            ),
            if (a.subtitle != null) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                a.subtitle!,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
            if (stats.isNotEmpty) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.sm)),
              UiStatStrip(stats: stats, showSpark: false),
            ],
            if (rr != null) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.sm)),
              UiBadge(
                label: 'R:R ${rr.toStringAsFixed(2)}',
                icon: Icons.balance_rounded,
                intent: UiIntent.info,
                size: UiSize.xs,
              ),
            ],
            if (a.note != null && a.note!.isNotEmpty) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xs)),
              Text(
                a.note!,
                style: context.uiText.caption.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chartAttachment(BuildContext context, MessageAttachment a) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    final double lastClose = a.candles.isNotEmpty ? a.candles.last.close : 0.0;
    final double firstOpen = a.candles.isNotEmpty ? a.candles.first.open : 0.0;
    final double changePct = firstOpen > 0 ? ((lastClose - firstOpen) / firstOpen) * 100 : 0.0;
    final bool isBullish = changePct >= 0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: context.sz(260),
        maxWidth: context.sz(350),
      ),
      child: Container(
        padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
        decoration: BoxDecoration(
          color: theme.colors.surface,
          borderRadius: context.radius(theme.radii.md),
          border: Border.all(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.candlestick_chart_rounded,
                  size: context.sz(18),
                  color: isBullish ? colors.success : colors.destructive,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  child: Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.bodyStrong.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (a.timeframe != null) ...<Widget>[
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  UiBadge(
                    label: a.timeframe!,
                    variant: UiBadgeVariant.soft,
                    intent: UiIntent.info,
                    size: UiSize.xs,
                  ),
                ],
              ],
            ),
            if (a.subtitle != null && a.subtitle!.isNotEmpty) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                a.subtitle!,
                style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
              ),
            ],
            SizedBox(height: context.sp(theme.spacing.xs)),
            Container(
              decoration: BoxDecoration(
                borderRadius: context.radius(theme.radii.sm),
                color: colors.surfaceMuted.withValues(alpha: 0.5),
              ),
              child: ClipRRect(
                borderRadius: context.radius(theme.radii.sm),
                child: UiCandleChart(
                  candles: a.candles,
                  height: 120,
                  showVolume: false,
                  interactive: false,
                ),
              ),
            ),
            if (a.note != null && a.note!.isNotEmpty) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xs)),
              Text(
                a.note!,
                style: context.uiText.caption.copyWith(
                  color: colors.foreground,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _imageAttachment(BuildContext context, MessageAttachment attachment) {
    final UiTheme theme = context.ui;
    if (attachment.isSignedUrlExpired) {
      unawaited(
        MessagesRepositoryScope.repository.resolveAttachmentUrl(
          attachment,
          threadId: message.threadId,
          forceRefresh: true,
        ),
      );
    }
    return GestureDetector(
      onTap: onOpenAttachment == null
          ? null
          : () => onOpenAttachment!(attachment),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.sz(260),
          maxHeight: context.sz(180),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: context.radius(theme.radii.md),
              child: SizedBox(
                width: context.sz(260),
                height: context.sz(140),
                child: Builder(
                  builder: (BuildContext imgCtx) {
                    final int? cacheW = UiRemoteImage.resolveCacheWidth(
                      imgCtx,
                      logicalWidth: imgCtx.sz(260),
                    );
                    return Image(
                      image: ResizeImage.resizeIfNeeded(
                        cacheW,
                        null,
                        NetworkImage(
                          UiRemoteImage.resizeImageUrl(
                            attachment.thumbnailUrl!,
                            targetWidthPx: cacheW,
                          ),
                        ),
                      ),
                      fit: BoxFit.cover,
                  loadingBuilder:
                      (
                        BuildContext ctx,
                        Widget child,
                        ImageChunkEvent? progress,
                      ) {
                        if (progress == null) return child;
                        return _mediaFallback(context, loading: true);
                      },
                  errorBuilder: (BuildContext ctx, Object e, StackTrace? s) {
                    if (attachment.storagePath != null) {
                      unawaited(
                        MessagesRepositoryScope.repository.resolveAttachmentUrl(
                          attachment,
                          threadId: message.threadId,
                          forceRefresh: true,
                        ),
                      );
                    }
                    return _mediaFallback(context);
                  },
                    );
                  },
                ),
              ),
            ),
            if (attachment.subtitle != null) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                attachment.subtitle!,
                style: context.uiText.caption.copyWith(
                  color: message.fromMe
                      ? theme.colors.onPrimary.withValues(alpha: 0.8)
                      : theme.colors.foregroundMuted,
                  fontSize: context.fs(11),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
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
        constraints: BoxConstraints(
          minWidth: context.sz(200),
          maxWidth: context.sz(260),
        ),
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
              child: Icon(
                attachment.kind.icon,
                size: context.sz(18),
                color: fg,
              ),
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
                    attachment.sizeLabel ??
                        attachment.subtitle ??
                        attachment.kind.label,
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
    required this.threadId,
    required this.fromMe,
    required this.fgColor,
  });

  final MessageAttachment attachment;
  final String threadId;
  final bool fromMe;
  final Color fgColor;

  @override
  State<_VoiceAttachmentPlayer> createState() => _VoiceAttachmentPlayerState();
}

class _VoiceAttachmentPlayerState extends State<_VoiceAttachmentPlayer> {
  AudioPlayer? _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<PlayerState>? _stateSub;
  bool _isPlaying = false;
  double _progress = 0.0;
  double _speed = 1.0;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Timer? _timer;

  static const List<double> _waveformHeights = <double>[
    6,
    10,
    16,
    22,
    14,
    8,
    18,
    24,
    20,
    12,
    16,
    26,
    18,
    14,
    22,
    12,
    8,
    20,
    24,
    16,
    10,
    18,
    14,
    6,
  ];

  int get _totalSeconds {
    if (_duration > Duration.zero) return _duration.inSeconds;
    final String raw =
        widget.attachment.sizeLabel ?? widget.attachment.subtitle ?? '0:12';
    final match = RegExp(r'(\d+):(\d+)').firstMatch(raw);
    if (match != null) {
      final int m = int.tryParse(match.group(1)!) ?? 0;
      final int s = int.tryParse(match.group(2)!) ?? 12;
      return (m * 60 + s).clamp(1, 600);
    }
    return 12;
  }

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    final String? url = widget.attachment.url;
    if (url != null && url.isNotEmpty) {
      _player = AudioPlayer();
      _posSub = _player!.onPositionChanged.listen((Duration pos) {
        if (!mounted) return;
        setState(() {
          _position = pos;
          if (_duration.inMilliseconds > 0) {
            _progress = (pos.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
          }
        });
      });
      _durSub = _player!.onDurationChanged.listen((Duration dur) {
        if (!mounted) return;
        setState(() => _duration = dur);
      });
      _completeSub = _player!.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _progress = 0.0;
          _position = Duration.zero;
        });
      });
      _stateSub = _player!.onPlayerStateChanged.listen((PlayerState state) {
        if (!mounted) return;
        final playing = state == PlayerState.playing;
        if (_isPlaying != playing) {
          setState(() => _isPlaying = playing);
        }
      });
    }
  }

  Future<void> _togglePlay() async {
    HapticFeedback.selectionClick();
    if (_isPlaying) {
      await _pause();
    } else {
      await _play();
    }
  }

  Future<void> _play() async {
    String? url = widget.attachment.url;
    if (widget.attachment.isSignedUrlExpired ||
        (url == null && widget.attachment.storagePath != null)) {
      try {
        url = await MessagesRepositoryScope.repository.resolveAttachmentUrl(
          widget.attachment,
          threadId: widget.threadId,
          forceRefresh: true,
        );
      } catch (_) {}
    }
    if (url != null && url.isNotEmpty) {
      try {
        _player ??= AudioPlayer();
        if (_posSub == null) _initAudioPlayer();
        if (_position >= _duration && _duration > Duration.zero) {
          await _player!.seek(Duration.zero);
        }
        if (url.startsWith('http://') || url.startsWith('https://')) {
          await _player!.play(UrlSource(url));
        } else if (url.startsWith('data:')) {
          final data = url.contains(',') ? url.split(',').last : url;
          await _player!.play(BytesSource(base64Decode(data)));
        } else {
          await _player!.play(DeviceFileSource(url));
        }
        await _player!.setPlaybackRate(_speed);
        if (mounted) setState(() => _isPlaying = true);
        return;
      } catch (e) {
        if (widget.attachment.storagePath != null) {
          try {
            final refreshed = await MessagesRepositoryScope.repository
                .resolveAttachmentUrl(
                  widget.attachment,
                  threadId: widget.threadId,
                  forceRefresh: true,
                );
            if (refreshed != null && refreshed.isNotEmpty) {
              await _player!.play(UrlSource(refreshed));
              await _player!.setPlaybackRate(_speed);
              if (mounted) setState(() => _isPlaying = true);
              return;
            }
          } catch (_) {}
        }
        debugPrint('[VoiceAttachmentPlayer] Real audio playback error: $e. Falling back to timer.');
      }
    }

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

  Future<void> _pause() async {
    _timer?.cancel();
    try {
      if (_player != null) {
        await _player!.pause();
      }
    } catch (_) {}
    if (mounted) setState(() => _isPlaying = false);
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_speed == 1.0) {
        _speed = 1.5;
      } else if (_speed == 1.5) {
        _speed = 2.0;
      } else {
        _speed = 1.0;
      }
    });
    try {
      _player?.setPlaybackRate(_speed);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _stateSub?.cancel();
    _player?.dispose();
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
    final int currentSec = (_duration > Duration.zero)
        ? _position.inSeconds
        : (_progress * _totalSeconds).floor();
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
                      children: List<Widget>.generate(_waveformHeights.length, (
                        int index,
                      ) {
                        final double barFraction =
                            (index + 1) / _waveformHeights.length;
                        final bool played = _progress >= barFraction;
                        final double h = _waveformHeights[index];
                        return Container(
                          width: context.sz(2.5),
                          height: context.sz(h),
                          decoration: BoxDecoration(
                            color: played ? fg : fg.withValues(alpha: 0.35),
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
