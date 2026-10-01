import 'dart:math' as math;

/// Pure drawdown and compounding maths — the arithmetic of surviving a losing
/// streak and of what a win rate actually compounds to. No Flutter imports.

// ── Drawdown recovery ───────────────────────────────────────────────────────

class DrawdownResult {
  const DrawdownResult({
    required this.maxDrawdownPct,
    required this.recoveryReturnNeeded,
    required this.riskOfRuinPct,
    required this.consecutiveLossesNeeded,
    required this.recoveryTradesNeeded,
  });

  /// `(peak − trough) / peak × 100`.
  final double maxDrawdownPct;

  /// Gain on the *remaining* capital needed to get back to the peak. Always
  /// larger than [maxDrawdownPct] — a 50% loss needs a 100% gain.
  final double recoveryReturnNeeded;

  /// Chance of losing [maxDrawdownPct] of capital before doubling it.
  final double riskOfRuinPct;

  /// Losses in a row, at the given risk per trade, that produce this drawdown.
  final double consecutiveLossesNeeded;

  /// Winning trades at the given R multiple needed to climb back to the peak.
  final double recoveryTradesNeeded;
}

DrawdownResult calcDrawdown({
  required double peakValue,
  required double troughValue,
  required double winRatePct,
  required double avgRMultiple,
  required double riskPerTradePct,
}) {
  final double drawdownPct = peakValue <= 0
      ? 0
      : ((peakValue - troughValue) / peakValue * 100).clamp(0.0, 100.0);
  final double remaining = 100 - drawdownPct;
  final double recovery = remaining <= 0
      ? double.infinity
      : drawdownPct / remaining * 100;

  final double w = (winRatePct / 100).clamp(0.0, 1.0);
  final double edge = (w * (1 + avgRMultiple) - 1).clamp(-1.0, 1.0);
  final double units = riskPerTradePct <= 0
      ? 0
      : drawdownPct / riskPerTradePct;
  double ruin;
  if (edge <= 0) {
    ruin = 100;
  } else if (units <= 0) {
    ruin = 0;
  } else {
    ruin = math.pow((1 - edge) / (1 + edge), units).toDouble() * 100;
  }

  // Each win adds avgRMultiple × risk% of the *drawn-down* balance.
  final double gainPerWin = avgRMultiple * riskPerTradePct;
  return DrawdownResult(
    maxDrawdownPct: drawdownPct,
    recoveryReturnNeeded: recovery,
    riskOfRuinPct: ruin.clamp(0.0, 100.0),
    consecutiveLossesNeeded: riskPerTradePct <= 0 ? 0 : units,
    recoveryTradesNeeded: gainPerWin <= 0 || recovery.isInfinite
        ? 0
        : recovery / gainPerWin,
  );
}

// ── Compounding ─────────────────────────────────────────────────────────────

class CompoundingResult {
  const CompoundingResult({
    required this.finalValue,
    required this.totalReturn,
    required this.cagr,
    required this.monthlyValues,
    required this.withMonthlyWithdrawal,
  });

  /// Balance after [months] of compounding, before any withdrawal.
  final double finalValue;

  /// Total gain as a percentage of the starting capital.
  final double totalReturn;

  /// Annualised growth rate implied by [finalValue].
  final double cagr;

  /// End-of-month balance, index 0 = end of month 1. Drives the sparkline.
  final List<double> monthlyValues;

  /// Balance when a fixed percentage is withdrawn at the end of every month.
  final double withMonthlyWithdrawal;
}

/// What a steady monthly return compounds to — the number that makes "just 5% a
/// month" sound reasonable, and the reason it rarely holds.
CompoundingResult calcCompounding({
  required double initialCapital,
  required double monthlyReturnPct,
  required int months,
  double monthlyWithdrawalPct = 0,
}) {
  final double r = monthlyReturnPct / 100;
  final double wd = (monthlyWithdrawalPct / 100).clamp(0.0, 1.0);
  final int n = math.max(0, months);

  double balance = initialCapital;
  double withWithdrawal = initialCapital;
  final List<double> series = <double>[];
  for (int m = 1; m <= n; m++) {
    balance *= 1 + r;
    withWithdrawal = withWithdrawal * (1 + r) * (1 - wd);
    series.add(balance);
  }

  final double years = n / 12;
  final double cagr = initialCapital <= 0 || years <= 0 || balance <= 0
      ? 0
      : (math.pow(balance / initialCapital, 1 / years) - 1) * 100;

  return CompoundingResult(
    finalValue: balance,
    totalReturn: initialCapital <= 0
        ? 0
        : (balance - initialCapital) / initialCapital * 100,
    cagr: cagr,
    monthlyValues: series,
    withMonthlyWithdrawal: withWithdrawal,
  );
}
