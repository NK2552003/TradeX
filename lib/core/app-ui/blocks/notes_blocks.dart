import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../cards/notes_cards.dart';
import '../models/app_models.dart';

/// Note blocks — compose the note cards into the list surface.

/// Search, type filter, tag filter, sort and density in one bar.
///
/// Stacked on a phone and a single row from tablet up, because every control
/// here is optional refinement: on a narrow screen the search field earns the
/// full width and the rest scrolls underneath it.
class AppNoteFilterBlock extends StatelessWidget {
  const AppNoteFilterBlock({
    super.key,
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

  Future<void> _showMobileFilters(BuildContext context) async {
    AppNoteType? selectedType = type;
    AppNoteSort selectedSort = sort;
    AppNoteDensity selectedDensity = density;
    String? selectedTag = tag;

    await UiDialog.show<void>(
      context,
      child: StatefulBuilder(
        builder: (BuildContext sheetContext, StateSetter setSheetState) {
          void update(VoidCallback change) => setSheetState(change);
          return UiDialog(
            title: 'Filter notes',
            description: 'Narrow the list and choose how notes are displayed.',
            icon: Icons.tune_rounded,
            actions: <Widget>[
              UiButton(
                label: 'Reset',
                variant: UiVariant.ghost,
                expandOnMobile: false,
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
              UiButton(
                label: 'Done',
                expandOnMobile: false,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.58,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
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
                          const UiOption<String>(
                            value: 'all',
                            label: 'All types',
                          ),
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
                            UiOption<AppNoteSort>(
                              value: value,
                              label: value.label,
                            ),
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
                ),
              ),
            ),
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
    final bool mobile = context.uiRes.isMobile || width < context.sz(1040);

    final Widget search = UiInput.search(
      value: query,
      hintText: 'Search titles, body text, tickers or tags',
      onChanged: onQueryChanged,
    );

    final Widget typeFilter = UiSelect<String>(
      expand: true,
      value: type?.name ?? 'all',
      onChanged: (String value) => onTypeChanged?.call(
        value == 'all' ? null : AppNoteType.values.byName(value),
      ),
      hintText: 'All types',
      leadingIcon: Icons.filter_alt_outlined,
      size: UiSize.sm,
      minWidth: context.sz(150),
      options: <UiOption<String>>[
        const UiOption<String>(value: 'all', label: 'All types'),
        for (final AppNoteType t in AppNoteType.values)
          UiOption<String>(value: t.name, label: t.label, icon: t.icon),
      ],
    );

    final Widget sortSelect = UiSelect<AppNoteSort>(
      expand: true,
      value: sort,
      onChanged: onSortChanged,
      leadingIcon: Icons.sort_rounded,
      size: UiSize.sm,
      minWidth: context.sz(150),
      options: <UiOption<AppNoteSort>>[
        for (final AppNoteSort s in AppNoteSort.values)
          UiOption<AppNoteSort>(value: s, label: s.label),
      ],
    );

    final Widget densityToggle = UiToggleGroup<AppNoteDensity>(
      value: density,
      onChanged: onDensityChanged,
      size: UiSize.sm,
      iconOnly: true,
      allowEmpty: false,
      options: const <UiToggleOption<AppNoteDensity>>[
        UiToggleOption<AppNoteDensity>(
          value: AppNoteDensity.titleOnly,
          label: 'Compact',
          icon: Icons.view_headline_rounded,
          tooltip: 'Titles only',
        ),
        UiToggleOption<AppNoteDensity>(
          value: AppNoteDensity.comfortable,
          label: 'Comfortable',
          icon: Icons.view_agenda_outlined,
          tooltip: 'Title and preview',
        ),
        UiToggleOption<AppNoteDensity>(
          value: AppNoteDensity.full,
          label: 'Full',
          icon: Icons.dashboard_customize_outlined,
          tooltip: 'Everything, including tags',
        ),
      ],
    );

    final Widget? tagRow = availableTags.isEmpty
        ? null
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                UiBadge(
                  label: 'All tags',
                  variant: tag == null
                      ? UiBadgeVariant.solid
                      : UiBadgeVariant.outline,
                  intent: UiIntent.primary,
                  size: UiSize.xs,
                  onTap: () => onTagChanged?.call(null),
                ),
                for (final String t in availableTags) ...<Widget>[
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  UiBadge(
                    label: '#$t',
                    variant: tag == t
                        ? UiBadgeVariant.solid
                        : UiBadgeVariant.outline,
                    intent: UiIntent.primary,
                    size: UiSize.xs,
                    onTap: () => onTagChanged?.call(tag == t ? null : t),
                  ),
                ],
              ],
            ),
          );

    if (mobile) {
      final int activeFilters = (type == null ? 0 : 1) + (tag == null ? 0 : 1);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          search,
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiButton(
            label: 'Filters and display',
            leadingIcon: Icons.tune_rounded,
            trailingIcon: Icons.keyboard_arrow_up_rounded,
            badgeCount: activeFilters == 0 ? null : activeFilters,
            variant: UiVariant.secondary,
            expand: true,
            onPressed: () => _showMobileFilters(context),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: search),
            SizedBox(width: context.sp(theme.spacing.md)),
            SizedBox(width: context.sz(220), child: typeFilter),
            SizedBox(width: context.sp(theme.spacing.sm)),
            SizedBox(width: context.sz(240), child: sortSelect),
            SizedBox(width: context.sp(theme.spacing.sm)),
            densityToggle,
            if (onNew != null) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.sm)),
              UiButton(
                label: 'New note',
                leadingIcon: Icons.add_rounded,
                size: UiSize.sm,
                onPressed: onNew,
              ),
            ],
          ],
        ),
        if (tagRow != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          tagRow,
        ],
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
    final double gap = context.sp(theme.spacing.md);

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
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xxl)),
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
    final double gap = context.sp(theme.spacing.md);

    if (!loading && notes.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.sp(theme.spacing.xxl),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int column = 0; column < columns; column++) ...<Widget>[
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
                            loading ? 'note_skeleton_$index' : notes[index].id,
                          ),
                          child: card,
                        );
                      }(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
