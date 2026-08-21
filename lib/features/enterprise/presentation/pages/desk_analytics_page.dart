import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/enterprise/data/repositories/desk_repository.dart';

/// Admin analytics: desk performance over a rolling window, attribution by
/// seat, strategy and symbol, session behaviour, plan consumption and the keys
/// that pull the same numbers out programmatically. Every figure is computed by
/// [DeskRepository.getAnalytics] so this screen only lays them out.
class DeskAnalyticsPage extends StatefulWidget {
  const DeskAnalyticsPage({
    super.key,
    this.repository,
    this.onOpenTeam,
    this.onOpenRisk,
    this.onOpenAudit,
    this.onUpgrade,
  });

  final DeskRepository? repository;
  final VoidCallback? onOpenTeam;
  final VoidCallback? onOpenRisk;
  final VoidCallback? onOpenAudit;
  final VoidCallback? onUpgrade;

  @override
  State<DeskAnalyticsPage> createState() => _DeskAnalyticsPageState();
}

/// Which dimension the attribution card is showing.
enum _Attribution { seat, strategy, symbol }

class _DeskAnalyticsPageState extends State<DeskAnalyticsPage> {
  late final DeskRepository _repo = widget.repository ?? DeskRepositoryImpl();

  /// Windows the console offers. The repository accepts any day count, so these
  /// are presentation presets rather than a limit.
  static const List<int> _windows = <int>[7, 30, 90];

  DeskAnalytics? _analytics;
  List<AppApiKey> _keys = const <AppApiKey>[];
  int _window = 30;
  _Attribution _attribution = _Attribution.seat;
  bool _loading = true;
  bool _refreshing = false;
  bool _creatingKey = false;
  String? _busyKeyId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _repo.getAnalytics(windowDays: _window),
      _repo.getApiKeys(),
    ]);
    if (!mounted) return;
    setState(() {
      _analytics = results[0]! as DeskAnalytics;
      _keys = results[1]! as List<AppApiKey>;
      _loading = false;
    });
  }

  /// Re-queries for a new window and drops the answer if the window moved on
  /// while the request was in flight.
  Future<void> _setWindow(int days) async {
    if (days == _window) return;
    setState(() {
      _window = days;
      _refreshing = true;
    });
    final DeskAnalytics analytics = await _repo.getAnalytics(windowDays: days);
    if (!mounted || _window != days) return;
    setState(() {
      _analytics = analytics;
      _refreshing = false;
    });
  }

  static String _windowLabel(int days) => '$days days';
  Future<void> _createKey() async {
    final List<({String scope, String description})> catalogue = await _repo
        .getApiScopes();
    if (!mounted) return;
    final ({String label, List<String> scopes})? draft =
        await UiDialog.show<({String label, List<String> scopes})>(
          context,
          child: _KeySheet(
            catalogue: catalogue,
            takenLabels: _keys
                .map((AppApiKey k) => k.label.toLowerCase())
                .toSet(),
          ),
        );
    if (draft == null || !mounted) return;
    setState(() => _creatingKey = true);
    final AppApiKey key = await _repo.createApiKey(draft.label, draft.scopes);
    if (!mounted) return;
    setState(() {
      _keys = <AppApiKey>[key, ..._keys];
      _creatingKey = false;
    });
    UiToast.show(
      context,
      title: 'Key created',
      message: '${key.maskedKey} · ${key.scopes.join(', ')}',
      intent: UiIntent.success,
    );
  }

  Future<void> _revokeKey(AppApiKey key) async {
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Revoke ${key.label}?',
      description:
          'Anything signing with this key stops working immediately. The '
          'revocation is audited and cannot be undone.',
      confirmLabel: 'Revoke key',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyKeyId = key.id);
    await _repo.revokeApiKey(key.id);
    final List<AppApiKey> keys = await _repo.getApiKeys();
    if (!mounted) return;
    setState(() {
      _keys = keys;
      _busyKeyId = null;
    });
    UiToast.show(
      context,
      title: '${key.label} revoked',
      message: 'The key is listed as revoked and can no longer authenticate.',
      intent: UiIntent.warning,
    );
  }

  Future<void> _copyKey(AppApiKey key) async {
    await Clipboard.setData(ClipboardData(text: key.maskedKey));
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Key reference copied',
      message:
          'Only the masked reference is stored — the secret is shown once.',
      intent: UiIntent.info,
    );
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _repo.getAnalytics(windowDays: _window),
      _repo.getApiKeys(),
    ]);
    if (!mounted) return;
    setState(() {
      _analytics = results[0]! as DeskAnalytics;
      _keys = results[1]! as List<AppApiKey>;
      _refreshing = false;
    });
  }

  String get _subtitle {
    final DeskAnalytics? analytics = _analytics;
    if (analytics == null) return 'Crunching desk performance…';
    final List<String> parts = <String>[
      'last ${analytics.windowDays} days',
      '${analytics.tradedDays} active day${analytics.tradedDays == 1 ? '' : 's'}',
      '${AppTokens.percent(analytics.greenDayRate)} of them green',
      '${analytics.seats.length} contributing seat${analytics.seats.length == 1 ? '' : 's'}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final DeskAnalytics? analytics = _analytics;
    return AppPageBlock(
      title: 'Desk analytics',
      subtitle: _subtitle,
      actions: <Widget>[
        UiButton(
          label: 'Refresh',
          leadingIcon: Icons.refresh_rounded,
          size: UiSize.sm,
          loading: _refreshing,
          onPressed: _loading ? null : _refresh,
        ),
        UiButton(
          label: 'Audit trail',
          variant: UiVariant.secondary,
          leadingIcon: Icons.receipt_long_rounded,
          size: UiSize.sm,
          hideLabelOnMobile: true,
          onPressed: widget.onOpenAudit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppFadeIn(child: _windowPicker()),
          UiGap.v(theme.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step,
            child: AppStatGridBlock(
              stats: analytics?.stats ?? const <AppStat>[],
              loading: _loading,
            ),
          ),
          UiGap.v(theme.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step * 2,
            child: AppDashboardLayoutBlock(
              main: <Widget>[
                AppEquityCurveBlock(
                  title: 'Desk equity',
                  series: analytics?.equity ?? const <AppSeriesPoint>[],
                ),
                _attributionCard(analytics),
                _seatTableCard(analytics),
                AppPnlCalendarBlock(
                  title: 'Daily desk P/L',
                  days: analytics?.days ?? const <AppDayPnl>[],
                  onDayTap: (AppDayPnl day) => UiToast.show(
                    context,
                    title: AppTokens.shortDate(day.date),
                    message:
                        '${day.trades} trade${day.trades == 1 ? '' : 's'} · ${AppTokens.signedMoney(day.pnl)}',
                    intent: AppTokens.plIntent(day.pnl),
                  ),
                ),
              ],
              side: <Widget>[
                _consistencyCard(analytics),
                _behaviourCard(analytics),
                AppUsageBlock(
                  metrics: analytics?.usage ?? const <AppUsageMetric>[],
                  onUpgrade: widget.onUpgrade,
                ),
                AppApiKeysBlock(
                  keys: _keys,
                  loading: _loading || _creatingKey || _busyKeyId != null,
                  onCreate: _createKey,
                  onRevoke: _revokeKey,
                  onCopy: _copyKey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Window switcher. Every card below reads the same window, so it sits once at
  /// the top rather than being repeated per card.
  Widget _windowPicker() {
    final UiTheme theme = context.ui;
    final Widget picker = UiToggleGroup<int>(
      value: _window,
      label: 'Reporting window',
      onChanged: _setWindow,
      expand: context.uiRes.isMobile,
      options: <UiToggleOption<int>>[
        for (final int days in _windows)
          UiToggleOption<int>(value: days, label: _windowLabel(days)),
      ],
    );
    if (context.uiRes.isMobile) return picker;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(child: picker),
        SizedBox(width: context.sp(theme.spacing.md)),
        if (_refreshing)
          UiSkeleton(width: context.sz(120), height: context.sz(20))
        else
          UiButton(
            label: 'Risk controls',
            variant: UiVariant.ghost,
            size: UiSize.sm,
            trailingIcon: Icons.arrow_forward_rounded,
            expandOnMobile: false,
            onPressed: widget.onOpenRisk,
          ),
      ],
    );
  }

  /// Attribution, one dimension at a time. Seat, strategy and symbol answer the
  /// same question from different angles, so they share a card rather than
  /// competing for space.
  Widget _attributionCard(DeskAnalytics? analytics) {
    final UiTheme theme = context.ui;
    final List<UiBarListItem> items = switch (_attribution) {
      _Attribution.seat => analytics?.bySeat ?? const <UiBarListItem>[],
      _Attribution.strategy => analytics?.byStrategy ?? const <UiBarListItem>[],
      _Attribution.symbol => analytics?.bySymbol ?? const <UiBarListItem>[],
    };
    return UiCard(
      title: 'Where the P/L came from',
      subtitle: _attributionHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiTabs(
            items: <UiTabItem>[
              for (final _Attribution dimension in _Attribution.values)
                UiTabItem(
                  label: _attributionLabel(dimension),
                  icon: _attributionIcon(dimension),
                ),
            ],
            index: _Attribution.values.indexOf(_attribution),
            variant: UiTabsVariant.segmented,
            size: UiSize.sm,
            stretch: true,
            showPanel: false,
            onChanged: (int index) =>
                setState(() => _attribution = _Attribution.values[index]),
          ),
          UiGap.v(theme.spacing.md),
          _attributionBars(items),
        ],
      ),
    );
  }

  /// The ranked bars themselves. Each bar is recoloured from its own sign so a
  /// list mixing winners and losers stays readable at a glance.
  Widget _attributionBars(List<UiBarListItem> items) => UiAsyncView(
    loading: _loading,
    isEmpty: items.isEmpty,
    emptyTitle: 'Nothing closed in this window',
    emptyMessage: 'Widen the reporting window to see where the desk earned.',
    emptyIcon: Icons.donut_large_rounded,
    builder: (BuildContext ctx) => UiBarList(
      items: <UiBarListItem>[
        for (final UiBarListItem item in items)
          UiBarListItem(
            label: item.label,
            value: item.value,
            color: AppTokens.pl(ctx, item.value),
          ),
      ],
      valueFormatter: _signedCompact,
    ),
  );

  static String _attributionLabel(_Attribution dimension) =>
      switch (dimension) {
        _Attribution.seat => 'By seat',
        _Attribution.strategy => 'By strategy',
        _Attribution.symbol => 'By symbol',
      };

  static IconData _attributionIcon(_Attribution dimension) =>
      switch (dimension) {
        _Attribution.seat => Icons.groups_rounded,
        _Attribution.strategy => Icons.schema_rounded,
        _Attribution.symbol => Icons.candlestick_chart_rounded,
      };

  String get _attributionHint => switch (_attribution) {
    _Attribution.seat => 'Net contribution per active seat over the window.',
    _Attribution.strategy =>
      'Net result per tagged playbook. Trades without a tag group under '
          'Unassigned.',
    _Attribution.symbol =>
      'The instruments moving the desk most, by absolute result.',
  };

  /// Bars carry the sign so a losing contributor can never read as a winning
  /// one, and stay compact so long labels keep their room.
  static String _signedCompact(num value) {
    final String sign = value > 0 ? '+' : (value < 0 ? '-' : '');
    return '$sign${AppTokens.compactMoney(value.abs())}';
  }

  /// Seat leaderboard — the accountability view: who traded, how often, how
  /// well, and how much of the desk's movement they own. On phones the table
  /// stacks into cards, so every column is still readable without scrolling
  /// sideways.
  Widget _seatTableCard(DeskAnalytics? analytics) {
    final List<DeskSeatPerformance> seats =
        analytics?.seats ?? const <DeskSeatPerformance>[];
    return UiCard(
      title: 'Seat leaderboard',
      subtitle:
          'Ranked by net contribution. Open a row to manage the seat itself.',
      trailing: UiButton(
        label: 'Team & seats',
        variant: UiVariant.ghost,
        size: UiSize.sm,
        trailingIcon: Icons.arrow_forward_rounded,
        expandOnMobile: false,
        hideLabelOnMobile: true,
        onPressed: widget.onOpenTeam,
      ),
      child: UiTable<DeskSeatPerformance>(
        rows: seats,
        loading: _loading,
        stackOnMobile: true,
        stickyHeader: true,
        density: UiDensity.compact,
        pageSize: 8,
        emptyLabel: 'No seat closed a trade in this window',
        onRowTap: (DeskSeatPerformance _) => widget.onOpenTeam?.call(),
        columns: _seatColumns(),
      ),
    );
  }

  /// Column set for the leaderboard. Every column is sortable, and the lower
  /// priority ones drop away as the viewport narrows — except in stacked mode,
  /// where they become labelled rows instead.
  List<UiTableColumn<DeskSeatPerformance>>
  _seatColumns() => <UiTableColumn<DeskSeatPerformance>>[
    UiTableColumn<DeskSeatPerformance>(
      header: 'Seat',
      flex: 2,
      compare: (DeskSeatPerformance a, DeskSeatPerformance b) =>
          a.member.name.compareTo(b.member.name),
      cell: (BuildContext ctx, DeskSeatPerformance row) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            row.member.name,
            style: ctx.uiText.bodyStrong,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: ctx.sp(ctx.ui.spacing.xxs)),
          UiBadge(
            label: appTeamRoleLabel(row.member.role),
            intent: appTeamRoleIntent(row.member.role),
            size: UiSize.xs,
          ),
        ],
      ),
    ),
    UiTableColumn<DeskSeatPerformance>(
      header: 'Trades',
      numeric: true,
      compare: (DeskSeatPerformance a, DeskSeatPerformance b) =>
          a.trades.compareTo(b.trades),
      cell: (BuildContext ctx, DeskSeatPerformance row) =>
          Text('${row.trades}', style: ctx.uiText.numeric),
    ),
    UiTableColumn<DeskSeatPerformance>(
      header: 'Win rate',
      numeric: true,
      compare: (DeskSeatPerformance a, DeskSeatPerformance b) =>
          a.winRate.compareTo(b.winRate),
      cell: (BuildContext ctx, DeskSeatPerformance row) => Text(
        AppTokens.percent(row.winRate, decimals: 0),
        style: ctx.uiText.numeric,
      ),
    ),
    UiTableColumn<DeskSeatPerformance>(
      header: 'Net P/L',
      numeric: true,
      compare: (DeskSeatPerformance a, DeskSeatPerformance b) =>
          a.netPnl.compareTo(b.netPnl),
      cell: (BuildContext ctx, DeskSeatPerformance row) => Text(
        AppTokens.signedMoney(row.netPnl, decimals: 0),
        style: ctx.uiText.numeric.copyWith(
          color: AppTokens.pl(ctx, row.netPnl),
        ),
      ),
    ),
    UiTableColumn<DeskSeatPerformance>(
      header: 'Avg R',
      numeric: true,
      hideBelow: UiTableVisibility.tabletUp,
      compare: (DeskSeatPerformance a, DeskSeatPerformance b) =>
          a.avgRMultiple.compareTo(b.avgRMultiple),
      cell: (BuildContext ctx, DeskSeatPerformance row) => Text(
        AppTokens.rr(row.avgRMultiple),
        style: ctx.uiText.numeric.copyWith(
          color: AppTokens.pl(ctx, row.avgRMultiple),
        ),
      ),
    ),
    UiTableColumn<DeskSeatPerformance>(
      header: 'Share of desk',
      numeric: true,
      hideBelow: UiTableVisibility.desktopUp,
      compare: (DeskSeatPerformance a, DeskSeatPerformance b) =>
          a.share.compareTo(b.share),
      cell: (BuildContext ctx, DeskSeatPerformance row) => Text(
        AppTokens.percent(row.share, decimals: 0),
        style: ctx.uiText.numeric.copyWith(color: ctx.uiColors.foregroundMuted),
      ),
    ),
    UiTableColumn<DeskSeatPerformance>(
      header: 'Best / worst',
      numeric: true,
      hideBelow: UiTableVisibility.desktopUp,
      compare: (DeskSeatPerformance a, DeskSeatPerformance b) =>
          a.bestTrade.compareTo(b.bestTrade),
      cell: (BuildContext ctx, DeskSeatPerformance row) => Text(
        '${AppTokens.signedMoney(row.bestTrade, decimals: 0)} / '
        '${AppTokens.signedMoney(row.worstTrade, decimals: 0)}',
        style: ctx.uiText.numeric.copyWith(color: ctx.uiColors.foregroundMuted),
      ),
    ),
  ];

  /// Consistency: how often the desk actually shows up, and whether the good
  /// days outnumber the bad ones. Same window as every other card.
  Widget _consistencyCard(DeskAnalytics? analytics) {
    final UiTheme theme = context.ui;
    if (analytics == null) {
      return UiCard(
        title: 'Consistency',
        loading: true,
        loadingHeight: 200,
        child: const SizedBox.shrink(),
      );
    }
    final int redDays = analytics.tradedDays - analytics.greenDays;
    return UiCard(
      title: 'Consistency',
      subtitle:
          '${analytics.tradedDays} of ${analytics.windowDays} days saw a trade.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiProgressBar(
            value: analytics.greenDayRate / 100,
            label: 'Green days',
            intent: UiIntent.bullish,
            valueFormatter: (num _) =>
                '${analytics.greenDays} of ${analytics.tradedDays}',
          ),
          if (analytics.tradedDays > 0) ...<Widget>[
            UiGap.v(theme.spacing.md),
            UiCategoryBar(
              segments: <UiCategorySegment>[
                UiCategorySegment(
                  value: analytics.greenDays.toDouble(),
                  label: '${analytics.greenDays} green',
                  color: theme.colors.bullish,
                ),
                UiCategorySegment(
                  value: redDays.toDouble(),
                  label: '$redDays red',
                  color: theme.colors.bearish,
                ),
              ],
            ),
          ],
          UiGap.v(theme.spacing.md),
          const UiDivider(),
          UiGap.v(theme.spacing.xs),
          _metricRow(
            'Best day',
            analytics.bestDay == null
                ? 'No activity yet'
                : '${AppTokens.shortDate(analytics.bestDay!.date)} · '
                      '${AppTokens.signedMoney(analytics.bestDay!.pnl, decimals: 0)}',
            icon: Icons.trending_up_rounded,
            intent: analytics.bestDay == null
                ? null
                : AppTokens.plIntent(analytics.bestDay!.pnl),
          ),
          _metricRow(
            'Worst day',
            analytics.worstDay == null
                ? 'No activity yet'
                : '${AppTokens.shortDate(analytics.worstDay!.date)} · '
                      '${AppTokens.signedMoney(analytics.worstDay!.pnl, decimals: 0)}',
            icon: Icons.trending_down_rounded,
            intent: analytics.worstDay == null
                ? null
                : AppTokens.plIntent(analytics.worstDay!.pnl),
          ),
          _metricRow(
            'Contributing seats',
            '${analytics.seats.length}',
            icon: Icons.groups_rounded,
          ),
          _metricRow(
            'Green day rate',
            AppTokens.percent(analytics.greenDayRate),
            icon: Icons.percent_rounded,
            intent: UiIntent.bullish,
          ),
        ],
      ),
    );
  }

  /// Label-and-figure row used by the side cards. Kept here so every one of
  /// them lines up its numbers the same way.
  Widget _metricRow(
    String label,
    String value, {
    IconData? icon,
    UiIntent? intent,
  }) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: context.sz(theme.sizes.iconSm),
              color: theme.colors.foregroundMuted,
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
          ],
          Expanded(
            child: Text(
              label,
              style: context.uiText.label.copyWith(
                color: theme.colors.foregroundMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Text(
            value,
            style: context.uiText.numeric.copyWith(
              color: intent?.color(context) ?? theme.colors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  /// Behaviour: the result mix, and which part of the session the desk chooses
  /// to open risk in. Both are derived from the closed trades in the window.
  Widget _behaviourCard(DeskAnalytics? analytics) {
    final UiTheme theme = context.ui;
    if (analytics == null) {
      return UiCard(
        title: 'Behaviour',
        loading: true,
        loadingHeight: 220,
        child: const SizedBox.shrink(),
      );
    }
    final List<({int count, AppOutcome outcome, double pnl})> mix = analytics
        .outcomes
        .where(
          (({int count, AppOutcome outcome, double pnl}) row) => row.count > 0,
        )
        .toList(growable: false);
    return UiCard(
      title: 'Behaviour',
      subtitle: 'How trades resolve, and when the desk puts risk on.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (mix.isEmpty)
            const UiCallout(
              title: 'Nothing closed yet',
              message:
                  'No position was closed in this window, so there is no '
                  'result mix to show.',
              intent: UiIntent.info,
              icon: Icons.hourglass_empty_rounded,
            )
          else ...<Widget>[
            UiCategoryBar(
              segments: <UiCategorySegment>[
                for (final ({int count, AppOutcome outcome, double pnl}) row
                    in mix)
                  UiCategorySegment(
                    value: row.count.toDouble(),
                    label:
                        '${AppTokens.outcomeLabel(row.outcome)} · ${row.count}',
                    color: AppTokens.outcomeIntent(row.outcome).color(context),
                  ),
              ],
            ),
            UiGap.v(theme.spacing.md),
            for (final ({int count, AppOutcome outcome, double pnl}) row in mix)
              _metricRow(
                '${AppTokens.outcomeLabel(row.outcome)} (${row.count})',
                AppTokens.signedMoney(row.pnl, decimals: 0),
                intent: AppTokens.plIntent(row.pnl),
              ),
          ],
          UiGap.v(theme.spacing.md),
          const UiDivider(),
          UiGap.v(theme.spacing.md),
          const UiLabel(
            text: 'Net by session block',
            helper: 'Bucketed by the hour a position was opened.',
          ),
          UiGap.v(theme.spacing.sm),
          _sessionBars(analytics.sessions),
        ],
      ),
    );
  }

  /// Session buckets, coloured by result so a consistently bad slot of the day
  /// is obvious without reading the numbers.
  Widget _sessionBars(List<UiBarListItem> sessions) {
    if (sessions.isEmpty) {
      return Text(
        'No opens recorded in this window.',
        style: context.uiText.caption.copyWith(
          color: context.uiColors.foregroundMuted,
        ),
      );
    }
    return UiBarList(
      items: <UiBarListItem>[
        for (final UiBarListItem item in sessions)
          UiBarListItem(
            label: item.label,
            value: item.value,
            color: AppTokens.pl(context, item.value),
          ),
      ],
      valueFormatter: _signedCompact,
    );
  }
}

/// Editor for a new desk key. It collects a label and the scopes to grant —
/// nothing else — because the secret itself is minted by the backend and shown
/// exactly once.
class _KeySheet extends StatefulWidget {
  const _KeySheet({required this.catalogue, required this.takenLabels});

  /// Scopes the plan allows, with the copy that explains each one.
  final List<({String scope, String description})> catalogue;

  /// Lower-cased labels already in use, so two keys can never share a name.
  final Set<String> takenLabels;

  @override
  State<_KeySheet> createState() => _KeySheetState();
}

class _KeySheetState extends State<_KeySheet> {
  final TextEditingController _label = TextEditingController();
  final Set<String> _scopes = <String>{};
  bool _touched = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  String get _value => _label.text.trim();

  String? get _error {
    if (_value.isEmpty) return 'Name the key after the system that will use it';
    if (widget.takenLabels.contains(_value.toLowerCase())) {
      return 'A key with that name already exists';
    }
    return null;
  }

  bool get _canSave => _error == null && _scopes.isNotEmpty;

  void _toggle(String scope, bool granted) {
    setState(() {
      if (granted) {
        _scopes.add(scope);
      } else {
        _scopes.remove(scope);
      }
    });
  }

  /// Emits the draft in catalogue order rather than tap order, so two keys
  /// granted the same scopes always read identically.
  void _submit() {
    setState(() => _touched = true);
    if (!_canSave) return;
    Navigator.of(context).pop((
      label: _value,
      scopes: <String>[
        for (final ({String description, String scope}) entry
            in widget.catalogue)
          if (_scopes.contains(entry.scope)) entry.scope,
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String? error = _touched ? _error : null;
    return UiDialog(
      title: 'Create a desk key',
      description:
          'The secret is shown once at creation — only a masked reference is '
          'stored afterwards.',
      icon: Icons.vpn_key_rounded,
      content: Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              UiField(
                label: 'Key name',
                required: true,
                error: error,
                helper: error == null
                    ? 'Shown in the audit trail whenever the key is used.'
                    : null,
                child: UiInput(
                  controller: _label,
                  hintText: 'Risk exporter',
                  autofocus: true,
                  error: error != null,
                  maxLength: 40,
                  onChanged: (String _) => setState(() => _touched = true),
                  onSubmitted: (String _) => _submit(),
                ),
              ),
              UiGap.v(theme.spacing.lg),
              const UiLabel(
                text: 'Scopes',
                required: true,
                helper: 'Grant the least a caller needs.',
              ),
              UiGap.v(theme.spacing.sm),
              for (final ({String description, String scope}) entry
                  in widget.catalogue)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: context.sp(theme.spacing.sm),
                  ),
                  child: UiSwitch(
                    value: _scopes.contains(entry.scope),
                    label: entry.scope,
                    description: entry.description,
                    asCard: true,
                    onChanged: (bool granted) => _toggle(entry.scope, granted),
                  ),
                ),
              if (_touched && _scopes.isEmpty)
                const UiCallout(
                  title: 'Pick at least one scope',
                  message: 'A key with no scopes cannot authenticate anything.',
                  intent: UiIntent.warning,
                  icon: Icons.lock_outline_rounded,
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        UiButton(
          label: 'Cancel',
          variant: UiVariant.secondary,
          expandOnMobile: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
        UiButton(
          label: 'Create key',
          leadingIcon: Icons.vpn_key_rounded,
          expandOnMobile: false,
          onPressed: _canSave ? _submit : null,
        ),
      ],
    );
  }
}
