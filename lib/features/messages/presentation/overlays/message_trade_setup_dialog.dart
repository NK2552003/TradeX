import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/messages/models/messages_models.dart';

/// Modal dialog for authoring and sharing live trade setups in messages without hardcoded data.
class MessageTradeSetupDialog extends StatefulWidget {
  const MessageTradeSetupDialog({super.key});

  static Future<MessageAttachment?> show(BuildContext context) {
    return UiDialog.show<MessageAttachment>(
      context,
      child: const MessageTradeSetupDialog(),
    );
  }

  @override
  State<MessageTradeSetupDialog> createState() =>
      _MessageTradeSetupDialogState();
}

class _MessageTradeSetupDialogState extends State<MessageTradeSetupDialog> {
  static const List<String> _popularSymbols = <String>[
    'NIFTY',
    'BANKNIFTY',
    'RELIANCE',
    'TCS',
    'NVDA',
    'BTC',
  ];

  late final TextEditingController _symbolController;
  late final TextEditingController _entryController;
  late final TextEditingController _stopController;
  late final TextEditingController _targetController;
  late final TextEditingController _strategyController;
  late final TextEditingController _notesController;

  bool _isLong = true;

  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController(text: 'NIFTY');
    _entryController = TextEditingController(text: '24350.00');
    _stopController = TextEditingController(text: '24200.00');
    _targetController = TextEditingController(text: '24800.00');
    _strategyController = TextEditingController(text: '15m ORB Breakout');
    _notesController = TextEditingController();

    _entryController.addListener(_onPriceChanged);
    _stopController.addListener(_onPriceChanged);
    _targetController.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _entryController.removeListener(_onPriceChanged);
    _stopController.removeListener(_onPriceChanged);
    _targetController.removeListener(_onPriceChanged);

    _symbolController.dispose();
    _entryController.dispose();
    _stopController.dispose();
    _targetController.dispose();
    _strategyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onPriceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _selectPreset(String s) {
    _symbolController.text = s;
    final String sym = s.toUpperCase();
    if (sym == 'BANKNIFTY') {
      _entryController.text = '52400.00';
      _stopController.text = _isLong ? '52100.00' : '52700.00';
      _targetController.text = _isLong ? '53200.00' : '51600.00';
    } else if (sym == 'NIFTY') {
      _entryController.text = '24350.00';
      _stopController.text = _isLong ? '24200.00' : '24500.00';
      _targetController.text = _isLong ? '24800.00' : '23900.00';
    } else if (sym == 'RELIANCE') {
      _entryController.text = '2980.00';
      _stopController.text = _isLong ? '2940.00' : '3020.00';
      _targetController.text = _isLong ? '3080.00' : '2880.00';
    } else if (sym == 'BTC') {
      _entryController.text = '94250.00';
      _stopController.text = _isLong ? '92800.00' : '95700.00';
      _targetController.text = _isLong ? '98500.00' : '90000.00';
    }
    setState(() {});
  }

  void _toggleDirection(bool long) {
    if (_isLong == long) return;
    setState(() {
      _isLong = long;
      // Flip stop and target appropriately
      final double? entry = double.tryParse(_entryController.text.trim());
      final double? stop = double.tryParse(_stopController.text.trim());
      final double? target = double.tryParse(_targetController.text.trim());
      if (entry != null && stop != null && target != null) {
        final double risk = (entry - stop).abs();
        final double reward = (target - entry).abs();
        if (_isLong) {
          _stopController.text = (entry - risk).toStringAsFixed(2);
          _targetController.text = (entry + reward).toStringAsFixed(2);
        } else {
          _stopController.text = (entry + risk).toStringAsFixed(2);
          _targetController.text = (entry - reward).toStringAsFixed(2);
        }
      }
    });
  }

  void _submit() {
    final String symbol = _symbolController.text.trim().toUpperCase();
    final double? entry = double.tryParse(_entryController.text.trim());
    final double? stop = double.tryParse(_stopController.text.trim());
    final double? target = double.tryParse(_targetController.text.trim());

    if (symbol.isEmpty || entry == null || stop == null || target == null) {
      return;
    }

    final String strategy = _strategyController.text.trim().isNotEmpty
        ? _strategyController.text.trim()
        : (_isLong ? 'Long Execution Setup' : 'Short Execution Setup');

    final MessageAttachment attachment = MessageAttachment(
      id: 'att_setup_${DateTime.now().microsecondsSinceEpoch}',
      kind: MessageAttachmentKind.tradeSetup,
      title: '$symbol Setup',
      subtitle: strategy,
      direction: _isLong ? 'long' : 'short',
      entry: entry,
      stop: stop,
      target: target,
      note: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    Navigator.of(context).pop(attachment);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final double? entry = double.tryParse(_entryController.text.trim());
    final double? stop = double.tryParse(_stopController.text.trim());
    final double? target = double.tryParse(_targetController.text.trim());

    double? riskPoints;
    double? rewardPoints;
    double? rr;
    String? validationError;

    if (entry != null && stop != null && target != null) {
      if (_isLong) {
        if (stop >= entry) {
          validationError =
              'For a Long trade, Stop Loss must be lower than Entry.';
        } else if (target <= entry) {
          validationError =
              'For a Long trade, Target must be higher than Entry.';
        }
      } else {
        if (stop <= entry) {
          validationError =
              'For a Short trade, Stop Loss must be higher than Entry.';
        } else if (target >= entry) {
          validationError =
              'For a Short trade, Target must be lower than Entry.';
        }
      }

      riskPoints = (entry - stop).abs();
      rewardPoints = (target - entry).abs();
      if (riskPoints > 0) {
        rr = rewardPoints / riskPoints;
      }
    }

    final bool canSubmit =
        _symbolController.text.trim().isNotEmpty &&
        entry != null &&
        stop != null &&
        target != null &&
        validationError == null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: context.sz(560),
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header
          Padding(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            child: Row(
              children: <Widget>[
                Container(
                  width: context.sz(38),
                  height: context.sz(38),
                  decoration: BoxDecoration(
                    color: (_isLong ? colors.success : colors.destructive)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isLong
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: _isLong ? colors.success : colors.destructive,
                    size: context.sz(20),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Share Trade Setup',
                        style: context.uiText.heading.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: context.fs(17),
                        ),
                      ),
                      Text(
                        'Enter real price execution boundaries to attach',
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                UiIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  size: UiSize.sm,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Direction Selector
                  Text(
                    'Trade Direction',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.foregroundMuted,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _toggleDirection(true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: EdgeInsets.symmetric(
                              vertical: context.sp(theme.spacing.sm),
                            ),
                            decoration: BoxDecoration(
                              color: _isLong
                                  ? colors.success.withValues(alpha: 0.15)
                                  : colors.surfaceMuted,
                              borderRadius: context.radius(theme.radii.md),
                              border: Border.all(
                                color: _isLong ? colors.success : colors.border,
                                width: _isLong ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.arrow_upward_rounded,
                                  color: _isLong
                                      ? colors.success
                                      : colors.foregroundMuted,
                                  size: context.sz(18),
                                ),
                                SizedBox(width: context.sp(theme.spacing.xs)),
                                Text(
                                  'LONG (BUY)',
                                  style: context.uiText.bodyStrong.copyWith(
                                    color: _isLong
                                        ? colors.success
                                        : colors.foregroundMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _toggleDirection(false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: EdgeInsets.symmetric(
                              vertical: context.sp(theme.spacing.sm),
                            ),
                            decoration: BoxDecoration(
                              color: !_isLong
                                  ? colors.destructive.withValues(alpha: 0.15)
                                  : colors.surfaceMuted,
                              borderRadius: context.radius(theme.radii.md),
                              border: Border.all(
                                color: !_isLong
                                    ? colors.destructive
                                    : colors.border,
                                width: !_isLong ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  color: !_isLong
                                      ? colors.destructive
                                      : colors.foregroundMuted,
                                  size: context.sz(18),
                                ),
                                SizedBox(width: context.sp(theme.spacing.xs)),
                                Text(
                                  'SHORT (SELL)',
                                  style: context.uiText.bodyStrong.copyWith(
                                    color: !_isLong
                                        ? colors.destructive
                                        : colors.foregroundMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: context.sp(theme.spacing.md)),

                  // Symbol & Presets
                  Text(
                    'Symbol / Ticker',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.foregroundMuted,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  UiInput(
                    controller: _symbolController,
                    hintText: 'e.g. NIFTY, BANKNIFTY, RELIANCE',
                  ),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  Wrap(
                    spacing: context.sp(theme.spacing.xs),
                    children: _popularSymbols.map((s) {
                      final bool isSel =
                          _symbolController.text.trim().toUpperCase() == s;
                      return GestureDetector(
                        onTap: () => _selectPreset(s),
                        child: UiBadge(
                          label: s,
                          variant: isSel
                              ? UiBadgeVariant.solid
                              : UiBadgeVariant.soft,
                          intent: isSel ? UiIntent.primary : UiIntent.neutral,
                          size: UiSize.xs,
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: context.sp(theme.spacing.md)),

                  // Price Triple
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Entry Price',
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.foregroundMuted,
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.xxs)),
                            UiInput(
                              controller: _entryController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Stop Loss',
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.destructive,
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.xxs)),
                            UiInput(
                              controller: _stopController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Target Price',
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.success,
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.xxs)),
                            UiInput(
                              controller: _targetController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (validationError != null) ...<Widget>[
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    Text(
                      validationError,
                      style: context.uiText.caption.copyWith(
                        color: colors.destructive,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  SizedBox(height: context.sp(theme.spacing.md)),

                  // Live R:R Summary Card
                  if (riskPoints != null && rewardPoints != null) ...<Widget>[
                    UiCard(
                      accentColor: _isLong
                          ? colors.success
                          : colors.destructive,
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              UiBadge(
                                label: _isLong
                                    ? 'LONG POSITION'
                                    : 'SHORT POSITION',
                                intent: _isLong
                                    ? UiIntent.success
                                    : UiIntent.danger,
                                variant: UiBadgeVariant.solid,
                                size: UiSize.xs,
                              ),
                              const Spacer(),
                              if (rr != null)
                                UiBadge(
                                  label: 'R:R 1 : ${rr.toStringAsFixed(2)}',
                                  icon: Icons.balance_rounded,
                                  intent: rr >= 2.0
                                      ? UiIntent.success
                                      : (rr >= 1.0
                                            ? UiIntent.info
                                            : UiIntent.warning),
                                  size: UiSize.xs,
                                ),
                            ],
                          ),
                          SizedBox(height: context.sp(theme.spacing.sm)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: <Widget>[
                              _metricColumn(
                                context,
                                'Max Risk',
                                '${riskPoints.toStringAsFixed(2)} pts',
                                colors.destructive,
                              ),
                              _metricColumn(
                                context,
                                'Take Profit',
                                '${rewardPoints.toStringAsFixed(2)} pts',
                                colors.success,
                              ),
                              _metricColumn(
                                context,
                                'Win Expectancy',
                                rr != null && rr >= 1.5
                                    ? 'Favorable'
                                    : 'Moderate',
                                colors.foreground,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.md)),
                  ],

                  // Strategy Name
                  Text(
                    'Setup / Playbook Name',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.foregroundMuted,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  UiInput(
                    controller: _strategyController,
                    hintText: 'e.g. 15m ORB Breakout, VWAP Retest',
                  ),

                  SizedBox(height: context.sp(theme.spacing.md)),

                  // Notes / Execution Details
                  Text(
                    'Notes / Trade Rationale (Optional)',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.foregroundMuted,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  UiTextarea(
                    controller: _notesController,
                    hintText:
                        'e.g. Wait for 5-minute candle close confirmation above resistance.',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Footer Actions
          Padding(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                UiButton(
                  label: 'Cancel',
                  variant: UiVariant.ghost,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                UiButton(
                  label: 'Share Setup',
                  icon: Icons.trending_up_rounded,
                  variant: UiVariant.solid,
                  intent: _isLong ? UiIntent.primary : UiIntent.danger,
                  onPressed: canSubmit ? _submit : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricColumn(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: context.uiText.caption.copyWith(
            color: context.uiColors.foregroundMuted,
            fontSize: context.fs(11),
          ),
        ),
        SizedBox(height: context.sp(context.ui.spacing.xxs)),
        Text(
          value,
          style: context.uiText.bodyStrong.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
