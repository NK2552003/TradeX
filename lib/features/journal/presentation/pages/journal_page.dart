import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/journal/data/repositories/journal_repository.dart';
import 'package:tradex/features/journal/presentation/widgets/journal_filters_sheet.dart';
import 'package:tradex/features/journal/presentation/widgets/trade_form_sheet.dart';

/// Which journal surface is on screen. The trade list keeps its own split-pane
/// selection, so the view is page-level state rather than a nested route.
enum _JournalView { trades, calendar, review }

/// The trading journal: filterable trade log with a detail pane, a P/L
/// calendar and a review surface (discipline checklist + breakdowns).
///
/// Desktop shows list and detail side by side; phones drill in to the detail
/// full screen and lift filters into a sheet.
class JournalPage extends StatefulWidget {
  const JournalPage({
    super.key,
    this.repository,
    this.composeSymbol,
    this.focusTradeId,
    this.onOpenAi,
    this.onOpenTicker,
  });

  final JournalRepository? repository;

  /// Opens the composer on this instrument as soon as the page has loaded, for
  /// a "log a trade" hand-off from a chart, an alert or a notification.
  final String? composeSymbol;

  /// Selects this trade on arrival, for a hand-off from search, a notification
  /// or a portfolio row. Filters are cleared first so the trade cannot land
  /// outside the list the reader is looking at.
  final String? focusTradeId;

  final VoidCallback? onOpenAi;
  final ValueChanged<String>? onOpenTicker;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  late final JournalRepository _repo =
      widget.repository ?? JournalRepositoryImpl();

  JournalQuery _query = const JournalQuery();
  List<AppTrade> _trades = const <AppTrade>[];
  JournalSummary? _summary;
  List<AppDayPnl> _days = const <AppDayPnl>[];
  List<AppChecklistItem> _checklist = const <AppChecklistItem>[];
  List<String> _symbols = const <String>[];
  List<String> _strategies = const <String>[];
  List<String> _tags = const <String>[];

  AppTrade? _selected;
  DateTime? _selectedDay;
  _JournalView _view = _JournalView.trades;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<String> symbols = await _repo.getSymbols();
    final List<String> strategies = await _repo.getStrategies();
    final List<String> tags = await _repo.getTags();
    final List<AppDayPnl> days = await _repo.getCalendar();
    final List<AppChecklistItem> checklist = await _repo.getChecklist();
    if (!mounted) return;
    setState(() {
      _symbols = symbols;
      _strategies = strategies;
      _tags = tags;
      _days = days;
      _checklist = checklist;
    });
    await _reload();
    if (!mounted) return;
    await _focusRequestedTrade();
    if (!mounted) return;
    final String? compose = widget.composeSymbol?.trim();
    if (compose != null && compose.isNotEmpty) {
      await _openForm(symbol: compose);
    }
  }

  /// Honours [JournalPage.focusTradeId]. The trade is fetched by id rather than
  /// looked up in `_trades`, so a deep link still works when the active filters
  /// would have hidden it — and the view switches to the log so the selection
  /// is somewhere the reader can see it.
  Future<void> _focusRequestedTrade() async {
    final String? id = widget.focusTradeId?.trim();
    if (id == null || id.isEmpty) return;
    final AppTrade? trade = await _repo.getTrade(id);
    if (!mounted || trade == null) return;
    setState(() {
      _selected = trade;
      _view = _JournalView.trades;
    });
    if (_trades.any((AppTrade t) => t.id == trade.id)) return;
    // The link points outside the current filters; widening beats showing a
    // detail pane for a row that is not in the list beside it.
    setState(() => _query = const JournalQuery());
    await _reload();
    if (!mounted) return;
    setState(() => _selected = trade);
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final List<AppTrade> trades = await _repo.getTrades(_query);
    final JournalSummary summary = await _repo.getSummary();
    if (!mounted) return;
    setState(() {
      _trades = trades;
      _summary = summary;
      _loading = false;
      final AppTrade? current = _selected;
      if (current != null && !trades.any((AppTrade t) => t.id == current.id)) {
        _selected = null;
      }
    });
  }

  Future<void> _openForm({AppTrade? initial, String? symbol}) async {
    final AppTrade? trade = await showTradeFormSheet(
      context,
      initial: initial,
      initialSymbol: symbol,
      symbols: _symbols,
      strategies: _strategies,
      tags: _tags,
    );
    if (trade == null || !mounted) return;
    await _repo.saveTrade(trade);
    final List<String> tags = await _repo.getTags();
    if (!mounted) return;
    setState(() {
      _selected = trade;
      _tags = tags;
    });
    UiToast.show(
      context,
      title: initial == null ? 'Trade logged' : 'Trade updated',
      message:
          '${trade.ticker} · ${AppTokens.sideLabel(trade.side)} · ${AppTokens.signedMoney(trade.pnl)}',
      intent: AppTokens.plIntent(trade.pnl),
    );
    await _reload();
  }

  Future<void> _delete(AppTrade trade) async {
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Delete this trade?',
      description:
          '${trade.ticker} opened ${AppTokens.shortDate(trade.openedAt)} will be removed from the journal. This cannot be undone.',
      confirmLabel: 'Delete',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    await _repo.deleteTrade(trade.id);
    if (!mounted) return;
    setState(() => _selected = null);
    UiToast.show(
      context,
      title: 'Trade deleted',
      message: '${trade.ticker} is no longer in your journal.',
      intent: UiIntent.neutral,
    );
    await _reload();
  }

  Future<void> _openFilters() async {
    final JournalQuery? next = await showJournalFiltersSheet(
      context,
      query: _query,
      symbols: _symbols,
      strategies: _strategies,
    );
    if (next == null || !mounted) return;
    setState(() => _query = next);
    await _reload();
  }

  Future<void> _setSearch(String value) async {
    setState(() => _query = _query.copyWith(search: value));
    await _reload();
  }

  Future<void> _setOutcome(AppOutcome? outcome) async {
    setState(
      () => _query = outcome == null
          ? _query.copyWith(clearOutcome: true)
          : _query.copyWith(outcome: outcome),
    );
    await _reload();
  }

  Future<void> _toggleChecklist(String id) async {
    await _repo.toggleChecklistItem(id);
    final List<AppChecklistItem> items = await _repo.getChecklist();
    if (!mounted) return;
    setState(() => _checklist = items);
  }

  /// Header stats mirror the dashboard so the two surfaces agree.
  List<AppStat> _stats(JournalSummary s) => <AppStat>[
    AppStat(
      label: 'Net P/L',
      value: s.netPnl,
      icon: Icons.account_balance_wallet_outlined,
      spark: s.spark,
      formatter: AppTokens.signedMoney,
    ),
    AppStat(
      label: 'Win rate',
      value: s.winRate,
      icon: Icons.percent_rounded,
      formatter: AppTokens.percent,
    ),
    AppStat(
      label: 'Avg R multiple',
      value: s.avgR,
      icon: Icons.balance_rounded,
      formatter: AppTokens.rr,
    ),
    AppStat(
      label: 'Entries',
      value: s.total,
      icon: Icons.receipt_long_outlined,
      suffix: ' logged',
      formatter: (num v) => v.toStringAsFixed(0),
    ),
  ];

  /// P/L grouped by playbook across the trades currently in view.
  List<UiBarListItem> _byStrategy() {
    final Map<String, double> totals = <String, double>{};
    for (final AppTrade trade in _trades) {
      if (trade.outcome == AppOutcome.open) continue;
      final String key = trade.strategy ?? 'Unassigned';
      totals[key] = (totals[key] ?? 0) + trade.pnl;
    }
    final List<MapEntry<String, double>> entries = totals.entries.toList()
      ..sort(
        (MapEntry<String, double> a, MapEntry<String, double> b) =>
            b.value.compareTo(a.value),
      );
    return <UiBarListItem>[
      for (final MapEntry<String, double> e in entries)
        UiBarListItem(label: e.key, value: e.value),
    ];
  }

  List<AppTrade> _tradesForDay(DateTime day) => _trades
      .where(
        (AppTrade t) =>
            t.openedAt.year == day.year &&
            t.openedAt.month == day.month &&
            t.openedAt.day == day.day,
      )
      .toList(growable: false);
  // JOURNAL_ACTIONS_3

  @override
  Widget build(BuildContext context) {
    final JournalSummary? summary = _summary;
    final bool isMobile = context.uiRes.isMobile;
    final bool detailOpen = isMobile && _selected != null;

    return AppPageBlock(
      title: 'Trade journal',
      subtitle: summary == null
          ? 'Loading your entries…'
          : '${summary.total} entries · ${AppTokens.signedMoney(summary.netPnl)} net · ${AppTokens.percent(summary.winRate)} win rate',
      scrollable: false,
      actions: <Widget>[
        UiButton(
          label: 'Log a trade',
          leadingIcon: Icons.add_rounded,
          size: UiSize.sm,
          onPressed: _openForm,
        ),
        UiButton(
          label: 'Review with AI',
          variant: UiVariant.secondary,
          leadingIcon: Icons.auto_awesome_rounded,
          size: UiSize.sm,
          hideLabelOnMobile: true,
          onPressed: widget.onOpenAi,
        ),
      ],
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!detailOpen) ...<Widget>[
              UiToggleGroup<_JournalView>(
                options: const <UiToggleOption<_JournalView>>[
                  UiToggleOption<_JournalView>(
                    value: _JournalView.trades,
                    label: 'Trades',
                    icon: Icons.list_alt_rounded,
                  ),
                  UiToggleOption<_JournalView>(
                    value: _JournalView.calendar,
                    label: 'Calendar',
                    icon: Icons.calendar_month_rounded,
                  ),
                  UiToggleOption<_JournalView>(
                    value: _JournalView.review,
                    label: 'Review',
                    icon: Icons.insights_rounded,
                  ),
                ],
                value: _view,
                expand: isMobile,
                onChanged: (_JournalView view) => setState(() => _view = view),
              ),
              UiGap.v(context.ui.spacing.md),
            ],
            Expanded(
              child: switch (_view) {
                _JournalView.trades => _tradesView(summary),
                _JournalView.calendar => _calendarView(),
                _JournalView.review => _reviewView(summary),
              },
            ),
          ],
        ),
      ),
    );
  }

  int _activeFilterCount() {
    int count = 0;
    if (_query.side != null) count++;
    if (_query.symbol != null) count++;
    if (_query.strategy != null) count++;
    if (_query.from != null || _query.to != null) count++;
    return count;
  }

  Future<void> _clearFilters() async {
    setState(() => _query = const JournalQuery());
    await _reload();
  }

  Widget _tradesView(JournalSummary? summary) {
    final AppTrade? selected = _selected;
    final int filters = _activeFilterCount();
    final bool filtered = filters > 0 || _query.search.isNotEmpty;

    return AppWorkspacePane(
      hasSelection: selected != null,
      onClearSelection: () => setState(() => _selected = null),
      listTitle: _loading
          ? 'Loading trades…'
          : '${_trades.length} trade${_trades.length == 1 ? '' : 's'} in view',
      listActions: <Widget>[
        UiButton(
          label: filters == 0 ? 'Filters' : 'Filters · $filters',
          variant: filters == 0 ? UiVariant.ghost : UiVariant.soft,
          size: UiSize.sm,
          leadingIcon: Icons.filter_alt_outlined,
          onPressed: _openFilters,
        ),
      ],
      list: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (summary != null && !context.uiRes.isMobile) ...<Widget>[
            AppFadeIn(child: AppStatGridBlock(stats: _stats(summary))),
            UiGap.v(context.ui.spacing.md),
          ],
          AppJournalFilterBlock(
            query: _query.search,
            outcome: _query.outcome,
            onQueryChanged: _setSearch,
            onOutcomeChanged: _setOutcome,
            onOpenFilters: _openFilters,
          ),
          UiGap.v(context.ui.spacing.md),
          AppTradeListBlock(
            trades: _trades,
            loading: _loading,
            onTradeTap: (AppTrade trade) => setState(() => _selected = trade),
            emptyAction: UiButton(
              label: filtered ? 'Clear filters' : 'Log your first trade',
              leadingIcon: filtered ? Icons.clear_rounded : Icons.add_rounded,
              onPressed: filtered ? _clearFilters : _openForm,
            ),
          ),
        ],
      ),
      detail: selected == null
          ? const SizedBox.shrink()
          : AppFadeIn(
              key: ValueKey<String>(selected.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppTradeDetailBlock(
                    trade: selected,
                    onEdit: () => _openForm(initial: selected),
                    onDelete: () => _delete(selected),
                  ),
                  UiGap.v(context.ui.spacing.lg),
                  _TradeFollowUpCard(
                    trade: selected,
                    onAskAi: widget.onOpenAi,
                    onOpenTicker: widget.onOpenTicker == null
                        ? null
                        : () => widget.onOpenTicker!(selected.ticker),
                  ),
                ],
              ),
            ),
      detailTitle: selected == null
          ? null
          : '${selected.ticker} · ${AppTokens.sideLabel(selected.side)}',
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
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete trade',
                onPressed: () => _delete(selected),
              ),
            ],
      breadcrumbs: selected == null
          ? const <UiCrumb>[]
          : <UiCrumb>[
              UiCrumb(
                label: 'Journal',
                onTap: () => setState(() => _selected = null),
              ),
              UiCrumb(label: AppTokens.shortDate(selected.openedAt)),
              UiCrumb(label: selected.ticker),
            ],
      placeholderTitle: 'Pick a trade',
      placeholderMessage:
          'Select an entry to review the fills, R multiple, discipline score and notes.',
      placeholderIcon: Icons.receipt_long_outlined,
    );
  }

  Widget _calendarView() {
    final DateTime? day = _selectedDay;
    final List<AppTrade> dayTrades = day == null
        ? const <AppTrade>[]
        : _tradesForDay(day);
    AppDayPnl? dayPnl;
    if (day != null) {
      for (final AppDayPnl d in _days) {
        if (d.date.year == day.year &&
            d.date.month == day.month &&
            d.date.day == day.day) {
          dayPnl = d;
          break;
        }
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppFadeIn(
            child: AppPnlCalendarBlock(
              days: _days,
              onDayTap: (AppDayPnl d) => setState(() => _selectedDay = d.date),
            ),
          ),
          UiGap.v(context.ui.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step * 2,
            child: UiCard(
              title: day == null ? 'Day detail' : AppTokens.shortDate(day),
              subtitle: day == null
                  ? 'Tap a day on the calendar to inspect the entries behind it.'
                  : '${dayPnl?.trades ?? dayTrades.length} trade${(dayPnl?.trades ?? dayTrades.length) == 1 ? '' : 's'} · ${AppTokens.signedMoney(dayPnl?.pnl ?? 0)}',
              trailing: day == null
                  ? null
                  : UiIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Clear day',
                      size: UiSize.sm,
                      onPressed: () => setState(() => _selectedDay = null),
                    ),
              child: day == null
                  ? const UiEmptyState(
                      title: 'No day selected',
                      message:
                          'Green and red cells show desk P/L; pick one to drill into the trades.',
                      icon: Icons.calendar_month_rounded,
                    )
                  : (dayTrades.isEmpty
                        ? UiEmptyState(
                            title: 'No journal entries on this day',
                            message:
                                'The calendar tracks realised P/L, and your filters may hide matching entries.',
                            icon: Icons.event_busy_rounded,
                            action: UiButton(
                              label: 'Log a trade',
                              leadingIcon: Icons.add_rounded,
                              size: UiSize.sm,
                              onPressed: _openForm,
                            ),
                          )
                        : Column(
                            children: <Widget>[
                              for (final AppTrade trade in dayTrades)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: context.sp(context.ui.spacing.sm),
                                  ),
                                  child: AppTradeCard(
                                    trade: trade,
                                    dense: true,
                                    onTap: () => setState(() {
                                      _selected = trade;
                                      _view = _JournalView.trades;
                                    }),
                                  ),
                                ),
                            ],
                          )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewView(JournalSummary? summary) {
    final List<AppTrade> closed = _trades
        .where((AppTrade t) => t.outcome != AppOutcome.open)
        .toList(growable: false);
    final List<AppTrade> streak = closed.take(20).toList(growable: false);
    double running = 0;
    final List<AppSeriesPoint> curve = <AppSeriesPoint>[
      for (int i = closed.length - 1; i >= 0; i--)
        AppSeriesPoint(
          label: AppTokens.shortDate(closed[i].openedAt),
          value: running += closed[i].pnl,
        ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (summary != null) ...<Widget>[
            AppFadeIn(
              child: AppStatGridBlock(
                stats: _stats(summary),
                loading: _loading,
              ),
            ),
            UiGap.v(context.ui.spacing.lg),
          ],
          AppFadeIn(
            delay: AppMotion.step * 2,
            child: AppDashboardLayoutBlock(
              main: <Widget>[
                AppEquityCurveBlock(
                  series: curve,
                  title: 'Journal equity curve',
                ),
                AppBreakdownBlock(
                  items: _byStrategy(),
                  title: 'P/L by playbook',
                ),
              ],
              side: <Widget>[
                if (summary != null)
                  UiCard(
                    title: 'Outcome split',
                    subtitle:
                        '${summary.wins}W · ${summary.losses}L · ${summary.breakeven}BE',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        UiCategoryBar(
                          segments: <UiCategorySegment>[
                            UiCategorySegment(
                              value: summary.wins.toDouble(),
                              label: 'Wins',
                              color: context.uiColors.bullish,
                            ),
                            UiCategorySegment(
                              value: summary.losses.toDouble(),
                              label: 'Losses',
                              color: context.uiColors.bearish,
                            ),
                            UiCategorySegment(
                              value: summary.breakeven.toDouble(),
                              label: 'Breakeven',
                              color: context.uiColors.foregroundMuted,
                            ),
                          ],
                        ),
                        if (streak.isNotEmpty) ...<Widget>[
                          UiGap.v(context.ui.spacing.md),
                          Text(
                            'Last ${streak.length} closed trades',
                            style: context.uiText.caption.copyWith(
                              color: context.uiColors.foregroundMuted,
                            ),
                          ),
                          UiGap.v(context.ui.spacing.xs),
                          UiTracker(
                            blocks: <UiTrackerBlock>[
                              for (final AppTrade t in streak.reversed)
                                UiTrackerBlock(
                                  intent: AppTokens.outcomeIntent(t.outcome),
                                  tooltip:
                                      '${t.ticker} · ${AppTokens.signedMoney(t.pnl)}',
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                AppPreTradeChecklistBlock(
                  items: _checklist,
                  onToggle: (AppChecklistItem item, bool _) =>
                      _toggleChecklist(item.id),
                  onConfirm: () => UiToast.show(
                    context,
                    title: 'Checklist cleared',
                    message: 'Discipline logged for your next entry.',
                    intent: UiIntent.success,
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

/// Post-trade next actions: hold time, follow-up prompts and quick jumps to
/// the instrument or the copilot.
class _TradeFollowUpCard extends StatelessWidget {
  const _TradeFollowUpCard({
    required this.trade,
    this.onAskAi,
    this.onOpenTicker,
  });

  final AppTrade trade;
  final VoidCallback? onAskAi;
  final VoidCallback? onOpenTicker;

  String get _holdTime {
    final DateTime end = trade.closedAt ?? DateTime.now();
    final Duration held = end.difference(trade.openedAt);
    if (held.inHours < 1) return '${held.inMinutes}m';
    if (held.inHours < 24) return '${held.inHours}h ${held.inMinutes % 60}m';
    return '${held.inDays}d ${held.inHours % 24}h';
  }

  @override
  Widget build(BuildContext context) => UiCard(
    title: 'Follow up',
    subtitle: trade.outcome == AppOutcome.open
        ? 'Open for $_holdTime · ${AppTokens.sideLabel(trade.side)} ${trade.ticker}'
        : 'Held $_holdTime · closed ${AppTokens.relativeTime(trade.closedAt ?? trade.openedAt)}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: context.sp(context.ui.spacing.xs),
          runSpacing: context.sp(context.ui.spacing.xs),
          children: <Widget>[
            UiBadge(
              label: AppTokens.outcomeLabel(trade.outcome),
              intent: AppTokens.outcomeIntent(trade.outcome),
            ),
            if (trade.strategy != null) UiBadge(label: trade.strategy!),
            if (trade.rMultiple != null)
              UiBadge(label: AppTokens.rr(trade.rMultiple!)),
            if (trade.psychologyScore != null)
              UiBadge(label: 'Discipline ${trade.psychologyScore}/10'),
          ],
        ),
        UiGap.v(context.ui.spacing.md),
        Row(
          children: <Widget>[
            if (onAskAi != null)
              Expanded(
                child: UiButton(
                  label: 'Ask the copilot',
                  variant: UiVariant.secondary,
                  leadingIcon: Icons.auto_awesome_rounded,
                  size: UiSize.sm,
                  expand: true,
                  onPressed: onAskAi,
                ),
              ),
            if (onAskAi != null && onOpenTicker != null)
              UiGap.h(context.ui.spacing.sm),
            if (onOpenTicker != null)
              Expanded(
                child: UiButton(
                  label: 'Open ${trade.ticker}',
                  variant: UiVariant.ghost,
                  leadingIcon: Icons.show_chart_rounded,
                  size: UiSize.sm,
                  expand: true,
                  onPressed: onOpenTicker,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
