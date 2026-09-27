import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/presentation/widgets/messages_widgets.dart';

/// "New message" picker. Searches the trader directory and starts (or reopens)
/// a direct conversation. The candidate list is supplied by the caller — this
/// widget holds no trader data of its own.
class NewMessageDialog extends StatefulWidget {
  const NewMessageDialog({
    super.key,
    required this.repository,
    required this.candidates,
    this.onStarted,
  });

  final MessagesRepository repository;
  final List<AppTrader> candidates;

  /// Called with the thread id once a conversation is started.
  final void Function(String threadId)? onStarted;

  /// Opens the dialog. Returns the started thread id, if any.
  static Future<String?> show(
    BuildContext context, {
    required MessagesRepository repository,
    required List<AppTrader> candidates,
    void Function(String threadId)? onStarted,
  }) {
    return UiDialog.show<String>(
      context,
      child: MessagesDensityScope(
        child: NewMessageDialog(
          repository: repository,
          candidates: candidates,
          onStarted: onStarted,
        ),
      ),
    );
  }

  @override
  State<NewMessageDialog> createState() => _NewMessageDialogState();
}

class _NewMessageDialogState extends State<NewMessageDialog> {
  String _query = '';

  List<AppTrader> get _results {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.candidates;
    return widget.candidates
        .where((AppTrader t) =>
            (t.displayName ?? '').toLowerCase().contains(q) ||
            t.handle.toLowerCase().contains(q))
        .toList();
  }

  void _start(AppTrader peer) {
    final String id = widget.repository.startConversation(peer);
    widget.onStarted?.call(id);
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AppTrader> results = _results;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('New message', style: context.uiText.subheading),
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
        UiInput.search(
          hintText: 'Search traders you follow',
          value: _query,
          autofocus: true,
          onChanged: (String v) => setState(() => _query = v),
          onClear: () => setState(() => _query = ''),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.sz(360)),
          child: results.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                  child: UiEmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No traders found',
                    message: 'No one matches "${_query.trim()}".',
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: context.sp(theme.spacing.xxs)),
                  itemBuilder: (BuildContext context, int i) =>
                      _TraderRow(trader: results[i], onTap: () => _start(results[i])),
                ),
        ),
      ],
    );
  }
}

class _TraderRow extends StatelessWidget {
  const _TraderRow({required this.trader, required this.onTap});

  final AppTrader trader;
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
          decoration: BoxDecoration(
            color: state.hovered ? colors.surfaceHover : Colors.transparent,
            borderRadius: context.radius(theme.radii.md),
          ),
          child: Row(
            children: <Widget>[
              AppPresenceAvatar(
                imageUrl: trader.avatarUrl,
                name: trader.displayName ?? trader.handle,
                size: UiSize.sm,
                verified: trader.verified,
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      trader.displayName ?? '@${trader.handle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.bodyStrong,
                    ),
                    Text(
                      '@${trader.handle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: context.sz(theme.sizes.iconSm),
                color: colors.foregroundSubtle,
              ),
            ],
          ),
        );
      },
    );
  }
}
