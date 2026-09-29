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
  int _mode = 0; // 0 = Direct, 1 = Group
  String _query = '';
  final TextEditingController _groupTitleController = TextEditingController();
  final Set<AppTrader> _selectedTraders = <AppTrader>{};

  @override
  void dispose() {
    _groupTitleController.dispose();
    super.dispose();
  }

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

  void _createGroup() {
    final String title = _groupTitleController.text.trim();
    if (title.isEmpty || _selectedTraders.isEmpty) return;
    final String id = widget.repository.startGroupConversation(
      title: title,
      participants: _selectedTraders.toList(),
    );
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
              child: Text(
                _mode == 0 ? 'New message' : 'New group conversation',
                style: context.uiText.subheading,
              ),
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
        UiToggleGroup<int>(
          value: _mode,
          variant: UiToggleGroupVariant.segmented,
          options: const <UiToggleOption<int>>[
            UiToggleOption<int>(
              value: 0,
              label: 'Direct',
              icon: Icons.person_outline_rounded,
            ),
            UiToggleOption<int>(
              value: 1,
              label: 'Group',
              icon: Icons.groups_outlined,
            ),
          ],
          onChanged: (int val) => setState(() => _mode = val),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        if (_mode == 1) ...<Widget>[
          UiInput(
            label: 'Group Name',
            hintText: 'e.g. Breakout Squad, Alpha Desk',
            controller: _groupTitleController,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          if (_selectedTraders.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
              child: Text(
                '${_selectedTraders.length} members selected',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        UiInput.search(
          hintText: _mode == 0 ? 'Search traders you follow' : 'Add traders to group',
          value: _query,
          onChanged: (String v) => setState(() => _query = v),
          onClear: () => setState(() => _query = ''),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.sz(280)),
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
                  itemBuilder: (BuildContext context, int i) {
                    final AppTrader trader = results[i];
                    final bool isSelected = _selectedTraders.contains(trader);
                    return _TraderRow(
                      trader: trader,
                      isSelectable: _mode == 1,
                      isSelected: isSelected,
                      onTap: () {
                        if (_mode == 0) {
                          _start(trader);
                        } else {
                          setState(() {
                            if (isSelected) {
                              _selectedTraders.remove(trader);
                            } else {
                              _selectedTraders.add(trader);
                            }
                          });
                        }
                      },
                    );
                  },
                ),
        ),
        if (_mode == 1) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.md)),
          UiButton(
            label: 'Create Group (${_selectedTraders.length})',
            icon: Icons.group_add_rounded,
            intent: UiIntent.primary,
            onPressed: (_groupTitleController.text.trim().isNotEmpty &&
                    _selectedTraders.isNotEmpty)
                ? _createGroup
                : null,
          ),
        ],
      ],
    );
  }
}

class _TraderRow extends StatelessWidget {
  const _TraderRow({
    required this.trader,
    required this.onTap,
    this.isSelectable = false,
    this.isSelected = false,
  });

  final AppTrader trader;
  final VoidCallback onTap;
  final bool isSelectable;
  final bool isSelected;

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
            color: isSelected
                ? colors.primary.withValues(alpha: 0.08)
                : (state.hovered ? colors.surfaceHover : Colors.transparent),
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
              if (isSelectable)
                UiCheckbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                )
              else
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
