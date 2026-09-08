/// Enhanced linking components for dynamic connections between Strategies, Journal, and Notes.
///
/// These components provide visual chips and pickers for creating and displaying links
/// between different entities in a compact, responsive manner.

import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../theme/app_tokens.dart';

/// A compact chip showing a linked entity with its type indicator.
///
/// Used in detail views to show what this entity is connected to.
class AppLinkChip extends StatelessWidget {
  const AppLinkChip({
    super.key,
    required this.ref,
    this.onTap,
    this.onRemove,
    this.compact = false,
  });

  /// The link reference containing kind, id, title
  final AppLinkRef ref;

  /// Callback when chip is tapped to navigate
  final VoidCallback? onTap;

  /// Callback to remove the link (editing mode)
  final VoidCallback? onRemove;

  /// Use compact layout with smaller padding and text
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color intentColor = _getIntentColor(context);

    return Material(
      color: context.uiColors.surfaceElevated,
      borderRadius: context.radius(compact ? theme.radii.sm : theme.radii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: context.radius(compact ? theme.radii.sm : theme.radii.md),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(compact ? theme.spacing.xs : theme.spacing.sm),
            vertical: context.sp(compact ? theme.spacing.xxs : theme.spacing.xs),
          ),
          decoration: BoxDecoration(
            borderRadius: context.radius(compact ? theme.radii.sm : theme.radii.md),
            border: Border.all(color: intentColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                ref.kind.icon,
                size: context.sz(compact ? 12 : 14),
                color: intentColor,
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Flexible(
                child: Text(
                  ref.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (compact ? context.uiText.caption : context.uiText.label).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onRemove != null) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.xxs)),
                InkWell(
                  onTap: onRemove,
                  borderRadius: context.radius(theme.radii.full),
                  child: Icon(
                    Icons.close_rounded,
                    size: context.sz(compact ? 12 : 14),
                    color: context.uiColors.foregroundMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getIntentColor(BuildContext context) {
    switch (ref.kind) {
      case AppLinkKind.strategy:
        return context.uiColors.primary;
      case AppLinkKind.journal:
        return context.uiColors.bullish;
      case AppLinkKind.note:
        return context.uiColors.info;
    }
  }
}

/// A group of link chips organized by type.
///
/// Displays sections for strategies, journal entries, and notes
/// that are linked to the current entity.
class AppLinkChipGroup extends StatelessWidget {
  const AppLinkChipGroup({
    super.key,
    required this.strategies,
    required this.journals,
    required this.notes,
    this.onTapStrategy,
    this.onTapJournal,
    this.onTapNote,
    this.onRemoveStrategy,
    this.onRemoveJournal,
    this.onRemoveNote,
    this.compact = false,
  });

  final List<AppLinkRef> strategies;
  final List<AppLinkRef> journals;
  final List<AppLinkRef> notes;

  final ValueChanged<AppLinkRef>? onTapStrategy;
  final ValueChanged<AppLinkRef>? onTapJournal;
  final ValueChanged<AppLinkRef>? onTapNote;

  final Function(int index)? onRemoveStrategy;
  final Function(int index)? onRemoveJournal;
  final Function(int index)? onRemoveNote;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    if (strategies.isEmpty && journals.isEmpty && notes.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (strategies.isNotEmpty) ...<Widget>[
          _buildSection(
            context,
            label: 'Strategies',
            icon: Icons.auto_graph,
            refs: strategies,
            onTap: onTapStrategy,
            onRemove: onRemoveStrategy != null 
                ? (int i) => onRemoveStrategy!(i) 
                : null,
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
        ],
        if (journals.isNotEmpty) ...<Widget>[
          _buildSection(
            context,
            label: 'Journal Entries',
            icon: Icons.journal,
            refs: journals,
            onTap: onTapJournal,
            onRemove: onRemoveJournal != null 
                ? (int i) => onRemoveJournal!(i) 
                : null,
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
        ],
        if (notes.isNotEmpty) ...<Widget>[
          _buildSection(
            context,
            label: 'Notes',
            icon: Icons.note,
            refs: notes,
            onTap: onTapNote,
            onRemove: onRemoveNote != null 
                ? (int i) => onRemoveNote!(i) 
                : null,
          ),
        ],
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String label,
    required IconData icon,
    required List<AppLinkRef> refs,
    ValueChanged<AppLinkRef>? onTap,
    void Function(int)? onRemove,
  }) {
    final UiTheme theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              icon,
              size: context.sz(14),
              color: context.uiColors.foregroundMuted,
            ),
            SizedBox(width: context.sp(theme.spacing.xxs)),
            Text(
              label,
              style: context.uiText.label.copyWith(
                color: context.uiColors.foregroundMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xxs),
          children: List<Widget>.generate(
            refs.length,
            (int i) => AppLinkChip(
              ref: refs[i],
              compact: compact,
              onTap: onTap != null ? () => onTap(refs[i]) : null,
              onRemove: onRemove != null ? () => onRemove(i) : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final UiTheme theme = context.ui;

    return Container(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      decoration: BoxDecoration(
        color: context.uiColors.surfaceMuted,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(color: context.uiColors.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.link_off_outlined,
            size: context.sz(24),
            color: context.uiColors.foregroundSubtle,
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'No links yet',
                  style: context.uiText.labelStrong,
                ),
                Text(
                  'Connect this to strategies, trades, or notes',
                  style: context.uiText.caption.copyWith(
                    color: context.uiColors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A picker dialog for selecting entities to link.
///
/// Shows tabs for strategies, journal entries, and notes
/// allowing users to select one or more items to link.
class AppLinkPicker extends StatefulWidget {
  const AppLinkPicker({
    super.key,
    required this.currentKind,
    this.preselected = const <AppLinkRef>[],
    this.allowMultiple = true,
    this.filterQuery,
  });

  /// The kind of entity we're linking FROM (to exclude self-references)
  final AppLinkKind currentKind;

  /// Already selected links
  final List<AppLinkRef> preselected;

  /// Allow selecting multiple items
  final bool allowMultiple;

  /// Optional search filter
  final String? filterQuery;

  @override
  State<AppLinkPicker> createState() => _AppLinkPickerState();
}

class _AppLinkPickerState extends State<AppLinkPicker> {
  late TabController _tabController;
  final Set<AppLinkRef> _selected = <AppLinkRef>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selected.addAll(widget.preselected);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return Dialog(
      insetPadding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Container(
        width: MediaQuery.of(context).size.width > 600 ? 600 : null,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
              decoration: BoxDecoration(
                color: context.uiColors.surfaceMuted,
                borderRadius: context.radius(theme.radii.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Link to...',
                    style: context.uiText.titleStrong,
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  TabBar(
                    controller: _tabController,
                    tabs: const <Widget>[
                      Tab(icon: Icon(Icons.auto_graph), text: 'Strategies'),
                      Tab(icon: Icon(Icons.journal), text: 'Journal'),
                      Tab(icon: Icon(Icons.note), text: 'Notes'),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  _buildList(AppLinkKind.strategy),
                  _buildList(AppLinkKind.journal),
                  _buildList(AppLinkKind.note),
                ],
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.uiColors.border),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    '${_selected.length} selected',
                    style: context.uiText.label.copyWith(
                      color: context.uiColors.foregroundMuted,
                    ),
                  ),
                  const Spacer(),
                  UiButton(
                    label: 'Cancel',
                    variant: UiVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  UiButton(
                    label: 'Link ${_selected.length > 1 ? '$_selected.length Items' : ''}',
                    variant: UiVariant.filled,
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_selected.toList()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(AppLinkKind kind) {
    // This would be populated from repositories
    // For now, show empty state
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.uiSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              kind.icon,
              size: context.sz(48),
              color: context.uiColors.foregroundSubtle,
            ),
            SizedBox(height: context.uiSpace.md),
            Text(
              'No ${kind.label.toLowerCase()} available',
              style: context.uiText.bodyStrong,
            ),
            SizedBox(height: context.uiSpace.sm),
            Text(
              'Create some ${kind.label.toLowerCase()} first',
              style: context.uiText.caption.copyWith(
                color: context.uiColors.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays link statistics in a compact format.
class AppLinkStats extends StatelessWidget {
  const AppLinkStats({
    super.key,
    required this.strategyCount,
    required this.journalCount,
    required this.noteCount,
    this.onTap,
  });

  final int strategyCount;
  final int journalCount;
  final int noteCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return InkWell(
      onTap: onTap,
      borderRadius: context.radius(theme.radii.md),
      child: Container(
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        decoration: BoxDecoration(
          color: context.uiColors.surfaceMuted,
          borderRadius: context.radius(theme.radii.lg),
          border: Border.all(color: context.uiColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildStat(
              context,
              icon: Icons.auto_graph,
              count: strategyCount,
              label: 'Strategies',
              color: context.uiColors.primary,
            ),
            _buildStat(
              context,
              icon: Icons.journal,
              count: journalCount,
              label: 'Trades',
              color: context.uiColors.bullish,
            ),
            _buildStat(
              context,
              icon: Icons.note,
              count: noteCount,
              label: 'Notes',
              color: context.uiColors.info,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(
    BuildContext context, {
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    final UiTheme theme = context.ui;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: context.sz(20),
          color: color,
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(
          '$count',
          style: context.uiText.heading.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: context.uiText.caption.copyWith(
            color: context.uiColors.foregroundMuted,
          ),
        ),
      ],
    );
  }
}
