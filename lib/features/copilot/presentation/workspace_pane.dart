import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../data/copilot_controller.dart';
import '../models/workspace.dart';
import 'connection_settings.dart';
import 'call_history.dart';
import 'computer_panel.dart';
import 'memory_settings.dart';
import 'page_library.dart';
import 'schedule_panel.dart';
import 'specialist_editor.dart';
import 'workspace_forms.dart';

enum WorkspaceSection {
  conversations('Conversations', Icons.chat_bubble_outline),
  pages('Spaces', Icons.folder_open_outlined),
  specialists('Specialists', Icons.people_outline),
  work('Scheduled work', Icons.schedule_outlined),
  calls('Call history', Icons.call_outlined),
  memory('Memory & learning', Icons.bookmark_border),
  connections('Connections', Icons.extension_outlined),
  computer('Computer', Icons.computer_outlined),
  settings('Settings', Icons.tune_rounded);

  const WorkspaceSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class CopilotWorkspacePane extends StatefulWidget {
  const CopilotWorkspacePane({
    super.key,
    required this.controller,
    required this.onConversation,
    required this.onPage,
    required this.onClose,
    this.searchQuery = '',
  });
  final CopilotController controller;
  final VoidCallback onConversation;
  final ValueChanged<WorkspacePage> onPage;
  final VoidCallback onClose;
  final String searchQuery;
  @override
  State<CopilotWorkspacePane> createState() => _CopilotWorkspacePaneState();
}

class _CopilotWorkspacePaneState extends State<CopilotWorkspacePane> {
  WorkspaceSection _section = WorkspaceSection.conversations;
  late String _query = widget.searchQuery;
  @override
  void didUpdateWidget(CopilotWorkspacePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      _query = widget.searchQuery;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: UiSelect<WorkspaceSection>(
                value: _section,
                expand: true,
                variant: UiInputVariant.ghost,
                options: [
                  for (final section in WorkspaceSection.values)
                    UiOption(label: section.label, value: section),
                ],
                onChanged: (value) => setState(() => _section = value),
              ),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close workspace',
              onPressed: widget.onClose,
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.md),
        if (_section != WorkspaceSection.settings)
          UiInput.search(
            value: _query,
            hintText: 'Search ${_section.label.toLowerCase()}',
            onChanged: (v) => setState(() => _query = v),
            onClear: () => setState(() => _query = ''),
          ),
        UiGap.v(context.ui.spacing.md),
        Expanded(
          child: switch (_section) {
            WorkspaceSection.conversations => _Conversations(
              controller: controller,
              query: _query,
              onOpen: widget.onConversation,
            ),
            WorkspaceSection.pages => CopilotPageLibrary(
              controller: controller,
              query: _query,
              onOpen: widget.onPage,
            ),
            WorkspaceSection.specialists => _Specialists(
              controller: controller,
              query: _query,
              onOpen: widget.onConversation,
            ),
            WorkspaceSection.work => CopilotSchedulePanel(
              controller: controller,
              query: _query,
              onConversation: widget.onConversation,
            ),
            WorkspaceSection.calls => CopilotCallHistory(
              controller: controller,
              query: _query,
              onConversation: widget.onConversation,
            ),
            WorkspaceSection.memory => CopilotMemorySettings(
              controller: controller,
              query: _query,
            ),
            WorkspaceSection.connections => CopilotConnections(
              controller: controller,
              query: _query,
            ),
            WorkspaceSection.computer => CopilotComputerPanel(
              controller: controller,
            ),
            WorkspaceSection.settings => CopilotSettings(
              controller: controller,
            ),
          },
        ),
      ],
    );
  }
}

class _Conversations extends StatelessWidget {
  const _Conversations({
    required this.controller,
    required this.query,
    required this.onOpen,
  });
  final CopilotController controller;
  final String query;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final threads =
        controller.workspace.threads
            .where(
              (t) =>
                  t.title.toLowerCase().contains(query.toLowerCase()) ||
                  t.messages.any(
                    (m) => m.body.toLowerCase().contains(query.toLowerCase()),
                  ),
            )
            .toList()
          ..sort(
            (a, b) => a.pinned == b.pinned
                ? textOf(
                    b.json,
                    'updatedAt',
                  ).compareTo(textOf(a.json, 'updatedAt'))
                : a.pinned
                ? -1
                : 1,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiButton(
          label: 'New conversation',
          icon: Icons.add,
          variant: UiVariant.outline,
          onPressed: controller.conversationLocked
              ? null
              : () {
                  controller.newConversation();
                  onOpen();
                },
        ),
        UiGap.v(context.ui.spacing.md),
        Expanded(
          child: threads.isEmpty
              ? const UiEmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'Room for your next idea',
                  message: 'Your conversations will be kept here.',
                )
              : ListView.separated(
                  itemCount: threads.length,
                  separatorBuilder: (_, _) => const UiDivider(),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    return UiCard(
                      variant: UiCardVariant.ghost,
                      selected: controller.activeThreadId == thread.id,
                      onTap: controller.conversationLocked
                          ? null
                          : () {
                              controller.selectThread(thread.id);
                              onOpen();
                            },
                      title: thread.title,
                      subtitle:
                          '${controller.workspace.specialists.where((s) => s.id == thread.specialistId).firstOrNull?.name ?? 'Specialist'} · ${thread.messages.length} messages',
                      trailing: UiDropdownMenu(
                        actions: [
                          UiMenuItem(
                            label: thread.pinned ? 'Unpin' : 'Pin',
                            icon: Icons.push_pin_outlined,
                            onPressed: () => controller.action({
                              'action': 'thread.update',
                              'id': thread.id,
                              'pinned': !thread.pinned,
                            }),
                          ),
                          UiMenuItem(
                            label: 'Rename',
                            icon: Icons.edit_outlined,
                            onPressed: () => showWorkspaceTextForm(
                              context,
                              controller,
                              title: 'Rename conversation',
                              action: 'thread.update',
                              initial: {'id': thread.id, 'title': thread.title},
                              fields: {'title': 'Title'},
                            ),
                          ),
                          UiMenuItem(
                            label: 'Delete',
                            icon: Icons.delete_outline,
                            destructive: true,
                            onPressed: () => confirmWorkspaceDelete(
                              context,
                              controller,
                              'thread.delete',
                              thread.id,
                              thread.title,
                            ),
                          ),
                        ],
                        child: const Icon(Icons.more_horiz),
                      ),
                      child: thread.status == 'idle'
                          ? const SizedBox.shrink()
                          : UiBadge(
                              label: thread.status,
                              intent: UiIntent.neutral,
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Specialists extends StatelessWidget {
  const _Specialists({
    required this.controller,
    required this.query,
    required this.onOpen,
  });
  final CopilotController controller;
  final String query;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      UiButton(
        label: 'Create specialist',
        icon: Icons.add,
        variant: UiVariant.outline,
        onPressed: () => showSpecialistEditor(context, controller),
      ),
      UiGap.v(context.ui.spacing.md),
      for (final specialist in controller.workspace.specialists.where(
        (s) =>
            '${s.name} ${s.role}'.toLowerCase().contains(query.toLowerCase()),
      ))
        UiCard(
          variant: UiCardVariant.ghost,
          title: specialist.name,
          subtitle: specialist.role,
          leading: UiAvatar(name: specialist.name),
          trailing: UiIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit ${specialist.name}',
            onPressed: () => showSpecialistEditor(
              context,
              controller,
              specialist: specialist,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                specialist.instructions,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: context.ui.colors.foregroundMuted,
                ),
              ),
              UiGap.v(context.ui.spacing.sm),
              UiButton(
                label: 'Start a conversation',
                trailingIcon: Icons.north_east,
                variant: UiVariant.ghost,
                onPressed: controller.conversationLocked
                    ? null
                    : () {
                        controller.newConversation(specialist: specialist.id);
                        onOpen();
                      },
              ),
            ],
          ),
        ),
    ],
  );
}
