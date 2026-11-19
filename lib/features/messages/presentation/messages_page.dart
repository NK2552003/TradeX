import 'dart:async';
import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/messages/data/chat_repository.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, this.repository});

  final ChatRepository? repository;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  late final ChatRepository _repo;
  bool _loading = true;
  List<AppConversation> _conversations = [];
  AppConversation? _selectedConversation;
  List<AppChatMessage> _messages = [];
  String _draft = '';
  StreamSubscription<AppChatMessage>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ChatRepositoryImpl();
    _loadConversations();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getConversations();
      if (mounted) {
        setState(() {
          _conversations = list;
          if (list.isNotEmpty && _selectedConversation == null) {
            _selectConversation(list.first);
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('MessagesPage error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectConversation(AppConversation conv) async {
    _realtimeSub?.cancel();
    setState(() {
      _selectedConversation = conv;
      _messages = [];
      _draft = '';
    });

    final msgs = await _repo.getMessages(conv.id);
    if (mounted) {
      setState(() => _messages = msgs);
    }

    _realtimeSub = _repo.streamMessages(conv.id).listen((newMsg) {
      if (mounted) {
        setState(() {
          _messages = [..._messages, newMsg];
        });
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final conv = _selectedConversation;
    final text = _draft.trim();
    if (conv == null || text.isEmpty) return;

    setState(() => _draft = '');
    try {
      final msg = await _repo.sendMessage(conv.id, text);
      if (mounted) {
        setState(() {
          _messages = [..._messages, msg];
        });
      }
    } catch (e) {
      debugPrint('Send message error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    if (_loading) {
      return UiSkeleton.messages();
    }

    return AppPageBlock(
      title: 'Direct Messages',
      subtitle: 'Encrypted 1-on-1 conversations with verified traders',
      child: Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: AppInboxBlock(
                conversations: _conversations,
                onOpen: (conv) => _selectConversation(conv),
              ),
            ),
            if (_selectedConversation != null) ...[
              UiGap.h(context.sp(theme.spacing.lg)),
              Expanded(
                flex: 3,
                child: AppChatThreadBlock(
                  peer: _selectedConversation!.peer,
                  messages: _messages,
                  draft: _draft,
                  onDraftChanged: (v) => setState(() => _draft = v),
                  onSend: _handleSendMessage,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
