import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../data/copilot_controller.dart';
import '../models/workspace.dart';
import 'workspace_forms.dart';

class CopilotPageLibrary extends StatefulWidget {
  const CopilotPageLibrary({
    super.key,
    required this.controller,
    required this.query,
    required this.onOpen,
  });
  final CopilotController controller;
  final String query;
  final ValueChanged<WorkspacePage> onOpen;
  @override
  State<CopilotPageLibrary> createState() => _CopilotPageLibraryState();
}

class _CopilotPageLibraryState extends State<CopilotPageLibrary> {
  String? _spaceId;
  bool _grid = false;
  Future<void> _newPage({WorkspacePage? parent}) async {
    final defaultSpaceId =
        parent?.spaceId ??
        _spaceId ??
        widget.controller.workspace.spaces.firstOrNull?['id'];
    if (defaultSpaceId == null) return;
    final page = await widget.controller.action({
      'action': 'page.save',
      'title': 'Untitled page',
      'body': '',
      'spaceId': defaultSpaceId,
      if (parent != null) 'parentId': parent.id,
    });
    if (page != null) widget.onOpen(WorkspacePage.fromJson(page));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final pages = controller.workspace.pages
        .where(
          (p) =>
              (_spaceId == null || p.spaceId == _spaceId) &&
              '${p.title} ${p.body}'.toLowerCase().contains(
                widget.query.toLowerCase(),
              ),
        )
        .toList();
    final cards = <Widget>[
      for (final page in pages)
        UiCard(
          key: ValueKey(page.id),
          title: page.title,
          variant: UiCardVariant.outlined,
          density: UiDensity.compact,
          subtitle: page.parentId == null
              ? (controller.workspace.spaces
                        .where((s) => s['id'] == page.spaceId)
                        .firstOrNull?['name']
                    as String?)
              : '↳ ${controller.workspace.pages.where((p) => p.id == page.parentId).firstOrNull?.title ?? 'Subpage'}',
          onTap: () => widget.onOpen(page),
          trailing: UiDropdownMenu(
            alignRight: true,
            actions: [
              UiMenuItem(
                label: 'Add subpage',
                icon: Icons.post_add,
                onPressed: () => _newPage(parent: page),
              ),
              UiMenuItem(
                label: 'Delete',
                destructive: true,
                icon: Icons.delete_outline,
                onPressed: () => confirmWorkspaceDelete(
                  context,
                  controller,
                  'page.delete',
                  page.id,
                  page.title,
                ),
              ),
            ],
            child: UiIconButton(
              icon: Icons.more_horiz,
              size: UiSize.sm,
              tooltip: 'Page actions',
              onPressed: () {},
            ),
          ),
          child: Text(
            page.body.isEmpty
                ? 'Start writing…'
                : page.body.replaceAll(RegExp(r'[#*`\n]'), ' '),
            maxLines: _grid ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.caption.copyWith(
              color: context.ui.colors.foregroundMuted,
            ),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: UiSelect<String>(
                value: _spaceId ?? '',
                expand: true,
                options: [
                  const UiOption(label: 'All spaces', value: ''),
                  for (final space in controller.workspace.spaces)
                    UiOption(label: space['name'], value: space['id']),
                ],
                onChanged: (v) =>
                    setState(() => _spaceId = v.isEmpty ? null : v),
              ),
            ),
            UiIconButton(
              icon: _grid ? Icons.view_list_outlined : Icons.grid_view_outlined,
              tooltip: _grid ? 'List view' : 'Grid view',
              onPressed: () => setState(() => _grid = !_grid),
            ),
            UiDropdownMenu(
              alignRight: true,
              actions: [
                UiMenuItem(
                  label: 'New space',
                  icon: Icons.create_new_folder_outlined,
                  onPressed: () => showWorkspaceTextForm(
                    context,
                    controller,
                    title: 'New space',
                    action: 'space.save',
                    fields: {'name': 'Name', 'description': 'Description'},
                  ),
                ),
                if (_spaceId != null &&
                    controller.workspace.spaces.any(
                      (s) => s['id'] == _spaceId,
                    )) ...[
                  UiMenuItem(
                    label: 'Rename space',
                    icon: Icons.edit_outlined,
                    onPressed: () => showWorkspaceTextForm(
                      context,
                      controller,
                      title: 'Edit space',
                      action: 'space.save',
                      initial:
                          controller.workspace.spaces
                              .where((s) => s['id'] == _spaceId)
                              .firstOrNull ??
                          const <String, dynamic>{},
                      fields: {'name': 'Name', 'description': 'Description'},
                    ),
                  ),
                  UiMenuItem(
                    label: 'Delete space',
                    icon: Icons.delete_outline,
                    destructive: true,
                    onPressed: () => confirmWorkspaceDelete(
                      context,
                      controller,
                      'space.delete',
                      _spaceId!,
                      'space',
                    ),
                  ),
                ],
              ],
              child: UiIconButton(
                icon: Icons.more_horiz,
                tooltip: 'Space options',
                onPressed: () {},
              ),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.sm),
        UiButton(
          label: 'New page',
          icon: Icons.add,
          variant: UiVariant.outline,
          onPressed: _newPage,
        ),
        UiGap.v(context.ui.spacing.md),
        Expanded(
          child: pages.isEmpty
              ? const UiEmptyState(
                  icon: Icons.description_outlined,
                  title: 'Keep the useful things',
                  message:
                      'Write a page or save an answer from a conversation.',
                )
              : SingleChildScrollView(
                  child: _grid
                      ? UiCardGrid(minTileWidth: 180, children: cards)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < cards.length; i++) ...[
                              if (i > 0) UiGap.v(context.ui.spacing.sm),
                              cards[i],
                            ],
                          ],
                        ),
                ),
        ),
      ],
    );
  }
}
