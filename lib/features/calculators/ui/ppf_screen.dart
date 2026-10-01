import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/investing_calculators.dart';
import '../services/market_data_service.dart';

/// PPF — a fixed annual habit, compounded untaxed, and what that exemption is
/// actually worth.
///
/// The headline corpus is easy. The point of the account is that none of the
/// interest is taxed, so it is shown against the same deposits into a taxable
/// product and against the pre-tax rate it is equivalent to.
class PpfCalculatorScreen extends StatefulWidget {
  const PpfCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<PpfCalculatorScreen> createState() => _PpfCalculatorScreenState();
}

class _PpfCalculatorScreenState extends State<PpfCalculatorScreen> {
  double _yearly = 150000;
  double _rate = 7.1;
  double _years = 15;
  double _slab = 30;
  bool _isVerified = true;

  static const double _annualCap = 150000;

  @override
  void initState() {
    super.initState();
    _fetchLivePpfRate();
  }

  Future<void> _fetchLivePpfRate() async {
    try {
      final MacroBenchmarks b =
          await MarketDataService.instance.getMacroBenchmarks();
      if (!mounted) return;
      setState(() {
        _rate = b.ppfRate;
        _isVerified = true;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final int yrs = _years.round();
    final PpfResult r = calcPpf(
      yearlyDeposit: _yearly,
      annualRatePct: _rate,
      years: yrs,
    );
    // The same deposits into something taxed at the slab, year after year.
    final double postTaxRate = _rate * (1 - _slab / 100);
    final PpfResult taxed = calcPpf(
      yearlyDeposit: _yearly,
      annualRatePct: postTaxRate,
      years: yrs,
    );
    final PpfResult ext5 = calcPpf(
      yearlyDeposit: _yearly,
      annualRatePct: _rate,
      years: yrs + 5,
    );
    final PpfResult ext10 = calcPpf(
      yearlyDeposit: _yearly,
      annualRatePct: _rate,
      years: yrs + 10,
    );
    final double edge = r.futureValue - taxed.futureValue;
    final double preTaxEquivalent = _slab >= 100 ? _rate : _rate / (1 - _slab / 100);
    final double deductionPerYear =
        (_yearly > _annualCap ? _annualCap : _yearly) * _slab / 100;
    final double deductionTotal = deductionPerYear * yrs;
    final double multiple = r.invested <= 0 ? 0 : r.futureValue / r.invested;
    final double gainShare = r.futureValue <= 0
        ? 0
        : r.gain / r.futureValue * 100;
    final double monthly = _yearly / 12;
    final double headroom = _annualCap - _yearly;
    final bool atCap = headroom <= 0;

    // Interest credited in each year, from the balances themselves.
    final List<double> balances = r.yearlyValues;
    final List<double> interestByYear = <double>[];
    for (int i = 0; i < balances.length; i++) {
      final double prev = i == 0 ? 0 : balances[i - 1];
      interestByYear.add(balances[i] - prev - _yearly);
    }
    final List<double> deposited = <double>[
      for (int i = 1; i <= balances.length; i++) _yearly * i,
    ];
    final List<double> taxedBalances = taxed.yearlyValues;
    final List<int> marks = <int>[
      for (final int y in const <int>[1, 3, 5, 7, 10, 15, 20, 25])
        if (y <= yrs && y <= balances.length) y,
    ];

    return AppCalculatorLayout(
      meta: calculatorMetaById('ppf'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Maturity after $yrs years',
        value: AppTokens.lakhCrore(r.futureValue),
        intent: UiIntent.primary,
        tag: 'tax-free',
        tagIntent: UiIntent.bullish,
        footnote:
            '${AppTokens.lakhCrore(r.invested)} deposited over $yrs years at '
            '${AppTokens.percent(_rate, decimals: 2)} — '
            '${AppTokens.lakhCrore(r.gain)} of interest, none of it taxed.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Deposited',
          value: AppTokens.lakhCrore(r.invested),
          hint: '${AppTokens.price(_yearly)} × $yrs years',
        ),
        UiStat(
          label: 'Interest',
          value: AppTokens.lakhCrore(r.gain),
          intent: UiIntent.bullish,
          hint: '${AppTokens.percent(gainShare, decimals: 0)} of the corpus',
        ),
        UiStat(
          label: 'Multiple',
          value: '${multiple.toStringAsFixed(2)}×',
          intent: UiIntent.info,
          hint: 'on money paid in',
        ),
        UiStat(
          label: 'Pre-tax equal to',
          value: AppTokens.percent(preTaxEquivalent, decimals: 2),
          intent: UiIntent.bullish,
          hint: 'at the ${AppTokens.percent(_slab, decimals: 0)} slab',
        ),
        UiStat(
          label: 'Exemption worth',
          value: AppTokens.lakhCrore(edge),
          intent: UiIntent.bullish,
          hint: 'against a taxed deposit',
          spark: balances,
        ),
        UiStat(
          label: '80C saving',
          value: AppTokens.lakhCrore(deductionTotal),
          intent: UiIntent.info,
          hint: '${AppTokens.price(deductionPerYear)} a year',
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'The deposit',
          hint: 'capped at ₹1.5 L a year',
          children: <Widget>[
            AppCalcNumberField(
              label: 'Yearly deposit',
              value: _yearly,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[12000, 50000, 100000, 150000],
              presetLabel: (double v) => AppTokens.compactMoney(v),
              helper: atCap
                  ? 'At the statutory maximum — ${AppTokens.price(monthly)} a '
                        'month.'
                  : '${AppTokens.price(headroom)} of the annual limit unused.',
              onChanged: (double v) => setState(() => _yearly = v),
            ),
            AppCalcSliderField(
              label: 'Years held',
              value: _years,
              min: 5,
              max: 35,
              divisions: 30,
              valueFormatter: (num v) => '${v.round()} yr',
              helper: yrs < 15
                  ? 'The account locks for 15 years; earlier years are shown for '
                        'reference only.'
                  : 'Extends in five-year blocks after the 15-year term.',
              onChanged: (double v) => setState(() => _years = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Rate and slab',
          hint: 'what it pays, what it saves',
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: <Widget>[
                UiBadge(
                  label: _isVerified
                      ? 'Govt: ${AppTokens.percent(_rate, decimals: 2)} Verified'
                      : 'Statutory: ${AppTokens.percent(_rate, decimals: 2)}',
                  intent: UiIntent.success,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
                UiButton(
                  label: 'Verify Rate',
                  leadingIcon: Icons.verified_outlined,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: _fetchLivePpfRate,
                ),
              ],
            ),
            AppCalcSliderField(
              label: 'Interest rate',
              value: _rate,
              min: 6,
              max: 9,
              divisions: 30,
              valueFormatter: (num v) => AppTokens.percent(v, decimals: 2),
              helper: 'Ministry of Finance quarterly notification rate.',
              onChanged: (double v) => setState(() => _rate = v),
            ),
            AppCalcSegment<double>(
              label: 'Tax slab',
              value: _slab,
              onChanged: (double v) => setState(() => _slab = v),
              helper: 'Sets what the exemption and the 80C deduction are worth.',
              options: const <UiToggleOption<double>>[
                UiToggleOption<double>(value: 0, label: 'Nil'),
                UiToggleOption<double>(value: 5, label: '5%'),
                UiToggleOption<double>(value: 20, label: '20%'),
                UiToggleOption<double>(value: 30, label: '30%'),
              ],
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'The account, year by year',
          hint: 'balance and the interest credited',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiKeyValueTable(
            labelHeader: 'Year',
            valueHeader: 'Balance',
            trailingHeader: 'Interest',
            rows: <UiKeyValueRow>[
              for (final int y in marks)
                UiKeyValueRow(
                  label: 'Year $y',
                  value: AppTokens.lakhCrore(balances[y - 1]),
                  trailing: AppTokens.price(interestByYear[y - 1]),
                  intent: UiIntent.neutral,
                  detail: '${AppTokens.lakhCrore(deposited[y - 1])} paid in · '
                      '${AppTokens.lakhCrore(balances[y - 1] - deposited[y - 1])} '
                      'earned',
                  share: r.futureValue <= 0
                      ? null
                      : (balances[y - 1] / r.futureValue).clamp(0.0, 1.0),
                ),
              UiKeyValueRow(
                label: 'At $yrs',
                value: AppTokens.lakhCrore(r.futureValue),
                trailing: AppTokens.price(
                  interestByYear.isEmpty ? 0 : interestByYear.last,
                ),
                intent: UiIntent.primary,
                emphasis: true,
                detail: 'Withdrawable in full, tax-free',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'What the exemption buys',
          hint: 'same deposits, taxed at the slab',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Route',
            valueHeader: 'Corpus',
            trailingHeader: 'Rate',
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'PPF',
                value: AppTokens.lakhCrore(r.futureValue),
                trailing: AppTokens.percent(_rate, decimals: 2),
                intent: UiIntent.bullish,
                emphasis: true,
                detail: 'Interest and maturity both exempt',
              ),
              UiKeyValueRow(
                label: 'Taxed deposit',
                value: AppTokens.lakhCrore(taxed.futureValue),
                trailing: AppTokens.percent(postTaxRate, decimals: 2),
                intent: UiIntent.bearish,
                detail: 'Same ${AppTokens.percent(_rate, decimals: 2)} gross, '
                    'slab taken each year',
              ),
              UiKeyValueRow(
                label: 'Difference',
                value: AppTokens.signedMoney(edge, decimals: 0),
                trailing: AppTokens.percent(preTaxEquivalent, decimals: 2),
                intent: AppTokens.plIntent(edge),
                detail: 'A taxable product must pay '
                    '${AppTokens.percent(preTaxEquivalent, decimals: 2)} to match',
              ),
              UiKeyValueRow(
                label: 'Extend 5 years',
                value: AppTokens.lakhCrore(ext5.futureValue),
                trailing: '+${AppTokens.compactMoney(ext5.futureValue - r.futureValue)}',
                intent: UiIntent.info,
                detail: 'One block, deposits continuing',
              ),
              UiKeyValueRow(
                label: 'Extend 10 years',
                value: AppTokens.lakhCrore(ext10.futureValue),
                trailing: '+${AppTokens.compactMoney(ext10.futureValue - r.futureValue)}',
                intent: UiIntent.info,
                detail: 'Two blocks, deposits continuing',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Balance against deposits',
          hint: 'the gap is untaxed compounding',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (int i = 1; i <= balances.length; i++)
                i == 1 || i % 5 == 0 || i == balances.length ? '$i' : '',
            ],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'PPF',
                values: balances,
                intent: UiIntent.bullish,
                area: true,
              ),
              AppCalcSeries(
                name: 'If taxed',
                values: taxedBalances,
                intent: UiIntent.warning,
              ),
              AppCalcSeries(
                name: 'Paid in',
                values: deposited,
                intent: UiIntent.neutral,
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Interest credited each year',
          hint: 'it accelerates without new money',
          child: AppCalcTrendChart(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Credited',
                values: interestByYear,
                intent: UiIntent.info,
                bars: true,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _yearly, label: 'a year’s deposit'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Deposits against interest',
          hint: 'what the maturity is made of',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: r.invested,
                label: 'Paid in ${AppTokens.compactMoney(r.invested)}',
              ),
              UiCategorySegment(
                value: r.gain < 0 ? 0 : r.gain,
                label: 'Interest ${AppTokens.compactMoney(r.gain)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'The rate, and what it is equal to',
          hint: 'gross · after slab · equivalent',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: 0,
            max: preTaxEquivalent + 2,
            minLabel: '0%',
            maxLabel: 'rate',
            valueFormatter: (num v) => AppTokens.percent(v, decimals: 2),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: postTaxRate,
                intent: UiIntent.neutral,
                label: 'what a taxed deposit keeps',
                alpha: 0.12,
              ),
              UiRangeZone(
                start: postTaxRate,
                end: preTaxEquivalent,
                intent: UiIntent.bullish,
                label: 'the exemption',
                alpha: 0.16,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(value: _rate, label: 'PPF', strong: true),
              UiRangeMarker(
                value: preTaxEquivalent,
                label: 'Equivalent',
                intent: UiIntent.bullish,
              ),
              UiRangeMarker(
                value: postTaxRate,
                label: 'Taxed',
                intent: UiIntent.warning,
                below: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (!atCap && _slab > 0)
          UiCallout(
            intent: UiIntent.info,
            title: '${AppTokens.price(headroom)} of the limit is unused',
            message:
                'Raising the deposit to the ₹1.5 L cap adds about '
                '${AppTokens.lakhCrore(calcPpf(yearlyDeposit: _annualCap, annualRatePct: _rate, years: yrs).futureValue - r.futureValue)} '
                'to the maturity and '
                '${AppTokens.price((_annualCap - _yearly) * _slab / 100)} a year '
                'of tax relief under 80C.',
          ),
        if (_slab >= 30)
          UiCallout(
            intent: UiIntent.bullish,
            title: 'Worth '
                '${AppTokens.percent(preTaxEquivalent, decimals: 2)} pre-tax',
            message:
                'At the 30% bracket a tax-free '
                '${AppTokens.percent(_rate, decimals: 2)} is the same as '
                '${AppTokens.percent(preTaxEquivalent, decimals: 2)} from a '
                'taxable deposit. No bank offers that on a comparable risk, '
                'which is the whole case for the account.',
          ),
        if (yrs < 15)
          UiCallout(
            intent: UiIntent.warning,
            title: 'The account is locked for 15 years',
            message:
                'A $yrs-year figure is arithmetic, not an option. Partial '
                'withdrawal opens from the seventh year and is capped; a loan '
                'against the balance is available between the third and sixth. '
                'Treat the maturity as reachable only at 15.',
          ),
      ],
      formula:
          'Balance grows on the whole balance each year\n'
          'Bₙ = (Bₙ₋₁ + Deposit) × (1 + r)\n'
          'Interest = Maturity − Deposits\n'
          'Equivalent = r ÷ (1 − slab)\n'
          '80C saving = min(Deposit, 1.5 L) × slab',
      notes: const <String>[
        'Interest is credited on the lowest balance between the fifth and the '
            'last day of each month, so a deposit made before 5 April earns a '
            'full year. This model compounds annually and ignores that timing.',
        'The rate is notified every quarter and has moved between 7.1% and 8.7% '
            'over the last decade. A single fixed rate across 15 years is a '
            'convenience, not a guarantee.',
        'The account is exempt at all three stages — deposit, interest and '
            'maturity. The comparison above taxes the alternative each year, '
            'which is how interest income is actually assessed.',
        'The ₹1.5 L cap is per person across all PPF accounts, and the 80C '
            'limit is shared with EPF, ELSS, insurance premiums and the rest of '
            'the section.',
      ],
    );
  }
}
