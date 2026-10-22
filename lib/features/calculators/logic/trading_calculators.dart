import 'dart:math' as math;

/// Pure trading maths. No Flutter imports — everything here is unit-testable
/// and free of side effects. All money values are in rupees.

// ── Position sizing ─────────────────────────────────────────────────────────

class PositionSizeResult {
  const PositionSizeResult({
    required this.riskAmount,
    required this.riskPerShare,
    required this.quantity,
    required this.positionValue,
    required this.capitalUsedPct,
  });

  /// Rupees at stake if the stop loss triggers.
  final double riskAmount;
  final double riskPerShare;
  final int quantity;
  final double positionValue;

  /// Share of the account tied up by the position, 0–100+.
  final double capitalUsedPct;
}

/// Quantity that keeps the loss at [riskPct] of [accountSize] if [sl] hits.
///
/// Works for both long ([entry] > [sl]) and short ([entry] < [sl]) setups —
/// only the distance matters.
PositionSizeResult calcPositionSize({
  required double accountSize,
  required double riskPct,
  required double entry,
  required double sl,
}) {
  final double riskAmount = accountSize * riskPct / 100;
  final double riskPerShare = (entry - sl).abs();
  final int quantity = riskPerShare <= 0
      ? 0
      : (riskAmount / riskPerShare).floor();
  final double positionValue = quantity * entry;
  return PositionSizeResult(
    riskAmount: riskAmount,
    riskPerShare: riskPerShare,
    quantity: quantity,
    positionValue: positionValue,
    capitalUsedPct: accountSize <= 0 ? 0 : positionValue / accountSize * 100,
  );
}

// ── Risk / reward ───────────────────────────────────────────────────────────

class RiskRewardResult {
  const RiskRewardResult({
    required this.risk,
    required this.reward,
    required this.ratio,
    required this.breakevenWinRatePct,
  });

  final double risk;
  final double reward;

  /// Reward divided by risk. 0 when the stop and entry coincide.
  final double ratio;

  /// Win rate needed just to break even at this ratio, 0–100.
  final double breakevenWinRatePct;
}

RiskRewardResult calcRiskReward({
  required double entry,
  required double sl,
  required double target,
}) {
  final rawRisk = (entry - sl).abs();
  final rawReward = (target - entry).abs();
  final double risk = rawRisk.isFinite ? rawRisk : 0;
  final double reward = rawReward.isFinite ? rawReward : 0;
  final rawRatio = risk <= 0 ? 0.0 : reward / risk;
  final double ratio = rawRatio.isFinite ? rawRatio : 0;
  return RiskRewardResult(
    risk: risk,
    reward: reward,
    ratio: ratio,
    breakevenWinRatePct: ratio <= 0 ? 100 : 100 / (1 + ratio),
  );
}

// ── Brokerage & statutory charges ───────────────────────────────────────────

class BrokerageResult {
  const BrokerageResult({
    required this.turnover,
    required this.brokerage,
    required this.stt,
    required this.exchangeTxn,
    required this.sebi,
    required this.gst,
    required this.stamp,
    required this.total,
    required this.grossPnl,
    required this.netPnl,
    required this.breakevenPoints,
  });

  final double turnover;
  final double brokerage;
  final double stt;
  final double exchangeTxn;
  final double sebi;
  final double gst;
  final double stamp;

  /// Every charge added together.
  final double total;
  final double grossPnl;
  final double netPnl;

  /// Points the price must move just to cover [total].
  final double breakevenPoints;
}

/// Indian equity/F&O charges as of FY 2025-26.
///
/// [broker] is `zerodha`, `upstox`, `icici` or `custom`; [segment] is
/// `eq_intra`, `eq_del`, `futures` or `options`. For `custom`, pass the
/// per-order fee in [customFlatFee] and the percentage in [customPct].
BrokerageResult calcBrokerage({
  required String broker,
  required String segment,
  required double qty,
  required double buyPrice,
  required double sellPrice,
  double customFlatFee = 20,
  double customPct = 0,
}) {
  final double buyValue = qty * buyPrice;
  final double sellValue = qty * sellPrice;
  final double turnover = buyValue + sellValue;

  // Per-leg brokerage. Delivery is free at every discount broker; ICICI
  // charges a percentage instead of a flat fee.
  double legBrokerage(double value) => switch ((broker, segment)) {
    (_, 'eq_del') when broker != 'icici' && broker != 'custom' => 0,
    ('icici', 'eq_del') => value * 0.0029,
    ('icici', _) => math.min(value * 0.0005, 20),
    ('custom', _) => customFlatFee + value * customPct / 100,
    (_, 'options') => 20,
    _ => math.min(value * 0.0003, 20),
  };
  final double brokerage = legBrokerage(buyValue) + legBrokerage(sellValue);

  // STT: delivery both legs, everything else sell side only.
  final double stt = switch (segment) {
    'eq_del' => turnover * 0.001,
    'eq_intra' => sellValue * 0.00025,
    'futures' => sellValue * 0.0002,
    'options' => sellValue * 0.001,
    _ => 0,
  };

  final double exchangeTxn = switch (segment) {
    'eq_del' || 'eq_intra' => turnover * 0.0000297,
    'futures' => turnover * 0.0000173,
    'options' => turnover * 0.0003503,
    _ => 0,
  };

  final double sebi = turnover * 0.000001;
  final double gst = (brokerage + exchangeTxn + sebi) * 0.18;

  final double stamp = switch (segment) {
    'eq_del' => buyValue * 0.00015,
    'eq_intra' => buyValue * 0.00003,
    'futures' => buyValue * 0.00002,
    'options' => buyValue * 0.00003,
    _ => 0,
  };

  final double total = brokerage + stt + exchangeTxn + sebi + gst + stamp;
  final double grossPnl = sellValue - buyValue;
  return BrokerageResult(
    turnover: turnover,
    brokerage: brokerage,
    stt: stt,
    exchangeTxn: exchangeTxn,
    sebi: sebi,
    gst: gst,
    stamp: stamp,
    total: total,
    grossPnl: grossPnl,
    netPnl: grossPnl - total,
    breakevenPoints: qty <= 0 ? 0 : total / qty,
  );
}

// ── Margin ──────────────────────────────────────────────────────────────────

class MarginResult {
  const MarginResult({
    required this.contractValue,
    required this.marginRequired,
    required this.leverage,
  });

  final double contractValue;
  final double marginRequired;

  /// Contract value per rupee of margin.
  final double leverage;
}

MarginResult calcMargin({
  required double lots,
  required double lotSize,
  required double price,
  required double marginPct,
}) {
  final double contractValue = lots * lotSize * price;
  final double marginRequired = contractValue * marginPct / 100;
  return MarginResult(
    contractValue: contractValue,
    marginRequired: marginRequired,
    leverage: marginRequired <= 0 ? 0 : contractValue / marginRequired,
  );
}

// ── Pivot points ────────────────────────────────────────────────────────────

class PivotResult {
  const PivotResult({
    required this.pp,
    required this.r1,
    required this.r2,
    required this.r3,
    required this.s1,
    required this.s2,
    required this.s3,
  });

  final double pp;
  final double r1;
  final double r2;
  final double r3;
  final double s1;
  final double s2;
  final double s3;
}

/// [method] is `standard`, `camarilla` or `woodie`.
PivotResult calcPivot({
  required double h,
  required double l,
  required double c,
  String method = 'standard',
}) {
  final double range = h - l;
  switch (method) {
    case 'camarilla':
      return PivotResult(
        pp: (h + l + c) / 3,
        r1: c + range * 1.1 / 12,
        r2: c + range * 1.1 / 6,
        r3: c + range * 1.1 / 4,
        s1: c - range * 1.1 / 12,
        s2: c - range * 1.1 / 6,
        s3: c - range * 1.1 / 4,
      );
    case 'woodie':
      final double pp = (h + l + 2 * c) / 4;
      return PivotResult(
        pp: pp,
        r1: 2 * pp - l,
        r2: pp + range,
        r3: h + 2 * (pp - l),
        s1: 2 * pp - h,
        s2: pp - range,
        s3: l - 2 * (h - pp),
      );
    default:
      final double pp = (h + l + c) / 3;
      return PivotResult(
        pp: pp,
        r1: 2 * pp - l,
        r2: pp + range,
        r3: h + 2 * (pp - l),
        s1: 2 * pp - h,
        s2: pp - range,
        s3: l - 2 * (h - pp),
      );
  }
}

// ── Fibonacci ───────────────────────────────────────────────────────────────

class FibResult {
  const FibResult({required this.levels, required this.extensions});

  /// Retracement levels as `(label, price)`, ordered shallow to deep.
  final List<(String, double)> levels;

  /// Extension targets beyond the swing.
  final List<(String, double)> extensions;
}

/// Retracements between [low] and [high]. In an uptrend the price retraces
/// down from [high]; in a downtrend it retraces up from [low].
FibResult calcFibonacci({
  required double high,
  required double low,
  bool uptrend = true,
}) {
  final double range = high - low;
  const List<double> ratios = <double>[0.236, 0.382, 0.5, 0.618, 0.786, 1.0];
  const List<double> extRatios = <double>[1.272, 1.618, 2.0];

  String label(double r) => '${(r * 100).toStringAsFixed(r == 0.5 ? 0 : 1)}%';
  double at(double r) => uptrend ? high - range * r : low + range * r;
  double ext(double r) =>
      uptrend ? high + range * (r - 1) : low - range * (r - 1);

  return FibResult(
    levels: <(String, double)>[
      for (final double r in ratios) (label(r), at(r)),
    ],
    extensions: <(String, double)>[
      for (final double r in extRatios) (label(r), ext(r)),
    ],
  );
}

// ── Trade P&L ───────────────────────────────────────────────────────────────

class PnlResult {
  const PnlResult({
    required this.grossPnl,
    required this.netPnl,
    required this.pnlPct,
    required this.investment,
    required this.isProfit,
  });

  final double grossPnl;
  final double netPnl;

  /// Return on the capital deployed, in percent.
  final double pnlPct;
  final double investment;
  final bool isProfit;
}

PnlResult calcPnl({
  required double entry,
  required double exit,
  required double qty,
  bool isLong = true,
  double brokerage = 0,
}) {
  final double gross = (isLong ? exit - entry : entry - exit) * qty;
  final double net = gross - brokerage;
  final double investment = entry * qty;
  return PnlResult(
    grossPnl: gross,
    netPnl: net,
    pnlPct: investment <= 0 ? 0 : net / investment * 100,
    investment: investment,
    isProfit: net >= 0,
  );
}

// ── ATR stop loss ───────────────────────────────────────────────────────────

class AtrStopResult {
  const AtrStopResult({
    required this.atr,
    required this.stopDistance,
    required this.longStop,
    required this.shortStop,
    required this.suggestedSize,
  });

  final double atr;

  /// [multiplier] × [atr] — how far the stop sits from entry.
  final double stopDistance;

  /// Entry − distance, floored at zero: price cannot go negative.
  final double longStop;

  /// Entry + distance.
  final double shortStop;

  /// Shares that keep the loss at the requested risk if the stop triggers.
  final double suggestedSize;
}

/// Volatility-based stop: a fixed multiple of Average True Range instead of a
/// round-number stop that sits where everyone else's does.
AtrStopResult calcAtrStop({
  required double atr,
  required double multiplier,
  required double entry,
  required double accountSize,
  required double riskPct,
}) {
  final double safeAtr = atr <= 0 ? 0 : atr;
  final double distance = safeAtr * multiplier;
  final double riskAmount = accountSize <= 0 || riskPct <= 0
      ? 0
      : accountSize * riskPct / 100;
  return AtrStopResult(
    atr: safeAtr,
    stopDistance: distance,
    longStop: math.max(0, entry - distance),
    shortStop: entry + distance,
    suggestedSize: distance <= 0 ? 0 : riskAmount / distance,
  );
}

// ── Kelly criterion ─────────────────────────────────────────────────────────

class KellyResult {
  const KellyResult({
    required this.fullKellyPct,
    required this.halfKellyPct,
    required this.quarterKellyPct,
    required this.riskAmount,
    required this.riskLevel,
  });

  /// `W − (1 − W) / R`, as a percentage of capital. Zero when the edge is
  /// negative — Kelly's answer to a losing system is to not bet.
  final double fullKellyPct;
  final double halfKellyPct;
  final double quarterKellyPct;

  /// Half Kelly applied to the account, in rupees.
  final double riskAmount;

  /// 'conservative' below 5% full Kelly, 'aggressive' above 25%.
  final String riskLevel;
}

/// Optimal fraction of capital to risk per trade for maximum long-run growth.
KellyResult calcKelly({
  required double winRatePct,
  required double avgWin,
  required double avgLoss,
  required double accountSize,
}) {
  final double w = (winRatePct / 100).clamp(0.0, 1.0);
  final double loss = avgLoss.abs();
  final double r = loss <= 0 ? 0 : avgWin / loss;
  final double raw = r <= 0 ? 0 : w - (1 - w) / r;
  final double full = math.max(0, raw * 100);
  return KellyResult(
    fullKellyPct: full,
    halfKellyPct: full / 2,
    quarterKellyPct: full / 4,
    riskAmount: accountSize <= 0 ? 0 : accountSize * (full / 2) / 100,
    riskLevel: switch (full) {
      < 5 => 'conservative',
      < 25 => 'moderate',
      _ => 'aggressive',
    },
  );
}

// ── Trade expectancy ────────────────────────────────────────────────────────

class ExpectancyResult {
  const ExpectancyResult({
    required this.expectancyR,
    required this.expectancyMoney,
    required this.monthlyExpected,
    required this.profitFactor,
    required this.verdict,
    required this.rollingCurve,
  });

  /// Expected R multiple per trade: `W × avgWinR − (1 − W) × avgLossR`.
  final double expectancyR;

  /// [expectancyR] in rupees, at the given risk per trade.
  final double expectancyMoney;
  final double monthlyExpected;

  /// Gross wins ÷ gross losses. Infinite when there are no losses.
  final double profitFactor;

  /// 'positive edge', 'breakeven' or 'no edge'.
  final String verdict;

  /// Cumulative R over a deterministic 20-trade sequence — the shape a run of
  /// this system tends to have, not a random simulation.
  final List<double> rollingCurve;
}

ExpectancyResult calcExpectancy({
  required double winRatePct,
  required double avgWinR,
  required double avgLossR,
  required double avgTradeRisk,
  required int tradesPerMonth,
}) {
  final double w = (winRatePct / 100).clamp(0.0, 1.0);
  final double lossR = avgLossR.abs();
  final double expectancy = w * avgWinR - (1 - w) * lossR;
  final double grossWin = w * avgWinR;
  final double grossLoss = (1 - w) * lossR;

  // Deal out 20 trades so wins land in proportion to the win rate rather than
  // all bunching at the front: trade i wins when the running quota allows it.
  const int n = 20;
  final List<double> curve = <double>[];
  double cumulative = 0;
  int wins = 0;
  for (int i = 1; i <= n; i++) {
    final bool win = wins < (w * i).round();
    if (win) wins++;
    cumulative += win ? avgWinR : -lossR;
    curve.add(cumulative);
  }

  return ExpectancyResult(
    expectancyR: expectancy,
    expectancyMoney: expectancy * avgTradeRisk,
    monthlyExpected: expectancy * avgTradeRisk * tradesPerMonth,
    profitFactor: grossLoss <= 0
        ? (grossWin <= 0 ? 0 : double.infinity)
        : grossWin / grossLoss,
    verdict: switch (expectancy) {
      > 0.05 => 'positive edge',
      >= -0.05 => 'breakeven',
      _ => 'no edge',
    },
    rollingCurve: curve,
  );
}

// ── Portfolio heat ──────────────────────────────────────────────────────────

class HeatResult {
  const HeatResult({
    required this.totalHeatPct,
    required this.totalHeatMoney,
    required this.riskOfRuinPct,
    required this.maxPositions,
    required this.heatLevel,
  });

  /// Sum of the risk on every open position, as a percentage of the account.
  final double totalHeatPct;
  final double totalHeatMoney;

  /// Chance of hitting [maxDrawdownPct] before doubling, from the classic
  /// gambler's-ruin approximation `((1 − edge) / (1 + edge)) ^ units`.
  final double riskOfRuinPct;

  /// How many positions of the current average risk fit inside 6% heat.
  final double maxPositions;

  /// 'safe' below 4%, 'elevated' to 7%, 'dangerous' above.
  final String heatLevel;
}

HeatResult calcPortfolioHeat({
  required double accountSize,
  required List<({double riskPct, String label})> openPositions,
  required double winRatePct,
  required double maxDrawdownPct,
}) {
  double heat = 0;
  for (final ({double riskPct, String label}) p in openPositions) {
    heat += p.riskPct.abs();
  }
  final double avgRisk = openPositions.isEmpty
      ? 0
      : heat / openPositions.length;

  // Edge as a fraction: a 55% win rate at 1:1 is a 10% edge.
  final double edge = ((winRatePct / 100).clamp(0.0, 1.0) * 2 - 1).clamp(
    -1.0,
    1.0,
  );
  final double units = avgRisk <= 0 ? 0 : maxDrawdownPct.abs() / avgRisk;
  double ruin;
  if (edge <= 0) {
    ruin = 100;
  } else if (units <= 0) {
    ruin = 0;
  } else {
    ruin = math.pow((1 - edge) / (1 + edge), units).toDouble() * 100;
  }

  return HeatResult(
    totalHeatPct: heat,
    totalHeatMoney: accountSize <= 0 ? 0 : accountSize * heat / 100,
    riskOfRuinPct: ruin.clamp(0.0, 100.0),
    maxPositions: avgRisk <= 0 ? 0 : 6 / avgRisk,
    heatLevel: switch (heat) {
      < 4 => 'safe',
      <= 7 => 'elevated',
      _ => 'dangerous',
    },
  );
}
