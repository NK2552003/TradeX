import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

abstract class MessagesRepository {
  Future<List<AppConversation>> getConversations({String? query});
  Future<AppConversation?> getConversation(String id);
  Future<List<AppChatMessage>> getMessages(String conversationId);
  Future<AppChatMessage> sendMessage(String conversationId, String body);
  Future<void> markRead(String conversationId);
  Future<int> getUnreadCount();
  Future<AppConversation> startConversation(AppTrader peer);
  Future<void> deleteConversation(String id);
}

class MessagesRepositoryImpl implements MessagesRepository {
  MessagesRepositoryImpl({DemoDataSource? source})
    : _source = source ?? DemoDataSource.instance {
    _conversations = List<AppConversation>.from(_source.conversations());
  }

  final DemoDataSource _source;
  late List<AppConversation> _conversations;
  final Map<String, List<AppChatMessage>> _threads =
      <String, List<AppChatMessage>>{};

  List<AppChatMessage> _threadFor(String conversationId) =>
      _threads.putIfAbsent(
        conversationId,
        () => List<AppChatMessage>.from(_source.chatMessages(conversationId)),
      );

  AppConversation _copy(
    AppConversation source, {
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unread,
  }) => AppConversation(
    id: source.id,
    peer: source.peer,
    lastMessage: lastMessage ?? source.lastMessage,
    lastMessageAt: lastMessageAt ?? source.lastMessageAt,
    unread: unread ?? source.unread,
  );

  @override
  Future<List<AppConversation>> getConversations({String? query}) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final String needle = (query ?? '').trim().toLowerCase();
    final List<AppConversation> rows = needle.isEmpty
        ? List<AppConversation>.from(_conversations)
        : _conversations
              .where(
                (AppConversation c) =>
                    (c.peer.displayName ?? '').toLowerCase().contains(needle) ||
                    c.peer.handle.toLowerCase().contains(needle) ||
                    c.lastMessage.toLowerCase().contains(needle),
              )
              .toList();
    rows.sort(
      (AppConversation a, AppConversation b) =>
          b.lastMessageAt.compareTo(a.lastMessageAt),
    );
    return rows;
  }

  @override
  Future<AppConversation?> getConversation(String id) async {
    for (final AppConversation conversation in _conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  @override
  Future<List<AppChatMessage>> getMessages(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    return List<AppChatMessage>.from(_threadFor(conversationId));
  }

  @override
  Future<AppChatMessage> sendMessage(String conversationId, String body) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final AppChatMessage message = AppChatMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      body: body,
      fromMe: true,
      sentAt: DateTime.now(),
    );
    _threadFor(conversationId).add(message);
    final int index = _conversations.indexWhere(
      (AppConversation c) => c.id == conversationId,
    );
    if (index >= 0) {
      _conversations[index] = _copy(
        _conversations[index],
        lastMessage: body,
        lastMessageAt: message.sentAt,
        unread: 0,
      );
    }
    return message;
  }

  @override
  Future<void> markRead(String conversationId) async {
    final int index = _conversations.indexWhere(
      (AppConversation c) => c.id == conversationId,
    );
    if (index < 0) return;
    _conversations[index] = _copy(_conversations[index], unread: 0);
  }

  @override
  Future<int> getUnreadCount() async => _conversations.fold<int>(
    0,
    (int sum, AppConversation c) => sum + c.unread,
  );

  @override
  Future<AppConversation> startConversation(AppTrader peer) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final AppConversation existing = _conversations.firstWhere(
      (AppConversation c) => c.peer.id == peer.id,
      orElse: () => AppConversation(
        id: 'cnv_${DateTime.now().microsecondsSinceEpoch}',
        peer: peer,
        lastMessage: 'Say hello to ${peer.displayName ?? peer.handle}.',
        lastMessageAt: DateTime.now(),
      ),
    );
    if (!_conversations.any((AppConversation c) => c.id == existing.id)) {
      _conversations = <AppConversation>[existing, ..._conversations];
      _threads[existing.id] = <AppChatMessage>[];
    }
    return existing;
  }

  @override
  Future<void> deleteConversation(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _conversations = _conversations
        .where((AppConversation c) => c.id != id)
        .toList();
    _threads.remove(id);
  }
}
