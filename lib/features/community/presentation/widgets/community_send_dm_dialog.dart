import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';

/// Modal dialog allowing a trader to send a post or direct message to another user.
class CommunitySendDmDialog extends StatefulWidget {
  const CommunitySendDmDialog({
    super.key,
    required this.repository,
    this.post,
  });

  final CommunityRepository repository;
  final CommunityPost? post;

  static Future<void> show(
    BuildContext context, {
    CommunityPost? post,
    CommunityRepository? repository,
  }) {
    final repo = repository ?? CommunityRepository();
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ctx.sz(460)),
          child: Container(
            padding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
            decoration: BoxDecoration(
              color: ctx.uiColors.surface,
              borderRadius: ctx.radius(ctx.ui.radii.lg),
              border: Border.all(
                color: ctx.uiColors.border,
                width: ctx.ui.borders.hairline,
              ),
            ),
            child: CommunitySendDmDialog(repository: repo, post: post),
          ),
        ),
      ),
    );
  }

  @override
  State<CommunitySendDmDialog> createState() => _CommunitySendDmDialogState();
}

class _CommunitySendDmDialogState extends State<CommunitySendDmDialog> {
  String _search = '';
  String _message = '';
  CommunityAuthor? _selectedRecipient;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final traders = widget.repository.suggestedTraders.where((t) {
      if (_search.isEmpty) return true;
      return t.displayName.toLowerCase().contains(_search.toLowerCase()) ||
          t.handle.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Header
        Row(
          children: <Widget>[
            Text(
              'Send Message',
              style: context.uiText.heading.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            UiIconButton(
              icon: Icons.close_rounded,
              size: UiSize.xs,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),

        // Search recipient
        UiSearchField(
          value: _search,
          hintText: 'Search people...',
          onChanged: (val) => setState(() => _search = val),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),

        // Trader list
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.sz(180)),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: traders.length,
            itemBuilder: (BuildContext ctx, int i) {
              final trader = traders[i];
              final isSelected = _selectedRecipient?.id == trader.id;

              return InkWell(
                onTap: () => setState(() => _selectedRecipient = trader),
                borderRadius: context.radius(theme.radii.sm),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.xs),
                    vertical: context.sp(theme.spacing.xs),
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: context.radius(theme.radii.sm),
                  ),
                  child: Row(
                    children: <Widget>[
                      UiAvatar(
                        name: trader.displayName,
                        imageUrl: trader.avatarUrl,
                        size: UiSize.xs,
                        verified: trader.verified,
                        verifiedColor: trader.verifiedColor(theme),
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Expanded(
                        child: Text(
                          '${trader.displayName} (@${trader.handle})',
                          style: context.uiText.caption.copyWith(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: theme.colors.foreground,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: context.sz(16),
                          color: theme.colors.primary,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Shared post snippet preview (if any)
        if (widget.post != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xs)),
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.sm),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.link_rounded,
                  size: context.sz(14),
                  color: theme.colors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Attaching post by @${widget.post!.author.handle}: "${widget.post!.body}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      fontSize: context.fs(11),
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: context.sp(theme.spacing.sm)),

        // Message input
        UiInput(
          value: _message,
          hintText: 'Add an optional comment...',
          onChanged: (val) => setState(() => _message = val),
        ),

        SizedBox(height: context.sp(theme.spacing.md)),

        // Action button
        UiButton(
          label: 'Send',
          variant: UiVariant.primary,
          onPressed: _selectedRecipient == null
              ? null
              : () {
                  widget.repository.sendDirectMessage(
                    _selectedRecipient!.id,
                    _message,
                    sharedPost: widget.post,
                  );
                  try {
                    final AppTrader trader = AppTrader(
                      id: _selectedRecipient!.id,
                      handle: _selectedRecipient!.handle,
                      displayName: _selectedRecipient!.displayName,
                      avatarUrl: _selectedRecipient!.avatarUrl,
                    );
                    final String threadId = MessagesRepositoryScope.repository
                        .startConversation(trader);
                    final String shareText = widget.post != null
                        ? (_message.isNotEmpty
                            ? '$_message\n\nShared post by @${widget.post!.author.handle}: "${widget.post!.body}"'
                            : 'Shared post by @${widget.post!.author.handle}: "${widget.post!.body}"')
                        : _message;
                    MessagesRepositoryScope.repository
                        .sendMessage(threadId, body: shareText);
                  } catch (_) {}
                  Navigator.of(context).pop();
                  UiToast.show(
                    context,
                    title: 'Message Sent',
                    message: 'Shared with @${_selectedRecipient!.handle}',
                    intent: UiIntent.success,
                  );
                },
        ),
      ],
    );
  }
}
