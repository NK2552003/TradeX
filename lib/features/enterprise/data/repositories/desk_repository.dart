import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_application_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';

/// A configurable desk-wide risk guardrail.
@immutable
class RiskLimit {
  const RiskLimit({
    required this.id,
    required this.label,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.used,
    this.enabled = true,
  });

  final String id;
  final String label;
  final String description;
  final double value;
  final double min;
  final double max;

  /// Smallest increment the desk allows for this limit, so every editor snaps
  /// to values the backend will accept.
  final double step;
  final String unit;
  final double used;
  final bool enabled;

  double get ratio => value <= 0 ? 0 : (used / value).clamp(0, 1).toDouble();
  bool get breached => enabled && used >= value;

  /// Slider stops between [min] and [max] at [step] intervals.
  int get divisions => step <= 0 ? 1 : ((max - min) / step).round().clamp(1, 400);

  /// Formats a value in this limit's own unit so no call site has to guess.
  String format(double raw) => switch (unit) {
    '₹' => AppTokens.money(raw),
    '%' => AppTokens.percent(raw),
    _ =>
      '${raw == raw.roundToDouble() ? raw.toStringAsFixed(0) : raw.toStringAsFixed(1)}$unit',
  };

  RiskLimit copyWith({double? value, bool? enabled}) => RiskLimit(
    id: id,
    label: label,
    description: description,
    value: value ?? this.value,
    min: min,
    max: max,
    step: step,
    unit: unit,
    used: used,
    enabled: enabled ?? this.enabled,
  );
}

/// Aggregated desk analytics for the admin console.
@immutable
class DeskSnapshot {
  const DeskSnapshot({
    required this.stats,
    required this.equity,
    required this.bySeat,
    required this.byStrategy,
    required this.days,
    required this.members,
    required this.recentAudit,
    required this.usage,
    required this.breachedLimits,
    required this.pendingAffiliates,
    required this.seatsUsed,
    required this.seatLicences,
    required this.idleSeatDays,
  });

  final List<AppStat> stats;
  final List<AppSeriesPoint> equity;
  final List<UiBarListItem> bySeat;
  final List<UiBarListItem> byStrategy;
  final List<AppDayPnl> days;
  final List<AppTeamMember> members;
  final List<AppAuditEntry> recentAudit;
  final List<AppUsageMetric> usage;
  final List<RiskLimit> breachedLimits;
  final int pendingAffiliates;

  /// Seats consumed by anyone who is not suspended.
  final int seatsUsed;

  /// Seats the current plan is licensed for.
  final int seatLicences;

  /// Desk policy for how long a seat may stay idle before the console suggests
  /// reclaiming it.
  final int idleSeatDays;

  int get seatsLeft => (seatLicences - seatsUsed).clamp(0, seatLicences);
}

/// One seat's contribution across an analytics window, so the console can rank
/// seats without re-deriving anything in the UI layer.
@immutable
class DeskSeatPerformance {
  const DeskSeatPerformance({
    required this.member,
    required this.trades,
    required this.netPnl,
    required this.winRate,
    required this.bestTrade,
    required this.worstTrade,
    required this.avgRMultiple,
    required this.share,
  });

  final AppTeamMember member;
  final int trades;
  final double netPnl;

  /// Percentage of this seat's closed trades that were winners.
  final double winRate;
  final double bestTrade;
  final double worstTrade;

  /// Mean R multiple across the trades that recorded one.
  final double avgRMultiple;

  /// How much of the desk's total movement this seat is responsible for, as a
  /// percentage of the summed absolute contributions.
  final double share;
}

/// Everything the desk analytics surface renders, for one rolling window.
@immutable
class DeskAnalytics {
  const DeskAnalytics({
    required this.windowDays,
    required this.stats,
    required this.equity,
    required this.days,
    required this.bySeat,
    required this.byStrategy,
    required this.bySymbol,
    required this.outcomes,
    required this.sessions,
    required this.seats,
    required this.usage,
    required this.tradedDays,
    required this.greenDays,
    this.bestDay,
    this.worstDay,
  });

  /// Length of the window these numbers cover, echoed back so the UI never has
  /// to remember what it asked for.
  final int windowDays;
  final List<AppStat> stats;
  final List<AppSeriesPoint> equity;
  final List<AppDayPnl> days;
  final List<UiBarListItem> bySeat;
  final List<UiBarListItem> byStrategy;
  final List<UiBarListItem> bySymbol;

  /// Closed-trade counts and P/L per outcome, for the result-mix bar.
  final List<({AppOutcome outcome, int count, double pnl})> outcomes;

  /// P/L grouped by the part of the session a trade was opened in.
  final List<UiBarListItem> sessions;
  final List<DeskSeatPerformance> seats;
  final List<AppUsageMetric> usage;

  /// Days in the window that recorded at least one trade.
  final int tradedDays;
  final int greenDays;
  final AppDayPnl? bestDay;
  final AppDayPnl? worstDay;

  double get greenDayRate => tradedDays == 0 ? 0 : greenDays / tradedDays * 100;
}

abstract class DeskRepository {
  Future<DeskSnapshot> getSnapshot();

  /// Desk performance over the last [windowDays] days. Every derived figure is
  /// computed here so the analytics screen only has to lay them out.
  Future<DeskAnalytics> getAnalytics({int windowDays});
  Future<List<AppTeamMember>> getMembers({
    String? query,
    AppTeamRole? role,
    AppMemberStatus? status,
  });
  Future<AppTeamMember> inviteMember(String email, AppTeamRole role);
  Future<AppTeamMember> changeRole(String memberId, AppTeamRole role);
  Future<AppTeamMember> setStatus(String memberId, AppMemberStatus status);
  Future<void> removeMember(String memberId);
  Future<List<AppAuditEntry>> getAuditLog({
    String? query,
    String? actor,
    DateTime? from,
    DateTime? to,
  });
  Future<List<String>> getAuditActors();

  /// How long the desk's plan keeps audit entries, surfaced so the console can
  /// state the retention window instead of implying it is forever.
  Future<int> getAuditRetentionDays();

  /// Exports the entries matching the same filters the caller is showing, so a
  /// download never contains more or less than what is on screen.
  Future<String> exportAuditLog({
    String? query,
    String? actor,
    DateTime? from,
    DateTime? to,
  });
  Future<List<RiskLimit>> getRiskLimits();
  Future<RiskLimit> saveRiskLimit(String id, {double? value, bool? enabled});
  Future<List<AppApiKey>> getApiKeys();

  /// Scopes a new key may be granted, with the copy that explains each one.
  Future<List<({String scope, String description})>> getApiScopes();
  Future<AppApiKey> createApiKey(String label, List<String> scopes);
  Future<void> revokeApiKey(String id);
  Future<List<AppUsageMetric>> getUsage();
  Future<List<UiBarListItem>> getSeatActivity();
}

class DeskRepositoryImpl implements DeskRepository {
  DeskRepositoryImpl({
    DemoDataSource? source,
    AffiliateApplicationRepository? applications,
  }) : _source = source ?? DemoDataSource.instance,
       _applications =
           applications ?? AffiliateApplicationRepositoryImpl.instance {
    _members = List<AppTeamMember>.from(_source.teamMembers());
    _audit = List<AppAuditEntry>.from(_source.auditLog());
    _keys = List<AppApiKey>.from(_source.apiKeys());
    _limits = _seedLimits();
  }

  final DemoDataSource _source;

  /// The desk console surfaces the affiliate review queue, so the count comes
  /// from the same repository the review screen uses rather than a constant.
  final AffiliateApplicationRepository _applications;
  late List<AppTeamMember> _members;
  late List<AppAuditEntry> _audit;
  late List<AppApiKey> _keys;
  late List<RiskLimit> _limits;

  List<RiskLimit> _seedLimits() {
    final List<AppTrade> trades = _source.trades();
    final double dayLoss = _source
        .dayPnl(days: 1)
        .fold<double>(0, (double sum, AppDayPnl d) => sum + d.pnl);
    return <RiskLimit>[
      RiskLimit(
        id: 'daily_loss',
        label: 'Daily loss cap',
        description: 'Trading is locked for the day once this is hit.',
        value: _source.dailyLossCap,
        min: 5000,
        max: 200000,
        step: 1000,
        unit: '₹',
        used: dayLoss < 0 ? dayLoss.abs() : 0,
      ),
      RiskLimit(
        id: 'per_trade_risk',
        label: 'Risk per trade',
        description: 'Maximum account percentage at risk on one entry.',
        value: _source.riskPerTradePercent,
        min: 0.25,
        max: 5,
        step: 0.25,
        unit: '%',
        used: 0.8,
      ),
      RiskLimit(
        id: 'open_positions',
        label: 'Concurrent positions',
        description: 'Caps how many positions a seat can hold at once.',
        value: 5,
        min: 1,
        max: 20,
        step: 1,
        unit: '',
        used: trades
            .where((AppTrade t) => t.outcome == AppOutcome.open)
            .length
            .toDouble(),
      ),
      RiskLimit(
        id: 'consecutive_losses',
        label: 'Consecutive losses',
        description: 'Forces a cool-off after this many losses in a row.',
        value: 3,
        min: 2,
        max: 10,
        step: 1,
        unit: '',
        used: 2,
      ),
      RiskLimit(
        id: 'leverage',
        label: 'Maximum leverage',
        description: 'Hard ceiling applied across all desk seats.',
        value: 4,
        min: 1,
        max: 20,
        step: 0.5,
        unit: '×',
        used: 2.4,
        enabled: false,
      ),
    ];
  }

  AppTeamMember _copy(
    AppTeamMember source, {
    AppTeamRole? role,
    AppMemberStatus? status,
  }) => AppTeamMember(
    id: source.id,
    name: source.name,
    email: source.email,
    role: role ?? source.role,
    status: status ?? source.status,
    avatarUrl: source.avatarUrl,
    lastActiveAt: source.lastActiveAt,
  );

  void _record(String action, {String? target}) {
    _audit = <AppAuditEntry>[
      AppAuditEntry(
        id: 'aud_${DateTime.now().microsecondsSinceEpoch}',
        actor: _members.first.email,
        action: action,
        at: DateTime.now(),
        target: target,
        ip: '10.0.0.1',
      ),
      ..._audit,
    ];
  }

  @override
  Future<DeskSnapshot> getSnapshot() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final List<AppTrade> trades = _source.trades();
    final List<AppTrade> closed = trades
        .where((AppTrade t) => t.outcome != AppOutcome.open)
        .toList(growable: false);
    final double net = closed.fold<double>(
      0,
      (double sum, AppTrade t) => sum + t.pnl,
    );
    final int wins = closed
        .where((AppTrade t) => t.outcome == AppOutcome.win)
        .length;
    final List<AppStrategy> strategies = _source.strategies();
    final int licences = _source.deskSeatLicences;
    final int seatsUsed = _members
        .where((AppTeamMember m) => m.status != AppMemberStatus.suspended)
        .length;
    final List<AffiliateApplicationModel> applications = await _applications
        .listApplications();
    final int pendingAffiliates = applications
        .where(
          (AffiliateApplicationModel a) =>
              a.status == AffiliateApplicationStatus.pending,
        )
        .length;

    return DeskSnapshot(
      stats: <AppStat>[
        AppStat(
          label: 'Desk P/L',
          value: net,
          delta: net * 0.06,
          icon: Icons.account_balance_rounded,
          formatter: AppTokens.signedMoney,
        ),
        AppStat(
          label: 'Active seats',
          value: _members
              .where((AppTeamMember m) => m.status == AppMemberStatus.active)
              .length,
          icon: Icons.groups_rounded,
          suffix: ' of $licences',
          formatter: (num v) => v.toStringAsFixed(0),
        ),
        AppStat(
          label: 'Desk win rate',
          value: closed.isEmpty ? 0 : wins / closed.length * 100,
          icon: Icons.percent_rounded,
          formatter: AppTokens.percent,
        ),
        AppStat(
          label: 'Open exposure',
          value: trades
              .where((AppTrade t) => t.outcome == AppOutcome.open)
              .length,
          icon: Icons.layers_outlined,
          suffix: ' positions',
          formatter: (num v) => v.toStringAsFixed(0),
        ),
      ],
      equity: _source.equitySeries(),
      bySeat: await getSeatActivity(),
      byStrategy: <UiBarListItem>[
        for (final AppStrategy s in strategies.take(6))
          UiBarListItem(label: s.name, value: s.netPnl),
      ],
      days: _source.dayPnl(),
      members: _members.take(6).toList(growable: false),
      recentAudit: _audit.take(6).toList(growable: false),
      usage: _source.usageMetrics(),
      breachedLimits: _limits
          .where((RiskLimit l) => l.breached)
          .toList(growable: false),
      pendingAffiliates: pendingAffiliates,
      seatsUsed: seatsUsed,
      seatLicences: licences,
      idleSeatDays: _source.deskIdleSeatDays,
    );
  }

  @override
  Future<List<AppTeamMember>> getMembers({
    String? query,
    AppTeamRole? role,
    AppMemberStatus? status,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final String needle = (query ?? '').trim().toLowerCase();
    return _members.where((AppTeamMember m) {
      if (role != null && m.role != role) return false;
      if (status != null && m.status != status) return false;
      if (needle.isEmpty) return true;
      return m.name.toLowerCase().contains(needle) ||
          m.email.toLowerCase().contains(needle);
    }).toList();
  }

  @override
  Future<AppTeamMember> inviteMember(String email, AppTeamRole role) async {
    await Future<void>.delayed(const Duration(milliseconds: 480));
    final String handle = email.split('@').first;
    final AppTeamMember member = AppTeamMember(
      id: 'mem_${DateTime.now().microsecondsSinceEpoch}',
      name: handle.isEmpty
          ? email
          : '${handle[0].toUpperCase()}${handle.substring(1)}',
      email: email,
      role: role,
      status: AppMemberStatus.invited,
    );
    _members = <AppTeamMember>[..._members, member];
    _record('Invited a team member', target: email);
    return member;
  }

  @override
  Future<AppTeamMember> changeRole(String memberId, AppTeamRole role) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final int index = _members.indexWhere(
      (AppTeamMember m) => m.id == memberId,
    );
    if (index < 0) throw StateError('Member $memberId not found');
    final AppTeamMember updated = _copy(_members[index], role: role);
    _members[index] = updated;
    _record('Changed a member role', target: updated.email);
    return updated;
  }

  @override
  Future<AppTeamMember> setStatus(
    String memberId,
    AppMemberStatus status,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final int index = _members.indexWhere(
      (AppTeamMember m) => m.id == memberId,
    );
    if (index < 0) throw StateError('Member $memberId not found');
    final AppTeamMember updated = _copy(_members[index], status: status);
    _members[index] = updated;
    _record('Updated a member status', target: updated.email);
    return updated;
  }

  @override
  Future<void> removeMember(String memberId) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final AppTeamMember? removed = _members
        .where((AppTeamMember m) => m.id == memberId)
        .firstOrNull;
    _members = _members
        .where((AppTeamMember m) => m.id != memberId)
        .toList();
    if (removed != null) {
      _record('Removed a team member', target: removed.email);
    }
  }

  @override
  Future<List<AppAuditEntry>> getAuditLog({
    String? query,
    String? actor,
    DateTime? from,
    DateTime? to,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final String needle = (query ?? '').trim().toLowerCase();
    return _audit.where((AppAuditEntry e) {
      if (actor != null && e.actor != actor) return false;
      if (from != null && e.at.isBefore(from)) return false;
      if (to != null && e.at.isAfter(to)) return false;
      if (needle.isEmpty) return true;
      return e.action.toLowerCase().contains(needle) ||
          e.actor.toLowerCase().contains(needle) ||
          (e.target ?? '').toLowerCase().contains(needle);
    }).toList();
  }

  @override
  Future<List<String>> getAuditActors() async =>
      _audit.map((AppAuditEntry e) => e.actor).toSet().toList()..sort();

  @override
  Future<int> getAuditRetentionDays() async => _source.deskAuditRetentionDays;

  @override
  Future<String> exportAuditLog({
    String? query,
    String? actor,
    DateTime? from,
    DateTime? to,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 620));
    final List<AppAuditEntry> rows = await getAuditLog(
      query: query,
      actor: actor,
      from: from,
      to: to,
    );
    _record('Downloaded audit log', target: '${rows.length} entries');
    return 'tradex_audit_${DateTime.now().toIso8601String().split('T').first}.csv';
  }

  @override
  Future<List<RiskLimit>> getRiskLimits() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<RiskLimit>.from(_limits);
  }

  @override
  Future<RiskLimit> saveRiskLimit(
    String id, {
    double? value,
    bool? enabled,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final int index = _limits.indexWhere((RiskLimit l) => l.id == id);
    if (index < 0) throw StateError('Limit $id not found');
    final RiskLimit updated = _limits[index].copyWith(
      value: value,
      enabled: enabled,
    );
    _limits[index] = updated;
    _record('Updated risk limits', target: updated.label);
    return updated;
  }

  @override
  Future<List<AppApiKey>> getApiKeys() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<AppApiKey>.from(_keys);
  }

  @override
  Future<List<({String scope, String description})>> getApiScopes() async =>
      _source.apiScopes();

  @override
  Future<AppApiKey> createApiKey(String label, List<String> scopes) async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
    final AppApiKey key = AppApiKey(
      id: 'key_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      maskedKey:
          'tdx_live_••••••••${DateTime.now().microsecondsSinceEpoch % 10000}',
      createdAt: DateTime.now(),
      scopes: scopes,
    );
    _keys = <AppApiKey>[key, ..._keys];
    _record('Created an API key', target: label);
    return key;
  }

  @override
  Future<void> revokeApiKey(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final int index = _keys.indexWhere((AppApiKey k) => k.id == id);
    if (index < 0) return;
    final AppApiKey current = _keys[index];
    _keys[index] = AppApiKey(
      id: current.id,
      label: current.label,
      maskedKey: current.maskedKey,
      createdAt: current.createdAt,
      lastUsedAt: current.lastUsedAt,
      revoked: true,
      scopes: current.scopes,
    );
    _record('Revoked an API key', target: current.label);
  }

  @override
  Future<List<AppUsageMetric>> getUsage() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _source.usageMetrics();
  }

  @override
  Future<DeskAnalytics> getAnalytics({int windowDays = 30}) async {
    await Future<void>.delayed(const Duration(milliseconds: 360));
    final List<AppTrade> closed = _closedTrades(windowDays: windowDays);
    final List<AppDayPnl> days = _source.dayPnl(days: windowDays);
    final Map<String, List<AppTrade>> bySeatId = _tradesBySeat(closed);
    final double net = _net(closed);
    final double grossWin = closed
        .where((AppTrade t) => t.pnl > 0)
        .fold<double>(0, (double sum, AppTrade t) => sum + t.pnl);
    final double grossLoss = closed
        .where((AppTrade t) => t.pnl < 0)
        .fold<double>(0, (double sum, AppTrade t) => sum + t.pnl.abs());
    final int wins = closed
        .where((AppTrade t) => t.outcome == AppOutcome.win)
        .length;
    final List<double> rMultiples = closed
        .map((AppTrade t) => t.rMultiple)
        .whereType<double>()
        .toList(growable: false);
    final double avgR = rMultiples.isEmpty
        ? 0
        : rMultiples.reduce((double a, double b) => a + b) / rMultiples.length;
    final List<AppDayPnl> traded = days
        .where((AppDayPnl d) => d.trades > 0)
        .toList(growable: false);

    return DeskAnalytics(
      windowDays: windowDays,
      stats: _analyticsStats(
        net: net,
        closed: closed.length,
        wins: wins,
        grossWin: grossWin,
        grossLoss: grossLoss,
        avgR: avgR,
        tradedDays: traded.length,
      ),
      equity: _source.equitySeries(points: windowDays),
      days: days,
      bySeat: await getSeatActivity(),
      byStrategy: _rank(closed, (AppTrade t) => t.strategy ?? 'Unassigned'),
      bySymbol: _rank(closed, (AppTrade t) => t.ticker, limit: 8),
      outcomes: _outcomeMix(closed),
      sessions: _sessionMix(closed),
      seats: _seatPerformance(bySeatId),
      usage: _source.usageMetrics(),
      tradedDays: traded.length,
      greenDays: traded.where((AppDayPnl d) => d.pnl > 0).length,
      bestDay: traded.isEmpty
          ? null
          : traded.reduce((AppDayPnl a, AppDayPnl b) => a.pnl >= b.pnl ? a : b),
      worstDay: traded.isEmpty
          ? null
          : traded.reduce((AppDayPnl a, AppDayPnl b) => a.pnl <= b.pnl ? a : b),
    );
  }
  /// Headline analytics figures. Kept beside the query so the console cannot
  /// disagree with the numbers behind it.
  List<AppStat> _analyticsStats({
    required double net,
    required int closed,
    required int wins,
    required double grossWin,
    required double grossLoss,
    required double avgR,
    required int tradedDays,
  }) => <AppStat>[
    AppStat(
      label: 'Net P/L',
      value: net,
      icon: Icons.account_balance_wallet_outlined,
      formatter: AppTokens.signedMoney,
    ),
    AppStat(
      label: 'Win rate',
      value: closed == 0 ? 0 : wins / closed * 100,
      icon: Icons.percent_rounded,
      formatter: AppTokens.percent,
    ),
    AppStat(
      label: 'Profit factor',
      value: grossLoss == 0 ? grossWin : grossWin / grossLoss,
      icon: Icons.balance_rounded,
      formatter: (num v) => v.toStringAsFixed(2),
    ),
    AppStat(
      label: 'Expectancy',
      value: avgR,
      icon: Icons.trending_up_rounded,
      formatter: AppTokens.rr,
    ),
    AppStat(
      label: 'Closed trades',
      value: closed,
      icon: Icons.receipt_long_outlined,
      formatter: (num v) => v.toStringAsFixed(0),
    ),
    AppStat(
      label: 'Trades per active day',
      value: tradedDays == 0 ? 0 : closed / tradedDays,
      icon: Icons.today_outlined,
      formatter: (num v) => v.toStringAsFixed(1),
    ),
  ];
  /// Net P/L per bucket, biggest contribution first.
  List<UiBarListItem> _rank(
    List<AppTrade> closed,
    String Function(AppTrade trade) key, {
    int? limit,
  }) {
    final Map<String, double> totals = <String, double>{};
    for (final AppTrade trade in closed) {
      final String bucket = key(trade);
      totals[bucket] = (totals[bucket] ?? 0) + trade.pnl;
    }
    final List<UiBarListItem> items = <UiBarListItem>[
      for (final MapEntry<String, double> e in totals.entries)
        UiBarListItem(label: e.key, value: e.value),
    ]..sort(
      (UiBarListItem a, UiBarListItem b) =>
          b.value.abs().compareTo(a.value.abs()),
    );
    return limit == null || items.length <= limit
        ? items
        : items.take(limit).toList(growable: false);
  }

  List<({AppOutcome outcome, int count, double pnl})> _outcomeMix(
    List<AppTrade> closed,
  ) => <({AppOutcome outcome, int count, double pnl})>[
    for (final AppOutcome outcome in AppOutcome.values)
      if (outcome != AppOutcome.open)
        (
          outcome: outcome,
          count: closed.where((AppTrade t) => t.outcome == outcome).length,
          pnl: _net(closed.where((AppTrade t) => t.outcome == outcome)),
        ),
  ];
  /// P/L by the part of the session a trade was opened in, using the venue's
  /// own session blocks rather than boundaries invented here.
  List<UiBarListItem> _sessionMix(List<AppTrade> closed) {
    final List<({int fromHour, int toHour, String label})> blocks = _source
        .sessionBlocks();
    return <UiBarListItem>[
      for (final ({int fromHour, int toHour, String label}) block in blocks)
        UiBarListItem(
          label: block.label,
          value: _net(
            closed.where(
              (AppTrade t) =>
                  t.openedAt.hour >= block.fromHour &&
                  t.openedAt.hour < block.toHour,
            ),
          ),
        ),
    ];
  }
  /// Per-seat performance, ranked by contribution. Shares are expressed against
  /// the summed absolute movement so a losing seat still reads as significant.
  List<DeskSeatPerformance> _seatPerformance(
    Map<String, List<AppTrade>> bySeatId,
  ) {
    final double totalAbs = bySeatId.values.fold<double>(
      0,
      (double sum, List<AppTrade> trades) => sum + _net(trades).abs(),
    );
    final List<DeskSeatPerformance> rows = <DeskSeatPerformance>[
      for (final AppTeamMember seat in _activeSeats)
        _seatRow(seat, bySeatId[seat.id] ?? const <AppTrade>[], totalAbs),
    ]..sort(
      (DeskSeatPerformance a, DeskSeatPerformance b) =>
          b.netPnl.compareTo(a.netPnl),
    );
    return rows;
  }

  DeskSeatPerformance _seatRow(
    AppTeamMember seat,
    List<AppTrade> trades,
    double totalAbs,
  ) {
    final double net = _net(trades);
    final List<double> rMultiples = trades
        .map((AppTrade t) => t.rMultiple)
        .whereType<double>()
        .toList(growable: false);
    final List<double> pnls = trades
        .map((AppTrade t) => t.pnl)
        .toList(growable: false);
    return DeskSeatPerformance(
      member: seat,
      trades: trades.length,
      netPnl: net,
      winRate: trades.isEmpty
          ? 0
          : trades.where((AppTrade t) => t.outcome == AppOutcome.win).length /
                trades.length *
                100,
      bestTrade: pnls.isEmpty
          ? 0
          : pnls.reduce((double a, double b) => a >= b ? a : b),
      worstTrade: pnls.isEmpty
          ? 0
          : pnls.reduce((double a, double b) => a <= b ? a : b),
      avgRMultiple: rMultiples.isEmpty
          ? 0
          : rMultiples.reduce((double a, double b) => a + b) /
                rMultiples.length,
      share: totalAbs == 0 ? 0 : net.abs() / totalAbs * 100,
    );
  }

  @override
  Future<List<UiBarListItem>> getSeatActivity() async {
    final Map<String, List<AppTrade>> bySeat = _tradesBySeat(_closedTrades());
    return <UiBarListItem>[
      for (final AppTeamMember seat in _activeSeats)
        UiBarListItem(label: seat.name, value: _net(bySeat[seat.id]!)),
    ]..sort(
      (UiBarListItem a, UiBarListItem b) => b.value.compareTo(a.value),
    );
  }

  List<AppTeamMember> get _activeSeats => _members
      .where((AppTeamMember m) => m.status == AppMemberStatus.active)
      .toList(growable: false);

  /// Closed trades, optionally limited to the last [windowDays] days.
  List<AppTrade> _closedTrades({int? windowDays}) {
    final DateTime? from = windowDays == null
        ? null
        : DateTime.now().subtract(Duration(days: windowDays));
    return _source.trades().where((AppTrade t) {
      if (t.outcome == AppOutcome.open) return false;
      if (from == null) return true;
      return (t.closedAt ?? t.openedAt).isAfter(from);
    }).toList(growable: false);
  }

  /// Attribution of closed trades to active seats. The demo backend does not
  /// stamp an owner on a trade, so the split lives in exactly one place and
  /// every desk surface reads the same answer.
  Map<String, List<AppTrade>> _tradesBySeat(List<AppTrade> closed) {
    final List<AppTeamMember> seats = _activeSeats;
    final Map<String, List<AppTrade>> byId = <String, List<AppTrade>>{
      for (final AppTeamMember seat in seats) seat.id: <AppTrade>[],
    };
    if (seats.isEmpty) return byId;
    for (int i = 0; i < closed.length; i++) {
      byId[seats[i % seats.length].id]!.add(closed[i]);
    }
    return byId;
  }

  double _net(Iterable<AppTrade> trades) =>
      trades.fold<double>(0, (double sum, AppTrade t) => sum + t.pnl);
}
