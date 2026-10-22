/// Pure Indian capital-gains and turnover maths. No Flutter imports.
///
/// Rates follow FY 2025-26 equity rules. Cess is the 4% health & education
/// cess applied on top of the tax.
library;

import 'dart:math' as math;

const double kStcgRate = 20.0;
const double kLtcgRate = 12.5;

/// Gains up to this amount are LTCG-exempt in a financial year.
const double kLtcgExemption = 125000.0;

const double kCessRate = 4.0;

/// Listed equity under sections 111A/112A, subject to the statutory conditions.
/// The annual exemption increased for FY 2024-25, including pre-July transfers.
/// Sources: Income Tax Department capital-gains FAQs and Finance (No. 2) Act 2024.
enum EquityTaxPeriod {
  beforeApril2024,
  aprilToJuly2024,
  from23July2024;

  double get stcgRate => this == from23July2024 ? kStcgRate : 15;
  double get ltcgRate => this == from23July2024 ? kLtcgRate : 10;
  double get exemption => this == beforeApril2024 ? 100000 : kLtcgExemption;
  String get label => switch (this) {
    beforeApril2024 => 'Before 1 Apr 2024',
    aprilToJuly2024 => '1 Apr – 22 Jul 2024',
    from23July2024 => 'From 23 Jul 2024',
  };
}

class StcgResult {
  const StcgResult({
    required this.gain,
    required this.taxableGain,
    required this.tax,
    required this.cess,
    required this.totalTax,
    required this.netGain,
    required this.effectiveRatePct,
  });

  final double gain;
  final double taxableGain;

  /// Tax before cess.
  final double tax;
  final double cess;
  final double totalTax;
  final double netGain;

  /// [totalTax] as a percentage of [gain].
  final double effectiveRatePct;
}

/// STCG on listed equity: the selected period rate (plus cess) with no exemption. A loss is
/// returned untaxed so the screen can show it as carry-forward.
StcgResult calcStcg({
  required double gain,
  EquityTaxPeriod period = EquityTaxPeriod.from23July2024,
}) {
  final double taxable = gain > 0 ? gain : 0;
  final double tax = taxable * period.stcgRate / 100;
  final double cess = tax * kCessRate / 100;
  final double total = tax + cess;
  return StcgResult(
    gain: gain,
    taxableGain: taxable,
    tax: tax,
    cess: cess,
    totalTax: total,
    netGain: gain - total,
    effectiveRatePct: gain <= 0 ? 0 : total / gain * 100,
  );
}

class LtcgResult {
  const LtcgResult({
    required this.gain,
    required this.exemptionUsed,
    required this.taxableGain,
    required this.tax,
    required this.cess,
    required this.totalTax,
    required this.netGain,
    required this.effectiveRatePct,
  });

  final double gain;

  /// Portion of the annual exemption consumed.
  final double exemptionUsed;
  final double taxableGain;
  final double tax;
  final double cess;
  final double totalTax;
  final double netGain;
  final double effectiveRatePct;
}

/// LTCG on listed equity at the selected period rate (plus cess) on the gain above
/// [kLtcgExemption]. [exemptionAlreadyUsed] lets a trader account for gains
/// already booked earlier in the same financial year.
LtcgResult calcLtcg({
  required double gain,
  double exemptionAlreadyUsed = 0,
  EquityTaxPeriod period = EquityTaxPeriod.from23July2024,
}) {
  final double remaining = (period.exemption - exemptionAlreadyUsed).clamp(
    0.0,
    period.exemption,
  );
  final double positive = gain > 0 ? gain : 0;
  final double used = positive < remaining ? positive : remaining;
  final double taxable = positive - used;
  final double tax = taxable * period.ltcgRate / 100;
  final double cess = tax * kCessRate / 100;
  final double total = tax + cess;
  return LtcgResult(
    gain: gain,
    exemptionUsed: used,
    taxableGain: taxable,
    tax: tax,
    cess: cess,
    totalTax: total,
    netGain: gain - total,
    effectiveRatePct: gain <= 0 ? 0 : total / gain * 100,
  );
}

class TurnoverResult {
  const TurnoverResult({
    required this.turnover,
    required this.netPnl,
    required this.auditRequired,
    required this.presumptiveIncome,
    required this.threshold,
  });

  /// Absolute sum of profits and losses (the F&O convention).
  final double turnover;
  final double netPnl;

  /// True when the turnover crosses [threshold] and profit is below the
  /// presumptive 6%.
  final bool auditRequired;

  /// 6% of [turnover] — the section 44AD presumptive figure.
  final double presumptiveIncome;
  final double threshold;
}

/// Section 44AB turnover for F&O.
///
/// [threshold] is ₹10 crore when 95%+ of receipts are digital, which is the
/// norm for exchange-settled trades.
TurnoverResult calcTurnover({
  required double profitSum,
  required double lossSum,
  double threshold = 100000000,
}) {
  final double turnover = profitSum.abs() + lossSum.abs();
  final double netPnl = profitSum.abs() - lossSum.abs();
  final double presumptive = turnover * 0.06;
  return TurnoverResult(
    turnover: turnover,
    netPnl: netPnl,
    auditRequired: turnover > threshold || netPnl < presumptive,
    presumptiveIncome: presumptive,
    threshold: threshold,
  );
}

// ── Slab tax ────────────────────────────────────────────────────────────────

/// Old-regime slabs: nil to ₹2.5L, 5% to ₹5L, 20% to ₹10L, 30% above.
double slabTaxOld(double income) {
  if (income <= 250000) return 0;
  double tax = 0;
  if (income > 1000000) tax += (income - 1000000) * 0.30;
  if (income > 500000) tax += (math.min(income, 1000000) - 500000) * 0.20;
  tax += (math.min(income, 500000) - 250000) * 0.05;
  return tax;
}

/// New-regime slabs for FY 2025-26: nil to ₹4L, then 5/10/15/20/25% in ₹4L
/// bands, 30% above ₹24L.
double slabTaxNew(double income) {
  const List<(double, double)> bands = <(double, double)>[
    (400000, 0.00),
    (800000, 0.05),
    (1200000, 0.10),
    (1600000, 0.15),
    (2000000, 0.20),
    (2400000, 0.25),
  ];
  double tax = 0;
  double prev = 0;
  for (final (double upTo, double rate) in bands) {
    if (income <= prev) return tax;
    tax += (math.min(income, upTo) - prev) * rate;
    prev = upTo;
  }
  if (income > prev) tax += (income - prev) * 0.30;
  return tax;
}

/// Section 87A rebate — ₹60,000 up to ₹12L of taxable income in the new
/// regime, ₹12,500 up to ₹5L in the old one.
double rebate87a(
  double taxableIncome,
  double tax, {
  required bool isNewRegime,
}) {
  if (isNewRegime) {
    return taxableIncome <= 1200000 ? math.min(tax, 60000) : 0;
  }
  return taxableIncome <= 500000 ? math.min(tax, 12500) : 0;
}

/// Slab tax net of the 87A rebate.
double slabTax(double taxableIncome, {required bool isNewRegime}) {
  final double gross = isNewRegime
      ? slabTaxNew(taxableIncome)
      : slabTaxOld(taxableIncome);
  return gross - rebate87a(taxableIncome, gross, isNewRegime: isNewRegime);
}

// ── Surcharge ───────────────────────────────────────────────────────────────

class SurchargeResult {
  const SurchargeResult({
    required this.basicTax,
    required this.surchargePct,
    required this.surchargeAmount,
    required this.healthEduCess,
    required this.totalTax,
    required this.effectiveRatePct,
    required this.marginalReliefApplied,
  });

  /// Slab tax before surcharge and cess, net of the 87A rebate.
  final double basicTax;

  /// Statutory rate for the income band, 0–37.
  final double surchargePct;

  /// Rupee surcharge after any marginal relief.
  final double surchargeAmount;
  final double healthEduCess;
  final double totalTax;

  /// [totalTax] over total income, in percent.
  final double effectiveRatePct;

  /// Relief given where crossing a threshold would cost more in tax than the
  /// income earned above it.
  final double marginalReliefApplied;
}

/// Statutory surcharge rate for [income]. The new regime drops the 37% band,
/// capping surcharge at 25%.
double surchargeRateFor(double income, {required bool isNewRegime}) {
  if (income <= 5000000) return 0;
  if (income <= 10000000) return 10;
  if (income <= 20000000) return 15;
  if (income <= 50000000) return 25;
  return isNewRegime ? 25 : 37;
}

/// Threshold below [income] where the surcharge band it sits in begins.
double _surchargeThresholdFor(double income) {
  if (income <= 5000000) return 0;
  if (income <= 10000000) return 5000000;
  if (income <= 20000000) return 10000000;
  if (income <= 50000000) return 20000000;
  return 50000000;
}

/// Surcharge and cess on top of slab tax, with marginal relief.
///
/// Marginal relief is the rule that stops a rupee of extra income from costing
/// more than a rupee of tax at a threshold: the surcharge is trimmed until the
/// step up in total tax is no bigger than the step up in income.
SurchargeResult calcSurcharge({
  required double totalIncome,
  required bool isNewRegime,
}) {
  final double income = math.max(0, totalIncome);
  final double basic = slabTax(income, isNewRegime: isNewRegime);
  final double pct = surchargeRateFor(income, isNewRegime: isNewRegime);
  double surcharge = basic * pct / 100;

  double relief = 0;
  final double threshold = _surchargeThresholdFor(income);
  if (threshold > 0 && surcharge > 0) {
    final double taxAtThreshold =
        slabTax(threshold, isNewRegime: isNewRegime) +
        slabTax(threshold, isNewRegime: isNewRegime) *
            surchargeRateFor(threshold, isNewRegime: isNewRegime) /
            100;
    final double excessIncome = income - threshold;
    final double excessTax = basic + surcharge - taxAtThreshold;
    if (excessTax > excessIncome) {
      relief = math.min(surcharge, excessTax - excessIncome);
      surcharge -= relief;
    }
  }

  final double cess = (basic + surcharge) * kCessRate / 100;
  final double total = basic + surcharge + cess;
  return SurchargeResult(
    basicTax: basic,
    surchargePct: pct,
    surchargeAmount: surcharge,
    healthEduCess: cess,
    totalTax: total,
    effectiveRatePct: income <= 0 ? 0 : total / income * 100,
    marginalReliefApplied: relief,
  );
}
// ── Advance tax ─────────────────────────────────────────────────────────────

class AdvanceTaxResult {
  const AdvanceTaxResult({
    required this.totalTaxLiability,
    required this.q1Due,
    required this.q2Due,
    required this.q3Due,
    required this.q4Due,
    required this.interest234b,
    required this.interest234c,
    required this.taxableIncome,
    required this.slabTaxAmount,
    required this.stcgTax,
    required this.ltcgTax,
    required this.surchargeAmount,
    required this.cess,
    required this.netPayable,
  });

  /// Tax on everything, before subtracting TDS already deducted.
  final double totalTaxLiability;

  /// Instalment payable in each quarter — 15/30/30/25% of [netPayable], the
  /// steps that make the statutory 15/45/75/100% cumulative schedule.
  final double q1Due;
  final double q2Due;
  final double q3Due;
  final double q4Due;

  /// 1% a month on the shortfall left unpaid after 31 March.
  final double interest234b;

  /// 1% a quarter for missing the instalment dates.
  final double interest234c;

  final double taxableIncome;
  final double slabTaxAmount;
  final double stcgTax;
  final double ltcgTax;
  final double surchargeAmount;
  final double cess;

  /// [totalTaxLiability] less TDS — the amount the instalments must cover.
  final double netPayable;

  /// Cumulative amount due by each of the four dates.
  List<double> get cumulativeDue => <double>[
    q1Due,
    q1Due + q2Due,
    q1Due + q2Due + q3Due,
    q1Due + q2Due + q3Due + q4Due,
  ];

  double get totalInterest => interest234b + interest234c;
}

/// The four dates advance tax falls due on, and what happens if you miss them.
const List<String> kAdvanceTaxDates = <String>[
  '15 Jun',
  '15 Sep',
  '15 Dec',
  '15 Mar',
];

/// Cumulative share of the liability due by each date.
const List<double> kAdvanceTaxCumulativePct = <double>[15, 45, 75, 100];

/// Advance tax on a trader's mixed income, under the old regime — the one where
/// the 80C deduction still exists.
///
/// The interest figures are the worst case: they assume no instalment was paid
/// during the year, so only TDS is credited.
AdvanceTaxResult calcAdvanceTax({
  required double businessIncome,
  required double stcgIncome,
  required double ltcgIncome,
  double salaryIncome = 0,
  double otherIncome = 0,
  double section80c = 0,
  double tdsAlreadyPaid = 0,
  int monthsTo234bPayment = 4,
}) {
  final double deduction = math.min(math.max(0, section80c), 150000);
  final double ordinary = math.max(
    0,
    salaryIncome + businessIncome + otherIncome - deduction,
  );
  final double stcg = math.max(0, stcgIncome);
  final double ltcg = math.max(0, ltcgIncome);
  final double totalIncome = ordinary + stcg + ltcg;

  final double slab = slabTax(ordinary, isNewRegime: false);
  final double stcgTax = stcg * kStcgRate / 100;
  final double ltcgTax = math.max(0, ltcg - kLtcgExemption) * kLtcgRate / 100;
  final double beforeSurcharge = slab + stcgTax + ltcgTax;

  final double surcharge =
      beforeSurcharge * surchargeRateFor(totalIncome, isNewRegime: false) / 100;
  final double cess = (beforeSurcharge + surcharge) * kCessRate / 100;
  final double liability = beforeSurcharge + surcharge + cess;
  final double net = math.max(0, liability - math.max(0, tdsAlreadyPaid));

  // Nothing paid on time means each instalment carries interest from its own
  // date: three months for the first three, one for the last.
  final double i234c =
      net * (0.15 * 0.03 + 0.45 * 0.03 + 0.75 * 0.03 + 1.00 * 0.01);
  final bool shortOf90Pct = math.max(0, tdsAlreadyPaid) < liability * 0.9;
  final double i234b = shortOf90Pct
      ? net * 0.01 * math.max(0, monthsTo234bPayment)
      : 0;

  return AdvanceTaxResult(
    totalTaxLiability: liability,
    q1Due: net * 0.15,
    q2Due: net * 0.30,
    q3Due: net * 0.30,
    q4Due: net * 0.25,
    interest234b: i234b,
    interest234c: i234c,
    taxableIncome: totalIncome,
    slabTaxAmount: slab,
    stcgTax: stcgTax,
    ltcgTax: ltcgTax,
    surchargeAmount: surcharge,
    cess: cess,
    netPayable: net,
  );
}
