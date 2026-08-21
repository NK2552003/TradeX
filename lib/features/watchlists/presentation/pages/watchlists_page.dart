import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/watchlists/data/repositories/watchlist_repository.dart';
import 'package:tradex/features/watchlists/presentation/widgets/alert_form_sheet.dart';
import 'package:tradex/features/watchlists/presentation/widgets/watchlist_sheets.dart';

/// Lists, market heatmap and the alert desk.
enum _WatchlistView { lists, heatmap, alerts }

/// Market watch: named watchlists on the left, a full instrument workspace on
/// the right (chart, sentiment, news, AI reads and per-symbol alerts), plus a
/// heatmap and an alert desk.
class WatchlistsPage extends StatefulWidget {
  const WatchlistsPage({
    super.key,
    this.repository,
    this.initialSymbol,
    this.onOpenAi,
    this.onLogTrade,
  });

  final WatchlistRepository? repository;

  /// Symbol to open on arrival, for deep links from the feed, the journal or a
  /// notification. Ignored when the instrument is not on the desk any more.
  final String? initialSymbol;

  /// Hands the selected symbol to the copilot.
  final ValueChanged<String>? onOpenAi;

  /// Sends the selected symbol into the journal composer.
  final ValueChanged<String>? onLogTrade;

  @override
  State<WatchlistsPage> createState() => _WatchlistsPageState();
}

class _WatchlistsPageState extends State<WatchlistsPage> {
  late final WatchlistRepository _repo =
      widget.repository ?? WatchlistRepositoryImpl();

  List<Watchlist> _lists = const <Watchlist>[];
  List<AppTicker> _tickers = const <AppTicker>[];
  List<AppTicker> _heatmap = const <AppTicker>[];
  List<AppPriceAlert> _alerts = const <AppPriceAlert>[];
  List<String> _symbols = const <String>[];

  AppTicker? _selected;
  List<AppCandle> _candles = const <AppCandle>[];
  List<AppNewsItem> _news = const <AppNewsItem>[];
  List<AppAiInsight> _insights = const <AppAiInsight>[];
  ({double bullish, double neutral, double bearish})? _sentiment;

  String _listId = '';
  String _search = '';
  AppTimeframe _timeframe = AppTimeframe.d1;
  UiPriceChartType _chartType = UiPriceChartType.candles;
  _WatchlistView _view = _WatchlistView.lists;
  bool _loading = true;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<Watchlist> lists = await _repo.getWatchlists();
    final List<String> symbols = await _repo.getAvailableSymbols();
    final List<AppTicker> heatmap = await _repo.getHeatmap();
    final List<AppPriceAlert> alerts = await _repo.getAlerts();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _symbols = symbols;
      _heatmap = heatmap;
      _alerts = alerts;
      if (_listId.isEmpty && lists.isNotEmpty) _listId = lists.first.id;
    });
    await _loadTickers();
    await _openInitialSymbol();
  }

  /// Honours a deep link into one instrument. The symbol can sit in the active
  /// list, in another list or only in the heatmap, so all three are tried before
  /// giving up quietly — a stale link should never block the page.
  Future<void> _openInitialSymbol() async {
    final String wanted = (widget.initialSymbol ?? '').trim().toUpperCase();
    if (wanted.isEmpty) return;
    AppTicker? match = _find(_tickers, wanted) ?? _find(_heatmap, wanted);
    if (match == null) {
      for (final Watchlist list in _lists) {
        if (list.id == _listId) continue;
        final List<AppTicker> rows = await _repo.getTickers(list.id);
        final AppTicker? found = _find(rows, wanted);
        if (found == null) continue;
        if (!mounted) return;
        setState(() => _listId = list.id);
        await _loadTickers();
        if (!mounted) return;
        match = found;
        break;
      }
    }
    if (match == null || !mounted) return;
    await _selectTicker(match);
  }

  /// Case-insensitive symbol lookup, so a link carrying `aapl` still lands.
  static AppTicker? _find(List<AppTicker> rows, String symbol) {
    for (final AppTicker t in rows) {
      if (t.symbol.toUpperCase() == symbol) return t;
    }
    return null;
  }

  Watchlist? get _list {
    for (final Watchlist w in _lists) {
      if (w.id == _listId) return w;
    }
    return _lists.isEmpty ? null : _lists.first;
  }

  /// Tickers of the active list, narrowed by the in-list search box.
  List<AppTicker> get _visible {
    if (_search.isEmpty) return _tickers;
    final String needle = _search.toLowerCase();
    return _tickers
        .where(
          (AppTicker t) =>
              t.symbol.toLowerCase().contains(needle) ||
              t.name.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  double _priceOf(String symbol) {
    for (final AppTicker t in <AppTicker>[..._tickers, ..._heatmap]) {
      if (t.symbol == symbol) return t.price;
    }
    return 0;
  }

  Future<void> _loadTickers() async {
    final Watchlist? list = _list;
    if (list == null) {
      setState(() {
        _tickers = const <AppTicker>[];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final List<AppTicker> rows = await _repo.getTickers(list.id);
    if (!mounted) return;
    setState(() {
      _tickers = rows;
      _loading = false;
      final AppTicker? current = _selected;
      if (current != null) {
        for (final AppTicker t in rows) {
          if (t.symbol == current.symbol) {
            _selected = t;
            return;
          }
        }
      }
    });
  }

  Future<void> _selectTicker(AppTicker ticker) async {
    setState(() {
      _selected = ticker;
      _candles = const <AppCandle>[];
      _news = const <AppNewsItem>[];
      _insights = const <AppAiInsight>[];
      _sentiment = null;
      _loadingDetail = true;
    });
    final List<AppCandle> candles = await _repo.getCandles(ticker.symbol);
    final List<AppNewsItem> news = await _repo.getNews(symbol: ticker.symbol);
    final List<AppAiInsight> insights = await _repo.getInsights(
      symbol: ticker.symbol,
    );
    final ({double bullish, double neutral, double bearish}) sentiment =
        await _repo.getSentiment(ticker.symbol);
    if (!mounted) return;
    setState(() {
      _candles = candles;
      _news = news;
      _insights = insights;
      _sentiment = sentiment;
      _loadingDetail = false;
    });
  }

  Future<void> _createList() async {
    final String? name = await showWatchlistNameSheet(
      context,
      takenNames: _lists.map((Watchlist w) => w.name).toList(growable: false),
    );
    if (name == null || !mounted) return;
    final Watchlist created = await _repo.createWatchlist(name);
    final List<Watchlist> lists = await _repo.getWatchlists();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _listId = created.id;
      _selected = null;
      _search = '';
    });
    UiToast.show(
      context,
      title: 'List created',
      message: '$name is ready — add the instruments you track.',
      intent: UiIntent.success,
    );
    await _loadTickers();
  }

  Future<void> _renameList() async {
    final Watchlist? list = _list;
    if (list == null) return;
    final String? name = await showWatchlistNameSheet(
      context,
      initialName: list.name,
      takenNames: _lists.map((Watchlist w) => w.name).toList(growable: false),
    );
    if (name == null || !mounted) return;
    await _repo.renameWatchlist(list.id, name);
    final List<Watchlist> lists = await _repo.getWatchlists();
    if (!mounted) return;
    setState(() => _lists = lists);
    UiToast.show(context, title: 'List renamed', message: name);
  }

  Future<void> _deleteList() async {
    final Watchlist? list = _list;
    if (list == null) return;
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Delete ${list.name}?',
      description:
          '${list.symbols.length} instruments stop being tracked in this list. Alerts stay put.',
      confirmLabel: 'Delete list',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    await _repo.deleteWatchlist(list.id);
    final List<Watchlist> lists = await _repo.getWatchlists();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _listId = lists.isEmpty ? '' : lists.first.id;
      _selected = null;
    });
    UiToast.show(
      context,
      title: 'List deleted',
      message: list.name,
      intent: UiIntent.warning,
    );
    await _loadTickers();
  }

  Future<void> _addSymbols() async {
    final Watchlist? list = _list;
    if (list == null) return;
    final List<String>? picked = await showAddSymbolsSheet(
      context,
      listName: list.name,
      symbols: _symbols,
      alreadyIn: list.symbols,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    for (final String symbol in picked) {
      await _repo.addSymbol(list.id, symbol);
    }
    final List<Watchlist> lists = await _repo.getWatchlists();
    if (!mounted) return;
    setState(() => _lists = lists);
    UiToast.show(
      context,
      title: 'Added to ${list.name}',
      message: picked.join(' · '),
      intent: UiIntent.success,
    );
    await _loadTickers();
  }

  Future<void> _removeSymbol(AppTicker ticker) async {
    final Watchlist? list = _list;
    if (list == null) return;
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Remove ${ticker.symbol}?',
      description: 'It leaves ${list.name} but stays available to re-add.',
      confirmLabel: 'Remove',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    await _repo.removeSymbol(list.id, ticker.symbol);
    final List<Watchlist> lists = await _repo.getWatchlists();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      if (_selected?.symbol == ticker.symbol) _selected = null;
    });
    UiToast.show(
      context,
      title: 'Removed ${ticker.symbol}',
      message: 'from ${list.name}',
      intent: UiIntent.warning,
    );
    await _loadTickers();
  }

  Future<void> _openAlertForm({AppPriceAlert? initial, String? symbol}) async {
    final AppPriceAlert? alert = await showAlertFormSheet(
      context,
      initial: initial,
      symbol: symbol,
      symbols: _symbols,
      priceOf: _priceOf,
    );
    if (alert == null || !mounted) return;
    await _repo.saveAlert(alert);
    final List<AppPriceAlert> alerts = await _repo.getAlerts();
    if (!mounted) return;
    setState(() => _alerts = alerts);
    UiToast.show(
      context,
      title: initial == null ? 'Alert armed' : 'Alert updated',
      message:
          '${alert.symbol} ${alert.above ? 'above' : 'below'} ${AppTokens.money(alert.targetPrice)}',
      intent: UiIntent.success,
    );
  }

  Future<void> _toggleAlert(AppPriceAlert alert, bool active) async {
    await _repo.toggleAlert(alert.id, active);
    final List<AppPriceAlert> alerts = await _repo.getAlerts();
    if (!mounted) return;
    setState(() => _alerts = alerts);
  }

  Future<void> _deleteAlert(AppPriceAlert alert) async {
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Delete alert?',
      description:
          '${alert.symbol} ${alert.above ? 'above' : 'below'} ${AppTokens.money(alert.targetPrice)} stops being watched.',
      confirmLabel: 'Delete',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    await _repo.deleteAlert(alert.id);
    final List<AppPriceAlert> alerts = await _repo.getAlerts();
    if (!mounted) return;
    setState(() => _alerts = alerts);
    UiToast.show(
      context,
      title: 'Alert deleted',
      message: alert.symbol,
      intent: UiIntent.warning,
    );
  }

  /// Alerts attached to the instrument in the detail pane.
  List<AppPriceAlert> _alertsFor(String symbol) => _alerts
      .where((AppPriceAlert a) => a.symbol == symbol)
      .toList(growable: false);

  /// Breadth of the list in view — computed, never stored.
  List<AppStat> _stats() {
    final List<AppTicker> rows = _visible;
    if (rows.isEmpty) return const <AppStat>[];
    final int up = rows.where((AppTicker t) => t.changePercent > 0).length;
    final int down = rows.where((AppTicker t) => t.changePercent < 0).length;
    final double avg =
        rows.fold<double>(0, (double sum, AppTicker t) => sum + t.changePercent) /
        rows.length;
    final List<AppTicker> sorted = <AppTicker>[...rows]
      ..sort(
        (AppTicker a, AppTicker b) =>
            b.changePercent.compareTo(a.changePercent),
      );
    final AppTicker best = sorted.first;
    final AppTicker worst = sorted.last;
    return <AppStat>[
      AppStat(
        label: 'Instruments',
        value: rows.length,
        icon: Icons.list_alt_rounded,
        suffix: ' · $up up / $down down',
        formatter: (num v) => v.toStringAsFixed(0),
      ),
      AppStat(
        label: 'Average move',
        value: avg,
        icon: Icons.stacked_line_chart_rounded,
        formatter: AppTokens.signedPercent,
        spark: rows
            .map((AppTicker t) => t.changePercent)
            .toList(growable: false),
      ),
      AppStat(
        label: 'Leader ${best.symbol}',
        value: best.changePercent,
        icon: Icons.trending_up_rounded,
        formatter: AppTokens.signedPercent,
        spark: best.spark,
      ),
      AppStat(
        label: 'Laggard ${worst.symbol}',
        value: worst.changePercent,
        icon: Icons.trending_down_rounded,
        formatter: AppTokens.signedPercent,
        spark: worst.spark,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final Watchlist? list = _list;
    final int armed = _alerts.where((AppPriceAlert a) => a.active).length;

    return AppPageBlock(
      title: 'Market watch',
      subtitle: list == null
          ? 'Create a list to start tracking instruments'
          : '${_lists.length} lists · ${_tickers.length} instruments · $armed armed alerts',
      scrollable: false,
      actions: <Widget>[
        UiButton(
          label: 'Add symbols',
          leadingIcon: Icons.add_rounded,
          expandOnMobile: false,
          onPressed: list == null ? null : _addSymbols,
        ),
        UiButton(
          label: 'New alert',
          variant: UiVariant.outline,
          leadingIcon: Icons.add_alert_outlined,
          expandOnMobile: false,
          hideLabelOnMobile: true,
          onPressed: () => _openAlertForm(symbol: _selected?.symbol),
        ),
      ],
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!(context.uiRes.isMobile &&
                _view == _WatchlistView.lists &&
                _selected != null)) ...<Widget>[
              UiToggleGroup<_WatchlistView>(
                options: <UiToggleOption<_WatchlistView>>[
                  const UiToggleOption<_WatchlistView>(
                    value: _WatchlistView.lists,
                    label: 'Lists',
                    icon: Icons.playlist_add_check_rounded,
                  ),
                  const UiToggleOption<_WatchlistView>(
                    value: _WatchlistView.heatmap,
                    label: 'Heatmap',
                    icon: Icons.grid_view_rounded,
                  ),
                  UiToggleOption<_WatchlistView>(
                    value: _WatchlistView.alerts,
                    label: 'Alerts',
                    icon: Icons.notifications_active_outlined,
                    badge: _alerts.isEmpty ? null : '${_alerts.length}',
                  ),
                ],
                value: _view,
                expand: context.uiRes.isMobile,
                onChanged: (_WatchlistView view) =>
                    setState(() => _view = view),
              ),
              UiGap.v(context.ui.spacing.lg),
            ],
            Expanded(
              child: switch (_view) {
                _WatchlistView.lists => _listsView(),
                _WatchlistView.heatmap => _heatmapView(),
                _WatchlistView.alerts => _alertsView(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _listsView() {
    final Watchlist? list = _list;
    final AppTicker? selected = _selected;
    final List<AppTicker> rows = _visible;

    return AppWorkspacePane(
      hasSelection: selected != null,
      onClearSelection: () => setState(() => _selected = null),
      initialRatio: 0.4,
      listTitle: list == null ? 'Watchlists' : list.name,
      listActions: <Widget>[
        UiIconButton(
          icon: Icons.drive_file_rename_outline_rounded,
          tooltip: 'Rename list',
          onPressed: list == null ? null : _renameList,
        ),
        UiIconButton(
          icon: Icons.playlist_add_rounded,
          tooltip: 'New list',
          onPressed: _createList,
        ),
        UiIconButton(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Delete list',
          onPressed: list == null || _lists.length < 2 ? null : _deleteList,
        ),
      ],
      detailTitle: selected?.symbol,
      detailActions: <Widget>[
        UiIconButton(
          icon: Icons.add_alert_outlined,
          tooltip: 'Alert on this symbol',
          onPressed: selected == null
              ? null
              : () => _openAlertForm(symbol: selected.symbol),
        ),
        UiIconButton(
          icon: Icons.playlist_remove_rounded,
          tooltip: 'Remove from list',
          onPressed: selected == null ? null : () => _removeSymbol(selected),
        ),
      ],
      breadcrumbs: <UiCrumb>[
        const UiCrumb(label: 'Watchlists'),
        if (list != null) UiCrumb(label: list.name),
        if (selected != null) UiCrumb(label: selected.symbol),
      ],
      placeholderTitle: 'Pick an instrument',
      placeholderMessage:
          'Select a symbol to see the chart, crowd sentiment, headlines and AI reads.',
      placeholderIcon: Icons.candlestick_chart_outlined,
      list: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_lists.isNotEmpty) ...<Widget>[
            UiSelect<String>(
              options: <UiOption<String>>[
                for (final Watchlist w in _lists)
                  UiOption<String>(
                    value: w.id,
                    label: w.name,
                    description: '${w.symbols.length} instruments',
                  ),
              ],
              value: _listId,
              leadingIcon: Icons.playlist_add_check_rounded,
              searchable: _lists.length > 6,
              onChanged: (String value) {
                setState(() {
                  _listId = value;
                  _selected = null;
                  _search = '';
                });
                _loadTickers();
              },
            ),
            UiGap.v(context.ui.spacing.md),
          ],
          UiSearchField(
            value: _search,
            hintText: 'Filter this list',
            onChanged: (String value) => setState(() => _search = value),
          ),
          UiGap.v(context.ui.spacing.md),
          if (!context.uiRes.isMobile && _stats().isNotEmpty) ...<Widget>[
            AppStatGridBlock(stats: _stats(), loading: _loading),
            UiGap.v(context.ui.spacing.lg),
          ],
          AppWatchlistBlock(
            tickers: rows,
            loading: _loading,
            onAdd: list == null ? _createList : _addSymbols,
            onTickerTap: _selectTicker,
            onFavorite: _removeSymbol,
          ),
          if (!_loading && rows.isEmpty && _search.isNotEmpty) ...<Widget>[
            UiGap.v(context.ui.spacing.md),
            UiButton(
              label: 'Clear filter',
              variant: UiVariant.ghost,
              leadingIcon: Icons.close_rounded,
              expand: true,
              onPressed: () => setState(() => _search = ''),
            ),
          ],
        ],
      ),
      detail: selected == null
          ? const SizedBox.shrink()
          : AppFadeIn(
              key: ValueKey<String>(selected.symbol),
              child: _detail(selected),
            ),
    );
  }

  Widget _detail(AppTicker ticker) {
    final ({double bullish, double neutral, double bearish})? sentiment =
        _sentiment;
    final List<AppPriceAlert> alerts = _alertsFor(ticker.symbol);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPriceChartBlock(
          candles: _candles,
          ticker: ticker,
          loading: _loadingDetail,
          timeframe: _timeframe,
          onTimeframeChanged: (AppTimeframe tf) =>
              setState(() => _timeframe = tf),
          chartType: _chartType,
          onChartTypeChanged: (UiPriceChartType type) =>
              setState(() => _chartType = type),
        ),
        UiGap.v(context.ui.spacing.lg),
        AppDashboardLayoutBlock(
          main: <Widget>[
            AppNewsFeedBlock(
              items: _news,
              title: '${ticker.symbol} headlines',
            ),
            AppMarketAiInsightsBlock(
              insights: _insights,
              title: 'AI reads on ${ticker.symbol}',
              loading: _loadingDetail,
            ),
          ],
          side: <Widget>[
            if (sentiment != null)
              AppSentimentBlock(
                bullish: sentiment.bullish,
                neutral: sentiment.neutral,
                bearish: sentiment.bearish,
                title: 'Crowd on ${ticker.symbol}',
              ),
            UiCard(
              title: 'Alerts on ${ticker.symbol}',
              trailing: UiButton(
                label: 'New',
                size: UiSize.sm,
                variant: UiVariant.outline,
                leadingIcon: Icons.add_rounded,
                expandOnMobile: false,
                onPressed: () => _openAlertForm(symbol: ticker.symbol),
              ),
              child: alerts.isEmpty
                  ? const UiEmptyState(
                      title: 'No levels set',
                      message:
                          'Arm an alert so you do not have to watch the tape.',
                      icon: Icons.notifications_none_rounded,
                    )
                  : Column(
                      children: <Widget>[
                        for (final AppPriceAlert alert in alerts)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: context.sp(context.ui.spacing.sm),
                            ),
                            child: AppPriceAlertCard(
                              alert: alert,
                              onToggle: (bool value) =>
                                  _toggleAlert(alert, value),
                              onDelete: () => _deleteAlert(alert),
                            ),
                          ),
                      ],
                    ),
            ),
            UiCard(
              title: 'Act on it',
              subtitle: 'Take the idea into the journal or ask the copilot.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  UiButton(
                    label: 'Log a trade on ${ticker.symbol}',
                    leadingIcon: Icons.add_task_rounded,
                    expand: true,
                    onPressed: widget.onLogTrade == null
                        ? null
                        : () => widget.onLogTrade!(ticker.symbol),
                  ),
                  UiGap.v(context.ui.spacing.sm),
                  UiButton(
                    label: 'Ask the copilot',
                    variant: UiVariant.secondary,
                    leadingIcon: Icons.auto_awesome,
                    expand: true,
                    onPressed: widget.onOpenAi == null
                        ? null
                        : () => widget.onOpenAi!(ticker.symbol),
                  ),
                  UiGap.v(context.ui.spacing.sm),
                  UiButton(
                    label: 'Remove from list',
                    variant: UiVariant.ghost,
                    leadingIcon: Icons.playlist_remove_rounded,
                    expand: true,
                    onPressed: () => _removeSymbol(ticker),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heatmapView() {
    final List<AppTicker> sorted = <AppTicker>[..._heatmap]
      ..sort(
        (AppTicker a, AppTicker b) =>
            b.changePercent.compareTo(a.changePercent),
      );
    final List<AppTicker> gainers = sorted.take(5).toList(growable: false);
    final List<AppTicker> losers = sorted.reversed
        .take(5)
        .toList(growable: false);

    void open(AppTicker ticker) {
      setState(() => _view = _WatchlistView.lists);
      _selectTicker(ticker);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppFadeIn(
            child: AppHeatmapBlock(
              entries: sorted,
              title: 'Market heatmap · ${sorted.length} instruments',
              onTap: open,
            ),
          ),
          UiGap.v(context.ui.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step * 2,
            child: _moverRail('Top gainers', gainers, open),
          ),
          UiGap.v(context.ui.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step * 3,
            child: _moverRail('Top losers', losers, open),
          ),
        ],
      ),
    );
  }

  Widget _moverRail(
    String title,
    List<AppTicker> tickers,
    ValueChanged<AppTicker> onTap,
  ) => UiCard(
    title: title,
    child: tickers.isEmpty
        ? const UiEmptyState(
            title: 'Nothing to show',
            icon: Icons.hourglass_empty_rounded,
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final AppTicker ticker in tickers)
                  Padding(
                    padding: EdgeInsets.only(
                      right: context.sp(context.ui.spacing.sm),
                    ),
                    child: AppMoverCard(
                      ticker: ticker,
                      width: context.sz(180),
                      onTap: () => onTap(ticker),
                    ),
                  ),
              ],
            ),
          ),
  );

  Widget _alertsView() {
    final List<AppPriceAlert> armed = _alerts
        .where((AppPriceAlert a) => a.active && a.triggeredAt == null)
        .toList(growable: false);
    final List<AppPriceAlert> triggered = _alerts
        .where((AppPriceAlert a) => a.triggeredAt != null)
        .toList(growable: false);
    final List<AppPriceAlert> paused = _alerts
        .where((AppPriceAlert a) => !a.active && a.triggeredAt == null)
        .toList(growable: false);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppStatGridBlock(
            stats: <AppStat>[
              AppStat(
                label: 'Armed',
                value: armed.length,
                icon: Icons.notifications_active_outlined,
                formatter: (num v) => v.toStringAsFixed(0),
              ),
              AppStat(
                label: 'Triggered',
                value: triggered.length,
                icon: Icons.notifications_on_outlined,
                formatter: (num v) => v.toStringAsFixed(0),
              ),
              AppStat(
                label: 'Paused',
                value: paused.length,
                icon: Icons.notifications_paused_outlined,
                formatter: (num v) => v.toStringAsFixed(0),
              ),
              AppStat(
                label: 'Instruments covered',
                value: _alerts
                    .map((AppPriceAlert a) => a.symbol)
                    .toSet()
                    .length,
                icon: Icons.candlestick_chart_rounded,
                formatter: (num v) => v.toStringAsFixed(0),
              ),
            ],
          ),
          UiGap.v(context.ui.spacing.lg),
          AppDashboardLayoutBlock(
            main: <Widget>[
              AppAlertsBlock(
                alerts: _alerts,
                onToggle: _toggleAlert,
                onDelete: _deleteAlert,
                onCreate: _openAlertForm,
              ),
            ],
            side: <Widget>[
              UiCard(
                title: 'Recently triggered',
                subtitle: 'Levels that already printed.',
                child: triggered.isEmpty
                    ? const UiEmptyState(
                        title: 'Nothing has fired yet',
                        message: 'Triggered levels land here with a timestamp.',
                        icon: Icons.history_rounded,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final AppPriceAlert alert in triggered)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: context.sp(context.ui.spacing.sm),
                              ),
                              child: UiCard(
                                onTap: () => _openAlertForm(initial: alert),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            '${alert.symbol} ${alert.above ? 'above' : 'below'} ${AppTokens.money(alert.targetPrice)}',
                                            style: context.uiText.bodyStrong,
                                          ),
                                          Text(
                                            AppTokens.relativeTime(
                                              alert.triggeredAt!,
                                            ),
                                            style: context.uiText.caption
                                                .copyWith(
                                                  color: context
                                                      .uiColors
                                                      .foregroundMuted,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    UiBadge(
                                      label: 'Fired',
                                      intent: UiIntent.warning,
                                      filled: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              UiCard(
                title: 'How alerts work',
                child: UiCallout(
                  title: 'Server-side monitoring',
                  message:
                      'Levels are evaluated on the exchange feed, so alerts fire whether or not the app is open.',
                  icon: Icons.cloud_done_outlined,
                  intent: UiIntent.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

