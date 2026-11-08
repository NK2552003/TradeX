import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../data/voice_controller.dart';

/// Redesigned, professional AI Voice Assistant Card with fluid open/close animations,
/// seamless minimized bar / expanded studio states, waveform visuals, and rich actions.
class CopilotVoicePanel extends StatefulWidget {
  const CopilotVoicePanel({
    super.key,
    required this.voice,
    required this.name,
    this.onClose,
  });

  final CopilotVoiceController voice;
  final String name;
  final VoidCallback? onClose;

  @override
  State<CopilotVoicePanel> createState() => _CopilotVoicePanelState();
}

class _CopilotVoicePanelState extends State<CopilotVoicePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.voice.minimized ? 0.0 : 1.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(CopilotVoicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.voice.minimized && _anim.value > 0.0) {
      _anim.reverse();
    } else if (!widget.voice.minimized && _anim.value < 1.0) {
      _anim.forward();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final CopilotVoiceController voice = widget.voice;
    final String name = widget.name;
    final String elapsed =
        '${voice.seconds ~/ 60}:${(voice.seconds % 60).toString().padLeft(2, '0')}';

    final UiIntent stageIntent = switch (voice.stage) {
      CopilotVoiceStage.speaking => UiIntent.primary,
      CopilotVoiceStage.listening => UiIntent.success,
      CopilotVoiceStage.thinking => UiIntent.info,
      CopilotVoiceStage.muted => UiIntent.warning,
      _ => UiIntent.neutral,
    };

    final Color accentColor = stageIntent.color(context);

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (BuildContext context, Widget? child) {
        return UiCard(
          key: const ValueKey('copilot-voice-panel'),
          variant: UiCardVariant.elevated,
          accentColor: accentColor,
          borderRadius: context.radius(theme.radii.xl),
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.sm),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header Row: Agent name & status, waveform preview when compact, badges & controls
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // Pulsing voice icon indicator
                  Container(
                    width: context.sz(34),
                    height: context.sz(34),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        voice.stage == CopilotVoiceStage.speaking
                            ? Icons.volume_up_rounded
                            : (voice.microphoneMuted
                                ? Icons.mic_off_rounded
                                : Icons.graphic_eq_rounded),
                        size: context.sz(16),
                        color: accentColor,
                      ),
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  // Specialist name & subline info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          voice.connecting
                              ? 'Connecting to $name…'
                              : '$name · $elapsed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.bodyStrong.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: context.fs(13),
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        Text(
                          'Natural-language voice (${voice.voiceModel.label} · ${voice.voiceModel.description})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                            fontSize: context.fs(11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  // Live status badge (Listening, Speaking, Thinking, etc.)
                  UiBadge(
                    label: voice.stage.label,
                    intent: stageIntent,
                    size: UiSize.xs,
                    variant: UiBadgeVariant.soft,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  // Voice persona selector dropdown in header
                  SizedBox(
                    width: context.sz(105),
                    child: UiSelect<CopilotVoiceModel>(
                      value: voice.voiceModel,
                      size: UiSize.xs,
                      expand: true,
                      options: <UiOption<CopilotVoiceModel>>[
                        for (final CopilotVoiceModel m in CopilotVoiceModel.values)
                          UiOption<CopilotVoiceModel>(
                            label: m.label,
                            description: m.description,
                            value: m,
                            icon: Icons.record_voice_over_outlined,
                          ),
                      ],
                      onChanged: voice.setVoiceModel,
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  // Toggle animate expand / collapse
                  UiIconButton(
                    icon: voice.minimized
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    tooltip: voice.minimized ? 'Expand voice studio' : 'Minimize voice studio',
                    size: UiSize.xs,
                    variant: UiVariant.ghost,
                    onPressed: () {
                      voice.toggleMinimized();
                      if (voice.minimized) {
                        _anim.reverse();
                      } else {
                        _anim.forward();
                      }
                    },
                  ),
                  // End call button in top right
                  UiIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'End voice session',
                    size: UiSize.xs,
                    intent: UiIntent.danger,
                    variant: UiVariant.ghost,
                    onPressed: widget.onClose ?? voice.end,
                  ),
                ],
              ),

              // Animated expandable studio area
              ClipRect(
                child: SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(height: context.sp(theme.spacing.sm)),
                      // Live Waveform visualizer banner
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(theme.spacing.xs),
                          vertical: context.sp(theme.spacing.xxs),
                        ),
                        decoration: BoxDecoration(
                          color: theme.colors.surfaceMuted.withValues(alpha: 0.6),
                          borderRadius: context.radius(theme.radii.md),
                          border: Border.all(
                            color: theme.colors.border.withValues(alpha: 0.25),
                          ),
                        ),
                        child: UiSparkChart(
                          values: voice.waveform,
                          filled: true,
                          height: 36,
                          color: accentColor,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.xs)),

                      // Live User speech caption
                      if (voice.userCaption.isNotEmpty) ...<Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.account_circle_outlined,
                              size: context.sz(14),
                              color: theme.colors.foregroundSubtle,
                            ),
                            SizedBox(width: context.sp(theme.spacing.xxs)),
                            Expanded(
                              child: Text(
                                'You · “${voice.userCaption}”',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.uiText.caption.copyWith(
                                  color: theme.colors.foregroundMuted,
                                  fontStyle: FontStyle.italic,
                                  fontSize: context.fs(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                      ],

                      // Assistant Live Caption / Response banner
                      Container(
                        padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.06),
                          borderRadius: context.radius(theme.radii.sm),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          voice.assistantCaption.isEmpty
                              ? 'Hi! I’m $name (${voice.voiceModel.label} voice). Ask me about your notes, journal trades, strategies, community posts, or live markets.'
                              : voice.assistantCaption,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.body.copyWith(
                            fontSize: context.fs(12),
                            height: 1.35,
                          ),
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.xs)),

                      // Natural-language voice quick action chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            for (final String prompt in const <String>[
                              'Summarize my notes & journal',
                              'Review my win rate & strategies',
                              'Check my watchlist pulse',
                              'Draft a community post',
                            ])
                              Padding(
                                padding: EdgeInsets.only(
                                  right: context.sp(theme.spacing.xs),
                                ),
                                child: UiButton(
                                  label: prompt,
                                  icon: Icons.graphic_eq_rounded,
                                  size: UiSize.xs,
                                  variant: UiVariant.soft,
                                  rounded: true,
                                  onPressed: () => voice.submitVoiceTurn(prompt),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.xs)),

                      // Bottom Control Actions Toolbar (Mic, Speaker, Hands-Free, End Call)
                      Row(
                        children: <Widget>[
                          UiIconButton(
                            icon: voice.microphoneMuted
                                ? Icons.mic_off_outlined
                                : Icons.mic_none,
                            tooltip: voice.microphoneMuted
                                ? 'Unmute microphone'
                                : 'Mute microphone',
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            intent: voice.microphoneMuted
                                ? UiIntent.warning
                                : UiIntent.primary,
                            onPressed: voice.toggleMicrophone,
                          ),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          UiIconButton(
                            icon: voice.speakerMuted
                                ? Icons.volume_off_outlined
                                : Icons.volume_up_outlined,
                            tooltip:
                                voice.speakerMuted ? 'Unmute speaker' : 'Mute speaker',
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            onPressed: voice.toggleSpeaker,
                          ),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          UiButton(
                            label: voice.handsFree ? 'Hands-free' : 'Push-to-talk',
                            icon: voice.handsFree
                                ? Icons.hearing_rounded
                                : Icons.touch_app_outlined,
                            size: UiSize.xs,
                            variant: voice.handsFree ? UiVariant.soft : UiVariant.outline,
                            onPressed: voice.toggleHandsFree,
                          ),
                          const Spacer(),
                          UiButton(
                            label: 'End call',
                            icon: Icons.call_end,
                            size: UiSize.xs,
                            intent: UiIntent.danger,
                            variant: UiVariant.soft,
                            onPressed: widget.onClose ?? voice.end,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
