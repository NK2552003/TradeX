import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/tax_calculators.dart';
import '../services/market_data_service.dart';

/// Short-term capital gains — a flat special rate, the losses that reduce it,
/// and the slab it would have faced as business income.
///
/// Delivery trades held under a year are taxed at a special rate that ignores
/// the slab entirely. That distinction is worth money, so both routes are
/// priced side by side.
class StcgCalculatorScreen extends StatefulWidget {
  const StcgCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<StcgCalculatorScreen> createState() => _StcgCalculatorScreenState();
}

class _StcgCalculatorScreenState extends State<StcgCalculatorScreen> {
  EquityTaxPeriod _taxPeriod = EquityTaxPeriod.from23July2024;
  double get _stcgRate => _taxPeriod.stcgRate;
  double get _ltcgRate => _taxPeriod.ltcgRate;
  double get _ltcgExemption => _taxPeriod.exemption;
  String _symbol = 'RELIANCE';
  double _livePrice = 1313.80;
  bool _isLive = false;
  double _gain = 500000;
  double _loss = 0;
  double _slab = 30;
  double _holdingDays = 180;

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
            : q.previousClose * 0.85;
        final double computed = (q.price - base) * 500;
        _gain = (computed <= 0 ? 50000 : computed).roundToDouble();
      });
    } catch (_) {}
  }

  static const List<double> _ladder = <double>[
    100000,
    250000,
    500000,
    1000000,
    2000000,
    5000000,
  ];

  @override
  Widget build(BuildContext context) {
    final double offset = _loss > _gain ? _gain : _loss;
    final double taxableBase = _gain - offset;
    final StcgResult r = calcStcg(period: _taxPeriod, gain: taxableBase);
    final double carryForward = _loss > _gain ? _loss - _gain : 0;

    // The same gain treated as business income — F&O and intraday go here.
    final double slabTax = taxableBase * _slab / 100;
    final double slabCess = slabTax * kCessRate / 100;
    final double slabTotal = slabTax + slabCess;
    final double flatEdge = slabTotal - r.totalTax;
    final double slabEffective = taxableBase <= 0
        ? 0
        : slabTotal / taxableBase * 100;

    final bool longTerm = _holdingDays > 365;
    final bool slabIsCheaper = flatEdge < 0;
    final double keptShare = _gain <= 0 ? 0 : r.netGain / _gain * 100;

    // Tax and take-home across a ladder of gains, at this rate.
    final List<double> taxCurve = <double>[
      for (final double g in _ladder)
        calcStcg(period: _taxPeriod, gain: g).totalTax,
    ];
    final List<double> netCurve = <double>[
      for (final double g in _ladder)
        calcStcg(period: _taxPeriod, gain: g).netGain,
    ];

    // Advance tax instalments — the flat schedule applied to this liability.
    final List<double> cumulative = <double>[
      for (final double p in kAdvanceTaxCumulativePct) r.totalTax * p / 100,
    ];

    return AppCalculatorLayout(
      meta: calculatorMetaById('stcg'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Tax on the gain',
        value: AppTokens.price(r.totalTax),
        intent: longTerm ? UiIntent.warning : UiIntent.primary,
        tag: '${AppTokens.percent(r.effectiveRatePct, decimals: 2)} effective',
        tagIntent: UiIntent.info,
        footnote:
            '${AppTokens.lakhCrore(_gain)} of short-term gain'
            '${offset > 0 ? ', ${AppTokens.lakhCrore(offset)} of losses set off' : ''}'
            ' — ${AppTokens.percent(_stcgRate, decimals: 1)} of '
            '${AppTokens.lakhCrore(r.taxableGain)} plus '
            '${AppTokens.percent(kCessRate, decimals: 1)} cess leaves '
            '${AppTokens.lakhCrore(r.netGain)} in hand.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Taxable gain',
          value: AppTokens.lakhCrore(r.taxableGain),
          hint: offset > 0
              ? 'after ${AppTokens.compactMoney(offset)} of losses'
              : 'no losses to set off',
        ),
        UiStat(
          label: 'Tax at ${AppTokens.percent(_stcgRate, decimals: 1)}',
          value: AppTokens.price(r.tax),
          intent: UiIntent.bearish,
          hint: 'the special rate',
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
          label: 'As business income',
          value: AppTokens.price(slabTotal),
          intent: slabIsCheaper ? UiIntent.bullish : UiIntent.warning,
          hint: 'at the ${AppTokens.percent(_slab, decimals: 1)} slab',
        ),
        UiStat(
          label: slabIsCheaper ? 'The slab is cheaper' : 'The flat rate saves',
          value: AppTokens.price(flatEdge.abs()),
          intent: slabIsCheaper ? UiIntent.bearish : UiIntent.bullish,
          hint: 'against the other route',
          spark: taxCurve,
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
              }),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'The gain',
          hint: 'realised profit and how long it was held',
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
                  label: 'Calc Live Gain',
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
              label: 'Short-term gain',
              value: _gain,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[100000, 500000, 1000000, 5000000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              onChanged: (double v) => setState(() => _gain = v),
            ),
            AppCalcSliderField(
              label: 'Holding period',
              value: _holdingDays,
              min: 1,
              max: 500,
              divisions: 499,
              intent: longTerm ? UiIntent.warning : UiIntent.primary,
              valueFormatter: (num v) => '${v.round()} days',
              helper: longTerm
                  ? 'Past 365 days this is a long-term gain — a different rate '
                        'and an exemption apply.'
                  : '${(365 - _holdingDays).round()} days short of long-term '
                        'treatment.',
              onChanged: (double v) => setState(() => _holdingDays = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Offsets and the alternative',
          hint: 'losses available, and your slab',
          children: <Widget>[
            AppCalcNumberField(
              label: 'Losses to set off',
              value: _loss,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[0, 50000, 100000, 250000],
              presetLabel: (double v) =>
                  v == 0 ? 'None' : AppTokens.compactMoney(v),
              helper: carryForward > 0
                  ? 'Only ${AppTokens.price(offset)} can be used here; '
                        '${AppTokens.price(carryForward)} carries forward.'
                  : 'Short-term losses set off against any capital gain.',
              onChanged: (double v) => setState(() => _loss = v),
            ),
            AppCalcSegment<double>(
              label: 'Your slab',
              value: _slab,
              onChanged: (double v) => setState(() => _slab = v),
              helper:
                  'Sets what the same profit would cost as F&O or intraday '
                  'income.',
              options: const <UiToggleOption<double>>[
                UiToggleOption<double>(value: 5, label: '5%'),
                UiToggleOption<double>(value: 10, label: '10%'),
                UiToggleOption<double>(value: 20, label: '20%'),
                UiToggleOption<double>(value: 30, label: '30%'),
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
                detail:
                    'Sale value less cost, held ${_holdingDays.round()} days',
              ),
              UiKeyValueRow(
                label: 'Losses set off',
                value: offset <= 0 ? '—' : '−${AppTokens.lakhCrore(offset)}',
                trailing: _gain <= 0
                    ? '—'
                    : AppTokens.percent(offset / _gain * 100, decimals: 1),
                intent: offset > 0 ? UiIntent.bullish : UiIntent.neutral,
                detail: carryForward > 0
                    ? '${AppTokens.price(carryForward)} unused, carried forward'
                    : 'Capped at the gain available',
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
                detail: 'What the special rate applies to',
              ),
              UiKeyValueRow(
                label: 'Tax at ${AppTokens.percent(_stcgRate, decimals: 1)}',
                value: '−${AppTokens.price(r.tax)}',
                trailing: _gain <= 0
                    ? '—'
                    : AppTokens.percent(r.tax / _gain * 100, decimals: 1),
                intent: UiIntent.bearish,
                detail: 'Flat, regardless of the slab',
              ),
              UiKeyValueRow(
                label: 'Cess at ${AppTokens.percent(kCessRate, decimals: 1)}',
                value: '−${AppTokens.price(r.cess)}',
                trailing: _gain <= 0
                    ? '—'
                    : AppTokens.percent(r.cess / _gain * 100, decimals: 2),
                intent: UiIntent.bearish,
                detail: 'Health and education cess, on the tax',
              ),
              UiKeyValueRow(
                label: 'Net in hand',
                value: AppTokens.lakhCrore(r.netGain),
                trailing: AppTokens.percent(keptShare, decimals: 1),
                intent: UiIntent.bullish,
                emphasis: true,
                detail: 'After ${AppTokens.price(r.totalTax)} of tax and cess',
                share: _gain <= 0 ? null : (r.netGain / _gain).clamp(0.0, 1.0),
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'When it has to be paid',
          hint: 'advance tax instalments',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Due by',
            valueHeader: 'Instalment',
            trailingHeader: 'Cumulative',
            rows: <UiKeyValueRow>[
              for (int i = 0; i < kAdvanceTaxDates.length; i++)
                UiKeyValueRow(
                  label: kAdvanceTaxDates[i],
                  value: AppTokens.price(
                    i == 0 ? cumulative[0] : cumulative[i] - cumulative[i - 1],
                  ),
                  trailing: AppTokens.percent(
                    kAdvanceTaxCumulativePct[i],
                    decimals: 0,
                  ),
                  intent: UiIntent.neutral,
                  detail: '${AppTokens.price(cumulative[i])} paid by this date',
                  share: r.totalTax <= 0
                      ? null
                      : (cumulative[i] / r.totalTax).clamp(0.0, 1.0),
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Tax as the gain grows',
          hint: 'flat rate, so the line is straight',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (final double g in _ladder) AppTokens.compactMoney(g),
            ],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Kept',
                values: netCurve,
                intent: UiIntent.bullish,
                area: true,
              ),
              AppCalcSeries(
                name: 'Tax',
                values: taxCurve,
                intent: UiIntent.bearish,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: r.totalTax, label: 'this trade'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'This gain under every route',
          hint: 'total tax including cess',
          child: UiBarList(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            items: <UiBarListItem>[
              UiBarListItem(
                label:
                    'Short-term ${AppTokens.percent(_stcgRate, decimals: 1)}',
                value: r.totalTax,
              ),
              for (final double s in const <double>[5, 10, 20, 30])
                UiBarListItem(
                  label: 'Slab ${AppTokens.percent(s, decimals: 1)}',
                  value: taxableBase * s / 100 * (1 + kCessRate / 100),
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Where the gain goes',
          hint: 'kept · tax · cess',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: r.netGain < 0 ? 0 : r.netGain,
                label: 'Kept ${AppTokens.compactMoney(r.netGain)}',
              ),
              UiCategorySegment(
                value: r.tax < 0 ? 0 : r.tax,
                label: 'Tax ${AppTokens.compactMoney(r.tax)}',
              ),
              UiCategorySegment(
                value: r.cess < 0 ? 0 : r.cess,
                label: 'Cess ${AppTokens.compactMoney(r.cess)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Effective rate against the alternative',
          hint: 'special rate · your slab',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: 0,
            max: slabEffective > 35 ? slabEffective + 3 : 38,
            minLabel: '0%',
            maxLabel: 'of the gain',
            valueFormatter: (num v) => AppTokens.percent(v, decimals: 2),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: r.effectiveRatePct,
                intent: UiIntent.bullish,
                label: 'the special rate',
                alpha: 0.14,
              ),
              UiRangeZone(
                start: r.effectiveRatePct,
                end: slabEffective > r.effectiveRatePct
                    ? slabEffective
                    : r.effectiveRatePct,
                intent: UiIntent.bearish,
                label: 'what the slab would add',
                alpha: 0.16,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: r.effectiveRatePct,
                label: 'Short-term',
                intent: UiIntent.bullish,
                strong: true,
              ),
              UiRangeMarker(
                value: slabEffective,
                label: 'As business income',
                intent: UiIntent.bearish,
                below: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (longTerm)
          UiCallout(
            intent: UiIntent.warning,
            title: 'Held ${_holdingDays.round()} days — this is long-term',
            message:
                'Listed equity crosses into long-term treatment after 365 days, '
                'where the rate is '
                '${AppTokens.percent(_ltcgRate, decimals: 1)} and the first '
                '${AppTokens.lakhCrore(_ltcgExemption)} of gain each year is '
                'exempt. The figures here apply the short-term rate and will '
                'overstate the tax.',
          ),
        if (carryForward > 0)
          UiCallout(
            intent: UiIntent.info,
            title: '${AppTokens.price(carryForward)} of loss goes unused',
            message:
                'Losses only offset gains, never other income, so '
                '${AppTokens.price(offset)} is absorbed here and the rest '
                'carries forward for eight assessment years — provided the '
                'return is filed by the due date.',
          ),
        if (!longTerm && flatEdge > 0)
          UiCallout(
            intent: UiIntent.bullish,
            title: 'The special rate saves ${AppTokens.price(flatEdge)}',
            message:
                'The same ${AppTokens.lakhCrore(taxableBase)} as F&O or intraday '
                'profit would be business income at your '
                '${AppTokens.percent(_slab, decimals: 1)} slab — '
                '${AppTokens.price(slabTotal)} against '
                '${AppTokens.price(r.totalTax)}. Delivery trades are the only '
                'route to the flat rate.',
          ),
      ],
      formula:
          'Taxable = Gain − losses set off\n'
          'Tax = Taxable × ${_stcgRate.toStringAsFixed(0)}%\n'
          'Cess = Tax × ${kCessRate.toStringAsFixed(0)}%\n'
          'Total = Tax + Cess\n'
          'Effective = Total ÷ Gain × 100',
      notes: <String>[
        'The ${AppTokens.percent(_stcgRate, decimals: 1)} rate applies to '
            'listed equity and equity mutual funds sold within 365 days, where '
            'STT has been paid. Unlisted shares, property and debt funds are '
            'taxed at the slab instead.',
        'Short-term losses set off against both short- and long-term gains; '
            'long-term losses only against long-term gains. Unabsorbed losses '
            'carry forward eight years if the return is filed on time.',
        'The slab comparison is the F&O and intraday case — those are business '
            'income, not capital gains, and carry their own audit and '
            'bookkeeping obligations.',
        'Surcharge is not modelled here. It begins above ₹50 lakh of total '
            'income and is capped at 15% on capital gains, applied before cess.',
      ],
    );
  }
}
