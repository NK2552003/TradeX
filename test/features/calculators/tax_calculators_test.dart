import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/calculators/logic/tax_calculators.dart';

void main() {
  group('calcStcg', () {
    test('15% plus 4% cess on the whole gain', () {
      final StcgResult r = calcStcg(gain: 100000);

      expect(r.taxableGain, 100000);
      expect(r.tax, closeTo(15000, 1e-9));
      expect(r.cess, closeTo(600, 1e-9));
      expect(r.totalTax, closeTo(15600, 1e-9));
      expect(r.netGain, closeTo(84400, 1e-9));
      expect(r.effectiveRatePct, closeTo(15.6, 1e-9));
    });

    test('there is no exemption slab', () {
      final StcgResult r = calcStcg(gain: 5000);

      expect(r.taxableGain, 5000);
      expect(r.totalTax, closeTo(780, 1e-9));
    });

    test('a loss is untaxed and left intact for carry-forward', () {
      final StcgResult r = calcStcg(gain: -50000);

      expect(r.taxableGain, 0);
      expect(r.tax, 0);
      expect(r.totalTax, 0);
      expect(r.netGain, -50000);
      expect(r.effectiveRatePct, 0);
    });
  });

  group('calcLtcg', () {
    test('gains inside the ₹1 lakh exemption are tax free', () {
      final LtcgResult r = calcLtcg(gain: 80000);

      expect(r.exemptionUsed, 80000);
      expect(r.taxableGain, 0);
      expect(r.totalTax, 0);
      expect(r.netGain, 80000);
    });

    test('only the gain above the exemption is taxed', () {
      final LtcgResult r = calcLtcg(gain: 350000);

      expect(r.exemptionUsed, kLtcgExemption);
      expect(r.taxableGain, 250000);
      expect(r.tax, closeTo(25000, 1e-9));
      expect(r.cess, closeTo(1000, 1e-9));
      expect(r.totalTax, closeTo(26000, 1e-9));
      expect(r.netGain, closeTo(324000, 1e-9));
      expect(r.effectiveRatePct, lessThan(kLtcgRate));
    });

    test('an exemption spent earlier in the year is not available again', () {
      final LtcgResult r = calcLtcg(gain: 150000, exemptionAlreadyUsed: 100000);

      expect(r.exemptionUsed, 0);
      expect(r.taxableGain, 150000);
      expect(r.totalTax, closeTo(15600, 1e-9));
    });

    test('a partly used exemption leaves the remainder', () {
      final LtcgResult r = calcLtcg(gain: 150000, exemptionAlreadyUsed: 40000);

      expect(r.exemptionUsed, 60000);
      expect(r.taxableGain, 90000);
      expect(r.tax, closeTo(9000, 1e-9));
    });

    test('over-reporting prior use cannot create a negative exemption', () {
      final LtcgResult r = calcLtcg(gain: 50000, exemptionAlreadyUsed: 500000);

      expect(r.exemptionUsed, 0);
      expect(r.taxableGain, 50000);
    });

    test('a loss is untaxed', () {
      final LtcgResult r = calcLtcg(gain: -20000);

      expect(r.taxableGain, 0);
      expect(r.totalTax, 0);
      expect(r.netGain, -20000);
    });
  });

  group('calcTurnover', () {
    test('turnover is the absolute sum of wins and losses', () {
      final TurnoverResult r = calcTurnover(profitSum: 850000, lossSum: 420000);

      expect(r.turnover, 1270000);
      expect(r.netPnl, 430000);
      expect(r.presumptiveIncome, closeTo(76200, 1e-9));
      expect(r.auditRequired, isFalse);
    });

    test('a loss sign is ignored', () {
      final TurnoverResult signed = calcTurnover(
        profitSum: 100000,
        lossSum: -60000,
      );
      final TurnoverResult unsigned = calcTurnover(
        profitSum: 100000,
        lossSum: 60000,
      );

      expect(signed.turnover, unsigned.turnover);
      expect(signed.netPnl, unsigned.netPnl);
    });

    test('profit below the 6% presumptive figure triggers an audit', () {
      final TurnoverResult r = calcTurnover(
        profitSum: 1000000,
        lossSum: 980000,
      );

      expect(r.netPnl, 20000);
      expect(r.presumptiveIncome, closeTo(118800, 1e-9));
      expect(r.auditRequired, isTrue);
    });

    test('crossing the threshold triggers an audit even on a fat profit', () {
      final TurnoverResult r = calcTurnover(
        profitSum: 150000000,
        lossSum: 0,
      );

      expect(r.turnover, greaterThan(r.threshold));
      expect(r.auditRequired, isTrue);
    });

    test('the lower ₹1 crore threshold can be selected', () {
      final TurnoverResult r = calcTurnover(
        profitSum: 20000000,
        lossSum: 0,
        threshold: 10000000,
      );

      expect(r.threshold, 10000000);
      expect(r.auditRequired, isTrue);
    });

    test('the statutory rates are the FY 2025-26 ones', () {
      expect(kStcgRate, 15.0);
      expect(kLtcgRate, 10.0);
      expect(kLtcgExemption, 100000.0);
      expect(kCessRate, 4.0);
    });
  });

  group('slab tax', () {
    test('the old regime steps at 2.5L, 5L and 10L', () {
      expect(slabTaxOld(250000), 0);
      expect(slabTaxOld(400000), 7500);
      expect(slabTaxOld(500000), 12500);
      expect(slabTaxOld(1000000), 112500);
      expect(slabTaxOld(1500000), 262500);
    });

    test('the new regime steps in 4L bands', () {
      expect(slabTaxNew(400000), 0);
      expect(slabTaxNew(800000), 20000);
      expect(slabTaxNew(1200000), 60000);
      expect(slabTaxNew(1300000), 75000);
      expect(slabTaxNew(2400000), 300000);
      expect(slabTaxNew(3000000), 480000);
    });

    test('the 87A rebate wipes out tax at the threshold', () {
      expect(rebate87a(1200000, 60000, isNewRegime: true), 60000);
      expect(rebate87a(1200001, 60000, isNewRegime: true), 0);
      expect(rebate87a(500000, 12500, isNewRegime: false), 12500);
      expect(rebate87a(500001, 32500, isNewRegime: false), 0);
      // The rebate never exceeds the tax it is offsetting.
      expect(rebate87a(300000, 2500, isNewRegime: true), 2500);
    });

    test('slab tax is net of the rebate', () {
      expect(slabTax(1200000, isNewRegime: true), 0);
      expect(slabTax(1300000, isNewRegime: true), 75000);
      expect(slabTax(500000, isNewRegime: false), 0);
      expect(slabTax(600000, isNewRegime: false), 32500);
    });

    test('the new regime is lighter than the old at a trader income', () {
      expect(
        slabTax(1500000, isNewRegime: true),
        lessThan(slabTax(1500000, isNewRegime: false)),
      );
    });
  });

  group('surchargeRateFor', () {
    test('the bands start above ₹50 lakh', () {
      expect(surchargeRateFor(5000000, isNewRegime: false), 0);
      expect(surchargeRateFor(5000001, isNewRegime: false), 10);
      expect(surchargeRateFor(10000000, isNewRegime: false), 10);
      expect(surchargeRateFor(10000001, isNewRegime: false), 15);
      expect(surchargeRateFor(20000000, isNewRegime: false), 15);
      expect(surchargeRateFor(20000001, isNewRegime: false), 25);
      expect(surchargeRateFor(50000000, isNewRegime: false), 25);
    });

    test('the new regime drops the 37% band', () {
      expect(surchargeRateFor(60000000, isNewRegime: false), 37);
      expect(surchargeRateFor(60000000, isNewRegime: true), 25);
    });
  });

  group('calcSurcharge', () {
    test('below ₹50 lakh there is only slab tax and cess', () {
      final SurchargeResult r = calcSurcharge(
        totalIncome: 4000000,
        isNewRegime: false,
      );

      expect(r.basicTax, closeTo(1012500, 1e-9));
      expect(r.surchargePct, 0);
      expect(r.surchargeAmount, 0);
      expect(r.healthEduCess, closeTo(40500, 1e-9));
      expect(r.totalTax, closeTo(1053000, 1e-9));
      expect(r.effectiveRatePct, closeTo(26.325, 1e-9));
      expect(r.marginalReliefApplied, 0);
    });

    test('₹60 lakh carries a 10% surcharge with no relief due', () {
      final SurchargeResult r = calcSurcharge(
        totalIncome: 6000000,
        isNewRegime: false,
      );

      expect(r.basicTax, closeTo(1612500, 1e-9));
      expect(r.surchargePct, 10);
      expect(r.surchargeAmount, closeTo(161250, 1e-9));
      expect(r.marginalReliefApplied, 0);
      expect(r.healthEduCess, closeTo(70950, 1e-9));
      expect(r.totalTax, closeTo(1844700, 1e-9));
    });

    test('marginal relief caps the tax on the first rupee over ₹50 lakh', () {
      final SurchargeResult r = calcSurcharge(
        totalIncome: 5010000,
        isNewRegime: false,
      );

      expect(r.surchargePct, 10);
      // 10% of ₹13.155 lakh would be ₹1,31,550 — relief leaves ₹7,000.
      expect(r.marginalReliefApplied, closeTo(124550, 1e-9));
      expect(r.surchargeAmount, closeTo(7000, 1e-9));
      // Tax before cess rises by exactly the ₹10,000 of extra income.
      final SurchargeResult at50L = calcSurcharge(
        totalIncome: 5000000,
        isNewRegime: false,
      );
      expect(
        r.basicTax + r.surchargeAmount - at50L.basicTax,
        closeTo(10000, 1e-6),
      );
    });

    test('relief shrinks as income moves away from the threshold', () {
      double reliefAt(double income) => calcSurcharge(
        totalIncome: income,
        isNewRegime: false,
      ).marginalReliefApplied;

      expect(reliefAt(5010000), greaterThan(reliefAt(5100000)));
      expect(reliefAt(5100000), greaterThan(reliefAt(5300000)));
      expect(reliefAt(6000000), 0);
    });

    test('the 87A rebate leaves ₹12 lakh untaxed in the new regime', () {
      final SurchargeResult free = calcSurcharge(
        totalIncome: 1200000,
        isNewRegime: true,
      );
      final SurchargeResult above = calcSurcharge(
        totalIncome: 1300000,
        isNewRegime: true,
      );

      expect(free.totalTax, 0);
      expect(free.effectiveRatePct, 0);
      expect(above.basicTax, closeTo(75000, 1e-9));
      expect(above.totalTax, closeTo(78000, 1e-9));
      expect(above.effectiveRatePct, closeTo(6, 1e-9));
    });

    test('the new regime is cheaper at ₹6 crore', () {
      final SurchargeResult oldR = calcSurcharge(
        totalIncome: 60000000,
        isNewRegime: false,
      );
      final SurchargeResult newR = calcSurcharge(
        totalIncome: 60000000,
        isNewRegime: true,
      );

      expect(oldR.surchargePct, 37);
      expect(newR.surchargePct, 25);
      expect(newR.totalTax, lessThan(oldR.totalTax));
    });

    test('a negative income is not a refund', () {
      final SurchargeResult r = calcSurcharge(
        totalIncome: -500000,
        isNewRegime: true,
      );

      expect(r.basicTax, 0);
      expect(r.totalTax, 0);
      expect(r.effectiveRatePct, 0);
    });
  });

  // ADVANCE_TAX_ANCHOR
}
