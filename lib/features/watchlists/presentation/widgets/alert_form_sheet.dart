import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Create/edit a price alert. Sheet on phones, dialog on desktop.
///
/// [priceOf] resolves the live price for a symbol so the form can show the
/// distance to target without the caller pre-computing anything.
Future<AppPriceAlert?> showAlertFormSheet(
  BuildContext context, {
  AppPriceAlert? initial,
  String? symbol,
  required List<String> symbols,
  required double Function(String symbol) priceOf,
}) => UiDialog.show<AppPriceAlert>(
  context,
  child: _AlertForm(
    initial: initial,
    symbol: symbol,
    symbols: symbols,
    priceOf: priceOf,
  ),
);

class _AlertForm extends StatefulWidget {
  const _AlertForm({
    required this.symbols,
    required this.priceOf,
    this.initial,
    this.symbol,
  });

  final AppPriceAlert? initial;
  final String? symbol;
  final List<String> symbols;
  final double Function(String symbol) priceOf;

  @override
  State<_AlertForm> createState() => _AlertFormState();
}

class _AlertFormState extends State<_AlertForm> {
  late String _symbol =
      widget.initial?.symbol ??
      widget.symbol ??
      (widget.symbols.isEmpty ? '' : widget.symbols.first);
  late bool _above = widget.initial?.above ?? true;
  late bool _active = widget.initial?.active ?? true;
  late final TextEditingController _price = TextEditingController(
    text: widget.initial == null
        ? ''
        : widget.initial!.targetPrice.toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  double get _current => _symbol.isEmpty ? 0 : widget.priceOf(_symbol);

  double? get _target => double.tryParse(_price.text.trim().replaceAll(',', ''));

  void _submit() {
    if (_symbol.isEmpty) {
      setState(() => _error = 'Pick an instrument to watch.');
      return;
    }
    final double? target = _target;
    if (target == null || target <= 0) {
      setState(() => _error = 'Enter the price level to alert on.');
      return;
    }
    final double current = _current;
    if (_above && target <= current) {
      setState(
        () => _error =
            'A "crosses above" alert needs a level above ${AppTokens.money(current)}.',
      );
      return;
    }
    if (!_above && target >= current) {
      setState(
        () => _error =
            'A "drops below" alert needs a level under ${AppTokens.money(current)}.',
      );
      return;
    }

    Navigator.of(context).pop(
      AppPriceAlert(
        id: widget.initial?.id ?? 'alr_${DateTime.now().microsecondsSinceEpoch}',
        symbol: _symbol,
        targetPrice: target,
        above: _above,
        currentPrice: current,
        active: _active,
        triggeredAt: null,
      ),
    );
  }

  /// How far the level sits from the last price — the reason the trader is
  /// setting the alert in the first place.
  Widget? _distance() {
    final double? target = _target;
    final double current = _current;
    if (target == null || target <= 0 || current <= 0) return null;
    final double percent = ((target - current) / current) * 100;
    return UiCallout(
      title:
          '${AppTokens.signedPercent(percent)} away · last ${AppTokens.money(current)}',
      message: _above
          ? 'Fires the first time $_symbol prints above ${AppTokens.money(target)}.'
          : 'Fires the first time $_symbol prints below ${AppTokens.money(target)}.',
      icon: Icons.notifications_active_outlined,
      intent: percent.abs() < 2 ? UiIntent.warning : UiIntent.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.initial != null;
    final double gap = context.ui.spacing.md;
    final Widget? distance = _distance();

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
                    editing ? 'Edit alert' : 'New price alert',
                    style: context.uiText.heading,
                  ),
                  UiGap.v(context.ui.spacing.xs),
                  Text(
                    'We watch the tape and ping you the moment the level trades.',
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
                    value: _symbol.isEmpty ? null : _symbol,
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
                  label: 'Trigger',
                  child: UiToggleGroup<bool>(
                    options: const <UiToggleOption<bool>>[
                      UiToggleOption<bool>(
                        value: true,
                        label: 'Crosses above',
                        icon: Icons.trending_up_rounded,
                        intent: UiIntent.bullish,
                      ),
                      UiToggleOption<bool>(
                        value: false,
                        label: 'Drops below',
                        icon: Icons.trending_down_rounded,
                        intent: UiIntent.bearish,
                      ),
                    ],
                    value: _above,
                    expand: true,
                    onChanged: (bool value) => setState(() {
                      _above = value;
                      _error = null;
                    }),
                  ),
                ),
                UiGap.v(gap),
                UiField(
                  label: 'Price level',
                  required: true,
                  helper: _symbol.isEmpty
                      ? null
                      : 'Last traded ${AppTokens.money(_current)}',
                  child: UiInput(
                    controller: _price,
                    hintText: '0.00',
                    prefixText: '₹',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (String _) => setState(() {}),
                  ),
                ),
                UiGap.v(gap),
                UiSwitch(
                  value: _active,
                  asCard: true,
                  label: 'Arm the alert',
                  description:
                      'Turn off to keep the level saved without notifications.',
                  onChanged: (bool value) => setState(() => _active = value),
                ),
                if (distance != null) ...<Widget>[UiGap.v(gap), distance],
              ],
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
            UiGap.h(gap),
            Expanded(
              child: UiButton(
                label: editing ? 'Save alert' : 'Create alert',
                leadingIcon: editing
                    ? Icons.check_rounded
                    : Icons.add_alert_outlined,
                expand: true,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
