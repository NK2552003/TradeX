import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../../settings/presentation/widgets/settings_side_sheet.dart';
import 'black_scholes_screen.dart';
import 'brokerage_screen.dart';
import 'cagr_screen.dart';
import 'calculator_journal_draft.dart';
import 'contract_value_screen.dart';
import 'currency_screen.dart';
import 'emi_screen.dart';
import 'fd_screen.dart';
import 'fibonacci_screen.dart';
import 'inflation_screen.dart';
import 'ltcg_screen.dart';
import 'lumpsum_screen.dart';
import 'margin_screen.dart';
import 'options_pnl_screen.dart';
import 'pip_value_screen.dart';
import 'pivot_points_screen.dart';
import 'pnl_screen.dart';
import 'position_size_screen.dart';
import 'ppf_screen.dart';
import 'risk_reward_screen.dart';
import 'sip_screen.dart';
import 'stcg_screen.dart';
import 'turnover_screen.dart';

/// The calculators hub — one index, two surfaces.
///
/// **Desktop** is a workbench: the tool index lives in a permanent rail beside
/// the live calculator, so switching tools costs one click and never loses the
/// numbers on screen. Nothing navigates.
///
/// **Mobile** is an index that opens a tool. A 300 dp rail cannot coexist with a
/// calculator on a phone, and faking one with a sheet buries the list behind a
/// button, so the list is simply the first screen and the tool is the second.
class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({
    super.key,
    this.onSubpageChanged,
    this.initialCalculatorId,
    this.initiallyOpened = false,
  });

  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;
  final String? initialCalculatorId;
  final bool initiallyOpened;

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen> {
  final ScrollController _indexScroll = ScrollController();

  String _query = '';
  AppCalculatorCategory? _category;

  late String _activeId;
  late bool _opened;

  @override
  void initState() {
    super.initState();
    _activeId = widget.initialCalculatorId ?? kAllCalculators.first.id;
    _opened = widget.initiallyOpened || widget.initialCalculatorId != null;
    if (_opened) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final AppCalculatorMeta meta = calculatorMetaById(_activeId);
        widget.onSubpageChanged?.call(meta.name, meta.icon, _closeTool);
      });
    }
  }

  void _openTool(String id) {
    setState(() {
      _activeId = id;
      _opened = true;
    });
    final AppCalculatorMeta meta = calculatorMetaById(id);
    widget.onSubpageChanged?.call(meta.name, meta.icon, _closeTool);
  }

  void _closeTool() {
    if (!mounted) return;
    setState(() => _opened = false);
    widget.onSubpageChanged?.call(null, null, null);
  }

  @override
  void didUpdateWidget(CalculatorsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCalculatorId != null &&
        widget.initialCalculatorId != oldWidget.initialCalculatorId) {
      _openTool(widget.initialCalculatorId!);
    } else if (oldWidget.onSubpageChanged != widget.onSubpageChanged &&
        _opened) {
      final AppCalculatorMeta meta = calculatorMetaById(_activeId);
      widget.onSubpageChanged?.call(meta.name, meta.icon, _closeTool);
    }
  }

  @override
  void dispose() {
    _indexScroll.dispose();
    if (_opened) {
      widget.onSubpageChanged?.call(null, null, null);
    }
    super.dispose();
  }

  List<AppCalculatorMeta> get _visible {
    final String q = _query.trim().toLowerCase();
    return kAllCalculators.where((AppCalculatorMeta m) {
      if (_category != null && m.category != _category) return false;
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q) ||
          m.tags.any((String t) => t.toLowerCase().contains(q));
    }).toList();
  }

  Map<AppCalculatorCategory, int> get _counts {
    final Map<AppCalculatorCategory, int> out = <AppCalculatorCategory, int>{};
    for (final AppCalculatorMeta m in kAllCalculators) {
      out[m.category] = (out[m.category] ?? 0) + 1;
    }
    return out;
  }

  void _clearFilters() => setState(() {
    _query = '';
    _category = null;
  });

  @override
  Widget build(BuildContext context) =>
      context.uiRes.isMobile ? _mobile(context) : _desktop(context);

  // ── Desktop workbench ──────────────────────────────────────────────────────

  Widget _desktop(BuildContext context) {
    if (_opened) {
      final theme = context.ui;

      return ColoredBox(
        color: theme.colors.background,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: AppCalculatorWorkspaceScope(
                embeddedHeader: widget.onSubpageChanged != null,
                child: _tool(context, onBack: _closeTool),
              ),
            ),
              Positioned(
                right: context.sp(theme.spacing.md),
                bottom: context.sp(theme.spacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: context.radius(theme.radii.lg),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: UiIconButton(
                        key: const ValueKey<String>('calculator_history_fab'),
                        icon: Icons.history_rounded,
                        tooltip: 'Trade & Calculation History',
                        variant: UiVariant.secondary,
                        size: UiSize.md,
                        onPressed: () => showCalculatorHistorySheet(context),
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: context.radius(theme.radii.lg),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: UiIconButton(
                        key: const ValueKey<String>('calculator_tools_fab'),
                        icon: Icons.grid_view_rounded,
                        tooltip: 'All Tools',
                        variant: UiVariant.primary,
                        size: UiSize.md,
                        onPressed: () => _openToolsSidebar(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }

    return _indexView(context);
  }

  void _openToolsSidebar(BuildContext context) {
    showSettingsSideSheet<void>(
      context,
      title: 'Tools',
      subtitle: '${kAllCalculators.length} available',
      desktopWidthRatio: 0.28,
      minDesktopWidth: 340,
      maxWidth: 420,
      action: UiBadge(
        label: '${kAllCalculators.length}',
        intent: UiIntent.primary,
        size: UiSize.xs,
      ),
      child: _ToolsSideSheetContent(
        activeId: _activeId,
        initialQuery: _query,
        initialCategory: _category,
        onSelect: (AppCalculatorMeta m) {
          _openTool(m.id);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _mobile(BuildContext context) {
    if (_opened) {
      return AppCalculatorWorkspaceScope(
        embeddedHeader: widget.onSubpageChanged != null,
        child: _tool(context, onBack: _closeTool),
      );
    }

    return _indexView(context);
  }

  Widget _indexView(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final List<AppCalculatorMeta> visible = _visible;

    return UiPage(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Tools',
                    style: context.uiText.heading.copyWith(color: c.foreground),
                  ),
                ),
                UiButton(
                  key: const ValueKey<String>('calculator_history_button'),
                  label: 'History',
                  leadingIcon: Icons.history_rounded,
                  variant: UiVariant.soft,
                  size: UiSize.xs,
                  onPressed: () => showCalculatorHistorySheet(context),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Text(
                  '${visible.length} / ${kAllCalculators.length}',
                  style: uiOverline(context),
                ),
              ],
            ),
          ),
          AppCalculatorFilterBlock(
            query: _query,
            onQueryChanged: (String v) => setState(() => _query = v),
            category: _category,
            onCategoryChanged: (AppCalculatorCategory? v) =>
                setState(() => _category = v),
            counts: _counts,
            total: kAllCalculators.length,
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Expanded(
            child: UiScrollbar(
              controller: _indexScroll,
              child: SingleChildScrollView(
                controller: _indexScroll,
                primary: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        context.sp(theme.spacing.md) +
                        context.uiPageBottomInset,
                  ),
                  child: AppCalculatorToolIndex(
                    tools: visible,
                    selectedId: null,
                    showDescription: true,
                    onSelect: (AppCalculatorMeta m) => _openTool(m.id),
                    onClear: _clearFilters,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── id → screen ────────────────────────────────────────────────────────────

  Widget _tool(BuildContext context, {VoidCallback? onBack}) {
    switch (_activeId) {
      case 'position_size':
        return PositionSizeCalculatorScreen(onBack: onBack);
      case 'risk_reward':
        return RiskRewardCalculatorScreen(onBack: onBack);
      case 'brokerage':
        return BrokerageCalculatorScreen(onBack: onBack);
      case 'margin':
        return MarginCalculatorScreen(onBack: onBack);
      case 'pivot_points':
        return PivotPointsCalculatorScreen(onBack: onBack);
      case 'fibonacci':
        return FibonacciCalculatorScreen(onBack: onBack);
      case 'pnl':
        return PnlCalculatorScreen(onBack: onBack);
      case 'options_pnl':
        return OptionsPnlCalculatorScreen(onBack: onBack);
      case 'black_scholes':
        return BlackScholesCalculatorScreen(onBack: onBack);
      case 'contract_value':
        return ContractValueCalculatorScreen(onBack: onBack);
      case 'sip':
        return SipCalculatorScreen(onBack: onBack);
      case 'lumpsum':
        return LumpsumCalculatorScreen(onBack: onBack);
      case 'fd':
        return FdCalculatorScreen(onBack: onBack);
      case 'cagr':
        return CagrCalculatorScreen(onBack: onBack);
      case 'inflation':
        return InflationCalculatorScreen(onBack: onBack);
      case 'ppf':
        return PpfCalculatorScreen(onBack: onBack);
      case 'emi':
        return EmiCalculatorScreen(onBack: onBack);
      case 'currency':
        return CurrencyCalculatorScreen(onBack: onBack);
      case 'pip_value':
        return PipValueCalculatorScreen(onBack: onBack);
      case 'stcg':
        return StcgCalculatorScreen(onBack: onBack);
      case 'ltcg':
        return LtcgCalculatorScreen(onBack: onBack);
      case 'turnover':
        return TurnoverCalculatorScreen(onBack: onBack);
      default:
        return AppCalculatorMissingTool(
          name: kAllCalculators
              .where((AppCalculatorMeta m) => m.id == _activeId)
              .map((AppCalculatorMeta m) => m.name)
              .firstOrNull,
        );
    }
  }
}

class _ToolsSideSheetContent extends StatefulWidget {
  const _ToolsSideSheetContent({
    required this.activeId,
    required this.onSelect,
    this.initialQuery = '',
    this.initialCategory,
  });

  final String activeId;
  final ValueChanged<AppCalculatorMeta> onSelect;
  final String initialQuery;
  final AppCalculatorCategory? initialCategory;

  @override
  State<_ToolsSideSheetContent> createState() => _ToolsSideSheetContentState();
}

class _ToolsSideSheetContentState extends State<_ToolsSideSheetContent> {
  final ScrollController _scroll = ScrollController();
  late String _query;
  late AppCalculatorCategory? _category;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<AppCalculatorMeta> get _visible {
    final String q = _query.trim().toLowerCase();
    return kAllCalculators.where((AppCalculatorMeta m) {
      if (_category != null && m.category != _category) return false;
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q) ||
          m.tags.any((String t) => t.toLowerCase().contains(q));
    }).toList();
  }

  Map<AppCalculatorCategory, int> get _counts {
    final Map<AppCalculatorCategory, int> out = <AppCalculatorCategory, int>{};
    for (final AppCalculatorMeta m in kAllCalculators) {
      out[m.category] = (out[m.category] ?? 0) + 1;
    }
    return out;
  }

  void _clearFilters() => setState(() {
    _query = '';
    _category = null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final List<AppCalculatorMeta> visible = _visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
          child: AppCalculatorFilterBlock(
            query: _query,
            onQueryChanged: (String v) => setState(() => _query = v),
            category: _category,
            onCategoryChanged: (AppCalculatorCategory? v) =>
                setState(() => _category = v),
            counts: _counts,
            total: kAllCalculators.length,
          ),
        ),
        SizedBox(
          height: theme.borders.hairline,
          child: ColoredBox(color: c.border),
        ),
        Expanded(
          child: UiScrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              primary: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
                child: AppCalculatorToolIndex(
                  tools: visible,
                  selectedId: widget.activeId,
                  onSelect: widget.onSelect,
                  onClear: _clearFilters,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
