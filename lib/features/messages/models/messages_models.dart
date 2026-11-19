import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

/// Domain models for the Messages feature.
///
/// Peers reuse the shared [AppTrader] identity so a conversation, a community
/// profile and a leaderboard row all describe the same person. Nothing in here
/// holds seed content — the strings live in `data/messages_seed_data.dart`.

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Live availability of the person behind a thread.
enum MessagePresence {
  online,
  away,
  busy,
  offline;

  String get label => switch (this) {
    MessagePresence.online => 'Online',
    MessagePresence.away => 'Away',
    MessagePresence.busy => 'Do not disturb',
    MessagePresence.offline => 'Offline',
  };

  /// The dot colour, resolved against the active theme.
  Color color(BuildContext context) {
    final UiColors c = context.uiColors;
    return switch (this) {
      MessagePresence.online => c.bullish,
      MessagePresence.away => c.warning,
      MessagePresence.busy => c.destructive,
      MessagePresence.offline => c.foregroundSubtle,
    };
  }

  bool get isLive =>
      this == MessagePresence.online || this == MessagePresence.busy;
}

/// Delivery state of an outgoing message, mirrored from a real transport.
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed;

  IconData get icon => switch (this) {
    MessageStatus.sending => Icons.schedule_rounded,
    MessageStatus.sent => Icons.check_rounded,
    MessageStatus.delivered => Icons.done_all_rounded,
    MessageStatus.read => Icons.done_all_rounded,
    MessageStatus.failed => Icons.error_outline_rounded,
  };
}

/// Inbox segmentation shown as filter chips.
enum ThreadFilter {
  all,
  unread,
  direct,
  groups,
  requests;

  String get label => switch (this) {
    ThreadFilter.all => 'All',
    ThreadFilter.unread => 'Unread',
    ThreadFilter.direct => 'Direct',
    ThreadFilter.groups => 'Groups',
    ThreadFilter.requests => 'Requests',
  };

  IconData get icon => switch (this) {
    ThreadFilter.all => Icons.forum_outlined,
    ThreadFilter.unread => Icons.mark_chat_unread_outlined,
    ThreadFilter.direct => Icons.person_outline_rounded,
    ThreadFilter.groups => Icons.groups_outlined,
    ThreadFilter.requests => Icons.mail_outline_rounded,
  };
}

/// What a message carries beyond plain text.
enum MessageAttachmentKind {
  image,
  chart,
  document,
  tradeSetup,
  voice;

  IconData get icon => switch (this) {
    MessageAttachmentKind.image => Icons.image_outlined,
    MessageAttachmentKind.chart => Icons.candlestick_chart_outlined,
    MessageAttachmentKind.document => Icons.description_outlined,
    MessageAttachmentKind.tradeSetup => Icons.trending_up_rounded,
    MessageAttachmentKind.voice => Icons.mic_none_rounded,
  };

  String get label => switch (this) {
    MessageAttachmentKind.image => 'Photo',
    MessageAttachmentKind.chart => 'Chart',
    MessageAttachmentKind.document => 'Document',
    MessageAttachmentKind.tradeSetup => 'Trade setup',
    MessageAttachmentKind.voice => 'Voice note',
  };
}

// ---------------------------------------------------------------------------
// Attachment
// ---------------------------------------------------------------------------

@immutable
class MessageAttachment {
  const MessageAttachment({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.url,
    this.thumbnailUrl,
    this.storagePath,
    this.signedUrlExpiresAt,
    this.sizeLabel,
    this.direction,
    this.entry,
    this.stop,
    this.target,
    this.candles = const <UiCandle>[],
    this.chartType,
    this.timeframe,
    this.note,
  });

  final String id;
  final MessageAttachmentKind kind;
  final String title;
  final String? subtitle;
  final String? url;
  final String? thumbnailUrl;

  /// Canonical private object key in `chat-attachments`:
  /// `<thread_id>/<uploader_id>/<generated_filename>`.
  final String? storagePath;

  /// Expiration timestamp for the currently resolved short-lived signed URL.
  final DateTime? signedUrlExpiresAt;

  final String? sizeLabel;

  /// Trade-setup levels, only set when [kind] is [MessageAttachmentKind.tradeSetup].
  /// [direction] is 'long' or 'short'; the reward:risk is derived from the three
  /// price levels when all are present.
  final String? direction;
  final double? entry;
  final double? stop;
  final double? target;

  /// Interactive financial chart fields, used when [kind] is [MessageAttachmentKind.chart]
  /// or when [kind] is [MessageAttachmentKind.tradeSetup] with attached candles.
  final List<UiCandle> candles;
  final String? chartType;
  final String? timeframe;
  final String? note;

  bool get isSignedUrlExpired =>
      signedUrlExpiresAt != null &&
      DateTime.now().isAfter(
        signedUrlExpiresAt!.subtract(const Duration(seconds: 15)),
      );

  MessageAttachment copyWith({
    String? id,
    MessageAttachmentKind? kind,
    String? title,
    String? subtitle,
    String? url,
    String? thumbnailUrl,
    String? storagePath,
    DateTime? signedUrlExpiresAt,
    String? sizeLabel,
    String? direction,
    double? entry,
    double? stop,
    double? target,
    List<UiCandle>? candles,
    String? chartType,
    String? timeframe,
    String? note,
  }) => MessageAttachment(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    url: url ?? this.url,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    storagePath: storagePath ?? this.storagePath,
    signedUrlExpiresAt: signedUrlExpiresAt ?? this.signedUrlExpiresAt,
    sizeLabel: sizeLabel ?? this.sizeLabel,
    direction: direction ?? this.direction,
    entry: entry ?? this.entry,
    stop: stop ?? this.stop,
    target: target ?? this.target,
    candles: candles ?? this.candles,
    chartType: chartType ?? this.chartType,
    timeframe: timeframe ?? this.timeframe,
    note: note ?? this.note,
  );
}

// ---------------------------------------------------------------------------
// Message
// ---------------------------------------------------------------------------

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.body,
    required this.fromMe,
    required this.sentAt,
    this.status = MessageStatus.sent,
    this.attachment,
    this.sharedRef,
    this.reactions = const <String, int>{},
    this.myReactions = const <String>{},
    this.replyToId,
    this.edited = false,
    this.systemNotice = false,
  });

  final String id;
  final String threadId;
  final String body;

  /// True when the signed-in trader sent it (right-aligned bubble).
  final bool fromMe;
  final DateTime sentAt;
  final MessageStatus status;

  final MessageAttachment? attachment;

  /// A shared Writing-Desk record (note / journal / strategy / ticker) rendered
  /// as a tappable card that opens in its home feature.
  final AppLinkRef? sharedRef;

  /// Emoji → count across everyone in the thread.
  final Map<String, int> reactions;

  /// Emoji the signed-in trader personally added (drives the toggle state).
  final Set<String> myReactions;

  final String? replyToId;
  final bool edited;

  /// Centered grey system line ("You accepted the request.").
  final bool systemNotice;

  bool get hasReactions => reactions.isNotEmpty;
  bool get hasText => body.trim().isNotEmpty;

  ChatMessage copyWith({
    String? body,
    MessageStatus? status,
    MessageAttachment? attachment,
    AppLinkRef? sharedRef,
    Map<String, int>? reactions,
    Set<String>? myReactions,
    bool? edited,
  }) => ChatMessage(
    id: id,
    threadId: threadId,
    body: body ?? this.body,
    fromMe: fromMe,
    sentAt: sentAt,
    status: status ?? this.status,
    attachment: attachment ?? this.attachment,
    sharedRef: sharedRef ?? this.sharedRef,
    reactions: reactions ?? this.reactions,
    myReactions: myReactions ?? this.myReactions,
    replyToId: replyToId,
    edited: edited ?? this.edited,
    systemNotice: systemNotice,
  );
}

// ---------------------------------------------------------------------------
// Thread
// ---------------------------------------------------------------------------

@immutable
class MessageThread {
  const MessageThread({
    required this.id,
    required this.peer,
    this.participants = const <AppTrader>[],
    this.isGroup = false,
    this.groupTitle,
    this.groupAvatarUrl,
    this.presence = MessagePresence.offline,
    this.lastMessagePreview = '',
    required this.lastMessageAt,
    this.unread = 0,
    this.pinned = false,
    this.muted = false,
    this.archived = false,
    this.isRequest = false,
    this.draft = '',
    this.typing = false,
    this.lastFromMe = false,
    this.lastStatus = MessageStatus.read,
  });

  final String id;

  /// The other party for a direct message; for a group this is the most recent
  /// speaker, used only as a fallback avatar/name.
  final AppTrader peer;
  final List<AppTrader> participants;
  final bool isGroup;
  final String? groupTitle;
  final String? groupAvatarUrl;

  final MessagePresence presence;
  final String lastMessagePreview;
  final DateTime lastMessageAt;
  final int unread;
  final bool pinned;
  final bool muted;
  final bool archived;

  /// A message request from someone the trader has not talked to before.
  final bool isRequest;

  /// Locally-composed but unsent text, restored when the thread reopens.
  final String draft;
  final bool typing;

  /// Whether the last message was outgoing, so the inbox can show a ✓✓ tick.
  final bool lastFromMe;
  final MessageStatus lastStatus;

  String get title => isGroup
      ? (groupTitle ?? 'Group')
      : (peer.displayName ?? '@${peer.handle}');

  String? get avatarUrl => isGroup ? groupAvatarUrl : peer.avatarUrl;

  String get subtitle =>
      isGroup ? '${participants.length} members' : '@${peer.handle}';

  bool get hasUnread => unread > 0;

  MessageThread copyWith({
    MessagePresence? presence,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    int? unread,
    bool? pinned,
    bool? muted,
    bool? archived,
    bool? isRequest,
    String? draft,
    bool? typing,
    bool? lastFromMe,
    MessageStatus? lastStatus,
    String? groupTitle,
    String? groupAvatarUrl,
    List<AppTrader>? participants,
    bool? isGroup,
  }) => MessageThread(
    id: id,
    peer: peer,
    participants: participants ?? this.participants,
    isGroup: isGroup ?? this.isGroup,
    groupTitle: groupTitle ?? this.groupTitle,
    groupAvatarUrl: groupAvatarUrl ?? this.groupAvatarUrl,
    presence: presence ?? this.presence,
    lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    unread: unread ?? this.unread,
    pinned: pinned ?? this.pinned,
    muted: muted ?? this.muted,
    archived: archived ?? this.archived,
    isRequest: isRequest ?? this.isRequest,
    draft: draft ?? this.draft,
    typing: typing ?? this.typing,
    lastFromMe: lastFromMe ?? this.lastFromMe,
    lastStatus: lastStatus ?? this.lastStatus,
  );
}
