import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/trading_calculators.dart';
import '../services/market_data_service.dart';
import 'calculator_journal_draft.dart';

/// Brokerage — what a round trip actually costs, line by line.
///
/// The gross figure on the terminal is not the figure that reaches the ledger.
/// Every statutory line item is laid out beside the leg that triggers it, and
/// the screen states the move needed before the position is merely even.
class BrokerageCalculatorScreen extends StatefulWidget {
  const BrokerageCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<BrokerageCalculatorScreen> createState() =>
      _BrokerageCalculatorScreenState();
}

class _BrokerageCalculatorScreenState extends State<BrokerageCalculatorScreen> {
  String _symbol = 'RELIANCE';
  String _broker = 'zerodha';
  String _segment = 'eq_intra';
  double _qty = 500;
  double _buy = 1302.50;
  double _sell = 1313.80;
  double _customFee = 20;
  double _customPct = 0.03;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveLtp(_symbol);
  }

  Future<void> _fetchLiveLtp(String sym) async {
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(sym);
      if (!mounted) return;
      setState(() {
        _symbol = sym;
        _buy = q.previousClose;
        _sell = q.price;
        _isLive = q.isLive;
      });
    } catch (_) {}
  }

  static const Map<String, String> _segmentNames = <String, String>{
    'eq_intra': 'Equity intraday — STT on the sell leg only.',
    'eq_del': 'Equity delivery — STT on both legs, no intraday relief.',
    'futures': 'Futures — CTT on sell, stamp on buy.',
    'options': 'Options — STT on premium, not on contract value.',
  };

  @override
  Widget build(BuildContext context) {
    final BrokerageResult r = calcBrokerage(
      broker: _broker,
      segment: _segment,
      qty: _qty,
      buyPrice: _buy,
      sellPrice: _sell,
      customFlatFee: _customFee,
      customPct: _customPct,
    );
    final List<(String, double, String)> lines = <(String, double, String)>[
      ('Brokerage', r.brokerage, 'both legs'),
      ('STT / CTT', r.stt, _segment == 'eq_del' ? 'buy + sell' : 'sell leg'),
      ('Exchange txn', r.exchangeTxn, 'on turnover'),
      ('SEBI charges', r.sebi, '₹10 a crore'),
      ('GST', r.gst, '18% on brokerage + txn'),
      ('Stamp duty', r.stamp, 'buy leg'),
    ];
    final double chargePct = r.turnover <= 0 ? 0 : r.total / r.turnover * 100;
    final double breakevenPrice = _buy + r.breakevenPoints;
    final double keptPct = r.grossPnl == 0 ? 0 : r.netPnl / r.grossPnl * 100;
    final bool eaten = r.grossPnl > 0 && r.netPnl <= 0;
    final double bePct = _buy <= 0 ? 0 : r.breakevenPoints / _buy * 100;
    final bool custom = _broker == 'custom';
    final double lo = <double>[
      _buy,
      _sell,
      breakevenPrice,
    ].reduce((double a, double b) => a < b ? a : b);
    final double hi = <double>[
      _buy,
      _sell,
      breakevenPrice,
    ].reduce((double a, double b) => a > b ? a : b);
    final double pad = (hi - lo) * 0.25 + 0.5;

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
                  entry: _buy,
                  exit: _sell,
                  quantity: _qty,
                  calculatorId: 'brokerage',
                  calculatorName: 'Brokerage',
                  notes:
                      'Net P&L after charges: ${AppTokens.signedMoney(r.netPnl, decimals: 0)} (Charges: ₹${AppTokens.price(r.total)})',
                )
              : null,
        ),
      ],
      meta: calculatorMetaById('brokerage'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Net P&L after charges',
        value: AppTokens.signedMoney(r.netPnl, decimals: 0),
        intent: AppTokens.plIntent(r.netPnl),
        tag: eaten ? 'charges won' : '${keptPct.toStringAsFixed(0)}% kept',
        tagIntent: eaten
            ? UiIntent.danger
            : keptPct >= 80
            ? UiIntent.bullish
            : UiIntent.warning,
        footnote:
            'Gross ${AppTokens.signedMoney(r.grossPnl, decimals: 0)} less '
            '${AppTokens.price(r.total)} of charges on '
            '${AppTokens.lakhCrore(r.turnover)} of turnover.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Turnover',
          value: AppTokens.lakhCrore(r.turnover),
          hint: 'both legs added',
        ),
        UiStat(
          label: 'Gross P&L',
          value: AppTokens.signedMoney(r.grossPnl, decimals: 0),
          intent: AppTokens.plIntent(r.grossPnl),
          hint: '${AppTokens.money(_sell - _buy)} a share',
        ),
        UiStat(
          label: 'Total charges',
          value: AppTokens.price(r.total),
          intent: UiIntent.bearish,
          hint: 'six line items',
          spark: <double>[for (final (String, double, String) l in lines) l.$2],
        ),
        UiStat(
          label: 'Cost of turnover',
          value: AppTokens.percent(chargePct, decimals: 3),
          intent: chargePct > 0.1 ? UiIntent.warning : UiIntent.neutral,
          hint: 'charges ÷ turnover',
        ),
        UiStat(
          label: 'Breakeven move',
          value: AppTokens.money(r.breakevenPoints),
          hint: '${AppTokens.percent(bePct, decimals: 3)} of entry',
        ),
        UiStat(
          label: 'Breakeven price',
          value: AppTokens.money(breakevenPrice),
          intent: _sell >= breakevenPrice ? UiIntent.bullish : UiIntent.bearish,
          hint: _sell >= breakevenPrice ? 'exit clears it' : 'exit below it',
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Contract',
          hint: 'sets the rate card',
          children: <Widget>[
            AppCalcSegment<String>(
              label: 'Broker',
              value: _broker,
              onChanged: (String v) => setState(() => _broker = v),
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'zerodha', label: 'Zerodha'),
                UiToggleOption<String>(value: 'upstox', label: 'Upstox'),
                UiToggleOption<String>(value: 'icici', label: 'ICICI'),
                UiToggleOption<String>(value: 'custom', label: 'Custom'),
              ],
            ),
            AppCalcSegment<String>(
              label: 'Segment',
              value: _segment,
              onChanged: (String v) => setState(() => _segment = v),
              helper: _segmentNames[_segment],
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'eq_intra', label: 'EQ intra'),
                UiToggleOption<String>(value: 'eq_del', label: 'EQ del'),
                UiToggleOption<String>(value: 'futures', label: 'FUT'),
                UiToggleOption<String>(value: 'options', label: 'OPT'),
              ],
            ),
            if (custom)
              AppCalcNumberField(
                label: 'Flat fee per leg',
                value: _customFee,
                prefix: '₹',
                decimals: 0,
                helper: 'Whichever is lower applies.',
                onChanged: (double v) => setState(() => _customFee = v),
              ),
            if (custom)
              AppCalcNumberField(
                label: 'Percent per leg',
                value: _customPct,
                suffix: '%',
                decimals: 3,
                onChanged: (double v) => setState(() => _customPct = v),
              ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Round trip',
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: context.sp(context.ui.spacing.xs),
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'Live Spot: ₹${AppTokens.price(_sell)}'
                      : 'Preset Spot: ₹${AppTokens.price(_sell)}',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),

                UiButton(
                  label: 'Sync LTP',
                  leadingIcon: Icons.refresh,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: () => _fetchLiveLtp(_symbol),
                ),
              ],
            ),
            AppCalcSegment<String>(
              label: 'Symbol',
              value: _symbol,
              onChanged: (String s) => _fetchLiveLtp(s),
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'RELIANCE', label: 'Reliance'),
                UiToggleOption<String>(value: 'TCS', label: 'TCS'),
                UiToggleOption<String>(value: 'HDFCBANK', label: 'HDFC'),
                UiToggleOption<String>(value: 'INFY', label: 'Infosys'),
                UiToggleOption<String>(value: 'NIFTY', label: 'Nifty'),
              ],
            ),
            AppCalcNumberField(
              label: 'Quantity',
              value: _qty,
              decimals: 0,
              presets: const <double>[100, 500, 1000, 5000],
              presetLabel: (double v) => AppTokens.count(v),
              onChanged: (double v) => setState(() => _qty = v),
            ),
            AppCalcNumberField(
              label: 'Buy price',
              value: _buy,
              prefix: '₹',
              onChanged: (double v) => setState(() => _buy = v),
            ),
            AppCalcNumberField(
              label: 'Sell price',
              value: _sell,
              prefix: '₹',
              helper: _sell >= _buy
                  ? 'Exit above entry — gross gain.'
                  : 'Exit below entry — gross loss.',
              onChanged: (double v) => setState(() => _sell = v),
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Charge ledger',
          hint: 'per round trip',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Line item',
            valueHeader: 'Amount',
            trailingHeader: 'Share',
            rows: <UiKeyValueRow>[
              for (final (String, double, String) l in lines)
                UiKeyValueRow(
                  label: l.$1,
                  value: AppTokens.price(l.$2),
                  trailing: r.total <= 0
                      ? '—'
                      : AppTokens.percent(l.$2 / r.total * 100, decimals: 0),
                  detail: l.$3,
                  share: r.total <= 0 ? null : (l.$2 / r.total).clamp(0.0, 1.0),
                ),
              UiKeyValueRow(
                label: 'Total charges',
                value: AppTokens.price(r.total),
                trailing: AppTokens.percent(chargePct, decimals: 3),
                intent: UiIntent.bearish,
                emphasis: true,
                detail: 'Share is of turnover, not of the charges',
              ),
              UiKeyValueRow(
                label: 'Net P&L',
                value: AppTokens.signedMoney(r.netPnl, decimals: 0),
                trailing: r.grossPnl == 0
                    ? '—'
                    : AppTokens.percent(keptPct, decimals: 0),
                intent: AppTokens.plIntent(r.netPnl),
                emphasis: true,
                detail: 'What survives of the gross',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Gross to net',
          hint: 'where it goes',
          child: UiWaterfallChart(
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            steps: <UiWaterfallStep>[
              UiWaterfallStep(label: 'Gross', value: r.grossPnl),
              UiWaterfallStep(label: 'Broker', value: -r.brokerage),
              UiWaterfallStep(label: 'STT', value: -r.stt),
              UiWaterfallStep(
                label: 'Txn+SEBI',
                value: -(r.exchangeTxn + r.sebi),
              ),
              UiWaterfallStep(label: 'GST+stamp', value: -(r.gst + r.stamp)),
              UiWaterfallStep(label: 'Net', value: r.netPnl, isTotal: true),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Charge mix',
          hint: AppTokens.price(r.total),
          child: UiDonutChart(
            valueFormatter: (num v) => AppTokens.price(v),
            slices: <UiDonutSlice>[
              for (final (String, double, String) l in lines)
                if (l.$2 > 0) UiDonutSlice(label: l.$1, value: l.$2),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Exit ladder',
          hint: 'buy · breakeven · exit',
          kind: AppCalcPanelKind.meter,
          child: UiRangeMeter(
            min: lo - pad,
            max: hi + pad,
            valueFormatter: (num v) => AppTokens.money(v, decimals: 2),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: _buy,
                end: breakevenPrice,
                intent: UiIntent.warning,
                label: 'charges',
                alpha: 0.18,
              ),
              if (_sell > breakevenPrice)
                UiRangeZone(
                  start: breakevenPrice,
                  end: _sell,
                  intent: UiIntent.bullish,
                  label: 'kept',
                  alpha: 0.18,
                ),
              if (_sell < breakevenPrice)
                UiRangeZone(
                  start: _sell,
                  end: breakevenPrice,
                  intent: UiIntent.bearish,
                  label: 'short',
                  alpha: 0.18,
                ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(value: _buy, label: 'Buy', strong: true),
              UiRangeMarker(
                value: _sell,
                label: 'Exit',
                intent: AppTokens.plIntent(r.netPnl),
              ),
              UiRangeMarker(
                value: breakevenPrice,
                label: 'Breakeven',
                intent: UiIntent.warning,
                below: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (eaten)
          UiCallout(
            intent: UiIntent.danger,
            title: 'Charges took the whole gain',
            message:
                'The trade made ${AppTokens.price(r.grossPnl)} gross and paid '
                '${AppTokens.price(r.total)} to keep it. Exit above '
                '${AppTokens.money(breakevenPrice)} or trade fewer, larger '
                'moves.',
          ),
        if (!eaten && bePct > 0.15)
          UiCallout(
            intent: UiIntent.warning,
            title: 'Costly per round trip',
            message:
                'Charges alone demand a ${AppTokens.percent(bePct, decimals: 2)} '
                'move. A strategy scalping less than that loses on arithmetic, '
                'not on direction.',
          ),
      ],
      formula:
          'Turnover = Qty × (Buy + Sell)\n'
          'Gross P&L = (Sell − Buy) × Qty\n'
          'Charges = Brokerage + STT + Txn + SEBI + GST + Stamp\n'
          'Net P&L = Gross P&L − Charges\n'
          'Breakeven move = Charges ÷ Qty',
      notes: const <String>[
        'Brokerage is the lower of the flat fee and the percentage, charged '
            'once per leg — delivery is free at the discount brokers.',
        'STT is the largest line item on most trades and is levied on the sell '
            'leg intraday, on both legs in delivery.',
        'GST applies to brokerage and exchange transaction charges only, never '
            'to STT or stamp duty.',
        'Breakeven move is the per-share drift needed to cover charges, before '
            'any profit exists.',
      ],
    );
  }
}
