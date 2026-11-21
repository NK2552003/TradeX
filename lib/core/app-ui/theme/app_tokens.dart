import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';

/// Subscription tiers used across cards, badges and gating blocks.
enum AppTier { free, premium, enterprise }

/// Direction of a value, used for P/L coloring.
enum AppTrend { up, down, flat }

/// Market sentiment buckets for AI / news blocks.
enum AppSentiment { bullish, neutral, bearish }

/// Side of a trade.
enum AppSide { long, short }

/// Outcome of a closed trade.
enum AppOutcome { win, loss, breakeven, open }

/// App-level semantic tokens layered on top of [UiTheme].
///
/// Nothing here hardcodes a raw color: every value resolves from the
/// design-system palette so light and dark both stay correct.
class AppTokens {
  const AppTokens._();

  // --------------------------------------------------------------- P/L color

  static AppTrend trendOf(num value) {
    if (value > 0) return AppTrend.up;
    if (value < 0) return AppTrend.down;
    return AppTrend.flat;
  }

  static UiIntent plIntent(num value) => switch (trendOf(value)) {
    AppTrend.up => UiIntent.bullish,
    AppTrend.down => UiIntent.bearish,
    AppTrend.flat => UiIntent.neutral,
  };

  static Color pl(BuildContext context, num value) =>
      plIntent(value).color(context);

  static Color plSurface(BuildContext context, num value) =>
      pl(context, value).withValues(alpha: 0.12);

  static IconData plIcon(num value) => switch (trendOf(value)) {
    AppTrend.up => Icons.trending_up,
    AppTrend.down => Icons.trending_down,
    AppTrend.flat => Icons.trending_flat,
  };

  // ------------------------------------------------------------------- Tiers

  /// Twitter/X-style verified blue for Basic (`AppTier.premium`) subscribers.
  static const Color verifiedBasicBlue = Color(0xFF1D9BF0);

  /// Twitter/X-style verified gold/orange for Pro (`AppTier.enterprise`) subscribers.
  static const Color verifiedProOrange = Color(0xFFF59E0B);

  /// Resolves an [AppTier] from a raw backend string (`'free'`, `'basic'`,
  /// `'premium'`, `'pro'`, `'enterprise'`).
  static AppTier parseTier(String? raw, {AppTier fallback = AppTier.free}) {
    final String clean = (raw ?? '').trim().toLowerCase();
    return switch (clean) {
      'enterprise' || 'pro' => AppTier.enterprise,
      'premium' || 'basic' || 'starter' => AppTier.premium,
      'free' => AppTier.free,
      _ => fallback,
    };
  }

  /// Whether a user should display a plan-based verified tick.
  ///
  /// Free users (`AppTier.free`) never display a tick unless [isSpecialRole]
  /// is true (e.g. affiliate partner or desk superadmin).
  static bool hasVerifiedTick(AppTier tier, {bool isSpecialRole = false}) =>
      isSpecialRole || tier != AppTier.free;

  /// Returns the Twitter/X-style verified tick color for [tier]:
  /// - Basic (`AppTier.premium`): Blue (`#1D9BF0`)
  /// - Pro (`AppTier.enterprise`): Orange/Gold (`#F59E0B`)
  /// - Free (`AppTier.free`): Muted (hidden when [hasVerifiedTick] is used)
  static Color verifiedTickColor(AppTier tier, {Color? freeFallback}) =>
      switch (tier) {
        AppTier.enterprise => verifiedProOrange,
        AppTier.premium => verifiedBasicBlue,
        AppTier.free => freeFallback ?? verifiedBasicBlue,
      };

  static Color tierColor(BuildContext context, AppTier tier) {
    final UiColors c = context.uiColors;
    switch (tier) {
      case AppTier.free:
        return c.foregroundMuted;
      case AppTier.premium:
        return verifiedBasicBlue;
      case AppTier.enterprise:
        return verifiedProOrange;
    }
  }

  static UiIntent tierIntent(AppTier tier) => switch (tier) {
    AppTier.free => UiIntent.neutral,
    AppTier.premium => UiIntent.info,
    AppTier.enterprise => UiIntent.warning,
  };

  static String tierLabel(AppTier tier) => switch (tier) {
    AppTier.free => 'Free',
    AppTier.premium => 'Basic',
    AppTier.enterprise => 'Pro',
  };

  static IconData tierIcon(AppTier tier) => switch (tier) {
    AppTier.free => Icons.person_outline,
    AppTier.premium => Icons.verified_rounded,
    AppTier.enterprise => Icons.verified_rounded,
  };

  // --------------------------------------------------------------- Sentiment

  static AppSentiment sentimentOf(double score) {
    if (score >= 0.15) return AppSentiment.bullish;
    if (score <= -0.15) return AppSentiment.bearish;
    return AppSentiment.neutral;
  }

  static Color sentimentColor(BuildContext context, double score) =>
      switch (sentimentOf(score)) {
        AppSentiment.bullish => context.uiColors.bullish,
        AppSentiment.bearish => context.uiColors.bearish,
        AppSentiment.neutral => context.uiColors.foregroundMuted,
      };

  static String sentimentLabel(double score) => switch (sentimentOf(score)) {
    AppSentiment.bullish => 'Bullish',
    AppSentiment.bearish => 'Bearish',
    AppSentiment.neutral => 'Neutral',
  };

  // ------------------------------------------------------------------- Sides

  static UiIntent sideIntent(AppSide side) =>
      side == AppSide.long ? UiIntent.bullish : UiIntent.bearish;

  static String sideLabel(AppSide side) =>
      side == AppSide.long ? 'Long' : 'Short';

  static IconData sideIcon(AppSide side) =>
      side == AppSide.long ? Icons.north_east : Icons.south_east;

  static UiIntent outcomeIntent(AppOutcome outcome) => switch (outcome) {
    AppOutcome.win => UiIntent.bullish,
    AppOutcome.loss => UiIntent.bearish,
    AppOutcome.breakeven => UiIntent.neutral,
    AppOutcome.open => UiIntent.info,
  };

  static String outcomeLabel(AppOutcome outcome) => switch (outcome) {
    AppOutcome.win => 'Win',
    AppOutcome.loss => 'Loss',
    AppOutcome.breakeven => 'Break-even',
    AppOutcome.open => 'Open',
  };

  // -------------------------------------------------------------- Formatting

  static String money(num value, {String symbol = '₹', int decimals = 2}) {
    final String sign = value < 0 ? '-' : '';
    return '$sign$symbol${value.abs().toStringAsFixed(decimals)}';
  }

  static String signedMoney(
    num value, {
    String symbol = '₹',
    int decimals = 2,
  }) {
    final String sign = value > 0 ? '+' : (value < 0 ? '-' : '');
    return '$sign$symbol${value.abs().toStringAsFixed(decimals)}';
  }

  static String compactMoney(num value, {String symbol = '₹'}) =>
      '${value < 0 ? '-' : ''}$symbol${uiCompactNumber(value.abs())}';

  /// A price: whole units, thousands grouped, no trailing decimals — the form
  /// plan cards, checkout totals and invoices are written in. Prices live here
  /// rather than in each surface so a coupon total and a plan label can never be
  /// formatted two different ways.
  static String price(num value, {String symbol = '₹'}) {
    final String digits = value.abs().round().toString();
    final String grouped = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (Match m) => '${m[1]},',
    );
    return '${value < 0 ? '-' : ''}$symbol$grouped';
  }

  /// A capital figure in the notation an Indian desk reads it in — crore above a
  /// crore, lakh above a lakh, grouped rupees below that. Risk limits and
  /// allocation ceilings are quoted this way, so the conversion lives here rather
  /// than being divided out in each control that shows one.
  static String lakhCrore(num value, {String symbol = '₹'}) {
    final double abs = value.abs().toDouble();
    final String sign = value < 0 ? '-' : '';
    if (abs >= 10000000) {
      return '$sign$symbol${_trim(abs / 10000000)} Cr';
    }
    if (abs >= 100000) return '$sign$symbol${_trim(abs / 100000)} Lakh';
    return price(value, symbol: symbol);
  }

  /// One decimal, dropped when it adds nothing: 1.5 stays, 2.0 becomes 2.
  static String _trim(double value) {
    final String fixed = value.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  /// A tally — likes, replies, followers, members. Exact while it is short enough
  /// to read, abbreviated once it is not, so a post with a million likes takes no
  /// more room in the action bar than one with three.
  ///
  /// Distinct from [compactMoney], which abbreviates from 1,000 and carries a
  /// currency symbol: a count of 1,200 reads as "1.2K" but ₹1,200 must not.
  static String count(num value) {
    final double abs = value.abs().toDouble();
    final String sign = value < 0 ? '-' : '';
    if (abs >= 1000000000) return '$sign${_trim(abs / 1000000000)}B';
    if (abs >= 1000000) return '$sign${_trim(abs / 1000000)}M';
    if (abs >= 10000) return '$sign${_trim(abs / 1000)}K';
    return price(value, symbol: '');
  }

  static String percent(num value, {int decimals = 1}) =>
      '${value.toStringAsFixed(decimals)}%';

  static String signedPercent(num value, {int decimals = 2}) =>
      uiSignedPercent(value, decimals: decimals);

  static String rr(num value) => '${value.toStringAsFixed(2)}R';

  /// "2h ago" style relative label, no intl dependency.
  static String relativeTime(DateTime time, {DateTime? now}) {
    final Duration d = (now ?? DateTime.now()).difference(time);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    if (d.inDays < 30) return '${(d.inDays / 7).floor()}w ago';
    if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo ago';
    return '${(d.inDays / 365).floor()}y ago';
  }

  static const List<String> monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String shortDate(DateTime date) {
    final DateTime local = date.toLocal();
    return '${monthLabels[local.month - 1]} ${local.day}';
  }

  /// Date with the year, for documents that outlive the current one — invoices,
  /// receipts, exports and audit records.
  static String fullDate(DateTime date) {
    final DateTime local = date.toLocal();
    return '${monthLabels[local.month - 1]} ${local.day}, ${local.year}';
  }

  /// 24-hour wall clock, for surfaces where the exact moment matters more than
  /// how long ago it was — audit trails, message stamps, execution logs.
  static String clockTime(DateTime time) {
    final DateTime local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// Date and wall clock together, so a table row is never ambiguous about
  /// which day an entry belongs to.
  static String stamp(DateTime time) =>
      '${shortDate(time)} · ${clockTime(time)}';

  // -------------------------------------------------------------- Weekdays
  //
  // alphajournal deliberately keeps `intl` out of the UI layer (see the pubspec
  // note), so weekday names live here alongside [monthLabels] rather than
  // going through `DateFormat`.

  /// Monday-first, matching Dart's `DateTime.weekday` (Mon = 1 … Sun = 7).
  static const List<String> weekdayLabels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Three-letter weekday, e.g. "Mon".
  static String weekdayShort(DateTime date) =>
      weekdayLabels[date.toLocal().weekday - 1];

  /// Single-letter weekday for dense date chips, e.g. "M".
  static String weekdayInitial(DateTime date) =>
      weekdayLabels[date.toLocal().weekday - 1].substring(0, 1);

  /// Midnight of [date] in local time — strips the wall clock so two moments
  /// on the same calendar day compare equal.
  static DateTime dateOnly(DateTime date) {
    final DateTime local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Whether [a] and [b] fall on the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) {
    final DateTime localA = a.toLocal();
    final DateTime localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }
}
