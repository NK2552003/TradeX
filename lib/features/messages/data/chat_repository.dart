import 'package:tradex/core/security/private_message_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';

abstract class ChatRepository {
  Future<List<AppConversation>> getConversations();
  Future<List<AppChatMessage>> getMessages(String conversationId);
  Future<AppChatMessage> sendMessage(String conversationId, String content);
  Stream<AppChatMessage> streamMessages(String conversationId);
}

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({DemoDataSource? demoDataSource})
    : _demo = demoDataSource ?? DemoDataSource.instance;

  final DemoDataSource _demo;
  SupabaseClient? get _client {
    if (SupabaseConfig.isConfigured) {
      try {
        return SupabaseConfig.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String get _targetUserId =>
      _client?.auth.currentUser?.id ??
      SupabaseAuthBackendService.instance.currentUserProfile?.id ??
      '';

  Future<String> _safeDecrypt(
    String value,
    String context,
    String sender,
  ) async {
    try {
      if (!PrivateMessageService.instance.isLocallyUnlockedFast) {
        await PrivateMessageService.instance.warmFromCache();
      }
      return await PrivateMessageService.instance.decrypt(
        value,
        context,
        sender,
      );
    } catch (_) {
      return PrivateMessageService.instance.isLocallyUnlockedFast
          ? 'Encrypted message unavailable on this device.'
          : 'Encrypted message — unlock history to view.';
    }
  }

  @override
  Future<List<AppConversation>> getConversations() async {
    final client = _client;
    final userId = _targetUserId;
    if (client == null) {
      return CustomerDataPolicy.allowDemo ? _demo.conversations() : [];
    }

    try {
      final response = await client
          .from('conversations')
          .select('''
            id,
            last_message_at,
            user_a_id,
            user_b_id,
            user_a:profiles!conversations_user_a_id_fkey(id, handle, display_name, avatar_url),
            user_b:profiles!conversations_user_b_id_fkey(id, handle, display_name, avatar_url)
          ''')
          .or('user_a_id.eq.$userId,user_b_id.eq.$userId')
          .order('last_message_at', ascending: false)
          .limit(50);

      final rows = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
      final convIds = rows
          .map((m) => m['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      final Map<String, Map<String, dynamic>> latestByConv = {};
      if (convIds.isNotEmpty) {
        final msgRows = await client
            .from('messages')
            .select('id, conversation_id, content, sender_id, created_at, read_at')
            .inFilter('conversation_id', convIds)
            .order('created_at', ascending: false)
            .limit(convIds.length * 4);
        for (final m in (msgRows as List<dynamic>).whereType<Map<String, dynamic>>()) {
          final cid = m['conversation_id']?.toString() ?? '';
          if (cid.isNotEmpty && !latestByConv.containsKey(cid)) {
            latestByConv[cid] = m;
          }
        }
      }

      final conversations = <AppConversation>[];
      for (final map in rows) {
        final userAId = map['user_a_id'] as String;
        final peerData =
            (userAId == userId ? map['user_b'] : map['user_a'])
                as Map<String, dynamic>? ??
            {};

        final peerId = peerData['id'] as String? ?? 'usr_peer';
        final peerHandle = peerData['handle'] as String? ?? 'trader';
        final peerName = peerData['display_name'] as String? ?? peerHandle;
        final avatarUrl = peerData['avatar_url'] as String?;

        final messageResponse = latestByConv[map['id']?.toString() ?? ''];

        final lastMsgContent = messageResponse == null
            ? 'No messages yet'
            : await _safeDecrypt(
                messageResponse['content'] as String,
                'legacy/${map['id']}/${messageResponse['id']}',
                messageResponse['sender_id'] as String,
              );
        final lastMsgTime = messageResponse != null
            ? DateTime.parse(messageResponse['created_at'] as String)
            : (map['last_message_at'] != null
                  ? DateTime.parse(map['last_message_at'] as String)
                  : DateTime.now());

        conversations.add(
          AppConversation(
            id: map['id'] as String,
            peer: AppTrader(
              id: peerId,
              handle: peerHandle,
              displayName: peerName,
              avatarUrl: avatarUrl,
            ),
            lastMessage: lastMsgContent,
            lastMessageAt: lastMsgTime,
            unread: 0,
          ),
        );
      }
      return conversations.isEmpty
          ? (CustomerDataPolicy.allowDemo
                ? _demo.conversations()
                : <AppConversation>[])
          : conversations;
    } catch (e) {
      debugPrint('ChatRepositoryImpl.getConversations error: $e');
      return CustomerDataPolicy.allowDemo
          ? _demo.conversations()
          : <AppConversation>[];
    }
  }

  @override
  Future<List<AppChatMessage>> getMessages(String conversationId) async {
    final client = _client;
    final userId = _targetUserId;
    if (client == null) {
      return CustomerDataPolicy.allowDemo
          ? _demo.chatMessages(conversationId)
          : [];
    }

    try {
      final response = await client
          .from('messages')
          .select('id, content, sender_id, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(100);

      final messages = (await Future.wait(
        (response as List<dynamic>).map((row) async {
          final map = row as Map<String, dynamic>;
          final senderId = map['sender_id'] as String;
          return AppChatMessage(
            id: map['id'] as String,
            body: await _safeDecrypt(
              map['content'] as String,
              'legacy/$conversationId/${map['id']}',
              senderId,
            ),
            fromMe: senderId == userId,
            sentAt: DateTime.parse(map['created_at'] as String),
          );
        }),
      )).reversed.toList();

      return messages.isEmpty
          ? (CustomerDataPolicy.allowDemo
                ? _demo.chatMessages(conversationId)
                : <AppChatMessage>[])
          : messages;
    } catch (e) {
      debugPrint('ChatRepositoryImpl.getMessages error: $e');
      return CustomerDataPolicy.allowDemo
          ? _demo.chatMessages(conversationId)
          : <AppChatMessage>[];
    }
  }

  @override
  Future<AppChatMessage> sendMessage(
    String conversationId,
    String content,
  ) async {
    final client = _client;
    final userId = _targetUserId;
    final sentAt = DateTime.now();

    if (client == null) {
      if (!CustomerDataPolicy.allowDemo) {
        throw StateError('Connect and sign in before sending messages.');
      }
      return AppChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        body: content,
        fromMe: true,
        sentAt: sentAt,
      );
    }

    try {
      final id = const Uuid().v4();
      final conversation = await client
          .from('conversations')
          .select('user_a_id,user_b_id')
          .eq('id', conversationId)
          .single();
      final encrypted = await PrivateMessageService.instance.encrypt(
        content,
        'legacy/$conversationId/$id',
        [
          conversation['user_a_id'] as String,
          conversation['user_b_id'] as String,
        ],
      );
      final response = await client
          .from('messages')
          .insert({
            'id': id,
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': encrypted,
          })
          .select('id, content, sender_id, created_at')
          .single();

      await client
          .from('conversations')
          .update({'last_message_at': sentAt.toIso8601String()})
          .eq('id', conversationId);

      return AppChatMessage(
        id: response['id'] as String,
        body: content,
        fromMe: true,
        sentAt: DateTime.parse(response['created_at'] as String),
      );
    } catch (e) {
      // Never report a failed encrypted send as a successfully sent local message.
      rethrow;
    }
  }

  @override
  Stream<AppChatMessage> streamMessages(String conversationId) {
    final client = _client;
    final userId = _targetUserId;
    if (client == null) {
      return const Stream<AppChatMessage>.empty();
    }

    final controller = StreamController<AppChatMessage>();

    final channel = client.channel('public:messages:$conversationId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            try {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final senderId = newRecord['sender_id'] as String?;
                final msg = AppChatMessage(
                  id: newRecord['id'] as String? ?? 'msg_realtime',
                  body: await _safeDecrypt(
                    newRecord['content'] as String? ?? '',
                    'legacy/$conversationId/${newRecord['id']}',
                    senderId!,
                  ),
                  fromMe: senderId == userId,
                  sentAt: newRecord['created_at'] != null
                      ? DateTime.parse(newRecord['created_at'] as String)
                      : DateTime.now(),
                );
                if (!controller.isClosed && _targetUserId == userId) {
                  controller.add(msg);
                }
              }
            } catch (_) {
              if (!controller.isClosed) {
                controller.addError(
                  StateError('Encrypted message could not be opened.'),
                );
              }
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
