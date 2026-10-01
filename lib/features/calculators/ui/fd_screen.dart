import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/investing_calculators.dart';
import '../services/market_data_service.dart';

/// Fixed deposit — the guaranteed number, and the two things that take it apart.
///
/// A deposit quotes one rate and pays another: compounding lifts it, the tax
/// slab cuts it, inflation decides whether anything is left. All four figures
/// sit on the same scale here.
class FdCalculatorScreen extends StatefulWidget {
  const FdCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<FdCalculatorScreen> createState() => _FdCalculatorScreenState();
}

class _FdCalculatorScreenState extends State<FdCalculatorScreen> {
  double _principal = 500000;
  double _rate = 7.05;
  double _months = 60;
  int _nPerYear = 4;
  double _slab = 30;
  double _inflation = 3.65;
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
        _rate = b.fdBenchmarkRate;
        _inflation = b.cpiInflationRate;
        _isLive = b.isLive;
      });
    } catch (_) {}
  }

  static const Map<int, String> _freqNames = <int, String>{
    1: 'Annually',
    2: 'Half-yearly',
    4: 'Quarterly',
    12: 'Monthly',
  };

  @override
  Widget build(BuildContext context) {
    final FdResult r = calcFd(
      principal: _principal,
      annualRatePct: _rate,
      months: _months,
      nPerYear: _nPerYear,
    );
    final double years = _months / 12;
    final double tax = r.gain * _slab / 100;
    final double netInterest = r.gain - tax;
    final double netMaturity = _principal + netInterest;
    final double postTaxYield = r.effectiveYieldPct * (1 - _slab / 100);
    final double realYield = postTaxYield - _inflation;
    final double monthlyInterest = _months <= 0 ? 0 : r.gain / _months;
    final bool losesToInflation = realYield < 0;
    final List<double> balance = r.yearlyValues;

    // The same deposit under every compounding convention on offer.
    final List<(int, double, double)> freqs = <(int, double, double)>[
      for (final int n in const <int>[1, 2, 4, 12])
        (
          n,
          calcFd(
            principal: _principal,
            annualRatePct: _rate,
            months: _months,
            nPerYear: n,
          ).futureValue,
          calcFd(
            principal: _principal,
            annualRatePct: _rate,
            months: _months,
            nPerYear: n,
          ).effectiveYieldPct,
        ),
    ];
    const List<double> rates = <double>[5.5, 6.0, 6.5, 7.0, 7.5, 8.0];

    return AppCalculatorLayout(
      meta: calculatorMetaById('fd'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Maturity value',
        value: AppTokens.lakhCrore(r.futureValue),
        intent: losesToInflation ? UiIntent.warning : UiIntent.primary,
        tag: '${_freqNames[_nPerYear] ?? 'Quarterly'} compounding',
        tagIntent: UiIntent.info,
        footnote:
            '${AppTokens.lakhCrore(r.gain)} of interest over '
            '${years.toStringAsFixed(years == years.roundToDouble() ? 0 : 1)} '
            'years — ${AppTokens.lakhCrore(netMaturity)} after '
            '${AppTokens.percent(_slab, decimals: 0)} tax.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Interest',
          value: AppTokens.lakhCrore(r.gain),
          intent: UiIntent.bullish,
          hint: '${AppTokens.price(monthlyInterest)} a month, averaged',
        ),
        UiStat(
          label: 'Effective yield',
          value: AppTokens.percent(r.effectiveYieldPct, decimals: 2),
          intent: UiIntent.info,
          hint: 'quoted ${AppTokens.percent(_rate, decimals: 2)}',
        ),
        UiStat(
          label: 'Tax on interest',
          value: AppTokens.price(tax),
          intent: UiIntent.bearish,
          hint: 'at the ${AppTokens.percent(_slab, decimals: 0)} slab',
        ),
        UiStat(
          label: 'After tax',
          value: AppTokens.percent(postTaxYield, decimals: 2),
          intent: postTaxYield > _inflation
              ? UiIntent.bullish
              : UiIntent.bearish,
          hint: 'yield you keep',
        ),
        UiStat(
          label: 'Real yield',
          value: AppTokens.signedPercent(realYield, decimals: 2),
          intent: AppTokens.plIntent(realYield),
          hint: losesToInflation ? 'below inflation' : 'above inflation',
        ),
        UiStat(
          label: 'Net maturity',
          value: AppTokens.lakhCrore(netMaturity),
          hint: 'principal plus kept interest',
          spark: balance,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Deposit',
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
              label: 'Principal',
              value: _principal,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[100000, 500000, 1000000, 2500000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              onChanged: (double v) => setState(() => _principal = v),
            ),
            AppCalcNumberField(
              label: 'Interest rate',
              value: _rate,
              suffix: '%',
              helper: 'Effective '
                  '${AppTokens.percent(r.effectiveYieldPct, decimals: 2)} once '
                  'compounding is counted.',
              onChanged: (double v) => setState(() => _rate = v),
            ),
            AppCalcSliderField(
              label: 'Tenure',
              value: _months,
              min: 6,
              max: 120,
              divisions: 38,
              valueFormatter: (num v) => v < 12
                  ? '${v.round()} mo'
                  : '${(v / 12).toStringAsFixed(v % 12 == 0 ? 0 : 1)} yr',
              onChanged: (double v) => setState(() => _months = v),
            ),
            AppCalcSegment<int>(
              label: 'Compounding',
              value: _nPerYear,
              onChanged: (int v) => setState(() => _nPerYear = v),
              options: const <UiToggleOption<int>>[
                UiToggleOption<int>(value: 1, label: '1/yr'),
                UiToggleOption<int>(value: 2, label: '2/yr'),
                UiToggleOption<int>(value: 4, label: '4/yr'),
                UiToggleOption<int>(value: 12, label: '12/yr'),
              ],
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'What it is measured against',
          hint: 'tax bracket and inflation',
          children: <Widget>[
            AppCalcSegment<double>(
              label: 'Tax slab',
              value: _slab,
              onChanged: (double v) => setState(() => _slab = v),
              helper: 'Interest is added to income and taxed at the slab.',
              options: const <UiToggleOption<double>>[
                UiToggleOption<double>(value: 0, label: 'Nil'),
                UiToggleOption<double>(value: 5, label: '5%'),
                UiToggleOption<double>(value: 20, label: '20%'),
                UiToggleOption<double>(value: 30, label: '30%'),
              ],
            ),
            AppCalcSliderField(
              label: 'Inflation',
              value: _inflation,
              min: 0,
              max: 12,
              divisions: 24,
              intent: losesToInflation ? UiIntent.danger : UiIntent.info,
              valueFormatter: (num v) => AppTokens.percent(v, decimals: 1),
              helper: losesToInflation
                  ? 'The deposit loses purchasing power after tax.'
                  : 'Real yield '
                        '${AppTokens.signedPercent(realYield, decimals: 2)}.',
              onChanged: (double v) => setState(() => _inflation = v),
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Maturity ledger',
          hint: 'quoted rate to real return',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiKeyValueTable(
            labelHeader: 'Line',
            valueHeader: 'Amount',
            trailingHeader: 'Rate',
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'Principal',
                value: AppTokens.lakhCrore(_principal),
                trailing: '—',
                detail: 'Locked for ${_months.toStringAsFixed(0)} months',
              ),
              UiKeyValueRow(
                label: 'Interest earned',
                value: AppTokens.lakhCrore(r.gain),
                trailing: AppTokens.percent(r.effectiveYieldPct, decimals: 2),
                intent: UiIntent.bullish,
                detail: '${_freqNames[_nPerYear] ?? ''} compounding',
                share: r.futureValue <= 0
                    ? null
                    : (r.gain / r.futureValue).clamp(0.0, 1.0),
              ),
              UiKeyValueRow(
                label: 'Tax on interest',
                value: AppTokens.signedMoney(-tax, decimals: 0),
                trailing: AppTokens.percent(_slab, decimals: 0),
                intent: UiIntent.bearish,
                detail: 'Taxed each year as it accrues, not at maturity',
              ),
              UiKeyValueRow(
                label: 'Net maturity',
                value: AppTokens.lakhCrore(netMaturity),
                trailing: AppTokens.percent(postTaxYield, decimals: 2),
                intent: UiIntent.primary,
                emphasis: true,
                detail: '${AppTokens.lakhCrore(netInterest)} of interest kept',
              ),
              UiKeyValueRow(
                label: 'After inflation',
                value: AppTokens.signedPercent(realYield, decimals: 2),
                trailing: AppTokens.percent(_inflation, decimals: 1),
                intent: AppTokens.plIntent(realYield),
                emphasis: true,
                detail: losesToInflation
                    ? 'Purchasing power falls over the tenure'
                    : 'Purchasing power grows slowly',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Compounding compared',
          hint: 'same rate, same tenure',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Credited',
            valueHeader: 'Maturity',
            trailingHeader: 'Effective',
            rows: <UiKeyValueRow>[
              for (final (int, double, double) f in freqs)
                UiKeyValueRow(
                  label: _freqNames[f.$1] ?? '${f.$1}/yr',
                  value: AppTokens.lakhCrore(f.$2),
                  trailing: AppTokens.percent(f.$3, decimals: 2),
                  intent: f.$1 == _nPerYear
                      ? UiIntent.primary
                      : UiIntent.neutral,
                  emphasis: f.$1 == _nPerYear,
                  detail: f.$1 == _nPerYear
                      ? 'Selected'
                      : AppTokens.signedMoney(
                          f.$2 - r.futureValue,
                          decimals: 0,
                        ),
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Balance over the tenure',
          hint: 'interest on interest',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (int i = 1; i <= balance.length; i++)
                i == 1 || i % 2 == 0 || i == balance.length ? '$i' : '',
            ],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Balance',
                values: balance,
                intent: UiIntent.bullish,
                area: true,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _principal, label: 'principal'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Interest at other rates',
          hint: 'over the same tenure',
          child: UiBarList(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            items: <UiBarListItem>[
              for (final double x in rates)
                UiBarListItem(
                  label: AppTokens.percent(x, decimals: 1),
                  value: calcFd(
                    principal: _principal,
                    annualRatePct: x,
                    months: _months,
                    nPerYear: _nPerYear,
                  ).gain,
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Where the maturity goes',
          hint: 'principal · kept · taxed',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: _principal,
                label: 'Principal ${AppTokens.compactMoney(_principal)}',
              ),
              UiCategorySegment(
                value: netInterest < 0 ? 0 : netInterest,
                label: 'Kept ${AppTokens.compactMoney(netInterest)}',
              ),
              UiCategorySegment(
                value: tax < 0 ? 0 : tax,
                label: 'Tax ${AppTokens.compactMoney(tax)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Yield, step by step',
          hint: 'quoted → effective → net → real',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: realYield < 0 ? realYield - 1 : 0,
            max: (r.effectiveYieldPct > _rate ? r.effectiveYieldPct : _rate) + 1,
            minLabel: realYield < 0 ? 'loss' : '0%',
            maxLabel: 'gross',
            valueFormatter: (num v) => AppTokens.percent(v, decimals: 2),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: _inflation,
                intent: UiIntent.bearish,
                label: 'inflation',
                alpha: 0.14,
              ),
              UiRangeZone(
                start: _inflation,
                end: postTaxYield > _inflation ? postTaxYield : _inflation,
                intent: UiIntent.bullish,
                label: 'real gain',
                alpha: 0.16,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: r.effectiveYieldPct,
                label: 'Effective',
                strong: true,
              ),
              UiRangeMarker(
                value: postTaxYield,
                label: 'After tax',
                intent: UiIntent.warning,
                below: true,
              ),
              UiRangeMarker(
                value: realYield,
                label: 'Real',
                intent: AppTokens.plIntent(realYield) == UiIntent.bullish
                    ? UiIntent.bullish
                    : UiIntent.bearish,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (losesToInflation)
          UiCallout(
            intent: UiIntent.danger,
            title: 'The deposit loses to inflation',
            message:
                '${AppTokens.percent(postTaxYield, decimals: 2)} kept after tax '
                'against ${AppTokens.percent(_inflation, decimals: 1)} of '
                'inflation is ${AppTokens.signedPercent(realYield, decimals: 2)} '
                'a year in real terms. The maturity value is certain; its '
                'purchasing power is certainly lower.',
          ),
        if (r.gain / (_months <= 0 ? 1 : _months / 12) > 40000)
          UiCallout(
            intent: UiIntent.info,
            title: 'TDS will apply',
            message:
                'Interest works out to about '
                '${AppTokens.price(r.gain / (_months <= 0 ? 1 : _months / 12))} '
                'a year, above the ₹40,000 bank threshold, so 10% is deducted '
                'at source. It is credit against the slab liability, not an '
                'extra tax.',
          ),
        if (_slab >= 30 && !losesToInflation)
          UiCallout(
            intent: UiIntent.warning,
            title: 'The slab takes '
                '${AppTokens.price(tax)} of the interest',
            message:
                'At the 30% bracket a '
                '${AppTokens.percent(_rate, decimals: 2)} deposit pays '
                '${AppTokens.percent(postTaxYield, decimals: 2)}. Debt funds '
                'and arbitrage funds hold the same risk profile with different '
                'tax treatment — worth comparing before locking the tenure.',
          ),
      ],
      formula:
          'n = Compounding periods a year\n'
          'Maturity = P × (1 + r ÷ n)^(n × years)\n'
          'Effective yield = (1 + r ÷ n)ⁿ − 1\n'
          'After tax = Effective × (1 − slab)\n'
          'Real = After tax − Inflation',
      notes: const <String>[
        'Interest on a cumulative deposit is taxable in the year it accrues, '
            'even though the cash arrives at maturity. The tax line above '
            'assumes the whole liability, not a deferral.',
        'Banks quote the nominal rate and compound quarterly by convention. The '
            'effective yield is the honest comparison figure across products.',
        'Breaking a deposit early usually costs a penalty of around one percent '
            'on the rate for the period actually held — the maturity above '
            'assumes it runs to term.',
        'Senior citizen rates typically add 0.25% to 0.50%. Enter the rate you '
            'have actually been offered rather than the card rate.',
      ],
    );
  }
}
