import 'package:tradex/core/security/message_cipher.dart';
import 'package:tradex/core/security/private_message_service.dart';
import 'private_chat_payload.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/utils/attachment_compression_service.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:tradex/features/linking/entity_ticker_links_repository.dart';
import 'package:tradex/features/linking/link_graph_service.dart';
import 'package:tradex/features/messages/data/messages_seed_data.dart';
import 'package:tradex/features/messages/models/messages_models.dart';

/// Reactive store for the Messages feature.
///
/// A plain [ChangeNotifier] — views `addListener`/`removeListener` and rebuild.
/// State is initialized with seed fallback when offline, or live Supabase tables
/// and Realtime channels when connected.
class MessagesRepository extends ChangeNotifier {
  MessagesRepository() {
    _threads = [];
    _requests = [];
    _messages = {};
    if (CustomerDataPolicy.allowDemo) {
      _threads = MessagesSeed.threads();
      _requests = MessagesSeed.requests();
      _messages = MessagesSeed.messagesByThread();
    }
    if (SupabaseConfig.isConfigured) {
      unawaited(_initSupabase());
      var account = _resolveUserId();
      _authSubscription = SupabaseConfig.client!.auth.onAuthStateChange.listen((
        event,
      ) {
        final next = event.session?.user.id ?? '';
        if (next == account) return;
        account = next;
        _threads.clear();
        _requests.clear();
        _messages.clear();
        _lastUploadedPathByUrl.clear();
        _pinnedMessages.clear();
        _typing.clear();
        for (final timer in _pending) {
          timer.cancel();
        }
        _pending.clear();
        notifyListeners();
        if (next.isNotEmpty) unawaited(fetchFromSupabase());
      });
    }
  }

  Future<ChatMessage> _decryptMessage(
    ChatMessage message,
    String sender,
  ) async {
    if (!message.body.startsWith(MessageCipher.prefix)) return message;
    try {
      final plain = await PrivateMessageService.instance.decrypt(
        message.body,
        'chat/${message.threadId}/${message.id}',
        sender,
      );
      final payload = decodePrivateChat(plain);
      var attachment = payload.attachment;
      if (attachment?.storagePath != null) {
        final url = await _createAttachmentSignedUrl(attachment!.storagePath!);
        attachment = attachment.copyWith(url: url, thumbnailUrl: url);
      }
      return message.copyWith(
        body: payload.body,
        attachment: attachment,
        sharedRef: payload.ref,
      );
    } catch (_) {
      return message.copyWith(
        body: 'Encrypted message unavailable on this device.',
      );
    }
  }

  /// Global singleton instance so messages can be opened or sent from any feature.
  static final MessagesRepository instance = MessagesRepository();

  static const String chatAttachmentsBucket = 'chat-attachments';
  static const int signedUrlTtlSeconds = 300;

  late List<MessageThread> _threads;
  late List<MessageThread> _requests;
  late Map<String, List<ChatMessage>> _messages;
  final Set<String> _typing = <String>{};
  final List<Timer> _pending = <Timer>[];
  final Map<String, String> _pinnedMessages = <String, String>{};
  final Map<String, Future<void>> _pendingThreadCreations =
      <String, Future<void>>{};
  final Map<String, String> _lastUploadedPathByUrl = <String, String>{};
  RealtimeChannel? _realtimeChannel;
  StreamSubscription<AuthState>? _authSubscription;

  /// Optional overrides for unit testing private chat storage without live Supabase.
  Future<void> Function({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
    required bool upsert,
  })?
  storageUploadOverride;

  Future<String> Function({
    required String bucket,
    required String path,
    required int expiresInSeconds,
  })?
  storageSignUrlOverride;

  Future<void> Function({required String bucket, required List<String> paths})?
  storageRemoveOverride;

  Future<void> Function({
    required ChatMessage message,
    required String uploaderId,
    required String? storagePath,
  })?
  messagePersistOverride;

  static bool _isUuid(String id) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(id);
  }

  /// Validates that [path] follows the canonical `<thread_id>/<uploader_id>/<filename>`
  /// structure in `chat-attachments`, contains no traversal segments, and matches
  /// the expected [expectedThreadId] and [expectedUploaderId] when supplied.
  static bool isValidChatStoragePath(
    String path, {
    String? expectedThreadId,
    String? expectedUploaderId,
  }) {
    final clean = path.trim();
    if (clean.isEmpty || clean.contains('..') || clean.startsWith('/')) {
      return false;
    }
    final parts = clean.split('/');
    if (parts.length != 3) return false;
    final threadSegment = parts[0].trim();
    final uploaderSegment = parts[1].trim();
    final filenameSegment = parts[2].trim();
    if (threadSegment.isEmpty ||
        uploaderSegment.isEmpty ||
        filenameSegment.isEmpty) {
      return false;
    }
    if (expectedThreadId != null &&
        expectedThreadId.isNotEmpty &&
        threadSegment != expectedThreadId) {
      return false;
    }
    if (expectedUploaderId != null &&
        expectedUploaderId.isNotEmpty &&
        uploaderSegment != expectedUploaderId) {
      return false;
    }
    return true;
  }

  /// Normalizes canonical `<thread_id>/<uploader_id>/<file>` paths as well as both
  /// legacy chat path layouts:
  /// 1. `<user_id>/chat/<thread_id>/<file>` -> `<thread_id>/<user_id>/<file>`
  /// 2. `chat/<thread_id>/<file>` -> `<thread_id>/<fallbackUploaderId>/<file>`
  static String? normalizeLegacyChatStoragePath(
    String? rawUrlOrPath, {
    String? fallbackThreadId,
    String? fallbackUploaderId,
  }) {
    if (rawUrlOrPath == null) return null;
    var candidate = rawUrlOrPath.trim();
    if (candidate.isEmpty || candidate.startsWith('data:')) return null;

    if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
      final uri = Uri.tryParse(candidate);
      if (uri == null) return null;
      final fullPath = Uri.decodeComponent(uri.path);
      const bucketMarkers = <String>[
        '/chat-attachments/',
        '/community-attachments/',
      ];
      String? extracted;
      for (final marker in bucketMarkers) {
        final idx = fullPath.indexOf(marker);
        if (idx != -1) {
          extracted = fullPath.substring(idx + marker.length);
          break;
        }
      }
      if (extracted == null || extracted.isEmpty) return null;
      candidate = extracted;
    }

    if (candidate.contains('?')) {
      candidate = candidate.split('?').first;
    }
    while (candidate.startsWith('/')) {
      candidate = candidate.substring(1);
    }
    if (candidate.isEmpty || candidate.contains('..')) return null;

    final parts = candidate.split('/');
    // Legacy layout 1: <user_id>/chat/<thread_id>/<file>
    if (parts.length == 4 && parts[1] == 'chat') {
      final userId = parts[0].trim();
      final threadId = parts[2].trim();
      final file = parts[3].trim();
      if (userId.isNotEmpty && threadId.isNotEmpty && file.isNotEmpty) {
        return '$threadId/$userId/$file';
      }
      return null;
    }
    // Legacy layout 2: chat/<thread_id>/<file>
    if (parts.length == 3 && parts[0] == 'chat') {
      final threadId = parts[1].trim();
      final file = parts[2].trim();
      final uploaderId = (fallbackUploaderId ?? '').trim();
      if (threadId.isNotEmpty && uploaderId.isNotEmpty && file.isNotEmpty) {
        return '$threadId/$uploaderId/$file';
      }
      return null;
    }
    // Canonical layout: <thread_id>/<uploader_id>/<file>
    if (parts.length == 3 && parts[0] != 'chat' && parts[1] != 'chat') {
      final threadId = parts[0].trim();
      final uploaderId = parts[1].trim();
      final file = parts[2].trim();
      if (threadId.isNotEmpty && uploaderId.isNotEmpty && file.isNotEmpty) {
        if (fallbackThreadId != null &&
            fallbackThreadId.isNotEmpty &&
            threadId != fallbackThreadId) {
          return null;
        }
        return '$threadId/$uploaderId/$file';
      }
    }
    return null;
  }

  String _resolveUserId() {
    if (SupabaseConfig.isConfigured) {
      final uid = SupabaseConfig.client?.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) return uid;
    }
    final stored = SupabaseAuthBackendService.instance.currentUserProfile?.id;
    if (stored != null && stored.isNotEmpty) return stored;
    return '';
  }

  Future<void> _initSupabase() async {
    await fetchFromSupabase();
    _subscribeRealtime();
  }

  Future<void> fetchFromSupabase() async {
    if (!SupabaseConfig.isConfigured) return;
    final client = SupabaseConfig.client;
    if (client == null) return;
    final currentUserId = _resolveUserId();

    try {
      final threadRows = await client
          .from('chat_threads')
          .select('''
            id,
            type,
            title,
            created_by,
            is_pinned,
            is_archived,
            is_request,
            last_message_preview,
            last_message_at,
            created_at,
            chat_participants(
              user_id,
              role,
              last_read_at,
              profiles(id, handle, display_name, avatar_url)
            )
          ''')
          .order('last_message_at', ascending: false)
          .limit(40);

      final List<MessageThread> loadedThreads = [];
      final List<MessageThread> loadedRequests = [];
      final Map<String, List<ChatMessage>> loadedMessages = {};

      final threadIds = (threadRows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      // Batch all messages for the loaded threads in one query instead of N+1.
      final Map<String, List<Map<String, dynamic>>> msgRowsByThread = {};
      if (threadIds.isNotEmpty) {
        final allMsgRows = await client
            .from('chat_messages')
            .select('''
              id,
              thread_id,
              sender_id,
              body,
              reply_to_id,
              system_notice,
              status,
              created_at,
              chat_attachments(id, kind, url, storage_path, title, file_size_bytes, duration_seconds),
              chat_reactions(id, user_id, emoji),
              chat_shared_refs(id, ref_id, kind, title, subtitle, ticker, tags)
            ''')
            .inFilter('thread_id', threadIds)
            .order('created_at', ascending: false)
            .limit(threadIds.length * 30);

        for (final mmap in allMsgRows) {
          final tid = mmap['thread_id']?.toString() ?? '';
          if (tid.isNotEmpty) {
            (msgRowsByThread[tid] ??= <Map<String, dynamic>>[]).add(mmap);
          }
        }
        for (final list in msgRowsByThread.values) {
          list.sort(
            (a, b) => (a['created_at']?.toString() ?? '').compareTo(
              b['created_at']?.toString() ?? '',
            ),
          );
        }
      }

      for (final tmap in threadRows) {
        final threadId = tmap['id'] as String;
        final isGroup = tmap['type'] == 'group' || tmap['type'] == 'desk';
        final isRequest = tmap['is_request'] as bool? ?? false;
        final isPinned = tmap['is_pinned'] as bool? ?? false;
        final isArchived = tmap['is_archived'] as bool? ?? false;
        final lastPreview = tmap['last_message_preview'] as String? ?? '';
        final lastAt =
            DateTime.tryParse(tmap['last_message_at']?.toString() ?? '') ??
            DateTime.now();

        final participantsData =
            tmap['chat_participants'] as List<dynamic>? ?? [];
        final List<AppTrader> traders = [];
        AppTrader? peer;

        for (final p in participantsData) {
          final pmap = p as Map<String, dynamic>;
          final prof = pmap['profiles'] as Map<String, dynamic>? ?? {};
          final pId =
              prof['id']?.toString() ?? pmap['user_id']?.toString() ?? '';
          final trader = AppTrader(
            id: pId,
            handle: prof['handle'] as String? ?? 'trader',
            displayName:
                prof['display_name'] as String? ??
                prof['handle'] as String? ??
                'Trader',
            avatarUrl: prof['avatar_url'] as String?,
          );
          traders.add(trader);
          if (pId != currentUserId && peer == null) {
            peer = trader;
          }
        }

        peer ??=
            traders.firstOrNull ??
            AppTrader(
              id: 'peer',
              handle: 'trader',
              displayName: tmap['title'] as String? ?? 'Trader',
            );

        final thread = MessageThread(
          id: threadId,
          peer: peer,
          participants: traders,
          isGroup: isGroup,
          groupTitle: isGroup ? (tmap['title'] as String?) : null,
          lastMessagePreview: lastPreview,
          lastMessageAt: lastAt,
          unread: 0,
          pinned: isPinned,
          archived: isArchived,
          isRequest: isRequest,
        );

        if (isRequest) {
          loadedRequests.add(thread);
        } else {
          loadedThreads.add(thread);
        }

        final msgRows = msgRowsByThread[threadId] ?? const <Map<String, dynamic>>[];

        final threadMsgs = <ChatMessage>[];
        for (final mmap in msgRows) {
          final msgId = mmap['id'] as String;
          final senderId = mmap['sender_id'] as String? ?? '';
          final fromMe = senderId == currentUserId;
          final body = mmap['body'] as String? ?? '';
          final sentAt =
              DateTime.tryParse(mmap['created_at']?.toString() ?? '') ??
              DateTime.now();
          final statusStr = mmap['status'] as String? ?? 'sent';
          final status = MessageStatus.values.firstWhere(
            (s) => s.name == statusStr,
            orElse: () => MessageStatus.sent,
          );
          final systemNotice = mmap['system_notice'] as bool? ?? false;
          final replyToId = mmap['reply_to_id'] as String?;

          // Attachments
          MessageAttachment? attachment;
          final attList = mmap['chat_attachments'] as List<dynamic>?;
          if (attList != null && attList.isNotEmpty) {
            final attMap = attList.first as Map<String, dynamic>;
            final kindStr = attMap['kind'] as String? ?? 'image';
            final attKind = MessageAttachmentKind.values.firstWhere(
              (k) => k.name == kindStr,
              orElse: () => MessageAttachmentKind.image,
            );
            var rawUrl = attMap['url'] as String?;
            final rawStoragePath = attMap['storage_path'] as String?;
            final normalizedStoragePath = normalizeLegacyChatStoragePath(
              rawStoragePath ?? rawUrl,
              fallbackThreadId: threadId,
              fallbackUploaderId: senderId,
            );
            DateTime? signedExpiresAt;
            if (normalizedStoragePath != null &&
                normalizedStoragePath.isNotEmpty) {
              try {
                rawUrl = await _createAttachmentSignedUrl(
                  normalizedStoragePath,
                );
                signedExpiresAt = DateTime.now().add(
                  const Duration(seconds: signedUrlTtlSeconds),
                );
              } catch (e) {
                debugPrint(
                  '[MessagesRepository] signed URL resolution error for $normalizedStoragePath: $e',
                );
                rawUrl = null;
              }
            }
            attachment = MessageAttachment(
              id: attMap['id'] as String,
              kind: attKind,
              title: attMap['title'] as String? ?? '',
              url: rawUrl,
              thumbnailUrl: rawUrl,
              storagePath: normalizedStoragePath,
              signedUrlExpiresAt: signedExpiresAt,
            );
          }

          // Shared refs
          AppLinkRef? sharedRef;
          final refList = mmap['chat_shared_refs'] as List<dynamic>?;
          if (refList != null && refList.isNotEmpty) {
            final refMap = refList.first as Map<String, dynamic>;
            final kindStr = refMap['kind'] as String? ?? 'note';
            final refId = refMap['ref_id'] as String? ?? '';
            AppLinkKind refKind =
                AppLinkKind.fromHost(kindStr) ??
                AppLinkKind.values.firstWhere(
                  (k) =>
                      k.name.toLowerCase() ==
                      kindStr.toLowerCase().replaceAll('_', ''),
                  orElse: () => AppLinkKind.note,
                );
            // Intelligent heuristic fallback if kind was recorded as generic note:
            if (refKind == AppLinkKind.note) {
              if (refId.startsWith('post_') ||
                  refId.startsWith('pst_') ||
                  refId.startsWith('community')) {
                refKind = AppLinkKind.communityPost;
              } else if (refId.startsWith('trade_') ||
                  refId.startsWith('entry_') ||
                  refId.startsWith('trn_') ||
                  refId.startsWith('journal_')) {
                refKind = AppLinkKind.journal;
              } else if (refId.startsWith('strat_') ||
                  refId.startsWith('strategy_')) {
                refKind = AppLinkKind.strategy;
              }
            }
            sharedRef = AppLinkRef(
              id: refId,
              kind: refKind,
              title: refMap['title'] as String? ?? '',
              subtitle: refMap['subtitle'] as String?,
            );
          }

          // Reactions
          final Map<String, int> reactions = {};
          final Set<String> myReactions = {};
          final reactList = mmap['chat_reactions'] as List<dynamic>?;
          if (reactList != null) {
            for (final r in reactList) {
              final rmap = r as Map<String, dynamic>;
              final emoji = rmap['emoji'] as String? ?? '';
              final rUserId = rmap['user_id'] as String? ?? '';
              if (emoji.isNotEmpty) {
                reactions[emoji] = (reactions[emoji] ?? 0) + 1;
                if (rUserId == currentUserId) {
                  myReactions.add(emoji);
                }
              }
            }
          }

          threadMsgs.add(
            await _decryptMessage(
              ChatMessage(
                id: msgId,
                threadId: threadId,
                body: body,
                fromMe: fromMe,
                sentAt: sentAt,
                status: status,
                attachment: attachment,
                sharedRef: sharedRef,
                reactions: reactions,
                myReactions: myReactions,
                replyToId: replyToId,
                systemNotice: systemNotice,
              ),
              senderId,
            ),
          );
        }

        loadedMessages[threadId] = threadMsgs;
      }

      if (_resolveUserId() != currentUserId) return;
      _threads = loadedThreads;
      _requests = loadedRequests;
      _messages = loadedMessages;
      notifyListeners();
    } catch (e) {
      debugPrint(
        '[MessagesRepository] fetchFromSupabase notice: $e. Falling back to conversations table.',
      );
      await _fetchFromConversationsTable(client, currentUserId);
      if (_threads.isEmpty && CustomerDataPolicy.allowDemo) {
        _threads = MessagesSeed.threads();
        _requests = MessagesSeed.requests();
        _messages = MessagesSeed.messagesByThread();
        notifyListeners();
      }
    }
  }

  Future<void> _fetchFromConversationsTable(
    SupabaseClient client,
    String currentUserId,
  ) async {
    try {
      final res = await client
          .from('conversations')
          .select('''
            id,
            last_message_at,
            created_at,
            user_a_id,
            user_b_id,
            user_a:profiles!conversations_user_a_id_fkey(id, handle, display_name, avatar_url),
            user_b:profiles!conversations_user_b_id_fkey(id, handle, display_name, avatar_url)
          ''')
          .or('user_a_id.eq.$currentUserId,user_b_id.eq.$currentUserId')
          .order('last_message_at', ascending: false)
          .limit(40);

      final List<MessageThread> loadedThreads = [];
      final Map<String, List<ChatMessage>> loadedMessages = {};

      final convIds = (res as List)
          .map((r) => (r as Map<String, dynamic>)['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final Map<String, List<Map<String, dynamic>>> msgsByConv = {};
      if (convIds.isNotEmpty) {
        final allConvMsgs = await client
            .from('messages')
            .select('id, conversation_id, content, sender_id, created_at')
            .inFilter('conversation_id', convIds)
            .order('created_at', ascending: false)
            .limit(convIds.length * 30);
        for (final m in allConvMsgs) {
          final cid = m['conversation_id']?.toString() ?? '';
          if (cid.isNotEmpty) {
            (msgsByConv[cid] ??= <Map<String, dynamic>>[]).add(m);
          }
        }
        for (final list in msgsByConv.values) {
          list.sort(
            (a, b) => (a['created_at']?.toString() ?? '').compareTo(
              b['created_at']?.toString() ?? '',
            ),
          );
        }
      }

      for (final tmap in res) {
        final convId = tmap['id']?.toString() ?? '';
        final userAId = tmap['user_a_id']?.toString() ?? '';
        final peerMap =
            (userAId == currentUserId ? tmap['user_b'] : tmap['user_a'])
                as Map<String, dynamic>? ??
            {};

        final peerId = peerMap['id']?.toString() ?? 'usr_peer';
        final peerHandle = peerMap['handle'] as String? ?? 'trader';
        final peerName = peerMap['display_name'] as String? ?? peerHandle;
        final peerAvatar = peerMap['avatar_url'] as String?;

        final peerTrader = AppTrader(
          id: peerId,
          handle: peerHandle,
          displayName: peerName,
          avatarUrl: peerAvatar,
        );

        final msgsRes = msgsByConv[convId] ?? const <Map<String, dynamic>>[];

        final List<ChatMessage> threadMsgs = [];
        String lastPreview = '';
        DateTime lastAt =
            DateTime.tryParse(tmap['last_message_at']?.toString() ?? '') ??
            DateTime.now();

        for (final m in msgsRes) {
          final mId = m['id']?.toString() ?? '';
          final content = await PrivateMessageService.instance.decrypt(
            m['content'] as String? ?? '',
            'legacy/$convId/$mId',
            m['sender_id'] as String,
          );
          final senderId = m['sender_id']?.toString() ?? '';
          final sentAt =
              DateTime.tryParse(m['created_at']?.toString() ?? '') ??
              DateTime.now();
          lastPreview = content;
          lastAt = sentAt;

          threadMsgs.add(
            ChatMessage(
              id: mId,
              threadId: convId,
              body: content,
              fromMe: senderId == currentUserId,
              sentAt: sentAt,
            ),
          );
        }

        loadedMessages[convId] = threadMsgs;
        loadedThreads.add(
          MessageThread(
            id: convId,
            peer: peerTrader,
            participants: [peerTrader],
            lastMessagePreview: lastPreview,
            lastMessageAt: lastAt,
          ),
        );
      }

      if (_resolveUserId() != currentUserId) return;
      if (loadedThreads.isNotEmpty) {
        _threads = loadedThreads;
        _messages = loadedMessages;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MessagesRepository] fallback conversations error: $e');
    }
  }

  void _subscribeRealtime() {
    if (!SupabaseConfig.isConfigured) return;
    final client = SupabaseConfig.client;
    if (client == null || _resolveUserId().isEmpty) return;

    try {
      if (_realtimeChannel != null) {
        unawaited(client.removeChannel(_realtimeChannel!));
        _realtimeChannel = null;
      }
      _realtimeChannel = client.channel('public:messages_channel')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) => _handleRealtimeMessageChange(payload),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_threads',
          callback: (payload) => _handleRealtimeThreadChange(payload),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_reactions',
          callback: (payload) => _handleRealtimeReactionChange(payload),
        )
        ..subscribe();
    } catch (e) {
      debugPrint('[MessagesRepository] subscribeRealtime error: $e');
    }
  }

  Future<void> _handleRealtimeMessageChange(
    PostgresChangePayload payload,
  ) async {
    try {
      final currentUserId = _resolveUserId();
      if (payload.eventType == PostgresChangeEvent.insert) {
        final row = payload.newRecord;
        final threadId = row['thread_id']?.toString();
        if (threadId == null) return;
        final senderId = row['sender_id']?.toString() ?? '';
        final fromMe = senderId == currentUserId;
        final msgId = row['id']?.toString() ?? const Uuid().v4();

        // Check if message is already in list (e.g. optimistic insert)
        final existingList = _messages[threadId] ?? <ChatMessage>[];
        if (existingList.any((m) => m.id == msgId)) return;

        final newMsg = await _decryptMessage(
          ChatMessage(
            id: msgId,
            threadId: threadId,
            body: row['body']?.toString() ?? '',
            fromMe: fromMe,
            sentAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now(),
            status: MessageStatus.sent,
            systemNotice: row['system_notice'] as bool? ?? false,
            replyToId: row['reply_to_id']?.toString(),
          ),
          senderId,
        );

        if (_resolveUserId() != currentUserId) return;
        if ((_messages[threadId] ?? []).any((m) => m.id == msgId)) return;
        _messages.putIfAbsent(threadId, () => <ChatMessage>[]).add(newMsg);
        _touchThread(
          threadId,
          preview: _previewFor(newMsg),
          fromMe: fromMe,
          status: MessageStatus.sent,
        );
        notifyListeners();
      } else if (payload.eventType == PostgresChangeEvent.update) {
        final row = payload.newRecord;
        final threadId = row['thread_id']?.toString();
        final msgId = row['id']?.toString();
        if (threadId == null || msgId == null) return;
        final list = _messages[threadId];
        if (list == null) return;
        final idx = list.indexWhere((m) => m.id == msgId);
        if (idx != -1) {
          final m = list[idx];
          list[idx] = await _decryptMessage(
            m.copyWith(body: row['body']?.toString() ?? m.body, edited: true),
            row['sender_id'] as String,
          );
          notifyListeners();
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        final oldRow = payload.oldRecord;
        final msgId = oldRow['id']?.toString();
        if (msgId == null) return;
        for (final entry in _messages.entries) {
          final beforeLen = entry.value.length;
          entry.value.removeWhere((m) => m.id == msgId);
          if (entry.value.length != beforeLen) {
            notifyListeners();
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('[MessagesRepository] realtime message error: $e');
    }
  }

  void _handleRealtimeThreadChange(PostgresChangePayload payload) {
    try {
      if (payload.eventType == PostgresChangeEvent.update) {
        final row = payload.newRecord;
        final threadId = row['id']?.toString();
        if (threadId == null) return;
        final idx = _threads.indexWhere((t) => t.id == threadId);
        if (idx != -1) {
          _threads[idx] = _threads[idx].copyWith(
            pinned: row['is_pinned'] as bool? ?? _threads[idx].pinned,
            archived: row['is_archived'] as bool? ?? _threads[idx].archived,
            isRequest: row['is_request'] as bool? ?? _threads[idx].isRequest,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[MessagesRepository] realtime thread error: $e');
    }
  }

  void _handleRealtimeReactionChange(PostgresChangePayload payload) {
    unawaited(fetchFromSupabase());
  }

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

  List<MessageThread> get requests =>
      List<MessageThread>.unmodifiable(_requests);

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
      List<ChatMessage>.unmodifiable(
        _messages[threadId] ?? const <ChatMessage>[],
      );

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

  /// Current Writing Desk records the composer can attach. These come from the
  /// live link-graph snapshot instead of a static demo list, so deletes and
  /// visibility changes are reflected before a message is sent.
  List<AppLinkRef> get shareableRefs {
    final graph = AppLinkGraphService.instance.current;
    final refs = <AppLinkRef>[
      ...graph.options(AppLinkKind.note),
      ...graph.options(AppLinkKind.journal),
      ...graph.options(AppLinkKind.strategy),
    ];
    if (refs.isNotEmpty) return refs;
    return CustomerDataPolicy.allowDemo
        ? MessagesSeed.shareableRefs()
        : const <AppLinkRef>[];
  }

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

  Future<String> _createAttachmentSignedUrl(
    String storagePath, {
    int expiresInSeconds = signedUrlTtlSeconds,
  }) async {
    if (storageSignUrlOverride != null) {
      return storageSignUrlOverride!(
        bucket: chatAttachmentsBucket,
        path: storagePath,
        expiresInSeconds: expiresInSeconds,
      );
    }
    final client = SupabaseConfig.client;
    if (!SupabaseConfig.isConfigured || client == null) {
      throw StateError('Supabase is not configured to sign attachment URLs.');
    }
    if (storagePath.endsWith('.enc')) {
      final bytes = await client.storage
          .from(chatAttachmentsBucket)
          .download(storagePath);
      final plaintext = await PrivateMessageService.instance.decrypt(
        utf8.decode(bytes),
        'file/$storagePath',
        storagePath.split('/')[1],
      );
      final data = jsonDecode(plaintext) as Map<String, dynamic>;
      return 'data:${data['mime']};base64,${data['bytes']}';
    }
    return client.storage
        .from(chatAttachmentsBucket)
        .createSignedUrl(storagePath, expiresInSeconds);
  }

  /// Resolves or refreshes a short-lived signed URL for [attachment] in
  /// `chat-attachments`, updating the in-memory message state when refreshed.
  Future<String?> resolveAttachmentUrl(
    MessageAttachment attachment, {
    String? threadId,
    String? uploaderId,
    bool forceRefresh = false,
  }) async {
    final currentUrl = attachment.url ?? attachment.thumbnailUrl;
    if (!forceRefresh &&
        currentUrl != null &&
        currentUrl.isNotEmpty &&
        currentUrl.startsWith('data:')) {
      return currentUrl;
    }

    final resolvedPath =
        attachment.storagePath ??
        _lastUploadedPathByUrl[currentUrl] ??
        normalizeLegacyChatStoragePath(
          currentUrl,
          fallbackThreadId: threadId,
          fallbackUploaderId: uploaderId ?? _resolveUserId(),
        );

    if (!forceRefresh &&
        currentUrl != null &&
        currentUrl.isNotEmpty &&
        !attachment.isSignedUrlExpired &&
        (currentUrl.startsWith('http://') ||
            currentUrl.startsWith('https://')) &&
        !currentUrl.contains('/community-attachments/')) {
      return currentUrl;
    }

    if (resolvedPath == null || resolvedPath.isEmpty) {
      return currentUrl;
    }

    if (threadId != null &&
        threadId.isNotEmpty &&
        !isValidChatStoragePath(resolvedPath, expectedThreadId: threadId)) {
      throw StateError(
        'Attachment storage path does not belong to thread $threadId.',
      );
    }

    final signedUrl = await _createAttachmentSignedUrl(resolvedPath);
    final expiresAt = DateTime.now().add(
      const Duration(seconds: signedUrlTtlSeconds),
    );
    _lastUploadedPathByUrl[signedUrl] = resolvedPath;

    // Update cached message attachment with the refreshed signed URL
    for (final entry in _messages.entries) {
      if (threadId != null && entry.key != threadId) continue;
      final list = entry.value;
      for (var i = 0; i < list.length; i++) {
        final msg = list[i];
        if (msg.attachment?.id == attachment.id) {
          list[i] = msg.copyWith(
            attachment: msg.attachment!.copyWith(
              url: signedUrl,
              thumbnailUrl: signedUrl,
              storagePath: resolvedPath,
              signedUrlExpiresAt: expiresAt,
            ),
          );
          notifyListeners();
          break;
        }
      }
    }
    return signedUrl;
  }

  /// Sends a message and awaits persistence when backed by Supabase or a test
  /// persistence override. Throws on persistence failure after cleaning up any
  /// optimistic message and orphaned private storage object.
  Future<ChatMessage> sendMessageAsync(
    String threadId, {
    String body = '',
    MessageAttachment? attachment,
    AppLinkRef? sharedRef,
    String? replyToId,
    String? senderIdOverride,
  }) async {
    if (!SupabaseConfig.isConfigured &&
        !CustomerDataPolicy.allowDemo &&
        messagePersistOverride == null) {
      throw StateError('Connect and sign in before sending messages.');
    }
    if (body.trim().isEmpty && attachment == null && sharedRef == null) {
      throw ArgumentError('Message must have text, attachment, or sharedRef.');
    }
    final currentUserId = senderIdOverride ?? _resolveUserId();
    String? resolvedStoragePath;
    if (attachment != null) {
      resolvedStoragePath =
          attachment.storagePath ??
          _lastUploadedPathByUrl[attachment.url] ??
          normalizeLegacyChatStoragePath(
            attachment.url,
            fallbackThreadId: threadId,
            fallbackUploaderId: currentUserId,
          );
      if (resolvedStoragePath != null &&
          !isValidChatStoragePath(
            resolvedStoragePath,
            expectedThreadId: threadId,
            expectedUploaderId: currentUserId.isNotEmpty ? currentUserId : null,
          )) {
        throw StateError(
          'Attachment storage path does not match the active thread and uploader.',
        );
      }
      if (resolvedStoragePath != null &&
          attachment.storagePath != resolvedStoragePath) {
        attachment = attachment.copyWith(storagePath: resolvedStoragePath);
      }
    }

    final msgId = SupabaseConfig.isConfigured
        ? const Uuid().v4()
        : 'msg_${DateTime.now().microsecondsSinceEpoch}';
    final ChatMessage message = ChatMessage(
      id: msgId,
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

    if (messagePersistOverride != null) {
      try {
        await messagePersistOverride!(
          message: message,
          uploaderId: currentUserId,
          storagePath: resolvedStoragePath,
        );
        _setStatus(threadId, message.id, MessageStatus.sent);
      } catch (e) {
        _messages[threadId]?.removeWhere((m) => m.id == message.id);
        if (resolvedStoragePath != null && storageRemoveOverride != null) {
          try {
            await storageRemoveOverride!(
              bucket: chatAttachmentsBucket,
              paths: <String>[resolvedStoragePath],
            );
          } catch (_) {}
        }
        notifyListeners();
        rethrow;
      }
    } else if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client;
      if (client == null) {
        _messages[threadId]?.removeWhere((m) => m.id == message.id);
        notifyListeners();
        throw StateError('Supabase client is not initialized.');
      }
      final pendingCreate = _pendingThreadCreations[threadId];
      if (pendingCreate != null) {
        await pendingCreate;
      }
      try {
        final encrypted = await PrivateMessageService.instance.encryptChat(
          encodePrivateChat(message),
          threadId,
          message.id,
        );
        await client.from('chat_messages').insert({
          'id': message.id,
          'thread_id': _isUuid(threadId) ? threadId : null,
          'sender_id': currentUserId,
          'body': encrypted,
          'reply_to_id':
              message.replyToId != null && _isUuid(message.replyToId!)
              ? message.replyToId
              : null,
          'system_notice': false,
          'status': 'sent',
          'created_at': message.sentAt.toIso8601String(),
        });
        if (_isUuid(threadId)) {
          // Trigger update_chat_thread_last_message already updates chat_threads
          // on insert; keep this best-effort so secondary metadata errors do not
          // mark an already-persisted message as failed.
          try {
            await client
                .from('chat_threads')
                .update({
                  'last_message_preview': 'Encrypted message',
                  'last_message_at': message.sentAt.toIso8601String(),
                })
                .eq('id', threadId);
          } catch (_) {}
        }
        _setStatus(threadId, message.id, MessageStatus.sent);
      } catch (e) {
        // If this message carries an attachment, never fall back to the legacy
        // text-only `messages` table or leave a broken attachment message.
        if (attachment != null) {
          _messages[threadId]?.removeWhere((m) => m.id == message.id);
          try {
            await client.from('chat_messages').delete().eq('id', message.id);
          } catch (_) {}
          if (resolvedStoragePath != null) {
            try {
              await client.storage.from(chatAttachmentsBucket).remove(<String>[
                resolvedStoragePath,
              ]);
            } catch (_) {}
          }
          notifyListeners();
          rethrow;
        }
        _setStatus(threadId, message.id, MessageStatus.failed);
        // Never downgrade to the legacy plaintext transport on any failure.
        rethrow;
      }
    } else {
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

    final Set<String> linkedTickers = <String>{
      if (sharedRef != null && sharedRef.kind == AppLinkKind.ticker)
        sharedRef.id,
      ...EntityTickerLinksRepository.extractTickers(body),
    };
    if (!SupabaseConfig.isConfigured && linkedTickers.isNotEmpty) {
      unawaited(
        EntityTickerLinksRepository.instance.recordLinks(
          entityType: 'message',
          entityId: message.id,
          tickers: linkedTickers,
          contextSource: sharedRef?.kind == AppLinkKind.ticker
              ? 'shared_ref'
              : 'inline',
        ),
      );
    }
    return message;
  }

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
    unawaited(
      sendMessageAsync(
        threadId,
        body: body,
        attachment: attachment,
        sharedRef: sharedRef,
        replyToId: replyToId,
      ).catchError((Object e) {
        debugPrint('[MessagesRepository] sendMessage error: $e');
        return ChatMessage(
          id: 'err',
          threadId: threadId,
          body: body,
          fromMe: true,
          sentAt: DateTime.now(),
          status: MessageStatus.failed,
        );
      }),
    );
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

  /// Uploads a chat attachment to the private `chat-attachments` bucket under
  /// `<thread_id>/<uploader_id>/<generated_filename>` with `upsert: false`,
  /// returning the short-lived signed URL, stable `storagePath`, and expiry.
  Future<({String url, String storagePath, DateTime expiresAt})>
  uploadChatAttachment({
    required String threadId,
    required Uint8List bytes,
    required String filename,
    String? uploaderId,
  }) async {
    final cleanThreadId = threadId.trim();
    if (cleanThreadId.isEmpty || cleanThreadId.contains('/')) {
      throw ArgumentError(
        'Valid threadId is required to upload an attachment.',
      );
    }

    if (SupabaseConfig.isConfigured || storageUploadOverride != null) {
      final compressed = await AttachmentCompressionService.compressAttachment(
        bytes: bytes,
        filename: filename,
        mimeType: filename.startsWith('voice_') && filename.endsWith('.webm')
            ? 'audio/webm'
            : null,
      );

      final ext = compressed.filename.contains('.')
          ? compressed.filename.split('.').last.toLowerCase().trim()
          : 'webp';
      final actor =
          (uploaderId ??
                  SupabaseConfig.client?.auth.currentUser?.id ??
                  _resolveUserId())
              .trim();
      if (actor.isEmpty) {
        throw StateError('Sign in required to upload an attachment.');
      }

      final storagePath =
          '$cleanThreadId/$actor/${const Uuid().v4()}.${storageUploadOverride == null ? 'enc' : ext}';
      if (!isValidChatStoragePath(
        storagePath,
        expectedThreadId: cleanThreadId,
        expectedUploaderId: actor,
      )) {
        throw StateError('Generated invalid chat attachment storage path.');
      }

      final pendingThread = _pendingThreadCreations[cleanThreadId];
      if (pendingThread != null) await pendingThread;
      if (storageUploadOverride != null) {
        await storageUploadOverride!(
          bucket: chatAttachmentsBucket,
          path: storagePath,
          bytes: compressed.bytes,
          contentType: compressed.mimeType,
          upsert: false,
        );
      } else {
        final client = SupabaseConfig.client!;
        await client.storage
            .from(chatAttachmentsBucket)
            .uploadBinary(
              storagePath,
              Uint8List.fromList(
                utf8.encode(
                  await PrivateMessageService.instance.encrypt(
                    jsonEncode({
                      'bytes': base64Encode(compressed.bytes),
                      'mime': compressed.mimeType,
                    }),
                    'file/$storagePath',
                    await PrivateMessageService.instance.participants(
                      cleanThreadId,
                    ),
                  ),
                ),
              ),
              fileOptions: FileOptions(
                contentType: 'application/octet-stream',
                cacheControl: '$signedUrlTtlSeconds',
                upsert: false,
              ),
            );
      }

      final signedUrl = await _createAttachmentSignedUrl(
        storagePath,
        expiresInSeconds: signedUrlTtlSeconds,
      );
      final expiresAt = DateTime.now().add(
        const Duration(seconds: signedUrlTtlSeconds),
      );
      _lastUploadedPathByUrl[signedUrl] = storagePath;
      return (url: signedUrl, storagePath: storagePath, expiresAt: expiresAt);
    }

    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase().trim()
        : 'png';
    final mimeType = ext == 'png'
        ? 'image/png'
        : (ext == 'jpg' || ext == 'jpeg')
        ? 'image/jpeg'
        : ext == 'pdf'
        ? 'application/pdf'
        : ext == 'webm'
        ? 'audio/webm'
        : (ext == 'm4a' || ext == 'mp4')
        ? 'audio/mp4'
        : (ext == 'mp3' || ext == 'wav')
        ? 'audio/$ext'
        : 'application/octet-stream';
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    final actor = (uploaderId ?? _resolveUserId()).trim();
    final localPath =
        '$cleanThreadId/${actor.isNotEmpty ? actor : 'local_user'}/${const Uuid().v4()}.$ext';
    final expiresAt = DateTime.now().add(
      const Duration(seconds: signedUrlTtlSeconds),
    );
    _lastUploadedPathByUrl[dataUrl] = localPath;
    return (url: dataUrl, storagePath: localPath, expiresAt: expiresAt);
  }

  /// Uploads an attachment to the private `chat-attachments` bucket and returns
  /// a short-lived signed URL (or data URI when running offline in tests).
  Future<String> uploadAttachment({
    required String threadId,
    required Uint8List bytes,
    required String filename,
    String? uploaderId,
  }) async {
    final uploaded = await uploadChatAttachment(
      threadId: threadId,
      bytes: bytes,
      filename: filename,
      uploaderId: uploaderId,
    );
    return uploaded.url;
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
    final wasMine = mine.contains(emoji);
    if (wasMine) {
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

    if (SupabaseConfig.isConfigured && _isUuid(messageId)) {
      unawaited(() async {
        try {
          final client = SupabaseConfig.client!;
          final currentUserId = _resolveUserId();
          if (!wasMine) {
            await client.from('chat_reactions').insert({
              'message_id': messageId,
              'user_id': currentUserId,
              'emoji': emoji,
            });
          } else {
            await client
                .from('chat_reactions')
                .delete()
                .eq('message_id', messageId)
                .eq('user_id', currentUserId)
                .eq('emoji', emoji);
          }
        } catch (e) {
          debugPrint('[MessagesRepository] toggleReaction Supabase error: $e');
        }
      }());
    }
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

    if (SupabaseConfig.isConfigured && _isUuid(messageId)) {
      unawaited(() async {
        try {
          final client = SupabaseConfig.client!;
          await client
              .from('chat_messages')
              .update({
                'body': await PrivateMessageService.instance.encryptChat(
                  encodePrivateChat(m.copyWith(body: clean)),
                  threadId,
                  messageId,
                ),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', messageId);
        } catch (e) {
          list[i] = m;
          notifyListeners();
        }
      }());
    }

    final Set<String> linkedTickers = <String>{
      if (m.sharedRef != null && m.sharedRef!.kind == AppLinkKind.ticker)
        m.sharedRef!.id,
      ...EntityTickerLinksRepository.extractTickers(clean),
    };
    if (!SupabaseConfig.isConfigured && linkedTickers.isNotEmpty) {
      unawaited(
        EntityTickerLinksRepository.instance.recordLinks(
          entityType: 'message',
          entityId: messageId,
          tickers: linkedTickers,
        ),
      );
    } else {
      unawaited(
        EntityTickerLinksRepository.instance.removeLinks(
          entityType: 'message',
          entityId: messageId,
        ),
      );
    }
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

    if (SupabaseConfig.isConfigured && _isUuid(messageId)) {
      unawaited(() async {
        try {
          final client = SupabaseConfig.client!;
          await client.from('chat_messages').delete().eq('id', messageId);
        } catch (e) {
          debugPrint('[MessagesRepository] deleteMessage Supabase error: $e');
        }
      }());
    }

    unawaited(
      EntityTickerLinksRepository.instance.removeLinks(
        entityType: 'message',
        entityId: messageId,
      ),
    );
  }

  final Set<String> _restrictedTraders = <String>{};

  /// Returns whether [peer] only accepts messages from invited accounts.
  bool isMessagingRestricted(AppTrader peer) {
    if (_restrictedTraders.contains(peer.id.toLowerCase()) ||
        _restrictedTraders.contains(peer.handle.toLowerCase())) {
      return true;
    }
    if (peer.handle.toLowerCase().contains('private') ||
        peer.handle.toLowerCase().contains('invited_only')) {
      return true;
    }
    return false;
  }

  /// Sets whether direct messages to [traderIdOrHandle] are restricted to invited users only.
  void setTraderMessagingRestricted(String traderIdOrHandle, bool restricted) {
    if (restricted) {
      _restrictedTraders.add(traderIdOrHandle.toLowerCase());
    } else {
      _restrictedTraders.remove(traderIdOrHandle.toLowerCase());
    }
    notifyListeners();
  }

  /// Starts (or reopens) a direct thread with [peer] and returns its id.
  ///
  /// @backend POST /threads { participantId }.
  String startConversation(AppTrader peer, {bool isRequest = false}) {
    final String normalizedHandle = peer.handle.toLowerCase().trim();
    bool matchesPeer(MessageThread t) =>
        !t.isGroup &&
        (t.peer.id == peer.id ||
            (normalizedHandle.isNotEmpty &&
                t.peer.handle.toLowerCase().trim() == normalizedHandle));

    final int existing = _threads.indexWhere(matchesPeer);
    if (existing != -1) {
      if (_threads[existing].archived) {
        _threads[existing] = _threads[existing].copyWith(archived: false);
        notifyListeners();
      }
      return _threads[existing].id;
    }

    final int existingReq = _requests.indexWhere(matchesPeer);
    if (existingReq != -1) {
      return _requests[existingReq].id;
    }

    final String id = SupabaseConfig.isConfigured
        ? const Uuid().v4()
        : 'thread_new_${DateTime.now().millisecondsSinceEpoch}';

    final thread = MessageThread(
      id: id,
      peer: peer,
      presence: MessagePresence.online,
      lastMessagePreview: isRequest
          ? '${peer.displayName ?? peer.handle} sent you a message request'
          : 'Say hi to ${peer.displayName ?? peer.handle} 👋',
      lastMessageAt: DateTime.now(),
      isRequest: isRequest,
    );

    if (isRequest) {
      _requests.insert(0, thread);
    } else {
      _threads.insert(0, thread);
    }
    _messages[id] = <ChatMessage>[];
    notifyListeners();

    if (SupabaseConfig.isConfigured) {
      final Future<void> createFuture = (() async {
        try {
          final client = SupabaseConfig.client!;
          final currentUserId = _resolveUserId();
          await client.from('chat_threads').insert({
            'id': id,
            'type': 'direct',
            'title': peer.displayName ?? peer.handle,
            'created_by': currentUserId,
            'last_message_preview': isRequest
                ? 'Message request'
                : 'Conversation started',
            'is_request': isRequest,
          });
          await client.from('chat_participants').insert([
            {'thread_id': id, 'user_id': currentUserId, 'role': 'admin'},
            if (_isUuid(peer.id))
              {'thread_id': id, 'user_id': peer.id, 'role': 'member'},
          ]);
        } catch (e) {
          debugPrint(
            '[MessagesRepository] startConversation Supabase error: $e',
          );
        }
      })();
      _pendingThreadCreations[id] = createFuture;
      unawaited(
        createFuture.whenComplete(() {
          _pendingThreadCreations.remove(id);
        }),
      );
    }

    return id;
  }

  /// Starts or opens a group conversation with multiple [participants].
  ///
  /// @backend POST /threads/group { title, participantIds }
  String startGroupConversation({
    required String title,
    required List<AppTrader> participants,
  }) {
    final String id = SupabaseConfig.isConfigured
        ? const Uuid().v4()
        : 'thread_grp_${DateTime.now().millisecondsSinceEpoch}';
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

    if (SupabaseConfig.isConfigured) {
      unawaited(() async {
        try {
          final client = SupabaseConfig.client!;
          final currentUserId = _resolveUserId();
          await client.from('chat_threads').insert({
            'id': id,
            'type': 'group',
            'title': title,
            'created_by': currentUserId,
            'last_message_preview':
                'Group created with ${participants.length} traders',
          });
          final participantRows = [
            {'thread_id': id, 'user_id': currentUserId, 'role': 'admin'},
            for (final p in participants)
              if (_isUuid(p.id))
                {'thread_id': id, 'user_id': p.id, 'role': 'member'},
          ];
          await client.from('chat_participants').insert(participantRows);
        } catch (e) {
          debugPrint(
            '[MessagesRepository] startGroupConversation Supabase error: $e',
          );
        }
      }());
    }

    return id;
  }

  /// @backend PATCH /threads/{id} { pinned }.
  void togglePin(String threadId) {
    _mutateThread(threadId, (MessageThread t) => t.copyWith(pinned: !t.pinned));
    if (SupabaseConfig.isConfigured && _isUuid(threadId)) {
      final t = threadById(threadId);
      if (t != null) {
        unawaited(
          SupabaseConfig.client!
              .from('chat_threads')
              .update({'is_pinned': t.pinned})
              .eq('id', threadId)
              .catchError((e) {
                debugPrint('[MessagesRepository] togglePin error: $e');
              }),
        );
      }
    }
  }

  /// @backend PATCH /threads/{id} { muted }.
  void toggleMute(String threadId) =>
      _mutateThread(threadId, (MessageThread t) => t.copyWith(muted: !t.muted));

  /// @backend PATCH /threads/{id} { archived }.
  void toggleArchive(String threadId) {
    _mutateThread(
      threadId,
      (MessageThread t) => t.copyWith(archived: !t.archived),
    );
    if (SupabaseConfig.isConfigured && _isUuid(threadId)) {
      final t = threadById(threadId);
      if (t != null) {
        unawaited(
          SupabaseConfig.client!
              .from('chat_threads')
              .update({'is_archived': t.archived})
              .eq('id', threadId)
              .catchError((e) {
                debugPrint('[MessagesRepository] toggleArchive error: $e');
              }),
        );
      }
    }
  }

  /// Accepts a message request, promoting it into the main inbox.
  ///
  /// @backend POST /requests/{id}/accept.
  String acceptRequest(String requestId) {
    final int i = _requests.indexWhere((MessageThread t) => t.id == requestId);
    if (i == -1) return requestId;
    final MessageThread promoted = _requests
        .removeAt(i)
        .copyWith(isRequest: false, unread: 0);
    _threads.insert(0, promoted);
    // Fold in a system notice so the transition is visible in the thread.
    _messages
        .putIfAbsent(promoted.id, () => <ChatMessage>[])
        .add(
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

    if (SupabaseConfig.isConfigured && _isUuid(requestId)) {
      unawaited(
        SupabaseConfig.client!
            .from('chat_threads')
            .update({'is_request': false})
            .eq('id', requestId)
            .catchError((e) {
              debugPrint('[MessagesRepository] acceptRequest error: $e');
            }),
      );
    }

    return promoted.id;
  }

  /// @backend POST /requests/{id}/decline.
  void declineRequest(String requestId) {
    _requests.removeWhere((MessageThread t) => t.id == requestId);
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(requestId)) {
      unawaited(
        SupabaseConfig.client!
            .from('chat_threads')
            .delete()
            .eq('id', requestId)
            .catchError((e) {
              debugPrint('[MessagesRepository] declineRequest error: $e');
            }),
      );
    }
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

    if (SupabaseConfig.isConfigured && _isUuid(threadId)) {
      unawaited(
        SupabaseConfig.client!
            .from('chat_threads')
            .delete()
            .eq('id', threadId)
            .catchError((e) {
              debugPrint('[MessagesRepository] deleteThread error: $e');
            }),
      );
    }
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

    if (SupabaseConfig.isConfigured && _isUuid(threadId)) {
      unawaited(
        SupabaseConfig.client!
            .from('chat_messages')
            .delete()
            .eq('thread_id', threadId)
            .catchError((e) {
              debugPrint('[MessagesRepository] clearThreadMessages error: $e');
            }),
      );
    }
  }

  /// Renames a group conversation.
  ///
  /// @backend PATCH /threads/{id} { groupTitle }.
  void renameGroup(String threadId, String newTitle) {
    final String clean = newTitle.trim();
    if (clean.isEmpty) return;
    _mutateThread(threadId, (MessageThread t) => t.copyWith(groupTitle: clean));
    _messages
        .putIfAbsent(threadId, () => <ChatMessage>[])
        .add(
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
    _messages
        .putIfAbsent(threadId, () => <ChatMessage>[])
        .add(
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
    final List<AppTrader> updated = thread.participants
        .where((AppTrader p) => p.id != traderId)
        .toList();
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
      _messages
          .putIfAbsent(threadId, () => <ChatMessage>[])
          .add(
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

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Searches live traders from Supabase profiles table, excluding the current user.
  /// Supports auto-detection by user id (UUID), handle (@handle), display name, or email.
  Future<List<AppTrader>> searchLiveTraders(String query) async {
    final cleanQuery = query.trim().replaceAll('@', '');
    if (!SupabaseConfig.isConfigured) {
      if (CustomerDataPolicy.allowDemo) {
        return DemoDataSource.instance.traders().where((t) {
          if (cleanQuery.isEmpty) return true;
          return (t.displayName ?? '').toLowerCase().contains(
                cleanQuery.toLowerCase(),
              ) ||
              t.handle.toLowerCase().contains(cleanQuery.toLowerCase()) ||
              t.id.toLowerCase() == cleanQuery.toLowerCase();
        }).toList();
      }
      return const <AppTrader>[];
    }

    try {
      final client = SupabaseConfig.client!;
      final currentUserId =
          client.auth.currentUser?.id ?? client.auth.currentSession?.user.id;

      var builder = client
          .from('profiles')
          .select('id, handle, display_name, avatar_url, bio, role, email');

      if (cleanQuery.isNotEmpty) {
        if (_uuidRegex.hasMatch(cleanQuery)) {
          builder = builder.or(
            'id.eq.$cleanQuery,display_name.ilike.%$cleanQuery%,handle.ilike.%$cleanQuery%,email.ilike.%$cleanQuery%',
          );
        } else {
          builder = builder.or(
            'display_name.ilike.%$cleanQuery%,handle.ilike.%$cleanQuery%,email.ilike.%$cleanQuery%',
          );
        }
      }

      final res = await builder.limit(40);
      final List<AppTrader> traders = [];
      for (final item in res as List) {
        final row = item as Map<String, dynamic>;
        final id = row['id']?.toString() ?? '';
        if (id.isNotEmpty && id == currentUserId) continue;
        final rawHandle =
            (row['handle'] ?? row['username']) as String? ?? 'trader';
        final handle = rawHandle.startsWith('@')
            ? rawHandle.substring(1)
            : rawHandle;
        final displayName = row['display_name'] as String? ?? handle;
        traders.add(
          AppTrader(
            id: id,
            handle: handle,
            displayName: displayName,
            avatarUrl: row['avatar_url'] as String?,
            bio: row['bio'] as String?,
            verified: row['verified'] as bool? ?? false,
          ),
        );
      }
      return traders;
    } catch (e) {
      debugPrint('[MessagesRepository] searchLiveTraders error: $e');
      return const <AppTrader>[];
    }
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
    if (m.sharedRef != null) {
      return 'Shared ${m.sharedRef!.kind.label.toLowerCase()}';
    }
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
    _authSubscription?.cancel();
    for (final Timer t in _pending) {
      t.cancel();
    }
    _pending.clear();
    if (_realtimeChannel != null && SupabaseConfig.isConfigured) {
      try {
        SupabaseConfig.client?.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
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
