import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

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
    return UiDrawer.show<void>(
      context,
      title: contextTitle ?? 'Copilot',
      width: 600,
      fromRight: true,
      scrollable: false,
      contentPadding: EdgeInsets.zero,
      footer: onOpenFullScreen == null
          ? null
          : Builder(
              builder: (context) => UiButton(
                label: 'Open workspace',
                variant: UiVariant.ghost,
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenFullScreen();
                },
              ),
            ),
      child: LayoutBuilder(
        builder: (context, constraints) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: constraints.biggest, viewInsets: EdgeInsets.zero),
          child: CopilotScreen(
            repository: repository,
            initialPrompt: initialPrompt,
            onOpenRef: onOpenRef,
            embedInScaffold: false,
          ),
        ),
      ),
    );
  }
}
