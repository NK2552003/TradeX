import 'dart:math' as math;

/// Pure options maths — payoff arithmetic and a Black-Scholes model with
/// Greeks. No Flutter imports.

// ── Single-leg payoff ───────────────────────────────────────────────────────

class OptionsPnlResult {
  const OptionsPnlResult({
    required this.premiumPaid,
    required this.breakeven,
    required this.maxProfit,
    required this.maxLoss,
    required this.payoff,
    required this.isUnlimitedProfit,
  });

  /// Total premium for every lot — outflow when buying, inflow when writing.
  final double premiumPaid;
  final double breakeven;

  /// `double.infinity` when the upside is uncapped.
  final double maxProfit;
  final double maxLoss;

  /// Payoff curve as `(spot, pnl)` samples for the chart.
  final List<(double, double)> payoff;
  final bool isUnlimitedProfit;
}

/// Payoff for one option leg.
///
/// Sampled across ±20% of [strike] so the screen can draw the hockey stick.
OptionsPnlResult calcOptionsPnl({
  required bool isBuy,
  required bool isCall,
  required double strike,
  required double premium,
  required double lots,
  required double lotSize,
}) {
  final double qty = lots * lotSize;
  final double premiumTotal = premium * qty;
  final double breakeven = isCall ? strike + premium : strike - premium;

  double pnlAt(double spot) {
    final double intrinsic = isCall
        ? math.max(0, spot - strike)
        : math.max(0, strike - spot);
    final double perUnit = isBuy ? intrinsic - premium : premium - intrinsic;
    return perUnit * qty;
  }

  const int samples = 41;
  final double lo = strike * 0.8;
  final double hi = strike * 1.2;
  final double step = (hi - lo) / (samples - 1);
  final List<(double, double)> payoff = <(double, double)>[
    for (int i = 0; i < samples; i++) (lo + step * i, pnlAt(lo + step * i)),
  ];

  // A long call has uncapped upside; a long put is capped by strike → 0.
  // Written options invert both.
  final bool unlimitedProfit = isBuy && isCall;
  final double maxProfit = switch ((isBuy, isCall)) {
    (true, true) => double.infinity,
    (true, false) => (strike - premium) * qty,
    (false, _) => premiumTotal,
  };
  final double maxLoss = switch ((isBuy, isCall)) {
    (true, _) => premiumTotal,
    (false, true) => double.infinity,
    (false, false) => (strike - premium) * qty,
  };

  return OptionsPnlResult(
    premiumPaid: premiumTotal,
    breakeven: breakeven,
    maxProfit: maxProfit,
    maxLoss: maxLoss,
    payoff: payoff,
    isUnlimitedProfit: unlimitedProfit,
  );
}

// ── Black-Scholes ───────────────────────────────────────────────────────────

class BlackScholesResult {
  const BlackScholesResult({
    required this.price,
    required this.delta,
    required this.gamma,
    required this.theta,
    required this.vega,
    required this.rho,
    required this.intrinsic,
    required this.timeValue,
  });

  final double price;
  final double delta;
  final double gamma;

  /// Premium decay per calendar day.
  final double theta;

  /// Premium change per 1% move in implied volatility.
  final double vega;

  /// Premium change per 1% move in the risk-free rate.
  final double rho;
  final double intrinsic;
  final double timeValue;
}

/// Standard normal PDF.
double _pdf(double x) => math.exp(-x * x / 2) / math.sqrt(2 * math.pi);

/// Standard normal CDF via the Abramowitz-Stegun 7.1.26 approximation
/// (|error| < 7.5e-8) — good enough for a premium quote and avoids a
/// dependency on a stats package.
double _cdf(double x) {
  const double a1 = 0.254829592;
  const double a2 = -0.284496736;
  const double a3 = 1.421413741;
  const double a4 = -1.453152027;
  const double a5 = 1.061405429;
  const double p = 0.3275911;

  final int sign = x < 0 ? -1 : 1;
  final double z = x.abs() / math.sqrt2;
  final double t = 1 / (1 + p * z);
  final double y =
      1 -
      (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-z * z);
  return 0.5 * (1 + sign * y);
}

/// Theoretical premium and Greeks. [ivPct] and [rfRate] are percentages,
/// [daysToExpiry] is calendar days.
BlackScholesResult calcBlackScholes({
  required double spot,
  required double strike,
  required double daysToExpiry,
  required double ivPct,
  required double rfRate,
  required bool isCall,
}) {
  final double t = daysToExpiry / 365;
  final double v = ivPct / 100;
  final double r = rfRate / 100;
  final double intrinsic = isCall
      ? math.max(0, spot - strike)
      : math.max(0, strike - spot);

  // At expiry, or with no volatility, the option is worth its intrinsic value
  // and every Greek except delta collapses.
  if (t <= 0 || v <= 0 || spot <= 0 || strike <= 0) {
    return BlackScholesResult(
      price: intrinsic,
      delta: intrinsic > 0 ? (isCall ? 1 : -1) : 0,
      gamma: 0,
      theta: 0,
      vega: 0,
      rho: 0,
      intrinsic: intrinsic,
      timeValue: 0,
    );
  }

  final double sqrtT = math.sqrt(t);
  final double d1 =
      (math.log(spot / strike) + (r + v * v / 2) * t) / (v * sqrtT);
  final double d2 = d1 - v * sqrtT;
  final double discount = math.exp(-r * t);

  final double price = isCall
      ? spot * _cdf(d1) - strike * discount * _cdf(d2)
      : strike * discount * _cdf(-d2) - spot * _cdf(-d1);

  final double delta = isCall ? _cdf(d1) : _cdf(d1) - 1;
  final double gamma = _pdf(d1) / (spot * v * sqrtT);
  final double thetaPerYear = isCall
      ? -spot * _pdf(d1) * v / (2 * sqrtT) - r * strike * discount * _cdf(d2)
      : -spot * _pdf(d1) * v / (2 * sqrtT) + r * strike * discount * _cdf(-d2);
  final double vega = spot * _pdf(d1) * sqrtT / 100;
  final double rho = isCall
      ? strike * t * discount * _cdf(d2) / 100
      : -strike * t * discount * _cdf(-d2) / 100;

  return BlackScholesResult(
    price: price,
    delta: delta,
    gamma: gamma,
    theta: thetaPerYear / 365,
    vega: vega,
    rho: rho,
    intrinsic: intrinsic,
    timeValue: math.max(0, price - intrinsic),
  );
}

// ── Contract value ──────────────────────────────────────────────────────────

class ContractValueResult {
  const ContractValueResult({
    required this.perLot,
    required this.total,
    required this.lots,
  });

  final double perLot;
  final double total;
  final double lots;
}

ContractValueResult calcContractValue({
  required double lotSize,
  required double price,
  double lots = 1,
}) {
  final double perLot = lotSize * price;
  return ContractValueResult(perLot: perLot, total: perLot * lots, lots: lots);
}

// ── Multi-leg strategy ──────────────────────────────────────────────────────

/// Named structures the builder can pre-fill. [custom] leaves the legs alone.
enum OptionStrategyTemplate {
  custom,
  longStraddle,
  shortStraddle,
  longStrangle,
  shortStrangle,
  bullCallSpread,
  bearPutSpread,
  bullPutSpread,
  bearCallSpread,
  longButterfly,
  shortButterfly,
  ironCondor,
  coveredCall,
  protectivePut,
}

class StrategyLeg {
  const StrategyLeg({
    required this.isBuy,
    required this.isCall,
    required this.strike,
    required this.premium,
    required this.lots,
    required this.lotSize,
  });

  final bool isBuy;
  final bool isCall;
  final double strike;
  final double premium;
  final int lots;
  final int lotSize;

  double get qty => lots * lotSize.toDouble();

  StrategyLeg copyWith({
    bool? isBuy,
    bool? isCall,
    double? strike,
    double? premium,
    int? lots,
    int? lotSize,
  }) => StrategyLeg(
    isBuy: isBuy ?? this.isBuy,
    isCall: isCall ?? this.isCall,
    strike: strike ?? this.strike,
    premium: premium ?? this.premium,
    lots: lots ?? this.lots,
    lotSize: lotSize ?? this.lotSize,
  );
}

class StrategyResult {
  const StrategyResult({
    required this.maxProfit,
    required this.maxLoss,
    required this.breakevens,
    required this.netPremium,
    required this.marginRequired,
    required this.rewardToRisk,
    required this.payoffCurve,
  });

  /// `double.infinity` when the upside is uncapped.
  final double maxProfit;

  /// Positive magnitude, `double.infinity` when the downside is uncapped.
  final double maxLoss;

  /// Spot prices where the combination breaks even — one for a spread, two for
  /// a straddle, condor or butterfly.
  final List<double> breakevens;

  /// Positive when the structure collects money, negative when it pays.
  final double netPremium;

  /// Rough SPAN + exposure estimate; a defined-risk structure is charged close
  /// to its own max loss, a naked short close to a share of notional.
  final double marginRequired;

  /// [maxProfit] ÷ [maxLoss].
  final double rewardToRisk;

  /// 21 samples across ±20% of spot.
  final List<({double price, double pnl})> payoffCurve;
}

/// Payoff of any combination of option legs at expiry.
///
/// The curve is piecewise linear with a kink at every strike, so the extremes
/// can only sit on a strike, at a spot of zero, or out at infinity — which is
/// what makes exact max profit, max loss and breakevens cheap to find without
/// scanning a grid.
StrategyResult calcStrategy(List<StrategyLeg> legs, double spot) {
  double pnlAt(double price) {
    double total = 0;
    for (final StrategyLeg l in legs) {
      final double intrinsic = l.isCall
          ? math.max(0, price - l.strike)
          : math.max(0, l.strike - price);
      final double perUnit = l.isBuy
          ? intrinsic - l.premium
          : l.premium - intrinsic;
      total += perUnit * l.qty;
    }
    return total;
  }

  const int samples = 21;
  final double lo = math.max(0, spot * 0.8);
  final double hi = spot * 1.2;
  final double step = samples > 1 ? (hi - lo) / (samples - 1) : 0;
  final List<({double price, double pnl})> curve =
      <({double price, double pnl})>[
        for (int i = 0; i < samples; i++)
          (price: lo + step * i, pnl: pnlAt(lo + step * i)),
      ];

  if (legs.isEmpty) {
    return StrategyResult(
      maxProfit: 0,
      maxLoss: 0,
      breakevens: const <double>[],
      netPremium: 0,
      marginRequired: 0,
      rewardToRisk: 0,
      payoffCurve: curve,
    );
  }
  double netPremium = 0;
  double callSlope = 0; // dP&L/dSpot above every strike.
  final List<double> shortNotionals = <double>[];
  double longPremium = 0;
  for (final StrategyLeg l in legs) {
    netPremium += (l.isBuy ? -1 : 1) * l.premium * l.qty;
    if (l.isCall) callSlope += (l.isBuy ? 1 : -1) * l.qty;
    if (l.isBuy) {
      longPremium += l.premium * l.qty;
    } else {
      shortNotionals.add(l.strike * l.qty);
    }
  }

  // Candidate extremes: every kink, plus a spot of zero.
  final List<double> strikes =
      legs.map((StrategyLeg l) => l.strike).toSet().toList()..sort();
  final List<double> nodes = <double>[0, ...strikes];
  double best = pnlAt(nodes.first);
  double worst = best;
  for (final double n in nodes) {
    final double v = pnlAt(n);
    best = math.max(best, v);
    worst = math.min(worst, v);
  }
  // Far enough past the last strike that any remaining zero crossing is
  // bracketed. The segment is straight out there, so interpolation is exact
  // however far out this sits.
  final double reach = legs.fold<double>(
    0,
    (double a, StrategyLeg l) => a + l.premium.abs(),
  );
  final double beyond = strikes.last + math.max(1, strikes.last) + reach * 10;
  if (callSlope == 0) {
    final double v = pnlAt(beyond);
    best = math.max(best, v);
    worst = math.min(worst, v);
  }

  final double maxProfit = callSlope > 0 ? double.infinity : best;
  // A structure that cannot lose has a max loss of zero, not a negative one.
  final double maxLoss = callSlope < 0 ? double.infinity : math.max(0, -worst);

  // Walk the segments and interpolate every zero crossing.
  final List<double> nodesUp = <double>[...nodes, beyond];
  final List<double> breakevens = <double>[];
  for (int i = 0; i < nodesUp.length - 1; i++) {
    final double x0 = nodesUp[i];
    final double x1 = nodesUp[i + 1];
    if (x1 <= x0) continue;
    final double y0 = pnlAt(x0);
    final double y1 = pnlAt(x1);
    if (y0 == 0) {
      breakevens.add(x0);
    } else if (y0.sign != y1.sign && y1 != 0) {
      breakevens.add(x0 + (x1 - x0) * (-y0 / (y1 - y0)));
    }
  }
  // Margin estimate. Long-only structures cost nothing but the debit. Short
  // legs block margin: the exchange nets them, so the biggest one carries the
  // full exposure and the rest a fraction. A defined-risk combination is
  // charged close to its own worst case instead.
  shortNotionals.sort();
  double naked = 0;
  for (int i = 0; i < shortNotionals.length; i++) {
    final bool largest = i == shortNotionals.length - 1;
    naked += shortNotionals[i] * (largest ? 0.15 : 0.05);
  }
  final double margin = shortNotionals.isEmpty
      ? longPremium
      : (maxLoss.isFinite ? math.min(naked, maxLoss) : naked);

  final double rewardToRisk;
  if (maxLoss.isInfinite) {
    rewardToRisk = 0;
  } else if (maxProfit.isInfinite || maxLoss == 0) {
    rewardToRisk = maxProfit > 0 ? double.infinity : 0;
  } else {
    rewardToRisk = maxProfit / maxLoss;
  }

  return StrategyResult(
    maxProfit: maxProfit,
    maxLoss: maxLoss,
    breakevens: breakevens,
    netPremium: netPremium,
    marginRequired: margin,
    rewardToRisk: rewardToRisk,
    payoffCurve: curve,
  );
}

extension OptionStrategyTemplateX on OptionStrategyTemplate {
  String get label => switch (this) {
    OptionStrategyTemplate.custom => 'Custom',
    OptionStrategyTemplate.longStraddle => 'Long Straddle',
    OptionStrategyTemplate.shortStraddle => 'Short Straddle',
    OptionStrategyTemplate.longStrangle => 'Long Strangle',
    OptionStrategyTemplate.shortStrangle => 'Short Strangle',
    OptionStrategyTemplate.bullCallSpread => 'Bull Call Spread',
    OptionStrategyTemplate.bearPutSpread => 'Bear Put Spread',
    OptionStrategyTemplate.bullPutSpread => 'Bull Put Spread',
    OptionStrategyTemplate.bearCallSpread => 'Bear Call Spread',
    OptionStrategyTemplate.longButterfly => 'Long Butterfly',
    OptionStrategyTemplate.shortButterfly => 'Short Butterfly',
    OptionStrategyTemplate.ironCondor => 'Iron Condor',
    OptionStrategyTemplate.coveredCall => 'Covered Call',
    OptionStrategyTemplate.protectivePut => 'Protective Put',
  };

  /// Which filter group the template belongs to on the builder screen.
  String get group => switch (this) {
    OptionStrategyTemplate.custom => 'All',
    OptionStrategyTemplate.longStraddle ||
    OptionStrategyTemplate.shortStraddle => 'Straddle',
    OptionStrategyTemplate.longStrangle ||
    OptionStrategyTemplate.shortStrangle => 'Strangle',
    OptionStrategyTemplate.bullCallSpread ||
    OptionStrategyTemplate.bearPutSpread ||
    OptionStrategyTemplate.bullPutSpread ||
    OptionStrategyTemplate.bearCallSpread ||
    OptionStrategyTemplate.coveredCall ||
    OptionStrategyTemplate.protectivePut => 'Spreads',
    OptionStrategyTemplate.ironCondor => 'Condor',
    OptionStrategyTemplate.longButterfly ||
    OptionStrategyTemplate.shortButterfly => 'Butterfly',
  };

  /// Set when the structure includes stock and is shown as its exact synthetic
  /// option equivalent, so the leg table never silently misrepresents it.
  String? get syntheticNote => switch (this) {
    OptionStrategyTemplate.coveredCall =>
      'Long stock + short ATM call. Bought at the strike, that payoff is '
          'identical to a short ATM put, which is how the legs are shown.',
    OptionStrategyTemplate.protectivePut =>
      'Long stock + long ATM put. Bought at the strike, that payoff is '
          'identical to a long ATM call, which is how the legs are shown.',
    _ => null,
  };
}

/// Strike interval an exchange would list around [spot].
double strikeStepFor(double spot) => switch (spot) {
  < 500 => 5,
  < 2000 => 10,
  < 30000 => 50,
  _ => 100,
};

/// Rough near-month premium for a strike, so a template arrives with numbers
/// worth looking at instead of zeros. ATM sits near 1.5% of spot and decays
/// away from it; deep strikes never price below intrinsic.
double premiumEstimate({
  required double strike,
  required bool isCall,
  required double spot,
}) {
  if (spot <= 0) return 0;
  final double intrinsic = isCall
      ? math.max(0, spot - strike)
      : math.max(0, strike - spot);
  final double extrinsic =
      spot * 0.015 * math.exp(-(strike - spot).abs() / (spot * 0.03));
  // Snap to the 5-paise tick options actually quote in.
  return ((intrinsic + extrinsic) * 20).round() / 20;
}

/// Legs for a named structure, centred on the ATM strike around [spot].
///
/// [OptionStrategyTemplate.custom] returns an empty list — the screen keeps
/// whatever the user already built.
List<StrategyLeg> legsForTemplate(
  OptionStrategyTemplate template, {
  required double spot,
  required int lotSize,
  double? step,
}) {
  if (template == OptionStrategyTemplate.custom || spot <= 0) {
    return const <StrategyLeg>[];
  }
  final double s = step ?? strikeStepFor(spot);
  final double atm = (spot / s).round() * s;

  StrategyLeg leg(bool isBuy, bool isCall, double strike, [int lots = 1]) =>
      StrategyLeg(
        isBuy: isBuy,
        isCall: isCall,
        strike: strike,
        premium: premiumEstimate(strike: strike, isCall: isCall, spot: spot),
        lots: lots,
        lotSize: lotSize,
      );
  return switch (template) {
    OptionStrategyTemplate.custom => const <StrategyLeg>[],
    OptionStrategyTemplate.longStraddle => <StrategyLeg>[
      leg(true, true, atm),
      leg(true, false, atm),
    ],
    OptionStrategyTemplate.shortStraddle => <StrategyLeg>[
      leg(false, true, atm),
      leg(false, false, atm),
    ],
    OptionStrategyTemplate.longStrangle => <StrategyLeg>[
      leg(true, true, atm + 2 * s),
      leg(true, false, atm - 2 * s),
    ],
    OptionStrategyTemplate.shortStrangle => <StrategyLeg>[
      leg(false, true, atm + 2 * s),
      leg(false, false, atm - 2 * s),
    ],
    OptionStrategyTemplate.bullCallSpread => <StrategyLeg>[
      leg(true, true, atm),
      leg(false, true, atm + 2 * s),
    ],
    OptionStrategyTemplate.bearPutSpread => <StrategyLeg>[
      leg(true, false, atm),
      leg(false, false, atm - 2 * s),
    ],
    OptionStrategyTemplate.bullPutSpread => <StrategyLeg>[
      leg(false, false, atm),
      leg(true, false, atm - 2 * s),
    ],
    OptionStrategyTemplate.bearCallSpread => <StrategyLeg>[
      leg(false, true, atm),
      leg(true, true, atm + 2 * s),
    ],
    OptionStrategyTemplate.longButterfly => <StrategyLeg>[
      leg(true, true, atm - 2 * s),
      leg(false, true, atm, 2),
      leg(true, true, atm + 2 * s),
    ],
    OptionStrategyTemplate.shortButterfly => <StrategyLeg>[
      leg(false, true, atm - 2 * s),
      leg(true, true, atm, 2),
      leg(false, true, atm + 2 * s),
    ],
    OptionStrategyTemplate.ironCondor => <StrategyLeg>[
      leg(true, false, atm - 4 * s),
      leg(false, false, atm - 2 * s),
      leg(false, true, atm + 2 * s),
      leg(true, true, atm + 4 * s),
    ],
    OptionStrategyTemplate.coveredCall => <StrategyLeg>[leg(false, false, atm)],
    OptionStrategyTemplate.protectivePut => <StrategyLeg>[leg(true, true, atm)],
  };
}
// ── IV rank ─────────────────────────────────────────────────────────────────

class IvRankResult {
  const IvRankResult({
    required this.ivRank,
    required this.ivPercentile,
    required this.signal,
    required this.interpretation,
  });

  /// Where today's IV sits inside the 52-week range, 0–100.
  final double ivRank;

  /// Share of the last year spent below today's IV, 0–100.
  final double ivPercentile;

  /// 'sell premium', 'buy premium' or 'neutral'.
  final String signal;
  final String interpretation;
}

/// Rank tells you whether options are expensive relative to their own history —
/// the only comparison that means anything, since 20% IV is cheap on one
/// underlying and dear on another.
IvRankResult calcIvRank({
  required double currentIv,
  required double low52w,
  required double high52w,
  required int daysAbove,
  required int totalDays,
}) {
  final double lo = math.min(low52w, high52w);
  final double hi = math.max(low52w, high52w);
  final double range = hi - lo;
  final double rank = range <= 0
      ? 0
      : ((currentIv - lo) / range * 100).clamp(0.0, 100.0);
  // daysAbove counts the days spent above today's IV, so the percentile of
  // today's reading is what is left.
  final double percentile = totalDays <= 0
      ? 0
      : ((totalDays - daysAbove) / totalDays * 100).clamp(0.0, 100.0);

  final String signal = switch (rank) {
    > 50 => 'sell premium',
    < 30 => 'buy premium',
    _ => 'neutral',
  };
  return IvRankResult(
    ivRank: rank,
    ivPercentile: percentile,
    signal: signal,
    interpretation: switch (signal) {
      'sell premium' =>
        'IV is in the upper half of its 52-week range. Credit structures — '
            'short strangles, iron condors, covered calls — are priced in your '
            'favour, and a fall in IV pays you.',
      'buy premium' =>
        'IV is near its 52-week floor. Debit structures — long straddles, '
            'calendars, plain long options — cost less than usual, and any '
            'volatility expansion pays you.',
      _ =>
        'IV is mid-range. Neither buying nor selling premium has an edge from '
            'volatility alone; trade direction, not vol.',
    },
  );
}
// ── Max pain ────────────────────────────────────────────────────────────────

class MaxPainResult {
  const MaxPainResult({
    required this.maxPainStrike,
    required this.painByStrike,
    required this.spot,
  });

  /// Strike where the total value writers would have to pay out is smallest.
  final double maxPainStrike;

  /// Total writer payout at every strike in the chain, ascending by strike.
  final List<({double strike, double totalPain})> painByStrike;

  /// Echoed back so the screen can show the distance from spot.
  final double spot;

  /// Signed gap from [spot] to [maxPainStrike].
  double get distanceFromSpot => maxPainStrike - spot;

  double get distancePct => spot <= 0 ? 0 : distanceFromSpot / spot * 100;
}

/// The strike at which option writers collectively lose the least — the level
/// open interest is said to pull expiry towards.
MaxPainResult calcMaxPain({
  required List<({double strike, double callOi, double putOi})> chain,
  required double spot,
}) {
  if (chain.isEmpty) {
    return MaxPainResult(
      maxPainStrike: 0,
      painByStrike: const <({double strike, double totalPain})>[],
      spot: spot,
    );
  }
  final List<({double strike, double callOi, double putOi})> rows =
      List<({double strike, double callOi, double putOi})>.of(chain)..sort(
        (
          ({double strike, double callOi, double putOi}) a,
          ({double strike, double callOi, double putOi}) b,
        ) => a.strike.compareTo(b.strike),
      );

  final List<({double strike, double totalPain})> pain =
      <({double strike, double totalPain})>[];
  for (final ({double strike, double callOi, double putOi}) at in rows) {
    double total = 0;
    for (final ({double strike, double callOi, double putOi}) r in rows) {
      total += r.callOi * math.max(0, at.strike - r.strike);
      total += r.putOi * math.max(0, r.strike - at.strike);
    }
    pain.add((strike: at.strike, totalPain: total));
  }

  ({double strike, double totalPain}) least = pain.first;
  for (final ({double strike, double totalPain}) p in pain) {
    if (p.totalPain < least.totalPain) least = p;
  }
  return MaxPainResult(
    maxPainStrike: least.strike,
    painByStrike: pain,
    spot: spot,
  );
}
// ── SPAN margin ─────────────────────────────────────────────────────────────

class SpanResult {
  const SpanResult({
    required this.nakedMargin,
    required this.hedgedMargin,
    required this.savedPct,
    required this.nrmlMargin,
    required this.misMargin,
    required this.notional,
    required this.marginPct,
  });

  /// SPAN + exposure on an unhedged short, in rupees.
  final double nakedMargin;

  /// The same position with a long leg against it — the exchange caps the
  /// worst case, so most of the margin is released.
  final double hedgedMargin;

  /// How much the hedge saves, as a percentage of [nakedMargin].
  final double savedPct;

  /// Carry-forward margin for the position as configured.
  final double nrmlMargin;

  /// Intraday margin, where brokers pass on part of their own benefit.
  final double misMargin;

  final double notional;

  /// Percentage of notional used for the naked leg.
  final double marginPct;
}

/// Exposure-based margin estimate. Index contracts carry a thinner exposure leg
/// than single stocks, so the symbol picks the default when no percentage is
/// supplied.
double autoMarginPctFor(String symbol) => switch (symbol.toUpperCase().trim()) {
  'NIFTY' => 12.0,
  'FINNIFTY' => 13.0,
  'BANKNIFTY' || 'MIDCPNIFTY' => 14.0,
  'SENSEX' || 'BANKEX' => 12.5,
  _ => 20.0,
};

SpanResult calcSpanMargin({
  required String symbol,
  required double spotPrice,
  required double lotSize,
  required int lots,
  required bool isHedged,
  double contractMarginPct = 0,
}) {
  final double pct = contractMarginPct > 0
      ? contractMarginPct
      : autoMarginPctFor(symbol);
  final double notional = math.max(0, spotPrice * lotSize * lots);
  final double naked = notional * pct / 100;
  // A long option against the short caps the loss, and the exchange releases
  // roughly 80% of the block — the standard hedge benefit.
  final double hedged = naked * 0.20;
  final double nrml = isHedged ? hedged : naked;
  return SpanResult(
    nakedMargin: naked,
    hedgedMargin: hedged,
    savedPct: naked <= 0 ? 0 : (naked - hedged) / naked * 100,
    nrmlMargin: nrml,
    // Intraday products pass part of the benefit on; squared off before close.
    misMargin: nrml * 0.60,
    notional: notional,
    marginPct: pct,
  );
}
