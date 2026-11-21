import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';

/// Desktop workspace surface: a persistent list pane on the left and a detail
/// pane on the right, collapsing to full-screen push navigation on phones.
///
/// Use it for Journal, Messages, Strategies and Notifications — anywhere the
/// desktop spec asks for list-plus-detail instead of separate pages.
class AppWorkspacePane extends StatelessWidget {
  const AppWorkspacePane({
    super.key,
    required this.list,
    required this.detail,
    required this.hasSelection,
    required this.onClearSelection,
    this.listTitle,
    this.listActions = const <Widget>[],
    this.detailTitle,
    this.detailActions = const <Widget>[],
    this.breadcrumbs = const <UiCrumb>[],
    this.placeholderTitle = 'Select an item',
    this.placeholderMessage = 'Pick something on the left to see details here.',
    this.placeholderIcon = Icons.view_sidebar_outlined,
    this.initialRatio = 0.34,
  });

  final Widget list;
  final Widget detail;
  final bool hasSelection;
  final VoidCallback onClearSelection;
  final String? listTitle;
  final List<Widget> listActions;
  final String? detailTitle;
  final List<Widget> detailActions;
  final List<UiCrumb> breadcrumbs;
  final String placeholderTitle;
  final String placeholderMessage;
  final IconData placeholderIcon;
  final double initialRatio;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    Widget header(String? title, List<Widget> actions, {Widget? leading}) {
      if (title == null && actions.isEmpty && leading == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading,
              SizedBox(width: context.sp(theme.spacing.xs)),
            ],
            if (title != null)
              Expanded(child: Text(title, style: context.uiText.subheading)),
            ...actions,
          ],
        ),
      );
    }

    final Widget listPane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        header(listTitle, listActions),
        Expanded(child: SingleChildScrollView(child: list)),
      ],
    );

    final Widget detailPane = hasSelection
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (breadcrumbs.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: context.sp(theme.spacing.sm),
                  ),
                  child: UiBreadcrumbs(crumbs: breadcrumbs),
                ),
              header(
                detailTitle,
                detailActions,
                leading: context.uiRes.isMobile
                    ? UiIconButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Back',
                        onPressed: onClearSelection,
                      )
                    : null,
              ),
              Expanded(child: SingleChildScrollView(child: detail)),
            ],
          )
        : UiPanePlaceholder(
            title: placeholderTitle,
            message: placeholderMessage,
            icon: placeholderIcon,
          );

    return UiSplitPane(
      primary: RepaintBoundary(child: listPane),
      detail: RepaintBoundary(child: detailPane),
      detailVisible: hasSelection,
      initialRatio: initialRatio,
    );
  }
}

/// Three-pane desktop workspace: context rail, list and detail.
/// Mirrors the desktop "home" layout where filters stay pinned on the left.
class AppWorkspaceThreePane extends StatelessWidget {
  const AppWorkspaceThreePane({
    super.key,
    required this.rail,
    required this.list,
    required this.detail,
    this.hasSelection = false,
    this.railVisible = true,
    this.railWidth = 240,
  });

  final Widget rail;
  final Widget list;
  final Widget detail;
  final bool hasSelection;
  final bool railVisible;
  final double railWidth;

  @override
  Widget build(BuildContext context) {
    return UiThreePane(
      rail: RepaintBoundary(child: rail),
      list: RepaintBoundary(child: list),
      detail: RepaintBoundary(child: detail),
      detailVisible: hasSelection,
      railVisible: railVisible,
      railWidth: railWidth,
    );
  }
}
