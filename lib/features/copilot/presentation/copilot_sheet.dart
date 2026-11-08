import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../data/copilot_controller.dart';
import 'copilot_screen.dart';

class CopilotSheet {
  static Future<void> show(
    BuildContext context, {
    required CopilotController repository,
    String? initialPrompt,
    String? contextTitle,
    String? contextSubtitle,
    IconData? contextIcon,
    AppLinkRef? contextRef,
    ValueChanged<AppLinkRef>? onOpenRef,
    VoidCallback? onOpenFullScreen,
  }) {
    if (!repository.generating) repository.newConversation();
    return UiDialog.present<void>(
      context: context,
      builder: (context) => Padding(
        padding: MediaQuery.viewInsetsOf(context),
        child: UiCard(
          padding: EdgeInsets.zero,
          borderless: true,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
                child: Row(
                  children: [
                    UiIconButton(
                      icon: Icons.close,
                      tooltip: 'Close copilot',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        contextTitle ?? 'Copilot',
                        style: context.uiText.heading,
                      ),
                    ),
                    if (onOpenFullScreen != null)
                      UiButton(
                        label: 'Open workspace',
                        variant: UiVariant.ghost,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onOpenFullScreen();
                        },
                      ),
                  ],
                ),
              ),
              Expanded(
                child: CopilotScreen(
                  repository: repository,
                  initialPrompt: initialPrompt,
                  onOpenRef: onOpenRef,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
