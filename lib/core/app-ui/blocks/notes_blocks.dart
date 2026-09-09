import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../cards/notes_cards.dart';
import '../models/app_models.dart';
import '../theme/app_tokens.dart';
import 'workbench_blocks.dart';

/// Note blocks — compose the note cards into the list surface.

/// Search, type filter, tag filter, sort and density in one bar.
///
/// Stacked on a phone and a single row from tablet up, because every control
/// here is optional refinement: on a narrow screen the search field earns the
/// full width and the rest scrolls underneath it.
class AppNoteFilterBlock extends StatelessWidget {
  const AppNoteFilterBlock({
    super.key,
    this.showSearch = true,
    this.showFilterControl = true,
    required this.query,
    required this.type,
    required this.sort,
    required this.density,
    this.tag,
    this.availableTags = const <String>[],
    this.onQueryChanged,
    this.onTypeChanged,
    this.onTagChanged,
    this.onSortChanged,
    this.onDensityChanged,
    this.onNew,
  });

  final bool showSearch;
  final bool showFilterControl;
  final String query;
  final AppNoteType? type;
  final String? tag;
  final AppNoteSort sort;
  final AppNoteDensity density;
  final List<String> availableTags;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<AppNoteType?>? onTypeChanged;
  final ValueChanged<String?>? onTagChanged;
  final ValueChanged<AppNoteSort>? onSortChanged;
  final ValueChanged<AppNoteDensity>? onDensityChanged;
  final VoidCallback? onNew;

  Future<void> showFilters(BuildContext context) async {
    AppNoteType? selectedType = type;
    AppNoteSort selectedSort = sort;
    AppNoteDensity selectedDensity = density;
    String? selectedTag = tag;

    await UiDrawer.show<void>(
      context,
      title: 'Note filters',
      child: StatefulBuilder(
        builder: (BuildContext sheetContext, StateSetter setSheetState) {
          void update(VoidCallback change) => setSheetState(change);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: UiIconButton(
                  icon: Icons.restart_alt_rounded,
                  tooltip: 'Reset filters',
                  variant: UiVariant.ghost,
                  onPressed: () => update(() {
                    selectedType = null;
                    selectedSort = AppNoteSort.values.first;
                    selectedDensity = AppNoteDensity.comfortable;
                    selectedTag = null;
                    onTypeChanged?.call(null);
                    onSortChanged?.call(selectedSort);
                    onDensityChanged?.call(selectedDensity);
                    onTagChanged?.call(null);
                  }),
                ),
              ),
              UiField(
                label: 'Type',
                child: UiSelect<String>(
                  expand: true,
                  value: selectedType?.name ?? 'all',
                  onChanged: (String value) => update(() {
                    selectedType = value == 'all'
                        ? null
                        : AppNoteType.values.byName(value);
                    onTypeChanged?.call(selectedType);
                  }),
                  options: <UiOption<String>>[
                    const UiOption<String>(value: 'all', label: 'All types'),
                    for (final AppNoteType value in AppNoteType.values)
                      UiOption<String>(
                        value: value.name,
                        label: value.label,
                        icon: value.icon,
                      ),
                  ],
                ),
              ),
              SizedBox(height: sheetContext.sp(context.ui.spacing.md)),
              UiField(
                label: 'Sort by',
                child: UiSelect<AppNoteSort>(
                  expand: true,
                  value: selectedSort,
                  onChanged: (AppNoteSort value) => update(() {
                    selectedSort = value;
                    onSortChanged?.call(value);
                  }),
                  options: <UiOption<AppNoteSort>>[
                    for (final AppNoteSort value in AppNoteSort.values)
                      UiOption<AppNoteSort>(value: value, label: value.label),
                  ],
                ),
              ),
              SizedBox(height: sheetContext.sp(context.ui.spacing.md)),
              Text('Reading density', style: sheetContext.uiText.label),
              SizedBox(height: sheetContext.sp(context.ui.spacing.xs)),
              UiToggleGroup<AppNoteDensity>(
                expand: true,
                value: selectedDensity,
                onChanged: (AppNoteDensity value) => update(() {
                  selectedDensity = value;
                  onDensityChanged?.call(value);
                }),
                allowEmpty: false,
                options: const <UiToggleOption<AppNoteDensity>>[
                  UiToggleOption<AppNoteDensity>(
                    value: AppNoteDensity.titleOnly,
                    label: 'Compact',
                  ),
                  UiToggleOption<AppNoteDensity>(
                    value: AppNoteDensity.comfortable,
                    label: 'Comfortable',
                  ),
                  UiToggleOption<AppNoteDensity>(
                    value: AppNoteDensity.full,
                    label: 'Full',
                  ),
                ],
              ),
              if (availableTags.isNotEmpty) ...<Widget>[
                SizedBox(height: sheetContext.sp(context.ui.spacing.md)),
                Text('Tag', style: sheetContext.uiText.label),
                SizedBox(height: sheetContext.sp(context.ui.spacing.xs)),
                Wrap(
                  spacing: sheetContext.sp(context.ui.spacing.xs),
                  runSpacing: sheetContext.sp(context.ui.spacing.xs),
                  children: <Widget>[
                    UiBadge(
                      label: 'All tags',
                      variant: selectedTag == null
                          ? UiBadgeVariant.solid
                          : UiBadgeVariant.outline,
                      onTap: () => update(() {
                        selectedTag = null;
                        onTagChanged?.call(null);
                      }),
                    ),
                    for (final String value in availableTags)
                      UiBadge(
                        label: '#$value',
                        variant: selectedTag == value
                            ? UiBadgeVariant.solid
                            : UiBadgeVariant.outline,
                        onTap: () => update(() {
                          selectedTag = value;
                          onTagChanged?.call(value);
                        }),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => _buildFilters(context, box.maxWidth),
  );

  Widget _buildFilters(BuildContext context, double width) {
    final UiTheme theme = context.ui;
    final int activeFilters = (type == null ? 0 : 1) + (tag == null ? 0 : 1);
    if (!showSearch && !showFilterControl && onNew == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: <Widget>[
        if (showSearch)
          Expanded(
            child: UiInput.search(
              value: query,
              hintText: 'Search notes, tags or linked records',
              size: UiSize.sm,
              onChanged: onQueryChanged,
            ),
          ),
        if (showSearch && (showFilterControl || onNew != null))
          SizedBox(width: context.sp(theme.spacing.xs)),
        if (showFilterControl)
          UiIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Note filters',
            badgeCount: activeFilters == 0 ? null : activeFilters,
            size: UiSize.sm,
            variant: UiVariant.soft,
            onPressed: () => showFilters(context),
          ),
        if (showFilterControl && onNew != null)
          SizedBox(width: context.sp(theme.spacing.xs)),
        if (onNew != null)
          UiIconButton(
            icon: Icons.add_rounded,
            tooltip: 'New note',
            size: UiSize.sm,
            variant: UiVariant.primary,
            onPressed: onNew,
          ),
      ],
    );
  }
}

/// The note grid: skeletons while loading, one of two empty states when there is
/// nothing to show, otherwise a responsive column of cards.
///
/// Deliberately not `UiCardGrid`: that grid gives every tile the same aspect
/// ratio, and note cards vary in height by a factor of three between a bare
/// title and a full card with tags. A [Wrap] of width-constrained columns keeps
/// each card exactly as tall as its content.
class AppNoteGridBlock extends StatelessWidget {
  const AppNoteGridBlock({
    super.key,
    required this.notes,
    this.loading = false,
    this.hasAnyNotes = true,
    this.density = AppNoteDensity.comfortable,
    this.highlight = '',
    this.selectedId,
    this.columns,
    this.onOpen,
    this.onDelete,
    this.onNew,
    this.onClearFilters,
  });

  final List<AppNote> notes;
  final bool loading;

  /// False only when the user has no notes at all, which needs the "write your
  /// first note" state rather than the "no matches" one.
  final bool hasAnyNotes;
  final AppNoteDensity density;
  final String highlight;
  final String? selectedId;

  /// Overrides the responsive column count — the editor's list rail uses 1.
  final int? columns;
  final ValueChanged<AppNote>? onOpen;
  final ValueChanged<AppNote>? onDelete;
  final VoidCallback? onNew;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    // One step tighter than md: the notebook is a wall of cards, and larger
    // gutters cost a card per row for no extra legibility.
    final double gap = context.sp(theme.spacing.sm);

    if (loading) {
      return _grid(
        context,
        gap: gap,
        children: List<Widget>.generate(
          4,
          (int _) => const AppNoteCardSkeleton(),
        ),
      );
    }

    if (notes.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.md),
          vertical: context.sp(theme.spacing.xl),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.sz(460)),
            child: hasAnyNotes
                ? UiEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No notes match',
                    message:
                        'Nothing here matches the current search and filters. '
                        'Widen them to see the rest of your notebook.',
                    action: UiButton(
                      label: 'Clear filters',
                      leadingIcon: Icons.filter_alt_off_outlined,
                      variant: UiVariant.outline,
                      onPressed: onClearFilters,
                    ),
                  )
                : UiEmptyState(
                    icon: Icons.edit_note_rounded,
                    title: 'Your notebook is empty',
                    message:
                        'Notes are for the thinking around a trade — the plan '
                        'before it, the review after it, the rules you keep '
                        'forgetting. Start from a template or a blank page.',
                    action: UiButton(
                      label: 'Write your first note',
                      leadingIcon: Icons.add_rounded,
                      onPressed: onNew,
                    ),
                  ),
          ),
        ),
      );
    }

    return _grid(
      context,
      gap: gap,
      children: notes
          .map(
            (AppNote note) => AppNoteCard(
              note: note,
              density: density,
              highlight: highlight,
              selected: note.id == selectedId,
              onTap: onOpen == null ? null : () => onOpen!(note),
              onDelete: onDelete == null ? null : () => onDelete!(note),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _grid(
    BuildContext context, {
    required double gap,
    required List<Widget> children,
  }) => LayoutBuilder(
    builder: (BuildContext ctx, BoxConstraints constraints) {
      final int count =
          columns ??
          ctx.uiRes.columns(mobile: 1, tablet: 2, desktop: 2, large: 2);
      // `constraints.maxWidth` rather than the screen width: the same grid is
      // used inside the editor's narrow list rail, where the device class would
      // report "desktop" and hand it four columns of 90px.
      final double available = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : ctx.uiRes.width;
      final int resolved = count.clamp(1, 2);
      final double width = (available - gap * (resolved - 1)) / resolved;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children
            .map(
              (Widget child) =>
                  SizedBox(width: width > 0 ? width : available, child: child),
            )
            .toList(growable: false),
      );
    },
  );
}

/// Sliver counterpart to [AppNoteGridBlock] for full-page notebooks.
///
/// It builds one responsive row at a time, so only cards near the viewport are
/// mounted. Desktop rows contain two notes; phones contain one. The first few
/// rows also receive the shared entrance motion, while later rows simply fade
/// as they are lazily materialised during scrolling.
class AppNoteLazyGridSliver extends StatelessWidget {
  const AppNoteLazyGridSliver({
    super.key,
    required this.notes,
    this.loading = false,
    this.hasAnyNotes = true,
    this.density = AppNoteDensity.comfortable,
    this.highlight = '',
    this.selectedId,
    this.onOpen,
    this.onDelete,
    this.onNew,
    this.onClearFilters,
  });

  final List<AppNote> notes;
  final bool loading;
  final bool hasAnyNotes;
  final AppNoteDensity density;
  final String highlight;
  final String? selectedId;
  final ValueChanged<AppNote>? onOpen;
  final ValueChanged<AppNote>? onDelete;
  final VoidCallback? onNew;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.sm);

    if (!loading && notes.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.xl),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.sz(460)),
              child: hasAnyNotes
                  ? UiEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No notes match',
                      message:
                          'Nothing here matches the current search and filters.',
                      action: UiButton(
                        label: 'Clear filters',
                        leadingIcon: Icons.filter_alt_off_outlined,
                        variant: UiVariant.outline,
                        onPressed: onClearFilters,
                      ),
                    )
                  : UiEmptyState(
                      icon: Icons.edit_note_rounded,
                      title: 'Your notebook is empty',
                      message:
                          'Capture the plan before a trade and the lesson after it.',
                      action: UiButton(
                        label: 'Write your first note',
                        leadingIcon: Icons.add_rounded,
                        onPressed: onNew,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return SliverLayoutBuilder(
      builder: (BuildContext ctx, SliverConstraints constraints) {
        final int columns = constraints.crossAxisExtent < ctx.sz(680) ? 1 : 2;
        final int itemCount = loading ? 4 : notes.length;
        final int rows = (itemCount / columns).ceil();

        return SliverList.builder(
          itemCount: rows,
          itemBuilder: (BuildContext rowContext, int rowIndex) {
            return Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (
                      int column = 0;
                      column < columns;
                      column++
                    ) ...<Widget>[
                      if (column > 0) SizedBox(width: gap),
                      Expanded(
                        child: () {
                          final int index = rowIndex * columns + column;
                          if (index >= itemCount) {
                            return const SizedBox.shrink();
                          }
                          final Widget card = loading
                              ? const AppNoteCardSkeleton()
                              : AppNoteCard(
                                  key: ValueKey<String>(notes[index].id),
                                  note: notes[index],
                                  density: density,
                                  highlight: highlight,
                                  selected: notes[index].id == selectedId,
                                  onTap: onOpen == null
                                      ? null
                                      : () => onOpen!(notes[index]),
                                  onDelete: onDelete == null
                                      ? null
                                      : () => onDelete!(notes[index]),
                                );
                          return RepaintBoundary(
                            key: ValueKey<String>(
                              loading
                                  ? 'note_skeleton_$index'
                                  : notes[index].id,
                            ),
                            child: card,
                          );
                        }(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Index rail (desktop) ─────────────────────────────────────────────────────

/// The notebook as a dense, type-grouped list for the workbench rail.
///
/// The desktop counterpart to [AppNoteLazyGridSliver]: where the grid gives a
/// bird's-eye of the whole notebook, this holds thirty notes in view at once
/// beside an open note. Grouping is by note type rather than by date — a trader
/// reaching for the rail is usually after "that plan" or "that review", not
/// "that Tuesday" — and each row carries a type-coloured stripe so the shape of
/// the notebook is visible before a title is read.
class AppNoteIndexList extends StatelessWidget {
  const AppNoteIndexList({
    super.key,
    required this.notes,
    this.selectedId,
    this.onOpen,
    this.scrollController,
    this.groupByType = true,
    this.emptyState,
    this.padding,
  });

  final List<AppNote> notes;
  final String? selectedId;
  final ValueChanged<AppNote>? onOpen;
  final ScrollController? scrollController;

  /// Off when a sort other than the default is applied — type headers over a
  /// list ordered by date would be lying about the grouping.
  final bool groupByType;
  final Widget? emptyState;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return emptyState ??
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(context.ui.spacing.md),
              vertical: context.sp(context.ui.spacing.xl),
            ),
            child: const UiEmptyState(
              icon: Icons.edit_note_rounded,
              title: 'No notes match',
              message: 'Clear a filter, or write the note you keep meaning to.',
            ),
          );
    }

    final List<_NoteIndexItem> items = <_NoteIndexItem>[];
    if (groupByType) {
      // Fixed order rather than first-seen, so the rail does not reshuffle when
      // a note's type changes.
      for (final AppNoteType type in AppNoteType.values) {
        final List<AppNote> group = notes
            .where((AppNote n) => n.noteType == type)
            .toList(growable: false);
        if (group.isEmpty) continue;
        items.add(_NoteIndexItem.header(type, group.length));
        items.addAll(group.map(_NoteIndexItem.note));
      }
    } else {
      items.addAll(notes.map(_NoteIndexItem.note));
    }

    return ListView.builder(
      controller: scrollController,
      padding: padding ?? EdgeInsets.only(bottom: context.uiPageBottomInset),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int i) {
        final _NoteIndexItem item = items[i];
        final AppNote? note = item.note;
        if (note == null) {
          return AppIndexSectionHeader(
            label: item.type!.label,
            icon: item.type!.icon,
            count: item.count,
          );
        }
        return AppNoteIndexRow(
          note: note,
          selected: note.id == selectedId,
          onTap: onOpen == null ? null : () => onOpen!(note),
        );
      },
    );
  }
}

class _NoteIndexItem {
  const _NoteIndexItem.header(this.type, this.count) : note = null;
  _NoteIndexItem.note(this.note) : type = null, count = 0;

  final AppNoteType? type;
  final int count;
  final AppNote? note;
}

/// One note in the rail.
///
/// Thin wrapper over [AppIndexRow] that decides what a note row *means*: the
/// stripe is the note type's colour, the warning state is "no tags", and the
/// meta line is the edit time with a word count underneath.
class AppNoteIndexRow extends StatelessWidget {
  const AppNoteIndexRow({
    super.key,
    required this.note,
    this.selected = false,
    this.onTap,
  });

  final AppNote note;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = note.noteType.intent.color(context);
    final String title = note.title.trim().isEmpty
        ? 'Untitled note'
        : note.title.trim();

    return AppIndexRow(
      title: title,
      subtitle:
          '${note.noteType.label} · ${AppTokens.relativeTime(note.updatedAt)}',
      meta: '${note.wordCount}w',
      icon: note.noteType.icon,
      accent: accent,
      selected: selected,
      onTap: onTap,
      badges: <Widget>[
        if (note.strategyName != null)
          UiBadge(
            label: note.strategyName!,
            size: UiSize.xs,
            icon: Icons.account_tree_outlined,
            intent: UiIntent.primary,
            variant: UiBadgeVariant.soft,
            maxWidth: context.sz(140),
          ),
        if (note.isPublic)
          const UiBadge(
            label: 'Public',
            size: UiSize.xs,
            icon: Icons.public_rounded,
            variant: UiBadgeVariant.outline,
          ),
        for (final String tag in note.tags.take(2))
          UiBadge(
            label: '#$tag',
            size: UiSize.xs,
            variant: UiBadgeVariant.ghost,
          ),
      ],
    );
  }
}
