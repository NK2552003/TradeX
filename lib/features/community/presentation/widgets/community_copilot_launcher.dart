import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/copilot/copilot.dart';

Future<void> showCommunityCopilot(
  BuildContext context, {
  String? initialPrompt,
}) => CopilotSheet.show(
  context,
  repository: CopilotScope.repository,
  contextTitle: 'Community copilot',
  initialPrompt: initialPrompt,
);

class CommunityCopilotLauncher extends StatefulWidget {
  const CommunityCopilotLauncher({
    super.key,
    this.onCompose,
    this.showCompose = false,
  });
  final VoidCallback? onCompose;
  final bool showCompose;

  @override
  State<CommunityCopilotLauncher> createState() =>
      _CommunityCopilotLauncherState();
}

class _CommunityCopilotLauncherState extends State<CommunityCopilotLauncher> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => UiCard(
    variant: UiCardVariant.elevated,
    padding: EdgeInsets.all(context.sp(context.ui.spacing.xs)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showCompose && widget.onCompose != null) ...[
          UiIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Create post',
            onPressed: widget.onCompose,
          ),
          UiGap.v(context.ui.spacing.xs),
        ],
        UiIconButton(
          icon: Icons.chat_bubble_outline,
          tooltip: 'Ask copilot',
          onPressed: _open
              ? null
              : () async {
                  setState(() => _open = true);
                  try {
                    await showCommunityCopilot(context);
                  } finally {
                    if (mounted) setState(() => _open = false);
                  }
                },
        ),
      ],
    ),
  );
}
