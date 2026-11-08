import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_preview.dart';

import '../data/copilot_controller.dart';
import '../models/workspace.dart';
import 'workspace_forms.dart';

class CopilotMemorySettings extends StatelessWidget {
  const CopilotMemorySettings({
    super.key,
    required this.controller,
    required this.query,
  });
  final CopilotController controller;
  final String query;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Text('A little context, remembered.', style: context.uiText.heading),
      UiGap.v(context.ui.spacing.sm),
      Text(
        'Preferences are used only by specialists with memory access.',
        style: context.uiText.caption,
      ),
      UiGap.v(context.ui.spacing.md),
      UiButton(
        label: 'Add a preference',
        icon: Icons.add,
        variant: UiVariant.outline,
        onPressed: () => showWorkspaceTextForm(
          context,
          controller,
          title: 'Remember a preference',
          action: 'memory.save',
          fields: {'text': 'What should your specialists know?'},
          multiline: {'text'},
        ),
      ),
      for (final memory in controller.workspace.memories.where(
        (m) => textOf(m, 'text').toLowerCase().contains(query.toLowerCase()),
      ))
        UiCard(
          variant: UiCardVariant.ghost,
          trailing: UiDropdownMenu(
            actions: [
              UiMenuItem(
                label: 'Edit',
                onPressed: () => showWorkspaceTextForm(
                  context,
                  controller,
                  title: 'Edit preference',
                  action: 'memory.save',
                  initial: memory,
                  fields: {'text': 'Preference'},
                  multiline: {'text'},
                ),
              ),
              UiMenuItem(
                label: 'Delete',
                destructive: true,
                onPressed: () => confirmWorkspaceDelete(
                  context,
                  controller,
                  'memory.delete',
                  memory['id'],
                  'preference',
                ),
              ),
            ],
            child: const Icon(Icons.more_horiz),
          ),
          child: Text(textOf(memory, 'text'), style: context.uiText.body),
        ),
      UiGap.v(context.ui.spacing.lg),
      const UiDivider(),
      UiGap.v(context.ui.spacing.md),
      Text('Learning library', style: context.uiText.heading),
      Text(
        'Review lessons suggested by your specialists. Only published lessons are used in future work.',
        style: context.uiText.caption,
      ),
      for (final skill in controller.workspace.skills.where(
        (s) => textOf(s, 'title').toLowerCase().contains(query.toLowerCase()),
      ))
        UiCard(
          variant: UiCardVariant.outlined,
          title: textOf(skill, 'title'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichMarkdownPreview(data: textOf(skill, 'instructions')),
              UiGap.v(context.ui.spacing.sm),
              Text(
                'Evidence: ${textOf(skill, 'evidence')}',
                style: context.uiText.caption,
              ),
              UiSwitch(
                label: 'Published',
                value: skill['published'] == true,
                onChanged: (v) => controller.action({
                  'action': 'skill.publish',
                  'id': skill['id'],
                  'published': v,
                }),
              ),
              UiButton(
                label: 'Delete lesson',
                variant: UiVariant.ghost,
                intent: UiIntent.danger,
                onPressed: () => confirmWorkspaceDelete(
                  context,
                  controller,
                  'skill.delete',
                  skill['id'],
                  textOf(skill, 'title'),
                ),
              ),
            ],
          ),
        ),
      if (controller.workspace.skills.isEmpty)
        const UiEmptyState(
          icon: Icons.auto_stories_outlined,
          title: 'Learning starts with a conversation',
          message:
              'Enable lessons in a specialist’s settings. Useful patterns can then be proposed for your review.',
        ),
    ],
  );
}

class CopilotSettings extends StatelessWidget {
  const CopilotSettings({super.key, required this.controller});
  final CopilotController controller;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Text('Make this space yours.', style: context.uiText.heading),
      UiGap.v(context.ui.spacing.lg),
      UiSelect<String>(
        label: 'Appearance',
        value: textOf(controller.workspace.settings, 'appearance', 'system'),
        expand: true,
        options: const [
          UiOption(label: 'Follow app', value: 'system'),
          UiOption(label: 'Light', value: 'light'),
          UiOption(label: 'Dark', value: 'dark'),
        ],
        onChanged: (v) =>
            controller.action({'action': 'settings.save', 'appearance': v}),
      ),
      UiGap.v(context.ui.spacing.lg),
      for (final entry in {
        'paused': 'Pause all AI work',
        'research': 'Allow web research',
        'memory': 'Allow saved preferences',
        'apps': 'Allow connected apps',
      }.entries)
        UiSwitch(
          label: entry.value,
          value: controller.workspace.settings[entry.key] == true,
          onChanged: (v) =>
              controller.action({'action': 'settings.save', entry.key: v}),
        ),
      UiGap.v(context.ui.spacing.md),
      Text(
        'Specialists also have individual permissions. Both must be enabled for access.',
        style: context.uiText.caption,
      ),
      UiGap.v(context.ui.spacing.lg),
      const UiDivider(),
      UiGap.v(context.ui.spacing.lg),
      UiBadge(
        label: controller.connected ? 'Connected' : 'Service offline',
        intent: controller.connected ? UiIntent.success : UiIntent.warning,
      ),
      UiGap.v(context.ui.spacing.sm),
      Text(
        controller.connected
            ? 'OpenAI powers conversations, research, data analysis, and calls. Scheduled work runs while the copilot service is online.'
            : 'Start the copilot service to connect this workspace.',
        style: context.uiText.body,
      ),
      UiGap.v(context.ui.spacing.md),
      if (!controller.connected) ...[
        SelectableText('dart run bin/copilot.dart', style: context.uiText.mono),
        UiGap.v(context.ui.spacing.sm),
        Text(
          'The service reads OPEN_AI_KEY from .env. For a device or hosted build, configure COPILOT_API_URL to point to your service.',
          style: context.uiText.caption,
        ),
      ],
      UiButton(
        label: 'Reconnect',
        variant: UiVariant.outline,
        onPressed: () => controller.reload(),
      ),
    ],
  );
}
