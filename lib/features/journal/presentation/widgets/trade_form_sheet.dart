import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Create/edit form for a journal entry. Opens as a bottom sheet on phones and
/// a centred dialog on larger screens (handled by [UiDialog.show]).
///
/// Returns the composed [AppTrade] via `Navigator.pop`, or `null` on cancel.
/// P/L, percentage and R multiple are derived here so the caller never has to
/// compute them.
Future<AppTrade?> showTradeFormSheet(
  BuildContext context, {
  AppTrade? initial,
  required List<String> symbols,
  required List<String> strategies,
  required List<String> tags,
}) => UiDialog.show<AppTrade>(
  context,
  child: _TradeForm(
    initial: initial,
    symbols: symbols,
    strategies: strategies,
    tags: tags,
  ),
);

class _TradeForm extends StatefulWidget {
  const _TradeForm({
    required this.symbols,
    required this.strategies,
    required this.tags,
    this.initial,
  });

  final AppTrade? initial;
  final List<String> symbols;
  final List<String> strategies;
  final List<String> tags;

  @override
  State<_TradeForm> createState() => _TradeFormState();
}

class _TradeFormState extends State<_TradeForm> {
  late String? _symbol = widget.initial?.ticker;
  late AppSide _side = widget.initial?.side ?? AppSide.long;
  late String? _strategy = widget.initial?.strategy;
  late List<String> _tags = List<String>.from(
    widget.initial?.tags ?? const <String>[],
  );
  late DateTime _openedAt = widget.initial?.openedAt ?? DateTime.now();
  late DateTime? _closedAt = widget.initial?.closedAt;
  late int _psychology = widget.initial?.psychologyScore ?? 7;
  late bool _stillOpen = widget.initial?.outcome == AppOutcome.open;

  late final TextEditingController _entry = TextEditingController(
    text: widget.initial?.entry.toString() ?? '',
  );
  late final TextEditingController _exit = TextEditingController(
    text: widget.initial?.exit?.toString() ?? '',
  );
  late final TextEditingController _stop = TextEditingController(
    text: widget.initial?.stopLoss?.toString() ?? '',
  );
  late final TextEditingController _target = TextEditingController(
    text: widget.initial?.target?.toString() ?? '',
  );
  late final TextEditingController _size = TextEditingController(
    text: widget.initial?.size.toString() ?? '1',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.initial?.notes ?? '',
  );

  String? _error;

  @override
  void dispose() {
    _entry.dispose();
    _exit.dispose();
    _stop.dispose();
    _target.dispose();
    _size.dispose();
    _notes.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', ''));

  void _submit() {
    final String? symbol = _symbol;
    final double? entry = _num(_entry);
    final double? size = _num(_size);
    final double? exit = _num(_exit);
    if (symbol == null || symbol.isEmpty) {
      setState(() => _error = 'Pick an instrument.');
      return;
    }
    if (entry == null || entry <= 0) {
      setState(() => _error = 'Entry price is required.');
      return;
    }
    if (size == null || size <= 0) {
      setState(() => _error = 'Position size must be greater than zero.');
      return;
    }
    if (!_stillOpen && (exit == null || exit <= 0)) {
      setState(() => _error = 'Add an exit price or mark the trade as open.');
      return;
    }

    final double? stop = _num(_stop);
    final int direction = _side == AppSide.long ? 1 : -1;
    final double pnl = _stillOpen || exit == null
        ? 0
        : (exit - entry) * size * direction;
    final double pnlPercent = _stillOpen || exit == null
        ? 0
        : ((exit - entry) / entry) * 100 * direction;
    final double? risk = stop == null ? null : (entry - stop).abs() * size;
    final double? rMultiple = risk == null || risk == 0 || _stillOpen
        ? null
        : pnl / risk;

    Navigator.of(context).pop(
      AppTrade(
        id: widget.initial?.id ?? 'trd_${DateTime.now().microsecondsSinceEpoch}',
        ticker: symbol,
        side: _side,
        entry: entry,
        exit: _stillOpen ? null : exit,
        openedAt: _openedAt,
        closedAt: _stillOpen ? null : (_closedAt ?? DateTime.now()),
        stopLoss: stop,
        target: _num(_target),
        size: size,
        pnl: pnl,
        pnlPercent: pnlPercent,
        rMultiple: rMultiple,
        outcome: _stillOpen
            ? AppOutcome.open
            : (pnl > 0
                  ? AppOutcome.win
                  : (pnl < 0 ? AppOutcome.loss : AppOutcome.breakeven)),
        strategy: _strategy,
        tags: _tags,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        screenshotUrl: widget.initial?.screenshotUrl,
        psychologyScore: _psychology,
      ),
    );
  }

  /// Two fields side by side on wide screens, stacked on phones so the touch
  /// targets stay full width.
  Widget _pair(Widget a, Widget b) {
    if (context.uiRes.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[a, UiGap.v(context.ui.spacing.md), b],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: a),
        UiGap.h(context.ui.spacing.md),
        Expanded(child: b),
      ],
    );
  }

  /// Live read-out of the numbers the form will derive on save, so the trader
  /// sees the P/L before committing.
  Widget? _preview() {
    final double? entry = _num(_entry);
    final double? exit = _num(_exit);
    final double? size = _num(_size);
    if (_stillOpen || entry == null || exit == null || size == null) return null;
    if (entry <= 0 || size <= 0) return null;

    final double? stop = _num(_stop);
    final int direction = _side == AppSide.long ? 1 : -1;
    final double pnl = (exit - entry) * size * direction;
    final double percent = ((exit - entry) / entry) * 100 * direction;
    final double? risk = stop == null ? null : (entry - stop).abs() * size;
    final double? r = risk == null || risk == 0 ? null : pnl / risk;

    return UiCallout(
      title:
          '${AppTokens.signedMoney(pnl)} · ${AppTokens.signedPercent(percent)}'
          '${r == null ? '' : ' · ${AppTokens.rr(r)}'}',
      message: 'Derived from entry, exit and size — stored with the trade.',
      icon: Icons.calculate_rounded,
      intent: pnl >= 0 ? UiIntent.success : UiIntent.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.initial != null;
    final Widget? preview = _preview();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    editing ? 'Edit trade' : 'Log a trade',
                    style: context.uiText.heading,
                  ),
                  UiGap.v(context.ui.spacing.xs),
                  Text(
                    editing
                        ? 'Update the fills, exits and notes for ${widget.initial!.ticker}.'
                        : 'Capture the setup while it is fresh — P/L and R are derived for you.',
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
              children: _fields(preview),
            ),
          ),
        ),
        UiGap.v(context.ui.spacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: UiButton(
                label: 'Cancel',
                variant: UiVariant.ghost,
                expand: true,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            UiGap.h(context.ui.spacing.md),
            Expanded(
              child: UiButton(
                label: editing ? 'Save changes' : 'Log trade',
                leadingIcon: editing
                    ? Icons.check_rounded
                    : Icons.add_task_rounded,
                expand: true,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
  List<Widget> _fields(Widget? preview) {
    final double gap = context.ui.spacing.md;
    return <Widget>[
      if (_error != null) ...<Widget>[
        UiCallout(
          title: _error!,
          intent: UiIntent.danger,
          onClose: () => setState(() => _error = null),
        ),
        UiGap.v(gap),
      ],
      UiField(
        label: 'Instrument',
        required: true,
        child: UiSelect<String>(
          options: <UiOption<String>>[
            for (final String symbol in widget.symbols)
              UiOption<String>(value: symbol, label: symbol),
          ],
          value: _symbol,
          searchable: true,
          hintText: 'Search symbols',
          leadingIcon: Icons.candlestick_chart_rounded,
          onChanged: (String value) => setState(() {
            _symbol = value;
            _error = null;
          }),
        ),
      ),
      UiGap.v(gap),
      UiField(
        label: 'Direction',
        child: UiToggleGroup<AppSide>(
          options: <UiToggleOption<AppSide>>[
            for (final AppSide side in AppSide.values)
              UiToggleOption<AppSide>(
                value: side,
                label: AppTokens.sideLabel(side),
                icon: AppTokens.sideIcon(side),
                intent: AppTokens.sideIntent(side),
              ),
          ],
          value: _side,
          size: UiSize.md,
          expand: true,
          onChanged: (AppSide side) => setState(() => _side = side),
        ),
      ),
      UiGap.v(gap),
      _pair(
        UiField(
          label: 'Entry price',
          required: true,
          child: UiInput(
            controller: _entry,
            hintText: '0.00',
            prefixText: '₹',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (String _) => setState(() {}),
          ),
        ),
        UiField(
          label: 'Position size',
          required: true,
          helper: 'Quantity, lots or contracts',
          child: UiInput(
            controller: _size,
            hintText: '1',
            leadingIcon: Icons.layers_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (String _) => setState(() {}),
          ),
        ),
      ),
      UiGap.v(gap),
      _pair(
        UiField(
          label: 'Stop loss',
          helper: 'Powers the R multiple',
          child: UiInput(
            controller: _stop,
            hintText: 'Optional',
            prefixText: '₹',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (String _) => setState(() {}),
          ),
        ),
        UiField(
          label: 'Target',
          child: UiInput(
            controller: _target,
            hintText: 'Optional',
            prefixText: '₹',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
      ),
      UiGap.v(gap),
      UiSwitch(
        value: _stillOpen,
        asCard: true,
        label: 'Position is still open',
        description: 'Leave on while the trade runs; exits stay optional.',
        onChanged: (bool value) => setState(() {
          _stillOpen = value;
          _error = null;
        }),
      ),
      UiGap.v(gap),
      _pair(
        UiField(
          label: 'Opened',
          child: UiDatePicker(
            value: _openedAt,
            lastDate: DateTime.now(),
            onChanged: (DateTime value) => setState(() => _openedAt = value),
          ),
        ),
        _stillOpen
            ? UiField(
                label: 'Exit price',
                helper: 'Available once the trade is closed',
                child: UiInput(
                  controller: _exit,
                  hintText: 'Trade still open',
                  enabled: false,
                ),
              )
            : UiField(
                label: 'Exit price',
                required: true,
                child: UiInput(
                  controller: _exit,
                  hintText: '0.00',
                  prefixText: '₹',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (String _) => setState(() {}),
                ),
              ),
      ),
      if (!_stillOpen) ...<Widget>[
        UiGap.v(gap),
        UiField(
          label: 'Closed',
          helper: 'Defaults to now when left empty',
          child: UiDatePicker(
            value: _closedAt,
            hintText: 'Pick a close date',
            firstDate: _openedAt,
            onChanged: (DateTime value) => setState(() => _closedAt = value),
          ),
        ),
      ],
      UiGap.v(gap),
      UiField(
        label: 'Strategy',
        child: UiSelect<String>(
          options: <UiOption<String>>[
            const UiOption<String>(value: '', label: 'Unassigned'),
            for (final String strategy in widget.strategies)
              UiOption<String>(value: strategy, label: strategy),
          ],
          value: _strategy ?? '',
          searchable: widget.strategies.length > 6,
          hintText: 'Pick a playbook',
          leadingIcon: Icons.account_tree_outlined,
          onChanged: (String value) =>
              setState(() => _strategy = value.isEmpty ? null : value),
        ),
      ),
      UiGap.v(gap),
      UiField(
        label: 'Tags',
        helper: 'Setup, session or mistake labels',
        child: UiTagInput(
          tags: _tags,
          suggestions: widget.tags,
          hintText: 'Add a tag',
          onChanged: (List<String> tags) => setState(() => _tags = tags),
        ),
      ),
      UiGap.v(gap),
      UiSlider(
        value: _psychology.toDouble(),
        min: 1,
        max: 10,
        divisions: 9,
        showTicks: true,
        showBounds: true,
        label: 'Discipline score',
        helper: 'How well did you follow the plan on this trade?',
        valueFormatter: (num value) => '${value.toStringAsFixed(0)}/10',
        intent: _psychology >= 7
            ? UiIntent.success
            : (_psychology >= 4 ? UiIntent.warning : UiIntent.danger),
        onChanged: (double value) =>
            setState(() => _psychology = value.round()),
      ),
      UiGap.v(gap),
      UiTextarea(
        controller: _notes,
        label: 'Notes',
        rows: 4,
        maxRows: 8,
        maxLength: 600,
        hintText: 'What was the thesis, and what would you repeat?',
      ),
      if (preview != null) ...<Widget>[UiGap.v(gap), preview],
    ];
  }
}
