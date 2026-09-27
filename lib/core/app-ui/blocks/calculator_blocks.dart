import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../cards/calculator_cards.dart';
import '../models/app_models.dart';

/// The layout engine behind the calculators hub and all 22 calculator screens.
///
/// Every screen fills the same slots — headline, stats, input groups, analysis
/// panels, callouts, formula, notes — and this file alone decides how they are
/// arranged. Desktop gets a bounded three-pane terminal: an input rail, an
/// analysis column, and a reference rail, each scrolling on its own. Mobile
/// gets a pinned readout over four compact tabs. Neither is a reflow of the
/// other, and no screen may opt out of the structure.

// ── Declarative slots ────────────────────────────────────────────────────────

/// The single figure a calculator exists to produce.
@immutable
class AppCalcHeadline {
  const AppCalcHeadline({
    required this.label,
    required this.value,
    this.intent = UiIntent.primary,
    this.unit,
    this.footnote,
    this.tag,
    this.tagIntent = UiIntent.neutral,
  });

  final String label;
  final String value;
  final UiIntent intent;

  /// Trails the value at caption size — 'qty', 'lots', '/ share', 'per year'.
  final String? unit;

  /// One line under the value: the assumption behind it, or the caveat.
  final String? footnote;

  /// Verdict pill beside the label — 'WITHIN LIMIT', 'ITM', 'AUDIT DUE'.
  final String? tag;
  final UiIntent tagIntent;
}

/// A titled cluster of controls in the input rail.
@immutable
class AppCalcInputGroup {
  const AppCalcInputGroup({
    required this.label,
    required this.children,
    this.hint,
  });

  final String label;
  final String? hint;
  final List<Widget> children;
}

/// Which pane a panel belongs to once the layout splits by purpose.
enum AppCalcPanelKind {
  /// Numbers read row by row — breakdowns, schedules, ladders, matrices.
  table,

  /// Trends, distributions, bridges.
  chart,

  /// One-dimensional position — meters, trackers, gauges, allocation bars.
  meter,
}

/// One analytical surface in the analysis column.
@immutable
class AppCalcPanel {
  const AppCalcPanel({
    required this.label,
    required this.child,
    this.kind = AppCalcPanelKind.chart,
    this.hint,
    this.wide = false,
  });

  final String label;

  /// Right-aligned qualifier in the panel caption — a unit, a basis, a count.
  final String? hint;
  final Widget child;
  final AppCalcPanelKind kind;

  /// Takes the whole analysis width instead of sharing a row with a sibling.
  final bool wide;
}

/// One line, area or bar of an [AppCalcTrendChart].
@immutable
class AppCalcSeries {
  const AppCalcSeries({
    required this.name,
    required this.values,
    this.intent,
    this.area = false,
    this.bars = false,
  });

  final String name;
  final List<double> values;

  /// Leave null to take the next colour from the theme's series ramp.
  final UiIntent? intent;
  final bool area;
  final bool bars;
}

/// Adapter over [UiComboChart] so screens declare `List<double>` instead of
/// assembling point and series objects by hand — 22 screens would otherwise
/// repeat the same twenty lines of plumbing.
class AppCalcTrendChart extends StatelessWidget {
  const AppCalcTrendChart({
    super.key,
    required this.series,
    this.labels,
    this.height = 168,
    this.valueFormatter,
    this.thresholds = const <UiChartThreshold>[],
    this.stacked = false,
    this.showLegend,
    this.curved = false,
    this.showAxisLabels = true,
  });

  final List<AppCalcSeries> series;

  /// X-axis captions. Defaults to 1-based indices.
  final List<String>? labels;
  final double height;
  final UiValueFormatter? valueFormatter;
  final List<UiChartThreshold> thresholds;
  final bool stacked;
  final bool? showLegend;
  final bool curved;
  final bool showAxisLabels;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    int n = 0;
    for (final AppCalcSeries s in series) {
      if (s.values.length > n) n = s.values.length;
    }
    if (n == 0) return const SizedBox.shrink();
    final List<String> axis =
        labels ?? <String>[for (int i = 0; i < n; i++) '${i + 1}'];

    return UiComboChart(
      data: <UiChartPoint>[
        for (int i = 0; i < n; i++)
          UiChartPoint(
            label: i < axis.length ? axis[i] : '',
            values: <double>[
              for (final AppCalcSeries s in series)
                i < s.values.length ? s.values[i] : 0,
            ],
          ),
      ],
      series: <UiChartSeries>[
        for (final AppCalcSeries s in series)
          UiChartSeries(
            name: s.name,
            color: s.intent?.color(context),
            type: s.bars
                ? UiChartSeriesType.bar
                : (s.area ? UiChartSeriesType.area : UiChartSeriesType.line),
            fillOpacity: s.area ? 0.14 : null,
          ),
      ],
      height: context.sz(height),
      curved: curved,
      glow: false,
      showLegend: showLegend ?? series.length > 1,
      toggleableLegend: false,
      showAxisLabels: showAxisLabels,
      stacked: stacked,
      valueFormatter: valueFormatter,
      thresholds: thresholds,
    );
  }
}

// ── Hosting ──────────────────────────────────────────────────────────────────

/// Marks a subtree as hosted inside the hub's workbench, so
/// [AppCalculatorLayout] drops its own page chrome and back affordance instead
/// of nesting a second page inside the one already on screen.
class AppCalculatorWorkspaceScope extends InheritedWidget {
  const AppCalculatorWorkspaceScope({
    super.key,
    required super.child,
    this.embeddedHeader = false,
  });

  final bool embeddedHeader;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppCalculatorWorkspaceScope>() !=
      null;

  static bool hasEmbeddedHeader(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppCalculatorWorkspaceScope>()
          ?.embeddedHeader ??
      false;

  @override
  bool updateShouldNotify(AppCalculatorWorkspaceScope oldWidget) =>
      embeddedHeader != oldWidget.embeddedHeader;
}

// ── The one layout ───────────────────────────────────────────────────────────

/// The single frame every calculator screen renders through.
///
/// Screens pass data, never layout: they cannot choose their own arrangement,
/// which is what keeps 22 tools reading like one instrument. The only branch is
/// form factor — [_DesktopCalculator] and [_MobileCalculator] are structurally
/// different surfaces, not two widths of the same one.
class AppCalculatorLayout extends StatelessWidget {
  const AppCalculatorLayout({
    super.key,
    required this.meta,
    required this.headline,
    required this.inputs,
    this.stats = const <UiStat>[],
    this.panels = const <AppCalcPanel>[],
    this.callouts = const <Widget>[],
    this.formula,
    this.notes = const <String>[],
    this.actions = const <Widget>[],
    this.onBack,
  });

  final AppCalculatorMeta meta;
  final AppCalcHeadline headline;
  final List<AppCalcInputGroup> inputs;

  /// The metric rail under the headline. Four to six reads best.
  final List<UiStat> stats;
  final List<AppCalcPanel> panels;

  /// Warnings and conclusions — [UiCallout]s, rendered under the panels.
  final List<Widget> callouts;

  /// The identity being computed, in plain notation.
  final String? formula;
  final List<String> notes;

  /// Compact trailing controls in the header (reset, copy, preset switch).
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final bool embedded = AppCalculatorWorkspaceScope.of(context);
    Widget buildBody(BuildContext ctx, BoxConstraints constraints) {
      final bool isNarrow = ctx.uiRes.isMobile || constraints.maxWidth < 680;
      return isNarrow
          ? _MobileCalculator(layout: this, embedded: embedded)
          : _DesktopCalculator(layout: this, embedded: embedded);
    }

    if (embedded) {
      return LayoutBuilder(builder: buildBody);
    }
    return UiPage(
      scrollable: false,
      maxWidth: 2400,
      child: LayoutBuilder(builder: buildBody),
    );
  }
}

// ── Desktop: three-pane terminal ─────────────────────────────────────────────

class _DesktopCalculator extends StatelessWidget {
  const _DesktopCalculator({required this.layout, required this.embedded});

  final AppCalculatorLayout layout;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final bool hasReference =
        layout.formula != null || layout.notes.isNotEmpty;

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final bool bounded = constraints.hasBoundedHeight;
        final Widget analysis = _AnalysisColumn(
          layout: layout,
          scroll: bounded,
          inlineReference: hasReference,
          maxWidth: w * 0.60,
        );

        final Widget rail = _InputRail(
          groups: layout.inputs,
          actions: layout.actions,
          scroll: bounded,
        );

        // Two independently scrolling panes with a 40/60 desktop split.
        final Widget body = bounded
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(flex: 40, child: rail),
                  _rule(ctx, vertical: true),
                  Expanded(flex: 60, child: analysis),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _InputRail(
                    groups: layout.inputs,
                    actions: layout.actions,
                    scroll: false,
                  ),
                  _rule(ctx),
                  analysis,
                ],
              );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: embedded ? null : ctx.radius(theme.radii.lg),
            border: embedded
                ? null
                : Border.all(color: c.border, width: theme.borders.hairline),
          ),
          child: ClipRRect(
            borderRadius: embedded
                ? BorderRadius.zero
                : ctx.radius(theme.radii.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
              children: <Widget>[
                _CalcHeader(
                  meta: layout.meta,
                  onBack: layout.onBack,
                  actions: layout.actions,
                  dense: false,
                  backgroundColor: c.surfaceMuted,
                ),
                _rule(ctx),
                if (bounded) Expanded(child: body) else body,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Readout band, panel grid, callouts — the desktop centre pane.
class _AnalysisColumn extends StatelessWidget {
  const _AnalysisColumn({
    required this.layout,
    required this.scroll,
    required this.inlineReference,
    required this.maxWidth,
  });

  final AppCalculatorLayout layout;
  final bool scroll;
  final bool inlineReference;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final double gap = context.sp(theme.spacing.md);
    final double pad = context.sp(theme.spacing.lg);

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ReadoutBand(headline: layout.headline, stats: layout.stats),
        if (layout.panels.isNotEmpty) ...<Widget>[
          SizedBox(height: gap),
          _PanelGrid(panels: layout.panels, available: maxWidth),
        ],
        for (final Widget callout in layout.callouts) ...<Widget>[
          SizedBox(height: gap),
          callout,
        ],
        if (inlineReference) ...<Widget>[
          SizedBox(height: gap),
          _ReferenceAccordion(
            formula: layout.formula,
            notes: layout.notes,
          ),
        ],
      ],
    );

    final Widget padded = Padding(
      padding: EdgeInsets.all(pad),
      child: content,
    );
    if (!scroll) return padded;
    return _ScrollPane(child: padded);
  }
}

/// Span-aware wrap grid. Wide panels take the row; the rest pair up, and drop
/// to one column when the pane is too narrow for two to stay legible.
class _PanelGrid extends StatelessWidget {
  const _PanelGrid({required this.panels, required this.available});

  final List<AppCalcPanel> panels;
  final double available;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final double gap = context.sp(theme.spacing.md);

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final bool twoUp = w >= ctx.sz(760);
        final List<Widget> rows = <Widget>[];
        int i = 0;
        while (i < panels.length) {
          final AppCalcPanel a = panels[i];
          final AppCalcPanel? b = (!twoUp || a.wide || i + 1 >= panels.length)
              ? null
              : (panels[i + 1].wide ? null : panels[i + 1]);
          if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
          if (b == null) {
            rows.add(_panel(a));
            i += 1;
          } else {
            rows.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _panel(a)),
                  SizedBox(width: gap),
                  Expanded(child: _panel(b)),
                ],
              ),
            );
            i += 2;
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }

  Widget _panel(AppCalcPanel p) => UiDataPanel(
    label: p.label,
    hint: p.hint,
    padding: p.kind == AppCalcPanelKind.table ? EdgeInsets.zero : null,
    child: p.child,
  );
}

// ── Shared pieces ────────────────────────────────────────────────────────────

/// One independently scrolling pane with the house thin scrollbar attached.
class _ScrollPane extends StatefulWidget {
  const _ScrollPane({required this.child});

  final Widget child;

  @override
  State<_ScrollPane> createState() => _ScrollPaneState();
}

class _ScrollPaneState extends State<_ScrollPane> {
  final ScrollController _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiScrollbar(
    controller: _ctrl,
    child: SingleChildScrollView(
      controller: _ctrl,
      primary: false,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: widget.child,
    ),
  );
}

/// A hairline. One helper so every seam in the layout is the same weight.
Widget _rule(BuildContext context, {bool vertical = false}) {
  final theme = context.ui;
  final Color color = theme.colors.border;
  return vertical
      ? SizedBox(width: theme.borders.hairline, child: ColoredBox(color: color))
      : SizedBox(
          height: theme.borders.hairline,
          child: ColoredBox(color: color),
        );
}

/// Tool identity: back, icon, name, category. Deliberately shallow — the page
/// title is not the point of a calculator, the number is.
class _CalcHeader extends StatelessWidget {
  const _CalcHeader({
    required this.meta,
    this.onBack,
    this.actions = const <Widget>[],
    this.dense = false,
    this.backgroundColor,
  });

  final AppCalculatorMeta meta;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool dense;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final UiIntent intent = meta.category.intent;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(dense ? theme.spacing.md : theme.spacing.lg),
        vertical: context.sp(theme.spacing.sm),
      ),
      color: backgroundColor ?? c.surfaceMuted,
      child: Row(
        children: <Widget>[
          if (onBack != null) ...<Widget>[
            UiIconButton(
              icon: Icons.arrow_back,
              size: UiSize.sm,
              tooltip: 'Back to calculators',
              onPressed: onBack,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          Icon(
            meta.icon,
            size: context.sz(theme.sizes.iconSm),
            color: intent.color(context),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  meta.name,
                  style: context.uiText.bodyStrong.copyWith(
                    color: c.foreground,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  meta.category.label.toUpperCase(),
                  style: uiOverline(context),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          for (final Widget action in actions) ...<Widget>[
            SizedBox(width: context.sp(theme.spacing.xs)),
            action,
          ],
        ],
      ),
    );
  }
}

/// The answer, then the metrics that qualify it.
///
/// One panel, two registers: a display-size figure the reader can find from
/// across the desk, and a hairline-separated rail of supporting numbers. Both
/// use tabular figures so a keystroke in the rail does not shuffle the layout.
class _ReadoutBand extends StatelessWidget {
  const _ReadoutBand({
    required this.headline,
    this.stats = const <UiStat>[],
    this.compact = false,
    this.framed = true,
  });

  final AppCalcHeadline headline;
  final List<UiStat> stats;
  final bool compact;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final Color tint = headline.intent.color(context);

    final Widget figure = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(compact ? theme.spacing.sm : theme.spacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  headline.label.toUpperCase(),
                  style: uiOverline(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (headline.tag != null) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.xs)),
                UiBadge(
                  label: headline.tag!,
                  intent: headline.tagIntent,
                  size: UiSize.xs,
                  variant: UiBadgeVariant.outline,
                  uppercase: true,
                ),
              ],
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  headline.value,
                  style: context.uiText.numeric.copyWith(
                    color: tint,
                    fontSize: context.fs(compact ? 24 : 30),
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (headline.unit != null) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.xxs)),
                Text(
                  headline.unit!,
                  style: context.uiText.caption.copyWith(
                    color: c.foregroundMuted,
                  ),
                ),
              ],
            ],
          ),
          if (headline.footnote != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xxs)),
            Text(
              headline.footnote!,
              style: context.uiText.caption.copyWith(
                color: c.foregroundSubtle,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        figure,
        if (stats.isNotEmpty) ...<Widget>[
          _rule(context),
          UiStatStrip(
            stats: stats,
            minCellWidth: compact ? 108 : 132,
            columns: compact ? 2 : null,
          ),
        ],
      ],
    );

    if (!framed) return body;
    return UiDataPanel(padding: EdgeInsets.zero, child: body);
  }
}

/// Grouped controls, hairline-separated, in a fixed-width rail.
///
/// Sections carry only a tracked overline — a rail of six bordered cards reads
/// as six unrelated forms, when it is one set of assumptions.
class _InputRail extends StatelessWidget {
  const _InputRail({
    required this.groups,
    this.actions = const <Widget>[],
    this.scroll = true,
    this.showHeader = true,
  });

  final List<AppCalcInputGroup> groups;
  final List<Widget> actions;
  final bool scroll;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showHeader)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.sp(theme.spacing.md),
              context.sp(theme.spacing.md),
              context.sp(theme.spacing.sm),
              context.sp(theme.spacing.xs),
            ),
            child: Row(
              children: <Widget>[
                Expanded(child: Text('Inputs', style: uiOverline(context))),
                for (final Widget action in actions) ...<Widget>[
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  action,
                ],
              ],
            ),
          ),
        for (int i = 0; i < groups.length; i++)
          _group(context, groups[i], first: i == 0 && !showHeader),
      ],
    );

    if (!scroll) return content;
    return _ScrollPane(child: content);
  }

  Widget _group(
    BuildContext context,
    AppCalcInputGroup group, {
    required bool first,
  }) {
    final theme = context.ui;
    final c = theme.colors;
    final double gap = context.sp(theme.spacing.sm);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.md),
      ),
      decoration: BoxDecoration(
        border: Border(
          top: first
              ? BorderSide.none
              : BorderSide(color: c.border, width: theme.borders.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(group.label.toUpperCase(), style: uiOverline(context)),
          if (group.hint != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xxs)),
            Text(
              group.hint!,
              style: context.uiText.caption.copyWith(
                color: c.foregroundSubtle,
                height: 1.35,
              ),
            ),
          ],
          for (final Widget child in group.children) ...<Widget>[
            SizedBox(height: gap),
            child,
          ],
        ],
      ),
    );
  }
}

/// The identity being computed, set on a muted slab so it reads as notation
/// rather than prose.
Widget _formulaBlock(BuildContext context, String formula) {
  final theme = context.ui;
  final c = theme.colors;
  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      horizontal: context.sp(theme.spacing.sm),
      vertical: context.sp(theme.spacing.sm),
    ),
    decoration: BoxDecoration(
      color: c.surfaceMuted,
      borderRadius: context.radius(theme.radii.sm),
      border: Border.all(color: c.border, width: theme.borders.hairline),
    ),
    child: Text(
      formula,
      style: context.uiText.caption.copyWith(
        color: c.foreground,
        height: 1.6,
        letterSpacing: 0.1,
      ),
    ),
  );
}

/// Assumptions, one per line, each tied to a hairline tick.
Widget _notesList(BuildContext context, List<String> notes) {
  final theme = context.ui;
  final c = theme.colors;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (int i = 0; i < notes.length; i++)
        Padding(
          padding: EdgeInsets.only(
            top: i == 0 ? 0 : context.sp(theme.spacing.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(top: context.sz(6)),
                width: context.sz(10),
                height: theme.borders.hairline * 2,
                color: c.borderStrong,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: Text(
                  notes[i],
                  style: context.uiText.caption.copyWith(
                    color: c.foregroundMuted,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// Method column: formula above, assumptions below, mirroring the input rail's
/// section rhythm so the two edges of the terminal balance.
class _ReferenceRail extends StatelessWidget {
  const _ReferenceRail({
    this.formula,
    this.notes = const <String>[],
    this.scroll = true,
    this.showHeader = true,
  });

  final String? formula;
  final List<String> notes;
  final bool scroll;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;

    Widget section(String title, Widget child, {required bool first}) =>
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.md),
          ),
          decoration: BoxDecoration(
            border: Border(
              top: first
                  ? BorderSide.none
                  : BorderSide(color: c.border, width: theme.borders.hairline),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: uiOverline(context)),
              SizedBox(height: context.sp(theme.spacing.sm)),
              child,
            ],
          ),
        );

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showHeader)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.sp(theme.spacing.md),
              context.sp(theme.spacing.md),
              context.sp(theme.spacing.md),
              context.sp(theme.spacing.xs),
            ),
            child: Text('Method', style: uiOverline(context)),
          ),
        if (formula != null)
          section(
            'Formula',
            _formulaBlock(context, formula!),
            first: !showHeader,
          ),
        if (notes.isNotEmpty)
          section(
            'Notes & assumptions',
            _notesList(context, notes),
            first: !showHeader && formula == null,
          ),
      ],
    );

    if (!scroll) return content;
    return _ScrollPane(child: content);
  }
}

/// Collapsed method block for panes too narrow to spare a third column.
class _ReferenceAccordion extends StatelessWidget {
  const _ReferenceAccordion({this.formula, this.notes = const <String>[]});

  final String? formula;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    return UiAccordion(
      allowMultiple: true,
      initiallyOpen: const <int>{0, 1},
      size: UiSize.sm,
      density: UiDensity.compact,
      items: <UiAccordionItem>[
        if (formula != null)
          UiAccordionItem(
            title: 'Formula',
            leadingIcon: Icons.functions,
            initiallyOpen: true,
            content: _formulaBlock(context, formula!),
          ),
        if (notes.isNotEmpty)
          UiAccordionItem(
            title: 'Notes & assumptions',
            leadingIcon: Icons.notes_outlined,
            initiallyOpen: true,
            badge: '${notes.length}',
            content: _notesList(context, notes),
          ),
      ],
    );
  }
}

// ── Mobile: pinned readout over four panes ───────────────────────────────────

/// A phone cannot show inputs, output, visuals and method at once, so it stops
/// pretending. The answer stays pinned; everything else is one tap away.
class _MobileCalculator extends StatefulWidget {
  const _MobileCalculator({required this.layout, required this.embedded});

  final AppCalculatorLayout layout;
  final bool embedded;

  @override
  State<_MobileCalculator> createState() => _MobileCalculatorState();
}

class _MobileCalculatorState extends State<_MobileCalculator> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final AppCalculatorLayout l = widget.layout;
    final List<AppCalcPanel> tables = l.panels
        .where((AppCalcPanel p) => p.kind == AppCalcPanelKind.table)
        .toList();
    final List<AppCalcPanel> visuals = l.panels
        .where((AppCalcPanel p) => p.kind != AppCalcPanelKind.table)
        .toList();

    final bool hasEmbeddedHeader =
        AppCalculatorWorkspaceScope.hasEmbeddedHeader(context);

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final bool bounded = constraints.hasBoundedHeight;
        final Widget pane = _pane(ctx, tables, visuals, scroll: bounded);

        return ColoredBox(
          color: c.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            children: <Widget>[
              if (!hasEmbeddedHeader) ...<Widget>[
                _CalcHeader(
                  meta: l.meta,
                  onBack: l.onBack,
                  actions: l.actions,
                  dense: true,
                ),
                _rule(ctx),
              ],
              _ReadoutBand(
                headline: l.headline,
                compact: true,
                framed: false,
              ),
              _rule(ctx),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ctx.sp(theme.spacing.sm),
                ),
                child: UiTabs(
                  index: _tab,
                  onChanged: (int i) => setState(() => _tab = i),
                  variant: UiTabsVariant.underline,
                  size: UiSize.sm,
                  density: UiDensity.compact,
                  stretch: true,
                  showPanel: false,
                  items: const <UiTabItem>[
                    UiTabItem(label: 'Inputs'),
                    UiTabItem(label: 'Output'),
                    UiTabItem(label: 'Visuals'),
                    UiTabItem(label: 'Method'),
                  ],
                ),
              ),
              if (bounded) Expanded(child: pane) else pane,
            ],
          ),
        );
      },
    );
  }

  Widget _pane(
    BuildContext context,
    List<AppCalcPanel> tables,
    List<AppCalcPanel> visuals, {
    required bool scroll,
  }) {
    final theme = context.ui;
    final AppCalculatorLayout l = widget.layout;
    final double gap = context.sp(theme.spacing.sm);
    final EdgeInsets pad = EdgeInsets.fromLTRB(
      context.sp(theme.spacing.sm),
      context.sp(theme.spacing.md),
      context.sp(theme.spacing.sm),
      context.sp(theme.spacing.xl) + context.uiPageBottomInset,
    );

    Widget stack(List<Widget> children, {String? emptyTitle}) {
      if (children.isEmpty) {
        return Padding(
          padding: pad,
          child: UiEmptyState(
            title: emptyTitle ?? 'Nothing here',
            message: 'This tool has no output of this kind.',
            icon: Icons.remove_circle_outline,
          ),
        );
      }
      return Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: gap),
              children[i],
            ],
          ],
        ),
      );
    }

    Widget panel(AppCalcPanel p) => UiDataPanel(
      label: p.label,
      hint: p.hint,
      padding: p.kind == AppCalcPanelKind.table ? EdgeInsets.zero : null,
      child: p.child,
    );

    late final Widget body;
    switch (_tab) {
      case 0:
        body = Padding(
          padding: EdgeInsets.only(bottom: pad.bottom),
          child: _InputRail(
            groups: l.inputs,
            actions: l.actions,
            scroll: false,
            showHeader: false,
          ),
        );
        break;
      case 1:
        body = stack(
          <Widget>[
            if (l.stats.isNotEmpty)
              UiDataPanel(
                padding: EdgeInsets.zero,
                child: UiStatStrip(stats: l.stats, columns: 2),
              ),
            for (final AppCalcPanel p in tables) panel(p),
            ...l.callouts,
          ],
          emptyTitle: 'No breakdown',
        );
        break;
      case 2:
        body = stack(
          <Widget>[for (final AppCalcPanel p in visuals) panel(p)],
          emptyTitle: 'No visuals',
        );
        break;
      default:
        body = Padding(
          padding: EdgeInsets.only(bottom: pad.bottom),
          child: _ReferenceRail(
            formula: l.formula,
            notes: l.notes,
            scroll: false,
            showHeader: false,
          ),
        );
    }

    final Widget keyed = KeyedSubtree(key: ValueKey<int>(_tab), child: body);
    if (!scroll) return keyed;
    return _ScrollPane(child: keyed);
  }
}

// ── Input controls ───────────────────────────────────────────────────────────

/// Compact labelled numeric field.
///
/// Owns its controller on purpose. Rebuilding from the parent's value on every
/// keystroke moves the caret to the end mid-typing, so the text is only pushed
/// back in when the incoming value genuinely differs from what is on screen —
/// a preset button, a reset, a linked field.
class AppCalcNumberField extends StatefulWidget {
  const AppCalcNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.decimals = 2,
    this.prefix,
    this.suffix,
    this.helper,
    this.hintText,
    this.enabled = true,
    this.allowNegative = false,
    this.presets = const <double>[],
    this.presetLabel,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  /// Digits kept when the value is written back into the field.
  final int decimals;
  final String? prefix;
  final String? suffix;
  final String? helper;
  final String? hintText;
  final bool enabled;
  final bool allowNegative;

  /// Quick-set chips under the field — lot sizes, standard rates, tenures.
  final List<double> presets;
  final String Function(double)? presetLabel;

  @override
  State<AppCalcNumberField> createState() => _AppCalcNumberFieldState();
}

class _AppCalcNumberFieldState extends State<AppCalcNumberField> {
  late final TextEditingController _ctrl = TextEditingController(
    text: _format(widget.value),
  );

  String _format(double v) {
    if (widget.decimals == 0) return v.round().toString();
    final String s = v.toStringAsFixed(widget.decimals);
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'\.?0+$'), '')
        : s;
  }

  @override
  void didUpdateWidget(AppCalcNumberField old) {
    super.didUpdateWidget(old);
    final double onScreen = double.tryParse(_ctrl.text.trim()) ?? double.nan;
    if ((onScreen - widget.value).abs() > 1e-9 &&
        !(onScreen.isNaN && _ctrl.text.trim().isEmpty && widget.value == 0)) {
      _ctrl.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return UiField(
      label: widget.label,
      helper: widget.helper,
      density: UiDensity.compact,
      enabled: widget.enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          UiInput(
            controller: _ctrl,
            enabled: widget.enabled,
            size: UiSize.sm,
            density: UiDensity.compact,
            hintText: widget.hintText ?? '0',
            prefixText: widget.prefix,
            suffixText: widget.suffix,
            textAlign: TextAlign.end,
            keyboardType: TextInputType.numberWithOptions(
              decimal: widget.decimals > 0,
              signed: widget.allowNegative,
            ),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(
                RegExp(
                  widget.allowNegative
                      ? (widget.decimals > 0 ? r'^-?[0-9]*\.?[0-9]*' : r'^-?[0-9]*')
                      : (widget.decimals > 0 ? r'^[0-9]*\.?[0-9]*' : r'^[0-9]*'),
                ),
              ),
            ],
            onChanged: (String raw) {
              final double? parsed = double.tryParse(raw.trim());
              widget.onChanged(parsed ?? 0);
            },
          ),
          if (widget.presets.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            UiToggleGroup<double>(
              options: <UiToggleOption<double>>[
                for (final double p in widget.presets)
                  UiToggleOption<double>(
                    value: p,
                    label: widget.presetLabel?.call(p) ?? _format(p),
                  ),
              ],
              value: widget.presets.any(
                (double p) => (p - widget.value).abs() < 1e-9,
              )
                  ? widget.presets.firstWhere(
                      (double p) => (p - widget.value).abs() < 1e-9,
                    )
                  : null,
              onChanged: (double p) {
                _ctrl.text = _format(p);
                widget.onChanged(p);
              },
              size: UiSize.xs,
              density: UiDensity.compact,
              variant: UiToggleGroupVariant.joined,
              // The preset bar spans the field it belongs to. Left to hug its
              // labels it outgrows a narrow input rail instead of dividing it.
              expand: true,
              enabled: widget.enabled,
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact labelled segmented control — sides, tenures, regimes, presets.
class AppCalcSegment<T> extends StatelessWidget {
  const AppCalcSegment({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.helper,
    this.expand = true,
  });

  final String label;
  final List<UiToggleOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? helper;
  final bool expand;

  @override
  Widget build(BuildContext context) => UiField(
    label: label,
    helper: helper,
    density: UiDensity.compact,
    child: UiToggleGroup<T>(
      options: options,
      value: value,
      onChanged: onChanged,
      size: UiSize.xs,
      density: UiDensity.compact,
      expand: expand,
      allowEmpty: false,
    ),
  );
}

/// Compact labelled slider for bounded assumptions — rates, volatility, tenor.
class AppCalcSliderField extends StatelessWidget {
  const AppCalcSliderField({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.valueFormatter,
    this.helper,
    this.intent = UiIntent.primary,
    this.showBounds = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;
  final UiValueFormatter? valueFormatter;
  final String? helper;
  final UiIntent intent;
  final bool showBounds;

  @override
  Widget build(BuildContext context) => UiSlider(
    label: label,
    helper: helper,
    value: value.clamp(min, max),
    min: min,
    max: max,
    divisions: divisions,
    onChanged: onChanged,
    size: UiSize.xs,
    intent: intent,
    showValue: true,
    showBounds: showBounds,
    valueFormatter: valueFormatter,
  );
}

// ── Hub blocks ───────────────────────────────────────────────────────────────

/// Search plus category filter for the tool index.
///
/// Stacks in the rail and in the mobile sheet alike — both are narrow, so there
/// is nothing to gain from putting the two controls side by side.
class AppCalculatorFilterBlock extends StatelessWidget {
  const AppCalculatorFilterBlock({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.category,
    required this.onCategoryChanged,
    this.counts = const <AppCalculatorCategory, int>{},
    this.total = 0,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;

  /// Null means "all categories".
  final AppCalculatorCategory? category;
  final ValueChanged<AppCalculatorCategory?> onCategoryChanged;
  final Map<AppCalculatorCategory, int> counts;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        UiInput(
          key: const ValueKey<String>('calculator_tool_search'),
          value: query,
          onChanged: onQueryChanged,
          hintText: 'Search tools',
          leadingIcon: Icons.search,
          size: UiSize.sm,
          density: UiDensity.compact,
          clearable: true,
          onClear: () => onQueryChanged(''),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        UiToggleGroup<String>(
          key: const ValueKey<String>('calculator_category_filter'),
          value: category?.name ?? '_all',
          onChanged: (String v) => onCategoryChanged(
            v == '_all'
                ? null
                : AppCalculatorCategory.values.firstWhere(
                    (AppCalculatorCategory c) => c.name == v,
                  ),
          ),
          size: UiSize.xs,
          density: UiDensity.compact,
          variant: UiToggleGroupVariant.pill,
          allowEmpty: false,
          options: <UiToggleOption<String>>[
            UiToggleOption<String>(
              value: '_all',
              label: 'All',
              badge: total > 0 ? '$total' : null,
            ),
            for (final AppCalculatorCategory cat
                in AppCalculatorCategory.values)
              UiToggleOption<String>(
                value: cat.name,
                label: cat.label,
                icon: cat.icon,
                intent: cat.intent,
                badge: counts[cat] != null ? '${counts[cat]}' : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// The tool index: compact rows grouped by category.
///
/// Shared by the desktop rail and the mobile sheet, so a tool sits in the same
/// place in the list wherever the reader opens it from.
class AppCalculatorToolIndex extends StatelessWidget {
  const AppCalculatorToolIndex({
    super.key,
    required this.tools,
    required this.selectedId,
    required this.onSelect,
    this.grouped = true,
    this.onClear,
    this.showDescription = false,
  });

  final List<AppCalculatorMeta> tools;
  final String? selectedId;
  final ValueChanged<AppCalculatorMeta> onSelect;
  final bool grouped;
  final VoidCallback? onClear;

  /// Adds each tool's one-line summary — worth the height on a phone, not in a
  /// 300 dp rail.
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    if (tools.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: UiEmptyState(
          title: 'No tools found',
          message: 'Nothing matches that search in this category.',
          icon: Icons.search_off,
          action: onClear == null
              ? null
              : UiButton(
                  label: 'Clear filters',
                  size: UiSize.xs,
                  variant: UiVariant.outline,
                  onPressed: onClear,
                ),
        ),
      );
    }

    final bool isTileLayout = showDescription || context.uiRes.isMobile;
    final double itemSpacing = context.sp(theme.spacing.xs + 2);

    if (!grouped) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < tools.length; i++) ...<Widget>[
            if (isTileLayout && i > 0) SizedBox(height: itemSpacing),
            AppCalculatorNavItem(
              meta: tools[i],
              selected: tools[i].id == selectedId,
              onTap: () => onSelect(tools[i]),
              showDescription: showDescription,
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final AppCalculatorCategory cat in AppCalculatorCategory.values)
          if (tools.any((AppCalculatorMeta m) => m.category == cat)) ...<Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                isTileLayout ? context.sp(theme.spacing.xs) : context.sp(theme.spacing.md),
                context.sp(theme.spacing.md),
                isTileLayout ? context.sp(theme.spacing.xs) : context.sp(theme.spacing.md),
                context.sp(theme.spacing.xs),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      cat.label.toUpperCase(),
                      style: uiOverline(context, color: cat.intent.color(context)),
                    ),
                  ),
                  Text(
                    '${tools.where((AppCalculatorMeta m) => m.category == cat).length}',
                    style: uiOverline(context),
                  ),
                ],
              ),
            ),
            for (final AppCalculatorMeta m
                in tools.where((AppCalculatorMeta m) => m.category == cat)) ...<Widget>[
              AppCalculatorNavItem(
                meta: m,
                selected: m.id == selectedId,
                onTap: () => onSelect(m),
                showDescription: showDescription,
              ),
              if (isTileLayout) SizedBox(height: itemSpacing),
            ],
          ],
      ],
    );
  }
}

