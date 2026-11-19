import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/tax_calculators.dart';
import '../services/market_data_service.dart';

/// Turnover — the figure that decides whether books and an audit are required,
/// and why a losing year can produce a larger one than a winning year.
///
/// For derivatives, turnover is the absolute sum of every settled difference,
/// not contract value. Losses add to it. That single rule catches more traders
/// than any rate does.
class TurnoverCalculatorScreen extends StatefulWidget {
  const TurnoverCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<TurnoverCalculatorScreen> createState() =>
      _TurnoverCalculatorScreenState();
}

class _TurnoverCalculatorScreenState extends State<TurnoverCalculatorScreen> {
  String _symbol = 'NIFTY';
  double _livePrice = 24850.0;
  bool _isLive = false;
  double _profit = 1200000;
  double _loss = 500000;
  double _threshold = 100000000;
  double _slab = 30;

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

  Future<void> _applyLiveSessionTurnover(String sym) async {
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(sym);
      if (!mounted) return;
      setState(() {
        _symbol = sym;
        _livePrice = q.price;
        _isLive = q.isLive;
        final double lotSize = sym == 'BANKNIFTY'
            ? 15
            : (sym == 'RELIANCE' ? 250 : 25);
        final double dailyRange = (q.high - q.low).abs() > 0
            ? (q.high - q.low).abs()
            : q.price * 0.012;
        final double annualTurnoverEst = dailyRange * lotSize * 240;
        _profit = (annualTurnoverEst * 0.58).roundToDouble();
        _loss = (annualTurnoverEst * 0.42).roundToDouble();
      });
    } catch (_) {}
  }

  static const double _presumptiveRate = 6;

  static const List<double> _limits = <double>[
    10000000,
    20000000,
    30000000,
    100000000,
  ];

  @override
  Widget build(BuildContext context) {
    final TurnoverResult r = calcTurnover(
      profitSum: _profit,
      lossSum: _loss,
      threshold: _threshold,
    );
    final double profitRatio = r.turnover <= 0
        ? 0
        : r.netPnl / r.turnover * 100;
    final bool overLimit = r.turnover > _threshold;
    final bool belowFloor = r.netPnl < r.presumptiveIncome;
    final double headroom = _threshold - r.turnover;
    final double usage = _threshold <= 0 ? 0 : r.turnover / _threshold * 100;

    // Tax on what is actually earned, against tax on the presumptive figure.
    final double cessFactor = 1 + kCessRate / 100;
    final double actualTax = r.netPnl <= 0
        ? 0
        : r.netPnl * _slab / 100 * cessFactor;
    final double presumptiveTax =
        r.presumptiveIncome * _slab / 100 * cessFactor;
    final double routeGap = presumptiveTax - actualTax;

    // Hold the winners fixed and walk the losers up: turnover climbs while the
    // net result falls, and the two curves cross the presumptive floor.
    const List<double> lossSteps = <double>[0, 0.25, 0.5, 0.75, 1, 1.5, 2];
    final List<TurnoverResult> walk = <TurnoverResult>[
      for (final double m in lossSteps)
        calcTurnover(
          profitSum: _profit,
          lossSum: _profit * m,
          threshold: _threshold,
        ),
    ];
    final List<double> turnoverCurve = <double>[
      for (final TurnoverResult t in walk) t.turnover,
    ];
    final List<double> netCurve = <double>[
      for (final TurnoverResult t in walk) t.netPnl,
    ];
    final List<double> floorCurve = <double>[
      for (final TurnoverResult t in walk) t.presumptiveIncome,
    ];

    return AppCalculatorLayout(
      meta: calculatorMetaById('turnover'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Turnover for the year',
        value: AppTokens.lakhCrore(r.turnover),
        intent: r.auditRequired ? UiIntent.warning : UiIntent.primary,
        tag: r.auditRequired ? 'audit applies' : 'no audit',
        tagIntent: r.auditRequired ? UiIntent.bearish : UiIntent.bullish,
        footnote:
            '${AppTokens.lakhCrore(_profit)} of favourable differences and '
            '${AppTokens.lakhCrore(_loss)} of unfavourable ones add up, they do '
            'not net off — turnover is '
            '${AppTokens.lakhCrore(r.turnover)} on a net result of '
            '${AppTokens.signedMoney(r.netPnl, decimals: 0)}.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Net result',
          value: AppTokens.signedMoney(r.netPnl, decimals: 0),
          intent: AppTokens.plIntent(r.netPnl),
          hint: 'profit less loss',
        ),
        UiStat(
          label: 'Profit ratio',
          value: AppTokens.percent(profitRatio, decimals: 2),
          intent: belowFloor ? UiIntent.bearish : UiIntent.bullish,
          hint:
              'of turnover — the floor is '
              '${AppTokens.percent(_presumptiveRate, decimals: 0)}',
        ),
        UiStat(
          label: 'Presumptive income',
          value: AppTokens.lakhCrore(r.presumptiveIncome),
          intent: UiIntent.info,
          hint:
              '${AppTokens.percent(_presumptiveRate, decimals: 0)} of turnover',
        ),
        UiStat(
          label: 'Limit used',
          value: AppTokens.percent(usage, decimals: 1),
          intent: overLimit
              ? UiIntent.bearish
              : usage > 75
              ? UiIntent.warning
              : UiIntent.bullish,
          hint: overLimit
              ? 'over by ${AppTokens.lakhCrore(-headroom)}'
              : '${AppTokens.lakhCrore(headroom)} to spare',
        ),
        UiStat(
          label: 'Tax on the result',
          value: AppTokens.price(actualTax),
          intent: UiIntent.bearish,
          hint: 'at the ${AppTokens.percent(_slab, decimals: 0)} slab',
        ),
        UiStat(
          label: 'Tax if presumptive',
          value: AppTokens.price(presumptiveTax),
          intent: routeGap > 0 ? UiIntent.warning : UiIntent.bullish,
          hint: routeGap > 0
              ? '${AppTokens.price(routeGap)} more'
              : '${AppTokens.price(-routeGap)} less',
          spark: turnoverCurve,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'The year’s trades',
          hint: 'settled differences, both directions',
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
                      : 'Benchmark: $_symbol (₹${AppTokens.price(_livePrice)})',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
                UiButton(
                  label: 'Sync Live Swing',
                  leadingIcon: Icons.sync,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: () => _applyLiveSessionTurnover(_symbol),
                ),
              ],
            ),
            AppCalcSegment<String>(
              label: 'F&O Instrument',
              value: _symbol,
              onChanged: (String s) => _applyLiveSessionTurnover(s),
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'NIFTY', label: 'Nifty 50'),
                UiToggleOption<String>(value: 'BANKNIFTY', label: 'Bank Nifty'),
                UiToggleOption<String>(value: 'FINNIFTY', label: 'Fin Nifty'),
                UiToggleOption<String>(value: 'RELIANCE', label: 'Reliance'),
              ],
            ),
            AppCalcNumberField(
              label: 'Favourable differences',
              value: _profit,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[500000, 1200000, 5000000, 20000000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              helper: 'Every winning trade added up, before costs.',
              onChanged: (double v) => setState(() => _profit = v),
            ),
            AppCalcNumberField(
              label: 'Unfavourable differences',
              value: _loss,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[0, 500000, 2000000, 10000000],
              presetLabel: (double v) =>
                  v == 0 ? 'None' : AppTokens.lakhCrore(v),
              helper:
                  'Losses are added, not subtracted — they raise turnover '
                  'by ${AppTokens.lakhCrore(_loss)}.',
              onChanged: (double v) => setState(() => _loss = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Which limit applies',
          hint: 'audit threshold and your slab',
          children: <Widget>[
            AppCalcSegment<double>(
              label: 'Audit threshold',
              value: _threshold,
              onChanged: (double v) => setState(() => _threshold = v),
              helper: overLimit
                  ? 'Turnover is over this limit — audit applies on that ground '
                        'alone.'
                  : '${AppTokens.lakhCrore(headroom)} of room under the limit.',
              options: const <UiToggleOption<double>>[
                UiToggleOption<double>(value: 10000000, label: '₹1 Cr'),
                UiToggleOption<double>(value: 20000000, label: '₹2 Cr'),
                UiToggleOption<double>(value: 30000000, label: '₹3 Cr'),
                UiToggleOption<double>(value: 100000000, label: '₹10 Cr'),
              ],
            ),
            AppCalcSegment<double>(
              label: 'Your slab',
              value: _slab,
              onChanged: (double v) => setState(() => _slab = v),
              helper:
                  'Derivatives are business income, so the slab applies — '
                  'no special rate.',
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
          label: 'How the figure is built',
          hint: 'differences added, then netted',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiKeyValueTable(
            labelHeader: 'Line',
            valueHeader: 'Amount',
            trailingHeader: 'Of turnover',
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'Favourable',
                value: AppTokens.lakhCrore(_profit),
                trailing: r.turnover <= 0
                    ? '—'
                    : AppTokens.percent(
                        _profit / r.turnover * 100,
                        decimals: 1,
                      ),
                intent: UiIntent.bullish,
                detail: 'Winning trades, summed',
                share: r.turnover <= 0
                    ? null
                    : (_profit / r.turnover).clamp(0.0, 1.0),
              ),
              UiKeyValueRow(
                label: 'Unfavourable',
                value: AppTokens.lakhCrore(_loss),
                trailing: r.turnover <= 0
                    ? '—'
                    : AppTokens.percent(_loss / r.turnover * 100, decimals: 1),
                intent: UiIntent.bearish,
                detail: 'Losing trades, summed as positives',
                share: r.turnover <= 0
                    ? null
                    : (_loss / r.turnover).clamp(0.0, 1.0),
              ),
              UiKeyValueRow(
                label: 'Turnover',
                value: AppTokens.lakhCrore(r.turnover),
                trailing: '100%',
                intent: UiIntent.info,
                emphasis: true,
                detail:
                    'The absolute sum — what the threshold is tested against',
              ),
              UiKeyValueRow(
                label: 'Net result',
                value: AppTokens.signedMoney(r.netPnl, decimals: 0),
                trailing: AppTokens.percent(profitRatio, decimals: 2),
                intent: AppTokens.plIntent(r.netPnl),
                detail: 'What is actually taxed, if books are kept',
              ),
              UiKeyValueRow(
                label: 'Presumptive floor',
                value: AppTokens.lakhCrore(r.presumptiveIncome),
                trailing: AppTokens.percent(_presumptiveRate, decimals: 0),
                intent: belowFloor ? UiIntent.bearish : UiIntent.neutral,
                detail: belowFloor
                    ? 'Declared result is below it — audit is triggered'
                    : 'Declared result clears it',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Against each limit',
          hint: 'the same turnover, every threshold',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Limit',
            valueHeader: 'Used',
            trailingHeader: 'Audit',
            rows: <UiKeyValueRow>[
              for (final double l in _limits)
                UiKeyValueRow(
                  label: AppTokens.lakhCrore(l),
                  value: AppTokens.percent(
                    l <= 0 ? 0 : r.turnover / l * 100,
                    decimals: 1,
                  ),
                  trailing: r.turnover > l
                      ? 'Yes'
                      : belowFloor
                      ? 'Yes'
                      : 'No',
                  intent: r.turnover > l ? UiIntent.bearish : UiIntent.bullish,
                  emphasis: (l - _threshold).abs() < 1,
                  detail: r.turnover > l
                      ? 'Over by ${AppTokens.lakhCrore(r.turnover - l)}'
                      : belowFloor
                      ? 'Under the limit, but the profit ratio triggers it'
                      : '${AppTokens.lakhCrore(l - r.turnover)} of room',
                  share: l <= 0 ? null : (r.turnover / l).clamp(0.0, 1.0),
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Turnover as the losses mount',
          hint: 'winners held fixed, losers walked up',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (final double m in lossSteps)
                AppTokens.percent(m * 100, decimals: 0),
            ],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Turnover',
                values: turnoverCurve,
                intent: UiIntent.warning,
                area: true,
              ),
              AppCalcSeries(
                name: 'Net result',
                values: netCurve,
                intent: UiIntent.info,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: r.turnover, label: 'this year'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Result against the 6% floor',
          hint: 'where the audit trigger crosses',
          child: AppCalcTrendChart(
            labels: <String>[
              for (final double m in lossSteps)
                AppTokens.percent(m * 100, decimals: 0),
            ],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Net result',
                values: netCurve,
                intent: UiIntent.bullish,
              ),
              AppCalcSeries(
                name: 'Floor',
                values: floorCurve,
                intent: UiIntent.bearish,
              ),
            ],
            thresholds: const <UiChartThreshold>[
              UiChartThreshold(value: 0, label: 'break-even'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'What the turnover is made of',
          hint: 'favourable · unfavourable',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: _profit < 0 ? 0 : _profit,
                label: 'Favourable ${AppTokens.compactMoney(_profit)}',
              ),
              UiCategorySegment(
                value: _loss < 0 ? 0 : _loss,
                label: 'Unfavourable ${AppTokens.compactMoney(_loss)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Turnover against the audit limit',
          hint: 'comfortable · close · over',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: 0,
            max: overLimit ? r.turnover * 1.1 : _threshold,
            minLabel: '0',
            maxLabel: AppTokens.lakhCrore(_threshold),
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: _threshold * 0.75,
                intent: UiIntent.bullish,
                label: 'comfortable',
                alpha: 0.12,
              ),
              UiRangeZone(
                start: _threshold * 0.75,
                end: _threshold,
                intent: UiIntent.warning,
                label: 'close to the limit',
                alpha: 0.14,
              ),
              if (overLimit)
                UiRangeZone(
                  start: _threshold,
                  end: r.turnover * 1.1,
                  intent: UiIntent.bearish,
                  label: 'audit',
                  alpha: 0.16,
                ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: r.turnover,
                label: 'This year',
                intent: overLimit ? UiIntent.bearish : UiIntent.bullish,
                strong: true,
              ),
              UiRangeMarker(
                value: _threshold,
                label: 'Limit',
                intent: UiIntent.info,
                below: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (overLimit)
          UiCallout(
            intent: UiIntent.danger,
            title:
                'Turnover is over the '
                '${AppTokens.lakhCrore(_threshold)} limit',
            message:
                '${AppTokens.lakhCrore(r.turnover)} exceeds it by '
                '${AppTokens.lakhCrore(r.turnover - _threshold)}, so accounts '
                'must be audited and the return filed on the later due date. '
                'The net result of '
                '${AppTokens.signedMoney(r.netPnl, decimals: 0)} does not enter '
                'that test at all.',
          ),
        if (!overLimit && belowFloor)
          UiCallout(
            intent: UiIntent.warning,
            title:
                'The profit ratio is under '
                '${AppTokens.percent(_presumptiveRate, decimals: 0)}',
            message:
                'Declaring ${AppTokens.signedMoney(r.netPnl, decimals: 0)} on '
                '${AppTokens.lakhCrore(r.turnover)} of turnover is '
                '${AppTokens.percent(profitRatio, decimals: 2)}, below the '
                'presumptive floor of '
                '${AppTokens.lakhCrore(r.presumptiveIncome)}. Either declare the '
                'presumptive figure — '
                '${AppTokens.price(presumptiveTax)} of tax at your slab — or '
                'keep books and have them audited.',
          ),
        if (_loss > 0)
          UiCallout(
            intent: UiIntent.info,
            title:
                '${AppTokens.lakhCrore(_loss)} of losses added '
                '${AppTokens.lakhCrore(_loss)} of turnover',
            message:
                'Without them turnover would be '
                '${AppTokens.lakhCrore(_profit)} instead of '
                '${AppTokens.lakhCrore(r.turnover)}. A heavily traded losing '
                'year can cross the audit threshold while the account is down — '
                'the compliance cost arrives with the loss, not with the profit.',
          ),
      ],
      formula:
          'Turnover = Σ favourable + Σ |unfavourable|\n'
          'Net result = Σ favourable − Σ |unfavourable|\n'
          'Profit ratio = Net result ÷ Turnover × 100\n'
          'Presumptive = Turnover × ${_presumptiveRate.toStringAsFixed(0)}%\n'
          'Audit if Turnover > limit, or ratio below the floor',
      notes: <String>[
        'For futures and options, turnover is the absolute sum of settled '
            'differences — plus premium received on options written. Contract '
            'value is not turnover, which is why a ₹50 lakh notional position '
            'can produce a few thousand rupees of it.',
        'Two independent triggers force an audit: turnover above the threshold, '
            'or a declared result below '
            '${AppTokens.percent(_presumptiveRate, decimals: 0)} of turnover '
            'when presumptive taxation is not opted for. Either one is enough.',
        'The higher threshold applies only when substantially all receipts and '
            'payments are digital, which broker settlements are. The lower '
            'limits remain relevant for the presumptive scheme itself.',
        'Derivative income is business income, so brokerage, exchange charges, '
            'STT on the sell side, internet and advisory costs are deductible '
            'against it — and losses carry forward eight years if the return is '
            'filed on time.',
      ],
    );
  }
}
