import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required explicit UI library import for feature widgets.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';

/// A row in the conversation history list. Shows the thread's persona lens, its
/// title, a one-line preview of the latest answer, the last-updated time and pin
/// state. Long-press (or the trailing affordance) surfaces thread actions.
class AiThreadTile extends StatelessWidget {
  const AiThreadTile({
    super.key,
    required this.thread,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final AiThread thread;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return UiCard(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      accentColor: selected ? colors.primary : null,
      variant: UiCardVariant.ghost,
      borderless: true,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            thread.pinned ? Icons.push_pin_rounded : Icons.description_outlined,
            size: context.sz(16),
            color: selected ? colors.foreground : colors.foregroundMuted,
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        thread.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.bodyStrong,
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      AppTokens.relativeTime(thread.updatedAt),
                      style: context.uiText.caption.copyWith(
                        color: colors.foregroundSubtle,
                        fontSize: context.fs(10),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  thread.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundMuted,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  '${thread.persona.shortLabel}  ·  ${thread.messageCount} messages',
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundSubtle,
                    fontSize: context.fs(10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
