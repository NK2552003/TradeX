import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/calculators/logic/risk_calculators.dart';

void main() {
  group('calcDrawdown', () {
    test('a 20% drawdown needs a 25% gain to get back', () {
      final DrawdownResult r = calcDrawdown(
        peakValue: 1000000,
        troughValue: 800000,
        winRatePct: 50,
        avgRMultiple: 2,
        riskPerTradePct: 1,
      );

      expect(r.maxDrawdownPct, closeTo(20, 1e-9));
      expect(r.recoveryReturnNeeded, closeTo(25, 1e-9));
      expect(r.recoveryReturnNeeded, greaterThan(r.maxDrawdownPct));
      // 20 losses of 1% each.
      expect(r.consecutiveLossesNeeded, closeTo(20, 1e-9));
      // 25% to make back at 2% a win.
      expect(r.recoveryTradesNeeded, closeTo(12.5, 1e-9));
    });

    test('half the account gone needs a double to recover', () {
      final DrawdownResult r = calcDrawdown(
        peakValue: 1000000,
        troughValue: 500000,
        winRatePct: 55,
        avgRMultiple: 2,
        riskPerTradePct: 2,
      );

      expect(r.maxDrawdownPct, closeTo(50, 1e-9));
      expect(r.recoveryReturnNeeded, closeTo(100, 1e-9));
    });

    test('a positive edge makes ruin remote, a flat one makes it certain', () {
      final DrawdownResult edge = calcDrawdown(
        peakValue: 1000000,
        troughValue: 800000,
        winRatePct: 50,
        avgRMultiple: 2,
        riskPerTradePct: 1,
      );
      final DrawdownResult none = calcDrawdown(
        peakValue: 1000000,
        troughValue: 800000,
        winRatePct: 50,
        avgRMultiple: 1,
        riskPerTradePct: 1,
      );

      expect(edge.riskOfRuinPct, lessThan(0.001));
      expect(none.riskOfRuinPct, 100);
    });

    test('bigger bets reach the same drawdown in fewer losses', () {
      final DrawdownResult small = calcDrawdown(
        peakValue: 1000000,
        troughValue: 900000,
        winRatePct: 55,
        avgRMultiple: 1.5,
        riskPerTradePct: 1,
      );
      final DrawdownResult big = calcDrawdown(
        peakValue: 1000000,
        troughValue: 900000,
        winRatePct: 55,
        avgRMultiple: 1.5,
        riskPerTradePct: 4,
      );

      expect(small.consecutiveLossesNeeded, closeTo(10, 1e-9));
      expect(big.consecutiveLossesNeeded, closeTo(2.5, 1e-9));
      expect(big.riskOfRuinPct, greaterThan(small.riskOfRuinPct));
    });

    test('a wiped-out account can never be recovered', () {
      final DrawdownResult r = calcDrawdown(
        peakValue: 1000000,
        troughValue: 0,
        winRatePct: 55,
        avgRMultiple: 2,
        riskPerTradePct: 1,
      );

      expect(r.maxDrawdownPct, 100);
      expect(r.recoveryReturnNeeded, double.infinity);
      expect(r.recoveryTradesNeeded, 0);
    });

    test('no peak returns zeroes rather than NaN', () {
      final DrawdownResult r = calcDrawdown(
        peakValue: 0,
        troughValue: 0,
        winRatePct: 55,
        avgRMultiple: 2,
        riskPerTradePct: 1,
      );

      expect(r.maxDrawdownPct, 0);
      expect(r.recoveryReturnNeeded, 0);
      expect(r.consecutiveLossesNeeded, 0);
    });

    test('a gain above the peak is not a negative drawdown', () {
      final DrawdownResult r = calcDrawdown(
        peakValue: 1000000,
        troughValue: 1200000,
        winRatePct: 55,
        avgRMultiple: 2,
        riskPerTradePct: 1,
      );

      expect(r.maxDrawdownPct, 0);
    });
  });

  group('calcCompounding', () {
    test('5% a month for a year is a 79.6% return', () {
      final CompoundingResult r = calcCompounding(
        initialCapital: 100000,
        monthlyReturnPct: 5,
        months: 12,
      );

      expect(r.finalValue, closeTo(179585.63, 0.01));
      expect(r.totalReturn, closeTo(79.5856, 1e-3));
      expect(r.cagr, closeTo(79.5856, 1e-3));
      expect(r.monthlyValues, hasLength(12));
      expect(r.monthlyValues.first, closeTo(105000, 1e-9));
    });

    test('no withdrawal leaves the balance untouched', () {
      final CompoundingResult r = calcCompounding(
        initialCapital: 100000,
        monthlyReturnPct: 5,
        months: 12,
      );

      expect(r.withMonthlyWithdrawal, closeTo(r.finalValue, 1e-6));
    });

    test('a monthly withdrawal compounds against the growth', () {
      final CompoundingResult r = calcCompounding(
        initialCapital: 100000,
        monthlyReturnPct: 5,
        months: 12,
        monthlyWithdrawalPct: 2,
      );

      expect(r.withMonthlyWithdrawal, closeTo(140924, 5));
      expect(r.withMonthlyWithdrawal, lessThan(r.finalValue));
    });

    test('the monthly series rises with every month', () {
      final CompoundingResult r = calcCompounding(
        initialCapital: 50000,
        monthlyReturnPct: 3,
        months: 24,
      );

      expect(r.monthlyValues, hasLength(24));
      for (int i = 1; i < r.monthlyValues.length; i++) {
        expect(r.monthlyValues[i], greaterThan(r.monthlyValues[i - 1]));
      }
      expect(r.monthlyValues.last, closeTo(r.finalValue, 1e-9));
    });

    test('two years of compounding annualises below the total return', () {
      final CompoundingResult r = calcCompounding(
        initialCapital: 100000,
        monthlyReturnPct: 2,
        months: 24,
      );

      expect(r.cagr, lessThan(r.totalReturn));
      // 1.02^12 − 1.
      expect(r.cagr, closeTo(26.824, 1e-2));
    });

    test('zero months leaves the capital where it started', () {
      final CompoundingResult r = calcCompounding(
        initialCapital: 100000,
        monthlyReturnPct: 5,
        months: 0,
      );

      expect(r.finalValue, 100000);
      expect(r.totalReturn, 0);
      expect(r.cagr, 0);
      expect(r.monthlyValues, isEmpty);
    });

    test('a losing month compounds downward', () {
      final CompoundingResult r = calcCompounding(
        initialCapital: 100000,
        monthlyReturnPct: -5,
        months: 12,
      );

      expect(r.finalValue, lessThan(100000));
      expect(r.totalReturn, lessThan(0));
      expect(r.cagr, lessThan(0));
    });
  });
}
