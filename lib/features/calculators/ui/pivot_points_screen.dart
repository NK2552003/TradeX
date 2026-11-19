import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/trading_calculators.dart';
import '../services/market_data_service.dart';

/// Pivot points — yesterday's range turned into today's decision levels.
///
/// The levels are only useful next to a live price, so the screen keeps the
/// last traded price in the inputs and answers the two questions that follow
/// from it: which level is next, and how much room lies between.
class PivotPointsCalculatorScreen extends StatefulWidget {
  const PivotPointsCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<PivotPointsCalculatorScreen> createState() =>
      _PivotPointsCalculatorScreenState();
}

class _PivotPointsCalculatorScreenState
    extends State<PivotPointsCalculatorScreen> {
  double _high = 23949.85;
  double _low = 23895.85;
  double _close = 23873.45;
  double _ltp = 23901.60;
  String _symbol = 'NIFTY';
  String _method = 'standard';
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _syncLiveOhlc(_symbol);
  }

  Future<void> _syncLiveOhlc(String sym) async {
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(sym);
      if (!mounted) return;
      setState(() {
        _high = q.high;
        _low = q.low;
        _close = q.previousClose;
        _ltp = q.price;
        _isLive = q.isLive;
      });
    } catch (_) {}
  }

  static const Map<String, String> _methodNotes = <String, String>{
    'standard': 'Classic floor pivots — the average of high, low and close.',
    'camarilla': 'Tighter bands built off the close, for mean reversion.',
    'woodie': 'Weights the close twice, so it tracks momentum.',
  };

  @override
  Widget build(BuildContext context) {
    final PivotResult r = calcPivot(
      h: _high,
      l: _low,
      c: _close,
      method: _method,
    );
    final PivotResult std = calcPivot(h: _high, l: _low, c: _close);
    final PivotResult cam = calcPivot(
      h: _high,
      l: _low,
      c: _close,
      method: 'camarilla',
    );
    final PivotResult wood = calcPivot(
      h: _high,
      l: _low,
      c: _close,
      method: 'woodie',
    );

    final List<_Level> levels = <_Level>[
      _Level('R3', r.r3, UiIntent.bearish),
      _Level('R2', r.r2, UiIntent.bearish),
      _Level('R1', r.r1, UiIntent.bearish),
      _Level('PP', r.pp, UiIntent.primary),
      _Level('S1', r.s1, UiIntent.bullish),
      _Level('S2', r.s2, UiIntent.bullish),
      _Level('S3', r.s3, UiIntent.bullish),
    ];

    final double range = _high - _low;
    final double closePos = range <= 0 ? 0 : (_close - _low) / range * 100;
    final bool above = _ltp >= r.pp;
    double? nextUp;
    double? nextDown;
    String upName = '—';
    String downName = '—';
    for (final _Level l in levels) {
      if (l.price > _ltp && (nextUp == null || l.price < nextUp)) {
        nextUp = l.price;
        upName = l.name;
      }
      if (l.price < _ltp && (nextDown == null || l.price > nextDown)) {
        nextDown = l.price;
        downName = l.name;
      }
    }
    final double roomUp = nextUp == null ? 0 : nextUp - _ltp;
    final double roomDown = nextDown == null ? 0 : _ltp - nextDown;
    final double pad = range * 0.15 + 1;

    return AppCalculatorLayout(
      meta: calculatorMetaById('pivot_points'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Pivot',
        value: AppTokens.money(r.pp, decimals: 2),
        intent: above ? UiIntent.bullish : UiIntent.bearish,
        tag: above ? 'above pivot' : 'below pivot',
        tagIntent: above ? UiIntent.bullish : UiIntent.bearish,
        footnote: range <= 0
            ? 'High must sit above low before levels exist.'
            : 'Next level up $upName at ${AppTokens.money(nextUp ?? r.r3)}, '
                  'support $downName at ${AppTokens.money(nextDown ?? r.s3)}.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Room to $upName',
          value: AppTokens.money(roomUp),
          intent: UiIntent.bullish,
          hint: _ltp <= 0
              ? 'above spot'
              : '${AppTokens.percent(roomUp / _ltp * 100, decimals: 2)} away',
        ),
        UiStat(
          label: 'Room to $downName',
          value: AppTokens.money(roomDown),
          intent: UiIntent.bearish,
          hint: _ltp <= 0
              ? 'below spot'
              : '${AppTokens.percent(roomDown / _ltp * 100, decimals: 2)} away',
        ),
        UiStat(
          label: 'Day range',
          value: AppTokens.money(range),
          hint: _low <= 0
              ? 'high less low'
              : '${AppTokens.percent(range / _low * 100, decimals: 2)} of low',
        ),
        UiStat(
          label: 'Close in range',
          value: AppTokens.percent(closePos, decimals: 0),
          intent: closePos >= 50 ? UiIntent.bullish : UiIntent.bearish,
          hint: closePos >= 50 ? 'upper half' : 'lower half',
        ),
        UiStat(
          label: 'R1 − S1 band',
          value: AppTokens.money(r.r1 - r.s1),
          hint: 'the day it implies',
        ),
        UiStat(
          label: 'Method',
          value: _method == 'standard'
              ? 'Floor'
              : _method == 'camarilla'
              ? 'Camarilla'
              : 'Woodie',
          intent: UiIntent.info,
          hint: '7 levels',
          spark: <double>[r.s3, r.s2, r.s1, r.pp, r.r1, r.r2, r.r3],
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Previous session',
          hint: 'the range being carried forward',
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: context.sp(context.ui.spacing.xs),
              children: <Widget>[
                UiBadge(
                  label: _isLive ? 'Live OHLC · $_symbol' : 'Reference OHLC',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),

                UiButton(
                  label: 'Sync Live OHLC',
                  leadingIcon: Icons.refresh,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: () => _syncLiveOhlc(_symbol),
                ),
              ],
            ),
            AppCalcSegment<String>(
              label: 'Instrument',
              value: _symbol,
              onChanged: (String v) {
                setState(() => _symbol = v);
                _syncLiveOhlc(v);
              },
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'NIFTY', label: 'Nifty'),
                UiToggleOption<String>(value: 'BANKNIFTY', label: 'Bank'),
                UiToggleOption<String>(value: 'SENSEX', label: 'Sensex'),
                UiToggleOption<String>(value: 'RELIANCE', label: 'Reliance'),
              ],
            ),
            AppCalcNumberField(
              label: 'High',
              value: _high,
              prefix: '₹',
              onChanged: (double v) => setState(() => _high = v),
            ),
            AppCalcNumberField(
              label: 'Low',
              value: _low,
              prefix: '₹',
              helper: range <= 0 ? 'Must sit below the high.' : null,
              onChanged: (double v) => setState(() => _low = v),
            ),
            AppCalcNumberField(
              label: 'Close',
              value: _close,
              prefix: '₹',
              helper: 'Settlement, not the last trade.',
              onChanged: (double v) => setState(() => _close = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Today',
          children: <Widget>[
            AppCalcNumberField(
              label: 'Last traded price',
              value: _ltp,
              prefix: '₹',
              helper: 'Positions the levels around the live price.',
              onChanged: (double v) => setState(() => _ltp = v),
            ),
            AppCalcSegment<String>(
              label: 'Method',
              value: _method,
              onChanged: (String v) => setState(() => _method = v),
              helper: _methodNotes[_method],
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'standard', label: 'Floor'),
                UiToggleOption<String>(value: 'camarilla', label: 'Camarilla'),
                UiToggleOption<String>(value: 'woodie', label: 'Woodie'),
              ],
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Level map',
          hint: 'against ${AppTokens.money(_ltp, decimals: 0)}',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiTable<_Level>(
            rows: levels,
            density: UiDensity.compact,
            stackOnMobile: false,
            columns: <UiTableColumn<_Level>>[
              UiTableColumn<_Level>(
                header: 'Level',
                flex: 2,
                cell: (BuildContext ctx, _Level l) => Text(
                  l.name,
                  style:
                      (l.name == 'PP' ? ctx.uiText.bodyStrong : ctx.uiText.body)
                          .copyWith(color: ctx.uiColors.foreground),
                ),
              ),
              UiTableColumn<_Level>(
                header: 'Price',
                numeric: true,
                flex: 3,
                cell: (BuildContext ctx, _Level l) => Text(
                  AppTokens.money(l.price, decimals: 2),
                  textAlign: TextAlign.right,
                  style: ctx.uiText.body.copyWith(
                    color: ctx.uiColors.foreground,
                  ),
                ),
              ),
              UiTableColumn<_Level>(
                header: 'From spot',
                numeric: true,
                flex: 3,
                cell: (BuildContext ctx, _Level l) => Text(
                  AppTokens.signedMoney(l.price - _ltp, decimals: 1),
                  textAlign: TextAlign.right,
                  style: ctx.uiText.body.copyWith(
                    color: AppTokens.pl(ctx, l.price - _ltp),
                  ),
                ),
              ),
              UiTableColumn<_Level>(
                header: 'Move',
                numeric: true,
                flex: 2,
                cell: (BuildContext ctx, _Level l) => Text(
                  _ltp <= 0
                      ? '—'
                      : AppTokens.signedPercent((l.price - _ltp) / _ltp * 100),
                  textAlign: TextAlign.right,
                  style: uiOverline(ctx),
                ),
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Methods compared',
          hint: 'S2 → R2',
          child: AppCalcTrendChart(
            labels: const <String>['S2', 'S1', 'PP', 'R1', 'R2'],
            valueFormatter: (num v) => AppTokens.money(v, decimals: 0),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Floor',
                values: <double>[std.s2, std.s1, std.pp, std.r1, std.r2],
                intent: UiIntent.primary,
              ),
              AppCalcSeries(
                name: 'Camarilla',
                values: <double>[cam.s2, cam.s1, cam.pp, cam.r1, cam.r2],
                intent: UiIntent.info,
              ),
              AppCalcSeries(
                name: 'Woodie',
                values: <double>[wood.s2, wood.s1, wood.pp, wood.r1, wood.r2],
                intent: UiIntent.warning,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _ltp, label: 'spot'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Distance to each level',
          hint: 'absolute',
          child: UiBarList(
            valueFormatter: (num v) => AppTokens.money(v, decimals: 1),
            items: <UiBarListItem>[
              for (final _Level l in levels)
                if (l.name != 'PP')
                  UiBarListItem(
                    label:
                        '${l.name} · ${AppTokens.money(l.price, decimals: 0)}',
                    value: (l.price - _ltp).abs(),
                  ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Session ladder',
          hint: 'S3 → R3',
          kind: AppCalcPanelKind.meter,
          wide: true,
          child: UiRangeMeter(
            min: r.s3 - pad,
            max: r.r3 + pad,
            valueFormatter: (num v) => AppTokens.money(v, decimals: 0),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: r.s1,
                end: r.pp,
                intent: UiIntent.bullish,
                label: 'support',
                alpha: 0.14,
              ),
              UiRangeZone(
                start: r.pp,
                end: r.r1,
                intent: UiIntent.bearish,
                label: 'resistance',
                alpha: 0.14,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(value: _ltp, label: 'Spot', strong: true),
              UiRangeMarker(
                value: r.pp,
                label: 'PP',
                intent: UiIntent.primary,
                below: true,
              ),
              UiRangeMarker(value: r.r1, label: 'R1', intent: UiIntent.bearish),
              UiRangeMarker(
                value: r.r2,
                label: 'R2',
                intent: UiIntent.bearish,
                below: true,
              ),
              UiRangeMarker(value: r.s1, label: 'S1', intent: UiIntent.bullish),
              UiRangeMarker(
                value: r.s2,
                label: 'S2',
                intent: UiIntent.bullish,
                below: true,
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Where the close landed',
          hint: 'inside the previous range',
          kind: AppCalcPanelKind.meter,
          child: UiRangeMeter(
            min: _low - pad,
            max: _high + pad,
            minLabel: 'Low',
            maxLabel: 'High',
            valueFormatter: (num v) => AppTokens.money(v, decimals: 0),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: _low,
                end: _low + (range / 2),
                intent: UiIntent.bearish,
                label: 'lower half',
                alpha: 0.12,
              ),
              UiRangeZone(
                start: _low + (range / 2),
                end: _high,
                intent: UiIntent.bullish,
                label: 'upper half',
                alpha: 0.12,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(value: _close, label: 'Close', strong: true),
              UiRangeMarker(
                value: _ltp,
                label: 'Spot',
                intent: UiIntent.info,
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
            title: 'Range is not a range',
            message:
                'The high must sit above the low. Until it does the levels '
                'collapse onto a single price.',
          ),
        if (range > 0 && roomUp > 0 && roomDown > 0 && roomUp < roomDown / 3)
          UiCallout(
            intent: UiIntent.info,
            title: 'Pressed against $upName',
            message:
                'Only ${AppTokens.money(roomUp)} of room above and '
                '${AppTokens.money(roomDown)} below. Longs here pay full risk '
                'for a fraction of the reward.',
          ),
        if (range > 0 && closePos >= 80)
          const UiCallout(
            intent: UiIntent.bullish,
            title: 'Closed near the high',
            message:
                'A close in the top fifth of the range pulls every level up '
                'with it, and tends to open the next session on the front foot.',
          ),
      ],
      formula:
          'PP = (High + Low + Close) ÷ 3\n'
          'R1 = 2·PP − Low        S1 = 2·PP − High\n'
          'R2 = PP + (High − Low) S2 = PP − (High − Low)\n'
          'R3 = High + 2(PP − Low) S3 = Low − 2(High − PP)',
      notes: const <String>[
        'Levels are computed once, from the settled previous session, and do '
            'not move intraday. Their value is that everyone sees the same ones.',
        'Camarilla bands sit closer to the close and suit reversion; Woodie '
            'weights the close twice and leans with momentum.',
        'A level is a zone, not a line. Treat a few ticks either side as the '
            'same decision.',
        'On a gap open the previous range is stale — the first hour usually '
            'writes better levels than the pivots do.',
      ],
    );
  }
}

/// One decision level with the colour it should carry.
class _Level {
  const _Level(this.name, this.price, this.intent);

  final String name;
  final double price;
  final UiIntent intent;
}
