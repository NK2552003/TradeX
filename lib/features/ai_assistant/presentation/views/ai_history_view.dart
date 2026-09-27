import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';

class AiHistoryView extends StatefulWidget {
  final AiAssistantRepository repository;
  final String? selectedThreadId;
  final void Function(String) onSelectThread;
  final VoidCallback onNewThread;

  const AiHistoryView({
    super.key,
    required this.repository,
    this.selectedThreadId,
    required this.onSelectThread,
    required this.onNewThread,
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
  }

  @override
  void didUpdateWidget(AiHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(thread.pinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(thread.pinned ? 'Unpin' : 'Pin'),
              onTap: () {
                _repository.togglePin(thread.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(thread);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                _repository.deleteThread(thread.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(AiThread thread) {
    final controller = TextEditingController(text: thread.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Thread'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'New title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _repository.renameThread(thread.id, controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
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
                UiButton(
                  leadingIcon: Icons.add,
                  label: 'New chat',
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
