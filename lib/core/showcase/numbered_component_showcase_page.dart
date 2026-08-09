import 'package:flutter/material.dart';

import '../app-ui/app_ui.dart';
import 'blocks_showcase.dart';
import 'cards_showcase.dart';
import 'charts_showcase.dart';
import 'component_showcase_page.dart';
import 'feedback_showcase.dart';
import 'input_showcase.dart';
import 'layout_showcase.dart';
import 'selection_showcase.dart';
import 'state_gallery.dart';

/// Category used by the filter chips, sidebar and the jump-to index.
enum ShowcaseCategory {
  foundation('Foundation', Icons.widgets_outlined),
  inputs('Inputs', Icons.input_outlined),
  selection('Selection & navigation', Icons.check_box_outlined),
  charts('Charts & data', Icons.bar_chart_outlined),
  layout('Layout', Icons.dashboard_customize_outlined),
  overlays('Feedback & overlays', Icons.layers_outlined),
  cards('Domain cards', Icons.subtitles_outlined),
  blocks('Domain blocks', Icons.view_quilt_outlined);

  const ShowcaseCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// One numbered slice of the showcase: a category, the number of galleries it
/// renders and a builder that receives the running start index.
@immutable
class ShowcaseSectionSpec {
  const ShowcaseSectionSpec({
    required this.category,
    required this.description,
    required this.count,
    required this.builder,
  });

  final ShowcaseCategory category;
  final String description;
  final int count;
  final Widget Function(int startIndex) builder;
}

/// Master showcase with sidebar category navigation.
///
/// Strictly renders only the single active selected category to eliminate
/// site lag and maintain high rendering performance.
class NumberedComponentShowcasePage extends StatefulWidget {
  const NumberedComponentShowcasePage({
    super.key,
    this.selectedId = 'showcase',
  });

  final String selectedId;

  @override
  State<NumberedComponentShowcasePage> createState() =>
      _NumberedComponentShowcasePageState();
}

class _NumberedComponentShowcasePageState
    extends State<NumberedComponentShowcasePage> {
  UiShowcaseConfig _config = const UiShowcaseConfig();
  String _query = '';
  late ShowcaseCategory _activeCategory = _resolveCategory(widget.selectedId);
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(NumberedComponentShowcasePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != oldWidget.selectedId) {
      setState(() {
        _activeCategory = _resolveCategory(widget.selectedId);
      });
    }
  }

  ShowcaseCategory _resolveCategory(String id) {
    switch (id) {
      case 'showcase_inputs':
        return ShowcaseCategory.inputs;
      case 'showcase_selection':
        return ShowcaseCategory.selection;
      case 'showcase_charts':
        return ShowcaseCategory.charts;
      case 'showcase_layout':
        return ShowcaseCategory.layout;
      case 'showcase_overlays':
        return ShowcaseCategory.overlays;
      case 'showcase_cards':
        return ShowcaseCategory.cards;
      case 'showcase_blocks':
        return ShowcaseCategory.blocks;
      case 'showcase_foundation':
      default:
        return ShowcaseCategory.foundation;
    }
  }

  static const List<ShowcaseSectionSpec> _specs = <ShowcaseSectionSpec>[
    ShowcaseSectionSpec(
      category: ShowcaseCategory.foundation,
      description:
          'Buttons, badges, surfaces and the async wrapper every other '
          'component is composed from.',
      count: kFoundationGalleryCount,
      builder: _buildFoundation,
    ),
    ShowcaseSectionSpec(
      category: ShowcaseCategory.inputs,
      description:
          'Text entry, fields, toggles and sliders with validation, '
          'adornments and helper messaging.',
      count: kInputGalleryCount,
      builder: _buildInputs,
    ),
    ShowcaseSectionSpec(
      category: ShowcaseCategory.selection,
      description:
          'Selects, toggle groups, radios, disclosure and tabbed navigation.',
      count: kSelectionGalleryCount,
      builder: _buildSelection,
    ),
    ShowcaseSectionSpec(
      category: ShowcaseCategory.charts,
      description:
          'Every chart and data-display component on the shared axis, scale, '
          'legend and crosshairs core.',
      count: kChartsGalleryCount,
      builder: _buildCharts,
    ),
    ShowcaseSectionSpec(
      category: ShowcaseCategory.layout,
      description:
          'Grids, pages, panes, dividers and navigation primitives.',
      count: kLayoutGalleryCount,
      builder: _buildLayout,
    ),
    ShowcaseSectionSpec(
      category: ShowcaseCategory.overlays,
      description:
          'Callouts, empty states, avatars, tooltips, dialogs, drawers and '
          'toasts with dismissal states.',
      count: kFeedbackGalleryCount,
      builder: _buildFeedback,
    ),
    ShowcaseSectionSpec(
      category: ShowcaseCategory.cards,
      description:
          'Brand primitives and model-driven domain cards with '
          'populated, selected, loading, empty and error states.',
      count: kCardsGalleryCount,
      builder: _buildCards,
    ),
    ShowcaseSectionSpec(
      category: ShowcaseCategory.blocks,
      description:
          'Screen-level blocks and app shell shown populated, '
          'loading, empty, dense and at mobile width.',
      count: kBlocksGalleryCount,
      builder: _buildBlocks,
    ),
  ];

  static Widget _buildFoundation(int i) => FoundationShowcaseSection(startIndex: i);
  static Widget _buildInputs(int i) => InputShowcaseSection(startIndex: i);
  static Widget _buildSelection(int i) => SelectionShowcaseSection(startIndex: i);
  static Widget _buildCharts(int i) => ChartsShowcaseSection(startIndex: i);
  static Widget _buildLayout(int i) => LayoutShowcaseSection(startIndex: i);
  static Widget _buildFeedback(int i) => FeedbackShowcaseSection(startIndex: i);
  static Widget _buildCards(int i) => CardsShowcaseSection(startIndex: i);
  static Widget _buildBlocks(int i) => BlocksShowcaseSection(startIndex: i);

  static int get totalEntries =>
      _specs.fold<int>(0, (int sum, ShowcaseSectionSpec s) => sum + s.count);

  static Map<ShowcaseCategory, ({int start, int end})> get categoryRanges {
    final Map<ShowcaseCategory, ({int start, int end})> map = {};
    int running = 1;
    for (final ShowcaseSectionSpec s in _specs) {
      map[s.category] = (start: running, end: running + s.count - 1);
      running += s.count;
    }
    return map;
  }

  bool _matches(ShowcaseSectionSpec spec, int start) {
    if (_query.trim().isEmpty && spec.category != _activeCategory) {
      return false;
    }
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final int number = int.tryParse(q) ?? -1;
    if (number > 0 && number >= start && number < start + spec.count) {
      return true;
    }
    return spec.category.label.toLowerCase().contains(q) ||
        spec.description.toLowerCase().contains(q);
  }

  void _selectCategory(ShowcaseCategory cat) {
    setState(() {
      _activeCategory = cat;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UiApp(
      theme: _config.dark ? UiTheme.dark() : UiTheme.light(),
      builder: (BuildContext ctx) => UiShowcaseScope(
        config: _config,
        onChanged: (UiShowcaseConfig c) => setState(() => _config = c),
        child: UiShowcaseEnvironment(
          config: _config,
          child: Builder(builder: _body),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = context.ui;
    final double gap = context.sp(theme.spacing.lg);
    final ranges = categoryRanges;

    int running = 1;
    final List<Widget> sections = <Widget>[];
    for (final ShowcaseSectionSpec spec in _specs) {
      final int start = running;
      running += spec.count;
      if (!_matches(spec, start)) continue;
      sections
        ..add(
          _SectionHeading(
            spec: spec,
            start: start,
            end: start + spec.count - 1,
          ),
        )
        ..add(SizedBox(height: context.sp(theme.spacing.md)))
        ..add(spec.builder(start))
        ..add(SizedBox(height: gap));
    }

    final Widget mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(total: totalEntries),
        SizedBox(height: gap),
        Row(
          children: <Widget>[
            UiDropdownMenu(
              actions: <UiMenuItem>[
                for (final cat in ShowcaseCategory.values)
                  UiMenuItem(
                    label:
                        '${cat.label} (#${ranges[cat]?.start}–${ranges[cat]?.end})',
                    icon: cat.icon,
                    selected: _activeCategory == cat && _query.isEmpty,
                    onTap: () => _selectCategory(cat),
                  ),
              ],
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.sm),
                  vertical: context.sp(theme.spacing.xs),
                ),
                decoration: BoxDecoration(
                  color: theme.colors.surface,
                  borderRadius: context.radius(theme.radii.md),
                  border: Border.all(
                    color: theme.colors.border,
                    width: theme.borders.hairline,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      _activeCategory.icon,
                      size: context.sz(14),
                      color: theme.colors.primary,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      'Category: ${_activeCategory.label} (#${ranges[_activeCategory]?.start}–${ranges[_activeCategory]?.end})',
                      style: context.uiText.bodyStrong.copyWith(fontSize: 11.5),
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Icon(
                      Icons.unfold_more_rounded,
                      size: context.sz(14),
                      color: theme.colors.foregroundMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        const UiShowcaseControlBar(),
        SizedBox(height: gap),
        UiInput.search(
          hintText: 'Search by component number, category or description…',
          value: _query,
          onChanged: (String q) => setState(() => _query = q),
          onClear: () => setState(() => _query = ''),
        ),
        SizedBox(height: gap),
        if (sections.isEmpty)
          const UiEmptyState(
            icon: Icons.search_off,
            title: 'No matching components found',
            message:
                'Try another search term or select a category from the dropdown menu above.',
          )
        else
          ...sections,
        SizedBox(height: gap),
      ],
    );

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.all(context.sp(theme.spacing.md)),
          child: mainContent,
        ),
      ),
    );
  }
}



class _Header extends StatelessWidget {
  const _Header({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: context.sp(theme.spacing.sm),
          runSpacing: context.sp(theme.spacing.xs),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            const AppLogo(),
            UiBadge(
              label: '$total entries',
              intent: UiIntent.primary,
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
            ),
            const UiBadge(
              label: 'single category active',
              variant: UiBadgeVariant.outline,
              size: UiSize.xs,
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Text(
          'TraderHub UI Kit — Component Showcase',
          style: context.uiText.subheading.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colors.foreground,
            fontSize: 14,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(
          'Select a category from the dropdown menu to filter component state matrix. '
          'Only the active category is rendered at a time for optimal performance.',
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.spec,
    required this.start,
    required this.end,
  });

  final ShowcaseSectionSpec spec;
  final int start;
  final int end;

  @override
  Widget build(BuildContext context) {
    return UiShowcaseSection(
      title: spec.category.label,
      subtitle: spec.description,
      trailing: UiBadge(
        label: '#$start–$end',
        variant: UiBadgeVariant.outline,
        size: UiSize.sm,
      ),
    );
  }
}
