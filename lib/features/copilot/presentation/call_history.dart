import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import '../data/copilot_controller.dart';
import '../models/workspace.dart';

class CopilotCallHistory extends StatelessWidget {
  const CopilotCallHistory({
    super.key,
    required this.controller,
    required this.query,
    required this.onConversation,
  });
  final CopilotController controller;
  final String query;
  final VoidCallback onConversation;

  @override
  Widget build(BuildContext context) {
    final calls = controller.workspace.calls.reversed.where((call) {
      final thread = controller.workspace.threads
          .where((t) => t.id == call['threadId'])
          .firstOrNull;
      return '${thread?.title} ${call['transcript']}'.toLowerCase().contains(
        query.toLowerCase(),
      );
    }).toList();
    if (calls.isEmpty) {
      return const UiEmptyState(
        icon: Icons.call_outlined,
        title: 'Pick up a conversation',
        message:
            'Call transcripts and durations appear here after a voice session.',
      );
    }
    return ListView.separated(
      itemCount: calls.length,
      separatorBuilder: (_, _) => UiGap.v(context.ui.spacing.sm),
      itemBuilder: (context, index) {
        final call = calls[index];
        final thread = controller.workspace.threads
            .where((t) => t.id == call['threadId'])
            .firstOrNull;
        final start = DateTime.tryParse(textOf(call, 'startedAt'))?.toLocal();
        final end = DateTime.tryParse(textOf(call, 'endedAt'))?.toLocal();
        final duration = start != null && end != null
            ? end.difference(start).inSeconds
            : 0;
        return UiCard(
          variant: UiCardVariant.outlined,
          density: UiDensity.compact,
          title: thread?.title ?? 'Voice conversation',
          subtitle:
              '${start?.toString().split('.').first ?? ''} · ${duration ~/ 60}m ${duration % 60}s',
          trailing: UiBadge(
            label: textOf(call, 'status'),
            size: UiSize.xs,
            intent: switch (textOf(call, 'status')) {
              'completed' || 'done' => UiIntent.success,
              'active' || 'running' => UiIntent.info,
              'failed' || 'error' => UiIntent.danger,
              _ => UiIntent.neutral,
            },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UiAccordion(
                sections: [
                  UiAccordionSection(
                    title: 'Transcript',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final turn in records(call['transcript']))
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: context.sp(context.ui.spacing.sm),
                            ),
                            child: Text(
                              '${turn['role'] == 'user' ? 'You' : 'Copilot'}: ${textOf(turn, 'body')}',
                              style: context.uiText.body,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              UiGap.v(context.ui.spacing.sm),
              UiButton(
                label: 'Open conversation',
                trailingIcon: Icons.north_east,
                variant: UiVariant.soft,
                size: UiSize.xs,
                onPressed: thread == null || controller.conversationLocked
                    ? null
                    : () {
                        controller.selectThread(thread.id);
                        onConversation();
                      },
              ),
            ],
          ),
        );
      },
    );
  }
}
