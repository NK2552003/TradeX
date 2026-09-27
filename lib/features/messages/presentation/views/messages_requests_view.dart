import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/widgets/messages_widgets.dart';

/// Message requests: conversations started by people the trader has not replied
/// to. Each row can be accepted (promotes it into the inbox and opens it) or
/// declined. All rows come from [MessagesRepository.requests].
class MessagesRequestsView extends StatefulWidget {
  const MessagesRequestsView({
    super.key,
    required this.repository,
    this.onAccepted,
    this.onOpenProfile,
  });

  final MessagesRepository repository;

  /// Called with the promoted thread id after acceptance, so the shell can open
  /// the conversation.
  final void Function(String threadId)? onAccepted;
  final void Function(AppTrader trader)? onOpenProfile;

  @override
  State<MessagesRequestsView> createState() => _MessagesRequestsViewState();
}

class _MessagesRequestsViewState extends State<MessagesRequestsView> {
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepo);
  }

  @override
  void didUpdateWidget(covariant MessagesRequestsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.repository != oldWidget.repository) {
      oldWidget.repository.removeListener(_onRepo);
      widget.repository.addListener(_onRepo);
    }
  }

  void _onRepo() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepo);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<MessageThread> requests = widget.repository.requests;

    if (requests.isEmpty) {
      return const MessagesEmptyState(
        icon: Icons.mark_email_read_outlined,
        title: 'No message requests',
        message: 'Requests from traders you have not spoken to appear here.',
      );
    }

    return ListView(
      padding: EdgeInsets.only(
        left: context.sp(theme.spacing.sm),
        right: context.sp(theme.spacing.sm),
        top: context.sp(theme.spacing.xs),
        bottom: context.sp(theme.spacing.xl),
      ),
      children: <Widget>[
        UiCallout(
          intent: UiIntent.info,
          icon: Icons.privacy_tip_outlined,
          title: 'These people want to message you',
          message: 'They cannot see whether you have read their request until '
              'you accept it.',
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        ...requests.map((MessageThread t) => _RequestRow(
              thread: t,
              onAccept: () => _accept(t),
              onDecline: () => _decline(t),
              onOpenProfile: widget.onOpenProfile == null
                  ? null
                  : () => widget.onOpenProfile!(t.peer),
            )),
      ],
    );
  }

  void _accept(MessageThread thread) {
    final String id = widget.repository.acceptRequest(thread.id);
    widget.onAccepted?.call(id);
  }

  void _decline(MessageThread thread) {
    widget.repository.declineRequest(thread.id);
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.thread,
    required this.onAccept,
    required this.onDecline,
    this.onOpenProfile,
  });

  final MessageThread thread;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.surface,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MessagesThreadAvatar(
                  thread: thread,
                  size: UiSize.md,
                  onTap: onOpenProfile,
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              thread.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.uiText.bodyStrong,
                            ),
                          ),
                          if (thread.peer.verified) ...<Widget>[
                            SizedBox(width: context.sp(theme.spacing.xxs)),
                            Icon(
                              Icons.verified_rounded,
                              size: context.sz(14),
                              color: colors.primary,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '@${thread.peer.handle}',
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  AppTokens.relativeTime(thread.lastMessageAt),
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundSubtle,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: context.radius(theme.radii.md),
              ),
              child: Text(
                thread.lastMessagePreview,
                style: context.uiText.body,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            Row(
              children: <Widget>[
                Expanded(
                  child: UiButton(
                    label: 'Decline',
                    variant: UiVariant.soft,
                    intent: UiIntent.neutral,
                    onPressed: onDecline,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: UiButton(
                    label: 'Accept',
                    icon: Icons.check_rounded,
                    intent: UiIntent.primary,
                    onPressed: onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
