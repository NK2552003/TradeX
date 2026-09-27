import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/widgets/messages_widgets.dart';

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
  });

  final MessagesRepository repository;
  final String threadId;
  final ChatMessage message;
  final void Function(ChatMessage message)? onReply;

  static Future<void> show(
    BuildContext context, {
    required MessagesRepository repository,
    required String threadId,
    required ChatMessage message,
    void Function(ChatMessage message)? onReply,
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
          border: Border.all(color: colors.border, width: theme.borders.hairline),
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
    final Color fg =
        intent == UiIntent.danger ? colors.destructive : colors.foreground;
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
