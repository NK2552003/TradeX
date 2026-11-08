import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_preview.dart';

import '../data/copilot_controller.dart';
import '../models/workspace.dart';

class CopilotReviewCard extends StatelessWidget {
  const CopilotReviewCard({
    super.key,
    required this.controller,
    required this.approval,
  });
  final CopilotController controller;
  final Json approval;
  @override
  Widget build(BuildContext context) {
    final args = Map<String, dynamic>.from(approval['arguments']);
    final isPage = approval['kind'] == 'propose_page';
    final isExternal =
        approval['kind'] == 'mcp' ||
        approval['kind'] == 'propose_computer_action';
    return UiCard(
      variant: UiCardVariant.outlined,
      title: isExternal
          ? '${approval['connectionName'] ?? 'Computer'} · ${approval['name'] ?? args['action']}'
          : isPage
          ? 'Review this page'
          : 'Keep this for later?',
      subtitle: isExternal
          ? textOf(approval, 'url')
          : 'Nothing is saved until you approve.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPage)
            Text(textOf(args, 'title'), style: context.uiText.heading),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: context.sz(280)),
            child: SingleChildScrollView(
              child: isExternal
                  ? SelectableText(
                      const JsonEncoder.withIndent('  ').convert(args),
                      style: context.uiText.mono,
                    )
                  : RichMarkdownPreview(
                      data: textOf(
                        args,
                        isPage
                            ? 'body'
                            : approval['kind'] == 'propose_skill'
                            ? 'instructions'
                            : 'text',
                      ),
                    ),
            ),
          ),
          UiGap.v(context.ui.spacing.md),
          Wrap(
            spacing: context.sp(context.ui.spacing.sm),
            children: [
              UiButton(
                label: isExternal
                    ? 'Approve & run'
                    : isPage
                    ? 'Approve & save'
                    : 'Approve',
                onPressed: controller.generating
                    ? null
                    : () => controller.decide(approval, true),
              ),
              UiButton(
                label: 'Decline',
                variant: UiVariant.ghost,
                onPressed: controller.generating
                    ? null
                    : () => controller.decide(approval, false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
