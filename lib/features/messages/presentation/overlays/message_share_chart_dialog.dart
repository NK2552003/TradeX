import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/messages/models/messages_models.dart';

/// Modal dialog for generating and sharing interactive technical charts in messages.
class MessageShareChartDialog extends StatefulWidget {
  const MessageShareChartDialog({super.key});

  static Future<MessageAttachment?> show(BuildContext context) {
    return UiDialog.show<MessageAttachment>(
      context,
      child: const MessageShareChartDialog(),
    );
  }

  @override
  State<MessageShareChartDialog> createState() =>
      _MessageShareChartDialogState();
}

class _MessageShareChartDialogState extends State<MessageShareChartDialog> {
  static const List<String> _popularSymbols = <String>[
    'NIFTY 50',
    'BANKNIFTY',
    'RELIANCE',
    'TCS',
    'NVDA',
    'AAPL',
    'BTC/USD',
    'ETH/USD',
  ];

  static const List<String> _timeframes = <String>[
    '5m',
    '15m',
    '1H',
    '1D',
    '1W',
  ];

  static const List<String> _patterns = <String>[
    'Bullish Breakout',
    'Support Rebound',
    'Consolidation Range',
    'Moving Average Cross',
    'Bearish Breakdown',
  ];

  late final TextEditingController _symbolController;
  late final TextEditingController _notesController;
  String _selectedTimeframe = '15m';
  String _selectedPattern = 'Bullish Breakout';
  List<UiCandle> _candles = <UiCandle>[];

  @override
  void initState() {
    super.initState();
    _symbolController = TextEditingController(text: 'NIFTY 50');
    _notesController = TextEditingController();
    _symbolController.addListener(_onFormUpdated);
    _regenerateCandles();
  }

  @override
  void dispose() {
    _symbolController.removeListener(_onFormUpdated);
    _symbolController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onFormUpdated() {
    if (!mounted) return;
    setState(() => _regenerateCandles());
  }

  double _basePriceFor(String symbol) {
    final s = symbol.toUpperCase().trim();
    if (s.contains('BANKNIFTY')) return 52400.0;
    if (s.contains('NIFTY')) return 24350.0;
    if (s.contains('RELIANCE')) return 2980.0;
    if (s.contains('TCS')) return 3950.0;
    if (s.contains('NVDA')) return 138.5;
    if (s.contains('AAPL')) return 232.0;
    if (s.contains('BTC')) return 94250.0;
    if (s.contains('ETH')) return 3480.0;
    return 1500.0;
  }

  void _regenerateCandles() {
    final String symbol = _symbolController.text.trim();
    final double base = _basePriceFor(symbol);
    final List<UiCandle> result = <UiCandle>[];
    final DateTime now = DateTime.now();

    double current = base;
    final int count = 22;
    final math.Random rng = math.Random(symbol.hashCode ^ _selectedPattern.hashCode);

    for (int i = 0; i < count; i++) {
      final double volatility = base * 0.004;
      double delta = (rng.nextDouble() - 0.48) * volatility;

      // Inject pattern momentum into final 5 candles
      if (_selectedPattern == 'Bullish Breakout' && i >= count - 5) {
        delta = (rng.nextDouble() * 0.7 + 0.3) * volatility;
      } else if (_selectedPattern == 'Bearish Breakdown' && i >= count - 5) {
        delta = -(rng.nextDouble() * 0.7 + 0.3) * volatility;
      } else if (_selectedPattern == 'Support Rebound') {
        if (i == count - 6) delta = -volatility * 1.5;
        if (i >= count - 4) delta = (rng.nextDouble() * 0.6 + 0.2) * volatility;
      }

      final double open = current;
      final double close = open + delta;
      final double high = math.max(open, close) + rng.nextDouble() * volatility * 0.6;
      final double low = math.min(open, close) - rng.nextDouble() * volatility * 0.6;
      final double volume = 1000 + rng.nextDouble() * 5000;

      result.add(
        UiCandle(
          time: now.subtract(Duration(minutes: (count - i) * 15)),
          open: double.parse(open.toStringAsFixed(2)),
          high: double.parse(high.toStringAsFixed(2)),
          low: double.parse(low.toStringAsFixed(2)),
          close: double.parse(close.toStringAsFixed(2)),
          volume: double.parse(volume.toStringAsFixed(0)),
        ),
      );
      current = close;
    }
    _candles = result;
  }

  void _selectPreset(String s) {
    _symbolController.text = s;
    setState(() => _regenerateCandles());
  }

  void _submit() {
    final String symbol = _symbolController.text.trim().toUpperCase();
    if (symbol.isEmpty || _candles.isEmpty) return;

    final MessageAttachment attachment = MessageAttachment(
      id: 'att_chart_${DateTime.now().microsecondsSinceEpoch}',
      kind: MessageAttachmentKind.chart,
      title: '$symbol · $_selectedTimeframe',
      subtitle: _selectedPattern,
      candles: _candles,
      timeframe: _selectedTimeframe,
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
    final bool isMobile = context.uiRes.isMobile;

    final double lastClose = _candles.isNotEmpty ? _candles.last.close : 0.0;
    final double firstOpen = _candles.isNotEmpty ? _candles.first.open : 0.0;
    final double changePct = firstOpen > 0 ? ((lastClose - firstOpen) / firstOpen) * 100 : 0.0;
    final bool isBullish = changePct >= 0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: context.sz(580),
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
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.candlestick_chart_rounded,
                    color: colors.primary,
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
                        'Share Technical Chart',
                        style: context.uiText.heading.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: context.fs(17),
                        ),
                      ),
                      Text(
                        'Generate an interactive chart setup to share in chat',
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

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Symbol input + presets
                  Text(
                    'Symbol / Instrument',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.foregroundMuted,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  UiInput(
                    controller: _symbolController,
                    hintText: 'e.g. NIFTY 50, RELIANCE, BTC/USD',
                    trailing: Icon(
                      Icons.search_rounded,
                      size: context.sz(18),
                      color: colors.foregroundMuted,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  Wrap(
                    spacing: context.sp(theme.spacing.xs),
                    runSpacing: context.sp(theme.spacing.xxs),
                    children: _popularSymbols.map((s) {
                      final bool isSelected =
                          _symbolController.text.trim().toUpperCase() == s;
                      return GestureDetector(
                        onTap: () => _selectPreset(s),
                        child: UiBadge(
                          label: s,
                          variant: isSelected
                              ? UiBadgeVariant.solid
                              : UiBadgeVariant.soft,
                          intent: isSelected
                              ? UiIntent.primary
                              : UiIntent.neutral,
                          size: UiSize.xs,
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: context.sp(theme.spacing.md)),

                  // Timeframe & Pattern selectors
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Timeframe',
                              style: context.uiText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.foregroundMuted,
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.xxs)),
                            Wrap(
                              spacing: context.sp(theme.spacing.xs),
                              children: _timeframes.map((tf) {
                                final bool isSel = _selectedTimeframe == tf;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedTimeframe = tf;
                                      _regenerateCandles();
                                    });
                                  },
                                  child: UiBadge(
                                    label: tf,
                                    variant: isSel
                                        ? UiBadgeVariant.solid
                                        : UiBadgeVariant.soft,
                                    intent: isSel
                                        ? UiIntent.primary
                                        : UiIntent.neutral,
                                    size: UiSize.xs,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: context.sp(theme.spacing.md)),

                  // Technical Pattern
                  Text(
                    'Setup / Pattern',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.foregroundMuted,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Wrap(
                    spacing: context.sp(theme.spacing.xs),
                    runSpacing: context.sp(theme.spacing.xxs),
                    children: _patterns.map((p) {
                      final bool isSel = _selectedPattern == p;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPattern = p;
                            _regenerateCandles();
                          });
                        },
                        child: UiBadge(
                          label: p,
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

                  // Live Chart Preview Card
                  UiCard(
                    accentColor: isBullish ? colors.success : colors.destructive,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              _symbolController.text.trim().isEmpty
                                  ? 'CHART PREVIEW'
                                  : _symbolController.text.trim().toUpperCase(),
                              style: context.uiText.bodyStrong.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            UiBadge(
                              label: _selectedTimeframe,
                              variant: UiBadgeVariant.soft,
                              intent: UiIntent.info,
                              size: UiSize.xs,
                            ),
                            const Spacer(),
                            Text(
                              lastClose.toStringAsFixed(2),
                              style: context.uiText.bodyStrong.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            UiBadge(
                              label: '${isBullish ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                              intent: isBullish ? UiIntent.success : UiIntent.danger,
                              size: UiSize.xs,
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.xs)),
                        if (_candles.isNotEmpty)
                          UiCandleChart(
                            candles: _candles,
                            height: isMobile ? 130 : 160,
                            showVolume: true,
                          )
                        else
                          SizedBox(
                            height: context.sz(140),
                            child: const Center(child: UiProgressCircle()),
                          ),
                      ],
                    ),
                  ),

                  SizedBox(height: context.sp(theme.spacing.md)),

                  // Notes / Commentary
                  Text(
                    'Notes / Analysis (Optional)',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.foregroundMuted,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  UiTextarea(
                    controller: _notesController,
                    hintText: 'e.g. Breakout retest verified, looking for continuation target.',
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
                  label: 'Share Chart',
                  icon: Icons.send_rounded,
                  variant: UiVariant.solid,
                  intent: UiIntent.primary,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
