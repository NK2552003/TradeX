import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/messages/data/messages_repository.dart';
import 'package:alphajournal/features/messages/models/messages_models.dart';
import 'package:alphajournal/features/messages/presentation/widgets/messages_widgets.dart';

/// Message requests: conversations started by people the trader has not replied
/// to. Each row can be accepted (promotes it into the inbox and opens it) or
/// declined. All rows come from [MessagesRepository.requests].
class MessagesRequestsView extends StatefulWidget {
  const MessagesRequestsView({
    super.key,
    required this.repository,
    this.onAccepted,
    this.onOpenThread,
    this.onOpenProfile,
  });

  final MessagesRepository repository;

  /// Called with the promoted thread id after acceptance, so the shell can open
  /// the conversation.
  final void Function(String threadId)? onAccepted;
  final void Function(MessageThread thread)? onOpenThread;
  final void Function(AppTrader trader)? onOpenProfile;

  @override
  State<MessagesRequestsView> createState() => _MessagesRequestsViewState();
}

enum _RequestTab { all, verified }

class _MessagesRequestsViewState extends State<MessagesRequestsView> {
  _RequestTab _tab = _RequestTab.all;
  String _query = '';

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

  void _confirmDeleteAll() {
    UiDialog.show<void>(
      context,
      child: UiDialog(
        title: 'Delete all requests?',
        content: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.sp(context.ui.spacing.sm),
          ),
          child: Text(
            'This will permanently decline and remove all incoming message requests. You cannot undo this.',
            style: context.uiText.body,
          ),
        ),
        actions: <Widget>[
          UiButton(
            label: 'Cancel',
            variant: UiVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          UiButton(
            label: 'Delete all',
            intent: UiIntent.danger,
            onPressed: () {
              widget.repository.declineAllRequests();
              Navigator.of(context).pop();
              UiToastScope.maybeOf(context)?.show(
                UiToastData(
                  title: 'All requests deleted',
                  message: 'Your message requests inbox has been cleared.',
                  intent: UiIntent.neutral,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<MessageThread> allRequests = widget.repository.requests;

    if (allRequests.isEmpty) {
      return const MessagesEmptyState(
        icon: Icons.mark_email_read_outlined,
        title: 'No message requests',
        message: 'Requests from traders you have not spoken to appear here.',
      );
    }

    final int verifiedCount = allRequests.where((t) => t.peer.verified).length;
    final List<MessageThread> requests = allRequests.where((t) {
      if (_tab == _RequestTab.verified && !t.peer.verified) return false;
      if (_query.trim().isNotEmpty) {
        final q = _query.trim().toLowerCase();
        final name = (t.peer.displayName ?? '').toLowerCase();
        final handle = t.peer.handle.toLowerCase();
        final preview = t.lastMessagePreview.toLowerCase();
        return name.contains(q) || handle.contains(q) || preview.contains(q);
      }
      return true;
    }).toList();

    return ListView(
      padding: EdgeInsets.only(
        left: context.sp(theme.spacing.sm),
        right: context.sp(theme.spacing.sm),
        top: context.sp(theme.spacing.xs),
        bottom: context.sp(theme.spacing.xl),
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: UiToggleGroup<_RequestTab>(
                value: _tab,
                onChanged: (_RequestTab t) => setState(() => _tab = t),
                options: <UiOption<_RequestTab>>[
                  UiOption<_RequestTab>(
                    value: _RequestTab.all,
                    label: 'All (${allRequests.length})',
                  ),
                  UiOption<_RequestTab>(
                    value: _RequestTab.verified,
                    label: 'Verified ($verifiedCount)',
                    icon: Icons.verified_rounded,
                  ),
                ],
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            UiButton(
              label: 'Delete all',
              variant: UiVariant.ghost,
              intent: UiIntent.danger,
              size: UiSize.sm,
              onPressed: _confirmDeleteAll,
            ),
          ],
        ),
        if (allRequests.length > 3) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xs)),
          UiInput.search(
            hintText: 'Filter requests',
            value: _query,
            onChanged: (String v) => setState(() => _query = v),
            onClear: () => setState(() => _query = ''),
          ),
        ],
        SizedBox(height: context.sp(theme.spacing.sm)),
        UiCallout(
          intent: UiIntent.info,
          icon: Icons.privacy_tip_outlined,
          title: 'These people want to message you',
          message:
              'They cannot see whether you have read their request until '
              'you accept it. Tap any request to preview the conversation.',
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        if (requests.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.xl),
            ),
            child: Center(
              child: Text(
                _tab == _RequestTab.verified
                    ? 'No requests from verified traders.'
                    : 'No requests match "$_query".',
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ),
          )
        else
          ...requests.map(
            (MessageThread t) => _RequestRow(
              thread: t,
              onOpen: widget.onOpenThread == null
                  ? null
                  : () => widget.onOpenThread!(t),
              onAccept: () => _accept(t),
              onDecline: () => _decline(t),
              onBlock: () => _block(t),
              onOpenProfile: widget.onOpenProfile == null
                  ? null
                  : () => widget.onOpenProfile!(t.peer),
            ),
          ),
      ],
    );
  }

  void _accept(MessageThread thread) {
    final String id = widget.repository.acceptRequest(thread.id);
    UiToastScope.maybeOf(context)?.show(
      UiToastData(
        title: 'Request Accepted',
        message: 'You can now message @${thread.peer.handle}.',
        intent: UiIntent.success,
      ),
    );
    widget.onAccepted?.call(id);
  }

  void _decline(MessageThread thread) {
    widget.repository.declineRequest(thread.id);
    UiToastScope.maybeOf(context)?.show(
      UiToastData(
        title: 'Request Declined',
        message: 'Message request from @${thread.peer.handle} was declined.',
        intent: UiIntent.neutral,
      ),
    );
  }

  void _block(MessageThread thread) {
    widget.repository.blockTrader(thread.peer.id);
    UiToastScope.maybeOf(context)?.show(
      UiToastData(
        title: 'Trader Blocked',
        message: '@${thread.peer.handle} has been blocked.',
        intent: UiIntent.danger,
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.thread,
    required this.onAccept,
    required this.onDecline,
    required this.onBlock,
    this.onOpen,
    this.onOpenProfile,
  });

  final MessageThread thread;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onBlock;
  final VoidCallback? onOpen;
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
            UiInteractive(
              onTap: onOpen,
              builder: (BuildContext context, UiInteractiveState state) {
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                  decoration: BoxDecoration(
                    color: state.hovered
                        ? colors.surfaceHover
                        : colors.surfaceMuted,
                    borderRadius: context.radius(theme.radii.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.lastMessagePreview,
                        style: context.uiText.body,
                      ),
                      if (onOpen != null) ...[
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        Text(
                          'Tap to inspect conversation',
                          style: context.uiText.caption.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 1,
                  child: UiButton(
                    label: 'Block',
                    icon: Icons.block_rounded,
                    size: UiSize.sm,
                    variant: UiVariant.ghost,
                    intent: UiIntent.danger,
                    onPressed: onBlock,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  flex: 1,
                  child: UiButton(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    size: UiSize.sm,
                    variant: UiVariant.soft,
                    intent: UiIntent.neutral,
                    onPressed: onDecline,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  flex: 1,
                  child: UiButton(
                    label: 'Accept',
                    icon: Icons.check_rounded,
                    size: UiSize.sm,
                    variant: UiVariant.solid,
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
