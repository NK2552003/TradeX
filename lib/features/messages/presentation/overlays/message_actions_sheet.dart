import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/copilot/copilot.dart';
import 'package:alphajournal/features/messages/data/messages_repository.dart';
import 'package:alphajournal/features/messages/models/messages_models.dart';
import 'package:alphajournal/features/messages/presentation/overlays/share_to_conversation_dialog.dart';
import 'package:alphajournal/features/messages/presentation/widgets/messages_widgets.dart';

/// Long-press actions for a single message: a quick emoji reaction row plus
/// copy / reply / delete. Reaction options come from the repository; delete is
/// only offered for the trader's own messages.
class MessageActionsSheet extends StatelessWidget {
  const MessageActionsSheet({
    super.key,
    required this.repository,
    required this.threadId,
    required this.message,
    this.onReply,
    this.onForward,
    this.onNavigateToAi,
  });

  final MessagesRepository repository;
  final String threadId;
  final ChatMessage message;
  final void Function(ChatMessage message)? onReply;
  final void Function(ChatMessage message)? onForward;
  final VoidCallback? onNavigateToAi;

  static Future<void> show(
    BuildContext context, {
    required MessagesRepository repository,
    required String threadId,
    required ChatMessage message,
    void Function(ChatMessage message)? onReply,
    void Function(ChatMessage message)? onForward,
    VoidCallback? onNavigateToAi,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => MessagesDensityScope(
        child: MessageActionsSheet(
          repository: repository,
          threadId: threadId,
          message: message,
          onReply: onReply,
          onForward: onForward,
          onNavigateToAi: onNavigateToAi,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.all(context.sp(theme.spacing.sm)),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: context.radius(theme.radii.xl),
          border: Border.all(
            color: colors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const MessagesSheetGrabber(),
            _reactionRow(context),
            UiDivider(),
            if (message.hasText)
              _action(
                context,
                icon: Icons.copy_rounded,
                label: 'Copy text',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.body));
                  Navigator.of(context).pop();
                },
              ),
            if (message.fromMe && message.hasText && !message.systemNotice)
              _action(
                context,
                icon: Icons.edit_outlined,
                label: 'Edit message',
                onTap: () {
                  Navigator.of(context).pop();
                  _showEditDialog(context);
                },
              ),
            _action(
              context,
              icon: Icons.auto_awesome_rounded,
              label: 'Analyze with AI Copilot',
              intent: UiIntent.primary,
              onTap: () {
                Navigator.of(context).pop();
                _analyzeWithAi(context);
              },
            ),
            if (onReply != null)
              _action(
                context,
                icon: Icons.reply_rounded,
                label: 'Reply',
                onTap: () {
                  Navigator.of(context).pop();
                  onReply!(message);
                },
              ),
            _action(
              context,
              icon: Icons.bookmark_border_rounded,
              label: 'Bookmark message',
              onTap: () {
                Navigator.of(context).pop();
                UiToastScope.maybeOf(context)?.show(
                  UiToastData(
                    title: 'Message Bookmarked',
                    message: 'Saved to your bookmarked messages.',
                    intent: UiIntent.success,
                  ),
                );
              },
            ),
            _action(
              context,
              icon: repository.pinnedMessageId(threadId) == message.id
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              label: repository.pinnedMessageId(threadId) == message.id
                  ? 'Unpin from conversation'
                  : 'Pin to conversation',
              onTap: () {
                final bool wasPinned =
                    repository.pinnedMessageId(threadId) == message.id;
                repository.togglePinMessage(threadId, message.id);
                Navigator.of(context).pop();
                UiToastScope.maybeOf(context)?.show(
                  UiToastData(
                    title: wasPinned ? 'Message Unpinned' : 'Message Pinned',
                    message: wasPinned
                        ? 'Message unpinned from this conversation.'
                        : 'Message pinned to top of conversation.',
                    intent: UiIntent.info,
                  ),
                );
              },
            ),
            _action(
              context,
              icon: Icons.forward_rounded,
              label: 'Forward message',
              onTap: () {
                Navigator.of(context).pop();
                if (onForward != null) {
                  onForward!(message);
                } else {
                  ShareToConversationDialog.forwardMessage(
                    context,
                    repository: repository,
                    message: message,
                  );
                }
              },
            ),
            if (message.fromMe && !message.systemNotice)
              _action(
                context,
                icon: Icons.delete_outline_rounded,
                label: 'Delete message',
                intent: UiIntent.danger,
                onTap: () {
                  repository.deleteMessage(threadId, message.id);
                  Navigator.of(context).pop();
                },
              ),
            SizedBox(height: context.sp(theme.spacing.xs)),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(
      text: message.body,
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => UiDialog(
        title: 'Edit message',
        content: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.sp(context.ui.spacing.sm),
          ),
          child: UiInput(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            variant: UiInputVariant.filled,
            autofocus: true,
          ),
        ),
        actions: <Widget>[
          UiButton(
            label: 'Cancel',
            variant: UiVariant.ghost,
            intent: UiIntent.neutral,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          UiButton(
            label: 'Save',
            variant: UiVariant.solid,
            intent: UiIntent.primary,
            onPressed: () {
              final String newText = controller.text.trim();
              if (newText.isNotEmpty) {
                repository.editMessage(threadId, message.id, newText);
              }
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _analyzeWithAi(BuildContext context) {
    Navigator.of(context).pop();
    final String content = message.hasText
        ? message.body
        : (message.sharedRef?.title ?? message.attachment?.title ?? 'Message');
    final String prompt =
        'Analyze this message/trade setup from our conversation:\n\n"$content"\n\n'
        'Provide technical setup validation, risk:reward assessment, and key levels to monitor.';

    CopilotSheet.show(
      context,
      repository: CopilotScope.repository,
      initialPrompt: prompt,
      contextTitle: 'Chat Message',
      contextSubtitle: content.length > 50
          ? '${content.substring(0, 50)}...'
          : content,
      contextIcon: Icons.chat_bubble_outline_rounded,
      onOpenFullScreen: onNavigateToAi,
    );
  }

  Widget _reactionRow(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (final String emoji in repository.quickReactions)
            _ReactionButton(
              emoji: emoji,
              active: message.myReactions.contains(emoji),
              onTap: () {
                repository.toggleReaction(threadId, message.id, emoji);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    UiIntent intent = UiIntent.neutral,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final Color fg = intent == UiIntent.danger
        ? colors.destructive
        : colors.foreground;
    return UiInteractive(
      onTap: onTap,
      builder: (BuildContext context, UiInteractiveState state) {
        return Container(
          width: double.infinity,
          color: state.hovered ? colors.surfaceHover : Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.sm),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: context.sz(theme.sizes.iconMd), color: fg),
              SizedBox(width: context.sp(theme.spacing.md)),
              Text(
                label,
                style: context.uiText.body.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.emoji,
    required this.onTap,
    this.active = false,
  });

  final String emoji;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: context.sz(44),
        height: context.sz(44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? colors.primary.withValues(alpha: 0.14)
              : colors.surfaceMuted,
          shape: BoxShape.circle,
          border: active
              ? Border.all(color: colors.primary, width: theme.borders.hairline)
              : null,
        ),
        child: Text(emoji, style: TextStyle(fontSize: context.fs(22))),
      ),
    );
  }
}
