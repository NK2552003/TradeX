import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/trading_calculators.dart';
import '../services/market_data_service.dart';
import 'calculator_journal_draft.dart';

/// Profit and loss — one closed trade, and the exits it could have had.
///
/// A single number is a poor answer here, so the screen puts the realised
/// result inside the ladder of nearby exits: what the same position pays two
/// percent higher, where it turns even, and what the charges cost along the way.
class PnlCalculatorScreen extends StatefulWidget {
  const PnlCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<PnlCalculatorScreen> createState() => _PnlCalculatorScreenState();
}

class _PnlCalculatorScreenState extends State<PnlCalculatorScreen> {
  String _symbol = 'RELIANCE';
  double _entry = 1302.50;
  double _exit = 1313.80;
  double _qty = 200;
  double _charges = 340;
  bool _isLong = true;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveLtp(_symbol, setAsExit: true);
  }

  Future<void> _fetchLiveLtp(String sym, {bool setAsExit = true}) async {
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(sym);
      if (!mounted) return;
      setState(() {
        _symbol = sym;
        if (setAsExit) {
          _exit = q.price;
          _entry = q.previousClose;
        } else {
          _entry = q.price;
        }
        _isLive = q.isLive;
      });
    } catch (_) {}
  }

  double _netAt(double price) => calcPnl(
    entry: _entry,
    exit: price,
    qty: _qty,
    isLong: _isLong,
    brokerage: _charges,
  ).netPnl;

  @override
  Widget build(BuildContext context) {
    final PnlResult r = calcPnl(
      entry: _entry,
      exit: _exit,
      qty: _qty,
      isLong: _isLong,
      brokerage: _charges,
    );
    final double perShare = (_isLong ? _exit - _entry : _entry - _exit);
    final double chargePerShare = _qty <= 0 ? 0 : _charges / _qty;
    final double breakeven = _isLong
        ? _entry + chargePerShare
        : _entry - chargePerShare;
    final double netPct = r.investment <= 0 ? 0 : r.netPnl / r.investment * 100;
    final double movePct = _entry <= 0 ? 0 : (_exit - _entry) / _entry * 100;
    final bool win = r.netPnl > 0;
    final bool eaten = r.grossPnl > 0 && r.netPnl <= 0;

    // Exits either side of the one taken, in even steps of the entry price.
    const List<double> steps = <double>[
      -0.10,
      -0.05,
      -0.02,
      0,
      0.02,
      0.05,
      0.10,
    ];
    final List<double> curve = <double>[
      for (int i = -10; i <= 10; i++) _netAt(_entry * (1 + i / 100)),
    ];
    final double lo = <double>[
      _entry,
      _exit,
      breakeven,
    ].reduce((double a, double b) => a < b ? a : b);
    final double hi = <double>[
      _entry,
      _exit,
      breakeven,
    ].reduce((double a, double b) => a > b ? a : b);
    final double pad = (hi - lo) * 0.2 + 1;

    return AppCalculatorLayout(
      actions: <Widget>[
        UiButton(
          label: 'History',
          leadingIcon: Icons.history_rounded,
          variant: UiVariant.ghost,
          size: UiSize.sm,
          onPressed: () => showCalculatorHistorySheet(context),
        ),
        UiButton(
          label: 'Log Trade',
          leadingIcon: Icons.book_outlined,
          variant: UiVariant.soft,
          size: UiSize.sm,
          onPressed: _qty > 0
              ? () => openCalculatorJournalDraft(
                  context,
                  symbol: _symbol,
                  entry: _entry,
                  exit: _exit,
                  quantity: _qty,
                  side: _isLong ? AppSide.long : AppSide.short,
                  calculatorId: 'pnl',
                  calculatorName: 'Profit & Loss',
                  notes:
                      'Net P&L: ${AppTokens.signedMoney(r.netPnl, decimals: 0)} (Charges: ₹${AppTokens.price(_charges)})',
                )
              : null,
        ),
      ],
      meta: calculatorMetaById('pnl'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Net profit and loss',
        value: AppTokens.signedMoney(r.netPnl, decimals: 0),
        intent: AppTokens.plIntent(r.netPnl),
        tag: eaten
            ? 'charges won'
            : win
            ? 'profit'
            : 'loss',
        tagIntent: eaten
            ? UiIntent.danger
            : win
            ? UiIntent.bullish
            : UiIntent.bearish,
        footnote:
            '${AppTokens.count(_qty)} ${_isLong ? 'long' : 'short'} at '
            '${AppTokens.money(_entry)}, out at ${AppTokens.money(_exit)} — '
            '${AppTokens.signedPercent(netPct, decimals: 2)} on capital.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Gross P&L',
          value: AppTokens.signedMoney(r.grossPnl, decimals: 0),
          intent: AppTokens.plIntent(r.grossPnl),
          hint: '${AppTokens.money(perShare)} a share',
        ),
        UiStat(
          label: 'Charges',
          value: AppTokens.price(_charges),
          intent: UiIntent.bearish,
          hint: '${AppTokens.money(chargePerShare)} a share',
        ),
        UiStat(
          label: 'Capital used',
          value: AppTokens.lakhCrore(r.investment),
          hint: 'entry × quantity',
        ),
        UiStat(
          label: 'Return',
          value: AppTokens.signedPercent(netPct, decimals: 2),
          intent: AppTokens.plIntent(netPct),
          hint: 'net, on capital',
        ),
        UiStat(
          label: 'Price move',
          value: AppTokens.signedPercent(movePct, decimals: 2),
          intent: AppTokens.plIntent(_isLong ? movePct : -movePct),
          hint: _isLong ? 'long — up is good' : 'short — down is good',
        ),
        UiStat(
          label: 'Breakeven exit',
          value: AppTokens.money(breakeven),
          intent: win ? UiIntent.bullish : UiIntent.warning,
          hint: 'covers the charges',
          spark: curve,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Position',
          children: <Widget>[
            AppCalcSegment<bool>(
              label: 'Side',
              value: _isLong,
              onChanged: (bool v) => setState(() => _isLong = v),
              options: const <UiToggleOption<bool>>[
                UiToggleOption<bool>(value: true, label: 'Long'),
                UiToggleOption<bool>(value: false, label: 'Short'),
              ],
            ),
            AppCalcNumberField(
              label: 'Quantity',
              value: _qty,
              decimals: 0,
              presets: const <double>[100, 200, 500, 1000],
              presetLabel: (double v) => AppTokens.count(v),
              onChanged: (double v) => setState(() => _qty = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Prices',
          hint: 'both legs, plus what it cost',
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'Live Spot: ₹${AppTokens.price(_exit)}'
                      : 'Preset Spot: ₹${AppTokens.price(_exit)}',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: context.sp(context.ui.spacing.xs),
                  runSpacing: context.sp(context.ui.spacing.xs),
                  children: <Widget>[
                    UiButton(
                      label: 'Sync Exit',
                      leadingIcon: Icons.refresh,
                      variant: UiVariant.ghost,
                      size: UiSize.xs,
                      onPressed: () => _fetchLiveLtp(_symbol, setAsExit: true),
                    ),
                    const SizedBox(width: 4),
                    UiButton(
                      label: 'Sync Entry',
                      variant: UiVariant.ghost,
                      size: UiSize.xs,
                      onPressed: () => _fetchLiveLtp(_symbol, setAsExit: false),
                    ),
                  ],
                ),
              ],
            ),
            AppCalcSegment<String>(
              label: 'Symbol',
              value: _symbol,
              onChanged: (String s) => _fetchLiveLtp(s, setAsExit: true),
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'RELIANCE', label: 'Reliance'),
                UiToggleOption<String>(value: 'TCS', label: 'TCS'),
                UiToggleOption<String>(value: 'HDFCBANK', label: 'HDFC'),
                UiToggleOption<String>(value: 'INFY', label: 'Infosys'),
                UiToggleOption<String>(value: 'NIFTY', label: 'Nifty'),
              ],
            ),
            AppCalcNumberField(
              label: 'Entry price',
              value: _entry,
              prefix: '₹',
              onChanged: (double v) => setState(() => _entry = v),
            ),
            AppCalcNumberField(
              label: 'Exit price',
              value: _exit,
              prefix: '₹',
              helper: _isLong
                  ? 'Above ${AppTokens.money(breakeven)} to clear charges.'
                  : 'Below ${AppTokens.money(breakeven)} to clear charges.',
              onChanged: (double v) => setState(() => _exit = v),
            ),
            AppCalcNumberField(
              label: 'Round-trip charges',
              value: _charges,
              prefix: '₹',
              decimals: 0,
              onChanged: (double v) => setState(() => _charges = v),
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Exit ladder',
          hint: 'net of charges',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Exit',
            valueHeader: 'Net P&L',
            trailingHeader: 'On capital',
            rows: <UiKeyValueRow>[
              for (final double s in steps)
                UiKeyValueRow(
                  label: s == 0
                      ? 'At entry'
                      : '${s > 0 ? '+' : ''}${(s * 100).toStringAsFixed(0)}%',
                  value: AppTokens.signedMoney(
                    _netAt(_entry * (1 + s)),
                    decimals: 0,
                  ),
                  trailing: r.investment <= 0
                      ? '—'
                      : AppTokens.signedPercent(
                          _netAt(_entry * (1 + s)) / r.investment * 100,
                          decimals: 1,
                        ),
                  intent: AppTokens.plIntent(_netAt(_entry * (1 + s))),
                  detail: AppTokens.money(_entry * (1 + s), decimals: 1),
                ),
              UiKeyValueRow(
                label: 'Taken',
                value: AppTokens.signedMoney(r.netPnl, decimals: 0),
                trailing: AppTokens.signedPercent(netPct, decimals: 1),
                intent: AppTokens.plIntent(r.netPnl),
                emphasis: true,
                detail: 'Exit at ${AppTokens.money(_exit, decimals: 1)}',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Trade ledger',
          hint: 'gross to net',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Line',
            valueHeader: 'Amount',
            trailingHeader: 'Per share',
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'Bought',
                value: AppTokens.price((_isLong ? _entry : _exit) * _qty),
                trailing: AppTokens.money(_isLong ? _entry : _exit),
                detail: _isLong ? 'Opening leg' : 'Closing leg',
              ),
              UiKeyValueRow(
                label: 'Sold',
                value: AppTokens.price((_isLong ? _exit : _entry) * _qty),
                trailing: AppTokens.money(_isLong ? _exit : _entry),
                detail: _isLong ? 'Closing leg' : 'Opening leg',
              ),
              UiKeyValueRow(
                label: 'Gross P&L',
                value: AppTokens.signedMoney(r.grossPnl, decimals: 0),
                trailing: AppTokens.money(perShare),
                intent: AppTokens.plIntent(r.grossPnl),
              ),
              UiKeyValueRow(
                label: 'Charges',
                value: AppTokens.signedMoney(-_charges, decimals: 0),
                trailing: AppTokens.money(chargePerShare),
                intent: UiIntent.bearish,
              ),
              UiKeyValueRow(
                label: 'Net P&L',
                value: AppTokens.signedMoney(r.netPnl, decimals: 0),
                trailing: AppTokens.money(_qty <= 0 ? 0 : r.netPnl / _qty),
                intent: AppTokens.plIntent(r.netPnl),
                emphasis: true,
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'P&L against exit price',
          hint: '±10% of entry',
          wide: true,
          child: AppCalcTrendChart(
            labels: <String>[
              for (int i = -10; i <= 10; i++) i % 5 == 0 ? '$i%' : '',
            ],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Net P&L',
                values: curve,
                intent: AppTokens.plIntent(r.netPnl),
                area: true,
              ),
            ],
            thresholds: const <UiChartThreshold>[
              UiChartThreshold(value: 0, label: 'breakeven'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Price ladder',
          hint: _isLong ? 'long' : 'short',
          kind: AppCalcPanelKind.meter,
          child: UiRangeMeter(
            min: lo - pad,
            max: hi + pad,
            valueFormatter: (num v) => AppTokens.money(v, decimals: 1),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: _entry < breakeven ? _entry : breakeven,
                end: _entry < breakeven ? breakeven : _entry,
                intent: UiIntent.warning,
                label: 'charges',
                alpha: 0.18,
              ),
              UiRangeZone(
                start: breakeven < _exit ? breakeven : _exit,
                end: breakeven < _exit ? _exit : breakeven,
                intent: win ? UiIntent.bullish : UiIntent.bearish,
                label: win ? 'kept' : 'shortfall',
                alpha: 0.18,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(value: _entry, label: 'Entry', strong: true),
              UiRangeMarker(
                value: _exit,
                label: 'Exit',
                intent: AppTokens.plIntent(r.netPnl),
              ),
              UiRangeMarker(
                value: breakeven,
                label: 'Even',
                intent: UiIntent.warning,
                below: true,
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Gross into net',
          hint: 'what charges take',
          kind: AppCalcPanelKind.meter,
          child: UiWaterfallChart(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            steps: <UiWaterfallStep>[
              UiWaterfallStep(label: 'Gross', value: r.grossPnl),
              UiWaterfallStep(label: 'Charges', value: -_charges),
              UiWaterfallStep(label: 'Net', value: r.netPnl, isTotal: true),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (eaten)
          UiCallout(
            intent: UiIntent.danger,
            title: 'A winning trade that lost money',
            message:
                'The move was right — ${AppTokens.price(r.grossPnl)} gross — but '
                '${AppTokens.price(_charges)} of charges took it. The exit had '
                'to clear ${AppTokens.money(breakeven)}.',
          ),
        if (!eaten && r.investment > 0 && netPct.abs() > 10)
          UiCallout(
            intent: win ? UiIntent.bullish : UiIntent.warning,
            title: win ? 'Large gain on capital' : 'Large loss on capital',
            message:
                '${AppTokens.signedPercent(netPct, decimals: 1)} on '
                '${AppTokens.lakhCrore(r.investment)} in one trade. Position '
                'size, not the move, is what makes a single result this big.',
          ),
      ],
      formula:
          'Gross P&L = (Exit − Entry) × Qty, reversed for a short\n'
          'Net P&L = Gross P&L − Charges\n'
          'Capital = Entry × Qty\n'
          'Return% = Net P&L ÷ Capital × 100\n'
          'Breakeven exit = Entry ± Charges ÷ Qty',
      notes: const <String>[
        'Return is quoted on the capital the entry tied up, not on the account, '
            'so it compares trades of different sizes fairly.',
        'The ladder recomputes charges at every exit, which is why the rows are '
            'not a straight multiple of one another.',
        'A short is the same arithmetic with the legs swapped: profit when the '
            'exit sits below the entry.',
        'Charges are entered as one round-trip figure. Use the brokerage tool '
            'to build that figure from the rate card.',
      ],
    );
  }
}
