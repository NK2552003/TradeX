import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/investing_calculators.dart';
import '../services/market_data_service.dart';

/// SIP — what a monthly habit compounds into, and how much of it is not yours.
///
/// The corpus is the headline, but the split between contributions and returns
/// is the lesson, so both sit in the same frame: a year-by-year ledger, the two
/// curves that produce it, and the goal the whole thing is aimed at.
class SipCalculatorScreen extends StatefulWidget {
  const SipCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<SipCalculatorScreen> createState() => _SipCalculatorScreenState();
}

class _SipCalculatorScreenState extends State<SipCalculatorScreen> {
  double _monthly = 25000;
  double _rate = 13.20;
  double _years = 15;
  double _stepUp = 0;
  double _goal = 10000000;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveBenchmarks();
  }

  Future<void> _fetchLiveBenchmarks() async {
    try {
      final MacroBenchmarks b =
          await MarketDataService.instance.getMacroBenchmarks();
      if (!mounted) return;
      setState(() {
        _rate = b.nifty10YCagr;
        _isLive = b.isLive;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final int yrs = _years.round();
    final SipResult r = calcSip(
      monthly: _monthly,
      annualRatePct: _rate,
      years: _years,
    );
    final StepUpSipResult su = calcStepUpSip(
      initialMonthly: _monthly,
      annualStepUpPct: _stepUp,
      annualRate: _rate,
      years: _years,
    );
    final double multiple = r.invested <= 0 ? 0 : r.futureValue / r.invested;
    final double gainShare = r.futureValue <= 0
        ? 0
        : r.gain / r.futureValue * 100;
    final double swrMonthly = r.futureValue * 0.04 / 12;
    final double goalPct = _goal <= 0 ? 0 : r.futureValue / _goal * 100;
    final bool metGoal = r.futureValue >= _goal;
    final double stepEdge = su.futureValue - su.flatValue;

    // Contributions accumulate in a straight line; the corpus does not.
    final List<double> corpus = r.yearlyValues;
    final List<double> contributed = <double>[
      for (int i = 1; i <= corpus.length; i++) _monthly * 12 * i,
    ];
    final List<double> stepped = su.yearlyValues;
    final List<int> marks = <int>[
      for (final int y in const <int>[1, 3, 5, 10, 15, 20, 25, 30])
        if (y <= yrs && y <= corpus.length) y,
    ];
    const List<double> rates = <double>[8, 10, 12, 14, 16];

    return AppCalculatorLayout(
      meta: calculatorMetaById('sip'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Corpus after $yrs years',
        value: AppTokens.lakhCrore(r.futureValue),
        intent: metGoal ? UiIntent.bullish : UiIntent.primary,
        tag: metGoal ? 'goal met' : '${AppTokens.percent(goalPct, decimals: 0)} of goal',
        tagIntent: metGoal ? UiIntent.bullish : UiIntent.neutral,
        footnote:
            '${AppTokens.lakhCrore(r.invested)} paid in over ${r.months} '
            'instalments, ${AppTokens.lakhCrore(r.gain)} earned — '
            '${AppTokens.percent(gainShare, decimals: 0)} of the corpus is '
            'return, not contribution.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Invested',
          value: AppTokens.lakhCrore(r.invested),
          hint: '${AppTokens.price(_monthly)} × ${r.months}',
        ),
        UiStat(
          label: 'Returns',
          value: AppTokens.lakhCrore(r.gain),
          intent: UiIntent.bullish,
          hint: '${AppTokens.percent(gainShare, decimals: 0)} of corpus',
        ),
        UiStat(
          label: 'Multiple',
          value: '${multiple.toStringAsFixed(2)}×',
          intent: UiIntent.info,
          hint: 'on money paid in',
        ),
        UiStat(
          label: 'Growth',
          value: AppTokens.signedPercent(r.growthPct, decimals: 0),
          intent: AppTokens.plIntent(r.growthPct),
          hint: 'absolute, not annual',
        ),
        UiStat(
          label: _stepUp > 0 ? 'With step-up' : 'Step-up off',
          value: _stepUp > 0
              ? AppTokens.lakhCrore(su.futureValue)
              : AppTokens.lakhCrore(r.futureValue),
          intent: _stepUp > 0 ? UiIntent.bullish : UiIntent.neutral,
          hint: _stepUp > 0
              ? '${AppTokens.lakhCrore(stepEdge)} more'
              : 'raise it annually',
          spark: stepped,
        ),
        UiStat(
          label: 'Draws at 4%',
          value: AppTokens.price(swrMonthly),
          hint: 'a month, corpus intact',
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Contribution',
          hint: 'what goes in, and whether it grows',
          children: <Widget>[
            AppCalcNumberField(
              label: 'Monthly amount',
              value: _monthly,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[5000, 10000, 25000, 50000],
              presetLabel: (double v) => AppTokens.compactMoney(v),
              onChanged: (double v) => setState(() => _monthly = v),
            ),
            AppCalcSliderField(
              label: 'Annual step-up',
              value: _stepUp,
              min: 0,
              max: 20,
              divisions: 20,
              intent: _stepUp > 0 ? UiIntent.bullish : UiIntent.neutral,
              valueFormatter: (num v) => AppTokens.percent(v, decimals: 0),
              helper: _stepUp > 0
                  ? 'Ends at ${AppTokens.price(su.finalMonthly)} a month.'
                  : 'Raise the instalment with income each year.',
              onChanged: (double v) => setState(() => _stepUp = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Assumptions',
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'Nifty 10Y: ${AppTokens.percent(_rate, decimals: 2)}'
                      : 'Benchmark: ${AppTokens.percent(_rate, decimals: 2)}',
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
              label: 'Expected return',
              value: _rate,
              min: 4,
              max: 20,
              divisions: 32,
              intent: _rate > 15 ? UiIntent.warning : UiIntent.primary,
              valueFormatter: (num v) => AppTokens.percent(v, decimals: 1),
              helper: _rate > 15
                  ? 'Above what broad equity has delivered over decades.'
                  : null,
              onChanged: (double v) => setState(() => _rate = v),
            ),
            AppCalcSliderField(
              label: 'Duration',
              value: _years,
              min: 1,
              max: 30,
              divisions: 29,
              valueFormatter: (num v) => '${v.round()} yr',
              onChanged: (double v) => setState(() => _years = v),
            ),
            AppCalcNumberField(
              label: 'Goal',
              value: _goal,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[2500000, 5000000, 10000000, 50000000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              helper: metGoal
                  ? 'Reached with ${AppTokens.lakhCrore(r.futureValue - _goal)} spare.'
                  : 'Short by ${AppTokens.lakhCrore(_goal - r.futureValue)}.',
              onChanged: (double v) => setState(() => _goal = v),
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Milestones',
          hint: 'corpus at each stage',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Year',
            valueHeader: 'Corpus',
            trailingHeader: 'Of which return',
            rows: <UiKeyValueRow>[
              for (final int y in marks)
                UiKeyValueRow(
                  label: 'Year $y',
                  value: AppTokens.lakhCrore(corpus[y - 1]),
                  trailing: AppTokens.lakhCrore(
                    corpus[y - 1] - _monthly * 12 * y,
                  ),
                  intent: corpus[y - 1] >= _goal
                      ? UiIntent.bullish
                      : UiIntent.neutral,
                  detail: '${AppTokens.lakhCrore(_monthly * 12 * y)} paid in',
                  share: r.futureValue <= 0
                      ? null
                      : (corpus[y - 1] / r.futureValue).clamp(0.0, 1.0),
                ),
              UiKeyValueRow(
                label: 'At $yrs',
                value: AppTokens.lakhCrore(r.futureValue),
                trailing: AppTokens.lakhCrore(r.gain),
                intent: metGoal ? UiIntent.bullish : UiIntent.warning,
                emphasis: true,
                detail: metGoal ? 'Goal cleared' : 'Goal not reached',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Rate sensitivity',
          hint: 'same instalment, other returns',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Return',
            valueHeader: 'Corpus',
            trailingHeader: 'Against 12%',
            rows: <UiKeyValueRow>[
              for (final double x in rates)
                UiKeyValueRow(
                  label: AppTokens.percent(x, decimals: 0),
                  value: AppTokens.lakhCrore(
                    calcSip(
                      monthly: _monthly,
                      annualRatePct: x,
                      years: _years,
                    ).futureValue,
                  ),
                  trailing: AppTokens.signedPercent(
                    calcSip(
                          monthly: _monthly,
                          annualRatePct: x,
                          years: _years,
                        ).futureValue /
                            calcSip(
                              monthly: _monthly,
                              annualRatePct: 12,
                              years: _years,
                            ).futureValue *
                            100 -
                        100,
                    decimals: 0,
                  ),
                  intent: x >= _rate ? UiIntent.bullish : UiIntent.bearish,
                  emphasis: (x - _rate).abs() < 0.5,
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Corpus against contributions',
          hint: 'the gap is compounding',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (int i = 1; i <= corpus.length; i++)
                i == 1 || i % 5 == 0 || i == corpus.length ? '$i' : '',
            ],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Corpus',
                values: corpus,
                intent: UiIntent.bullish,
                area: true,
              ),
              AppCalcSeries(
                name: 'Paid in',
                values: contributed,
                intent: UiIntent.neutral,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _goal, label: 'goal'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Step-up against flat',
          hint: _stepUp > 0
              ? '${AppTokens.percent(_stepUp, decimals: 0)} a year'
              : 'step-up is off',
          child: AppCalcTrendChart(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Stepped',
                values: stepped,
                intent: UiIntent.info,
                area: true,
              ),
              AppCalcSeries(
                name: 'Flat',
                values: corpus,
                intent: UiIntent.neutral,
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Contribution against return',
          hint: 'what built the corpus',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: r.invested,
                label: 'Paid in ${AppTokens.compactMoney(r.invested)}',
              ),
              UiCategorySegment(
                value: r.gain < 0 ? 0 : r.gain,
                label: 'Earned ${AppTokens.compactMoney(r.gain)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Progress to the goal',
          hint: AppTokens.percent(goalPct, decimals: 0),
          kind: AppCalcPanelKind.meter,
          child: UiRangeMeter(
            min: 0,
            max: (r.futureValue > _goal ? r.futureValue : _goal) * 1.08,
            minLabel: '0',
            maxLabel: 'goal',
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: _goal,
                intent: metGoal ? UiIntent.bullish : UiIntent.warning,
                label: metGoal ? 'covered' : 'to fund',
                alpha: 0.14,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: r.futureValue,
                label: 'Corpus',
                strong: true,
              ),
              UiRangeMarker(
                value: r.invested,
                label: 'Paid in',
                intent: UiIntent.neutral,
                below: true,
              ),
              UiRangeMarker(
                value: _goal,
                label: 'Goal',
                intent: UiIntent.info,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (!metGoal)
          UiCallout(
            intent: UiIntent.warning,
            title: 'The goal is short by '
                '${AppTokens.lakhCrore(_goal - r.futureValue)}',
            message:
                'At ${AppTokens.percent(_rate, decimals: 0)} for $yrs years the '
                'instalment needed is about '
                '${AppTokens.price(_goal <= 0 || r.futureValue <= 0 ? 0 : _monthly * _goal / r.futureValue)} '
                'a month — or hold this instalment and add years.',
          ),
        if (_stepUp > 0)
          UiCallout(
            intent: UiIntent.bullish,
            title: 'Step-up adds ${AppTokens.lakhCrore(stepEdge)}',
            message:
                'Raising the instalment ${AppTokens.percent(_stepUp, decimals: 0)} '
                'a year ends at ${AppTokens.price(su.finalMonthly)} a month and '
                '${AppTokens.lakhCrore(su.futureValue)} in total — '
                '${AppTokens.percent(su.flatValue <= 0 ? 0 : stepEdge / su.flatValue * 100, decimals: 0)} '
                'ahead of the flat instalment.',
          ),
        if (gainShare > 60)
          UiCallout(
            intent: UiIntent.info,
            title: 'Most of this corpus is return',
            message:
                '${AppTokens.percent(gainShare, decimals: 0)} of '
                '${AppTokens.lakhCrore(r.futureValue)} was never contributed. '
                'That share is bought with time, which is why the last five '
                'years add more than the first ten.',
          ),
      ],
      formula:
          'i = Annual return ÷ 12 ÷ 100\n'
          'n = Years × 12\n'
          'FV = P × [(1 + i)ⁿ − 1] ÷ i × (1 + i)\n'
          'Invested = P × n\n'
          'Return = FV − Invested',
      notes: const <String>[
        'The formula assumes the instalment is paid at the start of each month '
            'and earns a constant monthly rate. Real returns arrive unevenly, '
            'so treat the corpus as a central case, not a promise.',
        'A step-up is modelled as one raise a year applied to the instalment. '
            'It is the single highest-leverage change here — larger than a '
            'percentage point of return for most durations.',
        'The 4% draw is a planning convention for a portfolio expected to '
            'outlive the withdrawals; it is not a guaranteed income.',
        'Equity mutual fund gains are taxed on redemption, so the corpus shown '
            'is pre-tax. Long-term gains beyond the annual exemption are taxed '
            'at the prevailing LTCG rate.',
      ],
    );
  }
}
