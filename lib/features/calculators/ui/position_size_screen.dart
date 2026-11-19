import 'calculator_journal_draft.dart';
import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/trading_calculators.dart';
import '../services/market_data_service.dart';

/// Position size — the quantity that keeps a losing trade inside a fixed
/// percentage of capital.
///
/// The answer is a single integer, so the screen spends its space on what that
/// integer costs: the rupee risk, the capital it ties up, and the shape a
/// losing streak takes at this risk setting.
class PositionSizeCalculatorScreen extends StatefulWidget {
  const PositionSizeCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<PositionSizeCalculatorScreen> createState() =>
      _PositionSizeCalculatorScreenState();
}

class _PositionSizeCalculatorScreenState
    extends State<PositionSizeCalculatorScreen> {
  String _symbol = 'RELIANCE';
  double _account = 500000;
  double _riskPct = 1;
  double _entry = 500;
  double _sl = 475;
  double _charges = 340;
  String _segment = 'equity';
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveQuoteOnly(_symbol);
  }

  Future<void> _fetchLiveQuoteOnly(String sym) async {
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(sym);
      if (!mounted) return;
      setState(() {
        _symbol = sym;
        _isLive = q.isLive;
      });
    } catch (_) {}
  }

  Future<void> _fetchLiveEntry(String sym) async {
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(sym);
      if (!mounted) return;
      setState(() {
        _symbol = sym;
        _entry = q.price;
        _sl = (q.price * 0.985).roundToDouble();
        _isLive = q.isLive;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final PositionSizeResult r = calcPositionSize(
      accountSize: _account,
      riskPct: _riskPct,
      entry: _entry,
      sl: _sl,
    );
    final bool over = _riskPct > 2;
    final bool long = _entry >= _sl;
    final double lossWithCharges = r.riskPerShare * r.quantity + _charges;
    final double breakevenMove = r.quantity <= 0 ? 0 : _charges / r.quantity;
    final int streakTo30 = _riskPct <= 0 ? 99 : (30.1 / _riskPct).floor();
    final double free = _account - r.positionValue;

    // Compounded losing streak — the reason 2% is treated as a ceiling.
    final List<double> streak = <double>[];
    double equity = _account;
    for (int i = 0; i <= 10; i++) {
      streak.add(equity);
      equity *= 1 - _riskPct / 100;
    }
    final double lo = long ? _sl : _entry;
    final double hi = long ? _entry : _sl;
    final double pad = (hi - lo).abs() * 0.8 + 1;

    return AppCalculatorLayout(
      actions: [
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
          onPressed: r.quantity > 0
              ? () => openCalculatorJournalDraft(
                  context,
                  symbol: _symbol,
                  entry: _entry,
                  stopLoss: _sl,
                  quantity: r.quantity.toDouble(),
                  calculatorId: 'position_size',
                  calculatorName: 'Position Size',
                )
              : null,
        ),
      ],
      meta: calculatorMetaById('position_size'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Quantity to trade',
        value: AppTokens.count(r.quantity),
        unit: _segment == 'equity' ? 'shares' : 'contracts',
        intent: r.quantity > 0 ? UiIntent.primary : UiIntent.neutral,
        tag: over ? 'over limit' : 'within limit',
        tagIntent: over ? UiIntent.warning : UiIntent.bullish,
        footnote: r.quantity == 0
            ? 'Entry and stop loss must differ before a size exists.'
            : 'Floored, so a stop-out costs at most '
                  '${AppTokens.price(r.riskAmount)}.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Risk budget',
          value: AppTokens.price(r.riskAmount),
          hint: '${AppTokens.percent(_riskPct)} of capital',
          intent: over ? UiIntent.warning : UiIntent.bearish,
        ),
        UiStat(
          label: 'Risk / share',
          value: AppTokens.money(r.riskPerShare),
          hint: long ? 'long setup' : 'short setup',
        ),
        UiStat(
          label: 'Position value',
          value: AppTokens.lakhCrore(r.positionValue),
          hint: '${AppTokens.count(r.quantity)} × ${AppTokens.money(_entry)}',
        ),
        UiStat(
          label: 'Capital used',
          value: AppTokens.percent(r.capitalUsedPct),
          intent: r.capitalUsedPct > 100 ? UiIntent.warning : UiIntent.neutral,
          hint: r.capitalUsedPct > 100 ? 'needs leverage' : 'unleveraged',
        ),
        UiStat(
          label: 'Loss with charges',
          value: AppTokens.signedMoney(-lossWithCharges, decimals: 0),
          intent: UiIntent.bearish,
          hint: 'if the stop triggers',
        ),
        UiStat(
          label: 'Streak to −30%',
          value: '$streakTo30 trades',
          intent: UiIntent.info,
          hint: 'consecutive losses',
          spark: streak,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Capital',
          children: <Widget>[
            AppCalcSegment<String>(
              label: 'Segment',
              value: _segment,
              onChanged: (String v) => setState(() => _segment = v),
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(value: 'equity', label: 'Equity'),
                UiToggleOption<String>(value: 'futures', label: 'Futures'),
                UiToggleOption<String>(value: 'options', label: 'Options'),
              ],
            ),
            AppCalcNumberField(
              label: 'Account size',
              value: _account,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[100000, 500000, 1000000, 2500000],
              presetLabel: (double v) => AppTokens.lakhCrore(v),
              onChanged: (double v) => setState(() => _account = v),
            ),
            AppCalcSliderField(
              label: 'Risk per trade',
              value: _riskPct,
              min: 0.1,
              max: 5,
              divisions: 49,
              intent: over ? UiIntent.warning : UiIntent.primary,
              valueFormatter: (num v) => AppTokens.percent(v),
              helper: 'Desks cap single-trade risk at 1–2%.',
              onChanged: (double v) => setState(() => _riskPct = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'Trade',
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: context.sp(context.ui.spacing.xs),
              children: <Widget>[
                UiBadge(
                  label: _isLive
                      ? 'Live LTP: ₹${AppTokens.price(_entry)}'
                      : 'Preset LTP: ₹${AppTokens.price(_entry)}',
                  intent: _isLive ? UiIntent.success : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),

                UiButton(
                  label: 'Sync LTP',
                  leadingIcon: Icons.refresh,
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: () => _fetchLiveEntry(_symbol),
                ),
              ],
            ),
            AppCalcSegment<String>(
              label: 'Symbol',
              value: _symbol,
              onChanged: (String s) => _fetchLiveEntry(s),
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
              label: 'Stop loss',
              value: _sl,
              prefix: '₹',
              helper: long ? 'Below entry — long.' : 'Above entry — short.',
              onChanged: (double v) => setState(() => _sl = v),
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
          label: 'Sizing arithmetic',
          hint: 'per trade',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Component',
            valueHeader: 'Value',
            trailingHeader: 'Basis',
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'Risk budget',
                value: AppTokens.price(r.riskAmount),
                trailing: AppTokens.percent(_riskPct),
                intent: UiIntent.bearish,
                emphasis: true,
              ),
              UiKeyValueRow(
                label: 'Stop distance',
                value: AppTokens.money(r.riskPerShare),
                trailing: _entry <= 0
                    ? '—'
                    : AppTokens.percent(r.riskPerShare / _entry * 100),
                detail: 'Entry to stop, direction ignored',
              ),
              UiKeyValueRow(
                label: 'Quantity',
                value: AppTokens.count(r.quantity),
                trailing: 'floor',
                emphasis: true,
              ),
              UiKeyValueRow(
                label: 'Position value',
                value: AppTokens.price(r.positionValue),
                trailing: AppTokens.percent(r.capitalUsedPct),
                share: (r.capitalUsedPct / 100).clamp(0.0, 1.0),
              ),
              UiKeyValueRow(
                label: 'Charges',
                value: AppTokens.price(_charges),
                trailing: AppTokens.money(breakevenMove),
                detail: 'Round trip, and what it costs per share',
              ),
              UiKeyValueRow(
                label: 'Loss if stopped',
                value: AppTokens.signedMoney(-lossWithCharges, decimals: 0),
                trailing: _account <= 0
                    ? '—'
                    : AppTokens.percent(lossWithCharges / _account * 100),
                intent: UiIntent.bearish,
                emphasis: true,
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Losing streak',
          hint: 'compounded',
          child: AppCalcTrendChart(
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Capital',
                values: streak,
                intent: UiIntent.bearish,
                area: true,
              ),
            ],
            labels: <String>[for (int i = 0; i <= 10; i++) '$i'],
            valueFormatter: (num v) => AppTokens.compactMoney(v),
            thresholds: <UiChartThreshold>[
              UiChartThreshold(value: _account * 0.7, label: '−30%'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Trade ladder',
          hint: long ? 'long' : 'short',
          kind: AppCalcPanelKind.meter,
          child: UiRangeMeter(
            min: lo - pad,
            max: hi + pad,
            valueFormatter: (num v) => AppTokens.money(v, decimals: 1),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: _sl,
                end: _entry,
                intent: UiIntent.bearish,
                alpha: 0.18,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(value: _entry, label: 'Entry', strong: true),
              UiRangeMarker(
                value: _sl,
                label: 'Stop',
                intent: UiIntent.bearish,
                below: true,
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Capital deployment',
          hint: AppTokens.lakhCrore(_account),
          kind: AppCalcPanelKind.meter,
          child: UiCategoryBar(
            marker: (r.capitalUsedPct / 100).clamp(0.0, 1.0),
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: r.positionValue.clamp(0.0, _account),
                label: 'Deployed',
              ),
              UiCategorySegment(value: free < 0 ? 0 : free, label: 'Free'),
            ],
          ),
        ),
        // PLACEHOLDER_PANELS2
      ],
      callouts: <Widget>[
        if (over)
          const UiCallout(
            intent: UiIntent.warning,
            title: 'Risk above 2%',
            message:
                'At this setting a run of losses compounds faster than a '
                'normal winning month repairs it.',
          ),
        if (r.capitalUsedPct > 100)
          UiCallout(
            intent: UiIntent.info,
            title: 'Position exceeds capital',
            message:
                'The size needs ${(r.capitalUsedPct / 100).toStringAsFixed(2)}× '
                'leverage. Intraday products allow it; delivery does not.',
          ),
      ],
      formula:
          'Risk budget = Capital × Risk%\n'
          'Quantity = ⌊Risk budget ÷ |Entry − Stop|⌋\n'
          'Position value = Quantity × Entry',
      notes: const <String>[
        'Quantity is floored, so the realised loss lands under the budget, '
            'never over it.',
        'Only the distance to the stop matters — the same size holds for a '
            'short.',
        'Charges are excluded from the budget and shown separately, because '
            'they are paid whether or not the stop triggers.',
        'The streak curve compounds the loss on the balance that survives, '
            'which is why the count to −30% is not simply 30 ÷ risk.',
      ],
    );
  }
}
