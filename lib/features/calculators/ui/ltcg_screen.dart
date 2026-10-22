import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/tax_calculators.dart';
import '../services/market_data_service.dart';

/// Long-term capital gains — a lower rate, an annual exemption that resets,
/// and the harvesting habit that uses it.
///
/// The exemption is the whole story. It is per financial year and per person,
/// so a gain booked in two years instead of one can cost nothing at all.
class LtcgCalculatorScreen extends StatefulWidget {
  const LtcgCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<LtcgCalculatorScreen> createState() => _LtcgCalculatorScreenState();
}

class _LtcgCalculatorScreenState extends State<LtcgCalculatorScreen> {
  EquityTaxPeriod _taxPeriod = EquityTaxPeriod.from23July2024;
  double get _stcgRate => _taxPeriod.stcgRate;
  double get _ltcgRate => _taxPeriod.ltcgRate;
  double get _ltcgExemption => _taxPeriod.exemption;
  String _symbol = 'RELIANCE';
  double _livePrice = 1313.80;
  bool _isLive = false;
  double _gain = 500000;
  double _used = 0;
  double _holdingDays = 500;
  double _harvestYears = 5;

  @override
  void initState() {
    super.initState();
    _fetchLiveQuote(_symbol);
  }

  Future<void> _fetchLiveQuote(String sym) async {
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(sym);
      if (!mounted) return;
      setState(() {
        _symbol = sym;
        _livePrice = q.price;
        _isLive = q.isLive;
      });
    } catch (_) {}
  }

  Future<void> _applyLiveGain(String sym) async {
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(sym);
      if (!mounted) return;
      setState(() {
        _symbol = sym;
        _livePrice = q.price;
        _isLive = q.isLive;
        final double base = q.fiftyTwoWeekLow > 0
            ? q.fiftyTwoWeekLow
            : q.previousClose * 0.75;
        final double computed = (q.price - base) * 500;
        _gain = (computed <= 0 ? 150000 : computed).roundToDouble();
      });
    } catch (_) {}
  }

  static const List<double> _ladder = <double>[
    100000,
    200000,
    500000,
    1000000,
    2000000,
    5000000,
  ];

  @override
  Widget build(BuildContext context) {
    final LtcgResult r = calcLtcg(
      period: _taxPeriod,
      gain: _gain,
      exemptionAlreadyUsed: _used,
    );
    final double exemptionLeft = _ltcgExemption - _used < 0
        ? 0
        : _ltcgExemption - _used;
    final double spare = exemptionLeft - r.exemptionUsed;
    final bool fullyExempt = r.taxableGain <= 0;

    // The same profit sold a day early, at the short-term rate.
    final StcgResult asShort = calcStcg(period: _taxPeriod, gain: _gain);
    final double savedByHolding = asShort.totalTax - r.totalTax;
    final bool shortTerm = _holdingDays < 365;
    final double keptShare = _gain <= 0 ? 0 : r.netGain / _gain * 100;

    // Booking gains up to the exemption every year instead of once at the end.
    final double perYearSaving =
        _ltcgExemption * _ltcgRate / 100 * (1 + kCessRate / 100);
    final int yrs = _harvestYears.round();
    final List<double> harvestPath = <double>[
      for (int y = 1; y <= yrs; y++) perYearSaving * y,
    ];
    final double harvestTotal = perYearSaving * yrs;

    // Tax at both rates across a ladder of gains — the exemption bends one line.
    final List<double> longCurve = <double>[
      for (final double g in _ladder)
        calcLtcg(
          period: _taxPeriod,
          gain: g,
          exemptionAlreadyUsed: _used,
        ).totalTax,
    ];
    final List<double> shortCurve = <double>[
      for (final double g in _ladder)
        calcStcg(period: _taxPeriod, gain: g).totalTax,
    ];

    return AppCalculatorLayout(
      meta: calculatorMetaById('ltcg'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Tax on the gain',
        value: AppTokens.price(r.totalTax),
        intent: shortTerm
            ? UiIntent.warning
            : fullyExempt
            ? UiIntent.bullish
            : UiIntent.primary,
        tag: fullyExempt
            ? 'fully exempt'
            : '${AppTokens.percent(r.effectiveRatePct, decimals: 2)} effective',
        tagIntent: fullyExempt ? UiIntent.bullish : UiIntent.info,
        footnote:
            '${AppTokens.lakhCrore(_gain)} of long-term gain — '
            '${AppTokens.price(r.exemptionUsed)} falls under the annual '
            'exemption and ${AppTokens.lakhCrore(r.taxableGain)} is taxed at '
            '${AppTokens.percent(_ltcgRate, decimals: 1)}, leaving '
            '${AppTokens.lakhCrore(r.netGain)}.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Exemption used',
          value: AppTokens.price(r.exemptionUsed),
          intent: UiIntent.bullish,
          hint: spare <= 0
              ? 'the annual limit is spent'
              : '${AppTokens.price(spare)} still spare',
        ),
        UiStat(
          label: 'Taxable gain',
          value: AppTokens.lakhCrore(r.taxableGain),
          hint: 'above the exemption',
        ),
        UiStat(
          label: 'Tax at ${AppTokens.percent(_ltcgRate, decimals: 1)}',
          value: AppTokens.price(r.tax),
          intent: UiIntent.bearish,
          hint: 'no indexation on equity',
        ),
        UiStat(
          label: 'Cess',
          value: AppTokens.price(r.cess),
          intent: UiIntent.bearish,
          hint: '${AppTokens.percent(kCessRate, decimals: 1)} on the tax',
        ),
        UiStat(
          label: 'Net in hand',
          value: AppTokens.lakhCrore(r.netGain),
          intent: UiIntent.bullish,
          hint: '${AppTokens.percent(keptShare, decimals: 1)} of the gain',
        ),
        UiStat(
          label: 'Against short-term',
          value: AppTokens.price(savedByHolding),
          intent: UiIntent.bullish,
          hint: 'saved by crossing 365 days',
          spark: longCurve,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Tax period',
          hint:
              'Listed equity assumptions; surcharge and individual exemptions may affect your liability.',
          children: [
            UiSelect<EquityTaxPeriod>(
              label: 'Transfer date',
              value: _taxPeriod,
              options: [
                for (final period in EquityTaxPeriod.values)
                  UiOption(value: period, label: period.label),
              ],
              onChanged: (period) => setState(() {
                _taxPeriod = period;
                _used = _used.clamp(0, period.exemption);
              }),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'The gain',
          hint: 'profit booked, and the exemption already spent',
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'Live $_symbol: ₹${AppTokens.price(_livePrice)}'
                      : 'Sample: $_symbol (₹${AppTokens.price(_livePrice)})',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
                UiButton(
                  label: 'Calc 1Y Gain',
                  leadingIcon: Icons.sync,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: () => _applyLiveGain(_symbol),
                ),
              ],
            ),
            AppCalcSegment<String>(
              label: 'Sample Stock',
              value: _symbol,
              onChanged: (String s) => _applyLiveGain(s),
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'RELIANCE', label: 'Reliance'),
                UiToggleOption<String>(value: 'TCS', label: 'TCS'),
                UiToggleOption<String>(value: 'HDFCBANK', label: 'HDFC'),
                UiToggleOption<String>(value: 'INFY', label: 'Infosys'),
              ],
            ),
            AppCalcNumberField(
              label: 'Long-term gain',
              value: _gain,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[100000, 500000, 1000000, 5000000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              helper: fullyExempt
                  ? 'Inside the exemption — no tax on this sale.'
                  : '${AppTokens.lakhCrore(r.taxableGain)} of it is taxable.',
              onChanged: (double v) => setState(() => _gain = v),
            ),
            AppCalcSliderField(
              label: 'Exemption already used',
              value: _used,
              min: 0,
              max: _ltcgExemption,
              divisions: 20,
              intent: _used >= _ltcgExemption
                  ? UiIntent.danger
                  : UiIntent.primary,
              valueFormatter: (num v) => AppTokens.price(v),
              helper: _used >= _ltcgExemption
                  ? 'Spent for the year — the whole gain is taxable.'
                  : '${AppTokens.price(exemptionLeft)} of the '
                        '${AppTokens.lakhCrore(_ltcgExemption)} limit is left.',
              onChanged: (double v) => setState(() => _used = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Timing',
          hint: 'how long it was held, and how often you book',
          children: <Widget>[
            AppCalcSliderField(
              label: 'Holding period',
              value: _holdingDays,
              min: 100,
              max: 1500,
              divisions: 140,
              intent: shortTerm ? UiIntent.danger : UiIntent.primary,
              valueFormatter: (num v) => '${v.round()} days',
              helper: shortTerm
                  ? 'Under 365 days this is short-term — '
                        '${AppTokens.price(asShort.totalTax)} of tax instead.'
                  : '${(_holdingDays - 365).round()} days past the long-term '
                        'threshold.',
              onChanged: (double v) => setState(() => _holdingDays = v),
            ),
            AppCalcSegment<double>(
              label: 'Harvest across',
              value: _harvestYears,
              onChanged: (double v) => setState(() => _harvestYears = v),
              helper:
                  'Booking up to the exemption each year and buying back '
                  'resets the cost base for free.',
              options: const <UiToggleOption<double>>[
                UiToggleOption<double>(value: 1, label: '1 yr'),
                UiToggleOption<double>(value: 3, label: '3 yr'),
                UiToggleOption<double>(value: 5, label: '5 yr'),
                UiToggleOption<double>(value: 10, label: '10 yr'),
              ],
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'The tax ledger',
          hint: 'gain down to what you keep',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiKeyValueTable(
            labelHeader: 'Line',
            valueHeader: 'Amount',
            trailingHeader: 'Of gain',
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'Gross gain',
                value: AppTokens.lakhCrore(_gain),
                trailing: '100%',
                detail: 'Held ${_holdingDays.round()} days',
              ),
              UiKeyValueRow(
                label: 'Exemption applied',
                value: r.exemptionUsed <= 0
                    ? '—'
                    : '−${AppTokens.price(r.exemptionUsed)}',
                trailing: _gain <= 0
                    ? '—'
                    : AppTokens.percent(
                        r.exemptionUsed / _gain * 100,
                        decimals: 1,
                      ),
                intent: r.exemptionUsed > 0
                    ? UiIntent.bullish
                    : UiIntent.neutral,
                detail: _used > 0
                    ? '${AppTokens.price(_used)} of the limit was already used'
                    : 'First ${AppTokens.lakhCrore(_ltcgExemption)} each year',
              ),
              UiKeyValueRow(
                label: 'Taxable gain',
                value: AppTokens.lakhCrore(r.taxableGain),
                trailing: _gain <= 0
                    ? '—'
                    : AppTokens.percent(
                        r.taxableGain / _gain * 100,
                        decimals: 1,
                      ),
                intent: UiIntent.info,
                emphasis: true,
                detail: 'Without indexation, on listed equity',
              ),
              UiKeyValueRow(
                label: 'Tax at ${AppTokens.percent(_ltcgRate, decimals: 1)}',
                value: r.tax <= 0 ? '—' : '−${AppTokens.price(r.tax)}',
                trailing: _gain <= 0
                    ? '—'
                    : AppTokens.percent(r.tax / _gain * 100, decimals: 1),
                intent: r.tax > 0 ? UiIntent.bearish : UiIntent.neutral,
                detail: 'The special rate for long-term equity',
              ),
              UiKeyValueRow(
                label: 'Cess at ${AppTokens.percent(kCessRate, decimals: 1)}',
                value: r.cess <= 0 ? '—' : '−${AppTokens.price(r.cess)}',
                trailing: _gain <= 0
                    ? '—'
                    : AppTokens.percent(r.cess / _gain * 100, decimals: 2),
                intent: r.cess > 0 ? UiIntent.bearish : UiIntent.neutral,
                detail: 'Health and education cess, on the tax',
              ),
              UiKeyValueRow(
                label: 'Net in hand',
                value: AppTokens.lakhCrore(r.netGain),
                trailing: AppTokens.percent(keptShare, decimals: 1),
                intent: UiIntent.bullish,
                emphasis: true,
                detail: fullyExempt
                    ? 'Nothing withheld — the gain is exempt'
                    : 'After ${AppTokens.price(r.totalTax)} of tax and cess',
                share: _gain <= 0 ? null : (r.netGain / _gain).clamp(0.0, 1.0),
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'The routes compared',
          hint: 'same profit, different timing',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Route',
            valueHeader: 'Total tax',
            trailingHeader: 'Rate',
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'Long-term',
                value: AppTokens.price(r.totalTax),
                trailing: AppTokens.percent(r.effectiveRatePct, decimals: 2),
                intent: UiIntent.bullish,
                emphasis: true,
                detail: 'Held past 365 days, exemption applied',
              ),
              UiKeyValueRow(
                label: 'Short-term',
                value: AppTokens.price(asShort.totalTax),
                trailing: AppTokens.percent(
                  asShort.effectiveRatePct,
                  decimals: 2,
                ),
                intent: UiIntent.bearish,
                detail: 'Sold inside 365 days, no exemption',
              ),
              UiKeyValueRow(
                label: 'Waiting saves',
                value: AppTokens.signedMoney(savedByHolding, decimals: 0),
                trailing: _gain <= 0
                    ? '—'
                    : AppTokens.percent(
                        savedByHolding / _gain * 100,
                        decimals: 2,
                      ),
                intent: AppTokens.plIntent(savedByHolding),
                detail: 'The gap between the two rates, on this gain',
              ),
              UiKeyValueRow(
                label: 'Split over two years',
                value: AppTokens.price(
                  calcLtcg(period: _taxPeriod, gain: _gain / 2).totalTax * 2,
                ),
                trailing: 'two exemptions',
                intent: UiIntent.info,
                detail:
                    'Half now, half after 1 April — each year exempts '
                    '${AppTokens.lakhCrore(_ltcgExemption)}',
              ),
              UiKeyValueRow(
                label: 'Harvesting $yrs years',
                value: AppTokens.lakhCrore(harvestTotal),
                trailing: '${AppTokens.price(perYearSaving)}/yr',
                intent: UiIntent.bullish,
                detail: 'Tax never incurred by booking within the exemption',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Tax as the gain grows',
          hint: 'the exemption flattens the first lakh',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (final double g in _ladder) AppTokens.compactMoney(g),
            ],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Long-term',
                values: longCurve,
                intent: UiIntent.bullish,
                area: true,
              ),
              AppCalcSeries(
                name: 'Short-term',
                values: shortCurve,
                intent: UiIntent.bearish,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: r.totalTax, label: 'this sale'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Harvesting, year after year',
          hint: 'tax avoided by using each exemption',
          child: AppCalcTrendChart(
            labels: <String>[for (int y = 1; y <= yrs; y++) '$y'],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Cumulative saving',
                values: harvestPath,
                intent: UiIntent.info,
                bars: true,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: r.totalTax, label: 'this year’s tax'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Where the gain goes',
          hint: 'exempt · taxed but kept · tax',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: r.exemptionUsed < 0 ? 0 : r.exemptionUsed,
                label: 'Exempt ${AppTokens.compactMoney(r.exemptionUsed)}',
              ),
              UiCategorySegment(
                value: r.taxableGain - r.totalTax < 0
                    ? 0
                    : r.taxableGain - r.totalTax,
                label:
                    'Kept '
                    '${AppTokens.compactMoney(r.taxableGain - r.totalTax)}',
              ),
              UiCategorySegment(
                value: r.totalTax < 0 ? 0 : r.totalTax,
                label: 'Tax ${AppTokens.compactMoney(r.totalTax)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'The annual exemption',
          hint: 'spent earlier · this sale · spare',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: 0,
            max: _ltcgExemption,
            minLabel: '0',
            maxLabel: AppTokens.lakhCrore(_ltcgExemption),
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            zones: <UiRangeZone>[
              if (_used > 0)
                UiRangeZone(
                  start: 0,
                  end: _used,
                  intent: UiIntent.neutral,
                  label: 'used earlier',
                  alpha: 0.12,
                ),
              UiRangeZone(
                start: _used,
                end: _used + r.exemptionUsed,
                intent: UiIntent.bullish,
                label: 'this sale',
                alpha: 0.16,
              ),
              if (spare > 0)
                UiRangeZone(
                  start: _used + r.exemptionUsed,
                  end: _ltcgExemption,
                  intent: UiIntent.info,
                  label: 'spare this year',
                  alpha: 0.10,
                ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: _used + r.exemptionUsed,
                label: 'Claimed',
                intent: spare > 0 ? UiIntent.bullish : UiIntent.warning,
                strong: true,
              ),
              if (spare > 0)
                UiRangeMarker(
                  value: _ltcgExemption,
                  label: '${AppTokens.price(spare)} unused',
                  intent: UiIntent.info,
                  below: true,
                ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (shortTerm)
          UiCallout(
            intent: UiIntent.danger,
            title: 'Held ${_holdingDays.round()} days — not long-term yet',
            message:
                'Listed equity needs 365 days. Sold now the gain is short-term '
                'at ${AppTokens.percent(_stcgRate, decimals: 1)} with no '
                'exemption — ${AppTokens.price(asShort.totalTax)} against '
                '${AppTokens.price(r.totalTax)}. Waiting '
                '${(365 - _holdingDays).round()} more days saves '
                '${AppTokens.price(savedByHolding)}.',
          ),
        if (!shortTerm && fullyExempt)
          UiCallout(
            intent: UiIntent.bullish,
            title: 'Nothing is payable on this sale',
            message:
                'The whole ${AppTokens.lakhCrore(_gain)} sits inside the annual '
                'exemption. It still has to be reported in the return, and it '
                'consumes ${AppTokens.price(r.exemptionUsed)} of the limit — '
                'later sales this year will be taxed from the first rupee once '
                'the limit is spent.',
          ),
        if (!shortTerm && !fullyExempt)
          UiCallout(
            intent: UiIntent.info,
            title: 'Splitting the sale across 1 April',
            message:
                'Two financial years mean two exemptions. Booking '
                '${AppTokens.lakhCrore(_gain / 2)} on each side costs '
                '${AppTokens.price(calcLtcg(period: _taxPeriod, gain: _gain / 2).totalTax * 2)} '
                'against ${AppTokens.price(r.totalTax)} in one go — a saving of '
                '${AppTokens.price(r.totalTax - calcLtcg(period: _taxPeriod, gain: _gain / 2).totalTax * 2)} '
                'for a delay, not a decision about the holding.',
          ),
      ],
      formula:
          'Exemption = ₹1 L a year, across all long-term equity gains\n'
          'Taxable = Gain − exemption remaining\n'
          'Tax = Taxable × ${_ltcgRate.toStringAsFixed(1)}%\n'
          'Cess = Tax × ${kCessRate.toStringAsFixed(0)}%\n'
          'Effective = (Tax + Cess) ÷ Gain × 100',
      notes: <String>[
        'The ${AppTokens.percent(_ltcgRate, decimals: 1)} rate and the '
            '${AppTokens.lakhCrore(_ltcgExemption)} exemption apply to listed '
            'equity and equity mutual funds held beyond 365 days, where STT has '
            'been paid. Debt funds, unlisted shares and property follow other '
            'rules entirely.',
        'The exemption is per person per financial year, not per holding or per '
            'broker. Gains across every equity investment share the same limit, '
            'and it does not carry forward.',
        'Shares bought before 1 February 2018 are grandfathered — the cost is '
            'taken as the higher of the actual cost and the price on 31 January '
            '2018, which is not modelled here.',
        'Harvesting means selling to realise gain within the exemption and '
            'buying back to reset the cost base. Same-day repurchase is '
            'permitted for equity, but the price gap and the brokerage on both '
            'legs are real costs against the tax saved.',
      ],
    );
  }
}
