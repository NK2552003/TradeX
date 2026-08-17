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

  static Color tierColor(BuildContext context, AppTier tier) {
    final UiColors c = context.uiColors;
    switch (tier) {
      case AppTier.free:
        return c.foregroundMuted;
      case AppTier.premium:
        return c.warning;
      case AppTier.enterprise:
        return c.primary;
    }
  }

  static UiIntent tierIntent(AppTier tier) => switch (tier) {
        AppTier.free => UiIntent.neutral,
        AppTier.premium => UiIntent.warning,
        AppTier.enterprise => UiIntent.primary,
      };

  static String tierLabel(AppTier tier) => switch (tier) {
        AppTier.free => 'Free',
        AppTier.premium => 'Premium',
        AppTier.enterprise => 'Enterprise',
      };

  static IconData tierIcon(AppTier tier) => switch (tier) {
        AppTier.free => Icons.person_outline,
        AppTier.premium => Icons.workspace_premium_outlined,
        AppTier.enterprise => Icons.apartment_outlined,
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

  static String signedMoney(num value,
      {String symbol = '₹', int decimals = 2}) {
    final String sign = value > 0 ? '+' : (value < 0 ? '-' : '');
    return '$sign$symbol${value.abs().toStringAsFixed(decimals)}';
  }

  static String compactMoney(num value, {String symbol = '₹'}) =>
      '${value < 0 ? '-' : ''}$symbol${uiCompactNumber(value.abs())}';

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

  static String shortDate(DateTime date) =>
      '${monthLabels[date.month - 1]} ${date.day}';
}
