import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/enterprise/data/repositories/desk_repository.dart';

/// Admin risk controls: every desk-wide guardrail with its live consumption,
/// an editor that snaps to the increments the backend accepts, and a trail of
/// who changed what. Edits are staged locally so an admin can review the whole
/// set before committing.
class DeskRiskPage extends StatefulWidget {
  const DeskRiskPage({
    super.key,
    this.repository,
    this.onOpenAudit,
    this.onOpenTeam,
  });

  final DeskRepository? repository;
  final VoidCallback? onOpenAudit;
  final VoidCallback? onOpenTeam;

  @override
  State<DeskRiskPage> createState() => _DeskRiskPageState();
}

class _DeskRiskPageState extends State<DeskRiskPage> {
  late final DeskRepository _repo = widget.repository ?? DeskRepositoryImpl();

  List<RiskLimit> _limits = const <RiskLimit>[];
  List<AppAuditEntry> _history = const <AppAuditEntry>[];
  bool _loading = true;

  /// Staged slider values, keyed by limit id. A limit is only dirty while it has
  /// an entry here, which keeps "unsaved changes" honest.
  final Map<String, double> _drafts = <String, double>{};

  /// Ids currently being written, so each card can show its own spinner.
  final Set<String> _saving = <String>{};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }
  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _repo.getRiskLimits(),
      _repo.getAuditLog(query: 'risk'),
    ]);
    if (!mounted) return;
    setState(() {
      _limits = results[0]! as List<RiskLimit>;
      _history = results[1]! as List<AppAuditEntry>;
      _loading = false;
    });
  }

  /// Risk edits are audited, so the trail is re-read after every write.
  Future<void> _refreshHistory() async {
    final List<AppAuditEntry> entries = await _repo.getAuditLog(query: 'risk');
    if (!mounted) return;
    setState(() => _history = entries);
  }

  double _valueOf(RiskLimit limit) => _drafts[limit.id] ?? limit.value;

  bool _isDirty(RiskLimit limit) => _drafts.containsKey(limit.id);

  int get _dirtyCount => _drafts.length;

  List<RiskLimit> get _breached =>
      _limits.where((RiskLimit l) => l.breached).toList(growable: false);

  int get _enabledCount => _limits.where((RiskLimit l) => l.enabled).length;

  void _stage(RiskLimit limit, double value) {
    setState(() {
      if (value == limit.value) {
        _drafts.remove(limit.id);
      } else {
        _drafts[limit.id] = value;
      }
    });
  }

  void _replace(RiskLimit updated) {
    final int index = _limits.indexWhere((RiskLimit l) => l.id == updated.id);
    if (index < 0) return;
    final List<RiskLimit> next = List<RiskLimit>.from(_limits);
    next[index] = updated;
    _limits = next;
  }
  Future<void> _save(RiskLimit limit) async {
    final double? staged = _drafts[limit.id];
    if (staged == null) return;
    setState(() => _saving.add(limit.id));
    final RiskLimit updated = await _repo.saveRiskLimit(
      limit.id,
      value: staged,
    );
    if (!mounted) return;
    setState(() {
      _replace(updated);
      _drafts.remove(limit.id);
      _saving.remove(limit.id);
    });
    await _refreshHistory();
    if (!mounted) return;
    UiToast.show(
      context,
      title: '${updated.label} saved',
      message: 'Now ${updated.format(updated.value)} for every desk seat.',
      intent: updated.breached ? UiIntent.warning : UiIntent.success,
    );
  }

  Future<void> _saveAll() async {
    final Map<String, double> staged = Map<String, double>.from(_drafts);
    if (staged.isEmpty) return;
    setState(() => _saving.addAll(staged.keys));
    for (final MapEntry<String, double> entry in staged.entries) {
      final RiskLimit updated = await _repo.saveRiskLimit(
        entry.key,
        value: entry.value,
      );
      if (!mounted) return;
      setState(() {
        _replace(updated);
        _drafts.remove(entry.key);
        _saving.remove(entry.key);
      });
    }
    await _refreshHistory();
    if (!mounted) return;
    UiToast.show(
      context,
      title: '${staged.length} limit${staged.length == 1 ? '' : 's'} saved',
      message: 'The desk is trading against the new guardrails.',
      intent: UiIntent.success,
    );
  }
  Future<void> _toggle(RiskLimit limit, bool enabled) async {
    if (!enabled) {
      final bool confirmed = await UiDialog.confirm(
        context,
        title: 'Turn off ${limit.label.toLowerCase()}?',
        description:
            'Nothing will stop a seat from crossing ${limit.format(limit.value)} '
            'until this is switched back on. The change is audited.',
        confirmLabel: 'Turn off',
        confirmVariant: UiVariant.destructive,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _saving.add(limit.id));
    final RiskLimit updated = await _repo.saveRiskLimit(
      limit.id,
      enabled: enabled,
    );
    if (!mounted) return;
    setState(() {
      _replace(updated);
      _saving.remove(limit.id);
    });
    await _refreshHistory();
    if (!mounted) return;
    UiToast.show(
      context,
      title: '${updated.label} ${enabled ? 'enforced' : 'not enforced'}',
      message: enabled
          ? 'Breaches will lock trading again.'
          : 'Seats can trade past this limit until it is re-enabled.',
      intent: enabled ? UiIntent.success : UiIntent.warning,
    );
  }

  void _discard() => setState(_drafts.clear);

  String get _subtitle {
    if (_loading) return 'Reading the desk guardrails…';
    final List<String> parts = <String>[
      '$_enabledCount of ${_limits.length} enforced',
      if (_breached.isEmpty)
        'none breached'
      else
        '${_breached.length} breached right now',
      if (_dirtyCount > 0) '$_dirtyCount unsaved',
    ];
    return parts.join(' · ');
  }
  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return AppPageBlock(
      title: 'Risk controls',
      subtitle: _subtitle,
      actions: <Widget>[
        UiButton(
          label: _dirtyCount == 0
              ? 'Save changes'
              : 'Save $_dirtyCount change${_dirtyCount == 1 ? '' : 's'}',
          leadingIcon: Icons.save_outlined,
          size: UiSize.sm,
          loading: _saving.isNotEmpty,
          onPressed: _dirtyCount == 0 ? null : _saveAll,
        ),
        UiButton(
          label: 'Discard',
          variant: UiVariant.secondary,
          leadingIcon: Icons.undo_rounded,
          size: UiSize.sm,
          hideLabelOnMobile: true,
          onPressed: _dirtyCount == 0 ? null : _discard,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_breached.isNotEmpty) ...<Widget>[
            AppFadeIn(
              child: UiCallout(
                title: _breached.length == 1
                    ? '${_breached.first.label} is at its limit'
                    : '${_breached.length} limits are at their ceiling',
                message: _breached
                    .map(
                      (RiskLimit l) =>
                          '${l.label}: ${l.format(l.used)} of ${l.format(l.value)}',
                    )
                    .join(' · '),
                intent: UiIntent.danger,
                icon: Icons.gpp_maybe_outlined,
                action: UiButton(
                  label: 'Review seats',
                  size: UiSize.sm,
                  variant: UiVariant.outline,
                  expandOnMobile: false,
                  onPressed: widget.onOpenTeam,
                ),
              ),
            ),
            UiGap.v(theme.spacing.md),
          ],
          if (_dirtyCount > 0) ...<Widget>[
            AppFadeIn(delay: AppMotion.step, child: _dirtyCallout()),
            UiGap.v(theme.spacing.md),
          ],
          AppFadeIn(
            delay: AppMotion.step * 2,
            child: AppDashboardLayoutBlock(
              main: <Widget>[_limitsCard()],
              side: <Widget>[_policyCard(), _historyCard()],
            ),
          ),
        ],
      ),
    );
  }
  /// Spells out exactly which numbers are about to move, so "save" is never a
  /// blind action.
  Widget _dirtyCallout() {
    final List<RiskLimit> dirty = _limits
        .where(_isDirty)
        .toList(growable: false);
    return UiCallout(
      title: '$_dirtyCount unsaved change${_dirtyCount == 1 ? '' : 's'}',
      message: dirty
          .map(
            (RiskLimit l) =>
                '${l.label}: ${l.format(l.value)} → ${l.format(_valueOf(l))}',
          )
          .join(' · '),
      intent: UiIntent.info,
      icon: Icons.edit_outlined,
      action: UiButton(
        label: 'Save now',
        size: UiSize.sm,
        expandOnMobile: false,
        loading: _saving.isNotEmpty,
        onPressed: _saveAll,
      ),
    );
  }

  Widget _limitsCard() => UiCard(
    title: 'Desk guardrails',
    subtitle: 'Applied to every seat, including owners',
    child: UiAsyncView(
      loading: _loading,
      isEmpty: _limits.isEmpty,
      emptyTitle: 'No limits configured',
      emptyMessage: 'Add a guardrail to protect the desk from a bad session.',
      emptyIcon: Icons.shield_outlined,
      builder: (BuildContext ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < _limits.length; i++) ...<Widget>[
            if (i > 0) ...<Widget>[
              UiGap.v(ctx.ui.spacing.lg),
              const UiDivider(),
              UiGap.v(ctx.ui.spacing.lg),
            ],
            _limitEditor(_limits[i]),
          ],
        ],
      ),
    ),
  );
  Widget _limitEditor(RiskLimit limit) {
    final UiTheme theme = context.ui;
    final bool busy = _saving.contains(limit.id);
    final bool dirty = _isDirty(limit);
    final double staged = _valueOf(limit).clamp(limit.min, limit.max);
    final double usedRatio = staged <= 0
        ? 0
        : (limit.used / staged).clamp(0, 1).toDouble();
    final UiIntent usedIntent = usedRatio >= 1
        ? UiIntent.danger
        : (usedRatio >= 0.75 ? UiIntent.warning : UiIntent.success);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Wrap(
                    spacing: context.sp(theme.spacing.sm),
                    runSpacing: context.sp(theme.spacing.xs),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(limit.label, style: context.uiText.bodyStrong),
                      if (limit.breached)
                        const UiBadge(
                          label: 'Breached',
                          intent: UiIntent.danger,
                        ),
                      if (!limit.enabled)
                        const UiBadge(
                          label: 'Not enforced',
                          intent: UiIntent.neutral,
                        ),
                      if (dirty)
                        const UiBadge(label: 'Unsaved', intent: UiIntent.info),
                    ],
                  ),
                  UiGap.v(theme.spacing.xxs),
                  Text(
                    limit.description,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.md)),
            UiSwitch(
              value: limit.enabled,
              loading: busy,
              semanticLabel: 'Enforce ${limit.label}',
              onChanged: (bool value) => _toggle(limit, value),
            ),
          ],
        ),
        UiGap.v(theme.spacing.md),
        UiSlider(
          value: staged,
          min: limit.min,
          max: limit.max,
          divisions: limit.divisions,
          enabled: limit.enabled && !busy,
          showBounds: true,
          valueFormatter: (num value) => limit.format(value.toDouble()),
          intent: limit.breached ? UiIntent.danger : UiIntent.primary,
          helper: limit.enabled
              ? 'Moves in steps of ${limit.format(limit.step)}'
              : 'Turn the guardrail on to change its ceiling',
          onChanged: (double value) => _stage(limit, value),
        ),
        UiGap.v(theme.spacing.md),
        UiProgressBar(
          value: usedRatio,
          label: 'Consumed right now',
          intent: limit.enabled ? usedIntent : UiIntent.neutral,
          valueFormatter: (num _) =>
              '${limit.format(limit.used)} of ${limit.format(staged)}',
        ),
        if (dirty) ...<Widget>[
          UiGap.v(theme.spacing.md),
          Row(
            children: <Widget>[
              UiButton(
                label: 'Save ${limit.label.toLowerCase()}',
                size: UiSize.sm,
                leadingIcon: Icons.check_rounded,
                expandOnMobile: false,
                loading: busy,
                onPressed: () => _save(limit),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              UiButton(
                label: 'Reset to ${limit.format(limit.value)}',
                size: UiSize.sm,
                variant: UiVariant.ghost,
                expandOnMobile: false,
                onPressed: () => _stage(limit, limit.value),
              ),
            ],
          ),
        ],
        // __EDITOR_DONE__
      ],
    );
  }

  /// How enforcement behaves, written once so the console explains itself
  /// instead of relying on tribal knowledge.
  Widget _policyCard() => UiCard(
    title: 'How enforcement works',
    subtitle: '$_enabledCount of ${_limits.length} guardrails are live',
    child: UiAccordion(
      items: <UiAccordionItem>[
        UiAccordionItem(
          title: 'What happens at a breach',
          leadingIcon: Icons.block_rounded,
          content: _bullets(<String>[
            'New entries are rejected for the seat that crossed the line.',
            'The desk owner and the seat both get a notification.',
            'The breach is written to the audit trail with the value that tripped it.',
          ]),
        ),
        UiAccordionItem(
          title: 'Who can change a limit',
          leadingIcon: Icons.badge_outlined,
          content: _bullets(<String>[
            'Owners and admins can edit any guardrail.',
            'Analysts, members and viewers see the numbers but cannot move them.',
            'Every change records the actor, the old value and the new value.',
          ]),
        ),
        UiAccordionItem(
          title: 'Turning a guardrail off',
          leadingIcon: Icons.warning_amber_rounded,
          intent: UiIntent.warning,
          content: _bullets(<String>[
            'The limit stops blocking trades immediately.',
            'Consumption is still tracked, so you can see what it would have caught.',
            'Switching it back on re-applies the same ceiling with no re-entry needed.',
          ]),
        ),
      ],
    ),
  );
  Widget _bullets(List<String> lines) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String line in lines)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: context.sp(theme.spacing.xs)),
                  child: Icon(
                    Icons.circle,
                    size: context.sz(5),
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: Text(
                    line,
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _historyCard() => UiCard(
    title: 'Recent risk changes',
    subtitle: 'Pulled from the audit trail',
    actions: <Widget>[
      UiButton(
        label: 'Full audit log',
        variant: UiVariant.ghost,
        size: UiSize.sm,
        trailingIcon: Icons.arrow_forward_rounded,
        onPressed: widget.onOpenAudit,
      ),
    ],
    child: UiAsyncView(
      loading: _loading,
      isEmpty: _history.isEmpty,
      emptyTitle: 'No risk edits yet',
      emptyMessage: 'Changes to guardrails show up here the moment they save.',
      emptyIcon: Icons.history_rounded,
      builder: (BuildContext ctx) => UiTimeline(
        entries: <UiTimelineEntry>[
          for (final AppAuditEntry entry in _history.take(6))
            UiTimelineEntry(
              title: entry.action,
              subtitle: <String?>[entry.target, entry.actor]
                  .whereType<String>()
                  .join(' · '),
              timestamp: AppTokens.relativeTime(entry.at),
              icon: Icons.shield_outlined,
              intent: UiIntent.info,
            ),
        ],
      ),
    ),
  );
}
