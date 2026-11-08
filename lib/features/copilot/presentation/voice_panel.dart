import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../data/voice_controller.dart';

class CopilotVoicePanel extends StatelessWidget {
  const CopilotVoicePanel({super.key, required this.voice, required this.name});
  final CopilotVoiceController voice;
  final String name;
  @override
  Widget build(BuildContext context) {
    final elapsed =
        '${voice.seconds ~/ 60}:${(voice.seconds % 60).toString().padLeft(2, '0')}';
    return UiCard(
      variant: UiCardVariant.subtle,
      title: voice.connecting ? 'Connecting to $name…' : '$name · $elapsed',
      subtitle: 'AI-generated voice',
      trailing: UiIconButton(
        icon: voice.minimized ? Icons.open_in_full : Icons.close_fullscreen,
        tooltip: voice.minimized ? 'Expand call' : 'Minimize call',
        onPressed: voice.toggleMinimized,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!voice.minimized) ...[
            if (voice.userCaption.isNotEmpty)
              Text('You · ${voice.userCaption}', style: context.uiText.caption),
            UiGap.v(context.ui.spacing.sm),
            Text(
              voice.assistantCaption.isEmpty
                  ? 'Take your time. I’m listening.'
                  : voice.assistantCaption,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.body,
            ),
            UiGap.v(context.ui.spacing.md),
          ],
          Wrap(
            spacing: context.sp(context.ui.spacing.sm),
            children: [
              UiIconButton(
                icon: voice.microphoneMuted
                    ? Icons.mic_off_outlined
                    : Icons.mic_none,
                tooltip: voice.microphoneMuted
                    ? 'Unmute microphone'
                    : 'Mute microphone',
                onPressed: voice.toggleMicrophone,
              ),
              UiIconButton(
                icon: voice.speakerMuted
                    ? Icons.volume_off_outlined
                    : Icons.volume_up_outlined,
                tooltip: voice.speakerMuted ? 'Unmute speaker' : 'Mute speaker',
                onPressed: voice.toggleSpeaker,
              ),
              UiButton(
                label: 'End call',
                icon: Icons.call_end,
                intent: UiIntent.danger,
                variant: UiVariant.soft,
                onPressed: voice.end,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
