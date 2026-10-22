import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/trading_calculators.dart';
import '../services/market_data_service.dart';

/// Fibonacci — a swing divided into the places price tends to pause.
///
/// Retracements answer where to buy the pullback; extensions answer where to
/// leave. Both are shown against the live price, because a level nobody is
/// near is only trivia.
class FibonacciCalculatorScreen extends StatefulWidget {
  const FibonacciCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<FibonacciCalculatorScreen> createState() =>
      _FibonacciCalculatorScreenState();
}

class _FibonacciCalculatorScreenState extends State<FibonacciCalculatorScreen> {
  String _symbol = 'NIFTY';
  double _high = 23949.85;
  double _low = 23895.85;
  double _ltp = 23901.60;
  bool _uptrend = true;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveRange(_symbol);
  }

  Future<void> _fetchLiveRange(String sym, {bool use52Week = false}) async {
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(sym);
      if (!mounted) return;
      setState(() {
        _symbol = sym;
        _ltp = q.price;
        if (use52Week) {
          _high = q.fiftyTwoWeekHigh;
          _low = q.fiftyTwoWeekLow;
        } else {
          _high = q.high;
          _low = q.low;
        }
        _isLive = q.isLive;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final FibResult r = calcFibonacci(
      high: _high,
      low: _low,
      uptrend: _uptrend,
    );
    final double range = _high - _low;
    final double at618 = r.levels.length > 3 ? r.levels[3].$2 : 0;
    final double at786 = r.levels.length > 4 ? r.levels[4].$2 : 0;
    final double ext1618 = r.extensions.length > 1 ? r.extensions[1].$2 : 0;

    // Nearest retracement to the live price — the only one a trade can use now.
    String nearName = '—';
    double nearPrice = 0;
    double nearGap = double.infinity;
    for (final (String, double) l in r.levels) {
      final double gap = (l.$2 - _ltp).abs();
      if (gap < nearGap) {
        nearGap = gap;
        nearName = l.$1;
        nearPrice = l.$2;
      }
    }
    final bool inPocket = _uptrend
        ? _ltp <= at618 && _ltp >= at786
        : _ltp >= at618 && _ltp <= at786;
    final double retracedPct = range <= 0
        ? 0
        : _uptrend
        ? (_high - _ltp) / range * 100
        : (_ltp - _low) / range * 100;
    final double pad = range * 0.1 + 1;

    return AppCalculatorLayout(
      meta: calculatorMetaById('fibonacci'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Golden ratio · 61.8%',
        value: AppTokens.money(at618, decimals: 2),
        intent: inPocket ? UiIntent.bullish : UiIntent.primary,
        tag: inPocket ? 'in the pocket' : '$nearName nearest',
        tagIntent: inPocket ? UiIntent.bullish : UiIntent.neutral,
        footnote: range <= 0
            ? 'High must sit above low before a swing exists.'
            : 'Swing of ${AppTokens.money(range)} '
                  '${_uptrend ? 'up' : 'down'}, retraced '
                  '${AppTokens.percent(retracedPct, decimals: 0)} so far.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Swing range',
          value: AppTokens.money(range),
          hint: _uptrend ? 'low → high' : 'high → low',
        ),
        UiStat(
          label: 'Retraced',
          value: AppTokens.percent(retracedPct, decimals: 0),
          intent: retracedPct > 78.6 ? UiIntent.bearish : UiIntent.info,
          hint: retracedPct > 100 ? 'swing broken' : 'of the swing',
        ),
        UiStat(
          label: 'Golden pocket',
          value: AppTokens.money((at618 - at786).abs()),
          intent: inPocket ? UiIntent.bullish : UiIntent.neutral,
          hint: '61.8% → 78.6%',
        ),
        UiStat(
          label: 'Nearest level',
          value: AppTokens.money(nearPrice, decimals: 1),
          hint: '$nearName · ${AppTokens.money(nearGap, decimals: 1)} away',
        ),
        UiStat(
          label: 'Extension 161.8%',
          value: AppTokens.money(ext1618, decimals: 1),
          intent: UiIntent.bullish,
          hint: 'first target beyond',
        ),
        UiStat(
          label: 'Direction',
          value: _uptrend ? 'Uptrend' : 'Downtrend',
          intent: _uptrend ? UiIntent.bullish : UiIntent.bearish,
          hint: '6 levels, 3 targets',
          spark: <double>[for (final (String, double) l in r.levels) l.$2],
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Swing',
          hint: 'the leg being measured',
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: context.sp(context.ui.spacing.xs),
              children: <Widget>[
                UiBadge(
                  label: _isLive ? 'Live Quote' : 'Preset',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),

                UiButton(
                  label: 'Session OHLC',
                  leadingIcon: Icons.refresh,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: () => _fetchLiveRange(_symbol, use52Week: false),
                ),
                const SizedBox(width: 4),
                UiButton(
                  label: '52W Range',
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: () => _fetchLiveRange(_symbol, use52Week: true),
                ),
              ],
            ),
            AppCalcSegment<String>(
              label: 'Symbol',
              value: _symbol,
              onChanged: (String s) => _fetchLiveRange(s),
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'NIFTY', label: 'Nifty'),
                UiToggleOption<String>(value: 'BANKNIFTY', label: 'Bank'),
                UiToggleOption<String>(value: 'SENSEX', label: 'Sensex'),
                UiToggleOption<String>(value: 'RELIANCE', label: 'Reliance'),
              ],
            ),
            AppCalcSegment<bool>(
              label: 'Direction',
              value: _uptrend,
              onChanged: (bool v) => setState(() => _uptrend = v),
              helper: _uptrend
                  ? 'Measured down from the high — buying the dip.'
                  : 'Measured up from the low — selling the bounce.',
              options: const <UiToggleOption<bool>>[
                UiToggleOption<bool>(value: true, label: 'Uptrend'),
                UiToggleOption<bool>(value: false, label: 'Downtrend'),
              ],
            ),
            AppCalcNumberField(
              label: 'Swing high',
              value: _high,
              prefix: '₹',
              onChanged: (double v) => setState(() => _high = v),
            ),
            AppCalcNumberField(
              label: 'Swing low',
              value: _low,
              prefix: '₹',
              helper: range <= 0 ? 'Must sit below the high.' : null,
              onChanged: (double v) => setState(() => _low = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Live price',
          children: <Widget>[
            AppCalcNumberField(
              label: 'Last traded price',
              value: _ltp,
              prefix: '₹',
              helper: 'Decides which level is actually in play.',
              onChanged: (double v) => setState(() => _ltp = v),
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Retracement grid',
          hint: 'shallow to deep',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Ratio',
            valueHeader: 'Price',
            trailingHeader: 'From spot',
            rows: <UiKeyValueRow>[
              for (final (String, double) l in r.levels)
                UiKeyValueRow(
                  label: l.$1,
                  value: AppTokens.money(l.$2, decimals: 1),
                  trailing: _ltp <= 0
                      ? '—'
                      : AppTokens.signedPercent(
                          (l.$2 - _ltp) / _ltp * 100,
                          decimals: 2,
                        ),
                  intent: l.$1 == '61.8%'
                      ? UiIntent.bullish
                      : l.$1 == nearName
                      ? UiIntent.info
                      : UiIntent.neutral,
                  emphasis: l.$1 == '61.8%' || l.$1 == '50%',
                  detail: l.$1 == nearName ? 'Nearest to the live price' : null,
                  share: range <= 0
                      ? null
                      : ((l.$2 - _low) / range).clamp(0.0, 1.0),
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Extension targets',
          hint: 'beyond the swing',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Ratio',
            valueHeader: 'Target',
            trailingHeader: 'Reward',
            rows: <UiKeyValueRow>[
              for (final (String, double) x in r.extensions)
                UiKeyValueRow(
                  label: x.$1,
                  value: AppTokens.money(x.$2, decimals: 1),
                  trailing: AppTokens.money((x.$2 - _ltp).abs(), decimals: 0),
                  intent: UiIntent.bullish,
                  detail: 'From spot at ${AppTokens.money(_ltp, decimals: 0)}',
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Level fan',
          hint: 'spacing of the grid',
          child: AppCalcTrendChart(
            labels: <String>[for (final (String, double) l in r.levels) l.$1],
            valueFormatter: (num v) => AppTokens.money(v, decimals: 0),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Retracement',
                values: <double>[
                  for (final (String, double) l in r.levels) l.$2,
                ],
                intent: _uptrend ? UiIntent.bullish : UiIntent.bearish,
                area: true,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _ltp, label: 'spot'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Price against the grid',
          hint: 'golden pocket shaded',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: _low - pad,
            max: _high + pad,
            valueFormatter: (num v) => AppTokens.money(v, decimals: 0),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: at618 < at786 ? at618 : at786,
                end: at618 < at786 ? at786 : at618,
                intent: UiIntent.bullish,
                label: 'pocket',
                alpha: 0.2,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(value: _ltp, label: 'Spot', strong: true),
              if (r.levels.length > 1)
                UiRangeMarker(
                  value: r.levels[1].$2,
                  label: '38.2',
                  intent: UiIntent.info,
                  below: true,
                ),
              if (r.levels.length > 2)
                UiRangeMarker(
                  value: r.levels[2].$2,
                  label: '50',
                  intent: UiIntent.info,
                ),
              UiRangeMarker(
                value: at618,
                label: '61.8',
                intent: UiIntent.bullish,
                below: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (range <= 0)
          const UiCallout(
            intent: UiIntent.warning,
            title: 'No swing to measure',
            message:
                'Set a high above the low. Fibonacci divides a move — without '
                'one there is nothing to divide.',
          ),
        if (range > 0 && inPocket)
          UiCallout(
            intent: UiIntent.bullish,
            title: 'Price is in the golden pocket',
            message:
                'Between ${AppTokens.money(at618, decimals: 0)} and '
                '${AppTokens.money(at786, decimals: 0)} — the zone that '
                'attracts continuation entries, with the swing '
                '${_uptrend ? 'low' : 'high'} as the invalidation.',
          ),
        if (range > 0 && retracedPct > 100)
          const UiCallout(
            intent: UiIntent.danger,
            title: 'Swing broken',
            message:
                'Price has passed the far end of the leg, so this is no longer '
                'a retracement. Redraw from the new extreme.',
          ),
      ],
      formula:
          'Range = High − Low\n'
          'Uptrend level = High − Range × ratio\n'
          'Downtrend level = Low + Range × ratio\n'
          'Ratios = 23.6 · 38.2 · 50 · 61.8 · 78.6 · 100%\n'
          'Extensions = 127.2 · 161.8 · 200%',
      notes: const <String>[
        '50% is not a Fibonacci ratio. It is kept because price respects the '
            'midpoint of a swing regardless of the mathematics.',
        'The 61.8–78.6% band is where continuation setups cluster; deeper than '
            'that and the trend is usually in question.',
        'Levels are only as good as the swing chosen. Pick the leg the market '
            'is actually reacting to, not the largest one on the chart.',
        'Extensions measure from the swing, so they assume the trend resumes '
            'with the same energy it arrived with.',
      ],
    );
  }
}
