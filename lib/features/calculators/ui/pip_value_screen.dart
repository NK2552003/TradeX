import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/currency_calculators.dart';
import '../services/currency_rate_service.dart';

/// Pip value — what one point of movement is worth, and how many of them the
/// risk budget can absorb.
///
/// A pip is meaningless without a position size behind it, so size, stop
/// distance and the account are treated as one calculation rather than three.
class PipValueCalculatorScreen extends StatefulWidget {
  const PipValueCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<PipValueCalculatorScreen> createState() =>
      _PipValueCalculatorScreenState();
}

class _PipValueCalculatorScreenState extends State<PipValueCalculatorScreen> {
  String _pair = 'EURUSD';
  double _lotSize = 100000;
  double _lots = 1;
  double _stopPips = 20;
  double _account = 500000;
  double _riskPct = 1;
  CurrencyRatesSnapshot _snapshot = CurrencyRatesSnapshot.initialFallback();

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    try {
      final CurrencyRatesSnapshot snap = await CurrencyRateService.instance
          .getRates();
      if (mounted) {
        setState(() {
          _snapshot = snap;
        });
      }
    } catch (_) {}
  }

  static const List<String> _pairs = <String>[
    'EURUSD',
    'GBPUSD',
    'AUDUSD',
    'USDJPY',
    'USDINR',
    'USDCAD',
    'USDCHF',
    'USDSGD',
    'EURINR',
    'GBPINR',
    'EURJPY',
    'USDAED',
  ];

  static String _lotName(double units) => units == 1000
      ? 'Micro'
      : units == 10000
      ? 'Mini'
      : units == 100000
      ? 'Standard'
      : AppTokens.count(units);

  @override
  Widget build(BuildContext context) {
    final double units = _lotSize * _lots;
    final double usdInr = _snapshot.rateFor('INR');
    final PipResult r = calcPipValue(
      pair: _pair,
      lotSize: units,
      usdInr: usdInr,
      rates: _snapshot.rates,
    );
    final String base = _pair.substring(0, 3);
    final String quote = _pair.substring(3);
    final double perUnitInr = units <= 0 ? 0 : r.valueInInr / units;
    final double riskBudget = _account * _riskPct / 100;
    final double stopCost = _stopPips * r.valueInInr;
    final double pipsAllowed = r.valueInInr <= 0
        ? 0
        : riskBudget / r.valueInInr;
    final double suggestedUnits = _stopPips <= 0 || perUnitInr <= 0
        ? 0
        : riskBudget / (_stopPips * perUnitInr);
    final double suggestedLots = _lotSize <= 0 ? 0 : suggestedUnits / _lotSize;
    final bool overRisk = stopCost > riskBudget;
    final double budgetLeft = riskBudget - stopCost;
    final double twoR = stopCost * 2;

    // Cost of the stop as it widens, against the budget.
    const List<double> pipLadder = <double>[5, 10, 15, 20, 30, 40, 50, 60];
    final List<double> stopCurve = <double>[
      for (final double p in pipLadder) p * r.valueInInr,
    ];
    const List<double> sizes = <double>[1000, 10000, 100000, 200000, 500000];

    return AppCalculatorLayout(
      meta: calculatorMetaById('pip_value'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'One pip is worth',
        value: AppTokens.price(r.valueInInr),
        intent: overRisk ? UiIntent.warning : UiIntent.primary,
        tag:
            '$base/$quote · ${AppTokens.count(units)} units · ${_snapshot.isLive ? 'Live FX' : _snapshot.date}',
        tagIntent: _snapshot.isLive ? UiIntent.success : UiIntent.info,
        footnote:
            'A pip is ${r.pipSize} on this pair, so one point moves '
            '${r.valueInQuote.toStringAsFixed(2)} $quote — '
            '${AppTokens.price(r.valueInInr)} at the reference rate. A '
            '${_stopPips.round()}-pip stop risks '
            '${AppTokens.price(stopCost)}.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Pip in $quote',
          value: r.valueInQuote.toStringAsFixed(2),
          intent: UiIntent.info,
          hint: 'pip size ${r.pipSize}',
        ),
        UiStat(
          label: 'Position size',
          value: AppTokens.count(units),
          hint:
              '${_lots.toStringAsFixed(2)} × '
              '${_lotName(_lotSize)}',
        ),
        UiStat(
          label: 'Stop costs',
          value: AppTokens.price(stopCost),
          intent: overRisk ? UiIntent.bearish : UiIntent.bullish,
          hint:
              '${_stopPips.round()} pips against '
              '${AppTokens.price(riskBudget)}',
        ),
        UiStat(
          label: 'Budget allows',
          value: '${pipsAllowed.toStringAsFixed(0)} pips',
          intent: UiIntent.info,
          hint: 'at this size',
        ),
        UiStat(
          label: 'Size for the budget',
          value: '${suggestedLots.toStringAsFixed(2)} lots',
          intent: overRisk ? UiIntent.warning : UiIntent.bullish,
          hint: '${AppTokens.count(suggestedUnits)} units',
        ),
        UiStat(
          label: 'Two to one pays',
          value: AppTokens.price(twoR),
          intent: UiIntent.bullish,
          hint: '${(_stopPips * 2).round()} pips the other way',
          spark: stopCurve,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'The position',
          hint: 'pair and size',
          children: <Widget>[
            UiSelect<String>(
              label: 'Pair',
              value: _pair,
              expand: true,
              searchable: true,
              size: UiSize.sm,
              density: UiDensity.compact,
              helperText: quote == 'JPY'
                  ? 'Yen quotes carry two decimals, so a pip is 0.01.'
                  : 'Quoted in $quote — a pip is 0.0001.',
              options: <UiOption<String>>[
                for (final String p in _pairs)
                  UiOption<String>(
                    value: p,
                    label: '${p.substring(0, 3)}/${p.substring(3)}',
                    description: kCurrencyNames[p.substring(3)] ?? p,
                  ),
              ],
              onChanged: (String v) => setState(() => _pair = v),
            ),
            AppCalcSegment<double>(
              label: 'Lot',
              value: _lotSize,
              onChanged: (double v) => setState(() => _lotSize = v),
              helper: 'One standard lot is 100,000 units of $base.',
              options: const <UiToggleOption<double>>[
                UiToggleOption<double>(value: 1000, label: 'Micro'),
                UiToggleOption<double>(value: 10000, label: 'Mini'),
                UiToggleOption<double>(value: 100000, label: 'Standard'),
              ],
            ),
            AppCalcSliderField(
              label: 'Lots',
              value: _lots,
              min: 0.1,
              max: 10,
              divisions: 99,
              valueFormatter: (num v) => v.toStringAsFixed(2),
              helper:
                  '${AppTokens.count(units)} units — one pip is '
                  '${AppTokens.price(r.valueInInr)}.',
              onChanged: (double v) => setState(() => _lots = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'The risk behind it',
          hint: 'stop distance and budget',
          children: <Widget>[
            AppCalcSliderField(
              label: 'Stop distance',
              value: _stopPips,
              min: 5,
              max: 100,
              divisions: 95,
              intent: overRisk ? UiIntent.danger : UiIntent.primary,
              valueFormatter: (num v) => '${v.round()} pips',
              helper: overRisk
                  ? 'Costs ${AppTokens.price(stopCost)} — over the budget by '
                        '${AppTokens.price(-budgetLeft)}.'
                  : 'Costs ${AppTokens.price(stopCost)}, inside the budget.',
              onChanged: (double v) => setState(() => _stopPips = v),
            ),
            AppCalcNumberField(
              label: 'Account',
              value: _account,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[100000, 500000, 1000000, 5000000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              onChanged: (double v) => setState(() => _account = v),
            ),
            AppCalcSegment<double>(
              label: 'Risk per trade',
              value: _riskPct,
              onChanged: (double v) => setState(() => _riskPct = v),
              helper: '${AppTokens.price(riskBudget)} at risk on this trade.',
              options: const <UiToggleOption<double>>[
                UiToggleOption<double>(value: 0.5, label: '0.5%'),
                UiToggleOption<double>(value: 1, label: '1%'),
                UiToggleOption<double>(value: 2, label: '2%'),
                UiToggleOption<double>(value: 3, label: '3%'),
              ],
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Pip value by position size',
          hint: 'same pair, other sizes',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiKeyValueTable(
            labelHeader: 'Units',
            valueHeader: 'Pip in ₹',
            trailingHeader: 'In $quote',
            rows: <UiKeyValueRow>[
              for (final double s in sizes)
                UiKeyValueRow(
                  label: _lotName(s),
                  value: AppTokens.price(
                    calcPipValue(
                      pair: _pair,
                      lotSize: s,
                      usdInr: usdInr,
                      rates: _snapshot.rates,
                    ).valueInInr,
                  ),
                  trailing: calcPipValue(
                    pair: _pair,
                    lotSize: s,
                    usdInr: usdInr,
                    rates: _snapshot.rates,
                  ).valueInQuote.toStringAsFixed(2),
                  intent: (s - units).abs() < 1
                      ? UiIntent.primary
                      : UiIntent.neutral,
                  emphasis: (s - units).abs() < 1,
                  detail:
                      '${AppTokens.count(s)} units · '
                      '${_stopPips.round()}-pip stop costs '
                      '${AppTokens.price(_stopPips * calcPipValue(pair: _pair, lotSize: s, usdInr: usdInr, rates: _snapshot.rates).valueInInr)}',
                  share: riskBudget <= 0
                      ? null
                      : (_stopPips *
                                calcPipValue(
                                  pair: _pair,
                                  lotSize: s,
                                  usdInr: usdInr,
                                  rates: _snapshot.rates,
                                ).valueInInr /
                                riskBudget)
                            .clamp(0.0, 1.0),
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Across the pairs',
          hint: 'this size, every quote currency',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Pair',
            valueHeader: 'Pip in ₹',
            trailingHeader: 'Pip size',
            rows: <UiKeyValueRow>[
              for (final String p in _pairs)
                UiKeyValueRow(
                  label: '${p.substring(0, 3)}/${p.substring(3)}',
                  value: AppTokens.price(
                    calcPipValue(
                      pair: p,
                      lotSize: units,
                      usdInr: usdInr,
                      rates: _snapshot.rates,
                    ).valueInInr,
                  ),
                  trailing:
                      '${calcPipValue(pair: p, lotSize: units, usdInr: usdInr, rates: _snapshot.rates).pipSize}',
                  intent: p == _pair ? UiIntent.primary : UiIntent.neutral,
                  emphasis: p == _pair,
                  detail:
                      '${_stopPips.round()} pips = '
                      '${AppTokens.price(_stopPips * calcPipValue(pair: p, lotSize: units, usdInr: usdInr, rates: _snapshot.rates).valueInInr)}',
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Stop cost as it widens',
          hint: 'against the risk budget',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[for (final double p in pipLadder) '${p.round()}'],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Stop cost',
                values: stopCurve,
                intent: overRisk ? UiIntent.bearish : UiIntent.warning,
                area: true,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: riskBudget, label: 'budget'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Pip value by lot',
          hint: 'in rupees',
          child: UiBarList(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            items: <UiBarListItem>[
              for (final double s in sizes)
                UiBarListItem(
                  label: _lotName(s),
                  value: calcPipValue(
                    pair: _pair,
                    lotSize: s,
                    usdInr: usdInr,
                    rates: _snapshot.rates,
                  ).valueInInr,
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'The risk budget',
          hint: 'this stop · what is left',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: stopCost > riskBudget ? riskBudget : stopCost,
                label: 'Stop ${AppTokens.compactMoney(stopCost)}',
              ),
              UiCategorySegment(
                value: budgetLeft < 0 ? 0 : budgetLeft,
                label: 'Spare ${AppTokens.compactMoney(budgetLeft)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Pips the budget carries',
          hint: 'stop against what is affordable',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: 0,
            max: (pipsAllowed > _stopPips ? pipsAllowed : _stopPips) + 10,
            minLabel: '0',
            maxLabel: 'pips',
            valueFormatter: (num v) => '${v.round()}',
            zones: <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: pipsAllowed,
                intent: UiIntent.bullish,
                label: 'inside the budget',
                alpha: 0.14,
              ),
              UiRangeZone(
                start: pipsAllowed,
                end: pipsAllowed > _stopPips ? pipsAllowed : _stopPips + 10,
                intent: UiIntent.bearish,
                label: 'over',
                alpha: 0.16,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: _stopPips,
                label: 'Your stop',
                intent: overRisk ? UiIntent.bearish : UiIntent.bullish,
                strong: true,
              ),
              UiRangeMarker(
                value: pipsAllowed,
                label: 'Affordable',
                intent: UiIntent.info,
                below: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (overRisk)
          UiCallout(
            intent: UiIntent.danger,
            title: 'The stop costs more than the budget',
            message:
                '${_stopPips.round()} pips at ${AppTokens.count(units)} units is '
                '${AppTokens.price(stopCost)} against a budget of '
                '${AppTokens.price(riskBudget)}. Cut the size to '
                '${suggestedLots.toStringAsFixed(2)} lots '
                '(${AppTokens.count(suggestedUnits)} units) and the same stop '
                'fits exactly.',
          ),
        if (!overRisk && suggestedLots > _lots * 1.5)
          UiCallout(
            intent: UiIntent.info,
            title: 'Room for a larger position',
            message:
                'The budget supports ${suggestedLots.toStringAsFixed(2)} lots at '
                'this stop, against ${_lots.toStringAsFixed(2)} on the trade. '
                'Sizing up is optional; sizing up without widening the stop is '
                'what keeps the risk constant.',
          ),
        if (quote == 'JPY')
          UiCallout(
            intent: UiIntent.warning,
            title: 'Yen pairs move in 0.01 steps',
            message:
                'A pip on a JPY quote is 0.01, a hundred times the 0.0001 used '
                'on the majors, so the pip value looks large for the same unit '
                'count. Stops quoted in pips are not comparable across the two '
                'conventions.',
          ),
      ],
      formula:
          'Pip = 0.0001, or 0.01 when the quote is JPY\n'
          'Value in quote = Pip × Units\n'
          'Value in ₹ = Value in quote ÷ quote-per-USD × USD/INR\n'
          'Stop cost = Stop pips × Value in ₹\n'
          'Size = Budget ÷ (Stop pips × Pip value per unit)',
      notes: <String>[
        'Conversion to rupees uses rates from ${_snapshot.source} dated '
            '${_snapshot.date} (${_snapshot.isLive ? 'real-time feed' : 'stored offline reference'}). '
            'A live quote will differ slightly; the pip value in the quote currency is exact.',
        'On pairs where the quote currency is not INR, the rupee value of a pip '
            'drifts with the cross rate even when the position does not move. '
            'The exposure is to two currencies, not one.',
        'Brokers price the spread in pips, so a two-pip spread on a '
            '${_lots.toStringAsFixed(2)}-lot position costs '
            '${AppTokens.price(2 * r.valueInInr)} before the trade has moved.',
        'Retail participation in currency derivatives from India is limited to '
            'exchange-traded contracts on permitted pairs. Position sizes here '
            'are the interbank unit convention, not lot sizes on an Indian '
            'exchange.',
      ],
    );
  }
}
