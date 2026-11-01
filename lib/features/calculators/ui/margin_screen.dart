import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/options_calculators.dart';
import '../logic/trading_calculators.dart';
import '../services/market_data_service.dart';
import 'calculator_journal_draft.dart';

/// Margin — the capital an exchange blocks to let you carry a contract, and
/// what a hedge does to that number.
///
/// Notional is the position; margin is the deposit. The gap between them is
/// leverage, so the screen shows both, the SPAN relief a hedged leg earns, and
/// how many lots the account can actually carry.
class MarginCalculatorScreen extends StatefulWidget {
  const MarginCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<MarginCalculatorScreen> createState() => _MarginCalculatorScreenState();
}

class _MarginCalculatorScreenState extends State<MarginCalculatorScreen> {
  static const Map<String, double> _lotSizes = <String, double>{
    'NIFTY': 75,
    'BANKNIFTY': 35,
    'FINNIFTY': 65,
    'STOCK': 250,
  };
  static const Map<String, double> _spots = <String, double>{
    'NIFTY': 23901.60,
    'BANKNIFTY': 57382.60,
    'FINNIFTY': 23400,
    'STOCK': 1313.80,
  };

  String _symbol = 'NIFTY';
  int _lots = 2;
  double _lotSize = 75;
  double _price = 23901.60;
  bool _hedged = false;
  double _capital = 500000;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveQuote(_symbol);
  }

  Future<void> _fetchLiveQuote(String sym) async {
    final String query = sym == 'STOCK' ? 'RELIANCE' : sym;
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(query);
      if (!mounted) return;
      setState(() {
        _price = q.price;
        _isLive = q.isLive;
      });
    } catch (_) {}
  }

  void _pickSymbol(String v) {
    setState(() {
      _symbol = v;
      _lotSize = _lotSizes[v] ?? _lotSize;
      _price = _spots[v] ?? _price;
    });
    _fetchLiveQuote(v);
  }

  @override
  Widget build(BuildContext context) {
    final SpanResult s = calcSpanMargin(
      symbol: _symbol,
      spotPrice: _price,
      lotSize: _lotSize,
      lots: _lots,
      isHedged: _hedged,
    );
    final MarginResult m = calcMargin(
      lots: _lots.toDouble(),
      lotSize: _lotSize,
      price: _price,
      marginPct: s.marginPct,
    );
    final double required = _hedged ? s.hedgedMargin : s.nakedMargin;
    final double perLot = _lots <= 0 ? 0 : required / _lots;
    final double utilPct = _capital <= 0 ? 0 : required / _capital * 100;
    final double free = _capital - required;
    final int maxLots = perLot <= 0 ? 0 : (_capital / perLot).floor();
    final double saved = s.nakedMargin - s.hedgedMargin;

    // Margin against lot count — the curve is linear, which is the point: no
    // volume discount exists on a deposit.
    final List<double> nakedCurve = <double>[];
    final List<double> hedgedCurve = <double>[];
    for (int i = 1; i <= 8; i++) {
      final SpanResult x = calcSpanMargin(
        symbol: _symbol,
        spotPrice: _price,
        lotSize: _lotSize,
        lots: i,
        isHedged: true,
      );
      nakedCurve.add(x.nakedMargin);
      hedgedCurve.add(x.hedgedMargin);
    }

    return AppCalculatorLayout(
      actions: <Widget>[
        UiButton(
          label: 'History',
          leadingIcon: Icons.history_rounded,
          variant: UiVariant.ghost,
          size: UiSize.sm,
          onPressed: () => showCalculatorHistorySheet(context),
        ),
        UiButton(
          label: 'Log Trade',
          leadingIcon: Icons.book_outlined,
          variant: UiVariant.soft,
          size: UiSize.sm,
          onPressed: _lots > 0 && _lotSize > 0
              ? () => openCalculatorJournalDraft(
                  context,
                  symbol: _symbol == 'STOCK' ? 'RELIANCE' : _symbol,
                  entry: _price,
                  quantity: _lots * _lotSize,
                  calculatorId: 'margin',
                  calculatorName: 'Margin',
                  notes:
                      '$_lots lots (${_hedged ? 'Hedged' : 'Naked'}) · Margin blocked: ${AppTokens.lakhCrore(required)} (${m.leverage.toStringAsFixed(1)}× leverage)',
                )
              : null,
        ),
      ],
      meta: calculatorMetaById('margin'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Margin blocked',
        value: AppTokens.lakhCrore(required),
        intent: utilPct > 100 ? UiIntent.danger : UiIntent.primary,
        tag:
            '${_hedged ? 'hedged' : 'naked'} · ${_isLive ? 'Live LTP' : 'Ref'}',
        tagIntent: _isLive
            ? UiIntent.success
            : (_hedged ? UiIntent.bullish : UiIntent.warning),
        footnote:
            '$_lots ${_lots == 1 ? 'lot' : 'lots'} of $_symbol at '
            '${AppTokens.percent(s.marginPct)} of '
            '${AppTokens.lakhCrore(s.notional)} notional.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Notional',
          value: AppTokens.lakhCrore(s.notional),
          hint:
              '$_lots × ${AppTokens.count(_lotSize)} × '
              '${AppTokens.money(_price, decimals: 0)}',
        ),
        UiStat(
          label: 'Margin rate',
          value: AppTokens.percent(s.marginPct),
          hint: 'SPAN + exposure',
        ),
        UiStat(
          label: 'Per lot',
          value: AppTokens.price(perLot),
          hint: _hedged ? 'after hedge relief' : 'outright',
        ),
        UiStat(
          label: 'Leverage',
          value: '${m.leverage.toStringAsFixed(1)}×',
          intent: m.leverage > 8 ? UiIntent.warning : UiIntent.info,
          hint: 'notional ÷ margin',
        ),
        UiStat(
          label: 'Capital used',
          value: AppTokens.percent(utilPct),
          intent: utilPct > 100
              ? UiIntent.danger
              : utilPct > 60
              ? UiIntent.warning
              : UiIntent.bullish,
          hint: AppTokens.lakhCrore(_capital),
        ),
        UiStat(
          label: 'Lots affordable',
          value: AppTokens.count(maxLots),
          hint: 'on this balance',
          spark: nakedCurve,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Contract',
          hint: 'lot size follows the symbol',
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: context.sp(context.ui.spacing.xs),
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'Live LTP: ₹${AppTokens.price(_price)}'
                      : 'Reference: ₹${AppTokens.price(_price)}',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),

                UiButton(
                  label: 'Sync LTP',
                  leadingIcon: Icons.refresh,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: () => _fetchLiveQuote(_symbol),
                ),
              ],
            ),
            AppCalcSegment<String>(
              label: 'Symbol',
              value: _symbol,
              onChanged: _pickSymbol,
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'NIFTY', label: 'NIFTY'),
                UiToggleOption<String>(value: 'BANKNIFTY', label: 'BANKNF'),
                UiToggleOption<String>(value: 'FINNIFTY', label: 'FINNF'),
                UiToggleOption<String>(value: 'STOCK', label: 'Stock'),
              ],
            ),
            AppCalcNumberField(
              label: 'Spot / futures price',
              value: _price,
              prefix: '₹',
              decimals: 0,
              helper: _isLive ? 'Live spot from Yahoo Finance v8.' : null,
              onChanged: (double v) => setState(() => _price = v),
            ),
            AppCalcNumberField(
              label: 'Lot size',
              value: _lotSize,
              decimals: 0,
              helper: 'Exchange revises this each contract cycle.',
              onChanged: (double v) => setState(() => _lotSize = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Position',
          children: <Widget>[
            AppCalcSliderField(
              label: 'Lots',
              value: _lots.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              valueFormatter: (num v) => '${v.round()}',
              helper: 'Margin scales one for one with lots.',
              onChanged: (double v) => setState(() => _lots = v.round()),
            ),
            AppCalcSegment<bool>(
              label: 'Structure',
              value: _hedged,
              onChanged: (bool v) => setState(() => _hedged = v),
              helper: _hedged
                  ? 'Offsetting leg present — SPAN charges the spread.'
                  : 'Outright position — full SPAN plus exposure.',
              options: const <UiToggleOption<bool>>[
                UiToggleOption<bool>(value: false, label: 'Naked'),
                UiToggleOption<bool>(value: true, label: 'Hedged'),
              ],
            ),
            AppCalcNumberField(
              label: 'Account balance',
              value: _capital,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[200000, 500000, 1000000, 2500000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              onChanged: (double v) => setState(() => _capital = v),
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Margin ledger',
          hint: '$_lots ${_lots == 1 ? 'lot' : 'lots'}',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Component',
            valueHeader: 'Amount',
            trailingHeader: 'Of notional',
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'Notional value',
                value: AppTokens.price(s.notional),
                trailing: '100%',
                emphasis: true,
                detail: 'Price × lot size × lots',
              ),
              UiKeyValueRow(
                label: 'Naked margin',
                value: AppTokens.price(s.nakedMargin),
                trailing: AppTokens.percent(s.marginPct),
                intent: _hedged ? UiIntent.neutral : UiIntent.bearish,
                emphasis: !_hedged,
                share: (s.marginPct / 100).clamp(0.0, 1.0),
              ),
              UiKeyValueRow(
                label: 'Hedged margin',
                value: AppTokens.price(s.hedgedMargin),
                trailing: s.notional <= 0
                    ? '—'
                    : AppTokens.percent(s.hedgedMargin / s.notional * 100),
                intent: _hedged ? UiIntent.bullish : UiIntent.neutral,
                emphasis: _hedged,
                detail: 'Spread charge instead of two outrights',
              ),
              UiKeyValueRow(
                label: 'Hedge relief',
                value: AppTokens.price(saved),
                trailing: AppTokens.percent(s.savedPct, decimals: 0),
                intent: UiIntent.info,
                detail: 'Capital a protective leg releases',
              ),
              UiKeyValueRow(
                label: 'NRML (carry)',
                value: AppTokens.price(s.nrmlMargin),
                trailing: 'overnight',
              ),
              UiKeyValueRow(
                label: 'MIS (intraday)',
                value: AppTokens.price(s.misMargin),
                trailing: 'square off',
                detail: 'Broker relief, withdrawn near the close',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Margin against lots',
          hint: 'naked vs hedged',
          child: AppCalcTrendChart(
            labels: <String>[for (int i = 1; i <= 8; i++) '$i'],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Naked',
                values: nakedCurve,
                intent: UiIntent.bearish,
              ),
              AppCalcSeries(
                name: 'Hedged',
                values: hedgedCurve,
                intent: UiIntent.bullish,
                area: true,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _capital, label: 'balance'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Hedge relief',
          hint: AppTokens.percent(s.savedPct, decimals: 0),
          child: UiWaterfallChart(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            steps: <UiWaterfallStep>[
              UiWaterfallStep(label: 'Naked', value: s.nakedMargin),
              UiWaterfallStep(label: 'Relief', value: -saved),
              UiWaterfallStep(
                label: 'Hedged',
                value: s.hedgedMargin,
                isTotal: true,
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Balance after the block',
          hint: AppTokens.lakhCrore(_capital),
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            marker: (utilPct / 100).clamp(0.0, 1.0),
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: required.clamp(0.0, _capital <= 0 ? required : _capital),
                label: 'Blocked',
              ),
              UiCategorySegment(value: free < 0 ? 0 : free, label: 'Free'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Leverage on the position',
          hint: 'notional per rupee',
          kind: AppCalcPanelKind.meter,
          child: UiRangeMeter(
            min: 0,
            max: 12,
            minLabel: '0×',
            maxLabel: '12×',
            valueFormatter: (num v) => '${v.toStringAsFixed(1)}×',
            zones: const <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: 5,
                intent: UiIntent.bullish,
                label: 'measured',
                alpha: 0.14,
              ),
              UiRangeZone(
                start: 5,
                end: 8,
                intent: UiIntent.warning,
                label: 'stretched',
                alpha: 0.14,
              ),
              UiRangeZone(
                start: 8,
                end: 12,
                intent: UiIntent.bearish,
                label: 'thin',
                alpha: 0.14,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: m.leverage.clamp(0.0, 12.0),
                label: '${m.leverage.toStringAsFixed(1)}×',
                strong: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (utilPct > 100)
          UiCallout(
            intent: UiIntent.danger,
            title: 'Margin exceeds the balance',
            message:
                'This position needs ${AppTokens.lakhCrore(required)} against '
                '${AppTokens.lakhCrore(_capital)} available. The order will be '
                'rejected, or squared off on a shortfall penalty.',
          ),
        if (utilPct <= 100 && utilPct > 60)
          const UiCallout(
            intent: UiIntent.warning,
            title: 'Little room for a mark to market',
            message:
                'Above 60% utilisation an adverse move triggers a margin call '
                'before the stop is reached. Keep free cash for variation '
                'margin.',
          ),
        if (!_hedged && s.savedPct > 0)
          UiCallout(
            intent: UiIntent.info,
            title:
                'A hedge would free '
                '${AppTokens.percent(s.savedPct, decimals: 0)}',
            message:
                'Adding an offsetting leg cuts the block to '
                '${AppTokens.lakhCrore(s.hedgedMargin)} — '
                '${AppTokens.price(saved)} back in the account, at the cost of '
                'capping the upside.',
          ),
      ],
      formula:
          'Notional = Price × Lot size × Lots\n'
          'Margin = Notional × (SPAN% + Exposure%)\n'
          'Leverage = Notional ÷ Margin\n'
          'Lots affordable = ⌊Balance ÷ Margin per lot⌋',
      notes: const <String>[
        'Rates here are indicative index bands — 12% NIFTY, 14% BANKNIFTY, '
            '20% single stock. The exchange republishes SPAN through the day.',
        'A hedged pair is charged on the spread, not on both legs, which is why '
            'the relief is so large.',
        'MIS relief is a broker product, not an exchange rule, and is withdrawn '
            'before the close.',
        'Margin is blocked, not spent — it returns on exit, less any loss.',
      ],
    );
  }
}
