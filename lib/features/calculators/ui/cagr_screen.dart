import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/investing_calculators.dart';
import '../services/market_data_service.dart';

/// CAGR — the single rate that would have produced the result, and what that
/// rate is worth once something is compared against it.
///
/// Absolute return flatters long holdings and hides short ones. The annualised
/// figure is put next to a benchmark, a straight line, and the years it takes
/// to double.
class CagrCalculatorScreen extends StatefulWidget {
  const CagrCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<CagrCalculatorScreen> createState() => _CagrCalculatorScreenState();
}

class _CagrCalculatorScreenState extends State<CagrCalculatorScreen> {
  double _initial = 250000;
  double _final = 620000;
  double _years = 5;
  double _benchmark = 13.20;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveBenchmarks();
  }

  Future<void> _fetchLiveBenchmarks() async {
    try {
      final MacroBenchmarks b = await MarketDataService.instance
          .getMacroBenchmarks();
      if (!mounted) return;
      setState(() {
        _benchmark = b.nifty10YCagr;
        _isLive = b.isLive;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final int yrs = _years.round();
    final CagrResult r = calcCagr(
      initial: _initial,
      finalValue: _final,
      years: _years,
    );
    final GrowthResult bench = calcLumpsum(
      principal: _initial,
      annualRatePct: _benchmark,
      years: _years,
    );
    final double multiple = _initial <= 0 ? 0 : _final / _initial;
    final double alpha = r.cagrPct - _benchmark;
    final double vsBench = _final - bench.futureValue;
    final bool beat = alpha > 0;
    final bool lost = _final < _initial;

    // The smooth path the annualised rate implies, against the straight line
    // the same gain would have drawn.
    final List<double> compounded = <double>[];
    double v = _initial;
    for (int i = 0; i < yrs; i++) {
      v *= 1 + r.cagrPct / 100;
      compounded.add(v);
    }
    final List<double> straight = <double>[
      for (int i = 1; i <= yrs; i++)
        _initial + (yrs <= 0 ? 0 : r.gain / yrs * i),
    ];
    final List<double> benchPath = bench.yearlyValues;
    // Held for the same span again at the same rate.
    final List<double> ahead = <double>[];
    double f = _final;
    for (int i = 0; i < yrs; i++) {
      f *= 1 + r.cagrPct / 100;
      ahead.add(f);
    }
    final List<int> marks = <int>[
      for (final int y in const <int>[1, 2, 3, 5, 7, 10, 15, 20])
        if (y <= yrs && y <= compounded.length) y,
    ];

    return AppCalculatorLayout(
      meta: calculatorMetaById('cagr'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Compounded annual growth',
        value: AppTokens.signedPercent(r.cagrPct, decimals: 2),
        intent: AppTokens.plIntent(r.cagrPct),
        tag: beat ? 'ahead of benchmark' : 'behind benchmark',
        tagIntent: beat ? UiIntent.bullish : UiIntent.bearish,
        footnote:
            '${AppTokens.lakhCrore(_initial)} to '
            '${AppTokens.lakhCrore(_final)} over $yrs years — '
            '${AppTokens.signedPercent(r.absoluteReturnPct, decimals: 1)} '
            'absolute, ${multiple.toStringAsFixed(2)}× the money.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Absolute return',
          value: AppTokens.signedPercent(r.absoluteReturnPct, decimals: 1),
          intent: AppTokens.plIntent(r.absoluteReturnPct),
          hint: 'over the whole holding',
        ),
        UiStat(
          label: 'Gain',
          value: AppTokens.lakhCrore(r.gain),
          intent: AppTokens.plIntent(r.gain),
          hint: '${multiple.toStringAsFixed(2)}× the start',
        ),
        UiStat(
          label: 'Doubles in',
          value: r.doublingYears <= 0 || lost
              ? '—'
              : '${r.doublingYears.toStringAsFixed(1)} yr',
          intent: UiIntent.info,
          hint: lost ? 'no growth to compound' : 'at this rate',
        ),
        UiStat(
          label: 'Benchmark',
          value: AppTokens.percent(_benchmark, decimals: 1),
          hint: '${AppTokens.lakhCrore(bench.futureValue)} on the same money',
        ),
        UiStat(
          label: 'Alpha',
          value: AppTokens.signedPercent(alpha, decimals: 2),
          intent: AppTokens.plIntent(alpha),
          hint: 'a year, against the benchmark',
        ),
        UiStat(
          label: 'Against benchmark',
          value: AppTokens.signedMoney(vsBench, decimals: 0),
          intent: AppTokens.plIntent(vsBench),
          hint: beat ? 'earned in excess' : 'given up',
          spark: compounded,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'The holding',
          hint: 'both ends of the period',
          children: <Widget>[
            AppCalcNumberField(
              label: 'Starting value',
              value: _initial,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[100000, 250000, 1000000, 5000000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              onChanged: (double v) => setState(() => _initial = v),
            ),
            AppCalcNumberField(
              label: 'Ending value',
              value: _final,
              prefix: '₹',
              decimals: 0,
              helper: lost
                  ? 'Below the start — the rate comes out negative.'
                  : '${multiple.toStringAsFixed(2)}× the starting value.',
              onChanged: (double v) => setState(() => _final = v),
            ),
            AppCalcSliderField(
              label: 'Years held',
              value: _years,
              min: 1,
              max: 25,
              divisions: 24,
              valueFormatter: (num v) => '${v.round()} yr',
              helper: 'Use whole years. A partial year distorts the rate.',
              onChanged: (double v) => setState(() => _years = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Reference',
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'Nifty 10Y: ${AppTokens.percent(_benchmark, decimals: 2)}'
                      : 'Benchmark: ${AppTokens.percent(_benchmark, decimals: 2)}',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
                UiButton(
                  label: 'Sync Benchmark',
                  leadingIcon: Icons.refresh,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: _fetchLiveBenchmarks,
                ),
              ],
            ),
            AppCalcSliderField(
              label: 'Benchmark return',
              value: _benchmark,
              min: 0,
              max: 25,
              divisions: 50,
              intent: beat ? UiIntent.bullish : UiIntent.bearish,
              valueFormatter: (num v) => AppTokens.percent(v, decimals: 1),
              helper: beat
                  ? '${AppTokens.signedPercent(alpha, decimals: 2)} a year of '
                        'excess return.'
                  : 'The benchmark would have paid '
                        '${AppTokens.lakhCrore(bench.futureValue)}.',
              onChanged: (double v) => setState(() => _benchmark = v),
            ),
            AppCalcSegment<double>(
              label: 'Quick set',
              value: _benchmark,
              onChanged: (double v) => setState(() => _benchmark = v),
              helper: 'Deposit, index, or a demanding target.',
              options: const <UiToggleOption<double>>[
                UiToggleOption<double>(value: 7.05, label: 'FD 7.05%'),
                UiToggleOption<double>(value: 13.20, label: 'Nifty 13.2%'),
                UiToggleOption<double>(value: 15, label: 'Fund 15%'),
                UiToggleOption<double>(value: 20, label: 'High 20%'),
              ],
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'The implied path',
          hint: 'if every year returned the same',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiKeyValueTable(
            labelHeader: 'Year',
            valueHeader: 'Value',
            trailingHeader: 'Benchmark',
            rows: <UiKeyValueRow>[
              for (final int y in marks)
                UiKeyValueRow(
                  label: 'Year $y',
                  value: AppTokens.lakhCrore(compounded[y - 1]),
                  trailing: y <= benchPath.length
                      ? AppTokens.lakhCrore(benchPath[y - 1])
                      : '—',
                  intent:
                      y <= benchPath.length &&
                          compounded[y - 1] >= benchPath[y - 1]
                      ? UiIntent.bullish
                      : UiIntent.bearish,
                  detail: _initial <= 0
                      ? null
                      : '${(compounded[y - 1] / _initial).toStringAsFixed(2)}× '
                            'the start',
                  share: _final <= 0
                      ? null
                      : (compounded[y - 1] / _final).clamp(0.0, 1.0),
                ),
              UiKeyValueRow(
                label: 'Actual',
                value: AppTokens.lakhCrore(_final),
                trailing: AppTokens.lakhCrore(bench.futureValue),
                intent: AppTokens.plIntent(vsBench),
                emphasis: true,
                detail:
                    '${AppTokens.signedMoney(vsBench, decimals: 0)} against '
                    'the benchmark',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Rate card',
          hint: 'what other rates would have paid',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Rate',
            valueHeader: 'Ending value',
            trailingHeader: 'Against this',
            rows: <UiKeyValueRow>[
              for (final double x in const <double>[6, 8, 10, 12, 15, 18])
                UiKeyValueRow(
                  label: AppTokens.percent(x, decimals: 0),
                  value: AppTokens.lakhCrore(
                    calcLumpsum(
                      principal: _initial,
                      annualRatePct: x,
                      years: _years,
                    ).futureValue,
                  ),
                  trailing: AppTokens.signedMoney(
                    _final -
                        calcLumpsum(
                          principal: _initial,
                          annualRatePct: x,
                          years: _years,
                        ).futureValue,
                    decimals: 0,
                  ),
                  intent: r.cagrPct >= x ? UiIntent.bullish : UiIntent.bearish,
                  emphasis: (x - _benchmark).abs() < 0.5,
                  detail: r.cagrPct >= x ? 'Cleared' : 'Not cleared',
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Compounded against straight line',
          hint: 'same start, same finish',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (int i = 1; i <= compounded.length; i++)
                i == 1 || i % 5 == 0 || i == compounded.length ? '$i' : '',
            ],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Compounded',
                values: compounded,
                intent: AppTokens.plIntent(r.cagrPct),
                area: true,
              ),
              AppCalcSeries(
                name: 'Straight line',
                values: straight,
                intent: UiIntent.neutral,
              ),
              AppCalcSeries(
                name: 'Benchmark',
                values: benchPath,
                intent: UiIntent.info,
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Held another $yrs years',
          hint: 'at the same rate',
          child: AppCalcTrendChart(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Projected',
                values: ahead,
                intent: UiIntent.bullish,
                area: true,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _final, label: 'today'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Start against gain',
          hint: 'what the ending value is made of',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: _initial,
                label: 'Start ${AppTokens.compactMoney(_initial)}',
              ),
              UiCategorySegment(
                value: r.gain < 0 ? 0 : r.gain,
                label: 'Gain ${AppTokens.compactMoney(r.gain)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'The rate in context',
          hint: 'deposit · index · demanding',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: r.cagrPct < 0 ? r.cagrPct - 2 : 0,
            max: (r.cagrPct > 25 ? r.cagrPct : 25) + 2,
            minLabel: r.cagrPct < 0 ? 'loss' : '0%',
            maxLabel: 'rate',
            valueFormatter: (num v) => AppTokens.percent(v, decimals: 1),
            zones: const <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: 7,
                intent: UiIntent.neutral,
                label: 'deposit',
                alpha: 0.12,
              ),
              UiRangeZone(
                start: 7,
                end: 14,
                intent: UiIntent.info,
                label: 'index',
                alpha: 0.14,
              ),
              UiRangeZone(
                start: 14,
                end: 25,
                intent: UiIntent.bullish,
                label: 'outperformance',
                alpha: 0.16,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(value: r.cagrPct, label: 'CAGR', strong: true),
              UiRangeMarker(
                value: _benchmark,
                label: 'Benchmark',
                intent: UiIntent.warning,
                below: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (lost)
          UiCallout(
            intent: UiIntent.bearish,
            title: 'A negative rate',
            message:
                'The ending value is below the start, so the annualised figure '
                'is the rate at which the holding shrank — '
                '${AppTokens.signedPercent(r.cagrPct, decimals: 2)} a year for '
                '$yrs years.',
          ),
        if (!lost && _years <= 2)
          UiCallout(
            intent: UiIntent.warning,
            title: 'Too short to annualise safely',
            message:
                'Annualising $yrs '
                '${yrs == 1 ? 'year' : 'years'} projects one outcome onto a rate '
                'that implies repetition. A single strong year reads as a '
                'permanent ${AppTokens.percent(r.cagrPct, decimals: 1)} here, '
                'which it is not.',
          ),
        if (!lost && r.cagrPct > 25)
          UiCallout(
            intent: UiIntent.info,
            title:
                '${AppTokens.percent(r.cagrPct, decimals: 1)} is well above '
                'market returns',
            message:
                'Sustained rates at this level are rare over full cycles. '
                'Check whether fresh money was added during the period — that '
                'inflates the ending value and the rate with it. Use the XIRR '
                'approach when contributions are irregular.',
          ),
      ],
      formula:
          'CAGR = (Final ÷ Initial)^(1 ÷ Years) − 1\n'
          'Absolute = (Final − Initial) ÷ Initial × 100\n'
          'Gain = Final − Initial\n'
          'Doubling ≈ 72 ÷ CAGR\n'
          'Alpha = CAGR − Benchmark',
      notes: const <String>[
        'CAGR smooths the path completely. Two holdings with the same start, '
            'end and duration share a rate even if one fell 40% in the middle — '
            'it measures outcome, never risk.',
        'The figure is only valid for a single deployment. If money went in or '
            'came out along the way, the rate is wrong and XIRR is the correct '
            'tool.',
        'Alpha here is a plain difference in annual rates, not a risk-adjusted '
            'measure. Beating an index with far more concentration is not the '
            'same as beating it.',
        'Absolute return and CAGR diverge with duration. Quote the absolute for '
            'holdings under a year and the annualised figure beyond it.',
      ],
    );
  }
}
