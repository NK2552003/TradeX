import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

// ===========================================================================
// AI Assistant design foundations
// ---------------------------------------------------------------------------
// Mirrors the community / messages design layer: one density scope rescales the
// whole section, and a handful of shared primitives keep headers, empty states
// and sheet grabbers identical across the chat, insights, create and history
// views. Dialogs and bottom sheets re-apply [AiDensityScope] because they render
// on the root overlay, outside this subtree.
// ===========================================================================

/// Slightly denser than the app default so a tall thread rail and a chat column
/// coexist without feeling cramped — text is compressed less than space so the
/// conversation stays legible.
const UiScaleConfig kAiScale = UiScaleConfig(
  mobile: UiScale(space: 0.94, text: 0.98, size: 0.96),
  tablet: UiScale(space: 0.96, text: 0.99, size: 0.98),
  desktop: UiScale(space: 1.0, text: 1.0, size: 1.0),
  largeDesktop: UiScale(space: 1.04, text: 1.02, size: 1.02),
);

/// Max width for the centred chat column on very wide desktops so lines of the
/// assistant's answer stay a comfortable reading measure.
const double kAiChatMaxWidth = 780;

/// Wraps [child] so the whole AI Assistant subtree renders at [kAiScale].
/// A no-op if already applied (safe to nest inside overlays).
class AiDensityScope extends StatelessWidget {
  const AiDensityScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final UiTheme base = context.ui;
    if (identical(base.scaleConfig, kAiScale)) return child;
    return UiThemeScope(
      theme: base.copyWith(scaleConfig: kAiScale),
      child: child,
    );
  }
}

/// Compact section heading used in the create hub, insights rail, history list
/// and prompt library.
class AiSectionHeader extends StatelessWidget {
  const AiSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.xs),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: context.sz(theme.sizes.iconSm),
              color: theme.colors.foregroundMuted,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          Expanded(
            child: Text(
              title,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.15,
                fontSize: context.fs(10),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Quiet, editorial chrome for the Copilot workspace.
///
/// Omnirush keeps its product surface intentionally calm: one strong wordmark,
/// a tiny status signal, and a single action. Keeping that hierarchy here makes
/// the feature feel like a focused workbench instead of another dashboard.
class AiConsoleHeader extends StatelessWidget {
  const AiConsoleHeader({
    super.key,
    this.title = 'Copilot',
    this.subtitle = 'Your market workspace',
    this.trailing = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(
            color: colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.lg),
            vertical: context.sp(theme.spacing.md),
          ),
          child: Row(
            children: <Widget>[
              Text(
                'AJ',
                style: context.uiText.label.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: context.uiText.heading.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: context.uiText.caption.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              UiBadge(
                label: 'LIVE',
                icon: Icons.circle,
                intent: UiIntent.bullish,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
              ),
              for (final Widget action in trailing) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.xs)),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The rounded drag handle shown at the top of AI Assistant bottom sheets.
class AiSheetGrabber extends StatelessWidget {
  const AiSheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: Center(
        child: Container(
          width: context.sz(40),
          height: context.sz(4),
          decoration: BoxDecoration(
            color: theme.colors.borderStrong,
            borderRadius: BorderRadius.circular(context.sz(999)),
          ),
        ),
      ),
    );
  }
}

/// Section empty state — reuses the app-wide [UiEmptyState] at a size that sits
/// comfortably inside the chat, insights or history column.
class AiEmptyState extends StatelessWidget {
  const AiEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.sp(context.ui.spacing.xl)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: UiEmptyState(
            icon: icon,
            title: title,
            message: message,
            action: action,
          ),
        ),
      ),
    );
  }
}
