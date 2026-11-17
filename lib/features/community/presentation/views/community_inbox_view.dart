import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/community/presentation/widgets/community_send_dm_dialog.dart';

/// Direct messages center for 1-on-1 private trader discussions and shared setups.
class CommunityInboxView extends StatefulWidget {
  const CommunityInboxView({
    super.key,
    required this.repository,
    this.currentUser,
    this.onBack,
  });

  final CommunityRepository repository;
  final CommunityAuthor? currentUser;
  final VoidCallback? onBack;

  @override
  State<CommunityInboxView> createState() => _CommunityInboxViewState();
}

class _CommunityInboxViewState extends State<CommunityInboxView> {
  CommunityConversation? _activeConversation;
  final TextEditingController _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    _msgController.dispose();
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty || _activeConversation == null) return;
    widget.repository.sendDirectMessage(_activeConversation!.peer.id, text);
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: UiIconButton(
          icon: Icons.arrow_back,
          onPressed: () => widget.onBack != null
              ? widget.onBack!()
              : Navigator.of(context).pop(),
        ),
        title: Text(
          _activeConversation == null
              ? 'Direct Messages'
              : _activeConversation!.peer.displayName,
          style: context.uiText.heading.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.foreground,
          ),
        ),
        actions: [
          if (_activeConversation == null)
            UiIconButton(
              icon: Icons.edit_square,
              tooltip: 'New message',
              onPressed: () => CommunitySendDmDialog.show(
                context,
                repository: widget.repository,
              ),
            )
          else
            UiIconButton(
              icon: Icons.info_outline,
              tooltip: 'Conversation details',
              onPressed: () => UiDialog.show<void>(
                context,
                child: UiDialog(
                  title: 'Conversation details',
                  content: Text(
                    'Messages with @${_activeConversation!.peer.handle} are '
                    'private to this conversation. Message delivery and read '
                    'receipts update here when connected to Realtime.',
                    style: context.uiText.body,
                  ),
                  actions: <Widget>[
                    UiButton(
                      label: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kCommunityMaxWidth),
          child:
              widget.repository.isLoading &&
                  widget.repository.loadConversations().isEmpty
              ? UiSkeleton.messages()
              : (_activeConversation == null
                    ? _buildConversationList()
                    : _buildChatThread(_activeConversation!)),
        ),
      ),
    );
  }

  Widget _buildConversationList() {
    final colors = context.ui.colors;
    final conversations = widget.repository.loadConversations();

    if (conversations.isEmpty) {
      return Center(
        child: UiEmptyState(
          icon: Icons.mail_outline,
          title: 'No Direct Messages Yet',
          message:
              'Direct messages allow you to discuss setups, signals, and strategies privately with followed traders.',
          actionLabel: 'Start a Conversation',
          onActionPressed: () => CommunitySendDmDialog.show(
            context,
            repository: widget.repository,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (_, _) => const UiDivider(),
      itemBuilder: (ctx, idx) {
        final conv = conversations[idx];
        return InkWell(
          onTap: () => setState(() => _activeConversation = conv),
          child: Container(
            color: conv.unreadCount > 0
                ? colors.primary.withValues(alpha: 0.04)
                : Colors.transparent,
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(16),
              vertical: context.sp(14),
            ),
            child: Row(
              children: [
                UiAvatar(name: conv.peer.displayName, size: UiSize.md),
                SizedBox(width: context.sp(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              conv.peer.displayName,
                              style: context.uiText.body.copyWith(
                                fontWeight: conv.unreadCount > 0
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: colors.foreground,
                              ),
                            ),
                          ),
                          Text(
                            _formatTimestamp(conv.updatedAt),
                            style: context.uiText.caption.copyWith(
                              color: colors.foregroundMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.sp(4)),
                      Text(
                        conv.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: conv.unreadCount > 0
                              ? colors.foreground
                              : colors.foregroundMuted,
                          fontWeight: conv.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (conv.unreadCount > 0) ...[
                  SizedBox(width: context.sp(8)),
                  Container(
                    padding: EdgeInsets.all(context.sp(6)),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${conv.unreadCount}',
                      style: context.uiText.label.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatThread(CommunityConversation conv) {
    final colors = context.ui.colors;
    final messages = widget.repository.messagesForConversation(conv.id);

    return Column(
      children: [
        // Back to list bar
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(16),
            vertical: context.sp(8),
          ),
          color: colors.surfaceMuted,
          child: Row(
            children: [
              UiButton(
                label: 'All Conversations',
                icon: Icons.chevron_left,
                variant: UiVariant.ghost,
                size: UiSize.sm,
                onPressed: () => setState(() => _activeConversation = null),
              ),
              const Spacer(),
              Text(
                conv.peer.handle,
                style: context.uiText.caption.copyWith(
                  color: colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
        const UiDivider(),

        // Messages list
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.all(context.sp(16)),
            reverse: true,
            itemCount: messages.length,
            separatorBuilder: (_, _) => SizedBox(height: context.sp(12)),
            itemBuilder: (ctx, idx) {
              final msg = messages[messages.length - 1 - idx];
              final isMe = msg.isMine;

              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(14),
                          vertical: context.sp(10),
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? colors.primary : colors.surface,
                          borderRadius: BorderRadius.circular(context.sz(14)),
                          border: Border.all(
                            color: isMe ? Colors.transparent : colors.border,
                          ),
                        ),
                        child: Text(
                          msg.text,
                          style: context.uiText.body.copyWith(
                            color: isMe ? Colors.white : colors.foreground,
                          ),
                        ),
                      ),
                      if (msg.sharedPost != null) ...[
                        SizedBox(height: context.sp(6)),
                        InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CommunityPostDetailView(
                                  post: msg.sharedPost!,
                                  repository: widget.repository,
                                  currentUser:
                                      widget.currentUser ??
                                      widget.repository.currentAuthor,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.all(context.sp(10)),
                            decoration: BoxDecoration(
                              color: colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(
                                context.sz(8),
                              ),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.share,
                                  size: context.sz(14),
                                  color: colors.primary,
                                ),
                                SizedBox(width: context.sp(8)),
                                Text(
                                  'View Shared Post',
                                  style: context.uiText.caption.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: context.sp(2)),
                      Text(
                        _formatTimestamp(msg.sentAt),
                        style: context.uiText.label.copyWith(
                          color: colors.foregroundSubtle,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Input bar
        Container(
          padding: EdgeInsets.all(context.sp(12)),
          color: colors.surface,
          child: Row(
            children: [
              Expanded(
                child: UiInput(
                  hintText: 'Type a message...',
                  value: _msgController.text,
                  onChanged: (val) => _msgController.text = val,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              SizedBox(width: context.sp(8)),
              UiIconButton(
                icon: Icons.send,
                intent: UiIntent.primary,
                variant: UiVariant.primary,
                size: UiSize.md,
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${dt.day}/${dt.month}';
  }
}
