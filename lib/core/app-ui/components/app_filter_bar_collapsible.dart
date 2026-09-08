import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';

/// A collapsible filter bar for search, filters, and sorting.
///
/// Auto-collapses on mobile behind a toggle button.
/// Remains expanded on desktop for quick access.
class AppFilterBarCollapsible extends StatefulWidget {
  const AppFilterBarCollapsible({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    this.searchHint = 'Search...',
    this.sortOptions = const <AppSortOption>[],
    this.selectedSort,
    this.onSortChanged,
    this.filterChips = const <Widget>[],
    this.onClearFilters,
    this.activeFilterCount = 0,
    this.compact = false,
  });

  /// Current search query
  final String searchQuery;

  /// Callback when search changes
  final ValueChanged<String> onSearchChanged;

  /// Placeholder text for search field
  final String searchHint;

  /// Available sort options
  final List<AppSortOption> sortOptions;

  /// Currently selected sort option
  final String? selectedSort;

  /// Callback when sort changes
  final ValueChanged<String?>? onSortChanged;

  /// Additional filter chips (tags, status toggles, etc.)
  final List<Widget> filterChips;

  /// Clear all filters callback
  final VoidCallback? onClearFilters;

  /// Number of active filters (shown in badge on mobile)
  final int activeFilterCount;

  /// Use compact layout with reduced spacing
  final bool compact;

  @override
  State<AppFilterBarCollapsible> createState() => _AppFilterBarCollapsibleState();
}

class _AppFilterBarCollapsibleState extends State<AppFilterBarCollapsible> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    final double gutter = context.sp(widget.compact ? theme.spacing.sm : theme.spacing.md);

    // Desktop: always expanded
    if (!isMobile) {
      return _buildContent(context, gutter);
    }

    // Mobile: collapsible
    return Container(
      decoration: BoxDecoration(
        color: context.uiColors.surfaceMuted,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(color: context.uiColors.border),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.tune_rounded,
                        size: context.sz(16),
                        color: context.uiColors.foregroundMuted,
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Text(
                        'Filters',
                        style: context.uiText.labelStrong,
                      ),
                      if (widget.activeFilterCount > 0) ...<Widget>[
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        UiBadge(
                          label: '${widget.activeFilterCount}',
                          size: UiSize.xs,
                          intent: UiIntent.primary,
                        ),
                      ],
                    ],
                  ),
                ),
                UiIconButton(
                  icon: _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  tooltip: _expanded ? 'Collapse' : 'Expand',
                  size: UiSize.sm,
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildContent(context, gutter),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: theme.motion.fast,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, double gutter) {
    final UiTheme theme = context.ui;

    return Padding(
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Search row
          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: UiTextField(
                  value: widget.searchQuery,
                  hint: widget.searchHint,
                  leadingIcon: Icons.search_rounded,
                  trailingIcon: widget.searchQuery.isNotEmpty
                      ? Icons.close_rounded
                      : null,
                  onLeadingTap: widget.searchQuery.isNotEmpty
                      ? () => widget.onSearchChanged('')
                      : null,
                  onTrailingTap: widget.searchQuery.isNotEmpty
                      ? () => widget.onSearchChanged('')
                      : null,
                  onChanged: widget.onSearchChanged,
                  compact: widget.compact,
                ),
              ),
              if (widget.sortOptions.isNotEmpty) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: UiDropdown<String>(
                    value: widget.selectedSort,
                    hint: 'Sort by',
                    items: widget.sortOptions
                        .map((AppSortOption opt) => DropdownMenuItem<String>(
                              value: opt.value,
                              child: Text(opt.label),
                            ))
                        .toList(),
                    onChanged: widget.onSortChanged,
                    compact: widget.compact,
                  ),
                ),
              ),
            ],
          ),
          // Filter chips row
          if (widget.filterChips.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                ...widget.filterChips,
                if (widget.onClearFilters != null && widget.activeFilterCount > 0)
                  UiButton(
                    label: 'Clear all',
                    variant: UiVariant.ghost,
                    size: UiSize.xs,
                    onPressed: widget.onClearFilters,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Sort option for dropdown.
class AppSortOption {
  const AppSortOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}
