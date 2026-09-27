import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/widgets/messages_widgets.dart';

/// Sends a Writing-Desk record ([AppLinkRef]) into a direct conversation.
///
/// The universal "share to a chat" entry point: any feature (community post,
/// journal entry, strategy, note) can call [show] with the record to share and
/// the user picks a thread and adds an optional note. Threads come from the
/// repository; the reference is passed in.
class ShareToConversationDialog extends StatefulWidget {
  const ShareToConversationDialog({
    super.key,
    required this.repository,
    required this.reference,
    this.onShared,
  });

  final MessagesRepository repository;
  final AppLinkRef reference;

  /// Called with the destination thread id after sending.
  final void Function(String threadId)? onShared;

  static Future<void> show(
    BuildContext context, {
    required MessagesRepository repository,
    required AppLinkRef reference,
    void Function(String threadId)? onShared,
  }) {
    return UiDialog.show<void>(
      context,
      child: MessagesDensityScope(
        child: ShareToConversationDialog(
          repository: repository,
          reference: reference,
          onShared: onShared,
        ),
      ),
    );
  }

  @override
  State<ShareToConversationDialog> createState() =>
      _ShareToConversationDialogState();
}

class _ShareToConversationDialogState extends State<ShareToConversationDialog> {
  final TextEditingController _note = TextEditingController();
  String _query = '';
  String? _selectedId;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<MessageThread> get _results {
    final List<MessageThread> threads = widget.repository.threads;
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return threads;
    return threads
        .where((MessageThread t) =>
            t.title.toLowerCase().contains(q) ||
            t.peer.handle.toLowerCase().contains(q))
        .toList();
  }

  void _share() {
    final String? id = _selectedId;
    if (id == null) return;
    widget.repository.sendSharedRef(id, widget.reference, note: _note.text.trim());
    widget.onShared?.call(id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<MessageThread> results = _results;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Share to chat', style: context.uiText.subheading),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              size: UiSize.sm,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        AppLinkRefTile(ref: widget.reference),
        SizedBox(height: context.sp(theme.spacing.sm)),
        UiInput.search(
          hintText: 'Search conversations',
          value: _query,
          onChanged: (String v) => setState(() => _query = v),
          onClear: () => setState(() => _query = ''),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.sz(260)),
          child: results.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                  child: const UiEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No conversations',
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (BuildContext context, int i) {
                    final MessageThread t = results[i];
                    return _PickerRow(
                      thread: t,
                      selected: t.id == _selectedId,
                      onTap: () => setState(() => _selectedId = t.id),
                    );
                  },
                ),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        UiInput(
          label: 'Add a note (optional)',
          controller: _note,
          hintText: 'Say something about this…',
          minLines: 1,
          maxLines: 3,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Row(
          children: <Widget>[
            Expanded(
              child: UiButton(
                label: 'Cancel',
                variant: UiVariant.soft,
                intent: UiIntent.neutral,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: UiButton(
                label: 'Send',
                icon: Icons.send_rounded,
                intent: UiIntent.primary,
                onPressed: _selectedId == null ? null : _share,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.thread,
    required this.selected,
    required this.onTap,
  });

  final MessageThread thread;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return UiInteractive(
      onTap: onTap,
      builder: (BuildContext context, UiInteractiveState state) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.xs),
            vertical: context.sp(theme.spacing.xs),
          ),
          margin: EdgeInsets.only(bottom: context.sp(theme.spacing.xxs)),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.10)
                : (state.hovered ? colors.surfaceHover : Colors.transparent),
            borderRadius: context.radius(theme.radii.md),
            border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
              width: theme.borders.hairline,
            ),
          ),
          child: Row(
            children: <Widget>[
              MessagesThreadAvatar(
                thread: thread,
                size: UiSize.sm,
                showPresence: false,
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Text(
                  thread.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.bodyStrong,
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: context.sz(theme.sizes.iconSm),
                  color: colors.primary,
                ),
            ],
          ),
        );
      },
    );
  }
}
