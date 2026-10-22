import 'calculator_journal_draft.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

import '../calculator_registry.dart';
import '../logic/trading_calculators.dart';
import '../services/market_data_service.dart';

/// Risk / reward — the geometry of one trade, and what that geometry needs from
/// a win rate before it pays.
///
/// A ratio on its own decides nothing, so the screen pairs it with the win rate
/// that breaks even, the edge at the rate actually expected, and the equity path
/// a run of such trades produces.
class RiskRewardCalculatorScreen extends StatefulWidget {
  const RiskRewardCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<RiskRewardCalculatorScreen> createState() =>
      _RiskRewardCalculatorScreenState();
}

class _RiskRewardCalculatorScreenState
    extends State<RiskRewardCalculatorScreen> {
  String _symbol = 'RELIANCE';
  double _entry = 1313.80;
  double _sl = 1294.00;
  double _target = 1353.00;
  double _winRate = 45;
  double _riskAmount = 5000;
  int _perMonth = 20;
  bool _isLive = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveLevels(_symbol);
  }

  Future<void> _fetchLiveLevels(String sym) async {
    try {
      final MarketQuote q = await MarketDataService.instance.getQuote(sym);
      if (!mounted) return;
      setState(() {
        _symbol = sym;
        _entry = q.price;
        _sl = (q.price * 0.985).roundToDouble();
        _target = (q.price * 1.03).roundToDouble();
        _isLive = q.isLive;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final RiskRewardResult r = calcRiskReward(
      entry: _entry,
      sl: _sl,
      target: _target,
    );
    final ExpectancyResult e = calcExpectancy(
      winRatePct: _winRate,
      avgWinR: r.ratio,
      avgLossR: 1,
      avgTradeRisk: _riskAmount,
      tradesPerMonth: _perMonth,
    );
    final bool long = _target >= _entry;
    final double edge = _winRate - r.breakevenWinRatePct;
    final bool thin = r.ratio < 1.5;
    final double lo = <double>[
      _entry,
      _sl,
      _target,
    ].reduce((double a, double b) => a < b ? a : b);
    final double hi = <double>[
      _entry,
      _sl,
      _target,
    ].reduce((double a, double b) => a > b ? a : b);
    final double pad = (hi - lo) * 0.12 + 1;

    return AppCalculatorLayout(
      actions: [
        UiButton(
          label: 'Log Trade',
          leadingIcon: Icons.book_outlined,
          variant: UiVariant.soft,
          onPressed: r.risk > 0 && _riskAmount.isFinite && _riskAmount > 0
              ? () => openCalculatorJournalDraft(
                  context,
                  symbol: _symbol,
                  entry: _entry,
                  stopLoss: _sl,
                  quantity: (_riskAmount / r.risk).floorToDouble(),
                  target: _target,
                )
              : null,
        ),
      ],
      meta: calculatorMetaById('risk_reward'),
      onBack: widget.onBack,
      headline: AppCalcHeadline(
        label: 'Reward : Risk',
        value: r.ratio <= 0 ? '—' : '1 : ${r.ratio.toStringAsFixed(2)}',
        intent: thin ? UiIntent.warning : UiIntent.bullish,
        tag: e.verdict,
        tagIntent: switch (e.verdict) {
          'positive edge' => UiIntent.bullish,
          'no edge' => UiIntent.bearish,
          _ => UiIntent.warning,
        },
        footnote: r.ratio <= 0
            ? 'Entry and stop loss must differ.'
            : 'Needs ${AppTokens.percent(r.breakevenWinRatePct)} of these '
                  'trades to break even.',
      ),
      stats: <UiStat>[
        UiStat(
          label: 'Risk / share',
          value: AppTokens.money(r.risk),
          intent: UiIntent.bearish,
          hint: 'entry to stop',
        ),
        UiStat(
          label: 'Reward / share',
          value: AppTokens.money(r.reward),
          intent: UiIntent.bullish,
          hint: 'entry to target',
        ),
        UiStat(
          label: 'Breakeven rate',
          value: AppTokens.percent(r.breakevenWinRatePct),
          hint: 'at this ratio',
        ),
        UiStat(
          label: 'Edge',
          value: AppTokens.signedPercent(edge, decimals: 1),
          intent: AppTokens.plIntent(edge),
          hint: 'win rate over breakeven',
        ),
        UiStat(
          label: 'Expectancy',
          value: AppTokens.rr(e.expectancyR),
          intent: AppTokens.plIntent(e.expectancyR),
          hint:
              '${AppTokens.signedMoney(e.expectancyMoney, decimals: 0)} '
              'per trade',
        ),
        UiStat(
          label: 'Per month',
          value: AppTokens.signedMoney(e.monthlyExpected, decimals: 0),
          intent: AppTokens.plIntent(e.monthlyExpected),
          hint: '$_perMonth trades',
          spark: e.rollingCurve,
        ),
      ],
      inputs: <AppCalcInputGroup>[
        AppCalcInputGroup(
          label: 'Levels',
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
                  onPressed: () => _fetchLiveLevels(_symbol),
                ),
              ],
            ),
            AppCalcSegment<String>(
              label: 'Symbol',
              value: _symbol,
              onChanged: (String s) => _fetchLiveLevels(s),
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
              onChanged: (double v) => setState(() => _sl = v),
            ),
            AppCalcNumberField(
              label: 'Target',
              value: _target,
              prefix: '₹',
              helper: long ? 'Above entry — long.' : 'Below entry — short.',
              onChanged: (double v) => setState(() => _target = v),
            ),
          ],
        ),
        AppCalcInputGroup(
          label: 'System',
          hint: 'turns the ratio into money',
          children: <Widget>[
            AppCalcSliderField(
              label: 'Expected win rate',
              value: _winRate,
              min: 10,
              max: 90,
              divisions: 80,
              intent: edge >= 0 ? UiIntent.bullish : UiIntent.bearish,
              valueFormatter: (num v) => AppTokens.percent(v),
              helper:
                  'Breakeven sits at '
                  '${AppTokens.percent(r.breakevenWinRatePct)}.',
              onChanged: (double v) => setState(() => _winRate = v),
            ),
            AppCalcNumberField(
              label: 'Risk per trade',
              value: _riskAmount,
              prefix: '₹',
              decimals: 0,
              presets: const <double>[2000, 5000, 10000, 25000],
              presetLabel: (double v) => AppTokens.compactMoney(v),
              onChanged: (double v) => setState(() => _riskAmount = v),
            ),
            AppCalcNumberField(
              label: 'Trades per month',
              value: _perMonth.toDouble(),
              decimals: 0,
              onChanged: (double v) =>
                  setState(() => _perMonth = v.round().clamp(1, 500)),
            ),
          ],
        ),
      ],
      panels: <AppCalcPanel>[
        AppCalcPanel(
          label: 'Trade geometry',
          hint: 'per share',
          kind: AppCalcPanelKind.table,
          child: UiKeyValueTable(
            labelHeader: 'Leg',
            valueHeader: 'Price',
            trailingHeader: 'Move',
            rows: <UiKeyValueRow>[
              UiKeyValueRow(
                label: 'Entry',
                value: AppTokens.money(_entry),
                trailing: '—',
                emphasis: true,
              ),
              UiKeyValueRow(
                label: 'Stop loss',
                value: AppTokens.money(_sl),
                trailing: _entry <= 0
                    ? '—'
                    : AppTokens.signedPercent(
                        (_sl - _entry) / _entry * 100,
                        decimals: 2,
                      ),
                intent: UiIntent.bearish,
                detail: 'Risk ${AppTokens.money(r.risk)} a share',
              ),
              UiKeyValueRow(
                label: 'Target',
                value: AppTokens.money(_target),
                trailing: _entry <= 0
                    ? '—'
                    : AppTokens.signedPercent(
                        (_target - _entry) / _entry * 100,
                        decimals: 2,
                      ),
                intent: UiIntent.bullish,
                detail: 'Reward ${AppTokens.money(r.reward)} a share',
              ),
              UiKeyValueRow(
                label: 'Profit factor',
                value: e.profitFactor.isFinite
                    ? e.profitFactor.toStringAsFixed(2)
                    : '∞',
                trailing: e.verdict,
                intent: AppTokens.plIntent(e.expectancyR),
                emphasis: true,
                detail: 'Gross wins over gross losses at this win rate',
              ),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Equity over 20 trades',
          hint: 'R multiples',
          child: AppCalcTrendChart(
            series: <AppCalcSeries>[
              AppCalcSeries(
                name: 'Cumulative R',
                values: e.rollingCurve,
                intent: AppTokens.plIntent(e.expectancyR),
                area: true,
              ),
            ],
            valueFormatter: (num v) => '${v.toStringAsFixed(1)}R',
            thresholds: const <UiChartThreshold>[
              UiChartThreshold(value: 0, label: 'flat'),
            ],
          ),
        ),
        AppCalcPanel(
          label: 'Price ladder',
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
              UiRangeZone(
                start: _entry,
                end: _target,
                intent: UiIntent.bullish,
                alpha: 0.18,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(value: _entry, label: 'Entry', strong: true),
              UiRangeMarker(
                value: _target,
                label: 'Target',
                intent: UiIntent.bullish,
              ),
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
          label: 'Win rate against breakeven',
          hint: 'percent of trades',
          kind: AppCalcPanelKind.meter,
          child: UiRangeMeter(
            min: 0,
            max: 100,
            minLabel: '0%',
            maxLabel: '100%',
            valueFormatter: (num v) => AppTokens.percent(v, decimals: 0),
            zones: <UiRangeZone>[
              UiRangeZone(
                start: 0,
                end: r.breakevenWinRatePct,
                intent: UiIntent.bearish,
                alpha: 0.16,
              ),
              UiRangeZone(
                start: r.breakevenWinRatePct,
                end: 100,
                intent: UiIntent.bullish,
                alpha: 0.16,
              ),
            ],
            markers: <UiRangeMarker>[
              UiRangeMarker(
                value: _winRate,
                label: 'Expected',
                intent: edge >= 0 ? UiIntent.bullish : UiIntent.bearish,
                strong: true,
              ),
              UiRangeMarker(
                value: r.breakevenWinRatePct,
                label: 'Breakeven',
                intent: UiIntent.neutral,
                below: true,
              ),
            ],
          ),
        ),
      ],
      callouts: <Widget>[
        if (thin && r.ratio > 0)
          UiCallout(
            intent: UiIntent.warning,
            title: 'Thin reward for the risk',
            message:
                'Below 1 : 1.5 the system has to win '
                '${AppTokens.percent(r.breakevenWinRatePct)} of the time just '
                'to stand still, before charges.',
          ),
        if (e.expectancyR <= 0)
          const UiCallout(
            intent: UiIntent.danger,
            title: 'Negative expectancy',
            message:
                'At this win rate the ratio loses money over a long run of '
                'trades. Widen the target, tighten the stop, or skip the setup.',
          ),
      ],
      formula:
          'Risk = |Entry − Stop|\n'
          'Reward = |Target − Entry|\n'
          'Ratio = Reward ÷ Risk\n'
          'Breakeven win% = 1 ÷ (1 + Ratio) × 100\n'
          'Expectancy (R) = Win% × Ratio − Loss% × 1',
      notes: const <String>[
        'The ratio is geometry only. It says nothing about whether the target '
            'is reachable — the win rate carries that judgement.',
        'Breakeven win rate ignores charges. Add them and the real bar sits a '
            'few percent higher on every ratio.',
        'Expectancy is quoted in R, so it survives a change of position size. '
            'Money figures assume the risk per trade shown above.',
        'The equity curve is the deterministic sequence, not a simulation: '
            'wins and losses arrive in proportion, evenly spaced.',
      ],
    );
  }
}
