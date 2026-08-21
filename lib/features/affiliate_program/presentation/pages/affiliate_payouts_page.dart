import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/affiliate_program/data/repositories/affiliate_portal_repository.dart';

/// Payout ledger and withdrawal flow. The page never decides what a partner is
/// owed — it renders the balance the repository reports and refuses requests
/// the selected rail would reject.
class AffiliatePayoutsPage extends StatefulWidget {
  const AffiliatePayoutsPage({
    super.key,
    this.repository,
    this.onOpenReferrals,
    this.onOpenSettings,
  });

  final AffiliatePortalRepository? repository;
  final VoidCallback? onOpenReferrals;
  final VoidCallback? onOpenSettings;

  @override
  State<AffiliatePayoutsPage> createState() => _AffiliatePayoutsPageState();
}

class _AffiliatePayoutsPageState extends State<AffiliatePayoutsPage> {
  late final AffiliatePortalRepository _repo =
      widget.repository ?? AffiliatePortalRepositoryImpl();

  List<Payout> _rows = const <Payout>[];
  List<PayoutMethod> _methods = const <PayoutMethod>[];
  AffiliatePortalSnapshot? _snapshot;
  PayoutStatus? _status;
  bool _loading = true;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _repo.getPayouts(),
      _repo.getPayoutMethods(),
      _repo.getSnapshot(),
    ]);
    if (!mounted) return;
    setState(() {
      _rows = results[0]! as List<Payout>;
      _methods = results[1]! as List<PayoutMethod>;
      _snapshot = results[2]! as AffiliatePortalSnapshot;
      _loading = false;
    });
  }

  double get _pending => _snapshot?.pendingBalance ?? 0;

  double get _paidOut => _rows
      .where((Payout p) => p.status == PayoutStatus.paid)
      .fold<double>(0, (double sum, Payout p) => sum + p.amount);

  double get _inFlight => _rows
      .where((Payout p) => p.status != PayoutStatus.paid)
      .fold<double>(0, (double sum, Payout p) => sum + p.amount);

  List<Payout> get _visible => _status == null
      ? _rows
      : _rows.where((Payout p) => p.status == _status).toList(growable: false);

  /// The cheapest rail a partner currently qualifies for. Used to explain why a
  /// withdrawal is blocked instead of just disabling the button.
  double get _lowestMinimum => _methods.isEmpty
      ? 0
      : _methods
            .map((PayoutMethod m) => m.minimum)
            .reduce((double a, double b) => a < b ? a : b);

  bool get _canRequest =>
      !_loading && _methods.isNotEmpty && _pending >= _lowestMinimum;

  Future<void> _requestPayout() async {
    final _PayoutRequest? request = await UiDialog.show<_PayoutRequest>(
      context,
      child: _RequestSheet(
        balance: _pending,
        methods: _methods,
      ),
    );
    if (request == null || !mounted) return;
    setState(() => _requesting = true);
    final Payout payout = await _repo.requestPayout(
      request.amount,
      request.method.label,
    );
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _repo.getPayouts(),
      _repo.getSnapshot(),
    ]);
    if (!mounted) return;
    setState(() {
      _rows = results[0]! as List<Payout>;
      _snapshot = results[1]! as AffiliatePortalSnapshot;
      _requesting = false;
    });
    UiToast.show(
      context,
      title: '${AppTokens.money(payout.amount)} requested',
      message:
          '${request.method.label} · ${request.method.eta}. You will get an '
          'email when finance releases it.',
      intent: UiIntent.success,
    );
  }

  Future<void> _copyReference(Payout payout) async {
    final String? reference = payout.reference;
    if (reference == null) return;
    await Clipboard.setData(ClipboardData(text: reference));
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Reference copied',
      message: '$reference is on your clipboard.',
      intent: UiIntent.success,
    );
  }

  @override
  Widget build(BuildContext context) => AppPageBlock(
    title: 'Payouts',
    subtitle: _loading
        ? 'Loading your balance and ledger…'
        : '${AppTokens.money(_pending)} available · '
              '${AppTokens.money(_inFlight)} in flight · '
              '${AppTokens.money(_paidOut)} paid out',
    actions: <Widget>[
      UiButton(
        label: 'Payout settings',
        leadingIcon: Icons.tune_rounded,
        variant: UiVariant.outline,
        size: UiSize.sm,
        hideLabelOnMobile: true,
        onPressed: widget.onOpenSettings,
      ),
      UiButton(
        label: 'Request payout',
        leadingIcon: Icons.account_balance_wallet_outlined,
        size: UiSize.sm,
        loading: _requesting,
        onPressed: _canRequest ? _requestPayout : null,
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppFadeIn(child: _balanceCard()),
        UiGap.v(context.ui.spacing.lg),
        AppFadeIn(
          delay: AppMotion.step,
          child: AppDashboardLayoutBlock(
            main: <Widget>[_ledgerCard()],
            side: <Widget>[_nextPayoutCard(), _methodsCard(), _rulesCard()],
          ),
        ),
      ],
    ),
  );

  /// Balance split first, because "how much can I take out right now" is the
  /// only question this page has to answer instantly.
  Widget _balanceCard() {
    final double lifetime = _snapshot?.lifetimeEarned ?? 0;
    final double progress = _lowestMinimum <= 0
        ? 1
        : (_pending / _lowestMinimum).clamp(0, 1).toDouble();
    return UiCard(
      title: 'Balance',
      subtitle: _loading
          ? 'Fetching the ledger…'
          : 'Commission clears into this balance once a referred subscription '
                'is paid',
      trailing: UiBadge(
        label: _canRequest ? 'Withdrawable' : 'Below minimum',
        intent: _canRequest ? UiIntent.success : UiIntent.warning,
        filled: true,
      ),
      actions: <Widget>[
        UiButton(
          label: 'Request payout',
          leadingIcon: Icons.north_east_rounded,
          size: UiSize.sm,
          loading: _requesting,
          onPressed: _canRequest ? _requestPayout : null,
        ),
        UiButton(
          label: 'Where it comes from',
          variant: UiVariant.ghost,
          size: UiSize.sm,
          trailingIcon: Icons.arrow_forward_rounded,
          expandOnMobile: false,
          onPressed: widget.onOpenReferrals,
        ),
      ],
      child: _balanceBody(lifetime, progress),
    );
  }

  Widget _balanceBody(double lifetime, double progress) {
    if (_loading) return UiSkeleton(height: context.sz(140));
    final List<Widget> figures = <Widget>[
      _Figure(
        label: 'Available now',
        value: AppTokens.money(_pending),
        intent: UiIntent.success,
      ),
      _Figure(
        label: 'In flight',
        value: AppTokens.money(_inFlight),
        intent: UiIntent.info,
      ),
      _Figure(
        label: 'Paid out',
        value: AppTokens.money(_paidOut),
        intent: UiIntent.neutral,
      ),
      _Figure(
        label: 'Lifetime earned',
        value: AppTokens.money(lifetime),
        intent: UiIntent.primary,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (context.uiRes.isMobile)
          Wrap(
            spacing: context.sp(context.ui.spacing.xl),
            runSpacing: context.sp(context.ui.spacing.md),
            children: figures,
          )
        else
          Row(
            children: <Widget>[
              for (final Widget figure in figures) Expanded(child: figure),
            ],
          ),
        UiGap.v(context.ui.spacing.lg),
        if (lifetime > 0)
          UiCategoryBar(
            showLegend: false,
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: _paidOut,
                label: 'Paid',
                color: context.uiColors.foregroundSubtle,
              ),
              UiCategorySegment(
                value: _inFlight,
                label: 'In flight',
                color: UiIntent.info.color(context),
              ),
              UiCategorySegment(
                value: _pending,
                label: 'Available',
                color: context.uiColors.bullish,
              ),
            ],
          ),
        if (!_canRequest && _lowestMinimum > 0) ...<Widget>[
          UiGap.v(context.ui.spacing.md),
          UiProgressBar(value: progress, intent: UiIntent.warning),
          UiGap.v(context.ui.spacing.xs),
          Text(
            '${AppTokens.money(_lowestMinimum - _pending)} to go before the '
            'lowest minimum (${AppTokens.money(_lowestMinimum)}) is met.',
            style: context.uiText.caption.copyWith(
              color: context.uiColors.foregroundMuted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _ledgerCard() => UiCard(
    title: 'Payout ledger',
    subtitle: _status == null
        ? 'Every withdrawal, newest first'
        : '${payoutStatusLabel(_status!)} withdrawals only',
    trailing: UiBadge(
      label: '${_visible.length} of ${_rows.length}',
      intent: UiIntent.neutral,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiToggleGroup<PayoutStatus?>(
          value: _status,
          expand: context.uiRes.isMobile,
          onChanged: (PayoutStatus? value) => setState(() => _status = value),
          options: <UiToggleOption<PayoutStatus?>>[
            const UiToggleOption<PayoutStatus?>(value: null, label: 'All'),
            for (final PayoutStatus value in PayoutStatus.values)
              UiToggleOption<PayoutStatus?>(
                value: value,
                label: payoutStatusLabel(value),
                intent: payoutStatusIntent(value),
              ),
          ],
        ),
        UiGap.v(context.ui.spacing.md),
        UiTable<Payout>(
          rows: _visible,
          loading: _loading,
          stackOnMobile: true,
          pageSize: 8,
          onRowTap: _openDetail,
          emptyLabel: _status == null
              ? 'No withdrawals yet — your first request will show up here'
              : 'No ${payoutStatusLabel(_status!).toLowerCase()} withdrawals',
          columns: _ledgerColumns(),
        ),
      ],
    ),
  );

  List<UiTableColumn<Payout>> _ledgerColumns() => <UiTableColumn<Payout>>[
    UiTableColumn<Payout>(
      header: 'Requested',
      compare: (Payout a, Payout b) => a.requestedAt.compareTo(b.requestedAt),
      cell: (BuildContext context, Payout row) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppTokens.shortDate(row.requestedAt),
            style: context.uiText.bodyStrong,
          ),
          Text(
            AppTokens.relativeTime(row.requestedAt),
            style: context.uiText.caption.copyWith(
              color: context.uiColors.foregroundMuted,
            ),
          ),
        ],
      ),
    ),
    UiTableColumn<Payout>(
      header: 'Method',
      flex: 2,
      hideBelow: UiTableVisibility.tabletUp,
      compare: (Payout a, Payout b) => a.method.compareTo(b.method),
      cell: (BuildContext context, Payout row) => Text(
        row.method,
        style: context.uiText.body,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    UiTableColumn<Payout>(
      header: 'Reference',
      hideBelow: UiTableVisibility.desktopUp,
      cell: (BuildContext context, Payout row) => Text(
        row.reference ?? '—',
        style: context.uiText.caption.copyWith(
          color: context.uiColors.foregroundMuted,
          fontFamily: 'monospace',
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ),
    UiTableColumn<Payout>(
      header: 'Status',
      compare: (Payout a, Payout b) => a.status.index.compareTo(b.status.index),
      cell: (BuildContext context, Payout row) => UiBadge(
        label: payoutStatusLabel(row.status),
        intent: payoutStatusIntent(row.status),
        filled: true,
      ),
    ),
    UiTableColumn<Payout>(
      header: 'Amount',
      numeric: true,
      compare: (Payout a, Payout b) => a.amount.compareTo(b.amount),
      cell: (BuildContext context, Payout row) => Text(
        AppTokens.money(row.amount),
        style: context.uiText.bodyStrong,
      ),
    ),
  ];

  /// The open request gets its own card because it is the row a partner checks
  /// daily, and it is the one row the table sorts to the top only by accident.
  Widget _nextPayoutCard() {
    final Payout? next = _rows
        .where((Payout p) => p.status != PayoutStatus.paid)
        .fold<Payout?>(null, (Payout? found, Payout p) => found ?? p);
    return UiCard(
      title: 'Open request',
      subtitle: next == null
          ? 'Nothing is being processed right now'
          : '${next.method} · ${AppTokens.relativeTime(next.requestedAt)}',
      child: _loading
          ? UiSkeleton(height: context.sz(120))
          : next == null
          ? UiEmptyState(
              title: 'No pending withdrawal',
              message: _canRequest
                  ? 'Your balance is above the minimum — request it whenever '
                        'you like.'
                  : 'Commission keeps accruing; withdraw once you clear the '
                        'minimum.',
              icon: Icons.hourglass_empty_rounded,
              action: UiButton(
                label: 'Request payout',
                size: UiSize.sm,
                expandOnMobile: false,
                onPressed: _canRequest ? _requestPayout : null,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  AppTokens.money(next.amount),
                  style: context.uiText.display,
                ),
                UiGap.v(context.ui.spacing.md),
                UiStepper(
                  currentIndex: switch (next.status) {
                    PayoutStatus.pending => 0,
                    PayoutStatus.processing => 1,
                    PayoutStatus.paid => 2,
                  },
                  steps: const <UiStepperStep>[
                    UiStepperStep(
                      title: 'Requested',
                      subtitle: 'Awaiting review',
                    ),
                    UiStepperStep(
                      title: 'Processing',
                      subtitle: 'Sent to the bank',
                    ),
                    UiStepperStep(title: 'Paid', subtitle: 'In your account'),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _methodsCard() => UiCard(
    title: 'Withdrawal rails',
    subtitle: 'Minimums and fees are set by finance, not by this screen',
    child: _loading
        ? UiSkeleton(height: context.sz(140))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final PayoutMethod method in _methods)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: context.sp(context.ui.spacing.sm),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        method.icon,
                        size: context.sz(context.ui.sizes.iconSm),
                        color: _pending >= method.minimum
                            ? context.uiColors.bullish
                            : context.uiColors.foregroundSubtle,
                      ),
                      UiGap.h(context.ui.spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(method.label, style: context.uiText.bodyStrong),
                            Text(
                              'Min ${AppTokens.money(method.minimum)} · '
                              '${method.feePercent == 0 ? 'no fee' : '${AppTokens.percent(method.feePercent)} fee'} · '
                              '${method.eta}',
                              style: context.uiText.caption.copyWith(
                                color: context.uiColors.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );

  Widget _rulesCard() => const UiCallout(
    title: 'How payouts clear',
    message:
        'Commission becomes withdrawable after the referred subscription '
        'payment clears and its refund window closes. Requests are reviewed on '
        'working days; a rejected request returns the amount to your balance '
        'with a reason attached.',
    intent: UiIntent.info,
    icon: Icons.schedule_rounded,
  );

  Future<void> _openDetail(Payout payout) => UiDialog.show<void>(
    context,
    child: _PayoutSheet(
      payout: payout,
      onCopyReference: () => _copyReference(payout),
    ),
  );
}

/// Figure + label pair used in the balance strip.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.intent = UiIntent.neutral,
  });

  final String label;
  final String value;
  final UiIntent intent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: context.uiText.caption.copyWith(
          color: context.uiColors.foregroundMuted,
        ),
      ),
      UiGap.v(context.ui.spacing.xxs),
      Text(
        value,
        style: context.uiText.heading.copyWith(
          color: intent == UiIntent.neutral
              ? context.uiColors.foreground
              : intent.color(context),
        ),
      ),
    ],
  );
}

/// What the request sheet hands back: a validated amount and the rail it should
/// go out on.
@immutable
class _PayoutRequest {
  const _PayoutRequest({required this.amount, required this.method});

  final double amount;
  final PayoutMethod method;
}

/// Withdrawal sheet. Validates against the selected rail's minimum rather than
/// a page-level constant, so adding a rail needs no change here.
class _RequestSheet extends StatefulWidget {
  const _RequestSheet({required this.balance, required this.methods});

  final double balance;
  final List<PayoutMethod> methods;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  late PayoutMethod _method = widget.methods.firstWhere(
    (PayoutMethod m) => widget.balance >= m.minimum,
    orElse: () => widget.methods.first,
  );
  late final TextEditingController _controller = TextEditingController(
    text: widget.balance.toStringAsFixed(0),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_controller.text.trim());

  String? get _error {
    final double? amount = _amount;
    if (amount == null || amount <= 0) return 'Enter an amount to withdraw';
    if (amount > widget.balance) {
      return 'You can withdraw at most ${AppTokens.money(widget.balance)}';
    }
    if (amount < _method.minimum) {
      return '${_method.label} needs at least '
          '${AppTokens.money(_method.minimum)}';
    }
    return null;
  }

  void _setAmount(double value) =>
      setState(() => _controller.text = value.toStringAsFixed(0));

  @override
  Widget build(BuildContext context) {
    final String? error = _error;
    final double amount = _amount ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Request a payout', style: context.uiText.heading),
                  Text(
                    '${AppTokens.money(widget.balance)} available',
                    style: context.uiText.caption.copyWith(
                      color: context.uiColors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.lg),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                UiRadioCardGroup<String>(
                  label: 'Send it via',
                  value: _method.id,
                  mobileColumns: 1,
                  tabletColumns: 2,
                  desktopColumns: 2,
                  onChanged: (String id) => setState(
                    () => _method = widget.methods.firstWhere(
                      (PayoutMethod m) => m.id == id,
                    ),
                  ),
                  options: <UiOption<String>>[
                    for (final PayoutMethod method in widget.methods)
                      UiOption<String>(
                        value: method.id,
                        label: method.label,
                        description:
                            '${method.detail} · ${method.eta} · min '
                            '${AppTokens.money(method.minimum)}',
                        icon: method.icon,
                        enabled: widget.balance >= method.minimum,
                        trailingLabel: method.feePercent == 0
                            ? 'No fee'
                            : '${AppTokens.percent(method.feePercent)} fee',
                      ),
                  ],
                ),
                UiGap.v(context.ui.spacing.md),
                _amountField(error),
                UiGap.v(context.ui.spacing.md),
                _breakdown(amount),
              ],
            ),
          ),
        ),
        UiGap.v(context.ui.spacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            UiButton(
              label: 'Cancel',
              variant: UiVariant.ghost,
              expandOnMobile: false,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            UiGap.h(context.ui.spacing.sm),
            UiButton(
              label: 'Request ${AppTokens.money(amount)}',
              leadingIcon: Icons.north_east_rounded,
              expandOnMobile: false,
              onPressed: error != null
                  ? null
                  : () => Navigator.of(context).pop(
                      _PayoutRequest(amount: amount, method: _method),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  /// Quick amounts are fractions of the real balance, so they stay correct as
  /// commission accrues. They sit under the input rather than in the label row
  /// so three chips cannot overflow a phone-width dialog.
  Widget _amountField(String? error) => UiField(
    label: 'Amount',
    error: error,
    helper: error == null
        ? 'Anything you leave behind keeps earning and stays withdrawable'
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiInput(
          controller: _controller,
          prefixText: '₹ ',
          error: error != null,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (String _) => setState(() {}),
        ),
        UiGap.v(context.ui.spacing.xs),
        Wrap(
          spacing: context.sp(context.ui.spacing.xs),
          runSpacing: context.sp(context.ui.spacing.xs),
          children: <Widget>[
            for (final ({String label, double fraction}) preset
                in const <({String label, double fraction})>[
                  (label: '25%', fraction: 0.25),
                  (label: '50%', fraction: 0.5),
                  (label: 'Max', fraction: 1),
                ])
              UiButton(
                label: preset.label,
                variant: UiVariant.outline,
                size: UiSize.sm,
                expandOnMobile: false,
                onPressed: () => _setAmount(widget.balance * preset.fraction),
              ),
          ],
        ),
      ],
    ),
  );

  /// Fees are shown as the difference between requested and received, because
  /// that is the number partners complain about when it is hidden.
  Widget _breakdown(double amount) {
    final double net = _method.netOf(amount);
    return Container(
      padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
      decoration: BoxDecoration(
        color: context.uiColors.surfaceMuted,
        borderRadius: context.radius(context.ui.radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _line(context, 'Requested', AppTokens.money(amount)),
          _line(
            context,
            _method.feePercent == 0
                ? 'Processing fee'
                : 'Processing fee (${AppTokens.percent(_method.feePercent)})',
            _method.feePercent == 0
                ? 'None'
                : '− ${AppTokens.money(amount - net)}',
          ),
          _line(
            context,
            'Lands in your account',
            AppTokens.money(net),
            strong: true,
          ),
          _line(context, 'Expected by', _method.eta),
          _line(
            context,
            'Balance after this',
            AppTokens.money(widget.balance - amount),
          ),
        ],
      ),
    );
  }

  Widget _line(
    BuildContext context,
    String label,
    String value, {
    bool strong = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.xs)),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: context.uiText.caption.copyWith(
              color: context.uiColors.foregroundMuted,
            ),
          ),
        ),
        Text(
          value,
          style: strong
              ? context.uiText.bodyStrong.copyWith(
                  color: context.uiColors.bullish,
                )
              : context.uiText.body,
        ),
      ],
    ),
  );
}

/// Read-only detail for one ledger row, including the timeline finance works
/// to and the bank reference to quote in a support ticket.
class _PayoutSheet extends StatelessWidget {
  const _PayoutSheet({required this.payout, required this.onCopyReference});

  final Payout payout;
  final VoidCallback onCopyReference;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(AppTokens.money(payout.amount),
                    style: context.uiText.heading),
                Text(
                  '${payout.method} · requested '
                  '${AppTokens.relativeTime(payout.requestedAt)}',
                  style: context.uiText.caption.copyWith(
                    color: context.uiColors.foregroundMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          UiBadge(
            label: payoutStatusLabel(payout.status),
            intent: payoutStatusIntent(payout.status),
            filled: true,
          ),
          UiGap.h(context.ui.spacing.sm),
          UiIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      UiGap.v(context.ui.spacing.lg),
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiTimeline(
                entries: <UiTimelineEntry>[
                  UiTimelineEntry(
                    title: 'Requested',
                    subtitle: 'You asked for ${AppTokens.money(payout.amount)}',
                    timestamp: AppTokens.shortDate(payout.requestedAt),
                    icon: Icons.north_east_rounded,
                    intent: UiIntent.info,
                  ),
                  UiTimelineEntry(
                    title: payout.status == PayoutStatus.pending
                        ? 'Awaiting review'
                        : 'Approved and sent',
                    subtitle: payout.status == PayoutStatus.pending
                        ? 'Finance reviews requests on working days'
                        : 'Released to ${payout.method}',
                    icon: Icons.fact_check_outlined,
                    intent: payout.status == PayoutStatus.pending
                        ? UiIntent.warning
                        : UiIntent.success,
                  ),
                  UiTimelineEntry(
                    title: payout.paidAt == null ? 'Not settled yet' : 'Settled',
                    subtitle: payout.reference == null
                        ? 'A bank reference appears once it settles'
                        : 'Reference ${payout.reference}',
                    timestamp: payout.paidAt == null
                        ? null
                        : AppTokens.shortDate(payout.paidAt!),
                    icon: Icons.verified_rounded,
                    intent: payout.paidAt == null
                        ? UiIntent.neutral
                        : UiIntent.success,
                  ),
                ],
              ),
              UiGap.v(context.ui.spacing.md),
              if (payout.status != PayoutStatus.paid)
                const UiCallout(
                  title: 'Still in flight',
                  message:
                      'The amount stays out of your withdrawable balance until '
                      'this settles. If it is rejected the full amount returns '
                      'to your balance with a reason.',
                  intent: UiIntent.info,
                  icon: Icons.hourglass_bottom_rounded,
                ),
            ],
          ),
        ),
      ),
      UiGap.v(context.ui.spacing.lg),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          UiButton(
            label: 'Close',
            variant: UiVariant.ghost,
            expandOnMobile: false,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          UiGap.h(context.ui.spacing.sm),
          UiButton(
            label: 'Copy reference',
            leadingIcon: Icons.copy_rounded,
            expandOnMobile: false,
            onPressed: payout.reference == null ? null : onCopyReference,
          ),
        ],
      ),
    ],
  );
}
