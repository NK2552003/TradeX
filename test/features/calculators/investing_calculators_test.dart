import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/calculators/logic/investing_calculators.dart';

void main() {
  group('calcSip', () {
    test('a 12% SIP over 10 years roughly doubles the money invested', () {
      final SipResult r = calcSip(monthly: 25000, annualRatePct: 12, years: 10);

      expect(r.months, 120);
      expect(r.invested, 3000000);
      // Annuity-due at 1% a month: ₹58.08 lakh on ₹30 lakh invested.
      expect(r.futureValue, closeTo(5808477, 1000));
      expect(r.gain, closeTo(r.futureValue - r.invested, 1e-6));
      expect(r.growthPct, closeTo(r.gain / r.invested * 100, 1e-9));
    });

    test('a zero rate returns exactly what was paid in', () {
      final SipResult r = calcSip(monthly: 1000, annualRatePct: 0, years: 5);

      expect(r.futureValue, 60000);
      expect(r.gain, 0);
      expect(r.growthPct, 0);
    });

    test('the yearly series is monotonic and ends at the future value', () {
      final SipResult r = calcSip(monthly: 5000, annualRatePct: 10, years: 5);

      expect(r.yearlyValues, hasLength(5));
      for (int i = 1; i < r.yearlyValues.length; i++) {
        expect(r.yearlyValues[i], greaterThan(r.yearlyValues[i - 1]));
      }
      expect(r.yearlyValues.last, closeTo(r.futureValue, 1e-6));
    });
  });

  group('calcLumpsum', () {
    test('compounds annually', () {
      final GrowthResult r = calcLumpsum(
        principal: 100000,
        annualRatePct: 10,
        years: 3,
      );

      expect(r.futureValue, closeTo(133100, 1e-6));
      expect(r.gain, closeTo(33100, 1e-6));
      expect(r.growthPct, closeTo(33.1, 1e-9));
      expect(r.yearlyValues, hasLength(3));
      expect(r.yearlyValues.first, closeTo(110000, 1e-6));
    });

    test('a fractional tenure does not overshoot the final year', () {
      final GrowthResult r = calcLumpsum(
        principal: 100000,
        annualRatePct: 10,
        years: 2.5,
      );

      expect(r.yearlyValues, hasLength(3));
      expect(r.yearlyValues.last, closeTo(r.futureValue, 1e-6));
    });
  });

  group('calcFd', () {
    test('quarterly compounding beats the nominal rate', () {
      final FdResult r = calcFd(
        principal: 100000,
        annualRatePct: 8,
        months: 12,
      );

      expect(r.futureValue, closeTo(108243.216, 0.01));
      expect(r.effectiveYieldPct, closeTo(8.243216, 1e-5));
      expect(r.effectiveYieldPct, greaterThan(8));
    });

    test('annual compounding matches the nominal rate exactly', () {
      final FdResult r = calcFd(
        principal: 100000,
        annualRatePct: 8,
        months: 12,
        nPerYear: 1,
      );

      expect(r.futureValue, closeTo(108000, 1e-6));
      expect(r.effectiveYieldPct, closeTo(8, 1e-9));
    });

    test('more frequent compounding always yields more', () {
      double fvAt(int n) => calcFd(
        principal: 100000,
        annualRatePct: 8,
        months: 24,
        nPerYear: n,
      ).futureValue;

      expect(fvAt(4), greaterThan(fvAt(1)));
      expect(fvAt(12), greaterThan(fvAt(4)));
    });

    test('a nonsensical frequency falls back to annual instead of dividing '
        'by zero', () {
      final FdResult r = calcFd(
        principal: 100000,
        annualRatePct: 8,
        months: 12,
        nPerYear: 0,
      );

      expect(r.futureValue, closeTo(108000, 1e-6));
    });
  });

  group('calcCagr', () {
    test('doubling in 5 years is about 14.87% a year', () {
      final CagrResult r = calcCagr(
        initial: 100000,
        finalValue: 200000,
        years: 5,
      );

      expect(r.cagrPct, closeTo(14.8698, 1e-3));
      expect(r.absoluteReturnPct, closeTo(100, 1e-9));
      expect(r.gain, 100000);
      expect(r.doublingYears, closeTo(72 / r.cagrPct, 1e-9));
    });

    test('a loss produces a negative CAGR and no doubling time', () {
      final CagrResult r = calcCagr(
        initial: 200000,
        finalValue: 100000,
        years: 4,
      );

      expect(r.cagrPct, lessThan(0));
      expect(r.absoluteReturnPct, closeTo(-50, 1e-9));
      expect(r.doublingYears, double.infinity);
    });

    test('invalid inputs report zero rather than NaN', () {
      final CagrResult r = calcCagr(initial: 0, finalValue: 100, years: 5);

      expect(r.cagrPct, 0);
      expect(r.absoluteReturnPct, 0);
      expect(r.doublingYears, double.infinity);
    });
  });

  group('calcInflation', () {
    test('6% for 10 years nearly doubles the cost', () {
      final InflationResult r = calcInflation(
        amount: 100000,
        inflationPct: 6,
        years: 10,
      );

      expect(r.futureCost, closeTo(179084.77, 0.01));
      expect(r.presentValue, closeTo(55839.48, 0.01));
      expect(r.erosionPct, closeTo(44.16, 0.01));
      expect(r.yearlyCosts, hasLength(10));
      expect(r.yearlyCosts.last, closeTo(r.futureCost, 1e-6));
    });

    test('zero inflation leaves purchasing power intact', () {
      final InflationResult r = calcInflation(
        amount: 100000,
        inflationPct: 0,
        years: 10,
      );

      expect(r.futureCost, 100000);
      expect(r.presentValue, 100000);
      expect(r.erosionPct, 0);
    });
  });

  group('calcPpf', () {
    test('the full 15-year lock-in at 7.1% on ₹1.5 lakh a year', () {
      final PpfResult r = calcPpf(yearlyDeposit: 150000);

      expect(r.years, 15);
      expect(r.invested, 2250000);
      expect(r.futureValue, closeTo(4067284, 1000));
      expect(r.gain, closeTo(r.futureValue - r.invested, 1e-6));
      expect(r.yearlyValues, hasLength(15));
    });

    test('interest is credited after the deposit each year', () {
      final PpfResult r = calcPpf(
        yearlyDeposit: 100000,
        annualRatePct: 10,
        years: 1,
      );

      // One deposit, one credit: 100000 × 1.1.
      expect(r.futureValue, closeTo(110000, 1e-6));
    });

    test('an extended account keeps compounding', () {
      final PpfResult short = calcPpf(yearlyDeposit: 150000);
      final PpfResult long = calcPpf(yearlyDeposit: 150000, years: 25);

      expect(long.futureValue, greaterThan(short.futureValue));
      expect(long.yearlyValues, hasLength(25));
    });
  });

  group('calcEmi', () {
    test('a ₹25 lakh home loan at 8.75% over 20 years', () {
      final EmiResult r = calcEmi(
        principal: 2500000,
        annualRatePct: 8.75,
        years: 20,
      );

      expect(r.emi, closeTo(22093, 2));
      expect(r.totalPayment, closeTo(r.emi * 240, 1e-6));
      expect(r.totalInterest, closeTo(r.totalPayment - 2500000, 1e-6));
      expect(r.interestSharePct, greaterThan(40));
    });

    test('an interest-free loan just divides the principal', () {
      final EmiResult r = calcEmi(
        principal: 120000,
        annualRatePct: 0,
        years: 1,
      );

      expect(r.emi, closeTo(10000, 1e-9));
      expect(r.totalInterest, closeTo(0, 1e-9));
      expect(r.interestSharePct, closeTo(0, 1e-9));
    });

    test('the balance amortises to zero by the last instalment', () {
      final EmiResult r = calcEmi(
        principal: 500000,
        annualRatePct: 9,
        years: 5,
      );

      expect(r.yearlyBalances, hasLength(5));
      for (int i = 1; i < r.yearlyBalances.length; i++) {
        expect(r.yearlyBalances[i], lessThan(r.yearlyBalances[i - 1]));
      }
      expect(r.yearlyBalances.last, closeTo(0, 1));
    });

    test('a nonsensical loan returns zeroes instead of NaN', () {
      final EmiResult r = calcEmi(principal: 0, annualRatePct: 9, years: 5);

      expect(r.emi, 0);
      expect(r.totalPayment, 0);
      expect(r.yearlyBalances, isEmpty);
    });
  });

  group('calcStepUpSip', () {
    test('a flat step-up is exactly an ordinary SIP', () {
      final StepUpSipResult r = calcStepUpSip(
        initialMonthly: 10000,
        annualStepUpPct: 0,
        annualRate: 12,
        years: 10,
      );
      final SipResult flat = calcSip(
        monthly: 10000,
        annualRatePct: 12,
        years: 10,
      );

      expect(r.invested, closeTo(1200000, 1e-6));
      expect(r.futureValue, closeTo(flat.futureValue, 0.01));
      expect(r.flatValue, closeTo(flat.futureValue, 1e-9));
      expect(r.vsFlat, closeTo(0, 0.01));
      expect(r.finalMonthly, 10000);
    });

    test('a 10% step-up raises the instalment once a year', () {
      final StepUpSipResult r = calcStepUpSip(
        initialMonthly: 10000,
        annualStepUpPct: 10,
        annualRate: 12,
        years: 10,
      );

      // The tenth year is paid at 10,000 × 1.1⁹.
      expect(r.finalMonthly, closeTo(23579.48, 0.01));
      // 12 × 10,000 × (1.1¹⁰ − 1) / 0.1.
      expect(r.invested, closeTo(1912490.95, 0.01));
      expect(r.futureValue, greaterThan(r.flatValue));
      expect(r.vsFlat, closeTo(r.futureValue - r.flatValue, 1e-9));
      expect(r.gain, closeTo(r.futureValue - r.invested, 1e-6));
    });

    test('the yearly series has one entry a year and only rises', () {
      final StepUpSipResult r = calcStepUpSip(
        initialMonthly: 5000,
        annualStepUpPct: 15,
        annualRate: 10,
        years: 7,
      );

      expect(r.yearlyValues, hasLength(7));
      for (int i = 1; i < r.yearlyValues.length; i++) {
        expect(r.yearlyValues[i], greaterThan(r.yearlyValues[i - 1]));
      }
      expect(r.yearlyValues.last, closeTo(r.futureValue, 1e-9));
    });

    test('a bigger step-up always ends further ahead', () {
      double endAt(double stepUp) => calcStepUpSip(
        initialMonthly: 10000,
        annualStepUpPct: stepUp,
        annualRate: 12,
        years: 15,
      ).futureValue;

      expect(endAt(5), greaterThan(endAt(0)));
      expect(endAt(10), greaterThan(endAt(5)));
      expect(endAt(25), greaterThan(endAt(10)));
    });

    test('no years means nothing invested', () {
      final StepUpSipResult r = calcStepUpSip(
        initialMonthly: 10000,
        annualStepUpPct: 10,
        annualRate: 12,
        years: 0,
      );

      expect(r.invested, 0);
      expect(r.futureValue, 0);
      expect(r.growthPct, 0);
      expect(r.yearlyValues, isEmpty);
    });
  });

  group('calcXirr', () {
    test('a single year at a flat 10% solves exactly', () {
      final XirrResult r = calcXirr(
        cashFlows: <({DateTime date, double amount})>[
          (date: DateTime(2023), amount: -100000),
          (date: DateTime(2024), amount: 110000),
        ],
      );

      expect(r.converged, isTrue);
      expect(r.xirrPct, closeTo(10, 1e-4));
      expect(r.totalInvested, 100000);
      expect(r.currentValue, 110000);
      expect(r.absoluteReturn, closeTo(10, 1e-9));
      expect(r.years, closeTo(1, 1e-9));
    });

    test('a doubling in a year is 100%, a loss is negative', () {
      final XirrResult doubled = calcXirr(
        cashFlows: <({DateTime date, double amount})>[
          (date: DateTime(2023), amount: -50000),
          (date: DateTime(2024), amount: 100000),
        ],
      );
      final XirrResult lost = calcXirr(
        cashFlows: <({DateTime date, double amount})>[
          (date: DateTime(2023), amount: -100000),
          (date: DateTime(2024), amount: 90000),
        ],
      );

      expect(doubled.xirrPct, closeTo(100, 1e-3));
      expect(lost.xirrPct, closeTo(-10, 1e-3));
      expect(lost.absoluteReturn, closeTo(-10, 1e-9));
    });

    test('the solved rate discounts a monthly SIP back to zero', () {
      final List<({DateTime date, double amount})> flows =
          <({DateTime date, double amount})>[
            for (int m = 1; m <= 12; m++)
              (date: DateTime(2024, m), amount: -10000),
            (date: DateTime(2025), amount: 130000),
          ];
      final XirrResult r = calcXirr(cashFlows: flows);

      expect(r.converged, isTrue);
      expect(r.totalInvested, 120000);
      expect(r.currentValue, 130000);

      // Recompute the NPV independently at the rate it found.
      final DateTime start = flows.first.date;
      double npv = 0;
      for (final ({DateTime date, double amount}) f in flows) {
        final double t = f.date.difference(start).inDays / 365;
        npv += f.amount / math.pow(1 + r.xirrPct / 100, t);
      }
      expect(npv, closeTo(0, 0.01));
      // Money that was only in for part of the year annualises above 8.3%.
      expect(r.xirrPct, greaterThan(r.absoluteReturn));
    });

    test('half a year at 10% absolute annualises to about 21%', () {
      final XirrResult r = calcXirr(
        cashFlows: <({DateTime date, double amount})>[
          (date: DateTime(2023), amount: -100000),
          (date: DateTime(2023, 7, 2), amount: 110000),
        ],
      );

      // 1.1² − 1 on a 182-day holding.
      expect(r.years, closeTo(182 / 365, 1e-9));
      expect(r.xirrPct, closeTo(21.06, 0.2));
    });

    test('the order the rows were typed in does not matter', () {
      final XirrResult forward = calcXirr(
        cashFlows: <({DateTime date, double amount})>[
          (date: DateTime(2023), amount: -100000),
          (date: DateTime(2024), amount: 110000),
        ],
      );
      final XirrResult backward = calcXirr(
        cashFlows: <({DateTime date, double amount})>[
          (date: DateTime(2024), amount: 110000),
          (date: DateTime(2023), amount: -100000),
        ],
      );

      expect(backward.xirrPct, closeTo(forward.xirrPct, 1e-12));
    });

    test('flows that cannot describe a return report no convergence', () {
      final XirrResult outOnly = calcXirr(
        cashFlows: <({DateTime date, double amount})>[
          (date: DateTime(2023), amount: -100000),
          (date: DateTime(2024), amount: -50000),
        ],
      );
      final XirrResult one = calcXirr(
        cashFlows: <({DateTime date, double amount})>[
          (date: DateTime(2023), amount: -100000),
        ],
      );
      final XirrResult sameDay = calcXirr(
        cashFlows: <({DateTime date, double amount})>[
          (date: DateTime(2023), amount: -100000),
          (date: DateTime(2023), amount: 110000),
        ],
      );
      final XirrResult none = calcXirr(
        cashFlows: const <({DateTime date, double amount})>[],
      );

      for (final XirrResult r in <XirrResult>[outOnly, one, sameDay, none]) {
        expect(r.converged, isFalse);
        expect(r.xirrPct, 0);
      }
      // The totals are still worth showing even when the rate is not.
      expect(outOnly.totalInvested, 150000);
      expect(sameDay.currentValue, 110000);
    });

    test('a longer hold at the same multiple annualises lower', () {
      final XirrResult oneYear = calcXirr(
        cashFlows: <({DateTime date, double amount})>[
          (date: DateTime(2020), amount: -100000),
          (date: DateTime(2021), amount: 200000),
        ],
      );
      final XirrResult fiveYears = calcXirr(
        cashFlows: <({DateTime date, double amount})>[
          (date: DateTime(2020), amount: -100000),
          (date: DateTime(2025), amount: 200000),
        ],
      );

      expect(fiveYears.xirrPct, lessThan(oneYear.xirrPct));
      expect(fiveYears.absoluteReturn, closeTo(oneYear.absoluteReturn, 1e-9));
      // 2^(1/5) − 1, spread over five calendar years.
      expect(fiveYears.xirrPct, closeTo(14.83, 0.1));
    });
  });

  group('calcBondYtm', () {
    test('a bond at par yields its coupon', () {
      final BondResult r = calcBondYtm(
        faceValue: 1000,
        couponRate: 8,
        cleanPrice: 1000,
        yearsToMaturity: 5,
      );

      expect(r.ytm, closeTo(8, 1e-6));
      expect(r.currentYield, closeTo(8, 1e-9));
      expect(r.couponPerPeriod, 40);
      expect(r.totalCoupons, 10);
      expect(r.dirtyPrice, 1000);
    });

    test('a discount bond yields more than its coupon', () {
      final BondResult r = calcBondYtm(
        faceValue: 1000,
        couponRate: 8,
        cleanPrice: 900,
        yearsToMaturity: 5,
      );

      expect(r.ytm, closeTo(10.63, 0.05));
      expect(r.ytm, greaterThan(8));
      expect(r.currentYield, closeTo(80 / 900 * 100, 1e-9));
    });

    test('a premium bond yields less than its coupon', () {
      final BondResult r = calcBondYtm(
        faceValue: 1000,
        couponRate: 8,
        cleanPrice: 1100,
        yearsToMaturity: 5,
      );

      expect(r.ytm, lessThan(8));
      expect(r.currentYield, closeTo(80 / 1100 * 100, 1e-9));
    });

    test('a zero-coupon bond has a duration equal to its maturity', () {
      final BondResult r = calcBondYtm(
        faceValue: 1000,
        couponRate: 0,
        cleanPrice: 675.5642,
        yearsToMaturity: 5,
      );

      expect(r.ytm, closeTo(8, 0.01));
      expect(r.currentYield, 0);
      expect(r.duration, closeTo(5, 1e-9));
      // Modified duration discounts by one period of yield.
      expect(r.modifiedDuration, closeTo(5 / 1.04, 1e-3));
    });

    test('coupons pull the duration in below maturity', () {
      final BondResult r = calcBondYtm(
        faceValue: 1000,
        couponRate: 8,
        cleanPrice: 1000,
        yearsToMaturity: 5,
      );

      expect(r.duration, lessThan(5));
      expect(r.duration, closeTo(4.218, 0.01));
      expect(r.modifiedDuration, lessThan(r.duration));
    });

    test('accrued interest is added on top of the clean price', () {
      final BondResult r = calcBondYtm(
        faceValue: 1000,
        couponRate: 8,
        cleanPrice: 1000,
        yearsToMaturity: 5,
        accruedFraction: 0.5,
      );

      expect(r.dirtyPrice, closeTo(1020, 1e-9));
      // The yield is quoted off the clean price regardless.
      expect(r.ytm, closeTo(8, 1e-6));
    });

    test('an annual coupon prices differently from a semi-annual one', () {
      final BondResult annual = calcBondYtm(
        faceValue: 1000,
        couponRate: 8,
        cleanPrice: 900,
        yearsToMaturity: 5,
        couponFrequency: 1,
      );
      final BondResult semi = calcBondYtm(
        faceValue: 1000,
        couponRate: 8,
        cleanPrice: 900,
        yearsToMaturity: 5,
      );

      expect(annual.couponPerPeriod, 80);
      expect(annual.totalCoupons, 5);
      // Waiting a full year for each coupon costs a little yield.
      expect(annual.ytm, greaterThan(semi.ytm));
      expect(annual.duration, greaterThan(semi.duration));
    });

    test('a worthless quote does not divide by zero', () {
      final BondResult r = calcBondYtm(
        faceValue: 1000,
        couponRate: 8,
        cleanPrice: 0,
        yearsToMaturity: 5,
      );

      expect(r.ytm, 0);
      expect(r.currentYield, 0);
    });
  });

  group('calcGraham', () {
    test('the Graham number is the root of 22.5 × EPS × BVPS', () {
      final GrahamResult r = calcGraham(
        eps: 50,
        bvps: 200,
        currentPrice: 500,
        epsGrowthRate: 10,
      );

      expect(r.grahamNumber, closeTo(474.342, 1e-3));
      // 50 × (8.5 + 2 × 10) × 4.4 / 7.5.
      expect(r.intrinsicValue, closeTo(836, 1e-9));
      expect(r.marginOfSafety, closeTo(336 / 836 * 100, 1e-9));
      expect(r.verdict, 'undervalued');
      expect(r.upsidePct, closeTo(67.2, 1e-9));
      expect(r.buyBelow, closeTo(585.2, 1e-9));
    });

    test('a thin discount is fair, a premium is overvalued', () {
      GrahamResult at(double price) => calcGraham(
        eps: 50,
        bvps: 200,
        currentPrice: price,
        epsGrowthRate: 10,
      );

      expect(at(800).verdict, 'fairly valued');
      expect(at(800).marginOfSafety, closeTo(36 / 836 * 100, 1e-9));
      expect(at(900).verdict, 'overvalued');
      expect(at(900).marginOfSafety, lessThan(0));
      expect(at(900).upsidePct, lessThan(0));
    });

    test('a loss-making company has no valuation', () {
      final GrahamResult r = calcGraham(
        eps: -10,
        bvps: 200,
        currentPrice: 500,
      );

      expect(r.grahamNumber, 0);
      expect(r.intrinsicValue, 0);
      expect(r.marginOfSafety, 0);
      expect(r.verdict, 'overvalued');
      expect(r.buyBelow, 0);
    });

    test('a negative book value voids the Graham number only', () {
      final GrahamResult r = calcGraham(
        eps: 50,
        bvps: -20,
        currentPrice: 100,
      );

      expect(r.grahamNumber, 0);
      expect(r.intrinsicValue, greaterThan(0));
    });

    test('growth raises the intrinsic value, a higher AAA yield lowers it', () {
      double intrinsic({double g = 0, double y = 7.5}) => calcGraham(
        eps: 50,
        bvps: 200,
        currentPrice: 500,
        epsGrowthRate: g,
        aaaYield: y,
      ).intrinsicValue;

      // No growth: 50 × 8.5 × 4.4 / 7.5.
      expect(intrinsic(), closeTo(249.333, 1e-3));
      expect(intrinsic(g: 15), greaterThan(intrinsic(g: 5)));
      expect(intrinsic(y: 10), lessThan(intrinsic()));
      // A nonsense yield falls back to 7.5%.
      expect(intrinsic(y: 0), closeTo(intrinsic(), 1e-9));
    });
  });
}
