import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/strategies/data/repositories/strategy_repository.dart';
import 'package:tradex/features/strategies/presentation/widgets/strategy_form_sheet.dart';

/// Library grid vs. relationship graph.
enum _StrategyView { library, graph }

/// Strategy workbench: the playbook library, a detail pane with the analyzer
/// (AI review + backtest + version history) and a relationship graph.
class StrategiesPage extends StatefulWidget {
  const StrategiesPage({
    super.key,
    this.repository,
    this.onOpenAi,
    this.onOpenJournal,
  });

  final StrategyRepository? repository;
  final VoidCallback? onOpenAi;
  final VoidCallback? onOpenJournal;

  @override
  State<StrategiesPage> createState() => _StrategiesPageState();
}

class _StrategiesPageState extends State<StrategiesPage> {
  late final StrategyRepository _repo =
      widget.repository ?? StrategyRepositoryImpl();

  List<AppStrategy> _strategies = const <AppStrategy>[];
  List<String> _categories = const <String>[];
  List<AppStrategyVersion> _versions = const <AppStrategyVersion>[];
  StrategyGraph? _graph;
  AppStrategy? _selected;
  AppBacktestResult? _backtest;
  String? _review;

  String _search = '';
  String _category = '';
  _StrategyView _view = _StrategyView.library;
  bool _loading = true;
  bool _running = false;
  bool _reviewing = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<String> categories = await _repo.getCategories();
    final StrategyGraph graph = await _repo.getGraph();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _graph = graph;
    });
    await _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final List<AppStrategy> rows = await _repo.getStrategies(
      search: _search.isEmpty ? null : _search,
      category: _category.isEmpty ? null : _category,
    );
    if (!mounted) return;
    setState(() {
      _strategies = rows;
      _loading = false;
      final AppStrategy? current = _selected;
      if (current != null) {
        for (final AppStrategy s in rows) {
          if (s.id == current.id) {
            _selected = s;
            return;
          }
        }
        _selected = null;
      }
    });
  }

  Future<void> _select(AppStrategy strategy) async {
    setState(() {
      _selected = strategy;
      _versions = const <AppStrategyVersion>[];
      _backtest = null;
      _review = null;
    });
    final List<AppStrategyVersion> versions = await _repo.getVersions(
      strategy.id,
    );
    if (!mounted) return;
    setState(() => _versions = versions);
  }

  Future<void> _openForm({AppStrategy? initial}) async {
    final AppStrategy? strategy = await showStrategyFormSheet(
      context,
      initial: initial,
      categories: _categories,
    );
    if (strategy == null || !mounted) return;
    await _repo.saveStrategy(strategy);
    final List<String> categories = await _repo.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _selected = strategy;
    });
    UiToast.show(
      context,
      title: initial == null ? 'Playbook created' : 'Playbook saved',
      message: strategy.name,
      intent: UiIntent.success,
    );
    await _reload();
  }

  Future<void> _delete(AppStrategy strategy) async {
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Delete ${strategy.name}?',
      description:
          'The playbook is removed from your library. Logged trades keep their history.',
      confirmLabel: 'Delete',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    await _repo.deleteStrategy(strategy.id);
    if (!mounted) return;
    setState(() => _selected = null);
    UiToast.show(
      context,
      title: 'Playbook deleted',
      message: '${strategy.name} is no longer in your library.',
    );
    await _reload();
  }

  Future<void> _toggleFavorite(AppStrategy strategy) async {
    final AppStrategy updated = await _repo.toggleFavorite(strategy.id);
    if (!mounted) return;
    setState(() {
      if (_selected?.id == updated.id) _selected = updated;
    });
    await _reload();
  }

  Future<void> _runBacktest(AppStrategy strategy) async {
    setState(() => _running = true);
    final AppBacktestResult result = await _repo.runBacktest(strategy);
    if (!mounted) return;
    setState(() {
      _backtest = result;
      _running = false;
    });
    UiToast.show(
      context,
      title: 'Backtest complete',
      message:
          '${result.trades} trades · ${AppTokens.signedMoney(result.netPnl)} · ${AppTokens.percent(result.winRate)} hit rate',
      intent: AppTokens.plIntent(result.netPnl),
    );
  }

  Future<void> _generateReview(AppStrategy strategy) async {
    setState(() => _reviewing = true);
    final String summary = await _repo.generateSummary(strategy);
    if (!mounted) return;
    setState(() {
      _review = summary;
      _reviewing = false;
    });
  }

  Future<void> _restore(AppStrategy strategy, AppStrategyVersion version) async {
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Restore v${version.version}?',
      description:
          'Saved ${AppTokens.relativeTime(version.savedAt)}. The current rules become a new version, so nothing is lost.',
      confirmLabel: 'Restore',
    );
    if (!confirmed || !mounted) return;
    await _repo.restoreVersion(strategy.id, version.id);
    final List<AppStrategyVersion> versions = await _repo.getVersions(
      strategy.id,
    );
    if (!mounted) return;
    setState(() => _versions = versions);
    UiToast.show(
      context,
      title: 'Version restored',
      message: '${strategy.name} is back on v${version.version}.',
      intent: UiIntent.success,
    );
  }

  Future<void> _setSearch(String value) async {
    setState(() => _search = value);
    await _reload();
  }

  Future<void> _setCategory(String value) async {
    setState(() => _category = value);
    await _reload();
  }
// STRATEGY_ACTIONS_2

  @override
  Widget build(BuildContext context) {
    final bool isMobile = context.uiRes.isMobile;
    final bool detailOpen = isMobile && _selected != null;
    final int favorites = _strategies
        .where((AppStrategy s) => s.isFavorite)
        .length;

    return AppPageBlock(
      title: 'Strategy workbench',
      subtitle:
          '${_strategies.length} playbook${_strategies.length == 1 ? '' : 's'} · $favorites starred · AI review and backtests on demand',
      scrollable: false,
      actions: <Widget>[
        UiButton(
          label: 'New playbook',
          leadingIcon: Icons.add_rounded,
          size: UiSize.sm,
          onPressed: _openForm,
        ),
        UiButton(
          label: 'Open journal',
          variant: UiVariant.secondary,
          leadingIcon: Icons.receipt_long_outlined,
          size: UiSize.sm,
          hideLabelOnMobile: true,
          onPressed: widget.onOpenJournal,
        ),
      ],
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!detailOpen) ...<Widget>[
              UiToggleGroup<_StrategyView>(
                options: const <UiToggleOption<_StrategyView>>[
                  UiToggleOption<_StrategyView>(
                    value: _StrategyView.library,
                    label: 'Library',
                    icon: Icons.auto_stories_outlined,
                  ),
                  UiToggleOption<_StrategyView>(
                    value: _StrategyView.graph,
                    label: 'Graph',
                    icon: Icons.hub_outlined,
                  ),
                ],
                value: _view,
                expand: isMobile,
                onChanged: (_StrategyView view) => setState(() => _view = view),
              ),
              UiGap.v(context.ui.spacing.md),
            ],
            Expanded(
              child: switch (_view) {
                _StrategyView.library => _libraryView(),
                _StrategyView.graph => _graphView(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _libraryView() {
    final AppStrategy? selected = _selected;
    return AppWorkspacePane(
      hasSelection: selected != null,
      onClearSelection: () => setState(() => _selected = null),
      initialRatio: 0.42,
      listTitle: _loading ? 'Loading playbooks…' : 'Your playbooks',
      listActions: <Widget>[
        UiButton(
          label: 'New',
          variant: UiVariant.ghost,
          size: UiSize.sm,
          leadingIcon: Icons.add_rounded,
          onPressed: _openForm,
        ),
      ],
      list: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiSearchField(
            value: _search,
            hintText: 'Search playbooks and rules',
            loading: _loading,
            onChanged: _setSearch,
          ),
          if (_categories.isNotEmpty) ...<Widget>[
            UiGap.v(context.ui.spacing.sm),
            UiToggleGroup<String>(
              options: <UiToggleOption<String>>[
                const UiToggleOption<String>(value: '', label: 'All'),
                for (final String category in _categories)
                  UiToggleOption<String>(value: category, label: category),
              ],
              value: _category,
              onChanged: _setCategory,
            ),
          ],
          UiGap.v(context.ui.spacing.md),
          if (_loading && _strategies.isEmpty)
            Column(
              children: <Widget>[
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: context.sp(context.ui.spacing.sm),
                    ),
                    child: UiSkeleton(height: context.sz(96)),
                  ),
              ],
            )
          else
            AppStrategyLibraryBlock(
              strategies: _strategies,
              onCreate: _openForm,
              onOpen: _select,
              onFavorite: _toggleFavorite,
            ),
        ],
      ),
      detail: selected == null
          ? const SizedBox.shrink()
          : AppFadeIn(key: ValueKey<String>(selected.id), child: _detail(selected)),
      detailTitle: selected?.name,
      detailActions: selected == null
          ? const <Widget>[]
          : <Widget>[
              UiButton(
                label: 'Edit',
                variant: UiVariant.secondary,
                size: UiSize.sm,
                leadingIcon: Icons.edit_outlined,
                onPressed: () => _openForm(initial: selected),
              ),
              UiIconButton(
                icon: selected.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                tooltip: selected.isFavorite ? 'Unstar' : 'Star',
                onPressed: () => _toggleFavorite(selected),
              ),
              UiIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete playbook',
                onPressed: () => _delete(selected),
              ),
            ],
      breadcrumbs: selected == null
          ? const <UiCrumb>[]
          : <UiCrumb>[
              UiCrumb(
                label: 'Strategies',
                onTap: () => setState(() => _selected = null),
              ),
              if (selected.category != null) UiCrumb(label: selected.category!),
              UiCrumb(label: selected.name),
            ],
      placeholderTitle: 'Pick a playbook',
      placeholderMessage:
          'Open a strategy to see its expectancy, run a backtest and review the version history.',
      placeholderIcon: Icons.auto_stories_outlined,
    );
  }

  Widget _detail(AppStrategy s) {
    final List<AppSeriesPoint> curve = <AppSeriesPoint>[
      for (int i = 0; i < s.equityCurve.length; i++)
        AppSeriesPoint(label: 'T${i + 1}', value: s.equityCurve[i]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: context.sp(context.ui.spacing.xs),
          runSpacing: context.sp(context.ui.spacing.xs),
          children: <Widget>[
            if (s.category != null)
              UiBadge(label: s.category!, intent: UiIntent.info),
            UiBadge(
              label: s.isPublic ? 'Public' : 'Private',
              intent: s.isPublic ? UiIntent.success : UiIntent.neutral,
            ),
            UiBadge(label: 'v${s.versionCount}'),
            if (s.updatedAt != null)
              UiBadge(
                label: 'Updated ${AppTokens.relativeTime(s.updatedAt!)}',
                intent: UiIntent.neutral,
              ),
          ],
        ),
        UiGap.v(context.ui.spacing.md),
        AppStatGridBlock(
          stats: <AppStat>[
            AppStat(
              label: 'Net P/L',
              value: s.netPnl,
              icon: Icons.account_balance_wallet_outlined,
              spark: s.equityCurve,
              formatter: AppTokens.signedMoney,
            ),
            AppStat(
              label: 'Win rate',
              value: s.winRate,
              icon: Icons.percent_rounded,
              formatter: AppTokens.percent,
            ),
            AppStat(
              label: 'Avg R',
              value: s.avgR,
              icon: Icons.balance_rounded,
              formatter: AppTokens.rr,
            ),
            AppStat(
              label: 'Executions',
              value: s.trades,
              icon: Icons.receipt_long_outlined,
              formatter: (num v) => v.toStringAsFixed(0),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.lg),
        AppDashboardLayoutBlock(
          main: <Widget>[
            UiCard(
              title: 'Rules and thesis',
              trailing: UiIconButton(
                icon: Icons.edit_outlined,
                size: UiSize.sm,
                tooltip: 'Edit rules',
                onPressed: () => _openForm(initial: s),
              ),
              child: s.summary == null || s.summary!.isEmpty
                  ? UiEmptyState(
                      title: 'No rules written yet',
                      message:
                          'Document the trigger, invalidation and sizing so the AI review has something to work with.',
                      icon: Icons.edit_note_rounded,
                      action: UiButton(
                        label: 'Write the rules',
                        size: UiSize.sm,
                        onPressed: () => _openForm(initial: s),
                      ),
                    )
                  : Text(s.summary!, style: context.uiText.body),
            ),
            if (curve.isNotEmpty)
              AppEquityCurveBlock(series: curve, title: 'Playbook equity'),
            _backtest == null
                ? UiCard(
                    title: 'Backtest',
                    subtitle:
                        'Replay the rules over the sample history to sanity-check expectancy.',
                    child: UiButton(
                      label: _running ? 'Running backtest…' : 'Run backtest',
                      leadingIcon: Icons.play_arrow_rounded,
                      loading: _running,
                      expand: true,
                      onPressed: _running ? null : () => _runBacktest(s),
                    ),
                  )
                : AppBacktestResultBlock(
                    result: _backtest!,
                    onRerun: _running ? null : () => _runBacktest(s),
                    onSave: () => UiToast.show(
                      context,
                      title: 'Result saved',
                      message: 'Attached to ${s.name} for the desk report.',
                      intent: UiIntent.success,
                    ),
                  ),
          ],
          side: <Widget>[
            UiCard(
              title: 'AI review',
              subtitle: 'Grounded in your logged executions for this playbook.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_review != null) ...<Widget>[
                    Text(_review!, style: context.uiText.body),
                    UiGap.v(context.ui.spacing.md),
                  ],
                  UiButton(
                    label: _review == null ? 'Generate review' : 'Regenerate',
                    variant: _review == null
                        ? UiVariant.primary
                        : UiVariant.ghost,
                    leadingIcon: Icons.auto_awesome_rounded,
                    loading: _reviewing,
                    expand: true,
                    onPressed: _reviewing ? null : () => _generateReview(s),
                  ),
                  if (widget.onOpenAi != null) ...<Widget>[
                    UiGap.v(context.ui.spacing.sm),
                    UiButton(
                      label: 'Continue in the copilot',
                      variant: UiVariant.ghost,
                      size: UiSize.sm,
                      trailingIcon: Icons.arrow_forward_rounded,
                      expand: true,
                      onPressed: widget.onOpenAi,
                    ),
                  ],
                ],
              ),
            ),
            AppVersionHistoryBlock(
              versions: _versions,
              onRestore: (AppStrategyVersion v) => _restore(s, v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _graphView() {
    final StrategyGraph? graph = _graph;
    if (graph == null) {
      return Center(child: UiSkeleton(height: context.sz(320)));
    }
    final AppStrategy? selected = _selected;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppFadeIn(
            child: AppStrategyGraphBlock(
              nodes: graph.nodes,
              links: graph.links,
              selectedId: selected?.id,
              onSelect: (String? id) {
                if (id == null) {
                  setState(() => _selected = null);
                  return;
                }
                for (final AppStrategy s in _strategies) {
                  if (s.id == id) {
                    _select(s);
                    return;
                  }
                }
              },
            ),
          ),
          UiGap.v(context.ui.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step * 2,
            child: UiCard(
              title: 'Selection',
              subtitle: selected == null
                  ? 'Tap a node to inspect the playbook behind it.'
                  : '${selected.trades} executions · ${AppTokens.signedMoney(selected.netPnl)}',
              child: selected == null
                  ? const UiEmptyState(
                      title: 'Nothing selected',
                      message:
                          'Nodes group playbooks by regime; links show shared instruments and tags.',
                      icon: Icons.hub_outlined,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        AppStrategyCard(
                          strategy: selected,
                          onFavorite: () => _toggleFavorite(selected),
                        ),
                        UiGap.v(context.ui.spacing.md),
                        UiButton(
                          label: 'Open in library',
                          variant: UiVariant.secondary,
                          trailingIcon: Icons.arrow_forward_rounded,
                          expand: true,
                          onPressed: () =>
                              setState(() => _view = _StrategyView.library),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
