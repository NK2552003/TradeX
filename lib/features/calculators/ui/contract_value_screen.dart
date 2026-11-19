import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/options_calculators.dart';
import '../services/market_data_service.dart';

/// Contract value — what one lot actually controls, and what the exchange
/// wants held against it.
///
/// A derivatives quote hides its size. The screen puts notional, margin and
/// the leverage between them side by side, then shows what a one percent move
/// is worth in rupees.
class ContractValueCalculatorScreen extends StatefulWidget {
  const ContractValueCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ContractValueCalculatorScreen> createState() =>
      _ContractValueCalculatorScreenState();
}

class _ContractValueCalculatorScreenState
    extends State<ContractValueCalculatorScreen> {
  static const Map<String, (double, double)> _book = <String, (double, double)>{
    'NIFTY': (75, 23901.60),
    'BANKNIFTY': (35, 57382.60),
    'FINNIFTY': (65, 23400),
    'SENSEX': (20, 76614.72),
  };

  String _symbol = 'NIFTY';
  double _lotSize = 75;
  double _price = 23901.60;
  int _lots = 2;
  double _capital = 500000;
  bool _isLive = false;

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
        _price = q.price;
        _isLive = q.isLive;
      });
    } catch (_) {}
  }

  void _pick(String v) {
    setState(() {
      _symbol = v;
      _lotSize = _book[v]?.$1 ?? _lotSize;
      _price = _book[v]?.$2 ?? _price;
    });
    _fetchLiveQuote(v);
  }

  @override
  Widget build(BuildContext context) {
    final ContractValueResult r = calcContractValue(
      lotSize: _lotSize,
      price: _price,
      lots: _lots.toDouble(),
    );
    final SpanResult s = calcSpanMargin(
      symbol: _symbol,
      spotPrice: _price,
      lotSize: _lotSize,
      lots: _lots,
      isHedged: false,
    );
    final double marginPerLot = _lots <= 0 ? 0 : s.nakedMargin / _lots;
    final double leverage = s.nakedMargin <= 0 ? 0 : r.total / s.nakedMargin;
    final double utilPct = _capital <= 0 ? 0 : s.nakedMargin / _capital * 100;
    final double free = _capital - s.nakedMargin;
    final int maxLots = marginPerLot <= 0
        ? 0
        : (_capital / marginPerLot).floor();
    final double pointValue = _lotSize * _lots;
    final double onePct = r.total * 0.01;
    final bool overdrawn = s.nakedMargin > _capital;

    final List<double> notionalCurve = <double>[
      for (int i = 1; i <= 8; i++)
        calcContractValue(
          lotSize: _lotSize,
          price: _price,
          lots: i.toDouble(),
        ).total,
    ];
    final List<double> marginCurve = <double>[
      for (int i = 1; i <= 8; i++)
        calcSpanMargin(
          symbol: _symbol,
          spotPrice: _price,
          lotSize: _lotSize,
          lots: i,
          isHedged: false,
        ).nakedMargin,
    ];
    const List<double> moves = <double>[0.25, 0.5, 1, 2, 3];

    return AppCalculatorLayout(
      meta: calculatorMetaById('contract_value'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Notional controlled',
        value: AppTokens.lakhCrore(r.total),
        intent: UiIntent.primary,
        tag:
            '$_lots ${_lots == 1 ? 'lot' : 'lots'} · $_symbol · ${_isLive ? 'Live LTP' : 'Ref'}',
        tagIntent: _isLive ? UiIntent.success : UiIntent.info,
        footnote:
            '${AppTokens.lakhCrore(s.nakedMargin)} of margin holds it — '
            '${leverage.toStringAsFixed(1)}× leverage, '
            '${AppTokens.percent(utilPct, decimals: 0)} of the account.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Value per lot',
          value: AppTokens.lakhCrore(r.perLot),
          hint: '${_lotSize.round()} units × ₹${AppTokens.price(_price)}',
        ),
        UiStat(
          label: 'Margin required',
          value: AppTokens.lakhCrore(s.nakedMargin),
          intent: utilPct > 70 ? UiIntent.danger : UiIntent.warning,
          hint: '${AppTokens.percent(utilPct, decimals: 0)} of capital',
        ),
        UiStat(
          label: 'Leverage',
          value: '${leverage.toStringAsFixed(1)}×',
          intent: leverage > 8 ? UiIntent.danger : UiIntent.neutral,
          hint: 'notional ÷ margin',
        ),
        UiStat(
          label: '1% move in ₹',
          value: AppTokens.price(r.total * 0.01),
          intent: UiIntent.info,
          hint: '${_lots * _lotSize.round()} units × 1%',
          spark: notionalCurve,
        ),
        UiStat(
          label: 'Margin per lot',
          value: AppTokens.price(marginPerLot),
          hint: 'SPAN + exposure',
          spark: marginCurve,
        ),
        UiStat(
          label: 'Unused capital',
          value: AppTokens.lakhCrore(
            _capital > s.nakedMargin ? _capital - s.nakedMargin : 0,
          ),
          intent: UiIntent.bullish,
          hint: 'cushion against MTM',
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Contract',
          hint: 'the instrument being sized',
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: context.sp(context.ui.spacing.xs),
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'Live LTP: ₹${AppTokens.price(_price)}'
                      : 'Reference: ₹${AppTokens.price(_price)}',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),

                UiButton(
                  label: 'Sync LTP',
                  leadingIcon: Icons.refresh,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: () => _fetchLiveQuote(_symbol),
                ),
              ],
            ),
            AppCalcSegment<String>(
              label: 'Symbol',
              value: _symbol,
              onChanged: _pick,
              helper: 'Loads the exchange lot size and live spot.',
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'NIFTY', label: 'Nifty'),
                UiToggleOption<String>(value: 'BANKNIFTY', label: 'Bank'),
                UiToggleOption<String>(value: 'FINNIFTY', label: 'Fin'),
                UiToggleOption<String>(value: 'SENSEX', label: 'Sensex'),
              ],
            ),
            AppCalcNumberField(
              label: 'Price',
              value: _price,
              prefix: '₹',
              decimals: 0,
              helper: _isLive
                  ? 'Real-time spot price from Yahoo Finance v8.'
                  : 'Spot for index, futures price for a future.',
              onChanged: (double v) => setState(() => _price = v),
            ),
            AppCalcNumberField(
              label: 'Lot size',
              value: _lotSize,
              decimals: 0,
              presets: const <double>[75, 35, 65, 20],
              presetLabel: (double v) => v.toStringAsFixed(0),
              onChanged: (double v) => setState(() => _lotSize = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Size and account',
          children: <Widget>[
            AppCalcSliderField(
              label: 'Lots',
              value: _lots.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              intent: _lots > maxLots ? UiIntent.danger : UiIntent.primary,
              valueFormatter: (num v) => '${v.round()}',
              helper: _lots > maxLots
                  ? 'Beyond what the balance margins.'
                  : null,
              onChanged: (double v) => setState(() => _lots = v.round()),
            ),
            AppCalcNumberField(
              label: 'Account balance',
              value: _capital,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[100000, 500000, 1000000, 2500000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              onChanged: (double v) => setState(() => _capital = v),
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Contract ledger',
          hint: 'per lot, then per position',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Line',
            valueHeader: 'Position',
            trailingHeader: 'Per lot',
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'Notional',
                value: AppTokens.lakhCrore(r.total),
                trailing: AppTokens.lakhCrore(r.perLot),
                emphasis: true,
                detail: 'Lot size × price × lots',
              ),
              UiKeyValueRow(
                label: 'SPAN + exposure',
                value: AppTokens.price(s.nakedMargin),
                trailing: AppTokens.price(marginPerLot),
                intent: UiIntent.warning,
                detail:
                    '${AppTokens.percent(s.marginPct, decimals: 1)} of notional',
                share: r.total <= 0
                    ? null
                    : (s.nakedMargin / r.total).clamp(0.0, 1.0),
              ),
              UiKeyValueRow(
                label: 'Carry forward',
                value: AppTokens.price(s.nrmlMargin),
                trailing: AppTokens.price(
                  _lots <= 0 ? 0 : s.nrmlMargin / _lots,
                ),
                detail: 'NRML — held overnight',
              ),
              UiKeyValueRow(
                label: 'Intraday',
                value: AppTokens.price(s.misMargin),
                trailing: AppTokens.price(_lots <= 0 ? 0 : s.misMargin / _lots),
                intent: UiIntent.info,
                detail: 'MIS — squared off before close',
              ),
              UiKeyValueRow(
                label: 'One point',
                value: AppTokens.price(pointValue),
                trailing: AppTokens.price(_lotSize),
                detail: 'What a single index point pays',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Across the board',
          hint: 'at the loaded spots',
          kind: AppCalcPanelKind.table,
          wide: true,
          child: UiTable<_Sym>(
            rows: <_Sym>[
              for (final MapEntry<String, (double, double)> e in _book.entries)
                _Sym(
                  e.key,
                  e.value.$1,
                  e.value.$1 * e.value.$2,
                  calcSpanMargin(
                    symbol: e.key,
                    spotPrice: e.value.$2,
                    lotSize: e.value.$1,
                    lots: 1,
                    isHedged: false,
                  ).nakedMargin,
                ),
            ],
            density: UiDensity.compact,
            stackOnMobile: false,
            columns: <UiTableColumn<_Sym>>[
              UiTableColumn<_Sym>(
                header: 'Symbol',
                flex: 3,
                cell: (BuildContext ctx, _Sym x) => Text(
                  x.name,
                  style:
                      (x.name == _symbol
                              ? ctx.uiText.bodyStrong
                              : ctx.uiText.body)
                          .copyWith(color: ctx.uiColors.foreground),
                ),
              ),
              UiTableColumn<_Sym>(
                header: 'Lot',
                numeric: true,
                flex: 2,
                cell: (BuildContext ctx, _Sym x) => Text(
                  x.lot.toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  style: uiOverline(ctx),
                ),
              ),
              UiTableColumn<_Sym>(
                header: 'Value per lot',
                numeric: true,
                flex: 4,
                cell: (BuildContext ctx, _Sym x) => Text(
                  AppTokens.lakhCrore(x.notional),
                  textAlign: TextAlign.right,
                  style: ctx.uiText.body.copyWith(
                    color: ctx.uiColors.foreground,
                  ),
                ),
              ),
              UiTableColumn<_Sym>(
                header: 'Margin',
                numeric: true,
                flex: 4,
                cell: (BuildContext ctx, _Sym x) => Text(
                  AppTokens.price(x.margin),
                  textAlign: TextAlign.right,
                  style: ctx.uiText.body.copyWith(color: ctx.uiColors.warning),
                ),
              ),
              UiTableColumn<_Sym>(
                header: 'Leverage',
                numeric: true,
                flex: 3,
                cell: (BuildContext ctx, _Sym x) => Text(
                  x.margin <= 0
                      ? '—'
                      : '${(x.notional / x.margin).toStringAsFixed(1)}×',
                  textAlign: TextAlign.right,
                  style: uiOverline(ctx),
                ),
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Notional against margin',
          hint: '1 → 8 lots',
          wide: true,
          child: AppCalcTrendChart(
            labels: const <String>['1', '2', '3', '4', '5', '6', '7', '8'],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Notional',
                values: notionalCurve,
                intent: UiIntent.primary,
                area: true,
              ),
              AppCalcSeries(
                name: 'Margin',
                values: marginCurve,
                intent: UiIntent.warning,
              ),
            ],
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _capital, label: 'balance'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'What a move is worth',
          hint: 'on the whole position',
          child: UiBarList(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            items: <UiBarListItem>[
              for (final double m in moves)
                UiBarListItem(
                  label:
                      '${m.toStringAsFixed(m == m.roundToDouble() ? 0 : 2)}% · '
                      '${AppTokens.money(_price * m / 100, decimals: 0)} of price',
                  value: r.total * m / 100,
                ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Balance after the block',
          hint: '${AppTokens.percent(utilPct, decimals: 0)} committed',
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: s.nakedMargin,
                label: 'Blocked ${AppTokens.compactMoney(s.nakedMargin)}',
              ),
              UiCategorySegment(
                value: free < 0 ? 0 : free,
                label: 'Free ${AppTokens.compactMoney(free < 0 ? 0 : free)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Lots the balance carries',
          hint: 'naked, carried forward',
          kind: AppCalcPanelKind.meter,
          child: UiRangeMeter(
            min: 0,
            max: (maxLots < _lots ? _lots : maxLots) + 2,
            minLabel: '0',
            maxLabel: 'lots',
            valueFormatter: (num v) => '${v.round()}',
            zones: <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: maxLots * 0.7,
                intent: UiIntent.bullish,
                label: 'comfortable',
                alpha: 0.14,
              ),
              UiRangeZone(
                start: maxLots * 0.7,
                end: maxLots.toDouble(),
                intent: UiIntent.warning,
                label: 'stretched',
                alpha: 0.16,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: _lots.toDouble(),
                label: 'Taken',
                strong: true,
              ),
              UiRangeMarker(
                value: maxLots.toDouble(),
                label: 'Max',
                intent: UiIntent.warning,
                below: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (overdrawn)
          UiCallout(
            intent: UiIntent.danger,
            title: 'Margin exceeds the balance',
            message:
                '$_lots lots need ${AppTokens.price(s.nakedMargin)} against '
                '${AppTokens.price(_capital)} available. The order is rejected '
                'at ${maxLots + 1} lots; $maxLots is the most this balance '
                'carries.',
          ),
        if (!overdrawn && utilPct > 60)
          UiCallout(
            intent: UiIntent.warning,
            title: 'Most of the account is committed',
            message:
                '${AppTokens.percent(utilPct, decimals: 0)} of the balance is '
                'blocked, leaving ${AppTokens.price(free)} for mark-to-market. '
                'A ${AppTokens.percent(free / r.total * 100, decimals: 2)} move '
                'against the position starts a margin call.',
          ),
        if (!overdrawn && leverage > 8)
          UiCallout(
            intent: UiIntent.info,
            title: '${leverage.toStringAsFixed(1)}× on the notional',
            message:
                '${AppTokens.lakhCrore(r.total)} of exposure sits behind '
                '${AppTokens.price(s.nakedMargin)}. A one percent move is '
                '${AppTokens.percent(onePct / s.nakedMargin * 100, decimals: 0)} '
                'of the margin, not one percent of it.',
          ),
      ],
      formula:
          'Value per lot = Lot size × Price\n'
          'Notional = Value per lot × Lots\n'
          'Margin = Notional × SPAN+exposure %\n'
          'Leverage = Notional ÷ Margin\n'
          'One point = Lot size × Lots',
      notes: const <String>[
        'Margin here is an approximation of SPAN plus exposure. The exchange '
            'recomputes it through the session, and it rises when volatility '
            'does — size for the worse figure, not this one.',
        'Intraday product codes block less margin but are squared off by the '
            'broker near the close, at whatever price is available then.',
        'Leverage cuts both ways with no asymmetry: the same one percent that '
            'pays ten percent on margin also takes ten percent.',
        'Lot sizes are revised by the exchange from time to time. Confirm the '
            'current one before sizing anything real.',
      ],
    );
  }
}

/// One symbol's size and the margin behind a single lot of it.
class _Sym {
  const _Sym(this.name, this.lot, this.notional, this.margin);

  final String name;
  final double lot;
  final double notional;
  final double margin;
}
