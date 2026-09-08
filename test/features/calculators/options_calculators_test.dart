import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/calculators/logic/options_calculators.dart';

void main() {
  group('calcOptionsPnl', () {
    test('a long call risks the premium and has uncapped upside', () {
      final OptionsPnlResult r = calcOptionsPnl(
        isBuy: true,
        isCall: true,
        strike: 25000,
        premium: 120,
        lots: 2,
        lotSize: 50,
      );

      expect(r.premiumPaid, 12000);
      expect(r.breakeven, 25120);
      expect(r.maxLoss, 12000);
      expect(r.maxProfit, double.infinity);
      expect(r.isUnlimitedProfit, isTrue);
    });

    test('a written call caps profit at the premium and risks everything', () {
      final OptionsPnlResult r = calcOptionsPnl(
        isBuy: false,
        isCall: true,
        strike: 25000,
        premium: 120,
        lots: 1,
        lotSize: 50,
      );

      expect(r.maxProfit, 6000);
      expect(r.maxLoss, double.infinity);
      expect(r.isUnlimitedProfit, isFalse);
    });

    test('a long put breaks even below the strike and is capped there', () {
      final OptionsPnlResult r = calcOptionsPnl(
        isBuy: true,
        isCall: false,
        strike: 25000,
        premium: 200,
        lots: 1,
        lotSize: 50,
      );

      expect(r.breakeven, 24800);
      expect(r.maxLoss, 10000);
      expect(r.maxProfit, (25000 - 200) * 50);
    });

    test('the payoff curve is 41 samples across ±20% of the strike', () {
      final OptionsPnlResult r = calcOptionsPnl(
        isBuy: true,
        isCall: true,
        strike: 100,
        premium: 5,
        lots: 1,
        lotSize: 1,
      );

      expect(r.payoff, hasLength(41));
      expect(r.payoff.first.$1, closeTo(80, 1e-9));
      expect(r.payoff.last.$1, closeTo(120, 1e-9));
      // Far below the strike a long call just loses the premium.
      expect(r.payoff.first.$2, closeTo(-5, 1e-9));
      // At +20% it is 20 points in the money, less the 5 paid.
      expect(r.payoff.last.$2, closeTo(15, 1e-9));
    });

    test('the payoff crosses zero at the breakeven', () {
      final OptionsPnlResult r = calcOptionsPnl(
        isBuy: true,
        isCall: true,
        strike: 100,
        premium: 5,
        lots: 1,
        lotSize: 1,
      );

      final (double spot, double pnl) atBreakeven = r.payoff.firstWhere(
        ((double, double) p) => p.$2 >= 0,
      );
      expect(atBreakeven.$1, greaterThanOrEqualTo(r.breakeven - 1));
      expect(atBreakeven.$2, closeTo(0, 1));
    });
  });

  group('calcBlackScholes', () {
    test('an at-the-money call is worth roughly 0.4σ√T of spot', () {
      final BlackScholesResult r = calcBlackScholes(
        spot: 100,
        strike: 100,
        daysToExpiry: 365,
        ivPct: 20,
        rfRate: 0,
        isCall: true,
      );

      // The classic ATM approximation: 0.4 × σ × √T × S = 8.
      expect(r.price, closeTo(8, 0.2));
      expect(r.delta, closeTo(0.54, 0.02));
      expect(r.intrinsic, 0);
      expect(r.timeValue, closeTo(r.price, 1e-9));
    });

    test('put-call parity holds at a non-zero rate', () {
      const double spot = 24800;
      const double strike = 24900;
      const double days = 30;
      const double rate = 6.5;
      final BlackScholesResult call = calcBlackScholes(
        spot: spot,
        strike: strike,
        daysToExpiry: days,
        ivPct: 14,
        rfRate: rate,
        isCall: true,
      );
      final BlackScholesResult put = calcBlackScholes(
        spot: spot,
        strike: strike,
        daysToExpiry: days,
        ivPct: 14,
        rfRate: rate,
        isCall: false,
      );

      // C − P = S − K·e^(−rT)
      final double parity =
          spot - strike * math.exp(-rate / 100 * (days / 365));
      expect(call.price - put.price, closeTo(parity, 0.05));
    });

    test('call and put deltas differ by exactly one', () {
      final BlackScholesResult call = calcBlackScholes(
        spot: 100,
        strike: 105,
        daysToExpiry: 45,
        ivPct: 25,
        rfRate: 6,
        isCall: true,
      );
      final BlackScholesResult put = calcBlackScholes(
        spot: 100,
        strike: 105,
        daysToExpiry: 45,
        ivPct: 25,
        rfRate: 6,
        isCall: false,
      );

      expect(call.delta - put.delta, closeTo(1, 1e-9));
      // Gamma and vega are identical for a call and a put on the same terms.
      expect(call.gamma, closeTo(put.gamma, 1e-12));
      expect(call.vega, closeTo(put.vega, 1e-12));
    });

    test('theta is negative for a long option and rho signs oppose', () {
      final BlackScholesResult call = calcBlackScholes(
        spot: 100,
        strike: 100,
        daysToExpiry: 30,
        ivPct: 20,
        rfRate: 6,
        isCall: true,
      );
      final BlackScholesResult put = calcBlackScholes(
        spot: 100,
        strike: 100,
        daysToExpiry: 30,
        ivPct: 20,
        rfRate: 6,
        isCall: false,
      );

      expect(call.theta, lessThan(0));
      expect(put.theta, lessThan(0));
      expect(call.rho, greaterThan(0));
      expect(put.rho, lessThan(0));
    });

    test('at expiry the premium collapses to intrinsic value', () {
      final BlackScholesResult r = calcBlackScholes(
        spot: 110,
        strike: 100,
        daysToExpiry: 0,
        ivPct: 20,
        rfRate: 6,
        isCall: true,
      );

      expect(r.price, 10);
      expect(r.intrinsic, 10);
      expect(r.timeValue, 0);
      expect(r.delta, 1);
      expect(r.gamma, 0);
      expect(r.theta, 0);
      expect(r.vega, 0);
    });

    test('zero volatility is treated like expiry', () {
      final BlackScholesResult r = calcBlackScholes(
        spot: 90,
        strike: 100,
        daysToExpiry: 30,
        ivPct: 0,
        rfRate: 6,
        isCall: false,
      );

      expect(r.price, 10);
      expect(r.delta, -1);
    });

    test('a deeper strike is worth less than a nearer one', () {
      double priceAt(double strike) => calcBlackScholes(
        spot: 100,
        strike: strike,
        daysToExpiry: 30,
        ivPct: 20,
        rfRate: 6,
        isCall: true,
      ).price;

      expect(priceAt(110), lessThan(priceAt(100)));
      expect(priceAt(100), lessThan(priceAt(90)));
    });
  });

  group('calcContractValue', () {
    test('notional scales with lots', () {
      final ContractValueResult r = calcContractValue(
        lotSize: 50,
        price: 24800,
        lots: 3,
      );

      expect(r.perLot, 1240000);
      expect(r.total, 3720000);
      expect(r.lots, 3);
    });

    test('one lot is the default', () {
      final ContractValueResult r = calcContractValue(
        lotSize: 25,
        price: 100,
      );

      expect(r.total, r.perLot);
    });
  });

  group('calcStrategy', () {
    StrategyLeg leg(
      bool isBuy,
      bool isCall,
      double strike,
      double premium, [
      int lots = 1,
    ]) => StrategyLeg(
      isBuy: isBuy,
      isCall: isCall,
      strike: strike,
      premium: premium,
      lots: lots,
      lotSize: 50,
    );

    test('a lone long call matches the single-leg calculator', () {
      final StrategyResult r = calcStrategy(<StrategyLeg>[
        leg(true, true, 24800, 128),
      ], 24800);
      final OptionsPnlResult single = calcOptionsPnl(
        isBuy: true,
        isCall: true,
        strike: 24800,
        premium: 128,
        lots: 1,
        lotSize: 50,
      );

      expect(r.maxProfit, double.infinity);
      expect(r.maxLoss, closeTo(single.maxLoss, 1e-6));
      expect(r.breakevens, hasLength(1));
      expect(r.breakevens.single, closeTo(single.breakeven, 1e-6));
      expect(r.netPremium, closeTo(-6400, 1e-9));
      expect(r.marginRequired, closeTo(6400, 1e-9));
      expect(r.rewardToRisk, double.infinity);
      expect(r.payoffCurve, hasLength(21));
    });

    test('a long straddle breaks even either side of the strike', () {
      final StrategyResult r = calcStrategy(<StrategyLeg>[
        leg(true, true, 24800, 128),
        leg(true, false, 24800, 120),
      ], 24800);

      expect(r.netPremium, closeTo(-12400, 1e-9));
      expect(r.maxLoss, closeTo(12400, 1e-9));
      expect(r.maxProfit, double.infinity);
      expect(r.breakevens, hasLength(2));
      expect(r.breakevens.first, closeTo(24552, 1e-6));
      expect(r.breakevens.last, closeTo(25048, 1e-6));
    });

    test('a short straddle collects the premium and risks everything', () {
      final StrategyResult r = calcStrategy(<StrategyLeg>[
        leg(false, true, 24800, 128),
        leg(false, false, 24800, 120),
      ], 24800);

      expect(r.netPremium, closeTo(12400, 1e-9));
      expect(r.maxProfit, closeTo(12400, 1e-9));
      expect(r.maxLoss, double.infinity);
      // An unbounded loss has no meaningful reward-to-risk.
      expect(r.rewardToRisk, 0);
      // The larger short carries 15% of notional, the other 5%.
      expect(r.marginRequired, closeTo(1240000 * 0.15 + 1240000 * 0.05, 1e-6));
      expect(r.breakevens, hasLength(2));
      expect(r.breakevens.first, closeTo(24552, 1e-6));
    });

    test('a bull call spread is capped both ways', () {
      final StrategyResult r = calcStrategy(<StrategyLeg>[
        leg(true, true, 24800, 128),
        leg(false, true, 25000, 60),
      ], 24800);

      // Net debit of 68 a unit over a 200-point spread.
      expect(r.netPremium, closeTo(-3400, 1e-9));
      expect(r.maxLoss, closeTo(3400, 1e-9));
      expect(r.maxProfit, closeTo((200 - 68) * 50, 1e-9));
      expect(r.breakevens, hasLength(1));
      expect(r.breakevens.single, closeTo(24868, 1e-6));
      expect(r.rewardToRisk, closeTo(6600 / 3400, 1e-9));
      // Defined risk is charged its own worst case, not the naked block.
      expect(r.marginRequired, closeTo(3400, 1e-9));
    });

    test('no legs is all zeros but still draws a curve', () {
      final StrategyResult r = calcStrategy(const <StrategyLeg>[], 24800);

      expect(r.maxProfit, 0);
      expect(r.maxLoss, 0);
      expect(r.netPremium, 0);
      expect(r.marginRequired, 0);
      expect(r.breakevens, isEmpty);
      expect(r.payoffCurve, hasLength(21));
      expect(r.payoffCurve.first.price, closeTo(19840, 1e-9));
      expect(r.payoffCurve.last.price, closeTo(29760, 1e-9));
    });

    test('the payoff curve agrees with the maths at its own prices', () {
      final List<StrategyLeg> legs = <StrategyLeg>[
        leg(true, true, 24800, 128),
        leg(false, true, 25000, 60),
      ];
      final StrategyResult r = calcStrategy(legs, 24800);

      for (final ({double price, double pnl}) p in r.payoffCurve) {
        expect(p.pnl, greaterThanOrEqualTo(-r.maxLoss - 1e-6));
        expect(p.pnl, lessThanOrEqualTo(r.maxProfit + 1e-6));
      }
      // Below every strike the spread just loses the debit.
      expect(r.payoffCurve.first.pnl, closeTo(-3400, 1e-9));
    });
  });

  group('legsForTemplate', () {
    List<StrategyLeg> build(OptionStrategyTemplate t) =>
        legsForTemplate(t, spot: 24800, lotSize: 50);

    test('custom leaves whatever the user built alone', () {
      expect(build(OptionStrategyTemplate.custom), isEmpty);
      expect(
        legsForTemplate(
          OptionStrategyTemplate.longStraddle,
          spot: 0,
          lotSize: 50,
        ),
        isEmpty,
      );
    });

    test('a straddle is two same-strike legs, a strangle two apart', () {
      final List<StrategyLeg> straddle = build(
        OptionStrategyTemplate.longStraddle,
      );
      final List<StrategyLeg> strangle = build(
        OptionStrategyTemplate.longStrangle,
      );

      expect(straddle, hasLength(2));
      expect(straddle.every((StrategyLeg l) => l.isBuy), isTrue);
      expect(straddle.first.strike, straddle.last.strike);
      expect(straddle.map((StrategyLeg l) => l.isCall), <bool>[true, false]);

      expect(strangle, hasLength(2));
      expect(strangle.first.strike, isNot(strangle.last.strike));
      // The call sits above the put.
      expect(strangle.first.strike, greaterThan(strangle.last.strike));
    });

    test('legs are centred on the ATM strike for the listed step', () {
      final List<StrategyLeg> legs = legsForTemplate(
        OptionStrategyTemplate.bullCallSpread,
        spot: 24813,
        lotSize: 50,
      );

      expect(legs.first.strike, 24800);
      expect(legs.last.strike, 24900);
      expect(legs.first.isBuy, isTrue);
      expect(legs.last.isBuy, isFalse);
    });

    test('a butterfly doubles up on the body', () {
      final List<StrategyLeg> legs = build(
        OptionStrategyTemplate.longButterfly,
      );

      expect(legs, hasLength(3));
      final StrategyLeg body = legs.singleWhere(
        (StrategyLeg l) => !l.isBuy,
      );
      expect(body.lots, 2);
      expect(body.strike, 24800);
      expect(legs.first.strike, 24700);
      expect(legs.last.strike, 24900);
    });

    test('an iron condor is four legs, two of each side', () {
      final List<StrategyLeg> legs = build(OptionStrategyTemplate.ironCondor);

      expect(legs, hasLength(4));
      expect(legs.where((StrategyLeg l) => l.isBuy), hasLength(2));
      expect(legs.where((StrategyLeg l) => l.isCall), hasLength(2));
      // The bought wings are further out than the sold body.
      expect(legs.map((StrategyLeg l) => l.strike), <double>[
        24600,
        24700,
        24900,
        25000,
      ]);
    });

    test('the condor prices as a credit with defined risk', () {
      final StrategyResult r = calcStrategy(
        build(OptionStrategyTemplate.ironCondor),
        24800,
      );

      expect(r.netPremium, greaterThan(0));
      // Everything expires worthless between the short strikes.
      expect(r.maxProfit, closeTo(r.netPremium, 1e-6));
      // A 100-point wing on 50 units, less the credit taken in.
      expect(r.maxLoss, closeTo(100 * 50 - r.netPremium, 1e-6));
      expect(r.breakevens, hasLength(2));
      expect(r.rewardToRisk, closeTo(r.maxProfit / r.maxLoss, 1e-9));
    });

    test('the butterfly risks only its debit', () {
      final StrategyResult r = calcStrategy(
        build(OptionStrategyTemplate.longButterfly),
        24800,
      );

      expect(r.netPremium, lessThan(0));
      expect(r.maxLoss, closeTo(-r.netPremium, 1e-6));
      expect(r.maxProfit, greaterThan(0));
      expect(r.maxProfit.isFinite, isTrue);
      expect(r.breakevens, hasLength(2));
    });

    test('stock structures are shown as their exact synthetic', () {
      final List<StrategyLeg> covered = build(
        OptionStrategyTemplate.coveredCall,
      );
      final List<StrategyLeg> protective = build(
        OptionStrategyTemplate.protectivePut,
      );

      // Long stock + short ATM call == short ATM put.
      expect(covered.single.isBuy, isFalse);
      expect(covered.single.isCall, isFalse);
      // Long stock + long ATM put == long ATM call.
      expect(protective.single.isBuy, isTrue);
      expect(protective.single.isCall, isTrue);
      expect(OptionStrategyTemplate.coveredCall.syntheticNote, isNotNull);
      expect(OptionStrategyTemplate.protectivePut.syntheticNote, isNotNull);
      expect(OptionStrategyTemplate.longStraddle.syntheticNote, isNull);
    });

    test('every template has a label and a toggle group', () {
      for (final OptionStrategyTemplate t in OptionStrategyTemplate.values) {
        expect(t.label, isNotEmpty);
        expect(t.group, isIn(<String>[
          'All',
          'Straddle',
          'Strangle',
          'Spreads',
          'Condor',
          'Butterfly',
        ]));
      }
    });
  });

  group('strikeStepFor and premiumEstimate', () {
    test('the step widens with the underlying', () {
      expect(strikeStepFor(300), 5);
      expect(strikeStepFor(1500), 10);
      expect(strikeStepFor(24800), 50);
      expect(strikeStepFor(54000), 100);
    });

    test('an at-the-money premium is about 1.5% of spot', () {
      expect(
        premiumEstimate(strike: 24800, isCall: true, spot: 24800),
        closeTo(372, 0.05),
      );
    });

    test('a premium never prices below intrinsic', () {
      final double deepItm = premiumEstimate(
        strike: 20000,
        isCall: true,
        spot: 24800,
      );

      expect(deepItm, greaterThanOrEqualTo(4800));
      expect(deepItm, lessThan(4810));
    });

    test('equidistant calls and puts cost the same', () {
      expect(
        premiumEstimate(strike: 25000, isCall: true, spot: 24800),
        premiumEstimate(strike: 24600, isCall: false, spot: 24800),
      );
    });

    test('a further strike is cheaper, and no spot means no premium', () {
      expect(
        premiumEstimate(strike: 25200, isCall: true, spot: 24800),
        lessThan(premiumEstimate(strike: 25000, isCall: true, spot: 24800)),
      );
      expect(premiumEstimate(strike: 25000, isCall: true, spot: 0), 0);
    });
  });

  group('calcIvRank', () {
    test('rank is where IV sits in its 52-week range', () {
      final IvRankResult r = calcIvRank(
        currentIv: 18,
        low52w: 10,
        high52w: 30,
        daysAbove: 60,
        totalDays: 252,
      );

      expect(r.ivRank, closeTo(40, 1e-9));
      expect(r.ivPercentile, closeTo((252 - 60) / 252 * 100, 1e-9));
      expect(r.signal, 'neutral');
      expect(r.interpretation, isNotEmpty);
    });

    test('high IV says sell premium, low IV says buy it', () {
      final IvRankResult high = calcIvRank(
        currentIv: 25,
        low52w: 10,
        high52w: 30,
        daysAbove: 20,
        totalDays: 252,
      );
      final IvRankResult low = calcIvRank(
        currentIv: 14,
        low52w: 10,
        high52w: 30,
        daysAbove: 200,
        totalDays: 252,
      );

      expect(high.ivRank, closeTo(75, 1e-9));
      expect(high.signal, 'sell premium');
      expect(low.ivRank, closeTo(20, 1e-9));
      expect(low.signal, 'buy premium');
      expect(high.interpretation, isNot(low.interpretation));
    });

    test('a reading outside the range clamps to the ends', () {
      expect(
        calcIvRank(
          currentIv: 45,
          low52w: 10,
          high52w: 30,
          daysAbove: 0,
          totalDays: 252,
        ).ivRank,
        100,
      );
      expect(
        calcIvRank(
          currentIv: 5,
          low52w: 10,
          high52w: 30,
          daysAbove: 252,
          totalDays: 252,
        ).ivRank,
        0,
      );
    });

    test('swapped bounds are read the right way round', () {
      final IvRankResult r = calcIvRank(
        currentIv: 18,
        low52w: 30,
        high52w: 10,
        daysAbove: 60,
        totalDays: 252,
      );

      expect(r.ivRank, closeTo(40, 1e-9));
    });

    test('a flat range and an empty history do not divide by zero', () {
      final IvRankResult flat = calcIvRank(
        currentIv: 20,
        low52w: 20,
        high52w: 20,
        daysAbove: 0,
        totalDays: 0,
      );

      expect(flat.ivRank, 0);
      expect(flat.ivPercentile, 0);
    });
  });

  group('calcMaxPain', () {
    const List<({double strike, double callOi, double putOi})> chain =
        <({double strike, double callOi, double putOi})>[
          (strike: 24700, callOi: 2000, putOi: 0),
          (strike: 24800, callOi: 0, putOi: 0),
          (strike: 24900, callOi: 0, putOi: 1000),
        ];

    test('heavy call writing pins expiry to the lower strike', () {
      final MaxPainResult r = calcMaxPain(chain: chain, spot: 24800);

      expect(r.maxPainStrike, 24700);
      expect(r.painByStrike, hasLength(3));
      expect(r.painByStrike[0].totalPain, closeTo(200000, 1e-9));
      expect(r.painByStrike[1].totalPain, closeTo(300000, 1e-9));
      expect(r.painByStrike[2].totalPain, closeTo(400000, 1e-9));
      expect(r.distanceFromSpot, closeTo(-100, 1e-9));
      expect(r.distancePct, closeTo(-100 / 24800 * 100, 1e-9));
    });

    test('heavy put writing pins it to the higher strike', () {
      final MaxPainResult r = calcMaxPain(
        chain: const <({double strike, double callOi, double putOi})>[
          (strike: 24700, callOi: 1000, putOi: 0),
          (strike: 24900, callOi: 0, putOi: 2000),
        ],
        spot: 24800,
      );

      expect(r.maxPainStrike, 24900);
      expect(r.distanceFromSpot, closeTo(100, 1e-9));
    });

    test('rows arrive sorted however they were entered', () {
      final MaxPainResult r = calcMaxPain(
        chain: const <({double strike, double callOi, double putOi})>[
          (strike: 24900, callOi: 0, putOi: 1000),
          (strike: 24700, callOi: 2000, putOi: 0),
          (strike: 24800, callOi: 0, putOi: 0),
        ],
        spot: 24800,
      );

      expect(
        r.painByStrike.map((({double strike, double totalPain}) p) => p.strike),
        <double>[24700, 24800, 24900],
      );
      expect(r.maxPainStrike, 24700);
    });

    test('an empty chain has no strike to pin to', () {
      final MaxPainResult r = calcMaxPain(
        chain: const <({double strike, double callOi, double putOi})>[],
        spot: 24800,
      );

      expect(r.maxPainStrike, 0);
      expect(r.painByStrike, isEmpty);
      expect(r.distancePct, closeTo(-100, 1e-9));
    });

    test('a single strike is trivially its own max pain', () {
      final MaxPainResult r = calcMaxPain(
        chain: const <({double strike, double callOi, double putOi})>[
          (strike: 24800, callOi: 5000, putOi: 5000),
        ],
        spot: 24800,
      );

      expect(r.maxPainStrike, 24800);
      expect(r.painByStrike.single.totalPain, 0);
      expect(r.distanceFromSpot, 0);
    });
  });

  group('calcSpanMargin', () {
    test('an index short blocks a percentage of notional', () {
      final SpanResult r = calcSpanMargin(
        symbol: 'NIFTY',
        spotPrice: 24800,
        lotSize: 50,
        lots: 1,
        isHedged: false,
      );

      expect(r.marginPct, 12);
      expect(r.notional, 1240000);
      expect(r.nakedMargin, closeTo(148800, 1e-9));
      expect(r.hedgedMargin, closeTo(29760, 1e-9));
      expect(r.savedPct, closeTo(80, 1e-9));
      expect(r.nrmlMargin, closeTo(148800, 1e-9));
      expect(r.misMargin, closeTo(89280, 1e-9));
    });

    test('hedging the short releases most of the block', () {
      final SpanResult r = calcSpanMargin(
        symbol: 'NIFTY',
        spotPrice: 24800,
        lotSize: 50,
        lots: 1,
        isHedged: true,
      );

      expect(r.nrmlMargin, closeTo(29760, 1e-9));
      expect(r.misMargin, closeTo(17856, 1e-9));
      // The naked figure is still reported so the saving can be shown.
      expect(r.nakedMargin, closeTo(148800, 1e-9));
    });

    test('the symbol picks the default percentage', () {
      expect(autoMarginPctFor('NIFTY'), 12);
      expect(autoMarginPctFor('FINNIFTY'), 13);
      expect(autoMarginPctFor('BANKNIFTY'), 14);
      expect(autoMarginPctFor('SENSEX'), 12.5);
      // A single stock carries the fatter exposure leg.
      expect(autoMarginPctFor('RELIANCE'), 20);
      expect(autoMarginPctFor('  banknifty '), 14);
    });

    test('an explicit contract percentage wins', () {
      final SpanResult r = calcSpanMargin(
        symbol: 'NIFTY',
        spotPrice: 24800,
        lotSize: 50,
        lots: 1,
        isHedged: false,
        contractMarginPct: 15,
      );

      expect(r.marginPct, 15);
      expect(r.nakedMargin, closeTo(186000, 1e-9));
    });

    test('margin scales with lots', () {
      final SpanResult one = calcSpanMargin(
        symbol: 'BANKNIFTY',
        spotPrice: 52000,
        lotSize: 15,
        lots: 1,
        isHedged: false,
      );
      final SpanResult three = calcSpanMargin(
        symbol: 'BANKNIFTY',
        spotPrice: 52000,
        lotSize: 15,
        lots: 3,
        isHedged: false,
      );

      expect(three.nakedMargin, closeTo(one.nakedMargin * 3, 1e-9));
    });

    test('a nonsense price blocks nothing rather than going negative', () {
      final SpanResult r = calcSpanMargin(
        symbol: 'NIFTY',
        spotPrice: -100,
        lotSize: 50,
        lots: 1,
        isHedged: false,
      );

      expect(r.notional, 0);
      expect(r.nakedMargin, 0);
      expect(r.savedPct, 0);
    });
  });
}
