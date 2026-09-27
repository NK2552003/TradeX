import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/widgets/messages_widgets.dart';

/// A single open conversation: header, the message history (grouped into
/// same-sender runs and split by day), a live typing indicator and the
/// composer. Reads everything from [MessagesRepository.messagesFor]; the header
/// subtitle is the thread's own presence text. No literal content here.
class MessagesThreadView extends StatefulWidget {
  const MessagesThreadView({
    super.key,
    required this.repository,
    required this.threadId,
    this.showHeader = true,
    this.showBackButton = false,
    this.onBack,
    this.onOpenRef,
    this.onOpenInfo,
    this.onOpenProfile,
    this.onMessageActions,
  });

  final MessagesRepository repository;
  final String threadId;

  /// The embedded desktop workspace supplies its own header, so it can be hidden.
  final bool showHeader;
  final bool showBackButton;
  final VoidCallback? onBack;
  final void Function(AppLinkRef ref)? onOpenRef;
  final void Function(MessageThread thread)? onOpenInfo;
  final void Function(MessageThread thread)? onOpenProfile;

  /// Long-press on a bubble; the root wires this to the message actions sheet.
  final void Function(MessageThread thread, ChatMessage message)? onMessageActions;

  @override
  State<MessagesThreadView> createState() => _MessagesThreadViewState();
}

class _MessagesThreadViewState extends State<MessagesThreadView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepo);
    // Opening a thread clears its unread badge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.repository.markThreadRead(widget.threadId);
    });
  }

  @override
  void didUpdateWidget(covariant MessagesThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.repository != oldWidget.repository) {
      oldWidget.repository.removeListener(_onRepo);
      widget.repository.addListener(_onRepo);
    }
    if (widget.threadId != oldWidget.threadId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.repository.markThreadRead(widget.threadId);
      });
    }
  }

  void _onRepo() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepo);
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------

  void _sendText(String body) =>
      widget.repository.sendMessage(widget.threadId, body: body);

  void _sendAttachment(MessageAttachmentKind kind) {
    // A real client would open a picker; here we synthesise a representative
    // attachment for the chosen kind so the bubble variants are exercised.
    widget.repository.sendMessage(
      widget.threadId,
      attachment: MessageAttachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        title: kind.label,
        subtitle: 'Shared from your device',
        sizeLabel: kind == MessageAttachmentKind.voice ? '0:12' : null,
      ),
    );
  }

  void _reactToLast(String emoji) {
    final List<ChatMessage> msgs = widget.repository.messagesFor(widget.threadId);
    if (msgs.isEmpty) return;
    widget.repository.toggleReaction(widget.threadId, msgs.last.id, emoji);
  }

  @override
  Widget build(BuildContext context) {
    final MessageThread? thread = widget.repository.threadById(widget.threadId);
    if (thread == null) {
      return const MessagesEmptyState(
        icon: Icons.forum_outlined,
        title: 'Conversation not found',
      );
    }
    final UiTheme theme = context.ui;

    return Column(
      children: <Widget>[
        if (widget.showHeader) _header(context, thread),
        Expanded(
          child: Container(
            color: theme.colors.background,
            child: _messageList(context, thread),
          ),
        ),
        MessageComposer(
          threadId: thread.id,
          initialDraft: thread.draft,
          shareableRefs: widget.repository.shareableRefs,
          quickReactions: widget.repository.quickReactions,
          onSendText: _sendText,
          onSendAttachment: _sendAttachment,
          onSendRef: (AppLinkRef ref) =>
              widget.repository.sendSharedRef(thread.id, ref),
          onQuickReaction: _reactToLast,
          onDraftChanged: (String d) =>
              widget.repository.setDraft(thread.id, d),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------

  Widget _header(BuildContext context, MessageThread thread) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.border, width: theme.borders.hairline),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: Row(
            children: <Widget>[
              if (widget.showBackButton) ...<Widget>[
                UiIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  size: UiSize.sm,
                  onPressed: widget.onBack,
                ),
                SizedBox(width: context.sp(theme.spacing.xxs)),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: widget.onOpenProfile == null
                      ? null
                      : () => widget.onOpenProfile!(thread),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: <Widget>[
                      MessagesThreadAvatar(thread: thread, size: UiSize.sm),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    thread.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.uiText.bodyStrong,
                                  ),
                                ),
                                if (thread.peer.verified && !thread.isGroup) ...<Widget>[
                                  SizedBox(width: context.sp(theme.spacing.xxs)),
                                  Icon(
                                    Icons.verified_rounded,
                                    size: context.sz(14),
                                    color: colors.primary,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              widget.repository.isTyping(thread.id)
                                  ? 'typing…'
                                  : thread.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.uiText.caption.copyWith(
                                color: widget.repository.isTyping(thread.id)
                                    ? colors.bullish
                                    : colors.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              UiIconButton(
                icon: Icons.info_outline_rounded,
                tooltip: 'Conversation info',
                size: UiSize.sm,
                onPressed: widget.onOpenInfo == null
                    ? null
                    : () => widget.onOpenInfo!(thread),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageList(BuildContext context, MessageThread thread) {
    final UiTheme theme = context.ui;
    final List<ChatMessage> msgs =
        widget.repository.messagesFor(thread.id);
    final bool typing = widget.repository.isTyping(thread.id);

    if (msgs.isEmpty && !typing) {
      return MessagesEmptyState(
        icon: Icons.waving_hand_outlined,
        title: 'Say hello',
        message: 'This is the beginning of your conversation with '
            '${thread.title}.',
      );
    }

    // Build a flat render list with day dividers, newest last. Rendered in a
    // reverse ListView so it sticks to the latest message and grows upward.
    final List<_Row> rows = _rows(msgs, thread, typing);

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.sm),
      ),
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int i) {
        // Reverse index → chronological row.
        final _Row row = rows[rows.length - 1 - i];
        return switch (row) {
          _DividerRow(:final DateTime date) => ChatDateDivider(date: date),
          _TypingRow() => Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  top: context.sp(theme.spacing.xs),
                  bottom: context.sp(theme.spacing.sm),
                ),
                child: const UiTypingIndicator(),
              ),
            ),
          _MessageRow(:final ChatMessage message, :final bool tail, :final String? sender) =>
            MessageBubble(
              message: message,
              senderName: sender,
              showTail: tail,
              onOpenRef: widget.onOpenRef,
              onLongPress: () => _showMessageActions(context, thread, message),
              onReactionTap: (String emoji) => widget.repository
                  .toggleReaction(thread.id, message.id, emoji),
            ),
        };
      },
    );
  }

  List<_Row> _rows(
    List<ChatMessage> msgs,
    MessageThread thread,
    bool typing,
  ) {
    final List<_Row> rows = <_Row>[];
    DateTime? lastDay;
    for (int i = 0; i < msgs.length; i++) {
      final ChatMessage m = msgs[i];
      final DateTime day = DateTime(m.sentAt.year, m.sentAt.month, m.sentAt.day);
      if (lastDay == null || day != lastDay) {
        rows.add(_DividerRow(day));
        lastDay = day;
      }
      // Tail = last message of a same-sender run (drives footer + spacing).
      final ChatMessage? next = i + 1 < msgs.length ? msgs[i + 1] : null;
      final bool tail = next == null ||
          next.fromMe != m.fromMe ||
          next.systemNotice != m.systemNotice;
      // Group sender label: first inbound of a run, groups only.
      final ChatMessage? prev = i > 0 ? msgs[i - 1] : null;
      final bool runStart = prev == null ||
          prev.fromMe != m.fromMe ||
          prev.systemNotice;
      final String? sender = (thread.isGroup && !m.fromMe && runStart && !m.systemNotice)
          ? thread.peer.displayName ?? thread.peer.handle
          : null;
      rows.add(_MessageRow(message: m, tail: tail, sender: sender));
    }
    if (typing) rows.add(const _TypingRow());
    return rows;
  }

  void _showMessageActions(
    BuildContext context,
    MessageThread thread,
    ChatMessage message,
  ) {
    // Prefer the wired overlay (copy / react / reply / delete). Absent that,
    // fall back to a quick 👍 so a long-press always does something.
    if (widget.onMessageActions != null) {
      widget.onMessageActions!(thread, message);
      return;
    }
    widget.repository.toggleReaction(thread.id, message.id, '👍');
  }
}

// ---------------------------------------------------------------------------
// Render-row union
// ---------------------------------------------------------------------------

sealed class _Row {
  const _Row();
}

class _DividerRow extends _Row {
  const _DividerRow(this.date);
  final DateTime date;
}

class _MessageRow extends _Row {
  const _MessageRow({required this.message, required this.tail, this.sender});
  final ChatMessage message;
  final bool tail;
  final String? sender;
}

class _TypingRow extends _Row {
  const _TypingRow();
}
