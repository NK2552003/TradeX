import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';

class AiHistoryView extends StatefulWidget {
  final AiAssistantRepository repository;
  final String? selectedThreadId;
  final void Function(String) onSelectThread;
  final VoidCallback onNewThread;

  final String? searchQuery;

  const AiHistoryView({
    super.key,
    required this.repository,
    this.selectedThreadId,
    required this.onSelectThread,
    required this.onNewThread,
    this.searchQuery,
  });

  @override
  State<AiHistoryView> createState() => _AiHistoryViewState();
}

class _AiHistoryViewState extends State<AiHistoryView> {
  late AiAssistantRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _repository.addListener(_onRepositoryChanged);
    _searchQuery = widget.searchQuery ?? '';
    if (_searchQuery.isNotEmpty) {
      _searchController.text = _searchQuery;
    }
  }

  @override
  void didUpdateWidget(AiHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != null) {
      _searchQuery = widget.searchQuery!;
      _searchController.text = _searchQuery;
    }
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_onRepositoryChanged);
      _repository = widget.repository;
      _repository.addListener(_onRepositoryChanged);
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() {
    setState(() {});
  }

  void _handleLongPress(AiThread thread) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => SafeArea(
        top: false,
        child: Container(
          margin: EdgeInsets.all(ctx.sp(theme.spacing.sm)),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: ctx.radius(theme.radii.xl),
            border: Border.all(color: colors.border, width: theme.borders.hairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: ctx.sz(36),
                  height: ctx.sz(4),
                  margin: EdgeInsets.symmetric(vertical: ctx.sp(theme.spacing.xs)),
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ctx.sp(theme.spacing.md),
                  vertical: ctx.sp(theme.spacing.xxs),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        thread.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ctx.uiText.bodyStrong,
                      ),
                    ),
                  ],
                ),
              ),
              UiDivider(),
              _actionTile(
                ctx,
                icon: thread.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                label: thread.pinned ? 'Unpin thread' : 'Pin to top',
                onTap: () {
                  Navigator.pop(ctx);
                  _repository.togglePin(thread.id);
                },
              ),
              _actionTile(
                ctx,
                icon: Icons.edit_rounded,
                label: 'Rename thread',
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(thread);
                },
              ),
              _actionTile(
                ctx,
                icon: Icons.delete_outline_rounded,
                label: 'Delete thread',
                intent: UiIntent.danger,
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteDialog(thread);
                },
              ),
              SizedBox(height: ctx.sp(theme.spacing.xs)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    UiIntent intent = UiIntent.primary,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final Color color =
        intent == UiIntent.danger ? colors.destructive : colors.foreground;

    return UiInteractive(
      onTap: onTap,
      builder: (BuildContext ctx, UiInteractiveState state) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: ctx.sp(theme.spacing.md),
            vertical: ctx.sp(theme.spacing.sm),
          ),
          decoration: BoxDecoration(
            color: state.hovered ? colors.surfaceHover : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, size: ctx.sz(18), color: color),
              SizedBox(width: ctx.sp(theme.spacing.sm)),
              Expanded(
                child: Text(
                  label,
                  style: ctx.uiText.body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(AiThread thread) {
    final TextEditingController controller =
        TextEditingController(text: thread.title);
    UiDialog.show<void>(
      context,
      child: UiDialog(
        title: 'Rename Thread',
        content: Padding(
          padding:
              EdgeInsets.symmetric(vertical: context.sp(context.ui.spacing.sm)),
          child: UiInput(
            label: 'Thread Title',
            controller: controller,
            hintText: 'Enter new title…',
          ),
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.soft,
            intent: UiIntent.neutral,
            onPressed: () => Navigator.of(context).pop(),
          ),
          UiButton(
            label: 'Save',
            intent: UiIntent.primary,
            onPressed: () {
              final String trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                _repository.renameThread(thread.id, trimmed);
                UiToast.show(
                  context,
                  title: 'Renamed',
                  message: 'Thread title updated',
                  intent: UiIntent.success,
                );
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(AiThread thread) {
    UiDialog.show<void>(
      context,
      child: UiDialog(
        title: 'Delete Thread',
        content: Padding(
          padding:
              EdgeInsets.symmetric(vertical: context.sp(context.ui.spacing.sm)),
          child: Text(
            'Are you sure you want to delete "${thread.title}"? This conversation history cannot be recovered.',
            style: context.uiText.body,
          ),
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.soft,
            intent: UiIntent.neutral,
            onPressed: () => Navigator.of(context).pop(),
          ),
          UiButton(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            intent: UiIntent.danger,
            onPressed: () {
              _repository.deleteThread(thread.id);
              Navigator.of(context).pop();
              UiToast.show(
                context,
                title: 'Thread deleted',
                intent: UiIntent.neutral,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threads = _repository.threads.where((t) {
      if (_searchQuery.isEmpty) return true;
      return t.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final pinnedThreads = threads.where((t) => t.pinned).toList();
    final recentThreads = threads.where((t) => !t.pinned).toList();

    return AiDensityScope(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
            child: Row(
              children: [
                Expanded(
                  child: UiInput.search(
                    controller: _searchController,
                    hintText: 'Search chats...',
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
                SizedBox(width: context.sp(context.ui.spacing.sm)),
                UiIconButton(
                  icon: Icons.add_comment_outlined,
                  tooltip: 'New chat',
                  onPressed: widget.onNewThread,
                ),
              ],
            ),
          ),
          Expanded(
            child: threads.isEmpty
                ? AiEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No chats yet',
                    message: 'Start a new conversation to see your history here.',
                    action: UiButton(
                      label: 'New Chat',
                      onPressed: widget.onNewThread,
                    ),
                  )
                : ListView(
                    children: [
                      if (pinnedThreads.isNotEmpty) ...[
                        const AiSectionHeader(
                          title: 'Pinned',
                          icon: Icons.push_pin,
                        ),
                        ...pinnedThreads.map((thread) => AiThreadTile(
                              thread: thread,
                              selected: thread.id == widget.selectedThreadId,
                              onTap: () => widget.onSelectThread(thread.id),
                              onLongPress: () => _handleLongPress(thread),
                            )),
                      ],
                      if (recentThreads.isNotEmpty) ...[
                        const AiSectionHeader(
                          title: 'Recent',
                          icon: Icons.access_time,
                        ),
                        ...recentThreads.map((thread) => AiThreadTile(
                              thread: thread,
                              selected: thread.id == widget.selectedThreadId,
                              onTap: () => widget.onSelectThread(thread.id),
                              onLongPress: () => _handleLongPress(thread),
                            )),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
