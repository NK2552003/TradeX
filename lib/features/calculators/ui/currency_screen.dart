import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/currency_calculators.dart';
import '../services/currency_rate_service.dart';

/// Currency — the mid-market rate, the markup taken off it, and what actually
/// lands on the other side.
///
/// The quoted rate is never the rate you get. Both are shown, with the spread
/// between them priced in the amount being sent.
class CurrencyCalculatorScreen extends StatefulWidget {
  const CurrencyCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<CurrencyCalculatorScreen> createState() =>
      _CurrencyCalculatorScreenState();
}

class _CurrencyCalculatorScreenState extends State<CurrencyCalculatorScreen> {
  double _amount = 1000;
  String _from = 'USD';
  String _to = 'INR';
  double _markup = 1.5;
  bool _useHistorical = false;
  DateTime? _selectedDate;
  CurrencyRatesSnapshot _snapshot = CurrencyRatesSnapshot.initialFallback();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final CurrencyRatesSnapshot snap = await CurrencyRateService.instance
          .getRates(
            base: 'USD',
            date: _useHistorical ? _selectedDate : null,
            forceRefresh: forceRefresh,
          );
      if (mounted) {
        setState(() {
          _snapshot = snap;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onToggleHistorical(bool historical) {
    if (_useHistorical == historical) return;
    setState(() {
      _useHistorical = historical;
      if (historical && _selectedDate == null) {
        _selectedDate = DateTime.now().subtract(const Duration(days: 30));
      }
    });
    _fetchRates();
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _fetchRates();
  }

  static const Map<String, String> _symbols = <String, String>{
    'USD': '\$',
    'INR': '₹',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'SGD': 'S\$',
    'AED': 'AED ',
    'CHF': 'CHF ',
    'CNY': 'CN¥',
  };

  String _fmt(double v, String code) => AppTokens.money(
    v,
    symbol: _symbols[code] ?? '',
    decimals: v.abs() >= 1000 ? 0 : 2,
  );

  @override
  Widget build(BuildContext context) {
    final ConversionResult r = convertCurrency(
      amount: _amount,
      from: _from,
      to: _to,
      rates: _snapshot.rates,
    );
    final double fee = r.converted * _markup / 100;
    final double net = r.converted - fee;
    final double effectiveRate = _amount <= 0 ? 0 : net / _amount;
    final double spread = r.rate - effectiveRate;
    final List<String> codes = kFallbackRatesVsUsd.keys.toList();
    final List<String> others = <String>[
      for (final String c in codes)
        if (c != _from) c,
    ];
    const List<double> ladder = <double>[100, 500, 1000, 5000, 10000, 50000];
    const List<double> markups = <double>[0, 0.5, 1, 1.5, 2, 3];
    // What lands if the rate itself drifts a few percent either way.
    final List<double> moves = <double>[
      for (int i = -5; i <= 5; i++) net * (1 + i / 100),
    ];
    final List<double> feeCurve = <double>[
      for (final double m in markups) r.converted * m / 100,
    ];
    final bool costly = _markup >= 2;
    final bool sameCurrency = _from == _to;

    return AppCalculatorLayout(
      meta: calculatorMetaById('currency'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Lands as',
        value: _fmt(net, _to),
        intent: costly ? UiIntent.warning : UiIntent.primary,
        tag:
            '1 $_from = ${r.rate.toStringAsFixed(r.rate >= 50 ? 2 : 4)} $_to · ${_snapshot.date}',
        tagIntent: _snapshot.isLive ? UiIntent.success : UiIntent.info,
        footnote:
            '${_fmt(_amount, _from)} at the mid-market rate is '
            '${_fmt(r.converted, _to)} — '
            '${AppTokens.percent(_markup, decimals: 2)} of markup takes '
            '${_fmt(fee, _to)} of it.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Mid-market',
          value: _fmt(r.converted, _to),
          intent: UiIntent.info,
          hint: 'before any spread',
        ),
        UiStat(
          label: 'Markup cost',
          value: _fmt(fee, _to),
          intent: UiIntent.bearish,
          hint: 'at ${AppTokens.percent(_markup, decimals: 2)}',
        ),
        UiStat(
          label: 'Quoted rate',
          value: r.rate.toStringAsFixed(r.rate >= 50 ? 2 : 4),
          hint: '$_from to $_to',
        ),
        UiStat(
          label: 'Rate you get',
          value: effectiveRate.toStringAsFixed(effectiveRate >= 50 ? 2 : 4),
          intent: UiIntent.warning,
          hint: 'after the spread',
        ),
        UiStat(
          label: 'Inverse',
          value: r.inverseRate.toStringAsFixed(r.inverseRate >= 50 ? 2 : 4),
          hint: '1 $_to in $_from',
        ),
        UiStat(
          label: 'Spread',
          value: spread.toStringAsFixed(spread.abs() >= 1 ? 3 : 5),
          intent: UiIntent.bearish,
          hint: 'per unit of $_from',
          spark: feeCurve,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'The transfer',
          hint: 'amount, and the pair',
          children: <Widget>[
            AppCalcNumberField(
              label: 'Amount in $_from',
              value: _amount,
              prefix: _symbols[_from] ?? '',
              decimals: 2,
              presets: const <double>[100, 1000, 10000, 100000],
              presetLabel: (double v) => AppTokens.count(v),
              onChanged: (double v) => setState(() => _amount = v),
            ),
            UiSelect<String>(
              label: 'From',
              value: _from,
              expand: true,
              searchable: true,
              size: UiSize.sm,
              density: UiDensity.compact,
              options: <UiOption<String>>[
                for (final String c in codes)
                  UiOption<String>(
                    value: c,
                    label: c,
                    description: kCurrencyNames[c] ?? c,
                  ),
              ],
              onChanged: (String v) => setState(() => _from = v),
            ),
            UiSelect<String>(
              label: 'To',
              value: _to,
              expand: true,
              searchable: true,
              size: UiSize.sm,
              density: UiDensity.compact,
              helperText: sameCurrency
                  ? 'Same currency on both sides — the rate is 1.'
                  : '${kCurrencyNames[_to] ?? _to} · rates as of ${_snapshot.date} (${_snapshot.source})',
              options: <UiOption<String>>[
                for (final String c in codes)
                  UiOption<String>(
                    value: c,
                    label: c,
                    description: kCurrencyNames[c] ?? c,
                  ),
              ],
              onChanged: (String v) => setState(() => _to = v),
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: context.sp(context.ui.spacing.xs),
              children: <Widget>[
                UiBadge(
                  label: _snapshot.isLive
                      ? 'Live · ${_snapshot.date}'
                      : 'Offline · ${_snapshot.date}',
                  intent: _snapshot.isLive
                      ? UiIntent.success
                      : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),

                UiButton(
                  label: _isLoading ? 'Updating...' : 'Refresh',
                  leadingIcon: Icons.refresh,
                  loading: _isLoading,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: _isLoading
                      ? null
                      : () => _fetchRates(forceRefresh: true),
                ),
              ],
            ),
            AppCalcSegment<bool>(
              label: 'Rate source',
              value: _useHistorical,
              onChanged: _onToggleHistorical,
              options: const <UiToggleOption<bool>>[
                UiToggleOption<bool>(value: false, label: 'Real-time (Live)'),
                UiToggleOption<bool>(value: true, label: 'Historical date'),
              ],
            ),
            if (_useHistorical)
              UiDatePicker(
                value: _selectedDate,
                firstDate: DateTime(1999, 1, 4),
                lastDate: DateTime.now(),
                hintText: 'Select historical date',
                size: UiSize.sm,
                onChanged: _onDateSelected,
              ),
          ],
        ),
        AppCalcInputGroup(
          label: 'What the transfer costs',
          hint: 'the spread over mid-market',
          children: <Widget>[
            AppCalcSliderField(
              label: 'Markup',
              value: _markup,
              min: 0,
              max: 4,
              divisions: 40,
              intent: costly ? UiIntent.danger : UiIntent.warning,
              valueFormatter: (num v) => AppTokens.percent(v, decimals: 2),
              helper: 'Costs ${_fmt(fee, _to)} on this transfer.',
              onChanged: (double v) => setState(() => _markup = v),
            ),
            AppCalcSegment<double>(
              label: 'Typical channels',
              value: _markup,
              onChanged: (double v) => setState(() => _markup = v),
              helper:
                  'Transfer apps sit near the top of the book; cards and '
                  'bank counters near the bottom.',
              options: const <UiToggleOption<double>>[
                UiToggleOption<double>(value: 0.4, label: 'App 0.4%'),
                UiToggleOption<double>(value: 1, label: 'Broker 1%'),
                UiToggleOption<double>(value: 2, label: 'Card 2%'),
                UiToggleOption<double>(value: 3.5, label: 'Bank 3.5%'),
              ],
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'The same amount, everywhere else',
          hint: '${_fmt(_amount, _from)} across the board',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiKeyValueTable(
            labelHeader: 'Currency',
            valueHeader: 'Converts to',
            trailingHeader: 'Rate',
            rows: <UiKeyValueRow>[
              for (final String c in others)
                UiKeyValueRow(
                  label: c,
                  value: _fmt(
                    convertCurrency(
                      amount: _amount,
                      from: _from,
                      to: c,
                      rates: _snapshot.rates,
                    ).converted,
                    c,
                  ),
                  trailing:
                      convertCurrency(
                        amount: 1,
                        from: _from,
                        to: c,
                        rates: _snapshot.rates,
                      ).rate.toStringAsFixed(
                        convertCurrency(
                                  amount: 1,
                                  from: _from,
                                  to: c,
                                  rates: _snapshot.rates,
                                ).rate >=
                                50
                            ? 2
                            : 4,
                      ),
                  intent: c == _to ? UiIntent.primary : UiIntent.neutral,
                  emphasis: c == _to,
                  detail: kCurrencyNames[c] ?? c,
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Amount ladder',
          hint: 'mid-market, then what lands',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Sent',
            valueHeader: 'Lands',
            trailingHeader: 'Markup',
            rows: <UiKeyValueRow>[
              for (final double a in ladder)
                UiKeyValueRow(
                  label: _fmt(a, _from),
                  value: _fmt(
                    convertCurrency(
                          amount: a,
                          from: _from,
                          to: _to,
                          rates: _snapshot.rates,
                        ).converted *
                        (1 - _markup / 100),
                    _to,
                  ),
                  trailing: _fmt(
                    convertCurrency(
                          amount: a,
                          from: _from,
                          to: _to,
                          rates: _snapshot.rates,
                        ).converted *
                        _markup /
                        100,
                    _to,
                  ),
                  intent: UiIntent.neutral,
                  emphasis: (a - _amount).abs() < 0.01,
                  detail: (a - _amount).abs() < 0.01
                      ? 'This transfer'
                      : 'Mid-market '
                            '${_fmt(convertCurrency(amount: a, from: _from, to: _to, rates: _snapshot.rates).converted, _to)}',
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'If the rate drifts',
          hint: 'five percent either side',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (int i = -5; i <= 5; i++)
                i % 5 == 0 ? '${i > 0 ? '+' : ''}$i%' : '',
            ],
            valueFormatter: (num v) => uiCompactNumber(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Lands in $_to',
                values: moves,
                intent: UiIntent.info,
                area: true,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: net, label: 'today'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'What each channel takes',
          hint: 'markup priced on this transfer',
          child: UiBarList(
            valueFormatter: (num v) => uiCompactNumber(v),
            items: <UiBarListItem>[
              for (final double m in markups)
                UiBarListItem(
                  label: AppTokens.percent(
                    m,
                    decimals: m == m.roundToDouble() ? 0 : 1,
                  ),
                  value: r.converted * m / 100,
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Where the money goes',
          hint: 'received · taken',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: net < 0 ? 0 : net,
                label: 'Received ${_fmt(net, _to)}',
              ),
              UiCategorySegment(
                value: fee < 0 ? 0 : fee,
                label: 'Markup ${_fmt(fee, _to)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Quoted rate against the rate you get',
          hint: 'the gap is the spread',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: effectiveRate * 0.97,
            max: r.rate * 1.03 + 0.0001,
            minLabel: 'worse',
            maxLabel: 'mid-market',
            valueFormatter: (num v) => v.toStringAsFixed(v.abs() >= 50 ? 2 : 4),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: effectiveRate,
                end: r.rate,
                intent: costly ? UiIntent.bearish : UiIntent.warning,
                label: 'spread',
                alpha: 0.16,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: r.rate,
                label: 'Mid-market',
                intent: UiIntent.info,
                strong: true,
              ),
              UiRangeMarker(
                value: effectiveRate,
                label: 'Yours',
                intent: costly ? UiIntent.bearish : UiIntent.warning,
                below: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (sameCurrency)
          UiCallout(
            intent: UiIntent.info,
            title: 'Both sides are $_from',
            message:
                'The rate is 1 and nothing converts. Pick a different currency '
                'on one side to see the spread and the landed amount.',
          ),
        if (!sameCurrency && costly)
          UiCallout(
            intent: UiIntent.warning,
            title:
                '${AppTokens.percent(_markup, decimals: 2)} is an expensive '
                'spread',
            message:
                'It takes ${_fmt(fee, _to)} out of this transfer. At 0.4% the '
                'same amount would lose only '
                '${_fmt(r.converted * 0.004, _to)} — a difference of '
                '${_fmt(fee - r.converted * 0.004, _to)} for identical money '
                'moving the same distance.',
          ),
        if (!sameCurrency && _to == 'INR' && _amount > 0)
          UiCallout(
            intent: UiIntent.info,
            title: 'Inbound remittance rules apply',
            message:
                'Money sent to a resident account is not taxed as income, but '
                'the bank reports it. Outbound transfers under LRS attract TCS '
                'above the annual threshold, which is collected on top of the '
                'markup shown here.',
          ),
      ],
      formula:
          'Rate = (USD per unit of To) ÷ (USD per unit of From)\n'
          'Mid-market = Amount × Rate\n'
          'Markup = Mid-market × spread%\n'
          'Lands = Mid-market − Markup\n'
          'Your rate = Lands ÷ Amount',
      notes: <String>[
        'Rates are sourced from ${_snapshot.source} dated ${_snapshot.date} '
            '(${_snapshot.isLive ? 'live multi-central-bank composite' : 'offline reference fallback'}). '
            'Majors move fractions of a percent a day; confirm the quote before committing.',
        'The markup is where transfer costs actually sit. A service advertising '
            '"zero fees" is almost always taking two to four percent inside the '
            'rate instead.',
        'Cards add their own layer — a network conversion plus an issuer fee, '
            'usually 2% to 3.5% together, and dynamic conversion at the terminal '
            'is worse again.',
        'Cross rates route through the dollar, blending official exchange data '
            'from 84 central banks and market institutions worldwide.',
      ],
    );
  }
}
