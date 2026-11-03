import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';

/// Shared IDE-like chrome for the Copilot workspace.
///
/// The Copilot is a workbench rather than a dashboard: the activity rail answers
/// "where am I?", the explorer answers "what am I working on?", the editor owns
/// the conversation, and the inspector keeps supporting context visible.
class AiIdeActivityRail extends StatelessWidget {
  const AiIdeActivityRail({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(
            color: colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: context.sz(64),
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: context.sp(theme.spacing.md),
                ),
                child: Text(
                  'AJ',
                  style: context.uiText.label.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              _activityButton(
                context,
                index: 0,
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Chat editor',
              ),
              _activityButton(
                context,
                index: 1,
                icon: Icons.radar_rounded,
                label: 'Signal desk',
              ),
              _activityButton(
                context,
                index: 2,
                icon: Icons.auto_awesome_outlined,
                label: 'Creation studio',
              ),
              const Spacer(),
              _activityButton(
                context,
                index: 3,
                icon: Icons.history_rounded,
                label: 'Conversation history',
              ),
              Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
                child: UiIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Copilot settings',
                  size: UiSize.sm,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityButton(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool active = selected == index;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xxs)),
      child: Semantics(
        button: true,
        label: label,
        selected: active,
        child: UiInteractive(
          onTap: () => onSelected(index),
          builder: (BuildContext context, UiInteractiveState state) {
            final Color tint = active
                ? colors.foreground
                : colors.foregroundMuted;
            return AnimatedContainer(
              duration: theme.motion.fast,
              curve: theme.motion.curve,
              width: context.sz(44),
              height: context.sz(44),
              decoration: BoxDecoration(
                color: active || state.hovered
                    ? colors.surfaceMuted
                    : Colors.transparent,
                borderRadius: context.radius(theme.radii.md),
                border: active
                    ? Border.all(
                        color: colors.borderStrong,
                        width: theme.borders.hairline,
                      )
                    : null,
              ),
              child: Icon(icon, size: context.sz(19), color: tint),
            );
          },
        ),
      ),
    );
  }
}

class AiIdeExplorerHeader extends StatelessWidget {
  const AiIdeExplorerHeader({
    super.key,
    required this.onNewThread,
    this.onSearch,
  });

  final VoidCallback onNewThread;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.md),
          vertical: context.sp(theme.spacing.sm),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'EXPLORER',
                style: context.uiText.caption.copyWith(
                  color: colors.foregroundMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            UiIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Search conversations',
              size: UiSize.xs,
              onPressed: onSearch,
            ),
            UiIconButton(
              icon: Icons.add_rounded,
              tooltip: 'New conversation',
              size: UiSize.xs,
              intent: UiIntent.primary,
              onPressed: onNewThread,
            ),
          ],
        ),
      ),
    );
  }
}

class AiIdeSectionLabel extends StatelessWidget {
  const AiIdeSectionLabel({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.md),
        context.sp(theme.spacing.md),
        context.sp(theme.spacing.sm),
        context.sp(theme.spacing.xs),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: context.sz(16),
            color: colors.foregroundMuted,
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
          Expanded(
            child: Text(
              label,
              style: context.uiText.caption.copyWith(
                color: colors.foregroundMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class AiIdeEditorTab extends StatelessWidget {
  const AiIdeEditorTab({
    super.key,
    required this.title,
    required this.persona,
    this.onNew,
  });

  final String title;
  final AiPersona persona;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: SizedBox(
        height: context.sz(46),
        child: Row(
          children: <Widget>[
            Container(
              width: context.sz(2),
              height: double.infinity,
              color: colors.foreground,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
              ),
              child: Icon(
                persona.icon,
                size: context.sz(16),
                color: colors.foregroundMuted,
              ),
            ),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            if (onNew != null)
              UiIconButton(
                icon: Icons.add_rounded,
                tooltip: 'New conversation',
                size: UiSize.xs,
                onPressed: onNew,
              ),
            SizedBox(width: context.sp(theme.spacing.sm)),
          ],
        ),
      ),
    );
  }
}

class AiIdeStatusBar extends StatelessWidget {
  const AiIdeStatusBar({
    super.key,
    required this.persona,
    required this.connected,
    required this.setupCount,
  });

  final AiPersona persona;
  final bool connected;
  final int setupCount;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border, width: theme.borders.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.circle,
                size: context.sz(8),
                color: connected ? colors.bullish : colors.warning,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Text(
                connected ? 'CONNECTED' : 'SIMULATED',
                style: context.uiText.caption.copyWith(
                  fontSize: context.fs(10),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: colors.foregroundMuted,
                ),
              ),
              const Spacer(),
              Text(
                '${persona.shortLabel}  ·  $setupCount setups',
                style: context.uiText.caption.copyWith(
                  color: colors.foregroundMuted,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              Text(
                'AI COPILOT',
                style: context.uiText.caption.copyWith(
                  color: colors.foregroundSubtle,
                  fontSize: context.fs(10),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
