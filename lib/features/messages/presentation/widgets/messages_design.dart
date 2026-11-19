import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

// ===========================================================================
// Messages design foundations
// ---------------------------------------------------------------------------
// Mirrors the community design layer: one density scope rescales the whole
// section, and a couple of shared primitives keep headers and empty states
// identical across the inbox, thread, requests and archive views. Dialogs and
// bottom sheets re-apply [MessagesDensityScope] because they render on the root
// overlay, outside this subtree.
// ===========================================================================

/// Slightly denser than the app default so a tall inbox list fits more threads
/// without feeling cramped — text is compressed less than space to stay legible.
const UiScaleConfig kMessagesScale = UiScaleConfig(
  mobile: UiScale(space: 0.94, text: 0.98, size: 0.96),
  tablet: UiScale(space: 0.96, text: 0.99, size: 0.98),
  desktop: UiScale(space: 1.0, text: 1.0, size: 1.0),
  largeDesktop: UiScale(space: 1.04, text: 1.02, size: 1.02),
);

/// Max width for a centred chat column on very wide desktops.
const double kMessagesThreadMaxWidth = 760;

/// Wraps [child] so the whole Messages subtree renders at [kMessagesScale].
/// A no-op if already applied (safe to nest inside overlays).
class MessagesDensityScope extends StatelessWidget {
  const MessagesDensityScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final UiTheme base = context.ui;
    if (identical(base.scaleConfig, kMessagesScale)) return child;
    return UiThemeScope(
      theme: base.copyWith(scaleConfig: kMessagesScale),
      child: child,
    );
  }
}

/// Compact section heading used in the inbox, info sheet and archive.
class MessagesSectionHeader extends StatelessWidget {
  const MessagesSectionHeader({
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
              title.toUpperCase(),
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundSubtle,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                fontSize: context.fs(10.5),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The rounded drag handle shown at the top of Messages bottom sheets.
class MessagesSheetGrabber extends StatelessWidget {
  const MessagesSheetGrabber({super.key});

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
/// comfortably inside the inbox or thread column.
class MessagesEmptyState extends StatelessWidget {
  const MessagesEmptyState({
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
