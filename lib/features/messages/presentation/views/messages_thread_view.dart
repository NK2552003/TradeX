import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/overlays/message_actions_sheet.dart';
import 'package:tradex/features/messages/presentation/overlays/message_share_chart_dialog.dart';
import 'package:tradex/features/messages/presentation/overlays/message_trade_setup_dialog.dart';
import 'package:tradex/features/messages/presentation/overlays/share_to_conversation_dialog.dart';
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
  final void Function(MessageThread thread, ChatMessage message)?
  onMessageActions;

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

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  ChatMessage? _replyingTo;

  @override
  void dispose() {
    widget.repository.removeListener(_onRepo);
    _scroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _sendText(String body) {
    widget.repository.sendMessage(
      widget.threadId,
      body: body,
      replyToId: _replyingTo?.id,
    );
    if (_replyingTo != null) {
      setState(() => _replyingTo = null);
    }
  }

  Future<void> _sendAttachment(MessageAttachmentKind kind) async {
    try {
      if (kind == MessageAttachmentKind.chart) {
        final MessageAttachment? att = await MessageShareChartDialog.show(context);
        if (att == null || !mounted) return;
        widget.repository.sendMessage(
          widget.threadId,
          attachment: att,
        );
        return;
      } else if (kind == MessageAttachmentKind.tradeSetup) {
        final MessageAttachment? att = await MessageTradeSetupDialog.show(context);
        if (att == null || !mounted) return;
        widget.repository.sendMessage(
          widget.threadId,
          attachment: att,
        );
        return;
      } else if (kind == MessageAttachmentKind.image) {
        final ImagePicker picker = ImagePicker();
        final XFile? picked = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (picked == null || !mounted) return;

        UiToastScope.maybeOf(context)?.show(
          UiToastData(
            title: 'Uploading media...',
            message: 'Uploading image to conversation',
            intent: UiIntent.info,
          ),
        );

        final Uint8List bytes = await picked.readAsBytes();
        final String publicUrl = await widget.repository.uploadAttachment(
          threadId: widget.threadId,
          bytes: bytes,
          filename: picked.name,
        );

        widget.repository.sendMessage(
          widget.threadId,
          attachment: MessageAttachment(
            id: 'att_${DateTime.now().microsecondsSinceEpoch}',
            kind: MessageAttachmentKind.image,
            title: picked.name,
            subtitle: 'Shared Photo',
            thumbnailUrl: publicUrl,
            url: publicUrl,
          ),
        );
        return;
      } else if (kind == MessageAttachmentKind.document) {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          withData: true,
        );
        if (result == null || result.files.isEmpty || !mounted) return;

        final PlatformFile pickedFile = result.files.first;
        final Uint8List? bytes = pickedFile.bytes;
        if (bytes == null) {
          throw StateError('Could not read file data');
        }

        UiToastScope.maybeOf(context)?.show(
          UiToastData(
            title: 'Uploading document...',
            message: 'Uploading ${pickedFile.name}',
            intent: UiIntent.info,
          ),
        );

        final String publicUrl = await widget.repository.uploadAttachment(
          threadId: widget.threadId,
          bytes: bytes,
          filename: pickedFile.name,
        );

        widget.repository.sendMessage(
          widget.threadId,
          attachment: MessageAttachment(
            id: 'att_${DateTime.now().microsecondsSinceEpoch}',
            kind: MessageAttachmentKind.document,
            title: pickedFile.name,
            subtitle: '${(bytes.length / 1024).toStringAsFixed(1)} KB',
            sizeLabel: '${(bytes.length / 1024).toStringAsFixed(1)} KB',
            url: publicUrl,
          ),
        );
        return;
      }
    } catch (e) {
      if (mounted) {
        UiToastScope.maybeOf(context)?.show(
          UiToastData(
            title: 'Could not send attachment',
            message: '$e',
            intent: UiIntent.danger,
          ),
        );
      }
    }
  }

  Future<void> _sendVoice(String duration, Uint8List? bytes) async {
    String? audioUrl;
    if (bytes != null && bytes.isNotEmpty) {
      try {
        final ext = kIsWeb ? 'webm' : 'm4a';
        final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
        audioUrl = await widget.repository.uploadAttachment(
          threadId: widget.threadId,
          bytes: bytes,
          filename: filename,
        );
      } catch (e) {
        debugPrint(
          '[MessagesThreadView] Voice upload failed: $e. Falling back to data URI.',
        );
        final mime = kIsWeb ? 'audio/webm' : 'audio/mp4';
        audioUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      }
    }

    widget.repository.sendMessage(
      widget.threadId,
      attachment: MessageAttachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}',
        kind: MessageAttachmentKind.voice,
        title: 'Voice Note',
        subtitle: 'Audio message ($duration)',
        sizeLabel: duration,
        url: audioUrl,
      ),
    );
  }

  void _reactToLast(String emoji) {
    final List<ChatMessage> msgs = widget.repository.messagesFor(
      widget.threadId,
    );
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

    final ChatMessage? pinned = widget.repository.pinnedMessageFor(thread.id);
    return Column(
      children: <Widget>[
        if (widget.showHeader) _header(context, thread),
        if (widget.showHeader && _isSearching) _searchBar(context, thread),
        if (pinned != null && !_isSearching)
          _pinnedMessageBanner(context, pinned),
        Expanded(
          child: Container(
            color: theme.colors.background,
            child: _messageList(context, thread),
          ),
        ),
        if (thread.isRequest)
          _buildRequestActions(context, thread)
        else
          MessageComposer(
            threadId: thread.id,
            initialDraft: thread.draft,
            replyTo: _replyingTo,
            onCancelReply: () => setState(() => _replyingTo = null),
            shareableRefs: widget.repository.shareableRefs,
            quickReactions: widget.repository.quickReactions,
            onSendText: _sendText,
            onSendAttachment: _sendAttachment,
            onSendVoice: _sendVoice,
            onSendRef: (AppLinkRef ref) =>
                widget.repository.sendSharedRef(thread.id, ref),
            onQuickReaction: _reactToLast,
            onDraftChanged: (String d) =>
                widget.repository.setDraft(thread.id, d),
          ),
      ],
    );
  }

  Widget _buildRequestActions(BuildContext context, MessageThread thread) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.sm + 2),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border, width: theme.borders.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.privacy_tip_outlined,
                  size: context.sz(16),
                  color: colors.primary,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  child: Text(
                    '${thread.peer.displayName ?? thread.peer.handle} wants to send you a message',
                    style: context.uiText.bodyStrong,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.xxs)),
            Text(
              'Do you want to let @${thread.peer.handle} send you messages? They won\'t know you\'ve seen their message until you accept.',
              style: context.uiText.caption.copyWith(
                color: colors.foregroundMuted,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 1,
                  child: UiButton(
                    label: 'Block',
                    icon: Icons.block_rounded,
                    variant: UiVariant.ghost,
                    intent: UiIntent.danger,
                    size: UiSize.sm,
                    onPressed: () {
                      widget.repository.blockTrader(thread.peer.id);
                      widget.repository.declineRequest(thread.id);
                      widget.onBack?.call();
                      UiToastScope.maybeOf(context)?.show(
                        UiToastData(
                          title: 'User Blocked',
                          message: '@${thread.peer.handle} has been blocked.',
                          intent: UiIntent.danger,
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  flex: 1,
                  child: UiButton(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    variant: UiVariant.soft,
                    intent: UiIntent.neutral,
                    size: UiSize.sm,
                    onPressed: () {
                      widget.repository.declineRequest(thread.id);
                      widget.onBack?.call();
                      UiToastScope.maybeOf(context)?.show(
                        UiToastData(
                          title: 'Request Deleted',
                          message: 'Message request removed.',
                          intent: UiIntent.neutral,
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  flex: 1,
                  child: UiButton(
                    label: 'Accept',
                    icon: Icons.check_rounded,
                    variant: UiVariant.solid,
                    intent: UiIntent.primary,
                    size: UiSize.sm,
                    onPressed: () {
                      widget.repository.acceptRequest(thread.id);
                      UiToastScope.maybeOf(context)?.show(
                        UiToastData(
                          title: 'Request Accepted',
                          message:
                              'You can now exchange messages with @${thread.peer.handle}.',
                          intent: UiIntent.success,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
          bottom: BorderSide(
            color: colors.border,
            width: theme.borders.hairline,
          ),
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
                                if (thread.peer.verified &&
                                    !thread.isGroup) ...<Widget>[
                                  SizedBox(
                                    width: context.sp(theme.spacing.xxs),
                                  ),
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
                icon: _isSearching
                    ? Icons.search_off_rounded
                    : Icons.search_rounded,
                tooltip: _isSearching
                    ? 'Close search'
                    : 'Search in conversation',
                size: UiSize.sm,
                onPressed: () => setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                }),
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

  Widget _searchBar(BuildContext context, MessageThread thread) {
    final UiTheme theme = context.ui;
    final List<ChatMessage> allMsgs = widget.repository.messagesFor(thread.id);
    final String q = _searchQuery.trim().toLowerCase();
    final int matches = q.isEmpty
        ? allMsgs.length
        : allMsgs
              .where(
                (ChatMessage m) =>
                    m.body.toLowerCase().contains(q) ||
                    (m.attachment?.title.toLowerCase().contains(q) ?? false),
              )
              .length;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xs),
      ),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: UiInput.search(
              controller: _searchController,
              hintText: 'Search in conversation…',
              autofocus: true,
              onChanged: (String val) => setState(() => _searchQuery = val),
              onClear: () => setState(() {
                _searchQuery = '';
                _searchController.clear();
              }),
            ),
          ),
          if (q.isNotEmpty) ...<Widget>[
            SizedBox(width: context.sp(theme.spacing.xs)),
            UiBadge(
              label: '$matches found',
              size: UiSize.xs,
              intent: UiIntent.primary,
              variant: UiBadgeVariant.soft,
            ),
          ],
        ],
      ),
    );
  }

  Widget _pinnedMessageBanner(BuildContext context, ChatMessage pinned) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final String text = pinned.body.isNotEmpty
        ? pinned.body
        : (pinned.attachment?.title ?? 'Pinned message');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.xs),
      ),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: colors.primary.withValues(alpha: 0.2),
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.push_pin_rounded,
            size: context.sz(14),
            color: colors.primary,
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: 'Pinned: ',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                  TextSpan(
                    text: text,
                    style: context.uiText.caption.copyWith(
                      color: colors.foreground,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          UiIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Unpin message',
            size: UiSize.xs,
            onPressed: () {
              widget.repository.togglePinMessage(widget.threadId, pinned.id);
              UiToastScope.maybeOf(context)?.show(
                UiToastData(
                  title: 'Message Unpinned',
                  message: 'Pinned message removed.',
                  intent: UiIntent.info,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _messageList(BuildContext context, MessageThread thread) {
    final UiTheme theme = context.ui;
    final List<ChatMessage> rawMsgs = widget.repository.messagesFor(thread.id);
    final String q = _searchQuery.trim().toLowerCase();
    final List<ChatMessage> msgs = q.isEmpty
        ? rawMsgs
        : rawMsgs
              .where(
                (ChatMessage m) =>
                    m.body.toLowerCase().contains(q) ||
                    (m.attachment?.title.toLowerCase().contains(q) ?? false),
              )
              .toList();

    if (q.isNotEmpty && msgs.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.search_off_rounded,
                size: context.sz(36),
                color: theme.colors.foregroundMuted,
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Text('No messages found', style: context.uiText.subheading),
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                'No results matching "$_searchQuery"',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool typing = widget.repository.isTyping(thread.id);

    // Build a flat render list with day dividers, newest last. Rendered in a
    // reverse ListView so it sticks to the latest message and grows upward.
    final List<_Row> rows = _rows(msgs, thread, typing && q.isEmpty);

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
          _ProfileHeroRow(:final MessageThread thread) => _ProfileHeroCard(
            thread: thread,
            onOpenProfile: widget.onOpenProfile,
          ),
          _GreetingHintRow(:final String message) => Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.md),
              horizontal: context.sp(theme.spacing.lg),
            ),
            child: Center(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ),
          ),
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
          _MessageRow(
            :final ChatMessage message,
            :final bool tail,
            :final String? sender,
          ) =>
            MessageBubble(
              message: message,
              senderName: sender,
              showTail: tail,
              onOpenRef: widget.onOpenRef,
              onOpenAttachment: (MessageAttachment attachment) {
                if (attachment.kind == MessageAttachmentKind.image ||
                    attachment.kind == MessageAttachmentKind.chart) {
                  showUiLightbox(
                    context,
                    imageUrls: <String>[attachment.thumbnailUrl ?? ''],
                    caption: attachment.title,
                  );
                } else {
                  UiToastScope.maybeOf(context)?.show(
                    UiToastData(
                      title: 'Opening attachment',
                      message: 'Viewing ${attachment.title}...',
                      intent: UiIntent.info,
                    ),
                  );
                }
              },
              replyMessage: message.replyToId == null
                  ? null
                  : msgs.where((m) => m.id == message.replyToId).firstOrNull,
              onLongPress: () => _showMessageActions(context, thread, message),
              onReactionTap: (String emoji) => widget.repository.toggleReaction(
                thread.id,
                message.id,
                emoji,
              ),
            ),
        };
      },
    );
  }

  List<_Row> _rows(List<ChatMessage> msgs, MessageThread thread, bool typing) {
    final List<_Row> rows = <_Row>[];
    rows.add(_ProfileHeroRow(thread: thread));
    if (msgs.isEmpty) {
      rows.add(
        _GreetingHintRow(
          title: 'Say hello',
          message:
              'Send a message or voice note to begin your conversation with ${thread.title}.',
        ),
      );
    }
    DateTime? lastDay;
    for (int i = 0; i < msgs.length; i++) {
      final ChatMessage m = msgs[i];
      final DateTime day = DateTime(
        m.sentAt.year,
        m.sentAt.month,
        m.sentAt.day,
      );
      if (lastDay == null || day != lastDay) {
        rows.add(_DividerRow(day));
        lastDay = day;
      }
      // Tail = last message of a same-sender run (drives footer + spacing).
      final ChatMessage? next = i + 1 < msgs.length ? msgs[i + 1] : null;
      final bool tail =
          next == null ||
          next.fromMe != m.fromMe ||
          next.systemNotice != m.systemNotice;
      // Group sender label: first inbound of a run, groups only.
      final ChatMessage? prev = i > 0 ? msgs[i - 1] : null;
      final bool runStart =
          prev == null || prev.fromMe != m.fromMe || prev.systemNotice;
      final String? sender =
          (thread.isGroup && !m.fromMe && runStart && !m.systemNotice)
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
    MessageActionsSheet.show(
      context,
      repository: widget.repository,
      threadId: thread.id,
      message: message,
      onReply: (ChatMessage msg) {
        setState(() => _replyingTo = msg);
      },
      onForward: (ChatMessage msg) {
        ShareToConversationDialog.forwardMessage(
          context,
          repository: widget.repository,
          message: msg,
          onForwarded: (String dstThreadId) {
            UiToastScope.maybeOf(context)?.show(
              UiToastData(title: 'Message forwarded', intent: UiIntent.success),
            );
          },
        );
      },
      onNavigateToAi: () {
        widget.onOpenRef?.call(
          const AppLinkRef(
            id: 'ai_copilot',
            kind: AppLinkKind.aiCopilot,
            title: 'AI Copilot',
            subtitle: 'Message Analysis',
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Render-row union
// ---------------------------------------------------------------------------

sealed class _Row {
  const _Row();
}

class _ProfileHeroRow extends _Row {
  const _ProfileHeroRow({required this.thread});
  final MessageThread thread;
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

class _GreetingHintRow extends _Row {
  const _GreetingHintRow({required this.title, required this.message});
  final String title;
  final String message;
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.thread, this.onOpenProfile});

  final MessageThread thread;
  final void Function(MessageThread thread)? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final AppTrader peer = thread.peer;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.lg),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              MessagesThreadAvatar(thread: thread, size: UiSize.xl),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      thread.title,
                      style: context.uiText.heading,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (peer.verified && !thread.isGroup) ...<Widget>[
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    Icon(
                      Icons.verified_rounded,
                      size: context.sz(18),
                      color: colors.primary,
                    ),
                  ],
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                thread.subtitle,
                style: context.uiText.body.copyWith(
                  color: colors.foregroundMuted,
                ),
              ),
              if (thread.isRequest) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.sm)),
                UiCallout(
                  intent: UiIntent.info,
                  icon: Icons.privacy_tip_outlined,
                  title:
                      '${peer.displayName ?? peer.handle} wants to send you a message',
                  message:
                      'Do you want to let @${peer.handle} send you messages? '
                      'They cannot see that you\'ve viewed this message until you accept.',
                ),
              ],
              if (!thread.isGroup &&
                  peer.bio != null &&
                  peer.bio!.trim().isNotEmpty) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  peer.bio!.trim(),
                  style: context.uiText.body,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: context.sp(theme.spacing.sm)),
              if (!thread.isGroup) ...<Widget>[
                Wrap(
                  spacing: context.sp(theme.spacing.xs),
                  runSpacing: context.sp(theme.spacing.xxs),
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    UiBadge(
                      label: peer.tier.name.toUpperCase(),
                      variant: UiBadgeVariant.soft,
                      intent: UiIntent.primary,
                      size: UiSize.xs,
                    ),
                    if (peer.winRate != null)
                      UiBadge(
                        label:
                            '${(peer.winRate! * 100).toStringAsFixed(0)}% Win rate',
                        variant: UiBadgeVariant.soft,
                        intent: UiIntent.success,
                        size: UiSize.xs,
                      ),
                    if (peer.tradingStyle != null &&
                        peer.tradingStyle!.isNotEmpty)
                      UiBadge(
                        label: peer.tradingStyle!,
                        variant: UiBadgeVariant.soft,
                        intent: UiIntent.neutral,
                        size: UiSize.xs,
                      ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('${peer.following}', style: context.uiText.bodyStrong),
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    Text(
                      'Following',
                      style: context.uiText.caption.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    Text('${peer.followers}', style: context.uiText.bodyStrong),
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    Text(
                      'Followers',
                      style: context.uiText.caption.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
                if (onOpenProfile != null) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.md)),
                  UiButton(
                    label: 'View profile',
                    icon: Icons.person_outline_rounded,
                    size: UiSize.sm,
                    variant: UiVariant.outline,
                    intent: UiIntent.neutral,
                    onPressed: () => onOpenProfile!(thread),
                  ),
                ],
              ],
              SizedBox(height: context.sp(theme.spacing.md)),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.lock_outline_rounded,
                    size: context.sz(12),
                    color: colors.foregroundSubtle,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  Flexible(
                    child: Text(
                      'Direct messages are stored by alphajournal. Do not share sensitive credentials.',
                      textAlign: TextAlign.center,
                      style: context.uiText.caption.copyWith(
                        color: colors.foregroundSubtle,
                        fontSize: context.fs(11),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              const UiDivider(label: 'Conversation started'),
            ],
          ),
        ),
      ),
    );
  }
}
