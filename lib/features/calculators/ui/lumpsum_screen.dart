import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/investing_calculators.dart';
import '../services/market_data_service.dart';

/// Lump sum — one deployment, left alone, measured in both money and purchasing
/// power.
///
/// Nominal growth flatters a long horizon, so the corpus is shown beside its
/// inflation-adjusted twin, and beside the same money paid in monthly instead.
class LumpsumCalculatorScreen extends StatefulWidget {
  const LumpsumCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<LumpsumCalculatorScreen> createState() =>
      _LumpsumCalculatorScreenState();
}

class _LumpsumCalculatorScreenState extends State<LumpsumCalculatorScreen> {
  double _principal = 500000;
  double _rate = 13.20;
  double _years = 10;
  double _inflation = 3.65;
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
        _rate = b.nifty10YCagr;
        _inflation = b.cpiInflationRate;
        _isLive = b.isLive;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final int yrs = _years.round();
    final GrowthResult r = calcLumpsum(
      principal: _principal,
      annualRatePct: _rate,
      years: _years,
    );
    final CagrResult cg = calcCagr(
      initial: _principal,
      finalValue: r.futureValue,
      years: _years,
    );
    final InflationResult inf = calcInflation(
      amount: r.futureValue,
      inflationPct: _inflation,
      years: _years,
    );
    final SipResult sip = calcSip(
      monthly: _years <= 0 ? 0 : _principal / (_years * 12),
      annualRatePct: _rate,
      years: _years,
    );
    final double multiple = _principal <= 0 ? 0 : r.futureValue / _principal;
    final double realMultiple = _principal <= 0
        ? 0
        : inf.presentValue / _principal;
    final double gainShare = r.futureValue <= 0
        ? 0
        : r.gain / r.futureValue * 100;
    final double realRate = _rate - _inflation;
    final double lumpEdge = r.futureValue - sip.futureValue;

    // Deflate each year by compounding inflation, without touching dart:math.
    final List<double> nominal = r.yearlyValues;
    final List<double> real = <double>[];
    double deflator = 1;
    for (int i = 0; i < nominal.length; i++) {
      deflator *= 1 + _inflation / 100;
      real.add(nominal[i] / deflator);
    }
    final List<int> marks = <int>[
      for (final int y in const <int>[1, 3, 5, 7, 10, 15, 20, 25, 30])
        if (y <= yrs && y <= nominal.length) y,
    ];

    return AppCalculatorLayout(
      meta: calculatorMetaById('lumpsum'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Value after $yrs years',
        value: AppTokens.lakhCrore(r.futureValue),
        intent: UiIntent.primary,
        tag: '${multiple.toStringAsFixed(2)}× the deployment',
        tagIntent: multiple >= 2 ? UiIntent.bullish : UiIntent.neutral,
        footnote:
            '${AppTokens.lakhCrore(r.gain)} of gain on '
            '${AppTokens.lakhCrore(_principal)} — worth '
            '${AppTokens.lakhCrore(inf.presentValue)} in today’s money at '
            '${AppTokens.percent(_inflation, decimals: 0)} inflation.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Gain',
          value: AppTokens.lakhCrore(r.gain),
          intent: UiIntent.bullish,
          hint: '${AppTokens.percent(gainShare, decimals: 0)} of the corpus',
        ),
        UiStat(
          label: 'CAGR',
          value: AppTokens.percent(cg.cagrPct, decimals: 2),
          intent: UiIntent.info,
          hint: 'compounded, per year',
        ),
        UiStat(
          label: 'Real value',
          value: AppTokens.lakhCrore(inf.presentValue),
          intent: realRate > 0 ? UiIntent.bullish : UiIntent.bearish,
          hint: '${realMultiple.toStringAsFixed(2)}× in real terms',
        ),
        UiStat(
          label: 'Real return',
          value: AppTokens.signedPercent(realRate, decimals: 1),
          intent: AppTokens.plIntent(realRate),
          hint: 'return less inflation',
        ),
        UiStat(
          label: 'Doubles in',
          value: cg.doublingYears <= 0
              ? '—'
              : '${cg.doublingYears.toStringAsFixed(1)} yr',
          hint: yrs <= 0 || cg.doublingYears <= 0
              ? 'at this rate'
              : '${(yrs / cg.doublingYears).toStringAsFixed(1)} doublings',
        ),
        UiStat(
          label: 'Against monthly',
          value: AppTokens.signedMoney(lumpEdge, decimals: 0),
          intent: AppTokens.plIntent(lumpEdge),
          hint: 'same money, spread out',
          spark: nominal,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Deployment',
          children: <Widget>[
            AppCalcNumberField(
              label: 'Amount',
              value: _principal,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[100000, 500000, 1000000, 5000000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              onChanged: (double v) => setState(() => _principal = v),
            ),
            AppCalcSliderField(
              label: 'Duration',
              value: _years,
              min: 1,
              max: 30,
              divisions: 29,
              valueFormatter: (num v) => '${v.round()} yr',
              helper: cg.doublingYears > 0 && cg.doublingYears <= _years
                  ? 'Long enough for '
                        '${(_years / cg.doublingYears).floor()} '
                        'full doubling${(_years / cg.doublingYears).floor() == 1 ? '' : 's'}.'
                  : 'Not yet one doubling at this rate.',
              onChanged: (double v) => setState(() => _years = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Assumptions',
          hint: 'nominal return, then the erosion',
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'Nifty CAGR: ${AppTokens.percent(_rate, decimals: 2)}'
                      : 'Benchmark: ${AppTokens.percent(_rate, decimals: 2)}',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
                UiButton(
                  label: 'Sync Macro',
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
              onChanged: (double v) => setState(() => _rate = v),
            ),
            AppCalcSliderField(
              label: 'Inflation',
              value: _inflation,
              min: 0,
              max: 12,
              divisions: 24,
              intent: _inflation >= _rate ? UiIntent.danger : UiIntent.info,
              valueFormatter: (num v) => AppTokens.percent(v, decimals: 1),
              helper: _inflation >= _rate
                  ? 'Above the return — the corpus loses purchasing power.'
                  : 'Real return '
                        '${AppTokens.signedPercent(realRate, decimals: 1)}.',
              onChanged: (double v) => setState(() => _inflation = v),
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Milestones',
          hint: 'nominal, then in today’s money',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiKeyValueTable(
            labelHeader: 'Year',
            valueHeader: 'Corpus',
            trailingHeader: 'Real',
            rows: <UiKeyValueRow>[
              for (final int y in marks)
                UiKeyValueRow(
                  label: 'Year $y',
                  value: AppTokens.lakhCrore(nominal[y - 1]),
                  trailing: AppTokens.lakhCrore(real[y - 1]),
                  intent: real[y - 1] >= _principal
                      ? UiIntent.bullish
                      : UiIntent.bearish,
                  detail: _principal <= 0
                      ? null
                      : '${(nominal[y - 1] / _principal).toStringAsFixed(2)}× '
                            'nominal · '
                            '${(real[y - 1] / _principal).toStringAsFixed(2)}× real',
                  share: r.futureValue <= 0
                      ? null
                      : (nominal[y - 1] / r.futureValue).clamp(0.0, 1.0),
                ),
              UiKeyValueRow(
                label: 'At $yrs',
                value: AppTokens.lakhCrore(r.futureValue),
                trailing: AppTokens.lakhCrore(inf.presentValue),
                intent: UiIntent.primary,
                emphasis: true,
                detail:
                    '${AppTokens.percent(inf.erosionPct, decimals: 0)} of '
                    'the value is inflated away',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'All at once against monthly',
          hint: 'same total money',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Route',
            valueHeader: 'Corpus',
            trailingHeader: 'Multiple',
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'Deployed now',
                value: AppTokens.lakhCrore(r.futureValue),
                trailing: '${multiple.toStringAsFixed(2)}×',
                intent: lumpEdge >= 0 ? UiIntent.bullish : UiIntent.neutral,
                emphasis: true,
                detail: '${AppTokens.lakhCrore(_principal)} in year zero',
              ),
              UiKeyValueRow(
                label: 'Spread monthly',
                value: AppTokens.lakhCrore(sip.futureValue),
                trailing: sip.invested <= 0
                    ? '—'
                    : '${(sip.futureValue / sip.invested).toStringAsFixed(2)}×',
                intent: lumpEdge < 0 ? UiIntent.bullish : UiIntent.neutral,
                detail: '${AppTokens.price(sip.monthly)} × ${sip.months}',
              ),
              UiKeyValueRow(
                label: 'Difference',
                value: AppTokens.signedMoney(lumpEdge, decimals: 0),
                trailing: sip.futureValue <= 0
                    ? '—'
                    : AppTokens.signedPercent(
                        lumpEdge / sip.futureValue * 100,
                        decimals: 1,
                      ),
                intent: AppTokens.plIntent(lumpEdge),
                detail: lumpEdge >= 0
                    ? 'Time in the market, not timing it'
                    : 'Staggering wins at this rate and duration',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Nominal against real',
          hint: 'the gap is inflation',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (int i = 1; i <= nominal.length; i++)
                i == 1 || i % 5 == 0 || i == nominal.length ? '$i' : '',
            ],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Nominal',
                values: nominal,
                intent: UiIntent.bullish,
                area: true,
              ),
              AppCalcSeries(
                name: 'Real',
                values: real,
                intent: UiIntent.warning,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _principal, label: 'deployed'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Corpus at other returns',
          hint: 'after $yrs years',
          child: UiBarList(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            items: <UiBarListItem>[
              for (final double x in const <double>[6, 8, 10, 12, 15, 18])
                UiBarListItem(
                  label:
                      '${AppTokens.percent(x, decimals: 0)} · '
                      '${(_principal <= 0 ? 0 : calcLumpsum(principal: _principal, annualRatePct: x, years: _years).futureValue / _principal).toStringAsFixed(1)}×',
                  value: calcLumpsum(
                    principal: _principal,
                    annualRatePct: x,
                    years: _years,
                  ).futureValue,
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Deployment against gain',
          hint: 'what the corpus is made of',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: _principal,
                label: 'Deployed ${AppTokens.compactMoney(_principal)}',
              ),
              UiCategorySegment(
                value: r.gain < 0 ? 0 : r.gain,
                label: 'Gain ${AppTokens.compactMoney(r.gain)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Purchasing power',
          hint: 'deployment · real · nominal',
          kind: AppCalcPanelKind.meter,
          child: UiRangeMeter(
            min: 0,
            max: r.futureValue * 1.08 + 1,
            minLabel: '0',
            maxLabel: 'nominal',
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: _principal,
                intent: UiIntent.neutral,
                label: 'deployed',
                alpha: 0.12,
              ),
              UiRangeZone(
                start: inf.presentValue < _principal
                    ? inf.presentValue
                    : _principal,
                end: inf.presentValue < _principal
                    ? _principal
                    : inf.presentValue,
                intent: inf.presentValue >= _principal
                    ? UiIntent.bullish
                    : UiIntent.bearish,
                label: inf.presentValue >= _principal
                    ? 'real gain'
                    : 'real loss',
                alpha: 0.16,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: r.futureValue,
                label: 'Nominal',
                strong: true,
              ),
              UiRangeMarker(
                value: inf.presentValue,
                label: 'Real',
                intent: UiIntent.warning,
                below: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (realRate <= 0)
          UiCallout(
            intent: UiIntent.danger,
            title: 'Inflation is winning',
            message:
                '${AppTokens.percent(_rate, decimals: 1)} of return against '
                '${AppTokens.percent(_inflation, decimals: 1)} of inflation '
                'leaves ${AppTokens.lakhCrore(inf.presentValue)} of purchasing '
                'power from ${AppTokens.lakhCrore(_principal)} deployed. The '
                'number grows; what it buys does not.',
          ),
        if (realRate > 0 && inf.erosionPct > 40)
          UiCallout(
            intent: UiIntent.warning,
            title:
                'Inflation takes '
                '${AppTokens.percent(inf.erosionPct, decimals: 0)} of the corpus',
            message:
                '${AppTokens.lakhCrore(r.futureValue)} in $yrs years buys what '
                '${AppTokens.lakhCrore(inf.presentValue)} buys today. Plan '
                'against the real figure — the nominal one is the illusion.',
          ),
        if (cg.doublingYears > 0 && _years >= cg.doublingYears * 2)
          UiCallout(
            intent: UiIntent.info,
            title: 'Two doublings or more sit inside this horizon',
            message:
                'At ${AppTokens.percent(_rate, decimals: 1)} the money doubles '
                'every ${cg.doublingYears.toStringAsFixed(1)} years, so the '
                'final doubling adds more than everything before it. Duration, '
                'not the rate, is doing the work.',
          ),
      ],
      formula:
          'FV = P × (1 + r)ⁿ\n'
          'Gain = FV − P\n'
          'CAGR = (FV ÷ P)^(1 ÷ n) − 1\n'
          'Real value = FV ÷ (1 + i)ⁿ\n'
          'Doubling ≈ 72 ÷ r',
      notes: const <String>[
        'Compounding is annual here. Daily or monthly compounding at the same '
            'nominal rate lands slightly higher; the difference is small next to '
            'the uncertainty in the rate itself.',
        'The real figure discounts by inflation at the same constant rate. It is '
            'the honest one to plan a goal against, because goals are priced in '
            'future rupees.',
        'The monthly comparison spreads the identical total across the same '
            'duration. A lump sum usually wins on a rising path and loses on a '
            'falling one — this model only knows the rising case.',
        'Nothing here accounts for tax on redemption or for the cost of the '
            'product holding the money. Both come out of the corpus shown.',
      ],
    );
  }
}
