import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Presentation-only models. No networking, no serialization assumptions —
/// map your real API/domain objects into these before rendering.

@immutable
class AppTrade {
  const AppTrade({
    required this.id,
    required this.ticker,
    required this.side,
    required this.entry,
    required this.exit,
    required this.openedAt,
    this.closedAt,
    this.stopLoss,
    this.target,
    this.size = 1,
    this.pnl = 0,
    this.pnlPercent = 0,
    this.rMultiple,
    this.outcome = AppOutcome.open,
    this.strategy,
    this.tags = const <String>[],
    this.notes,
    this.screenshotUrl,
    this.psychologyScore,
  });

  final String id;
  final String ticker;
  final AppSide side;
  final double entry;
  final double? exit;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double? stopLoss;
  final double? target;
  final double size;
  final double pnl;
  final double pnlPercent;
  final double? rMultiple;
  final AppOutcome outcome;
  final String? strategy;
  final List<String> tags;
  final String? notes;
  final String? screenshotUrl;
  final int? psychologyScore;
}

@immutable
class AppStrategy {
  const AppStrategy({
    required this.id,
    required this.name,
    this.summary,
    this.category,
    this.isPublic = false,
    this.isFavorite = false,
    this.trades = 0,
    this.winRate = 0,
    this.avgR = 0,
    this.netPnl = 0,
    this.updatedAt,
    this.versionCount = 1,
    this.equityCurve = const <double>[],
  });

  final String id;
  final String name;
  final String? summary;
  final String? category;
  final bool isPublic;
  final bool isFavorite;
  final int trades;
  final double winRate;
  final double avgR;
  final double netPnl;
  final DateTime? updatedAt;
  final int versionCount;
  final List<double> equityCurve;
}

@immutable
class AppStrategyVersion {
  const AppStrategyVersion({
    required this.id,
    required this.version,
    required this.savedAt,
    this.author,
    this.note,
    this.isCurrent = false,
  });

  final String id;
  final int version;
  final DateTime savedAt;
  final String? author;
  final String? note;
  final bool isCurrent;
}

@immutable
class AppTicker {
  const AppTicker({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    this.spark = const <double>[],
    this.note,
    this.category,
    this.isFavorite = false,
    this.currencySymbol = '₹',
  });

  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final List<double> spark;
  final String? note;
  final String? category;
  final bool isFavorite;
  final String currencySymbol;
}

@immutable
class AppPriceAlert {
  const AppPriceAlert({
    required this.id,
    required this.symbol,
    required this.targetPrice,
    required this.above,
    this.currentPrice,
    this.active = true,
    this.triggeredAt,
  });

  final String id;
  final String symbol;
  final double targetPrice;
  final bool above;
  final double? currentPrice;
  final bool active;
  final DateTime? triggeredAt;
}

@immutable
class AppStat {
  const AppStat({
    required this.label,
    required this.value,
    this.delta,
    this.icon,
    this.spark = const <double>[],
    this.suffix,
    this.formatter,
    this.intentOverride,
  });

  final String label;
  final num value;
  final num? delta;
  final IconData? icon;
  final List<double> spark;
  final String? suffix;
  final String Function(num value)? formatter;
  final AppTrend? intentOverride;
}

@immutable
class AppSeriesPoint {
  const AppSeriesPoint({required this.label, required this.value});

  final String label;
  final double value;
}

@immutable
class AppDayPnl {
  const AppDayPnl({required this.date, required this.pnl, this.trades = 0});

  final DateTime date;
  final double pnl;
  final int trades;
}

@immutable
class AppTrader {
  const AppTrader({
    required this.id,
    required this.handle,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.tier = AppTier.free,
    this.followers = 0,
    this.following = 0,
    this.winRate,
    this.verified = false,
    this.isFollowing = false,
    this.tradingStyle,
  });

  final String id;
  final String handle;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final AppTier tier;
  final int followers;
  final int following;
  final double? winRate;
  final bool verified;
  final bool isFollowing;
  final String? tradingStyle;
}

@immutable
class AppPost {
  const AppPost({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    this.type,
    this.tickers = const <String>[],
    this.imageUrl,
    this.attachments = const <AppPostAttachment>[],
    this.likes = 0,
    this.comments = 0,
    this.liked = false,
    this.saved = false,
  });

  final String id;
  final AppTrader author;
  final String body;
  final DateTime createdAt;
  final String? type;
  final List<String> tickers;
  final String? imageUrl;
  final List<AppPostAttachment> attachments;
  final int likes;
  final int comments;
  final bool liked;
  final bool saved;
}

abstract class AppPostAttachment {
  const AppPostAttachment();
}

class AppPostImageAttachment extends AppPostAttachment {
  const AppPostImageAttachment(this.url);
  final String url;
}

class AppPostChartAttachment extends AppPostAttachment {
  const AppPostChartAttachment(this.candles);
  final dynamic candles; // Expects List<UiCandle> from flutter-ui
}

class AppPostStrategyAttachment extends AppPostAttachment {
  const AppPostStrategyAttachment(this.name, {this.locked = false});
  final String name;
  final bool locked;
}

@immutable
class AppComment {
  const AppComment({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    this.likes = 0,
    this.liked = false,
  });

  final String id;
  final AppTrader author;
  final String body;
  final DateTime createdAt;
  final int likes;
  final bool liked;
}

@immutable
class AppConversation {
  const AppConversation({
    required this.id,
    required this.peer,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unread = 0,
  });

  final String id;
  final AppTrader peer;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unread;
}

@immutable
class AppChatMessage {
  const AppChatMessage({
    required this.id,
    required this.body,
    required this.fromMe,
    required this.sentAt,
    this.pending = false,
  });

  final String id;
  final String body;
  final bool fromMe;
  final DateTime sentAt;
  final bool pending;
}

@immutable
class AppAiInsight {
  const AppAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.confidence,
    this.sentimentScore,
    this.tickers = const <String>[],
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final double? confidence;
  final double? sentimentScore;
  final List<String> tickers;
  final DateTime? createdAt;
}

@immutable
class AppNewsItem {
  const AppNewsItem({
    required this.id,
    required this.headline,
    required this.source,
    required this.publishedAt,
    this.sentimentScore = 0,
    this.tickers = const <String>[],
    this.summary,
  });

  final String id;
  final String headline;
  final String source;
  final DateTime publishedAt;
  final double sentimentScore;
  final List<String> tickers;
  final String? summary;
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.createdAt,
    this.body,
    this.icon,
    this.category,
    this.read = false,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String? body;
  final IconData? icon;
  final String? category;
  final bool read;
}

@immutable
class AppPlan {
  const AppPlan({
    required this.tier,
    required this.amount,
    required this.priceLabel,
    required this.features,
    this.period = '/mo',
    this.highlighted = false,
    this.current = false,
    this.description,
  });

  final AppTier tier;

  /// What this plan charges per [period], as a number. Carried alongside
  /// [priceLabel] so a checkout sheet can apply a coupon or total up a cycle
  /// without parsing the rendered label back into arithmetic.
  final double amount;

  /// [amount] as the plan cards render it, currency symbol and grouping
  /// included. The catalogue formats it once so no surface invents its own.
  final String priceLabel;
  final List<String> features;
  final String period;
  final bool highlighted;
  final bool current;
  final String? description;
}

@immutable
class AppChecklistItem {
  const AppChecklistItem({
    required this.id,
    required this.label,
    this.description,
    this.done = false,
    this.icon,
  });

  final String id;
  final String label;
  final String? description;
  final bool done;
  final IconData? icon;
}

@immutable
class AppAchievement {
  const AppAchievement({
    required this.id,
    required this.title,
    required this.icon,
    this.description,
    this.unlocked = false,
    this.progress,
  });

  final String id;
  final String title;
  final IconData icon;
  final String? description;
  final bool unlocked;
  final double? progress;
}

@immutable
class AppNavActionItem {
  const AppNavActionItem({
    required this.id,
    required this.label,
    required this.icon,
    this.onPressed,
    this.destructive = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
}

@immutable
class AppNavItem {
  const AppNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badgeCount,
    this.tierLocked = false,
    this.subItems,
    this.actionItems,
    this.url,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final int? badgeCount;
  final bool tierLocked;
  final List<AppNavItem>? subItems;
  final List<AppNavActionItem>? actionItems;
  final String? url;
}

@immutable
class AppNavSection {
  const AppNavSection({required this.title, required this.items});

  final String? title;
  final List<AppNavItem> items;
}

@immutable
class AppCommandItem {
  const AppCommandItem({
    required this.id,
    required this.label,
    required this.icon,
    this.group,
    this.hint,
  });

  final String id;
  final String label;
  final IconData icon;
  final String? group;
  final String? hint;
}
