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
  const NumberedComponentShowcasePage({super.key});

  @override
  State<NumberedComponentShowcasePage> createState() =>
      _NumberedComponentShowcasePageState();
}

class _NumberedComponentShowcasePageState
    extends State<NumberedComponentShowcasePage> {
  UiShowcaseConfig _config = const UiShowcaseConfig();
  String _query = '';
  ShowcaseCategory _activeCategory = ShowcaseCategory.foundation;
  final ScrollController _scroll = ScrollController();

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
    final bool isMobile = context.uiRes.isMobile;
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
        const UiShowcaseControlBar(),
        SizedBox(height: gap),
        if (isMobile) ...<Widget>[
          _MobileCategorySelector(
            active: _activeCategory,
            ranges: ranges,
            onSelect: _selectCategory,
          ),
          SizedBox(height: gap),
        ],
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
                'Try another search term or select a category from the sidebar.',
          )
        else
          ...sections,
        SizedBox(height: gap),
      ],
    );

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: SafeArea(
        child: isMobile
            ? SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                child: mainContent,
              )
            : Row(
                children: <Widget>[
                  SizedBox(
                    width: context.sz(280),
                    child: _Sidebar(
                      active: _activeCategory,
                      query: _query,
                      ranges: ranges,
                      onSelect: _selectCategory,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.xl),
                        vertical: context.sp(theme.spacing.lg),
                      ),
                      child: mainContent,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.active,
    required this.query,
    required this.ranges,
    required this.onSelect,
  });

  final ShowcaseCategory active;
  final String query;
  final Map<ShowcaseCategory, ({int start, int end})> ranges;
  final ValueChanged<ShowcaseCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          right: BorderSide(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.sm),
              horizontal: context.sp(theme.spacing.xs),
            ),
            child: Row(
              children: <Widget>[
                const AppLogoMark(size: 28),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Text(
                  'TraderHub UI',
                  style: context.uiText.heading.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Text(
            'CATEGORIES',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Expanded(
            child: ListView(
              children: <Widget>[
                for (final cat in ShowcaseCategory.values) ...<Widget>[
                  _SidebarTile(
                    title: cat.label,
                    icon: cat.icon,
                    badgeLabel:
                        '#${ranges[cat]?.start}–${ranges[cat]?.end}',
                    selected: active == cat && query.isEmpty,
                    onTap: () => onSelect(cat),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.title,
    required this.icon,
    required this.badgeLabel,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String badgeLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return UiInteractive(
      onTap: onTap,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        padding: EdgeInsets.symmetric(
          horizontal: ctx.sp(theme.spacing.sm),
          vertical: ctx.sp(theme.spacing.xs),
        ),
        decoration: BoxDecoration(
          color: selected
              ? theme.colors.primary.withValues(alpha: 0.12)
              : (s.hovered ? theme.colors.surfaceMuted : Colors.transparent),
          borderRadius: ctx.radius(theme.radii.md),
          border: Border.all(
            color: selected
                ? theme.colors.primary.withValues(alpha: 0.4)
                : Colors.transparent,
            width: theme.borders.hairline,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: ctx.sz(18),
              color: selected
                  ? theme.colors.primary
                  : (s.hovered
                      ? theme.colors.foreground
                      : theme.colors.foregroundMuted),
            ),
            SizedBox(width: ctx.sp(theme.spacing.xs)),
            Expanded(
              child: Text(
                title,
                style: ctx.uiText.body.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? theme.colors.primary
                      : theme.colors.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            UiBadge(
              label: badgeLabel,
              size: UiSize.xs,
              intent: selected ? UiIntent.primary : UiIntent.neutral,
              variant: selected ? UiBadgeVariant.solid : UiBadgeVariant.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileCategorySelector extends StatelessWidget {
  const _MobileCategorySelector({
    required this.active,
    required this.ranges,
    required this.onSelect,
  });

  final ShowcaseCategory active;
  final Map<ShowcaseCategory, ({int start, int end})> ranges;
  final ValueChanged<ShowcaseCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final cat in ShowcaseCategory.values) ...<Widget>[
            UiBadge(
              label: '${cat.label} (#${ranges[cat]?.start}–${ranges[cat]?.end})',
              icon: cat.icon,
              intent: active == cat ? UiIntent.primary : UiIntent.neutral,
              variant: active == cat ? UiBadgeVariant.solid : UiBadgeVariant.outline,
              onTap: () => onSelect(cat),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
        ],
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
            ),
            const UiBadge(
              label: 'single category active',
              variant: UiBadgeVariant.outline,
              size: UiSize.xs,
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        Text(
          'TraderHub UI Kit — Component Showcase',
          style: context.uiText.display.copyWith(color: theme.colors.foreground),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Text(
          'Select a category from the sidebar to view its full state matrix. '
          'Only the active category is rendered at a time for optimal site performance.',
          style:
              context.uiText.body.copyWith(color: theme.colors.foregroundMuted),
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
