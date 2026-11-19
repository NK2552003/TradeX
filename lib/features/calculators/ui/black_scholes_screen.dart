import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/options_calculators.dart';
import '../services/market_data_service.dart';

/// Black–Scholes — what an option is worth, and which of its exposures is
/// actually driving that number.
///
/// The price alone is rarely the question. Delta, theta and vega are, so the
/// greeks sit in a table beside two sensitivity curves: value against spot, and
/// value against the days that remain.
class BlackScholesCalculatorScreen extends StatefulWidget {
  const BlackScholesCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<BlackScholesCalculatorScreen> createState() =>
      _BlackScholesCalculatorScreenState();
}

class _BlackScholesCalculatorScreenState
    extends State<BlackScholesCalculatorScreen> {
  String _symbol = 'NIFTY';
  double _spot = 23901.60;
  double _strike = 23900;
  double _days = 7;
  double _iv = 14;
  double _rf = 6.82;
  double _lotSize = 75;
  bool _isCall = true;
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
    _fetchLiveSpotAndRf(_symbol);
  }

  Future<void> _fetchLiveSpotAndRf(String sym) async {
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(sym);
      final MacroBenchmarks b = await MarketDataService.instance
          .getMacroBenchmarks();
      if (!mounted) return;
      final int step = _symbolMeta[sym]?.$2 ?? 50;
      final double atm = (q.price / step).roundToDouble() * step;
      setState(() {
        _symbol = sym;
        _spot = q.price;
        _strike = atm;
        _lotSize = _symbolMeta[sym]?.$1 ?? _lotSize;
        _rf = b.gSec10YYield;
        _isLive = q.isLive;
      });
    } catch (_) {}
  }

  BlackScholesResult _at({double? spot, double? days, double? iv}) =>
      calcBlackScholes(
        spot: spot ?? _spot,
        strike: _strike,
        daysToExpiry: days ?? _days,
        ivPct: iv ?? _iv,
        rfRate: _rf,
        isCall: _isCall,
      );

  @override
  Widget build(BuildContext context) {
    final BlackScholesResult r = _at();
    final double moneyness = _strike <= 0
        ? 0
        : (_spot - _strike) / _strike * 100;
    final bool itm = r.intrinsic > 0;
    final double timeShare = r.price <= 0 ? 0 : r.timeValue / r.price * 100;
    final double thetaPerLot = r.theta * _lotSize;
    final double perLot = r.price * _lotSize;
    final double thetaShare = r.price <= 0 ? 0 : r.theta.abs() / r.price * 100;

    // Value against spot, ±4% in half-percent steps.
    final List<double> spotCurve = <double>[
      for (int i = -8; i <= 8; i++) _at(spot: _spot * (1 + i / 200)).price,
    ];
    // Value against the calendar, from today to expiry.
    final int decaySteps = _days < 1 ? 1 : _days.round();
    final List<double> decayCurve = <double>[
      for (int d = decaySteps; d >= 0; d--) _at(days: d.toDouble()).price,
    ];
    final List<double> ivCurve = <double>[
      for (int i = 0; i <= 8; i++) _at(iv: 6 + i * 3).price,
    ];
    final double pad = _spot * 0.01 + 1;
    final double beAtExpiry = _isCall ? _strike + r.price : _strike - r.price;
    final double meterLo = <double>[
      _spot,
      _strike,
      beAtExpiry,
    ].reduce((double a, double b) => a < b ? a : b);
    final double meterHi = <double>[
      _spot,
      _strike,
      beAtExpiry,
    ].reduce((double a, double b) => a > b ? a : b);

    return AppCalculatorLayout(
      meta: calculatorMetaById('black_scholes'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Theoretical premium',
        value: AppTokens.money(r.price),
        unit: 'per share',
        intent: UiIntent.primary,
        tag: itm ? 'in the money' : 'out of the money',
        tagIntent: itm ? UiIntent.bullish : UiIntent.neutral,
        footnote:
            '${AppTokens.money(r.intrinsic)} intrinsic and '
            '${AppTokens.money(r.timeValue)} time value — '
            '${AppTokens.percent(timeShare, decimals: 0)} of the price decays '
            'over ${_days.toStringAsFixed(0)} days.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Delta',
          value: r.delta.toStringAsFixed(3),
          intent: r.delta >= 0 ? UiIntent.bullish : UiIntent.bearish,
          hint: '${AppTokens.money(r.delta * _lotSize)} a point, per lot',
        ),
        UiStat(
          label: 'Theta',
          value: r.theta.toStringAsFixed(2),
          intent: UiIntent.bearish,
          hint: '${AppTokens.money(thetaPerLot, decimals: 0)} a day, per lot',
        ),
        UiStat(
          label: 'Vega',
          value: r.vega.toStringAsFixed(2),
          intent: UiIntent.info,
          hint: 'per 1 point of IV',
        ),
        UiStat(
          label: 'Gamma',
          value: r.gamma.toStringAsFixed(5),
          hint: 'delta drift per point',
        ),
        UiStat(
          label: 'Time value',
          value: AppTokens.money(r.timeValue),
          intent: timeShare > 60 ? UiIntent.warning : UiIntent.neutral,
          hint: '${AppTokens.percent(timeShare, decimals: 0)} of premium',
          spark: decayCurve,
        ),
        UiStat(
          label: 'Per lot',
          value: AppTokens.price(perLot),
          hint: '${AppTokens.count(_lotSize)} × premium',
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Contract',
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: context.sp(context.ui.spacing.xs),
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'Live Spot & 10Y Yield'
                      : 'Preset Spot & Yield',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),

                UiButton(
                  label: 'Sync Live',
                  leadingIcon: Icons.refresh,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: () => _fetchLiveSpotAndRf(_symbol),
                ),
              ],
            ),
            AppCalcSegment<String>(
              label: 'Symbol',
              value: _symbol,
              onChanged: (String s) => _fetchLiveSpotAndRf(s),
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'NIFTY', label: 'Nifty'),
                UiToggleOption<String>(value: 'BANKNIFTY', label: 'Bank'),
                UiToggleOption<String>(value: 'FINNIFTY', label: 'Fin'),
                UiToggleOption<String>(value: 'SENSEX', label: 'Sensex'),
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
              label: 'Spot price',
              value: _spot,
              prefix: '₹',
              decimals: 0,
              onChanged: (double v) => setState(() => _spot = v),
            ),
            AppCalcNumberField(
              label: 'Strike',
              value: _strike,
              prefix: '₹',
              decimals: 0,
              helper:
                  'Moneyness '
                  '${AppTokens.signedPercent(moneyness, decimals: 2)}.',
              onChanged: (double v) => setState(() => _strike = v),
            ),
            AppCalcNumberField(
              label: 'Lot size',
              value: _lotSize,
              decimals: 0,
              presets: const <double>[75, 35, 65, 20],
              presetLabel: (double v) => v.toStringAsFixed(0),
              onChanged: (double v) => setState(() => _lotSize = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Market',
          hint: 'time and volatility do the work',
          children: <Widget>[
            AppCalcSliderField(
              label: 'Days to expiry',
              value: _days,
              min: 0,
              max: 60,
              divisions: 60,
              intent: _days <= 3 ? UiIntent.warning : UiIntent.primary,
              valueFormatter: (num v) => '${v.round()} d',
              helper: _days <= 3
                  ? 'Decay is steepest in the final sessions.'
                  : null,
              onChanged: (double v) => setState(() => _days = v),
            ),
            AppCalcSliderField(
              label: 'Implied volatility',
              value: _iv,
              min: 5,
              max: 60,
              divisions: 55,
              intent: UiIntent.info,
              valueFormatter: (num v) => AppTokens.percent(v, decimals: 0),
              helper:
                  'Vega says '
                  '${AppTokens.money(r.vega)} a point.',
              onChanged: (double v) => setState(() => _iv = v),
            ),
            AppCalcNumberField(
              label: 'Risk-free rate',
              value: _rf,
              suffix: '%',
              decimals: 2,
              onChanged: (double v) => setState(() => _rf = v),
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'The greeks',
          hint: 'per share, then per lot',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiKeyValueTable(
            labelHeader: 'Exposure',
            valueHeader: 'Value',
            trailingHeader: 'Per lot',
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'Delta',
                value: r.delta.toStringAsFixed(4),
                trailing: AppTokens.money(r.delta * _lotSize, decimals: 0),
                intent: r.delta >= 0 ? UiIntent.bullish : UiIntent.bearish,
                detail: 'Premium moves this much for one point of spot',
                emphasis: true,
              ),
              UiKeyValueRow(
                label: 'Gamma',
                value: r.gamma.toStringAsFixed(5),
                trailing: (r.gamma * _lotSize).toStringAsFixed(3),
                detail: 'How fast delta itself changes',
              ),
              UiKeyValueRow(
                label: 'Theta',
                value: r.theta.toStringAsFixed(3),
                trailing: AppTokens.money(thetaPerLot, decimals: 0),
                intent: UiIntent.bearish,
                detail: 'Given up each day the position is held',
                emphasis: true,
              ),
              UiKeyValueRow(
                label: 'Vega',
                value: r.vega.toStringAsFixed(3),
                trailing: AppTokens.money(r.vega * _lotSize, decimals: 0),
                intent: UiIntent.info,
                detail: 'Per one point of implied volatility',
              ),
              UiKeyValueRow(
                label: 'Rho',
                value: r.rho.toStringAsFixed(4),
                trailing: AppTokens.money(r.rho * _lotSize, decimals: 0),
                detail: 'Per one point of the risk-free rate',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Spot ladder',
          hint: 'premium at nearby prices',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Spot',
            valueHeader: 'Premium',
            trailingHeader: 'Change',
            rows: <UiKeyValueRow>[
              for (final double m in const <double>[
                -0.02,
                -0.01,
                -0.005,
                0,
                0.005,
                0.01,
                0.02,
              ])
                UiKeyValueRow(
                  label: AppTokens.money(_spot * (1 + m), decimals: 0),
                  value: AppTokens.money(_at(spot: _spot * (1 + m)).price),
                  trailing: AppTokens.signedMoney(
                    _at(spot: _spot * (1 + m)).price - r.price,
                    decimals: 1,
                  ),
                  intent: AppTokens.plIntent(
                    _at(spot: _spot * (1 + m)).price - r.price,
                  ),
                  emphasis: m == 0,
                  detail: m == 0
                      ? 'The live spot'
                      : '${AppTokens.signedPercent(m * 100, decimals: 1)} of spot',
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Value against spot',
          hint: '±4% of the live price',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (int i = -8; i <= 8; i++) i % 4 == 0 ? '${i / 2}%' : '',
            ],
            valueFormatter: (num v) => AppTokens.money(v, decimals: 0),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Premium',
                values: spotCurve,
                intent: _isCall ? UiIntent.bullish : UiIntent.bearish,
                area: true,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: r.price, label: 'now'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Decay to expiry',
          hint: '${_days.toStringAsFixed(0)} days, spot held still',
          child: AppCalcTrendChart(
            valueFormatter: (num v) => AppTokens.money(v, decimals: 0),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Premium',
                values: decayCurve,
                intent: UiIntent.warning,
                area: true,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: r.intrinsic, label: 'intrinsic'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Value against volatility',
          hint: '6% → 30% IV',
          child: AppCalcTrendChart(
            labels: <String>[
              for (int i = 0; i <= 8; i++) i % 2 == 0 ? '${6 + i * 3}%' : '',
            ],
            valueFormatter: (num v) => AppTokens.money(v, decimals: 0),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Premium',
                values: ivCurve,
                intent: UiIntent.info,
                area: true,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: r.price, label: 'at $_iv%'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Intrinsic against time value',
          hint: 'what the premium is made of',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: r.intrinsic,
                label: 'Intrinsic ${AppTokens.money(r.intrinsic)}',
              ),
              UiCategorySegment(
                value: r.timeValue,
                label: 'Time ${AppTokens.money(r.timeValue)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Moneyness',
          hint: 'spot · strike · expiry breakeven',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: meterLo - pad,
            max: meterHi + pad,
            valueFormatter: (num v) => AppTokens.money(v, decimals: 0),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: _isCall ? _strike : meterLo - pad,
                end: _isCall ? meterHi + pad : _strike,
                intent: UiIntent.bullish,
                label: 'in the money',
                alpha: 0.14,
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
                value: beAtExpiry,
                label: 'Even',
                intent: UiIntent.warning,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (_days <= 3 && thetaShare > 8)
          UiCallout(
            intent: UiIntent.warning,
            title: 'Theta is taking the premium apart',
            message:
                'At ${_days.toStringAsFixed(0)} days the position gives up '
                '${AppTokens.percent(thetaShare, decimals: 1)} of its value a '
                'day — ${AppTokens.money(thetaPerLot.abs(), decimals: 0)} per '
                'lot. Spot has to move for the buyer simply to stand still.',
          ),
        if (r.intrinsic <= 0)
          UiCallout(
            intent: UiIntent.info,
            title: 'Entirely time value',
            message:
                'Spot at ${AppTokens.money(_spot, decimals: 0)} leaves this '
                'contract with no intrinsic value. Every rupee of the '
                '${AppTokens.money(r.price)} premium expires unless price '
                'clears ${AppTokens.money(beAtExpiry, decimals: 0)}.',
          ),
        if (_iv >= 35)
          UiCallout(
            intent: UiIntent.danger,
            title: 'Volatility is priced high',
            message:
                'At ${AppTokens.percent(_iv, decimals: 0)} IV the model is '
                'charging ${AppTokens.money(r.vega * 10)} for every ten points '
                'of volatility. A drop after the event, with spot unchanged, '
                'still loses money.',
          ),
      ],
      formula:
          'd₁ = [ln(S ÷ K) + (r + σ² ÷ 2)·t] ÷ (σ·√t)\n'
          'd₂ = d₁ − σ·√t\n'
          'Call = S·N(d₁) − K·e^(−r·t)·N(d₂)\n'
          'Put  = K·e^(−r·t)·N(−d₂) − S·N(−d₁)\n'
          'Time value = Premium − Intrinsic',
      notes: const <String>[
        'The model assumes European exercise, no dividends and constant '
            'volatility. Indian index options are European and cash settled, so '
            'the first two hold; the third never does.',
        'Theta is quoted per calendar day, not per session. A weekend costs two '
            'days of decay and delivers no chance to trade out of it.',
        'Vega is per one point of implied volatility. Around an event the IV '
            'move usually matters more than the move in spot.',
        'Implied volatility is an input here, not an output. Feed it the '
            'market’s own number — a theoretical price built on a guessed IV '
            'only tells you about the guess.',
      ],
    );
  }
}
