import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';

class AiPersonaDialog extends StatelessWidget {
  final AiPersona current;

  const AiPersonaDialog({super.key, required this.current});

  static Future<AiPersona?> show(BuildContext context, {required AiPersona current}) {
    return showDialog<AiPersona>(
      context: context,
      builder: (context) => AiPersonaDialog(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AiDensityScope(
      child: UiDialog(
        title: 'Choose your lens',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('The persona shapes how the copilot frames its answers', style: context.uiText.body),
            SizedBox(height: context.sp(context.ui.spacing.md)),
            AiPersonaSelector(
              selected: current,
              onChanged: (persona) {
                Navigator.of(context).pop(persona);
              },
            ),
          ],
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
