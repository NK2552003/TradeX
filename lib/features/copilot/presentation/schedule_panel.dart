import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../data/copilot_controller.dart';
import '../models/workspace.dart';

class CopilotSchedulePanel extends StatelessWidget {
  const CopilotSchedulePanel({
    super.key,
    required this.controller,
    required this.query,
    required this.onConversation,
  });
  final CopilotController controller;
  final String query;
  final VoidCallback onConversation;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      UiButton(
        label: 'Schedule work',
        icon: Icons.add,
        variant: UiVariant.outline,
        onPressed: () => UiDialog.show<void>(
          context,
          maxWidth: 560,
          child: _ScheduleForm(controller: controller),
        ),
      ),
      UiGap.v(context.ui.spacing.md),
      Text(
        'Work returns to its original conversation, even while the app is closed. Keep the copilot service running.',
        style: context.uiText.caption,
      ),
      UiGap.v(context.ui.spacing.md),
      for (final task in controller.workspace.schedules.where(
        (t) => textOf(t, 'prompt').toLowerCase().contains(query.toLowerCase()),
      )) ...[
        UiCard(
          variant: UiCardVariant.outlined,
          density: UiDensity.compact,
          title: textOf(task, 'prompt'),
          subtitle:
              'Next: ${DateTime.tryParse(textOf(task, 'nextRunAt'))?.toLocal().toString().substring(0, 16) ?? '—'}',
          trailing: UiBadge(
            label: textOf(task, 'status'),
            size: UiSize.xs,
            intent: switch (textOf(task, 'status')) {
              'scheduled' => UiIntent.success,
              'running' => UiIntent.info,
              'paused' => UiIntent.warning,
              'failed' || 'error' => UiIntent.danger,
              _ => UiIntent.neutral,
            },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: context.sp(context.ui.spacing.xs),
                runSpacing: context.sp(context.ui.spacing.xs),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  UiButton(
                    label: 'Open conversation',
                    size: UiSize.xs,
                    variant: UiVariant.soft,
                    onPressed: controller.conversationLocked
                        ? null
                        : () {
                            controller.selectThread(task['threadId']);
                            onConversation();
                          },
                  ),
                  if (task['status'] != 'running') ...[
                    UiButton(
                      label: task['status'] == 'scheduled' ? 'Pause' : 'Resume',
                      size: UiSize.xs,
                      variant: UiVariant.outline,
                      onPressed: () => controller.action({
                        'action': 'schedule.control',
                        'id': task['id'],
                        'command': task['status'] == 'scheduled'
                            ? 'pause'
                            : 'resume',
                      }),
                    ),
                    UiButton(
                      label: 'Retry after review',
                      size: UiSize.xs,
                      variant: UiVariant.outline,
                      onPressed: () => controller.action({
                        'action': 'schedule.control',
                        'id': task['id'],
                        'command': 'retry',
                      }),
                    ),
                    UiIconButton(
                      icon: Icons.delete_outline,
                      size: UiSize.xs,
                      tooltip: 'Delete schedule',
                      onPressed: () => controller.action({
                        'action': 'schedule.control',
                        'id': task['id'],
                        'command': 'delete',
                      }),
                    ),
                  ],
                ],
              ),
              if (records(task['runs']).isNotEmpty) ...[
                UiGap.v(context.ui.spacing.sm),
                UiAccordion(
                  sections: [
                    UiAccordionSection(
                      title: 'Run history',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final run in records(
                            task['runs'],
                          ).reversed.take(10))
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: context.sp(context.ui.spacing.xs),
                              ),
                              child: Text(
                                '${run['status']} · ${run['startedAt']}\n${run['error'] ?? ''}'
                                    .trim(),
                                style: context.uiText.caption,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        UiGap.v(context.ui.spacing.md),
      ],
      if (controller.workspace.schedules.isEmpty)
        const UiEmptyState(
          icon: Icons.schedule,
          title: 'A head start, on schedule',
          message:
              'Set up a morning brief, a weekly review, or a one-time research task.',
        ),
    ],
  );
}

class _ScheduleForm extends StatefulWidget {
  const _ScheduleForm({required this.controller});
  final CopilotController controller;
  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  String _prompt = '';
  int _interval = 1440;
  late String _time = DateTime.now()
      .add(const Duration(hours: 1))
      .toIso8601String()
      .substring(0, 16);
  late String? _threadId =
      widget.controller.activeThreadId ??
      widget.controller.workspace.threads.firstOrNull?.id;
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    final time = DateTime.tryParse(_time);
    if (time == null || _threadId == null) {
      setState(
        () => _error =
            'Choose a conversation and enter a valid local date and time.',
      );
      return;
    }
    setState(() => _saving = true);
    final result = await widget.controller.action({
      'action': 'schedule.save',
      'threadId': _threadId,
      'prompt': _prompt,
      'intervalMinutes': _interval,
      'nextRunAt': time.toUtc().toIso8601String(),
    });
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => UiDialog(
    title: 'Give tomorrow a head start',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UiSelect<String>(
          label: 'Conversation',
          value: _threadId,
          expand: true,
          options: [
            for (final thread in widget.controller.workspace.threads)
              UiOption(label: thread.title, value: thread.id),
          ],
          onChanged: (v) => setState(() => _threadId = v),
        ),
        UiGap.v(context.ui.spacing.md),
        UiInput(
          label: 'What should be done?',
          value: _prompt,
          maxLines: 5,
          minLines: 3,
          onChanged: (v) => _prompt = v,
        ),
        UiGap.v(context.ui.spacing.md),
        UiInput(
          label: 'First run (your local time)',
          helperText: 'YYYY-MM-DD HH:MM',
          value: _time,
          onChanged: (v) => _time = v,
        ),
        UiGap.v(context.ui.spacing.md),
        UiSelect<int>(
          label: 'Repeat',
          value: _interval,
          expand: true,
          options: const [
            UiOption(label: 'Once', value: 0),
            UiOption(label: 'Every 15 minutes', value: 15),
            UiOption(label: 'Hourly', value: 60),
            UiOption(label: 'Daily', value: 1440),
            UiOption(label: 'Weekly', value: 10080),
          ],
          onChanged: (v) => setState(() => _interval = v),
        ),
        if (_error != null)
          UiCallout(
            title: 'Could not schedule',
            message: _error!,
            intent: UiIntent.warning,
          ),
      ],
    ),
    actions: [
      UiButton(
        label: 'Cancel',
        variant: UiVariant.ghost,
        onPressed: () => Navigator.of(context).pop(),
      ),
      UiButton(
        label: 'Schedule',
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
    ],
  );
}
