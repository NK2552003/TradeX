import 'dart:math' as math;

/// Pure investing maths — compounding, annuities and amortisation.
/// No Flutter imports.

/// Shared shape for every "grows over time" calculator so the screens can
/// render one result layout.
class GrowthResult {
  const GrowthResult({
    required this.invested,
    required this.futureValue,
    required this.gain,
    required this.growthPct,
    required this.yearlyValues,
  });

  final double invested;
  final double futureValue;
  final double gain;

  /// Gain as a percentage of [invested].
  final double growthPct;

  /// End-of-year corpus, index 0 = end of year 1. Drives the sparkline.
  final List<double> yearlyValues;
}

// ── SIP ─────────────────────────────────────────────────────────────────────

class SipResult extends GrowthResult {
  const SipResult({
    required super.invested,
    required super.futureValue,
    required super.gain,
    required super.growthPct,
    required super.yearlyValues,
    required this.monthly,
    required this.months,
  });

  final double monthly;
  final int months;
}

/// Future value of a monthly SIP: `P × ((1+i)^n − 1) / i × (1+i)`,
/// contributions made at the start of each month.
SipResult calcSip({
  required double monthly,
  required double annualRatePct,
  required double years,
}) {
  final int months = (years * 12).round();
  final double i = annualRatePct / 100 / 12;
  double fv(int n) {
    if (n <= 0) return 0;
    if (i == 0) return monthly * n;
    return monthly * ((math.pow(1 + i, n) - 1) / i) * (1 + i);
  }

  final double futureValue = fv(months);
  final double invested = monthly * months;
  return SipResult(
    invested: invested,
    futureValue: futureValue,
    gain: futureValue - invested,
    growthPct: invested <= 0 ? 0 : (futureValue - invested) / invested * 100,
    yearlyValues: <double>[
      for (int y = 1; y <= years.ceil(); y++) fv(math.min(y * 12, months)),
    ],
    monthly: monthly,
    months: months,
  );
}

// ── Lumpsum ─────────────────────────────────────────────────────────────────

GrowthResult calcLumpsum({
  required double principal,
  required double annualRatePct,
  required double years,
}) {
  final double r = annualRatePct / 100;
  double fv(double y) => principal * math.pow(1 + r, y);
  final double futureValue = fv(years);
  return GrowthResult(
    invested: principal,
    futureValue: futureValue,
    gain: futureValue - principal,
    growthPct: principal <= 0 ? 0 : (futureValue - principal) / principal * 100,
    yearlyValues: <double>[
      for (int y = 1; y <= years.ceil(); y++)
        fv(y > years ? years : y.toDouble()),
    ],
  );
}

// ── Fixed deposit ───────────────────────────────────────────────────────────

class FdResult extends GrowthResult {
  const FdResult({
    required super.invested,
    required super.futureValue,
    required super.gain,
    required super.growthPct,
    required super.yearlyValues,
    required this.effectiveYieldPct,
  });

  /// Annual yield once compounding is taken into account.
  final double effectiveYieldPct;
}

/// Maturity value with [nPerYear] compounding periods (4 = quarterly, the
/// Indian bank default).
FdResult calcFd({
  required double principal,
  required double annualRatePct,
  required double months,
  int nPerYear = 4,
}) {
  final double r = annualRatePct / 100;
  final int n = nPerYear <= 0 ? 1 : nPerYear;
  double fv(double m) => principal * math.pow(1 + r / n, n * m / 12);
  final double futureValue = fv(months);
  final double years = months / 12;
  return FdResult(
    invested: principal,
    futureValue: futureValue,
    gain: futureValue - principal,
    growthPct: principal <= 0 ? 0 : (futureValue - principal) / principal * 100,
    yearlyValues: <double>[
      for (int y = 1; y <= years.ceil(); y++)
        fv(math.min(y * 12, months).toDouble()),
    ],
    effectiveYieldPct: (math.pow(1 + r / n, n) - 1) * 100,
  );
}

// ── CAGR ────────────────────────────────────────────────────────────────────

class CagrResult {
  const CagrResult({
    required this.cagrPct,
    required this.absoluteReturnPct,
    required this.gain,
    required this.doublingYears,
  });

  final double cagrPct;
  final double absoluteReturnPct;
  final double gain;

  /// Years to double at this rate. `double.infinity` if the rate is ≤ 0.
  final double doublingYears;
}

CagrResult calcCagr({
  required double initial,
  required double finalValue,
  required double years,
}) {
  final bool valid = initial > 0 && years > 0 && finalValue > 0;
  final double cagr = valid
      ? (math.pow(finalValue / initial, 1 / years) - 1) * 100
      : 0;
  return CagrResult(
    cagrPct: cagr,
    absoluteReturnPct: initial <= 0
        ? 0
        : (finalValue - initial) / initial * 100,
    gain: finalValue - initial,
    doublingYears: cagr <= 0 ? double.infinity : 72 / cagr,
  );
}

// ── Inflation ───────────────────────────────────────────────────────────────

class InflationResult {
  const InflationResult({
    required this.futureCost,
    required this.presentValue,
    required this.erosionPct,
    required this.yearlyCosts,
  });

  /// What today's basket will cost after the period.
  final double futureCost;

  /// What today's amount will be worth in today's money after the period.
  final double presentValue;
  final double erosionPct;
  final List<double> yearlyCosts;
}

InflationResult calcInflation({
  required double amount,
  required double inflationPct,
  required double years,
}) {
  final double r = inflationPct / 100;
  final double factor = math.pow(1 + r, years).toDouble();
  return InflationResult(
    futureCost: amount * factor,
    presentValue: factor == 0 ? amount : amount / factor,
    erosionPct: factor == 0 ? 0 : (1 - 1 / factor) * 100,
    yearlyCosts: <double>[
      for (int y = 1; y <= years.ceil(); y++)
        amount * math.pow(1 + r, math.min(y, years)),
    ],
  );
}

// ── PPF ─────────────────────────────────────────────────────────────────────

class PpfResult extends GrowthResult {
  const PpfResult({
    required super.invested,
    required super.futureValue,
    required super.gain,
    required super.growthPct,
    required super.yearlyValues,
    required this.years,
  });

  final int years;
}

/// PPF credits interest once a year on the balance after the annual deposit,
/// so the yearly contribution compounds like an ordinary annuity-due.
PpfResult calcPpf({
  required double yearlyDeposit,
  double annualRatePct = 7.1,
  int years = 15,
}) {
  final double r = annualRatePct / 100;
  double balance = 0;
  final List<double> yearly = <double>[];
  for (int y = 0; y < years; y++) {
    balance = (balance + yearlyDeposit) * (1 + r);
    yearly.add(balance);
  }
  final double invested = yearlyDeposit * years;
  return PpfResult(
    invested: invested,
    futureValue: balance,
    gain: balance - invested,
    growthPct: invested <= 0 ? 0 : (balance - invested) / invested * 100,
    yearlyValues: yearly,
    years: years,
  );
}

// ── EMI ─────────────────────────────────────────────────────────────────────

class EmiResult {
  const EmiResult({
    required this.emi,
    required this.totalPayment,
    required this.totalInterest,
    required this.interestSharePct,
    required this.yearlyBalances,
  });

  final double emi;
  final double totalPayment;
  final double totalInterest;

  /// Interest as a share of the total outflow.
  final double interestSharePct;

  /// Outstanding principal at the end of each year.
  final List<double> yearlyBalances;
}

/// `EMI = P × i × (1+i)^n / ((1+i)^n − 1)`.
EmiResult calcEmi({
  required double principal,
  required double annualRatePct,
  required double years,
}) {
  final int n = (years * 12).round();
  final double i = annualRatePct / 100 / 12;
  if (n <= 0 || principal <= 0) {
    return const EmiResult(
      emi: 0,
      totalPayment: 0,
      totalInterest: 0,
      interestSharePct: 0,
      yearlyBalances: <double>[],
    );
  }
  final double emi = i == 0
      ? principal / n
      : principal * i * math.pow(1 + i, n) / (math.pow(1 + i, n) - 1);
  final double total = emi * n;

  final List<double> balances = <double>[];
  double balance = principal;
  for (int m = 1; m <= n; m++) {
    balance = balance + balance * i - emi;
    if (m % 12 == 0 || m == n) balances.add(math.max(0, balance));
  }

  return EmiResult(
    emi: emi,
    totalPayment: total,
    totalInterest: total - principal,
    interestSharePct: total <= 0 ? 0 : (total - principal) / total * 100,
    yearlyBalances: balances,
  );
}

// ── Step-up SIP ─────────────────────────────────────────────────────────────

class StepUpSipResult extends GrowthResult {
  const StepUpSipResult({
    required super.invested,
    required super.futureValue,
    required super.gain,
    required super.growthPct,
    required super.yearlyValues,
    required this.vsFlat,
    required this.flatValue,
    required this.finalMonthly,
  });

  /// How much more the step-up earns than a flat SIP of the starting amount.
  final double vsFlat;
  final double flatValue;

  /// Instalment in the final year, after every annual raise.
  final double finalMonthly;
}

/// A SIP whose instalment rises once a year — the version that matches a salary
/// rather than pretending income is flat for twenty years.
StepUpSipResult calcStepUpSip({
  required double initialMonthly,
  required double annualStepUpPct,
  required double annualRate,
  required double years,
}) {
  final double i = annualRate / 100 / 12;
  final int wholeYears = years.ceil();
  final int months = (years * 12).round();

  double balance = 0;
  double invested = 0;
  double monthly = initialMonthly;
  double finalMonthly = initialMonthly;
  final List<double> yearly = <double>[];
  for (int m = 1; m <= months; m++) {
    // Contribution first, then a month of growth: instalments land on day one.
    balance = (balance + monthly) * (1 + i);
    invested += monthly;
    finalMonthly = monthly;
    if (m % 12 == 0) {
      yearly.add(balance);
      monthly *= 1 + annualStepUpPct / 100;
    } else if (m == months) {
      yearly.add(balance);
    }
  }
  while (yearly.length < wholeYears) {
    yearly.add(balance);
  }

  final SipResult flat = calcSip(
    monthly: initialMonthly,
    annualRatePct: annualRate,
    years: years,
  );
  return StepUpSipResult(
    invested: invested,
    futureValue: balance,
    gain: balance - invested,
    growthPct: invested <= 0 ? 0 : (balance - invested) / invested * 100,
    yearlyValues: yearly,
    vsFlat: balance - flat.futureValue,
    flatValue: flat.futureValue,
    finalMonthly: finalMonthly,
  );
}

// ── XIRR ────────────────────────────────────────────────────────────────────

class XirrResult {
  const XirrResult({
    required this.xirrPct,
    required this.totalInvested,
    required this.currentValue,
    required this.absoluteReturn,
    required this.years,
    required this.converged,
  });

  /// Annualised return that discounts every cash flow back to zero.
  final double xirrPct;

  /// Sum of the outflows, as a positive number.
  final double totalInvested;

  /// Sum of the inflows, including the closing value.
  final double currentValue;

  /// Plain gain over cost, ignoring when the money went in.
  final double absoluteReturn;

  /// Span of the cash flows in years.
  final double years;

  /// False when no rate could be solved — a flat or one-sided set of flows.
  final bool converged;
}

/// Money-weighted return for irregular cash flows. Outflows are negative, the
/// closing value is a positive flow on the last date.
///
/// Solved by Newton-Raphson with a bisection fallback, so a steep or awkward
/// series still returns an answer instead of diverging.
XirrResult calcXirr({
  required List<({DateTime date, double amount})> cashFlows,
}) {
  final List<({DateTime date, double amount})> flows =
      List<({DateTime date, double amount})>.of(cashFlows)..sort(
        (
          ({DateTime date, double amount}) a,
          ({DateTime date, double amount}) b,
        ) => a.date.compareTo(b.date),
      );

  double outflow = 0;
  double inflow = 0;
  for (final ({DateTime date, double amount}) f in flows) {
    if (f.amount < 0) {
      outflow += -f.amount;
    } else {
      inflow += f.amount;
    }
  }
  final double absReturn = outflow <= 0
      ? 0
      : (inflow - outflow) / outflow * 100;
  final double span = flows.length < 2
      ? 0
      : flows.last.date.difference(flows.first.date).inDays / 365;

  XirrResult fail() => XirrResult(
    xirrPct: 0,
    totalInvested: outflow,
    currentValue: inflow,
    absoluteReturn: absReturn,
    years: span,
    converged: false,
  );

  if (flows.length < 2 || outflow <= 0 || inflow <= 0 || span <= 0) {
    return fail();
  }
  final DateTime start = flows.first.date;
  final List<double> t = <double>[
    for (final ({DateTime date, double amount}) f in flows)
      f.date.difference(start).inDays / 365,
  ];

  double npv(double r) {
    double sum = 0;
    for (int k = 0; k < flows.length; k++) {
      sum += flows[k].amount / math.pow(1 + r, t[k]);
    }
    return sum;
  }

  double dNpv(double r) {
    double sum = 0;
    for (int k = 0; k < flows.length; k++) {
      if (t[k] == 0) continue;
      sum += -t[k] * flows[k].amount / math.pow(1 + r, t[k] + 1);
    }
    return sum;
  }

  const double lowerBound = -0.9999;
  double rate = 0.1;
  bool solved = false;
  for (int iter = 0; iter < 100; iter++) {
    final double f = npv(rate);
    if (f.abs() < 1e-7) {
      solved = true;
      break;
    }
    final double d = dNpv(rate);
    if (d == 0 || !d.isFinite) break;
    final double next = rate - f / d;
    if (!next.isFinite || next <= lowerBound) break;
    if ((next - rate).abs() < 1e-10) {
      rate = next;
      solved = true;
      break;
    }
    rate = next;
  }

  if (!solved) {
    // Bracket a sign change, then halve it — slower but it cannot run away.
    double lo = lowerBound;
    double hi = 10;
    double flo = npv(lo);
    if (flo.sign == npv(hi).sign) return fail();
    for (int iter = 0; iter < 200; iter++) {
      final double mid = (lo + hi) / 2;
      final double fmid = npv(mid);
      rate = mid;
      solved = true;
      if (fmid.abs() < 1e-9 || (hi - lo).abs() < 1e-12) break;
      if (fmid.sign == flo.sign) {
        lo = mid;
        flo = fmid;
      } else {
        hi = mid;
      }
    }
  }

  return XirrResult(
    xirrPct: rate * 100,
    totalInvested: outflow,
    currentValue: inflow,
    absoluteReturn: absReturn,
    years: span,
    converged: solved,
  );
}
// ── Bond yield ──────────────────────────────────────────────────────────────

class BondResult {
  const BondResult({
    required this.ytm,
    required this.currentYield,
    required this.cleanPrice,
    required this.dirtyPrice,
    required this.duration,
    required this.modifiedDuration,
    required this.couponPerPeriod,
    required this.totalCoupons,
  });

  /// Yield to maturity, annualised and in percent.
  final double ytm;

  /// Annual coupon over the market price.
  final double currentYield;
  final double cleanPrice;

  /// Clean price plus interest accrued since the last coupon.
  final double dirtyPrice;

  /// Macaulay duration in years — the weighted average time to a rupee back.
  final double duration;

  /// Percentage price move per 1% shift in yield.
  final double modifiedDuration;

  final double couponPerPeriod;
  final int totalCoupons;
}

/// Yield to maturity by bisection on the price function, plus the duration
/// measures that say how hard a rate move will hit the price.
BondResult calcBondYtm({
  required double faceValue,
  required double couponRate,
  required double cleanPrice,
  required double yearsToMaturity,
  int couponFrequency = 2,
  double accruedFraction = 0,
}) {
  final int freq = math.max(1, couponFrequency);
  final int n = math.max(1, (yearsToMaturity * freq).round());
  final double coupon = faceValue * couponRate / 100 / freq;

  double priceAt(double periodRate) {
    double pv = 0;
    for (int k = 1; k <= n; k++) {
      pv += coupon / math.pow(1 + periodRate, k);
    }
    return pv + faceValue / math.pow(1 + periodRate, n);
  }

  // Bisect the per-period rate: price falls monotonically as yield rises.
  double lo = -0.9;
  double hi = 3;
  double rate = 0;
  if (cleanPrice > 0) {
    for (int iter = 0; iter < 200; iter++) {
      rate = (lo + hi) / 2;
      if (priceAt(rate) > cleanPrice) {
        lo = rate;
      } else {
        hi = rate;
      }
    }
  }
  // Macaulay duration: each cash flow weighted by when it arrives.
  double weighted = 0;
  double pvTotal = 0;
  for (int k = 1; k <= n; k++) {
    final double cf = k == n ? coupon + faceValue : coupon;
    final double pv = cf / math.pow(1 + rate, k);
    weighted += pv * (k / freq);
    pvTotal += pv;
  }
  final double macaulay = pvTotal <= 0 ? 0 : weighted / pvTotal;
  final double annualYtm = rate * freq * 100;

  return BondResult(
    ytm: annualYtm,
    currentYield: cleanPrice <= 0
        ? 0
        : faceValue * couponRate / 100 / cleanPrice * 100,
    cleanPrice: cleanPrice,
    dirtyPrice: cleanPrice + coupon * accruedFraction.clamp(0.0, 1.0),
    duration: macaulay,
    modifiedDuration: macaulay / (1 + rate),
    couponPerPeriod: coupon,
    totalCoupons: n,
  );
}

// ── Graham number ───────────────────────────────────────────────────────────

class GrahamResult {
  const GrahamResult({
    required this.grahamNumber,
    required this.intrinsicValue,
    required this.marginOfSafety,
    required this.verdict,
    required this.upsidePct,
    required this.buyBelow,
  });

  /// `√(22.5 × EPS × BVPS)` — Graham's ceiling for a defensive buy.
  final double grahamNumber;

  /// Graham's growth formula: `EPS × (8.5 + 2g) × 4.4 / Y`.
  final double intrinsicValue;

  /// How far below [intrinsicValue] the price sits, in percent. Negative when
  /// the price is above it.
  final double marginOfSafety;

  /// 'undervalued', 'fairly valued' or 'overvalued'.
  final String verdict;

  /// Move to [intrinsicValue] from the current price, in percent.
  final double upsidePct;

  /// Price that leaves a 30% margin of safety.
  final double buyBelow;
}

/// Graham's two valuation yardsticks side by side. A company earning nothing
/// has no Graham number — the formula needs positive earnings and book value.
GrahamResult calcGraham({
  required double eps,
  required double bvps,
  required double currentPrice,
  double epsGrowthRate = 0,
  double aaaYield = 7.5,
}) {
  final double graham = eps <= 0 || bvps <= 0
      ? 0
      : math.sqrt(22.5 * eps * bvps);
  final double y = aaaYield <= 0 ? 7.5 : aaaYield;
  final double intrinsic = eps <= 0
      ? 0
      : eps * (8.5 + 2 * epsGrowthRate) * 4.4 / y;
  final double mos = intrinsic <= 0
      ? 0
      : (intrinsic - currentPrice) / intrinsic * 100;

  return GrahamResult(
    grahamNumber: graham,
    intrinsicValue: intrinsic,
    marginOfSafety: mos,
    verdict: switch (mos) {
      _ when intrinsic <= 0 => 'overvalued',
      >= 30 => 'undervalued',
      >= 0 => 'fairly valued',
      _ => 'overvalued',
    },
    upsidePct: currentPrice <= 0
        ? 0
        : (intrinsic - currentPrice) / currentPrice * 100,
    buyBelow: intrinsic * 0.7,
  );
}
