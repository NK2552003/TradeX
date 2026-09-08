import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/calculators/logic/trading_calculators.dart';

void main() {
  group('calcPositionSize', () {
    test('sizes the position from rupee risk per share', () {
      final PositionSizeResult r = calcPositionSize(
        accountSize: 500000,
        riskPct: 1,
        entry: 100,
        sl: 95,
      );

      expect(r.riskAmount, 5000);
      expect(r.riskPerShare, 5);
      expect(r.quantity, 1000);
      expect(r.positionValue, 100000);
      expect(r.capitalUsedPct, closeTo(20, 1e-9));
    });

    test('a short setup uses the same distance', () {
      final PositionSizeResult r = calcPositionSize(
        accountSize: 500000,
        riskPct: 1,
        entry: 95,
        sl: 100,
      );

      expect(r.riskPerShare, 5);
      expect(r.quantity, 1000);
    });

    test('quantity floors rather than rounding up past the risk cap', () {
      final PositionSizeResult r = calcPositionSize(
        accountSize: 100000,
        riskPct: 1,
        entry: 100,
        sl: 97,
      );

      // 1000 / 3 = 333.33 → 333, which risks ₹999, never ₹1,002.
      expect(r.quantity, 333);
      expect(r.quantity * r.riskPerShare, lessThanOrEqualTo(r.riskAmount));
    });

    test('a stop at the entry yields no position instead of infinity', () {
      final PositionSizeResult r = calcPositionSize(
        accountSize: 500000,
        riskPct: 1,
        entry: 100,
        sl: 100,
      );

      expect(r.quantity, 0);
      expect(r.positionValue, 0);
    });
  });

  group('calcRiskReward', () {
    test('a 2R setup needs a 33% win rate to break even', () {
      final RiskRewardResult r = calcRiskReward(entry: 100, sl: 95, target: 110);

      expect(r.risk, 5);
      expect(r.reward, 10);
      expect(r.ratio, 2);
      expect(r.breakevenWinRatePct, closeTo(100 / 3, 1e-9));
    });

    test('a 1R setup needs a 50% win rate', () {
      final RiskRewardResult r = calcRiskReward(entry: 100, sl: 90, target: 110);

      expect(r.ratio, 1);
      expect(r.breakevenWinRatePct, closeTo(50, 1e-9));
    });

    test('a zero-distance stop demands a 100% win rate', () {
      final RiskRewardResult r = calcRiskReward(
        entry: 100,
        sl: 100,
        target: 110,
      );

      expect(r.ratio, 0);
      expect(r.breakevenWinRatePct, 100);
    });
  });

  group('calcBrokerage', () {
    test('a discount-broker delivery trade pays no brokerage but real STT', () {
      final BrokerageResult r = calcBrokerage(
        broker: 'zerodha',
        segment: 'eq_del',
        qty: 100,
        buyPrice: 1000,
        sellPrice: 1050,
      );

      expect(r.turnover, 205000);
      expect(r.brokerage, 0);
      expect(r.grossPnl, 5000);
      expect(r.stt, closeTo(205, 1e-9));
      expect(r.total, greaterThan(0));
      expect(r.netPnl, closeTo(r.grossPnl - r.total, 1e-9));
    });

    test('intraday brokerage is capped at ₹20 per leg', () {
      final BrokerageResult r = calcBrokerage(
        broker: 'zerodha',
        segment: 'eq_intra',
        qty: 10000,
        buyPrice: 500,
        sellPrice: 505,
      );

      // 0.03% of a ₹50 lakh leg would be ₹1,500 — the cap binds on both legs.
      expect(r.brokerage, 40);
    });

    test('ICICI charges a percentage on delivery instead of a flat fee', () {
      final BrokerageResult r = calcBrokerage(
        broker: 'icici',
        segment: 'eq_del',
        qty: 100,
        buyPrice: 1000,
        sellPrice: 1000,
      );

      expect(r.brokerage, closeTo(200000 * 0.0029, 1e-9));
    });

    test('GST is charged on brokerage plus exchange and SEBI fees', () {
      final BrokerageResult r = calcBrokerage(
        broker: 'zerodha',
        segment: 'eq_intra',
        qty: 100,
        buyPrice: 1000,
        sellPrice: 1010,
      );

      expect(
        r.gst,
        closeTo((r.brokerage + r.exchangeTxn + r.sebi) * 0.18, 1e-6),
      );
      expect(
        r.total,
        closeTo(
          r.brokerage + r.stt + r.exchangeTxn + r.sebi + r.gst + r.stamp,
          1e-6,
        ),
      );
    });

    test('STT on options is charged on the sell leg only', () {
      final BrokerageResult r = calcBrokerage(
        broker: 'zerodha',
        segment: 'options',
        qty: 100,
        buyPrice: 100,
        sellPrice: 150,
      );

      expect(r.stt, closeTo(15000 * 0.001, 1e-9));
      expect(r.brokerage, 40);
    });

    test('breakeven points cover the round trip', () {
      final BrokerageResult r = calcBrokerage(
        broker: 'zerodha',
        segment: 'eq_intra',
        qty: 100,
        buyPrice: 1000,
        sellPrice: 1000,
      );

      expect(r.grossPnl, 0);
      expect(r.breakevenPoints, closeTo(r.total / 100, 1e-9));
      expect(r.netPnl, closeTo(-r.total, 1e-9));
    });

    test('a custom flat fee is applied per leg', () {
      final BrokerageResult r = calcBrokerage(
        broker: 'custom',
        segment: 'eq_intra',
        qty: 100,
        buyPrice: 1000,
        sellPrice: 1000,
        customFlatFee: 15,
      );

      expect(r.brokerage, 30);
    });
  });

  group('calcMargin', () {
    test('leverage is the inverse of the margin percentage', () {
      final MarginResult r = calcMargin(
        lots: 2,
        lotSize: 50,
        price: 20000,
        marginPct: 20,
      );

      expect(r.contractValue, 2000000);
      expect(r.marginRequired, 400000);
      expect(r.leverage, closeTo(5, 1e-9));
    });

    test('zero margin reports no leverage rather than infinity', () {
      final MarginResult r = calcMargin(
        lots: 1,
        lotSize: 50,
        price: 20000,
        marginPct: 0,
      );

      expect(r.leverage, 0);
    });
  });

  group('calcPivot', () {
    test('standard pivots sit symmetrically around the pivot', () {
      final PivotResult r = calcPivot(h: 110, l: 90, c: 100);

      expect(r.pp, closeTo(100, 1e-9));
      expect(r.r1, closeTo(110, 1e-9));
      expect(r.s1, closeTo(90, 1e-9));
      expect(r.r2, closeTo(120, 1e-9));
      expect(r.s2, closeTo(80, 1e-9));
      expect(r.r3, greaterThan(r.r2));
      expect(r.s3, lessThan(r.s2));
    });

    test('woodie weights the close twice', () {
      final PivotResult r = calcPivot(h: 110, l: 90, c: 100, method: 'woodie');

      expect(r.pp, closeTo((110 + 90 + 200) / 4, 1e-9));
    });

    test('camarilla levels stay tighter than standard ones', () {
      final PivotResult standard = calcPivot(h: 110, l: 90, c: 100);
      final PivotResult camarilla = calcPivot(
        h: 110,
        l: 90,
        c: 100,
        method: 'camarilla',
      );

      expect(camarilla.r1, lessThan(standard.r1));
      expect(camarilla.s1, greaterThan(standard.s1));
    });
  });

  group('calcFibonacci', () {
    test('an uptrend retraces down from the swing high', () {
      final FibResult r = calcFibonacci(high: 200, low: 100);

      expect(r.levels, hasLength(6));
      expect(r.levels.first.$1, '23.6%');
      expect(r.levels.first.$2, closeTo(200 - 23.6, 1e-9));
      expect(r.levels[3].$1, '61.8%');
      expect(r.levels[3].$2, closeTo(200 - 61.8, 1e-9));
      expect(r.levels.last.$2, closeTo(100, 1e-9));
      expect(r.extensions, hasLength(3));
      expect(r.extensions.first.$2, greaterThan(200));
    });

    test('a downtrend retraces up from the swing low', () {
      final FibResult r = calcFibonacci(high: 200, low: 100, uptrend: false);

      expect(r.levels.first.$2, closeTo(100 + 23.6, 1e-9));
      expect(r.levels.last.$2, closeTo(200, 1e-9));
      expect(r.extensions.first.$2, lessThan(100));
    });
  });

  group('calcPnl', () {
    test('a long profits when price rises', () {
      final PnlResult r = calcPnl(entry: 100, exit: 110, qty: 50);

      expect(r.grossPnl, 500);
      expect(r.investment, 5000);
      expect(r.pnlPct, closeTo(10, 1e-9));
      expect(r.isProfit, isTrue);
    });

    test('a short profits when price falls', () {
      final PnlResult r = calcPnl(
        entry: 110,
        exit: 100,
        qty: 50,
        isLong: false,
      );

      expect(r.grossPnl, 500);
      expect(r.isProfit, isTrue);
    });

    test('charges come out of the net figure and the percentage', () {
      final PnlResult r = calcPnl(
        entry: 100,
        exit: 110,
        qty: 50,
        brokerage: 120,
      );

      expect(r.grossPnl, 500);
      expect(r.netPnl, 380);
      expect(r.pnlPct, closeTo(7.6, 1e-9));
    });

    test('a losing trade is not a profit', () {
      final PnlResult r = calcPnl(entry: 100, exit: 90, qty: 10);

      expect(r.netPnl, -100);
      expect(r.isProfit, isFalse);
    });
  });

  group('calcAtrStop', () {
    test('the stop sits a multiple of ATR either side of entry', () {
      final AtrStopResult r = calcAtrStop(
        atr: 50,
        multiplier: 1.5,
        entry: 1000,
        accountSize: 500000,
        riskPct: 1,
      );

      expect(r.stopDistance, closeTo(75, 1e-9));
      expect(r.longStop, closeTo(925, 1e-9));
      expect(r.shortStop, closeTo(1075, 1e-9));
      // ₹5,000 of risk over a 75-point stop.
      expect(r.suggestedSize, closeTo(5000 / 75, 1e-9));
    });

    test('a wide stop cannot push the long stop below zero', () {
      final AtrStopResult r = calcAtrStop(
        atr: 50,
        multiplier: 1.5,
        entry: 50,
        accountSize: 100000,
        riskPct: 1,
      );

      expect(r.longStop, 0);
      expect(r.shortStop, closeTo(125, 1e-9));
    });

    test('a zero ATR sizes nothing rather than dividing by zero', () {
      final AtrStopResult r = calcAtrStop(
        atr: 0,
        multiplier: 2,
        entry: 1000,
        accountSize: 500000,
        riskPct: 1,
      );

      expect(r.stopDistance, 0);
      expect(r.suggestedSize, 0);
      expect(r.longStop, 1000);
    });

    test('size scales with the risk budget', () {
      final AtrStopResult one = calcAtrStop(
        atr: 20,
        multiplier: 2,
        entry: 500,
        accountSize: 1000000,
        riskPct: 1,
      );
      final AtrStopResult two = calcAtrStop(
        atr: 20,
        multiplier: 2,
        entry: 500,
        accountSize: 1000000,
        riskPct: 2,
      );

      expect(two.suggestedSize, closeTo(one.suggestedSize * 2, 1e-9));
    });
  });

  group('calcKelly', () {
    test('a 60% win rate at 2:1 wants 40% of capital', () {
      final KellyResult r = calcKelly(
        winRatePct: 60,
        avgWin: 2000,
        avgLoss: 1000,
        accountSize: 500000,
      );

      expect(r.fullKellyPct, closeTo(40, 1e-9));
      expect(r.halfKellyPct, closeTo(20, 1e-9));
      expect(r.quarterKellyPct, closeTo(10, 1e-9));
      expect(r.riskAmount, closeTo(100000, 1e-9));
      expect(r.riskLevel, 'aggressive');
    });

    test('a negative edge is told to bet nothing', () {
      final KellyResult r = calcKelly(
        winRatePct: 30,
        avgWin: 1000,
        avgLoss: 1000,
        accountSize: 500000,
      );

      expect(r.fullKellyPct, 0);
      expect(r.riskAmount, 0);
      expect(r.riskLevel, 'conservative');
    });

    test('a thin edge lands in the moderate band', () {
      final KellyResult r = calcKelly(
        winRatePct: 55,
        avgWin: 1000,
        avgLoss: 1000,
        accountSize: 100000,
      );

      expect(r.fullKellyPct, closeTo(10, 1e-9));
      expect(r.riskLevel, 'moderate');
      expect(r.riskAmount, closeTo(5000, 1e-9));
    });

    test('the sign of the average loss is ignored', () {
      final KellyResult signed = calcKelly(
        winRatePct: 60,
        avgWin: 2000,
        avgLoss: -1000,
        accountSize: 500000,
      );

      expect(signed.fullKellyPct, closeTo(40, 1e-9));
    });

    test('no average loss cannot divide by zero', () {
      final KellyResult r = calcKelly(
        winRatePct: 100,
        avgWin: 1000,
        avgLoss: 0,
        accountSize: 500000,
      );

      expect(r.fullKellyPct, 0);
    });
  });

  group('calcExpectancy', () {
    test('a 50% win rate at 2R is half an R per trade', () {
      final ExpectancyResult r = calcExpectancy(
        winRatePct: 50,
        avgWinR: 2,
        avgLossR: 1,
        avgTradeRisk: 5000,
        tradesPerMonth: 20,
      );

      expect(r.expectancyR, closeTo(0.5, 1e-9));
      expect(r.expectancyMoney, closeTo(2500, 1e-9));
      expect(r.monthlyExpected, closeTo(50000, 1e-9));
      expect(r.profitFactor, closeTo(2, 1e-9));
      expect(r.verdict, 'positive edge');
    });

    test('the rolling curve ends where 20 trades of expectancy would', () {
      final ExpectancyResult r = calcExpectancy(
        winRatePct: 50,
        avgWinR: 2,
        avgLossR: 1,
        avgTradeRisk: 5000,
        tradesPerMonth: 20,
      );

      expect(r.rollingCurve, hasLength(20));
      expect(r.rollingCurve.last, closeTo(r.expectancyR * 20, 1e-9));
    });

    test('a coin flip at 1R is breakeven, not an edge', () {
      final ExpectancyResult r = calcExpectancy(
        winRatePct: 50,
        avgWinR: 1,
        avgLossR: 1,
        avgTradeRisk: 5000,
        tradesPerMonth: 20,
      );

      expect(r.expectancyR, closeTo(0, 1e-9));
      expect(r.verdict, 'breakeven');
      expect(r.profitFactor, closeTo(1, 1e-9));
    });

    test('a losing system is called out', () {
      final ExpectancyResult r = calcExpectancy(
        winRatePct: 30,
        avgWinR: 1,
        avgLossR: 1,
        avgTradeRisk: 5000,
        tradesPerMonth: 20,
      );

      expect(r.expectancyR, closeTo(-0.4, 1e-9));
      expect(r.verdict, 'no edge');
      expect(r.monthlyExpected, lessThan(0));
    });

    test('a system that never loses has an infinite profit factor', () {
      final ExpectancyResult r = calcExpectancy(
        winRatePct: 100,
        avgWinR: 1,
        avgLossR: 1,
        avgTradeRisk: 1000,
        tradesPerMonth: 10,
      );

      expect(r.profitFactor, double.infinity);
      expect(r.rollingCurve.last, closeTo(20, 1e-9));
    });
  });

  group('calcPortfolioHeat', () {
    const List<({double riskPct, String label})> threeOpen =
        <({double riskPct, String label})>[
          (riskPct: 1, label: 'RELIANCE'),
          (riskPct: 1.5, label: 'TCS'),
          (riskPct: 2, label: 'NIFTY fut'),
        ];

    test('heat is the sum of the risk on every open position', () {
      final HeatResult r = calcPortfolioHeat(
        accountSize: 1000000,
        openPositions: threeOpen,
        winRatePct: 55,
        maxDrawdownPct: 20,
      );

      expect(r.totalHeatPct, closeTo(4.5, 1e-9));
      expect(r.totalHeatMoney, closeTo(45000, 1e-9));
      expect(r.heatLevel, 'elevated');
      // 6% of heat divided by the 1.5% average position.
      expect(r.maxPositions, closeTo(4, 1e-9));
      expect(r.riskOfRuinPct, closeTo(6.885, 0.02));
    });

    test('under 4% is safe, over 7% is dangerous', () {
      final HeatResult safe = calcPortfolioHeat(
        accountSize: 1000000,
        openPositions: const <({double riskPct, String label})>[
          (riskPct: 1, label: 'a'),
          (riskPct: 1, label: 'b'),
        ],
        winRatePct: 55,
        maxDrawdownPct: 20,
      );
      final HeatResult hot = calcPortfolioHeat(
        accountSize: 1000000,
        openPositions: const <({double riskPct, String label})>[
          (riskPct: 3, label: 'a'),
          (riskPct: 3, label: 'b'),
          (riskPct: 3, label: 'c'),
        ],
        winRatePct: 55,
        maxDrawdownPct: 20,
      );

      expect(safe.heatLevel, 'safe');
      expect(hot.heatLevel, 'dangerous');
      expect(hot.riskOfRuinPct, greaterThan(safe.riskOfRuinPct));
    });

    test('a flat coin-flip system is certain to hit the drawdown', () {
      final HeatResult r = calcPortfolioHeat(
        accountSize: 1000000,
        openPositions: threeOpen,
        winRatePct: 50,
        maxDrawdownPct: 20,
      );

      expect(r.riskOfRuinPct, 100);
    });

    test('an empty book is safe and risks nothing', () {
      final HeatResult r = calcPortfolioHeat(
        accountSize: 1000000,
        openPositions: const <({double riskPct, String label})>[],
        winRatePct: 55,
        maxDrawdownPct: 20,
      );

      expect(r.totalHeatPct, 0);
      expect(r.totalHeatMoney, 0);
      expect(r.riskOfRuinPct, 0);
      expect(r.maxPositions, 0);
      expect(r.heatLevel, 'safe');
    });
  });
}
