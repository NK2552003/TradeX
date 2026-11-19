import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/investing_calculators.dart';
import '../services/market_data_service.dart';

/// EMI — the instalment, the interest behind it, and what a little extra does.
///
/// The instalment is the easy number. The two that matter are how much of the
/// total repayment is interest, and how far the closing date moves when the
/// instalment is paid above the minimum.
class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen> {
  double _principal = 5000000;
  double _rate = 8.5;
  double _years = 20;
  double _extra = 0;
  double _income = 150000;
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
        _rate = b.homeLoanBenchmarkRate;
        _isLive = b.isLive;
      });
    } catch (_) {}
  }

  static const List<double> _tenures = <double>[10, 15, 20, 25, 30];

  @override
  Widget build(BuildContext context) {
    final int yrs = _years.round();
    final EmiResult r = calcEmi(
      principal: _principal,
      annualRatePct: _rate,
      years: _years,
    );
    final double mRate = _rate / 12 / 100;
    final double firstInterest = _principal * mRate;
    final double firstPrincipal = r.emi - firstInterest;
    final double emiToIncome = _income <= 0 ? 0 : r.emi / _income * 100;
    final double interestMultiple = _principal <= 0
        ? 0
        : r.totalInterest / _principal;
    final bool stretched = emiToIncome > 40;

    // Repay the same loan with an extra amount every month and see where it
    // closes. A plain amortisation walk, no dart:math needed.
    final double pay = r.emi + _extra;
    final List<double> prepayPath = <double>[];
    double bal = _principal;
    double prepaidInterest = 0;
    int paidMonths = 0;
    while (bal > 0.5 && paidMonths < 1200) {
      final double interest = bal * mRate;
      double cut = pay - interest;
      if (cut <= 0) break;
      if (cut > bal) cut = bal;
      bal -= cut;
      prepaidInterest += interest;
      paidMonths++;
      if (paidMonths % 12 == 0) prepayPath.add(bal);
    }
    final double interestSaved = r.totalInterest - prepaidInterest;
    final int monthsSaved = yrs * 12 - paidMonths;

    // Yearly balances split into what each year paid off and what it cost.
    final List<double> balances = r.yearlyBalances;
    final List<double> principalYear = <double>[];
    final List<double> interestYear = <double>[];
    for (int y = 0; y < balances.length; y++) {
      final double prev = y == 0 ? _principal : balances[y - 1];
      final double repaid = prev - balances[y];
      principalYear.add(repaid < 0 ? 0 : repaid);
      interestYear.add(r.emi * 12 - repaid);
    }
    while (prepayPath.length < balances.length) {
      prepayPath.add(0);
    }
    int crossover = 0;
    for (int y = 0; y < balances.length; y++) {
      if (principalYear[y] > interestYear[y]) {
        crossover = y + 1;
        break;
      }
    }
    final List<int> marks = <int>[
      for (final int y in const <int>[1, 3, 5, 10, 15, 20, 25, 30])
        if (y <= yrs && y <= balances.length) y,
    ];

    return AppCalculatorLayout(
      meta: calculatorMetaById('emi'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Monthly instalment',
        value: AppTokens.price(r.emi),
        intent: stretched ? UiIntent.warning : UiIntent.primary,
        tag: '${AppTokens.percent(emiToIncome, decimals: 0)} of income',
        tagIntent: stretched ? UiIntent.bearish : UiIntent.bullish,
        footnote:
            '${AppTokens.lakhCrore(_principal)} at '
            '${AppTokens.percent(_rate, decimals: 2)} over $yrs years — '
            '${AppTokens.lakhCrore(r.totalPayment)} repaid in all, of which '
            '${AppTokens.lakhCrore(r.totalInterest)} is interest.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Total interest',
          value: AppTokens.lakhCrore(r.totalInterest),
          intent: UiIntent.bearish,
          hint: '${interestMultiple.toStringAsFixed(2)}× the amount borrowed',
        ),
        UiStat(
          label: 'Total repaid',
          value: AppTokens.lakhCrore(r.totalPayment),
          hint: '${AppTokens.price(r.emi)} × ${yrs * 12}',
        ),
        UiStat(
          label: 'Interest share',
          value: AppTokens.percent(r.interestSharePct, decimals: 1),
          intent: UiIntent.warning,
          hint: 'of everything repaid',
        ),
        UiStat(
          label: 'First instalment',
          value: AppTokens.price(firstInterest),
          intent: UiIntent.bearish,
          hint:
              'is interest — '
              '${AppTokens.price(firstPrincipal)} cuts the loan',
        ),
        UiStat(
          label: 'Principal leads from',
          value: crossover <= 0 ? '—' : 'Year $crossover',
          intent: UiIntent.info,
          hint: crossover <= 0
              ? 'interest leads throughout'
              : 'repayment outruns interest',
        ),
        UiStat(
          label: _extra > 0 ? 'Interest saved' : 'Add to the instalment',
          value: _extra > 0 ? AppTokens.lakhCrore(interestSaved) : '—',
          intent: _extra > 0 ? UiIntent.bullish : UiIntent.neutral,
          hint: _extra > 0
              ? 'closes ${(monthsSaved / 12).toStringAsFixed(1)} yr early'
              : 'to shorten the loan',
          spark: balances,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'The loan',
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'Benchmark: ${AppTokens.percent(_rate, decimals: 2)}'
                      : 'Preset: ${AppTokens.percent(_rate, decimals: 2)}',
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
            AppCalcNumberField(
              label: 'Amount borrowed',
              value: _principal,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[1000000, 2500000, 5000000, 10000000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              onChanged: (double v) => setState(() => _principal = v),
            ),
            AppCalcSliderField(
              label: 'Interest rate',
              value: _rate,
              min: 6,
              max: 18,
              divisions: 48,
              intent: _rate > 12 ? UiIntent.warning : UiIntent.primary,
              valueFormatter: (num v) => AppTokens.percent(v, decimals: 2),
              helper:
                  'A quarter point here moves the instalment by about '
                  '${AppTokens.price((calcEmi(principal: _principal, annualRatePct: _rate + 0.25, years: _years).emi - r.emi).abs())}.',
              onChanged: (double v) => setState(() => _rate = v),
            ),
            AppCalcSliderField(
              label: 'Tenure',
              value: _years,
              min: 1,
              max: 30,
              divisions: 29,
              valueFormatter: (num v) => '${v.round()} yr',
              helper:
                  'Longer tenure, smaller instalment, more interest — '
                  '${AppTokens.lakhCrore(r.totalInterest)} at this length.',
              onChanged: (double v) => setState(() => _years = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Pressure tests',
          hint: 'paying extra, and what it costs you monthly',
          children: <Widget>[
            AppCalcSliderField(
              label: 'Extra each month',
              value: _extra,
              min: 0,
              max: 50000,
              divisions: 50,
              intent: _extra > 0 ? UiIntent.bullish : UiIntent.neutral,
              valueFormatter: (num v) => AppTokens.price(v),
              helper: _extra > 0
                  ? 'Closes in ${(paidMonths / 12).toStringAsFixed(1)} years and '
                        'saves ${AppTokens.lakhCrore(interestSaved)}.'
                  : 'Any amount above the instalment goes straight to principal.',
              onChanged: (double v) => setState(() => _extra = v),
            ),
            AppCalcNumberField(
              label: 'Monthly income',
              value: _income,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[75000, 150000, 300000, 500000],
              presetLabel: (double v) => AppTokens.compactMoney(v),
              helper:
                  'The instalment takes '
                  '${AppTokens.percent(emiToIncome, decimals: 1)} of it. Lenders '
                  'stop around 50% across all loans.',
              onChanged: (double v) => setState(() => _income = v),
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Amortisation by year',
          hint: 'what each year pays off, and what it costs',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiKeyValueTable(
            labelHeader: 'Year',
            valueHeader: 'Outstanding',
            trailingHeader: 'Interest paid',
            rows: <UiKeyValueRow>[
              for (final int y in marks)
                UiKeyValueRow(
                  label: 'Year $y',
                  value: AppTokens.lakhCrore(balances[y - 1]),
                  trailing: AppTokens.lakhCrore(interestYear[y - 1]),
                  intent: principalYear[y - 1] > interestYear[y - 1]
                      ? UiIntent.bullish
                      : UiIntent.bearish,
                  detail:
                      '${AppTokens.lakhCrore(principalYear[y - 1])} off the loan '
                      '· ${_principal <= 0 ? '—' : AppTokens.percent(balances[y - 1] / _principal * 100, decimals: 0)} still owed',
                  share: _principal <= 0
                      ? null
                      : (balances[y - 1] / _principal).clamp(0.0, 1.0),
                ),
              UiKeyValueRow(
                label: 'Closed',
                value: AppTokens.lakhCrore(r.totalPayment),
                trailing: AppTokens.lakhCrore(r.totalInterest),
                intent: UiIntent.primary,
                emphasis: true,
                detail:
                    '${AppTokens.percent(r.interestSharePct, decimals: 1)} '
                    'of everything repaid was interest',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Tenure against interest',
          hint: 'same loan, other lengths',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Tenure',
            valueHeader: 'Instalment',
            trailingHeader: 'Interest',
            rows: <UiKeyValueRow>[
              for (final double t in _tenures)
                UiKeyValueRow(
                  label: '${t.round()} yr',
                  value: AppTokens.price(
                    calcEmi(
                      principal: _principal,
                      annualRatePct: _rate,
                      years: t,
                    ).emi,
                  ),
                  trailing: AppTokens.lakhCrore(
                    calcEmi(
                      principal: _principal,
                      annualRatePct: _rate,
                      years: t,
                    ).totalInterest,
                  ),
                  intent: t <= _years ? UiIntent.bullish : UiIntent.bearish,
                  emphasis: (t - _years).abs() < 0.5,
                  detail: (t - _years).abs() < 0.5
                      ? 'Selected'
                      : '${AppTokens.signedMoney(calcEmi(principal: _principal, annualRatePct: _rate, years: t).totalInterest - r.totalInterest, decimals: 0)} '
                            'against the current tenure',
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'The balance falling',
          hint: _extra > 0
              ? 'minimum against paying extra'
              : 'outstanding loan',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (int i = 1; i <= balances.length; i++)
                i == 1 || i % 5 == 0 || i == balances.length ? '$i' : '',
            ],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Minimum',
                values: balances,
                intent: UiIntent.warning,
                area: true,
              ),
              if (_extra > 0)
                AppCalcSeries(
                  name: 'Paying extra',
                  values: prepayPath,
                  intent: UiIntent.bullish,
                ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _principal / 2, label: 'half repaid'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Interest against principal',
          hint: 'per year, as the split turns',
          child: AppCalcTrendChart(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Interest',
                values: interestYear,
                intent: UiIntent.bearish,
              ),
              AppCalcSeries(
                name: 'Principal',
                values: principalYear,
                intent: UiIntent.bullish,
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'What you actually repay',
          hint: 'borrowed · interest',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: _principal,
                label: 'Borrowed ${AppTokens.compactMoney(_principal)}',
              ),
              UiCategorySegment(
                value: r.totalInterest < 0 ? 0 : r.totalInterest,
                label: 'Interest ${AppTokens.compactMoney(r.totalInterest)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Instalment against income',
          hint: 'comfortable · stretched · refused',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: 0,
            max: emiToIncome > 70 ? emiToIncome + 5 : 75,
            minLabel: '0%',
            maxLabel: 'of income',
            valueFormatter: (num v) => AppTokens.percent(v, decimals: 0),
            zones: const <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: 30,
                intent: UiIntent.bullish,
                label: 'comfortable',
                alpha: 0.14,
              ),
              UiRangeZone(
                start: 30,
                end: 50,
                intent: UiIntent.warning,
                label: 'stretched',
                alpha: 0.14,
              ),
              UiRangeZone(
                start: 50,
                end: 75,
                intent: UiIntent.bearish,
                label: 'lenders refuse',
                alpha: 0.16,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: emiToIncome,
                label: 'This loan',
                intent: stretched ? UiIntent.bearish : UiIntent.bullish,
                strong: true,
              ),
              if (_extra > 0)
                UiRangeMarker(
                  value: _income <= 0 ? 0 : pay / _income * 100,
                  label: 'With extra',
                  intent: UiIntent.info,
                  below: true,
                ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (interestMultiple >= 1)
          UiCallout(
            intent: UiIntent.bearish,
            title: 'The interest exceeds the loan',
            message:
                '${AppTokens.lakhCrore(r.totalInterest)} of interest on '
                '${AppTokens.lakhCrore(_principal)} borrowed — '
                '${interestMultiple.toStringAsFixed(2)}× the amount, over $yrs '
                'years. Cutting the tenure is the only lever that changes this '
                'much; the rate barely moves it.',
          ),
        if (_extra > 0 && monthsSaved > 0)
          UiCallout(
            intent: UiIntent.bullish,
            title:
                'Closes ${(monthsSaved / 12).toStringAsFixed(1)} years early',
            message:
                '${AppTokens.price(_extra)} more each month ends the loan in '
                '${(paidMonths / 12).toStringAsFixed(1)} years instead of $yrs '
                'and saves ${AppTokens.lakhCrore(interestSaved)} of interest — '
                'about '
                '${AppTokens.percent(r.totalInterest <= 0 ? 0 : interestSaved / r.totalInterest * 100, decimals: 0)} '
                'of the total.',
          ),
        if (stretched)
          UiCallout(
            intent: UiIntent.warning,
            title:
                'The instalment takes '
                '${AppTokens.percent(emiToIncome, decimals: 0)} of income',
            message:
                'Above 40% leaves little room for a rate rise. A floating loan '
                'repriced two points higher would cost '
                '${AppTokens.price(calcEmi(principal: _principal, annualRatePct: _rate + 2, years: _years).emi)} '
                'a month — check that figure fits before signing this one.',
          ),
      ],
      formula:
          'i = Rate ÷ 12 ÷ 100\n'
          'n = Years × 12\n'
          'EMI = P × i × (1 + i)ⁿ ÷ [(1 + i)ⁿ − 1]\n'
          'Total interest = EMI × n − P\n'
          'Each month: interest = balance × i',
      notes: const <String>[
        'Every instalment is the same size, but its split is not. Interest is '
            'charged on the outstanding balance, so the early years are almost '
            'all interest and the last years almost all principal.',
        'Extra payments are modelled as going straight to principal with the '
            'instalment unchanged, which shortens the loan. Most lenders also '
            'allow the alternative — keep the tenure and reduce the instalment.',
        'Floating rates reprice against an external benchmark. Lenders usually '
            'hold the instalment and extend the tenure instead, which quietly '
            'adds far more interest than the rate change suggests.',
        'Processing fees, insurance bundled into the loan, and prepayment '
            'charges on fixed-rate loans are outside these figures.',
      ],
    );
  }
}
