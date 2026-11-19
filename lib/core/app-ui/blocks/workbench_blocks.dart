import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import '../../flutter-ui/flutter_ui.dart';

/// Workbench blocks — the shared frame behind the journal and strategy
/// surfaces.
///
/// The calculators hub established the rule these follow: **desktop and mobile
/// are different surfaces, not two widths of one.** On a desktop the index lives
/// in a permanent rail beside the open document, so moving between records costs
/// one click and never unloads what is on screen. On a phone that rail cannot
/// coexist with a document, and hiding it behind a button buries the list, so the
/// index simply *is* the first screen and the document is the second.
///
/// [AppWorkbenchLayout] owns that branch once. Screens pass an index and a
/// document and cannot choose their own arrangement, which is what keeps the
/// journal and the strategy library reading like one application.

// ── Hosting ──────────────────────────────────────────────────────────────────

/// Marks a subtree as hosted inside a workbench.
///
/// A document rendered in the desktop rail is already inside a page; if it drew
/// its own page chrome and back button the user would see two headers and a back
/// affordance that goes nowhere. Documents read this and drop theirs.
class AppWorkbenchScope extends InheritedWidget {
  const AppWorkbenchScope({
    super.key,
    required super.child,
    this.embeddedHeader = false,
  });

  /// True when the host already renders a title bar for this document — the
  /// mobile shell does, via `onSubpageChanged`.
  final bool embeddedHeader;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppWorkbenchScope>() != null;

  static bool hasEmbeddedHeader(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppWorkbenchScope>()
          ?.embeddedHeader ??
      false;

  @override
  bool updateShouldNotify(AppWorkbenchScope oldWidget) =>
      embeddedHeader != oldWidget.embeddedHeader;
}

/// Marks feature screens hosted by the unified Writing Desk.
///
/// Standalone screens keep their own desktop creation/help actions. Inside the
/// desk those actions belong to the shared header, while phone screens retain
/// their thumb-reachable floating action. This presentation contract keeps one
/// source of truth without coupling feature code to `WorkspaceScreen`.
class AppWritingDeskScope extends InheritedWidget {
  const AppWritingDeskScope({super.key, required super.child});

  static bool isHosted(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppWritingDeskScope>() != null;

  @override
  bool updateShouldNotify(AppWritingDeskScope oldWidget) => false;
}

// ── Layout ───────────────────────────────────────────────────────────────────

/// The desktop half of the workbench: a resizable index rail to the right of
/// the open document.
///
/// Mobile never reaches this widget. Screens branch on `context.uiRes.isMobile`
/// and render their own index page, because the phone surface is a different
/// screen with different affordances rather than this one squeezed.
class AppWorkbenchLayout extends StatefulWidget {
  const AppWorkbenchLayout({
    super.key,
    required this.index,
    required this.document,
    this.expandedIndex,
    this.hasActiveDocument = true,
    this.aside,
    this.railWidth = 300,
    this.asideWidth = 300,
    this.showIndex = true,
    this.showAside = false,
    this.title = 'Writing desk',
  });
  final Widget index, document;

  /// The rich, full-width view shown when no document is active. When null the
  /// compact [index] fills the width instead. Only consulted while
  /// [hasActiveDocument] is false.
  final Widget? expandedIndex;

  /// When false the layout drops the split pane entirely and shows
  /// [expandedIndex] (or [index]) at full width — no rail, no empty document
  /// pane. When true the usual rail + document split is rendered.
  final bool hasActiveDocument;
  final Widget? aside;
  final double railWidth, asideWidth;
  final bool showIndex, showAside;
  final String title;
  @override
  State<AppWorkbenchLayout> createState() => _AppWorkbenchLayoutState();
}

class _AppWorkbenchLayoutState extends State<AppWorkbenchLayout> {
  bool library = true;
  final _documentKey = GlobalKey();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // No document is active: collapse to a full-width index instead of a
      // split pane with a blank right half. The rich expanded view is used
      // when a screen provides one, otherwise the compact index fills the width.
      if (!widget.hasActiveDocument) {
        return ColoredBox(
          color: context.ui.colors.background,
          child: widget.expandedIndex ?? widget.index,
        );
      }
      final showIndex = widget.showIndex && library;
      final showAside =
          widget.showAside && widget.aside != null && box.maxWidth >= 1700;
      final document = KeyedSubtree(
        key: _documentKey,
        child: AppWorkbenchScope(child: widget.document),
      );
      Widget content = showIndex
          ? UiSplitPane(
              key: const ValueKey('workbench_library_split'),
              initialRatio: (1 - (context.sz(widget.railWidth) / box.maxWidth))
                  .clamp(.58, .78),
              minRatio: .58,
              maxRatio: .78,
              primary: document,
              detail: _WorkbenchLibraryScope(
                hide: () => setState(() => library = false),
                child: widget.index,
              ),
            )
          : document;
      if (showAside) {
        content = UiSplitPane(
          key: const ValueKey('workbench_context_split'),
          primary: content,
          detail: widget.aside!,
          initialRatio: .78,
          minRatio: .70,
          maxRatio: .82,
        );
      }
      return ColoredBox(
        color: context.ui.colors.background,
        child: showIndex || !widget.showIndex
            ? content
            : Stack(
                children: <Widget>[
                  Positioned.fill(child: content),
                  Positioned(
                    top: context.sp(context.ui.spacing.xs),
                    right: context.sp(context.ui.spacing.xs),
                    child: UiIconButton(
                      icon: Icons.view_sidebar_outlined,
                      tooltip: 'Show record library',
                      size: UiSize.sm,
                      variant: UiVariant.soft,
                      onPressed: () => setState(() => library = true),
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

class _WorkbenchLibraryScope extends InheritedWidget {
  const _WorkbenchLibraryScope({required this.hide, required super.child});
  final VoidCallback hide;
  static _WorkbenchLibraryScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_WorkbenchLibraryScope>();
  @override
  bool updateShouldNotify(_WorkbenchLibraryScope oldWidget) => true;
}

// ── Index rail ───────────────────────────────────────────────────────────────

/// The rail's own frame: a fixed header, an optional filter area, then the
/// scrolling list.
///
/// Header and filters stay put while the list scrolls, so the search field a
/// trader is typing into does not slide away under their cursor.
class AppWorkbenchIndex extends StatelessWidget {
  const AppWorkbenchIndex({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.filters,
    this.actions = const <Widget>[],
    this.footer,
    this.scrollController,
    this.scrollHeader = false,
    this.showTitle = false,
  });
  final String title;
  final String? subtitle;
  final Widget? filters, footer;
  final Widget child;
  final List<Widget> actions;
  final ScrollController? scrollController;

  /// Phone lists let filters scroll out of the way; desktop rails pin them.
  final bool scrollHeader;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final gutter = context.sp(theme.spacing.md);
    final libraryScope = _WorkbenchLibraryScope.of(context);
    final bool hasTitle = showTitle && title.isNotEmpty;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasTitle)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: UiHeader(
                    title: title,
                    subtitle: subtitle,
                    actions: actions,
                  ),
                ),
                if (libraryScope case final library?)
                  UiIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Hide library',
                    size: UiSize.sm,
                    onPressed: library.hide,
                  ),
              ],
            ),
          )
        else if (libraryScope != null || actions.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              context.sp(theme.spacing.xs),
              gutter,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (libraryScope case final library?)
                  UiIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Hide library',
                    size: UiSize.sm,
                    onPressed: library.hide,
                  )
                else
                  const SizedBox.shrink(),
                if (actions.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ),
          ),
        if (filters != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              context.sp(theme.spacing.xs),
              gutter,
              0,
            ),
            child: filters,
          ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        const UiDivider(spacing: 0),
      ],
    );
    return ColoredBox(
      color: theme.colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!scrollHeader) header,
          Expanded(
            child: scrollHeader
                ? NestedScrollView(
                    headerSliverBuilder: (context, innerScrolled) => [
                      SliverToBoxAdapter(child: header),
                    ],
                    body: child,
                  )
                : UiScrollbar(controller: scrollController, child: child),
          ),
          if (footer != null) ...[
            const UiDivider(spacing: 0),
            Padding(padding: EdgeInsets.all(gutter), child: footer),
          ],
        ],
      ),
    );
  }
}

/// One record in the rail.
///
/// Denser than a card on purpose: the rail's job is to hold thirty records in
/// view at once, and cards with padding and shadows hold eight. The accent stripe
/// carries the record's state (P/L sign, playbook status) so the list is scannable
/// without reading a word.
class AppIndexRow extends StatelessWidget {
  const AppIndexRow({
    super.key,
    required this.title,
    this.subtitle,
    this.meta,
    this.metaColor,
    this.icon,
    this.accent,
    this.badges = const <Widget>[],
    this.selected = false,
    this.onTap,
    this.trailing,
    this.warning = false,
  });

  final String title;
  final String? subtitle;

  /// Right-aligned, one line: P/L, win rate, a relative timestamp.
  final String? meta;
  final Color? metaColor;
  final IconData? icon;

  /// The left stripe. Null draws no stripe, which reads as "no state".
  final Color? accent;
  final List<Widget> badges;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Flags the row as needing attention — unfiled, unwritten, broken link.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final Color stripe = accent ?? (warning ? c.warning : Colors.transparent);

    return AppHoverLift(
      enabled: onTap != null,
      scale: 1,
      child: Material(
        color: selected ? c.surfaceMuted : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: context.sz(3),
                child: ColoredBox(color: stripe),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.sp(theme.spacing.md),
                  context.sp(theme.spacing.sm),
                  context.sp(theme.spacing.md),
                  context.sp(theme.spacing.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Padding(
                        padding: EdgeInsets.only(top: context.sz(2)),
                        child: Icon(
                          icon,
                          size: context.sz(15),
                          color: selected ? c.primary : c.foregroundMuted,
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.body.copyWith(
                              color: c.foreground,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: context.sz(1)),
                              child: Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.uiText.caption.copyWith(
                                  color: c.foregroundMuted,
                                ),
                              ),
                            ),
                          if (badges.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                top: context.sp(theme.spacing.xs),
                              ),
                              child: Wrap(
                                spacing: context.sp(theme.spacing.xs),
                                runSpacing: context.sz(2),
                                children: badges,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ?trailing,
                    if (meta != null && meta!.isNotEmpty) ...<Widget>[
                      SizedBox(width: context.sp(theme.spacing.sm)),
                      Text(
                        meta!,
                        style: context.uiText.caption.copyWith(
                          color: metaColor ?? c.foregroundMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A group label inside the rail — "This week", "Live playbooks".
class AppIndexSectionHeader extends StatelessWidget {
  const AppIndexSectionHeader({
    super.key,
    required this.label,
    this.count,
    this.icon,
  });

  final String label;
  final int? count;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    return Container(
      color: c.surfaceMuted.withValues(alpha: 0.5),
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: context.sz(12), color: c.foregroundMuted),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          Expanded(
            child: Text(label.toUpperCase(), style: uiOverline(context)),
          ),
          if (count != null)
            Text(
              '$count',
              style: context.uiText.caption.copyWith(color: c.foregroundMuted),
            ),
        ],
      ),
    );
  }
}

/// Focused record form. Prose is authored in the shared Notes workspace.
class AppRecordDetailsForm extends StatelessWidget {
  const AppRecordDetailsForm({
    super.key,
    required this.title,
    required this.description,
    required this.fields,
    required this.onSave,
    required this.onBack,
    this.onDelete,
    this.saving = false,
  });
  final String title, description;
  final Widget fields;
  final VoidCallback onSave, onBack;
  final VoidCallback? onDelete;
  final bool saving;
  @override
  Widget build(BuildContext context) => UiPage(
    maxWidth: 800,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiHeader(
          title: title,
          subtitle: description,
          actions: [
            UiIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back to record',
              onPressed: saving ? null : onBack,
            ),
            if (onDelete != null)
              UiIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete record',
                onPressed: saving ? null : onDelete,
              ),
            UiButton(
              label: 'Save details',
              leadingIcon: Icons.check_rounded,
              loading: saving,
              onPressed: saving ? null : onSave,
            ),
          ],
        ),
        const UiGap.v(20),
        fields,
        SizedBox(height: context.uiPageBottomInset + context.sp(24)),
      ],
    ),
  );
}
