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
            .select('conversation_id, content, created_at, read_at')
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

        final lastMsgContent =
            messageResponse?['content'] as String? ?? 'No messages yet';
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

      final messages = (response as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        final senderId = map['sender_id'] as String;
        return AppChatMessage(
          id: map['id'] as String,
          body: map['content'] as String,
          fromMe: senderId == userId,
          sentAt: DateTime.parse(map['created_at'] as String),
        );
      }).toList().reversed.toList();

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
      return AppChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        body: content,
        fromMe: true,
        sentAt: sentAt,
      );
    }

    try {
      final response = await client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': content,
          })
          .select('id, content, sender_id, created_at')
          .single();

      await client
          .from('conversations')
          .update({'last_message_at': sentAt.toIso8601String()})
          .eq('id', conversationId);

      return AppChatMessage(
        id: response['id'] as String,
        body: response['content'] as String,
        fromMe: true,
        sentAt: DateTime.parse(response['created_at'] as String),
      );
    } catch (e) {
      debugPrint('ChatRepositoryImpl.sendMessage error: $e');
      return AppChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        body: content,
        fromMe: true,
        sentAt: sentAt,
      );
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
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              final senderId = newRecord['sender_id'] as String?;
              final msg = AppChatMessage(
                id: newRecord['id'] as String? ?? 'msg_realtime',
                body: newRecord['content'] as String? ?? '',
                fromMe: senderId == userId,
                sentAt: newRecord['created_at'] != null
                    ? DateTime.parse(newRecord['created_at'] as String)
                    : DateTime.now(),
              );
              controller.add(msg);
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
