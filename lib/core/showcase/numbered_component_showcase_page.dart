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

/// Category used by the filter chips and the jump-to index.
enum ShowcaseCategory {
  foundation('Foundation'),
  inputs('Inputs'),
  selection('Selection & navigation'),
  charts('Charts & data'),
  layout('Layout'),
  overlays('Feedback & overlays'),
  cards('Domain cards'),
  blocks('Domain blocks');

  const ShowcaseCategory(this.label);

  final String label;
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

/// Exhaustive master showcase: every foundation component, chart, domain card
/// and domain block rendered as a full state matrix, numbered end to end.
///
/// Global controls (theme, density, RTL, text scale, device-width simulator)
/// live in [UiShowcaseControlBar]; category chips, search and a jump-to index
/// narrow the page down to a single family.
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
  final Set<ShowcaseCategory> _categories = <ShowcaseCategory>{};
  final ScrollController _scroll = ScrollController();
  final Map<ShowcaseCategory, GlobalKey> _anchors =
      <ShowcaseCategory, GlobalKey>{
    for (final ShowcaseCategory c in ShowcaseCategory.values) c: GlobalKey(),
  };

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
          'legend and crosshair core.',
      count: kChartsGalleryCount,
      builder: _buildCharts,
    ),
    ShowcaseSectionSpec(
      category: ShowcaseCategory.layout,
      description:
          'Grids, pages, panes, dividers and the navigation primitives that '
          'structure a screen.',
      count: kLayoutGalleryCount,
      builder: _buildLayout,
    ),
    ShowcaseSectionSpec(
      category: ShowcaseCategory.overlays,
      description:
          'Callouts, empty states, avatars, tooltips, dialogs, drawers and '
          'toasts with their dismissal and queueing states.',
      count: kFeedbackGalleryCount,
      builder: _buildFeedback,
    ),
    ShowcaseSectionSpec(
      category: ShowcaseCategory.cards,
      description:
          'Brand, motion primitives and every model-driven domain card with '
          'populated, selected, loading, empty and error states.',
      count: kCardsGalleryCount,
      builder: _buildCards,
    ),
    ShowcaseSectionSpec(
      category: ShowcaseCategory.blocks,
      description:
          'Screen-level blocks and the app shell, each shown populated, '
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

  bool _matches(ShowcaseSectionSpec spec, int start) {
    if (_categories.isNotEmpty && !_categories.contains(spec.category)) {
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

  void _jumpTo(ShowcaseCategory category) {
    final BuildContext? ctx = _anchors[category]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
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
    final double gap = context.sp(theme.spacing.xl);

    int running = 1;
    final List<Widget> sections = <Widget>[];
    for (final ShowcaseSectionSpec spec in _specs) {
      final int start = running;
      running += spec.count;
      if (!_matches(spec, start)) continue;
      sections
        ..add(
          KeyedSubtree(
            key: _anchors[spec.category],
            child: _SectionHeading(
              spec: spec,
              start: start,
              end: start + spec.count - 1,
            ),
          ),
        )
        ..add(SizedBox(height: context.sp(theme.spacing.md)))
        ..add(spec.builder(start))
        ..add(SizedBox(height: gap));
    }

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext ctx, BoxConstraints c) {
            final double maxWidth = c.maxWidth > 1440 ? 1440 : c.maxWidth;
            return SingleChildScrollView(
              controller: _scroll,
              padding: EdgeInsets.symmetric(
                horizontal: ctx.sp(
                  ctx.uiRes.isMobile ? theme.spacing.lg : theme.spacing.xxl,
                ),
                vertical: ctx.sp(theme.spacing.xl),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _Header(total: totalEntries),
                      SizedBox(height: gap),
                      const UiShowcaseControlBar(),
                      SizedBox(height: context.sp(theme.spacing.md)),
                      _FilterBar(
                        query: _query,
                        selected: _categories,
                        onQuery: (String v) => setState(() => _query = v),
                        onToggle: (ShowcaseCategory cat) => setState(() {
                          if (!_categories.remove(cat)) _categories.add(cat);
                        }),
                        onClear: () => setState(() {
                          _categories.clear();
                          _query = '';
                        }),
                        onJump: _jumpTo,
                      ),
                      SizedBox(height: gap),
                      if (sections.isEmpty)
                        const UiEmptyState(
                          icon: Icons.search_off,
                          title: 'No matching sections',
                          message:
                              'Try another number, component family or '
                              'category name.',
                        )
                      else
                        ...sections,
                      SizedBox(height: gap),
                    ],
                  ),
                ),
              ),
            );
          },
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
              label: '$total numbered entries',
              intent: UiIntent.primary,
              variant: UiBadgeVariant.soft,
            ),
            const UiBadge(
              label: 'all states',
              variant: UiBadgeVariant.outline,
              size: UiSize.xs,
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        Text(
          'TraderHub UI Kit — exhaustive state showcase',
          style: context.uiText.display.copyWith(color: theme.colors.foreground),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Text(
          'Every component, chart, card and block rendered under its full '
          'matrix of variants, intents, sizes, densities, interaction states '
          'and data states — with theme, density, RTL, text-scale and '
          'device-width controls applied globally.',
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.query,
    required this.selected,
    required this.onQuery,
    required this.onToggle,
    required this.onClear,
    required this.onJump,
  });

  final String query;
  final Set<ShowcaseCategory> selected;
  final ValueChanged<String> onQuery;
  final ValueChanged<ShowcaseCategory> onToggle;
  final VoidCallback onClear;
  final ValueChanged<ShowcaseCategory> onJump;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return UiCard(
      variant: UiCardVariant.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UiInput.search(
            hintText: 'Search by number, family or category',
            value: query,
            onChanged: onQuery,
            onClear: () => onQuery(''),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              for (final ShowcaseCategory c in ShowcaseCategory.values)
                UiBadge(
                  label: c.label,
                  intent:
                      selected.contains(c) ? UiIntent.primary : UiIntent.neutral,
                  variant: selected.contains(c)
                      ? UiBadgeVariant.solid
                      : UiBadgeVariant.outline,
                  onTap: () => onToggle(c),
                ),
              if (selected.isNotEmpty || query.isNotEmpty)
                UiBadge(
                  label: 'Clear',
                  icon: Icons.close,
                  variant: UiBadgeVariant.ghost,
                  onTap: onClear,
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiDivider(),
          SizedBox(height: context.sp(theme.spacing.md)),
          Text(
            'JUMP TO',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              for (final ShowcaseCategory c in ShowcaseCategory.values)
                UiButton(
                  label: c.label,
                  size: UiSize.sm,
                  variant: UiVariant.ghost,
                  expandOnMobile: false,
                  onPressed: () => onJump(c),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
