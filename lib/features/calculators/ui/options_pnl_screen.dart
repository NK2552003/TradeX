import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/options_calculators.dart';
import '../services/market_data_service.dart';

/// Options P&L — one leg, held to expiry, drawn as the hockey stick it is.
///
/// The premium is certain and the payoff is not, so the screen leads with the
/// breakeven, keeps the payoff curve beside a grid of expiry prices, and marks
/// where the live spot sits on the way there.
class OptionsPnlCalculatorScreen extends StatefulWidget {
  const OptionsPnlCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<OptionsPnlCalculatorScreen> createState() =>
      _OptionsPnlCalculatorScreenState();
}

class _OptionsPnlCalculatorScreenState
    extends State<OptionsPnlCalculatorScreen> {
  String _symbol = 'NIFTY';
  bool _isBuy = true;
  bool _isCall = true;
  double _strike = 23900;
  double _premium = 120;
  double _lots = 2;
  double _lotSize = 75;
  double _spot = 23901.60;
  bool _isLive = false;

  static const Map<String, (double, int)> _symbolMeta = <String, (double, int)>{
    'NIFTY': (75, 50),
    'BANKNIFTY': (35, 100),
    'FINNIFTY': (65, 50),
    'SENSEX': (20, 100),
  };

  @override
  void initState() {
    super.initState();
    _fetchLiveSpot(_symbol);
  }

  Future<void> _fetchLiveSpot(String sym) async {
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(sym);
      if (!mounted) return;
      final int step = _symbolMeta[sym]?.$2 ?? 50;
      final double atm = (q.price / step).roundToDouble() * step;
      setState(() {
        _symbol = sym;
        _spot = q.price;
        _strike = atm;
        _lotSize = _symbolMeta[sym]?.$1 ?? _lotSize;
        _isLive = q.isLive;
      });
    } catch (_) {}
  }

  double _perShareAt(double s) {
    final double intrinsic = _isCall
        ? (s - _strike > 0 ? s - _strike : 0)
        : (_strike - s > 0 ? _strike - s : 0);
    return _isBuy ? intrinsic - _premium : _premium - intrinsic;
  }

  @override
  Widget build(BuildContext context) {
    final OptionsPnlResult r = calcOptionsPnl(
      isBuy: _isBuy,
      isCall: _isCall,
      strike: _strike,
      premium: _premium,
      lots: _lots,
      lotSize: _lotSize,
    );
    final double qty = _lots * _lotSize;
    final double intrinsicNow = _isCall
        ? (_spot - _strike > 0 ? _spot - _strike : 0)
        : (_strike - _spot > 0 ? _strike - _spot : 0);
    final double atSpot = _perShareAt(_spot) * qty;
    final double toBreakeven = (r.breakeven - _spot).abs();
    final bool itm = intrinsicNow > 0;
    final String label =
        '${_isBuy ? 'Long' : 'Short'} ${_isCall ? 'call' : 'put'}';
    final List<double> curve = <double>[
      for (final (double, double) p in r.payoff) p.$2,
    ];
    final double lo = <double>[
      _strike,
      r.breakeven,
      _spot,
    ].reduce((double a, double b) => a < b ? a : b);
    final double hi = <double>[
      _strike,
      r.breakeven,
      _spot,
    ].reduce((double a, double b) => a > b ? a : b);
    final double pad = (hi - lo) * 0.35 + _premium;
    final List<double> grid = <double>[
      _strike * 0.90,
      _strike * 0.95,
      _strike * 0.98,
      _strike,
      _strike * 1.02,
      _strike * 1.05,
      _strike * 1.10,
    ];

    return AppCalculatorLayout(
      meta: calculatorMetaById('options_pnl'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Breakeven at expiry',
        value: AppTokens.money(r.breakeven, decimals: 1),
        intent: itm ? UiIntent.bullish : UiIntent.primary,
        tag: label,
        tagIntent: _isBuy ? UiIntent.info : UiIntent.warning,
        footnote:
            '${AppTokens.money(toBreakeven, decimals: 1)} '
            '${r.breakeven > _spot ? 'above' : 'below'} spot — '
            '${AppTokens.percent(_spot <= 0 ? 0 : toBreakeven / _spot * 100, decimals: 2)} '
            'of the index.',
      ),
      stats: <UiStat>[
        UiStat(
          label: _isBuy ? 'Premium paid' : 'Premium received',
          value: AppTokens.price(r.premiumPaid),
          intent: _isBuy ? UiIntent.bearish : UiIntent.bullish,
          hint: '${AppTokens.money(_premium)} × ${AppTokens.count(qty)}',
        ),
        UiStat(
          label: 'Max profit',
          value: r.isUnlimitedProfit
              ? 'Unlimited'
              : AppTokens.price(r.maxProfit),
          intent: UiIntent.bullish,
          hint: r.isUnlimitedProfit ? 'no cap above' : 'premium kept',
        ),
        UiStat(
          label: 'Max loss',
          value: AppTokens.signedMoney(-r.maxLoss.abs(), decimals: 0),
          intent: UiIntent.bearish,
          hint: _isBuy ? 'the premium' : 'uncapped beyond',
        ),
        UiStat(
          label: 'Intrinsic now',
          value: AppTokens.money(intrinsicNow),
          intent: itm ? UiIntent.bullish : UiIntent.neutral,
          hint: itm ? 'in the money' : 'out of the money',
        ),
        UiStat(
          label: 'If expiry were now',
          value: AppTokens.signedMoney(atSpot, decimals: 0),
          intent: AppTokens.plIntent(atSpot),
          hint: 'at ${AppTokens.money(_spot, decimals: 0)}',
        ),
        UiStat(
          label: 'Contracts',
          value: AppTokens.count(qty),
          hint:
              '${_lots.toStringAsFixed(0)} × '
              '${AppTokens.count(_lotSize)}',
          spark: curve,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Leg',
          hint: 'what is being taken on',
          children: <Widget>[
            AppCalcSegment<bool>(
              label: 'Side',
              value: _isBuy,
              onChanged: (bool v) => setState(() => _isBuy = v),
              helper: _isBuy
                  ? 'Loss capped at the premium, upside open.'
                  : 'Gain capped at the premium, loss open.',
              options: const <UiToggleOption<bool>>[
                UiToggleOption<bool>(value: true, label: 'Buy'),
                UiToggleOption<bool>(value: false, label: 'Sell'),
              ],
            ),
            AppCalcSegment<bool>(
              label: 'Type',
              value: _isCall,
              onChanged: (bool v) => setState(() => _isCall = v),
              options: const <UiToggleOption<bool>>[
                UiToggleOption<bool>(value: true, label: 'Call'),
                UiToggleOption<bool>(value: false, label: 'Put'),
              ],
            ),
            AppCalcNumberField(
              label: 'Strike',
              value: _strike,
              prefix: '₹',
              decimals: 0,
              onChanged: (double v) => setState(() => _strike = v),
            ),
            AppCalcNumberField(
              label: 'Premium',
              value: _premium,
              prefix: '₹',
              helper: 'Per share, as quoted.',
              onChanged: (double v) => setState(() => _premium = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Size and spot',
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: context.sp(context.ui.spacing.xs),
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'Live Spot: ₹${AppTokens.price(_spot)}'
                      : 'Preset Spot: ₹${AppTokens.price(_spot)}',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),

                UiButton(
                  label: 'Sync Spot',
                  leadingIcon: Icons.refresh,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: () => _fetchLiveSpot(_symbol),
                ),
              ],
            ),
            AppCalcSegment<String>(
              label: 'Symbol',
              value: _symbol,
              onChanged: (String s) => _fetchLiveSpot(s),
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'NIFTY', label: 'Nifty'),
                UiToggleOption<String>(value: 'BANKNIFTY', label: 'Bank'),
                UiToggleOption<String>(value: 'FINNIFTY', label: 'Fin'),
                UiToggleOption<String>(value: 'SENSEX', label: 'Sensex'),
              ],
            ),
            AppCalcSliderField(
              label: 'Lots',
              value: _lots,
              min: 1,
              max: 20,
              divisions: 19,
              valueFormatter: (num v) => '${v.round()}',
              onChanged: (double v) =>
                  setState(() => _lots = v.roundToDouble()),
            ),
            AppCalcNumberField(
              label: 'Lot size',
              value: _lotSize,
              decimals: 0,
              presets: const <double>[75, 35, 65, 20],
              presetLabel: (double v) => v.toStringAsFixed(0),
              onChanged: (double v) => setState(() => _lotSize = v),
            ),
            AppCalcNumberField(
              label: 'Spot price',
              value: _spot,
              prefix: '₹',
              decimals: 0,
              helper: itm ? 'In the money now.' : 'Out of the money now.',
              onChanged: (double v) => setState(() => _spot = v),
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Expiry grid',
          hint: 'per position',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Expiry price',
            valueHeader: 'Net P&L',
            trailingHeader: 'Per share',
            rows: <UiKeyValueRow>[
              for (final double s in grid)
                UiKeyValueRow(
                  label: AppTokens.money(s, decimals: 0),
                  value: AppTokens.signedMoney(
                    _perShareAt(s) * qty,
                    decimals: 0,
                  ),
                  trailing: AppTokens.signedMoney(_perShareAt(s), decimals: 1),
                  intent: AppTokens.plIntent(_perShareAt(s)),
                  detail: s == _strike
                      ? 'At the strike — intrinsic is nil'
                      : null,
                  emphasis: s == _strike,
                ),
              UiKeyValueRow(
                label: 'Breakeven',
                value: '—',
                trailing: AppTokens.money(r.breakeven, decimals: 1),
                intent: UiIntent.warning,
                emphasis: true,
                detail: 'Strike ${_isCall ? '+' : '−'} premium',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Payoff at expiry',
          hint: '±20% of strike',
          wide: true,
          child: AppCalcTrendChart(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Net P&L',
                values: curve,
                intent: _isBuy ? UiIntent.bullish : UiIntent.warning,
                area: true,
              ),
            ],
            thresholds: const <UiChartThreshold>[
              UiChartThreshold(value: 0, label: 'breakeven'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Strike ladder',
          hint: 'spot · strike · breakeven',
          kind: AppCalcPanelKind.meter,
          child: UiRangeMeter(
            min: lo - pad,
            max: hi + pad,
            valueFormatter: (num v) => AppTokens.money(v, decimals: 0),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: _isCall ? r.breakeven : lo - pad,
                end: _isCall ? hi + pad : r.breakeven,
                intent: _isBuy ? UiIntent.bullish : UiIntent.bearish,
                label: _isBuy ? 'profit' : 'assigned',
                alpha: 0.16,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(value: _spot, label: 'Spot', strong: true),
              UiRangeMarker(
                value: _strike,
                label: 'Strike',
                intent: UiIntent.info,
                below: true,
              ),
              UiRangeMarker(
                value: r.breakeven,
                label: 'Even',
                intent: UiIntent.warning,
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Premium into payoff',
          hint: 'at the live spot',
          kind: AppCalcPanelKind.meter,
          child: UiWaterfallChart(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            steps: <UiWaterfallStep>[
              UiWaterfallStep(
                label: 'Intrinsic',
                value: intrinsicNow * qty * (_isBuy ? 1 : -1),
              ),
              UiWaterfallStep(
                label: 'Premium',
                value: r.premiumPaid * (_isBuy ? -1 : 1),
              ),
              UiWaterfallStep(label: 'Net', value: atSpot, isTotal: true),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (!_isBuy)
          UiCallout(
            intent: UiIntent.warning,
            title: 'Written options carry open risk',
            message:
                'The best case is the ${AppTokens.price(r.premiumPaid)} premium; '
                'the worst case is not bounded on this side. Margin is blocked '
                'and marked to market daily.',
          ),
        if (_isBuy && !itm)
          UiCallout(
            intent: UiIntent.info,
            title: 'Entirely time value',
            message:
                'With spot at ${AppTokens.money(_spot, decimals: 0)} the option '
                'has no intrinsic value. It needs '
                '${AppTokens.money(toBreakeven, decimals: 0)} of movement '
                'before expiry simply to return the premium.',
          ),
      ],
      formula:
          'Qty = Lots × Lot size\n'
          'Premium = Premium × Qty\n'
          'Call breakeven = Strike + Premium\n'
          'Put breakeven = Strike − Premium\n'
          'Payoff = (Intrinsic − Premium) × Qty, reversed when written',
      notes: const <String>[
        'The curve is expiry payoff, not the live mark. Before expiry the '
            'position also carries time value, which the option pricing tool '
            'covers.',
        'A bought option cannot lose more than its premium. A written one can, '
            'which is why the exchange blocks margin for it.',
        'Breakeven ignores charges and any slippage on entry — both push it '
            'further away.',
        'Indian index options are cash settled, so nothing is delivered at the '
            'strike; the difference is credited.',
      ],
    );
  }
}
