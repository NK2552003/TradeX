import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_seed_data.dart';
import 'package:tradex/features/messages/models/messages_models.dart';

/// Reactive store for the Messages feature.
///
/// A plain [ChangeNotifier] — views `addListener`/`removeListener` and rebuild.
/// State is seeded once from [MessagesSeed]; every mutation is local and
/// optimistic, with a simulated peer reply so the thread feels alive. Each
/// mutation documents the backend call it stands in for.
class MessagesRepository extends ChangeNotifier {
  MessagesRepository() {
    _threads = MessagesSeed.threads();
    _requests = MessagesSeed.requests();
    _messages = MessagesSeed.messagesByThread();
  }

  /// Global singleton instance so messages can be opened or sent from any feature.
  static final MessagesRepository instance = MessagesRepository();

  late List<MessageThread> _threads;
  late List<MessageThread> _requests;
  late Map<String, List<ChatMessage>> _messages;
  final Set<String> _typing = <String>{};
  final List<Timer> _pending = <Timer>[];
  final Map<String, String> _pinnedMessages = <String, String>{};

  final Random _rng = Random(7);

  static const List<String> _autoReplies = <String>[
    'Got it — thanks for sharing 🙏',
    'On it. Give me a few minutes to look.',
    'Solid. That lines up with what I am seeing.',
    'Nice one. Let us review it after the close.',
    'Appreciate it. Adding this to my notes now.',
    'Good call. I will mirror that in my rules.',
  ];

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Active (non-archived) threads, pinned first then most-recent.
  List<MessageThread> get threads {
    final List<MessageThread> live =
        _threads.where((MessageThread t) => !t.archived).toList()
          ..sort(_byPinnedThenRecency);
    return live;
  }

  List<MessageThread> get archivedThreads =>
      _threads.where((MessageThread t) => t.archived).toList()
        ..sort(_byPinnedThenRecency);

  List<MessageThread> get requests => List<MessageThread>.unmodifiable(_requests);

  /// Total unread across active threads + pending requests, for the nav badge.
  int get unreadCount =>
      threads.fold<int>(0, (int sum, MessageThread t) => sum + t.unread) +
      _requests.fold<int>(0, (int sum, MessageThread t) => sum + t.unread);

  int get requestCount => _requests.length;

  bool isTyping(String threadId) => _typing.contains(threadId);

  MessageThread? threadById(String id) {
    for (final MessageThread t in _threads) {
      if (t.id == id) return t;
    }
    for (final MessageThread t in _requests) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<ChatMessage> messagesFor(String threadId) =>
      List<ChatMessage>.unmodifiable(_messages[threadId] ?? const <ChatMessage>[]);

  String? pinnedMessageId(String threadId) => _pinnedMessages[threadId];

  ChatMessage? pinnedMessageFor(String threadId) {
    final String? msgId = _pinnedMessages[threadId];
    if (msgId == null) return null;
    final List<ChatMessage> list = messagesFor(threadId);
    return list.where((ChatMessage m) => m.id == msgId).firstOrNull;
  }

  void togglePinMessage(String threadId, String messageId) {
    if (_pinnedMessages[threadId] == messageId) {
      _pinnedMessages.remove(threadId);
    } else {
      _pinnedMessages[threadId] = messageId;
    }
    notifyListeners();
  }

  /// Records the composer can attach.
  List<AppLinkRef> get shareableRefs => MessagesSeed.shareableRefs();

  /// Emoji offered in the composer's quick-reaction row.
  List<String> get quickReactions => MessagesSeed.quickReactions;

  /// Applies the inbox [filter] then a free-text [query] over title + preview.
  List<MessageThread> filtered(ThreadFilter filter, String query) {
    Iterable<MessageThread> base = switch (filter) {
      ThreadFilter.requests => _requests,
      _ => threads,
    };
    base = switch (filter) {
      ThreadFilter.unread => base.where((MessageThread t) => t.hasUnread),
      ThreadFilter.direct => base.where((MessageThread t) => !t.isGroup),
      ThreadFilter.groups => base.where((MessageThread t) => t.isGroup),
      _ => base,
    };
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return base.toList();
    return base
        .where(
          (MessageThread t) =>
              t.title.toLowerCase().contains(q) ||
              t.lastMessagePreview.toLowerCase().contains(q) ||
              t.peer.handle.toLowerCase().contains(q),
        )
        .toList();
  }

  int _byPinnedThenRecency(MessageThread a, MessageThread b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.lastMessageAt.compareTo(a.lastMessageAt);
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Sends a message. Optimistically appended as [MessageStatus.sending], then
  /// advanced to delivered/read; a peer auto-reply follows on direct threads.
  ///
  /// @backend POST /threads/{id}/messages then stream status + inbound replies.
  void sendMessage(
    String threadId, {
    String body = '',
    MessageAttachment? attachment,
    AppLinkRef? sharedRef,
    String? replyToId,
  }) {
    if (body.trim().isEmpty && attachment == null && sharedRef == null) return;
    final ChatMessage message = ChatMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      threadId: threadId,
      body: body.trim(),
      fromMe: true,
      sentAt: DateTime.now(),
      status: MessageStatus.sending,
      attachment: attachment,
      sharedRef: sharedRef,
      replyToId: replyToId,
    );
    _messages.putIfAbsent(threadId, () => <ChatMessage>[]).add(message);
    _touchThread(
      threadId,
      preview: _previewFor(message),
      fromMe: true,
      status: MessageStatus.sending,
      clearDraft: true,
    );
    notifyListeners();

    // Simulated transport: sending → sent → delivered, then a peer reply.
    _after(const Duration(milliseconds: 350), () {
      _setStatus(threadId, message.id, MessageStatus.sent);
    });
    _after(const Duration(milliseconds: 900), () {
      _setStatus(threadId, message.id, MessageStatus.delivered);
    });

    final MessageThread? thread = threadById(threadId);
    if (thread != null && !thread.isGroup && !thread.isRequest) {
      _simulatePeerReply(threadId);
    }
  }

  /// Convenience wrapper used by the share-to-conversation flow.
  ///
  /// @backend POST /threads/{id}/messages with an entity reference payload.
  void sendSharedRef(String threadId, AppLinkRef ref, {String note = ''}) =>
      sendMessage(threadId, body: note, sharedRef: ref);

  /// Marks every message in a thread read and clears its unread badge.
  ///
  /// @backend POST /threads/{id}/read { upTo: `messageId` }.
  void markThreadRead(String threadId) {
    final int idx = _threads.indexWhere((MessageThread t) => t.id == threadId);
    if (idx == -1 || _threads[idx].unread == 0) return;
    _threads[idx] = _threads[idx].copyWith(unread: 0);
    notifyListeners();
  }

  /// Toggles a per-message emoji reaction for the signed-in trader.
  ///
  /// @backend PUT/DELETE /messages/{id}/reactions/{emoji}.
  void toggleReaction(String threadId, String messageId, String emoji) {
    final List<ChatMessage>? list = _messages[threadId];
    if (list == null) return;
    final int i = list.indexWhere((ChatMessage m) => m.id == messageId);
    if (i == -1) return;
    final ChatMessage m = list[i];
    final Map<String, int> counts = Map<String, int>.of(m.reactions);
    final Set<String> mine = Set<String>.of(m.myReactions);
    if (mine.contains(emoji)) {
      mine.remove(emoji);
      final int next = (counts[emoji] ?? 1) - 1;
      if (next <= 0) {
        counts.remove(emoji);
      } else {
        counts[emoji] = next;
      }
    } else {
      mine.add(emoji);
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    list[i] = m.copyWith(reactions: counts, myReactions: mine);
    notifyListeners();
  }

  /// Edits the body of an existing message.
  ///
  /// @backend PATCH /messages/{id} { body }.
  void editMessage(String threadId, String messageId, String newBody) {
    final List<ChatMessage>? list = _messages[threadId];
    if (list == null) return;
    final int i = list.indexWhere((ChatMessage m) => m.id == messageId);
    if (i == -1) return;
    final ChatMessage m = list[i];
    final String clean = newBody.trim();
    if (clean.isEmpty || clean == m.body) return;
    list[i] = m.copyWith(body: clean, edited: true);
    if (i == list.length - 1) {
      _touchThread(
        threadId,
        preview: clean,
        fromMe: m.fromMe,
        status: m.status,
        at: m.sentAt,
      );
    }
    notifyListeners();
  }

  /// Removes a message the trader sent.
  ///
  /// @backend DELETE /messages/{id}.
  void deleteMessage(String threadId, String messageId) {
    final List<ChatMessage>? list = _messages[threadId];
    if (list == null) return;
    list.removeWhere((ChatMessage m) => m.id == messageId);
    final ChatMessage? last = list.isEmpty ? null : list.last;
    if (last != null) {
      _touchThread(
        threadId,
        preview: _previewFor(last),
        fromMe: last.fromMe,
        status: last.status,
        at: last.sentAt,
      );
    }
    notifyListeners();
  }

  /// Starts (or reopens) a direct thread with [peer] and returns its id.
  ///
  /// @backend POST /threads { participantId }.
  String startConversation(AppTrader peer) {
    final int existing = _threads.indexWhere(
      (MessageThread t) => !t.isGroup && t.peer.id == peer.id,
    );
    if (existing != -1) {
      if (_threads[existing].archived) {
        _threads[existing] = _threads[existing].copyWith(archived: false);
        notifyListeners();
      }
      return _threads[existing].id;
    }
    final String id = 'thread_new_${DateTime.now().millisecondsSinceEpoch}';
    _threads.insert(
      0,
      MessageThread(
        id: id,
        peer: peer,
        presence: MessagePresence.online,
        lastMessagePreview: 'Say hi to ${peer.displayName ?? peer.handle} 👋',
        lastMessageAt: DateTime.now(),
      ),
    );
    _messages[id] = <ChatMessage>[];
    notifyListeners();
    return id;
  }

  /// Starts or opens a group conversation with multiple [participants].
  ///
  /// @backend POST /threads/group { title, participantIds }
  String startGroupConversation({
    required String title,
    required List<AppTrader> participants,
  }) {
    final String id = 'thread_grp_${DateTime.now().millisecondsSinceEpoch}';
    final AppTrader dummyPeer = participants.isNotEmpty
        ? participants.first
        : const AppTrader(id: 'group', handle: 'group', displayName: 'Group');
    final MessageThread thread = MessageThread(
      id: id,
      peer: dummyPeer,
      groupTitle: title,
      isGroup: true,
      participants: participants,
      lastMessagePreview: 'Group created with ${participants.length} traders',
      lastMessageAt: DateTime.now(),
    );
    _threads.insert(0, thread);
    _messages[id] = <ChatMessage>[
      ChatMessage(
        id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
        threadId: id,
        body: 'You created group "$title" with ${participants.length} members.',
        fromMe: true,
        sentAt: DateTime.now(),
        systemNotice: true,
      ),
    ];
    notifyListeners();
    return id;
  }

  /// @backend PATCH /threads/{id} { pinned }.
  void togglePin(String threadId) => _mutateThread(
    threadId,
    (MessageThread t) => t.copyWith(pinned: !t.pinned),
  );

  /// @backend PATCH /threads/{id} { muted }.
  void toggleMute(String threadId) => _mutateThread(
    threadId,
    (MessageThread t) => t.copyWith(muted: !t.muted),
  );

  /// @backend PATCH /threads/{id} { archived }.
  void toggleArchive(String threadId) => _mutateThread(
    threadId,
    (MessageThread t) => t.copyWith(archived: !t.archived),
  );

  /// Accepts a message request, promoting it into the main inbox.
  ///
  /// @backend POST /requests/{id}/accept.
  String acceptRequest(String requestId) {
    final int i = _requests.indexWhere((MessageThread t) => t.id == requestId);
    if (i == -1) return requestId;
    final MessageThread promoted = _requests.removeAt(i).copyWith(
      isRequest: false,
      unread: 0,
    );
    _threads.insert(0, promoted);
    // Fold in a system notice so the transition is visible in the thread.
    _messages.putIfAbsent(promoted.id, () => <ChatMessage>[]).add(
      ChatMessage(
        id: '${promoted.id}_sys',
        threadId: promoted.id,
        body: 'You accepted the message request.',
        fromMe: false,
        sentAt: DateTime.now(),
        systemNotice: true,
      ),
    );
    notifyListeners();
    return promoted.id;
  }

  /// @backend POST /requests/{id}/decline.
  void declineRequest(String requestId) {
    _requests.removeWhere((MessageThread t) => t.id == requestId);
    notifyListeners();
  }

  /// @backend DELETE /requests.
  void declineAllRequests() {
    _requests.clear();
    notifyListeners();
  }

  /// Deletes a conversation thread completely.
  ///
  /// @backend DELETE /threads/{id}.
  void deleteThread(String threadId) {
    _threads.removeWhere((MessageThread t) => t.id == threadId);
    _requests.removeWhere((MessageThread t) => t.id == threadId);
    _messages.remove(threadId);
    notifyListeners();
  }

  /// Clears all messages in a conversation without removing the thread.
  ///
  /// @backend DELETE /threads/{id}/messages.
  void clearThreadMessages(String threadId) {
    _messages[threadId]?.clear();
    _touchThread(
      threadId,
      preview: 'No messages',
      fromMe: false,
      status: MessageStatus.read,
      clearDraft: true,
    );
    notifyListeners();
  }

  /// Renames a group conversation.
  ///
  /// @backend PATCH /threads/{id} { groupTitle }.
  void renameGroup(String threadId, String newTitle) {
    final String clean = newTitle.trim();
    if (clean.isEmpty) return;
    _mutateThread(
      threadId,
      (MessageThread t) => t.copyWith(groupTitle: clean),
    );
    _messages.putIfAbsent(threadId, () => <ChatMessage>[]).add(
      ChatMessage(
        id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
        threadId: threadId,
        body: 'Group name changed to "$clean".',
        fromMe: true,
        sentAt: DateTime.now(),
        systemNotice: true,
      ),
    );
    notifyListeners();
  }

  /// Adds a participant to a group conversation.
  ///
  /// @backend POST /threads/{id}/participants { traderId }.
  void addParticipant(String threadId, AppTrader trader) {
    final int idx = _threads.indexWhere((MessageThread t) => t.id == threadId);
    if (idx == -1) return;
    final MessageThread thread = _threads[idx];
    if (thread.participants.any((AppTrader p) => p.id == trader.id)) return;
    final List<AppTrader> updated = <AppTrader>[...thread.participants, trader];
    _threads[idx] = MessageThread(
      id: thread.id,
      peer: thread.peer,
      participants: updated,
      isGroup: thread.isGroup,
      groupTitle: thread.groupTitle,
      groupAvatarUrl: thread.groupAvatarUrl,
      presence: thread.presence,
      lastMessagePreview:
          '${trader.displayName ?? trader.handle} joined the group',
      lastMessageAt: DateTime.now(),
      unread: thread.unread,
      pinned: thread.pinned,
      muted: thread.muted,
      archived: thread.archived,
      isRequest: thread.isRequest,
      draft: thread.draft,
      typing: thread.typing,
      lastFromMe: true,
      lastStatus: MessageStatus.sent,
    );
    _messages.putIfAbsent(threadId, () => <ChatMessage>[]).add(
      ChatMessage(
        id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
        threadId: threadId,
        body: '${trader.displayName ?? trader.handle} joined the group.',
        fromMe: true,
        sentAt: DateTime.now(),
        systemNotice: true,
      ),
    );
    notifyListeners();
  }

  /// Removes a participant from a group conversation.
  ///
  /// @backend DELETE /threads/{id}/participants/{traderId}.
  void removeParticipant(String threadId, String traderId) {
    final int idx = _threads.indexWhere((MessageThread t) => t.id == threadId);
    if (idx == -1) return;
    final MessageThread thread = _threads[idx];
    AppTrader? removed;
    for (final AppTrader p in thread.participants) {
      if (p.id == traderId) {
        removed = p;
        break;
      }
    }
    final List<AppTrader> updated =
        thread.participants.where((AppTrader p) => p.id != traderId).toList();
    _threads[idx] = MessageThread(
      id: thread.id,
      peer: thread.peer,
      participants: updated,
      isGroup: thread.isGroup,
      groupTitle: thread.groupTitle,
      groupAvatarUrl: thread.groupAvatarUrl,
      presence: thread.presence,
      lastMessagePreview: removed != null
          ? '${removed.displayName ?? removed.handle} left the group'
          : thread.lastMessagePreview,
      lastMessageAt: DateTime.now(),
      unread: thread.unread,
      pinned: thread.pinned,
      muted: thread.muted,
      archived: thread.archived,
      isRequest: thread.isRequest,
      draft: thread.draft,
      typing: thread.typing,
      lastFromMe: true,
      lastStatus: MessageStatus.sent,
    );
    if (removed != null) {
      _messages.putIfAbsent(threadId, () => <ChatMessage>[]).add(
        ChatMessage(
          id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
          threadId: threadId,
          body: '${removed.displayName ?? removed.handle} left the group.',
          fromMe: false,
          sentAt: DateTime.now(),
          systemNotice: true,
        ),
      );
    }
    notifyListeners();
  }

  /// Blocks a trader: removes any incoming requests and hides active conversations.
  ///
  /// @backend POST /traders/{id}/block.
  void blockTrader(String traderId) {
    _requests.removeWhere((MessageThread t) => t.peer.id == traderId);
    for (int i = 0; i < _threads.length; i++) {
      if (_threads[i].peer.id == traderId) {
        _threads[i] = _threads[i].copyWith(archived: true);
      }
    }
    notifyListeners();
  }

  /// Persists the unsent composer text so it survives navigation.
  ///
  /// @backend local only (draft cache).
  void setDraft(String threadId, String draft) {
    final int idx = _threads.indexWhere((MessageThread t) => t.id == threadId);
    if (idx == -1) return;
    if (_threads[idx].draft == draft) return;
    _threads[idx] = _threads[idx].copyWith(draft: draft);
    // No notify: drafts must not rebuild the whole inbox on every keystroke.
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _simulatePeerReply(String threadId) {
    _after(const Duration(milliseconds: 1100), () {
      _typing.add(threadId);
      notifyListeners();
    });
    _after(Duration(milliseconds: 2200 + _rng.nextInt(1200)), () {
      _typing.remove(threadId);
      final MessageThread? thread = threadById(threadId);
      if (thread == null) return;
      final ChatMessage reply = ChatMessage(
        id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
        threadId: threadId,
        body: _autoReplies[_rng.nextInt(_autoReplies.length)],
        fromMe: false,
        sentAt: DateTime.now(),
      );
      _messages.putIfAbsent(threadId, () => <ChatMessage>[]).add(reply);
      // An open thread is being read, so do not inflate its unread counter.
      _touchThread(
        threadId,
        preview: reply.body,
        fromMe: false,
        status: MessageStatus.read,
      );
      notifyListeners();
    });
  }

  void _setStatus(String threadId, String messageId, MessageStatus status) {
    final List<ChatMessage>? list = _messages[threadId];
    if (list == null) return;
    final int i = list.indexWhere((ChatMessage m) => m.id == messageId);
    if (i == -1) return;
    list[i] = list[i].copyWith(status: status);
    final int t = _threads.indexWhere((MessageThread th) => th.id == threadId);
    if (t != -1 && _threads[t].lastFromMe) {
      _threads[t] = _threads[t].copyWith(lastStatus: status);
    }
    notifyListeners();
  }

  void _touchThread(
    String threadId, {
    required String preview,
    required bool fromMe,
    MessageStatus status = MessageStatus.read,
    DateTime? at,
    bool clearDraft = false,
  }) {
    final int idx = _threads.indexWhere((MessageThread t) => t.id == threadId);
    if (idx == -1) return;
    _threads[idx] = _threads[idx].copyWith(
      lastMessagePreview: preview,
      lastMessageAt: at ?? DateTime.now(),
      lastFromMe: fromMe,
      lastStatus: status,
      draft: clearDraft ? '' : null,
    );
  }

  void _mutateThread(
    String threadId,
    MessageThread Function(MessageThread) update,
  ) {
    final int idx = _threads.indexWhere((MessageThread t) => t.id == threadId);
    if (idx == -1) return;
    _threads[idx] = update(_threads[idx]);
    notifyListeners();
  }

  String _previewFor(ChatMessage m) {
    if (m.body.trim().isNotEmpty) return m.body.trim();
    if (m.sharedRef != null) return 'Shared ${m.sharedRef!.kind.label.toLowerCase()}';
    if (m.attachment != null) return m.attachment!.kind.label;
    return 'Message';
  }

  void _after(Duration d, VoidCallback fn) {
    late Timer timer;
    timer = Timer(d, () {
      _pending.remove(timer);
      fn();
    });
    _pending.add(timer);
  }

  @override
  void dispose() {
    for (final Timer t in _pending) {
      t.cancel();
    }
    _pending.clear();
    super.dispose();
  }
}

/// Static accessor so overlays and cross-feature callers can reach the shared
/// repository without threading it through constructors.
class MessagesRepositoryScope {
  MessagesRepositoryScope._();

  static MessagesRepository? _instance;

  static MessagesRepository get repository =>
      _instance ??= MessagesRepository();

  static set repository(MessagesRepository repo) => _instance = repo;
}
