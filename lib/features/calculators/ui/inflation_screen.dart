import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/investing_calculators.dart';
import '../services/market_data_service.dart';

/// Inflation — the same basket, priced later, and whether savings kept up.
///
/// Two questions sit behind one rate: what today's cost becomes, and what
/// today's money will still buy. Both are shown, against the return the money
/// is actually earning.
class InflationCalculatorScreen extends StatefulWidget {
  const InflationCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<InflationCalculatorScreen> createState() =>
      _InflationCalculatorScreenState();
}

class _InflationCalculatorScreenState
    extends State<InflationCalculatorScreen> {
  double _amount = 100000;
  double _inflation = 3.65;
  double _years = 20;
  double _return = 8;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveCpi();
  }

  Future<void> _fetchLiveCpi() async {
    try {
      final MacroBenchmarks b =
          await MarketDataService.instance.getMacroBenchmarks();
      if (!mounted) return;
      setState(() {
        _inflation = b.cpiInflationRate;
        _isLive = b.isLive;
      });
    } catch (_) {}
  }

  static const List<(String, double)> _basket = <(String, double)>[
    ('Litre of fuel', 105),
    ('Monthly groceries', 15000),
    ('Annual school fee', 150000),
    ('Family car', 1200000),
    ('City apartment', 8000000),
  ];

  @override
  Widget build(BuildContext context) {
    final int yrs = _years.round();
    final InflationResult r = calcInflation(
      amount: _amount,
      inflationPct: _inflation,
      years: _years,
    );
    final GrowthResult inv = calcLumpsum(
      principal: _amount,
      annualRatePct: _return,
      years: _years,
    );
    final double realRate = _return - _inflation;
    final double gap = inv.futureValue - r.futureCost;
    final bool keepsUp = gap >= 0;
    final double halvingYears = _inflation <= 0 ? 0 : 72 / _inflation;
    final double costMultiple = _amount <= 0 ? 0 : r.futureCost / _amount;
    final double kept = r.presentValue;
    final double lost = _amount - r.presentValue;
    // The return needed just to stand still is the inflation rate itself.
    final double needed = _inflation;

    // Purchasing power of today's money, year by year, without dart:math.
    final List<double> costs = r.yearlyCosts;
    final List<double> power = <double>[];
    double deflator = 1;
    for (int i = 0; i < costs.length; i++) {
      deflator *= 1 + _inflation / 100;
      power.add(_amount / deflator);
    }
    final List<double> savings = inv.yearlyValues;
    final List<int> marks = <int>[
      for (final int y in const <int>[1, 3, 5, 10, 15, 20, 25, 30])
        if (y <= yrs && y <= costs.length) y,
    ];

    return AppCalculatorLayout(
      meta: calculatorMetaById('inflation'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Cost in $yrs years',
        value: AppTokens.lakhCrore(r.futureCost),
        intent: UiIntent.warning,
        tag: '${costMultiple.toStringAsFixed(2)}× today',
        tagIntent: UiIntent.bearish,
        footnote:
            '${AppTokens.lakhCrore(_amount)} of spending today at '
            '${AppTokens.percent(_inflation, decimals: 1)} inflation — the same '
            'money left alone would still buy '
            '${AppTokens.lakhCrore(r.presentValue)} worth.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Future cost',
          value: AppTokens.lakhCrore(r.futureCost),
          intent: UiIntent.bearish,
          hint: '${costMultiple.toStringAsFixed(2)}× the price today',
        ),
        UiStat(
          label: 'Money keeps',
          value: AppTokens.lakhCrore(r.presentValue),
          intent: UiIntent.warning,
          hint: 'of ${AppTokens.lakhCrore(_amount)} in real terms',
        ),
        UiStat(
          label: 'Eroded',
          value: AppTokens.percent(r.erosionPct, decimals: 1),
          intent: UiIntent.bearish,
          hint: 'purchasing power gone',
        ),
        UiStat(
          label: 'Halves in',
          value: halvingYears <= 0
              ? '—'
              : '${halvingYears.toStringAsFixed(1)} yr',
          intent: UiIntent.info,
          hint: halvingYears <= 0 ? 'no inflation' : 'value of a rupee',
        ),
        UiStat(
          label: 'Savings reach',
          value: AppTokens.lakhCrore(inv.futureValue),
          intent: keepsUp ? UiIntent.bullish : UiIntent.bearish,
          hint: 'at ${AppTokens.percent(_return, decimals: 1)} a year',
        ),
        UiStat(
          label: keepsUp ? 'Ahead of cost' : 'Short of cost',
          value: AppTokens.signedMoney(gap, decimals: 0),
          intent: AppTokens.plIntent(gap),
          hint: 'savings against the basket',
          spark: savings,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'What is being priced',
          hint: 'an amount and a horizon',
          children: <Widget>[
            AppCalcNumberField(
              label: 'Cost today',
              value: _amount,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[50000, 100000, 1000000, 5000000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              onChanged: (double v) => setState(() => _amount = v),
            ),
            AppCalcSliderField(
              label: 'Years ahead',
              value: _years,
              min: 1,
              max: 30,
              divisions: 29,
              valueFormatter: (num v) => '${v.round()} yr',
              helper: halvingYears <= 0
                  ? 'No erosion at zero inflation.'
                  : '${(_years / halvingYears).toStringAsFixed(1)} halvings of '
                        'purchasing power over this span.',
              onChanged: (double v) => setState(() => _years = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Rates',
          hint: 'erosion against what money earns',
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'World Bank CPI: ${AppTokens.percent(_inflation, decimals: 2)}'
                      : 'CPI: ${AppTokens.percent(_inflation, decimals: 2)}',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
                UiButton(
                  label: 'Sync CPI',
                  leadingIcon: Icons.refresh,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: _fetchLiveCpi,
                ),
              ],
            ),
            AppCalcSliderField(
              label: 'Inflation',
              value: _inflation,
              min: 0,
              max: 12,
              divisions: 48,
              intent: UiIntent.warning,
              valueFormatter: (num v) => AppTokens.percent(v, decimals: 1),
              helper: 'Prices rise '
                  '${costMultiple.toStringAsFixed(2)}× over $yrs years at this '
                  'rate.',
              onChanged: (double v) => setState(() => _inflation = v),
            ),
            AppCalcSliderField(
              label: 'Return on the money',
              value: _return,
              min: 0,
              max: 20,
              divisions: 40,
              intent: realRate > 0 ? UiIntent.bullish : UiIntent.danger,
              valueFormatter: (num v) => AppTokens.percent(v, decimals: 1),
              helper: realRate > 0
                  ? 'Real return '
                        '${AppTokens.signedPercent(realRate, decimals: 1)} — '
                        'ahead of prices.'
                  : 'Below inflation, so the money loses ground even as it '
                        'grows.',
              onChanged: (double v) => setState(() => _return = v),
            ),
            AppCalcSegment<double>(
              label: 'Where it sits',
              value: _return,
              onChanged: (double v) => setState(() => _return = v),
              helper: 'Savings account, deposit, debt, or equity.',
              options: const <UiToggleOption<double>>[
                UiToggleOption<double>(value: 3.5, label: 'Bank 3.5%'),
                UiToggleOption<double>(value: 7, label: 'FD 7%'),
                UiToggleOption<double>(value: 9, label: 'Debt 9%'),
                UiToggleOption<double>(value: 12, label: 'Equity 12%'),
              ],
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'The same basket, priced later',
          hint: 'cost, then what today’s money buys',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiKeyValueTable(
            labelHeader: 'Year',
            valueHeader: 'Costs',
            trailingHeader: 'Money buys',
            rows: <UiKeyValueRow>[
              for (final int y in marks)
                UiKeyValueRow(
                  label: 'Year $y',
                  value: AppTokens.lakhCrore(costs[y - 1]),
                  trailing: y <= power.length
                      ? AppTokens.lakhCrore(power[y - 1])
                      : '—',
                  intent: y <= savings.length && savings[y - 1] >= costs[y - 1]
                      ? UiIntent.bullish
                      : UiIntent.bearish,
                  detail: _amount <= 0
                      ? null
                      : '${(costs[y - 1] / _amount).toStringAsFixed(2)}× the '
                            'price · savings '
                            '${y <= savings.length ? AppTokens.compactMoney(savings[y - 1]) : '—'}',
                  share: r.futureCost <= 0
                      ? null
                      : (costs[y - 1] / r.futureCost).clamp(0.0, 1.0),
                ),
              UiKeyValueRow(
                label: 'At $yrs',
                value: AppTokens.lakhCrore(r.futureCost),
                trailing: AppTokens.lakhCrore(r.presentValue),
                intent: AppTokens.plIntent(gap),
                emphasis: true,
                detail: '${AppTokens.percent(r.erosionPct, decimals: 1)} of the '
                    'value eroded · savings '
                    '${AppTokens.signedMoney(gap, decimals: 0)} against the cost',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Everyday prices',
          hint: 'at the same rate for $yrs years',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Item',
            valueHeader: 'Then',
            trailingHeader: 'Now',
            rows: <UiKeyValueRow>[
              for (final (String, double) item in _basket)
                UiKeyValueRow(
                  label: item.$1,
                  value: AppTokens.price(
                    calcInflation(
                      amount: item.$2,
                      inflationPct: _inflation,
                      years: _years,
                    ).futureCost,
                  ),
                  trailing: AppTokens.price(item.$2),
                  intent: UiIntent.warning,
                  detail: '+'
                      '${AppTokens.price(calcInflation(amount: item.$2, inflationPct: _inflation, years: _years).futureCost - item.$2)}'
                      ' over $yrs years',
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Cost against savings',
          hint: 'the gap is the shortfall',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (int i = 1; i <= costs.length; i++)
                i == 1 || i % 5 == 0 || i == costs.length ? '$i' : '',
            ],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Cost',
                values: costs,
                intent: UiIntent.bearish,
                area: true,
              ),
              AppCalcSeries(
                name: 'Savings',
                values: savings,
                intent: keepsUp ? UiIntent.bullish : UiIntent.warning,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _amount, label: 'today'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'What a rupee still buys',
          hint: 'purchasing power, year by year',
          child: AppCalcTrendChart(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Real value',
                values: power,
                intent: UiIntent.warning,
                area: true,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _amount / 2, label: 'half'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Cost at other rates',
          hint: 'after $yrs years',
          child: UiBarList(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            items: <UiBarListItem>[
              for (final double x in const <double>[3, 4, 5, 6, 8, 10])
                UiBarListItem(
                  label: '${AppTokens.percent(x, decimals: 0)} · '
                      '${(_amount <= 0 ? 0 : calcInflation(amount: _amount, inflationPct: x, years: _years).futureCost / _amount).toStringAsFixed(1)}×',
                  value: calcInflation(
                    amount: _amount,
                    inflationPct: x,
                    years: _years,
                  ).futureCost,
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Today’s money, split',
          hint: 'kept · eroded',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: kept < 0 ? 0 : kept,
                label: 'Keeps ${AppTokens.compactMoney(kept)}',
              ),
              UiCategorySegment(
                value: lost < 0 ? 0 : lost,
                label: 'Erodes ${AppTokens.compactMoney(lost)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Return against inflation',
          hint: 'standing still · gaining ground',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: 0,
            max: (_return > _inflation ? _return : _inflation) + 3,
            minLabel: '0%',
            maxLabel: 'rate',
            valueFormatter: (num v) => AppTokens.percent(v, decimals: 1),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: _inflation,
                intent: UiIntent.bearish,
                label: 'lost to prices',
                alpha: 0.14,
              ),
              UiRangeZone(
                start: _inflation,
                end: _return > _inflation ? _return : _inflation,
                intent: UiIntent.bullish,
                label: 'real gain',
                alpha: 0.16,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: _return,
                label: 'Return',
                intent: realRate > 0 ? UiIntent.bullish : UiIntent.bearish,
                strong: true,
              ),
              UiRangeMarker(
                value: needed,
                label: 'Break even',
                intent: UiIntent.warning,
                below: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (!keepsUp)
          UiCallout(
            intent: UiIntent.danger,
            title: 'The savings fall '
                '${AppTokens.lakhCrore(gap.abs())} short',
            message:
                '${AppTokens.percent(_return, decimals: 1)} on the money against '
                '${AppTokens.percent(_inflation, decimals: 1)} on prices leaves '
                '${AppTokens.lakhCrore(inv.futureValue)} to meet a '
                '${AppTokens.lakhCrore(r.futureCost)} bill. The gap has to come '
                'from a higher return, more money set aside, or a smaller goal.',
          ),
        if (keepsUp && realRate > 0)
          UiCallout(
            intent: UiIntent.bullish,
            title: '${AppTokens.signedPercent(realRate, decimals: 1)} a year '
                'of real growth',
            message:
                'The money outpaces prices by that margin, so '
                '${AppTokens.lakhCrore(_amount)} today covers a '
                '${AppTokens.lakhCrore(r.futureCost)} cost with '
                '${AppTokens.lakhCrore(gap)} to spare. Only the real rate '
                'compounds into anything you can spend.',
          ),
        if (r.erosionPct > 50)
          UiCallout(
            intent: UiIntent.warning,
            title: 'Over half the value is gone',
            message:
                '${AppTokens.percent(_inflation, decimals: 1)} for $yrs years '
                'cuts ${AppTokens.lakhCrore(_amount)} down to '
                '${AppTokens.lakhCrore(r.presentValue)} of buying power. Cash '
                'left idle over this span is not safe — it is a slow, certain '
                'loss.',
          ),
      ],
      formula:
          'Future cost = Amount × (1 + i)ⁿ\n'
          'Real value = Amount ÷ (1 + i)ⁿ\n'
          'Erosion = (1 − Real ÷ Amount) × 100\n'
          'Real return = Return − Inflation\n'
          'Halving ≈ 72 ÷ i',
      notes: const <String>[
        'One constant rate is applied to everything here. Real baskets move at '
            'their own pace — education and healthcare have run well above the '
            'headline index, electronics below it.',
        'Real return is quoted as a plain subtraction, which is close enough at '
            'these rates. The exact figure divides the growth factors and comes '
            'out slightly lower.',
        'The savings line is pre-tax. Tax on the gain is paid in future rupees '
            'but reduces real purchasing power, so the true gap is wider than '
            'the one shown.',
        'Goals should be priced in future rupees. Planning a target from today’s '
            'cost is the most common way a long-horizon plan ends up short.',
      ],
    );
  }
}
