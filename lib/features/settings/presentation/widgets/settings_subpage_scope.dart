import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import 'settings_side_sheet.dart';

/// One screen on the settings drill-in stack.
typedef SettingsSubpageEntry = ({
  String title,
  String? subtitle,
  IconData icon,
  Widget page,
});

/// Inline navigation for settings detail screens.
///
/// Settings screens used to open their detail views — blocked users, an invoice,
/// a change-of-plan table, a public profile preview — with `showGeneralDialog`.
/// That pushes a route *above* the app shell: the dock disappears, the shell
/// header keeps naming the parent screen, and what the reader gets is a sheet
/// rather than a page. Pushing onto this scope instead leaves the shell where it
/// is and swaps only the content it hosts, so the dock stays put and the header
/// retitles itself the same way it does for any other settings screen.
///
/// [SettingsRootPage] installs the scope and owns the stack. Screens push
/// through [openSettingsSubpage] rather than reading the scope directly.
class SettingsSubpageScope extends InheritedWidget {
  const SettingsSubpageScope({
    super.key,
    required this.push,
    required this.pop,
    required super.child,
  });

  /// Adds a screen on top of whatever is showing.
  final void Function(SettingsSubpageEntry entry) push;

  /// Removes the top screen. A no-op when the stack is already empty.
  final VoidCallback pop;

  /// Looked up without registering a dependency: callers reach for this from a
  /// tap handler, not from `build`, and none of them need to rebuild when the
  /// stack moves.
  static SettingsSubpageScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsSubpageScope>();

  @override
  bool updateShouldNotify(SettingsSubpageScope oldWidget) => false;
}

/// Opens [page] as a settings detail screen.
///
/// On mobile, pushes onto [SettingsSubpageScope] to render inline inside the content
/// so that the floating dock and mobile header navigation remain continuous.
/// On desktop and tablet, opens as a sleek right side overlay panel ([showSettingsSideSheet])
/// overlaying on top of the window with smooth slide animation and barrier dismissal.
void openSettingsSubpage(
  BuildContext context, {
  required String title,
  required IconData icon,
  required Widget page,
  String? subtitle,
  double desktopWidthRatio = 0.52,
  double? maxWidth,
  double? minDesktopWidth,
}) {
  final bool isMobile = context.uiRes.isMobile;
  final SettingsSubpageScope? scope = SettingsSubpageScope.maybeOf(context);
  if (isMobile && scope != null) {
    scope.push((title: title, subtitle: subtitle, icon: icon, page: page));
    return;
  }
  showSettingsSideSheet(
    context,
    title: title,
    subtitle: subtitle,
    desktopWidthRatio: desktopWidthRatio,
    maxWidth: maxWidth,
    minDesktopWidth: minDesktopWidth,
    child: page,
  );
}

/// Closes the top settings screen on mobile, or dismisses the side sheet overlay on desktop.
void closeSettingsSubpage(BuildContext context) {
  final bool isMobile = context.uiRes.isMobile;
  final SettingsSubpageScope? scope = SettingsSubpageScope.maybeOf(context);
  if (isMobile && scope != null) {
    scope.pop();
    return;
  }
  Navigator.of(context).maybePop();
}
