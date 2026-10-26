import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_checkbox.dart';
import 'ui_card.dart';
import 'ui_icon_button.dart';
import 'ui_dropdown_menu.dart';
import 'ui_badge.dart';
import 'ui_scrollbar.dart';
import 'ui_common.dart';
import 'ui_skeleton.dart';

class UiTableColumn<T> {
  const UiTableColumn({
    String? header,
    this.label,
    this.id,
    Widget Function(BuildContext context, T row)? cell,
    this.cellBuilder,
    this.valueGetter,
    this.numeric = false,
    this.flex = 1,
    this.width,
    this.hideBelow = UiTableVisibility.always,
    int Function(T a, T b)? compare,
    this.sortValue,
    this.sortable,
  }) : rawHeader = header,
       rawCell = cell,
       rawCompare = compare;

  final String? rawHeader;
  final String? label;
  final String? id;
  final Widget Function(BuildContext context, T row)? rawCell;
  final Widget Function(BuildContext context, T row)? cellBuilder;
  final String Function(T row)? valueGetter;
  final bool numeric;
  final int flex;
  final double? width;

  /// Progressive disclosure: drop low-priority columns on small screens.
  final UiTableVisibility hideBelow;

  /// Provide a comparator to make the column sortable by tapping its header.
  final int Function(T a, T b)? rawCompare;
  final Comparable<Object?> Function(T row)? sortValue;
  final bool? sortable;

  String get header => rawHeader ?? label ?? id ?? '';

  Widget Function(BuildContext context, T row) get cell =>
      rawCell ??
      cellBuilder ??
      (BuildContext context, T row) => Text(
        valueGetter != null ? valueGetter!(row) : '',
        style: context.uiText.body,
      );

  int Function(T a, T b)? get compare =>
      rawCompare ??
      (sortValue != null
          ? (T a, T b) => sortValue!(a).compareTo(sortValue!(b))
          : null);
}

enum UiTableVisibility { always, tabletUp, desktopUp }

/// Responsive data table. On phones it can collapse into stacked cards so the
/// same column definitions serve every screen size.
///
/// Sorting (any column with a `compare`) and pagination (`pageSize`) are
/// handled internally; pass [onSort] to observe changes or [sortColumn] /
/// [sortAscending] to drive sorting from outside (e.g. server-side sorting).
class UiTable<T> extends StatefulWidget {
  const UiTable({
    super.key,
    required this.columns,
    required this.rows,
    this.rowKey,
    this.onRowTap,
    this.stackOnMobile = false,
    this.emptyLabel = 'No data',
    this.pageSize,
    this.onSort,
    this.sortColumn,
    this.sortColumnId,
    this.sortAscending,
    this.footer,
    this.loading = false,
    this.errorText,
    this.selectable = false,
    this.selectedRows,
    this.onSelectionChanged,
    this.expandableWhen,
    this.expandedBuilder,
    this.stickyHeader = false,
    this.maxBodyHeight,
    this.density = UiDensity.comfortable,
  });

  final List<UiTableColumn<T>> columns;
  final List<T> rows;
  final Object Function(T row)? rowKey;
  final void Function(T row)? onRowTap;
  final bool stackOnMobile;
  final String emptyLabel;

  /// Rows per page. Null disables pagination.
  final int? pageSize;

  /// Called with the column index and direction whenever sorting changes.
  final void Function(int columnIndex, bool ascending)? onSort;

  /// Controlled sort state. When provided, rows are assumed pre-sorted.
  final int? sortColumn;
  final String? sortColumnId;
  final bool? sortAscending;

  /// Optional footer row (totals, summaries).
  final Widget? footer;

  /// Shows skeleton rows instead of data while a fetch is in flight.
  final bool loading;

  /// When set, replaces the table body with an error message.
  final String? errorText;

  /// Renders a leading checkbox column and enables multi-row selection.
  final bool selectable;
  final Set<T>? selectedRows;
  final ValueChanged<Set<T>>? onSelectionChanged;

  /// Renders a leading disclosure chevron; rows for which this returns true
  /// can be expanded to reveal [expandedBuilder] content beneath them.
  final bool Function(T row)? expandableWhen;
  final Widget Function(BuildContext context, T row)? expandedBuilder;

  /// Keeps the header visible while the body scrolls within [maxBodyHeight].
  final bool stickyHeader;
  final double? maxBodyHeight;

  /// Row padding density.
  final UiDensity density;

  @override
  State<UiTable<T>> createState() => _UiTableState<T>();
}

class _UiTableState<T> extends State<UiTable<T>> {
  int? _sortCol;
  bool _asc = true;
  int _page = 0;
  final Set<T> _expanded = <T>{};
  final ScrollController _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  Set<T> get _selected => widget.selectedRows ?? const <Never>{};

  int? get _controlledColumn {
    if (widget.sortColumn != null) return widget.sortColumn;
    if (widget.sortColumnId == null) return null;
    final index = widget.columns.indexWhere(
      (column) => column.id == widget.sortColumnId,
    );
    return index < 0 ? null : index;
  }

  bool get _controlled => _controlledColumn != null;
  int? get _activeSortCol => _controlled ? _controlledColumn : _sortCol;
  bool get _activeAsc => _controlled ? (widget.sortAscending ?? true) : _asc;

  @override
  void didUpdateWidget(UiTable<T> old) {
    super.didUpdateWidget(old);
    if (old.rows.length != widget.rows.length ||
        old.pageSize != widget.pageSize) {
      _page = 0;
    }
    _expanded.removeWhere((row) => !widget.rows.contains(row));
  }

  List<UiTableColumn<T>> _visible(BuildContext context) {
    final r = context.uiRes;
    return widget.columns.where((UiTableColumn<T> c) {
      switch (c.hideBelow) {
        case UiTableVisibility.always:
          return true;
        case UiTableVisibility.tabletUp:
          return !r.isMobile;
        case UiTableVisibility.desktopUp:
          return r.isDesktop;
      }
    }).toList();
  }

  void _toggleSort(int columnIndex) {
    final bool asc = _activeSortCol == columnIndex ? !_activeAsc : true;
    if (!_controlled) {
      setState(() {
        _sortCol = columnIndex;
        _asc = asc;
        _page = 0;
      });
    }
    widget.onSort?.call(columnIndex, asc);
  }

  List<T> get _sorted {
    final int? col = _activeSortCol;
    if (_controlled || col == null || col >= widget.columns.length) {
      return widget.rows;
    }
    final int Function(T, T)? cmp = widget.columns[col].compare;
    if (cmp == null) return widget.rows;
    final List<T> out = List<T>.of(widget.rows)..sort(cmp);
    return _activeAsc ? out : out.reversed.toList();
  }

  int get _pageCount {
    final int? size = widget.pageSize;
    if (size == null || size <= 0) return 1;
    return (widget.rows.length / size).ceil().clamp(1, 1 << 30);
  }

  List<T> _paged(List<T> source) {
    final int? size = widget.pageSize;
    if (size == null || size <= 0) return source;
    final int start = (_page * size).clamp(0, source.length);
    return source.sublist(start, (start + size).clamp(0, source.length));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _buildTable(context, constraints.maxWidth),
  );

  Widget _buildTable(BuildContext context, double availableWidth) {
    final theme = context.ui;
    final double densityPad = widget.density.factor;
    if (widget.errorText != null) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.error_outline,
                color: theme.colors.bearish,
                size: context.sz(theme.sizes.iconLg),
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Text(
                widget.errorText!,
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (widget.loading) {
      return Column(
        children: <Widget>[
          for (int i = 0; i < (widget.pageSize ?? 5).clamp(3, 8); i++)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: UiSkeleton(
                width: double.infinity,
                height: theme.sizes.controlHeightMd,
              ),
            ),
        ],
      );
    }
    if (widget.rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
        child: Center(
          child: Text(
            widget.emptyLabel,
            style: context.uiText.body.copyWith(
              color: theme.colors.foregroundSubtle,
            ),
          ),
        ),
      );
    }

    final List<T> visibleRows = _paged(_sorted);

    if (widget.stackOnMobile && availableWidth < context.sz(640)) {
      return _stackedRecords(context, visibleRows);
    }

    final List<UiTableColumn<T>> cols = _visible(context);

    final Widget headerRow = Container(
      color: theme.colors.surfaceMuted,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.lg),
        vertical: context.sp(theme.spacing.md),
      ),
      child: Row(
        children: <Widget>[
          if (widget.selectable)
            SizedBox(
              width: context.sz(theme.sizes.controlHeightXs),
              child: UiCheckbox(
                value:
                    visibleRows.isNotEmpty &&
                    visibleRows.every(_selected.contains),
                onChanged: (bool value) {
                  final next = <T>{..._selected};
                  if (value) {
                    next.addAll(visibleRows);
                  } else {
                    next.removeAll(visibleRows);
                  }
                  widget.onSelectionChanged?.call(next);
                },
              ),
            ),
          if (widget.expandableWhen != null)
            SizedBox(width: context.sz(theme.sizes.controlHeightXs)),
          for (final UiTableColumn<T> col in cols)
            _cellWrap(context, col, _headerCell(context, col)),
        ],
      ),
    );

    final List<Widget> bodyRows = <Widget>[
      for (int i = 0; i < visibleRows.length; i++)
        Column(
          key: widget.rowKey == null
              ? null
              : ValueKey(widget.rowKey!(visibleRows[i])),
          children: <Widget>[
            UiInteractive(
              enabled: widget.onRowTap != null,
              onTap: widget.onRowTap == null
                  ? null
                  : () => widget.onRowTap!(visibleRows[i]),
              builder: (BuildContext ctx, UiInteractiveState s) => Container(
                decoration: BoxDecoration(
                  color: s.hovered
                      ? theme.colors.surfaceHover
                      : theme.colors.surface,
                  border: Border(
                    top: BorderSide(
                      color: theme.colors.border,
                      width: theme.borders.hairline,
                    ),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: ctx.sp(theme.spacing.lg),
                  vertical: ctx.sp(theme.spacing.md) * densityPad,
                ),
                child: Row(
                  children: <Widget>[
                    if (widget.selectable)
                      SizedBox(
                        width: ctx.sz(theme.sizes.controlHeightXs),
                        child: UiCheckbox(
                          value: _selected.contains(visibleRows[i]),
                          onChanged: (bool v) {
                            final Set<T> next = <T>{..._selected};
                            v
                                ? next.add(visibleRows[i])
                                : next.remove(visibleRows[i]);
                            widget.onSelectionChanged?.call(next);
                          },
                        ),
                      ),
                    if (widget.expandableWhen != null)
                      SizedBox(
                        width: ctx.sz(theme.sizes.controlHeightXs),
                        child: widget.expandableWhen!(visibleRows[i])
                            ? UiInteractive(
                                onTap: () => setState(
                                  () => _expanded.contains(visibleRows[i])
                                      ? _expanded.remove(visibleRows[i])
                                      : _expanded.add(visibleRows[i]),
                                ),
                                builder: (BuildContext c, _) => Icon(
                                  _expanded.contains(visibleRows[i])
                                      ? Icons.expand_more
                                      : Icons.chevron_right,
                                  size: c.sz(theme.sizes.iconSm),
                                  color: theme.colors.foregroundMuted,
                                ),
                              )
                            : null,
                      ),
                    for (final UiTableColumn<T> col in cols)
                      _cellWrap(
                        ctx,
                        col,
                        Align(
                          alignment: col.numeric
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: col.cell(ctx, visibleRows[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.expandableWhen != null &&
                widget.expandedBuilder != null &&
                widget.expandableWhen!(visibleRows[i]) &&
                _expanded.contains(visibleRows[i]))
              Container(
                width: double.infinity,
                color: theme.colors.surfaceMuted,
                padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                child: widget.expandedBuilder!(context, visibleRows[i]),
              ),
          ],
        ),
    ];

    Widget bodyContent = Column(children: bodyRows);
    // When a max body height is supplied (or a sticky header is requested),
    // the header row above stays put while only the row list scrolls.
    if (widget.maxBodyHeight != null) {
      bodyContent = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: context.sp(widget.maxBodyHeight!),
        ),
        child: SingleChildScrollView(child: bodyContent),
      );
    } else if (widget.stickyHeader) {
      // No explicit height: still isolate the header from the body scroll
      // region so it never scrolls with the rows below it.
      bodyContent = SingleChildScrollView(child: bodyContent);
    }

    final double minTableWidth =
        cols.fold<double>(
          0.0,
          (double acc, UiTableColumn<T> c) =>
              acc +
              (c.width != null
                  ? context.sz(c.width!)
                  : context.sz(128) * c.flex),
        ) +
        (widget.selectable ? 40.0 : 0.0) +
        (widget.expandableWhen != null ? 40.0 : 0.0) +
        context.sp(theme.spacing.lg) * 2;

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final bool needsHScroll = constraints.maxWidth < minTableWidth;
        final Widget tableContainer = Container(
          decoration: BoxDecoration(
            borderRadius: ctx.radius(theme.radii.lg),
            border: Border.all(
              color: theme.colors.border,
              width: theme.borders.hairline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              headerRow,
              bodyContent,
              if (widget.footer != null)
                Container(
                  width: double.infinity,
                  color: theme.colors.surfaceMuted,
                  padding: EdgeInsets.symmetric(
                    horizontal: ctx.sp(theme.spacing.lg),
                    vertical: ctx.sp(theme.spacing.md),
                  ),
                  child: widget.footer,
                ),
            ],
          ),
        );

        final Widget responsiveTable = needsHScroll
            ? UiScrollbar(
                controller: _horizontal,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(bottom: ctx.sp(theme.spacing.sm)),
                  child: SizedBox(width: minTableWidth, child: tableContainer),
                ),
              )
            : tableContainer;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            responsiveTable,
            if (widget.pageSize != null) _pager(context),
          ],
        );
      },
    );
  }

  Widget _headerCell(BuildContext context, UiTableColumn<T> col) {
    final theme = context.ui;
    final int index = widget.columns.indexOf(col);
    final bool sortable =
        col.sortable != false && (col.compare != null || widget.onSort != null);
    final bool active = _activeSortCol == index;

    final Widget label = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            col.header,
            textAlign: col.numeric ? TextAlign.right : TextAlign.left,
            style: context.uiText.caption.copyWith(
              color: active
                  ? theme.colors.foreground
                  : theme.colors.foregroundMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (sortable) ...<Widget>[
          SizedBox(width: context.sp(theme.spacing.xxs)),
          Icon(
            active
                ? (_activeAsc ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: context.sz(theme.sizes.iconSm * 0.75),
            color: active
                ? theme.colors.foreground
                : theme.colors.foregroundSubtle,
          ),
        ],
      ],
    );

    final Widget aligned = Align(
      alignment: col.numeric ? Alignment.centerRight : Alignment.centerLeft,
      child: label,
    );

    if (!sortable) return aligned;
    return UiInteractive(
      onTap: () => _toggleSort(index),
      builder: (BuildContext ctx, UiInteractiveState s) => aligned,
    );
  }

  Widget _pager(BuildContext context) {
    final theme = context.ui;
    final int total = _pageCount;
    return Padding(
      padding: EdgeInsets.only(top: context.sp(theme.spacing.md)),
      child: Row(
        children: <Widget>[
          // Expanded rather than Text + Spacer: at a high page count on a narrow
          // phone, "Page 12 of 340" plus both buttons is wider than the row.
          Expanded(
            child: Text(
              'Page ${_page + 1} of $total',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          _pageButton(
            context,
            Icons.chevron_left,
            _page > 0 ? () => setState(() => _page -= 1) : null,
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          _pageButton(
            context,
            Icons.chevron_right,
            _page < total - 1 ? () => setState(() => _page += 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _pageButton(BuildContext context, IconData icon, VoidCallback? onTap) {
    final theme = context.ui;
    // A finger needs the full 44pt target; a mouse pointer does not, so the
    // desktop build stays compact. Shrinking this on touch made the pager buttons
    // 35pt — under the minimum, and the commonest miss-tap on the table.
    final double side = context.uiRes.isMobile
        ? theme.sizes.minTapTarget
        : theme.sizes.minTapTarget * 0.8;
    return UiInteractive(
      enabled: onTap != null,
      onTap: onTap,
      builder: (BuildContext ctx, UiInteractiveState s) => Container(
        width: ctx.sz(side),
        height: ctx.sz(side),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: s.hovered ? theme.colors.surfaceHover : theme.colors.surface,
          borderRadius: ctx.radius(theme.radii.md),
          border: Border.all(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Icon(
          icon,
          size: ctx.sz(theme.sizes.iconSm),
          color: onTap == null
              ? theme.colors.disabledForeground
              : theme.colors.foreground,
        ),
      ),
    );
  }

  Widget _cellWrap(BuildContext context, UiTableColumn<T> col, Widget child) {
    final padded = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(context.ui.spacing.sm),
      ),
      child: child,
    );
    return col.width != null
        ? SizedBox(width: context.sz(col.width!), child: padded)
        : Expanded(flex: col.flex, child: padded);
  }

  Widget _stackedRecords(BuildContext context, List<T> rows) {
    final theme = context.ui;
    final sortable = widget.columns
        .where(
          (column) =>
              column.sortable != false &&
              (column.compare != null || widget.onSort != null),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sortable.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: context.sp(theme.spacing.sm),
              children: [
                UiDropdownMenu(
                  semanticLabel: 'Sort records',
                  actions: [
                    for (final column in sortable)
                      UiMenuItem(
                        label: column.header,
                        selected:
                            _activeSortCol == widget.columns.indexOf(column),
                        onPressed: () =>
                            _toggleSort(widget.columns.indexOf(column)),
                      ),
                  ],
                  child: UiBadge(
                    label: _activeSortCol == null
                        ? 'Sort records'
                        : 'Sort: ${widget.columns[_activeSortCol!].header}',
                  ),
                ),
                if (_activeSortCol != null)
                  UiIconButton(
                    icon: _activeAsc
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    tooltip: _activeAsc ? 'Sort descending' : 'Sort ascending',
                    onPressed: () => _toggleSort(_activeSortCol!),
                  ),
              ],
            ),
          ),
        for (final row in rows)
          Padding(
            key: widget.rowKey == null ? null : ValueKey(widget.rowKey!(row)),
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            child: UiCard(
              selected: _selected.contains(row),
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              onTap: widget.onRowTap == null
                  ? null
                  : () => widget.onRowTap!(row),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.selectable ||
                      widget.expandableWhen?.call(row) == true)
                    Row(
                      children: [
                        if (widget.selectable)
                          Expanded(
                            child: UiCheckbox(
                              value: _selected.contains(row),
                              label: 'Select record',
                              onChanged: (value) {
                                final next = <T>{..._selected};
                                value ? next.add(row) : next.remove(row);
                                widget.onSelectionChanged?.call(next);
                              },
                            ),
                          ),
                        if (!widget.selectable) const Spacer(),
                        if (widget.expandableWhen?.call(row) == true)
                          UiIconButton(
                            icon: _expanded.contains(row)
                                ? Icons.expand_less
                                : Icons.expand_more,
                            tooltip: _expanded.contains(row)
                                ? 'Collapse row'
                                : 'Expand row',
                            onPressed: () => setState(
                              () => _expanded.contains(row)
                                  ? _expanded.remove(row)
                                  : _expanded.add(row),
                            ),
                          ),
                      ],
                    ),
                  for (final column in widget.columns)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(theme.spacing.sm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (column.header.isNotEmpty) ...[
                            Text(
                              column.header,
                              style: context.uiText.caption.copyWith(
                                color: theme.colors.foregroundMuted,
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.xxs)),
                          ],
                          DefaultTextStyle.merge(
                            style: context.uiText.body,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: column.cell(context, row),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_expanded.contains(row) && widget.expandedBuilder != null)
                    widget.expandedBuilder!(context, row),
                ],
              ),
            ),
          ),
        if (widget.footer != null) widget.footer!,
        if (widget.pageSize != null) _pager(context),
      ],
    );
  }
}
