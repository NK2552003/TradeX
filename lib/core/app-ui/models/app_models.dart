import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../theme/app_tokens.dart';

/// Presentation-only models. No networking, no serialization assumptions —
/// map your real API/domain objects into these before rendering.

/// Counters derived from a markdown body.
///
/// Three records in this app own long-form markdown — a note, a journal entry
/// and a strategy playbook — and all three want the same cheap summary on a
/// card without re-parsing the source on every rebuild. Deriving them in one
/// place is what keeps "12 words" on a note card and on a journal card meaning
/// exactly the same thing.
@immutable
class AppMarkdownStats {
  const AppMarkdownStats({
    required this.wordCount,
    required this.checklistDone,
    required this.checklistTotal,
    required this.hasImages,
    required this.hasCode,
  });

  factory AppMarkdownStats.of(String content) {
    final Iterable<RegExpMatch> boxes = _checklistBox.allMatches(content);
    return AppMarkdownStats(
      wordCount: content
          .split(_whitespace)
          .where((String w) => w.trim().isNotEmpty)
          .length,
      checklistTotal: boxes.length,
      checklistDone: boxes
          .where((RegExpMatch m) => m.group(1)!.toLowerCase() == 'x')
          .length,
      hasImages: content.contains('!['),
      hasCode: content.contains('```'),
    );
  }

  static final RegExp _checklistBox = RegExp(
    r'^\s*[-*+]\s+\[( |x|X)\]',
    multiLine: true,
  );
  static final RegExp _whitespace = RegExp(r'\s+');

  /// A one-paragraph plain-text preview of a markdown body.
  ///
  /// List rows need the trader's *words*, and raw markdown shows them `##`,
  /// `**` and image refs instead. This is deliberately a stripper rather than a
  /// renderer: a card preview must not depend on a markdown widget, and a
  /// heading rendered at body size in a two-line clamp reads as noise anyway.
  ///
  /// Fenced code and images are dropped entirely — a preview that opens with
  /// three lines of Pine Script tells the reader nothing about the trade.
  static String excerpt(String content, {int maxChars = 180}) {
    if (content.trim().isEmpty) return '';
    String text = content
        .replaceAll(_fence, ' ')
        .replaceAll(_image, ' ')
        .replaceAllMapped(_link, (Match m) => m.group(1) ?? '')
        .replaceAll(_frontMatter, ' ')
        .replaceAll(_blockSyntax, '')
        .replaceAll(_inlineSyntax, '')
        .replaceAll(_whitespace, ' ')
        .trim();
    if (text.length <= maxChars) return text;
    // Cut on a word boundary so the ellipsis never lands mid-word.
    final int cut = text.lastIndexOf(' ', maxChars);
    text = text.substring(0, cut <= 0 ? maxChars : cut).trimRight();
    return '$text…';
  }

  static final RegExp _fence = RegExp(r'```[\s\S]*?```|~~~[\s\S]*?~~~');
  static final RegExp _image = RegExp(r'!\[[^\]]*\]\([^)]*\)');
  static final RegExp _link = RegExp(r'\[([^\]]*)\]\([^)]*\)');
  static final RegExp _frontMatter = RegExp(
    r'^---[\s\S]*?---',
    multiLine: true,
  );
  static final RegExp _blockSyntax = RegExp(
    r'^\s{0,3}(#{1,6}\s+|>\s?|[-*+]\s+(\[[ xX]\]\s*)?|\d+\.\s+|[-*_]{3,}\s*$)',
    multiLine: true,
  );
  static final RegExp _inlineSyntax = RegExp(r'[*_`~]|<[^>]+>');

  final int wordCount;
  final int checklistDone;
  final int checklistTotal;
  final bool hasImages;
  final bool hasCode;

  bool get hasChecklist => checklistTotal > 0;
}

/// A journal entry: the execution facts of one trade *plus* the long-form
/// markdown the trader wrote about it.
///
/// The numbers and the write-up live on one record rather than two because a
/// journal entry with no story is a broker statement, and a story with no
/// numbers cannot be ranked, filtered or rolled up. [content] is the markdown
/// body — [notes] survives as the one-line summary older screens render.
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
    this.userId = '',
    this.title = '',
    this.content = '',
    this.strategyId,
    this.linkedNoteIds = const <String>[],
    this.isPublic = false,
    this.updatedAt,
    this.wordCount = 0,
    this.checklistDone = 0,
    this.checklistTotal = 0,
    this.hasImages = false,
    this.hasCode = false,
    this.isFavorite = false,
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

  /// The strategy *name*, kept denormalised so a card can label the entry
  /// without resolving [strategyId] against the strategy library.
  final String? strategy;
  final List<String> tags;

  /// One-line summary. Rendered where there is no room for [content].
  final String? notes;
  final String? screenshotUrl;
  final int? psychologyScore;

  final String userId;

  /// Headline for the entry. Empty means "derive it" — see [displayTitle].
  final String title;

  /// Raw markdown: the thesis, the execution log and the review, in the
  /// trader's own words.
  final String content;

  /// The strategy this entry was traded under, if any.
  final String? strategyId;

  /// Trader notes attached to this entry. The mirror of
  /// [AppNote.linkedJournalIds].
  final List<String> linkedNoteIds;

  /// Whether this entry may be opened from a public post. Its linked notes and
  /// strategy keep their own visibility and never become public implicitly.
  final bool isPublic;

  final DateTime? updatedAt;
  final int wordCount;
  final int checklistDone;
  final int checklistTotal;
  final bool hasImages;
  final bool hasCode;
  final bool isFavorite;

  bool get isOpen => outcome == AppOutcome.open;

  bool get hasChecklist => checklistTotal > 0;

  bool get hasStory => content.trim().isNotEmpty;

  DateTime get sortDate => closedAt ?? openedAt;

  DateTime get editedAt => updatedAt ?? closedAt ?? openedAt;

  /// `RELIANCE long · 12 Mar` when the trader has not named the entry. A
  /// journal list of forty rows all called "Untitled" is unusable, and the
  /// ticker plus side is the label a trader would have typed anyway.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final String setup = strategy?.trim() ?? '';
    final String side0 = AppTokens.sideLabel(side);
    return setup.isEmpty ? '$ticker $side0' : '$ticker $side0 · $setup';
  }

  AppTrade withDerivedCounts() {
    final AppMarkdownStats stats = AppMarkdownStats.of(content);
    return copyWith(
      wordCount: stats.wordCount,
      checklistTotal: stats.checklistTotal,
      checklistDone: stats.checklistDone,
      hasImages: stats.hasImages,
      hasCode: stats.hasCode,
    );
  }

  AppTrade copyWith({
    String? id,
    String? ticker,
    AppSide? side,
    double? entry,
    double? exit,
    bool clearExit = false,
    DateTime? openedAt,
    DateTime? closedAt,
    bool clearClosedAt = false,
    double? stopLoss,
    double? target,
    double? size,
    double? pnl,
    double? pnlPercent,
    double? rMultiple,
    AppOutcome? outcome,
    String? strategy,
    List<String>? tags,
    String? notes,
    String? screenshotUrl,
    int? psychologyScore,
    String? userId,
    String? title,
    String? content,
    String? strategyId,
    bool clearStrategy = false,
    List<String>? linkedNoteIds,
    bool? isPublic,
    DateTime? updatedAt,
    int? wordCount,
    int? checklistDone,
    int? checklistTotal,
    bool? hasImages,
    bool? hasCode,
    bool? isFavorite,
  }) => AppTrade(
    id: id ?? this.id,
    ticker: ticker ?? this.ticker,
    side: side ?? this.side,
    entry: entry ?? this.entry,
    exit: clearExit ? null : (exit ?? this.exit),
    openedAt: openedAt ?? this.openedAt,
    closedAt: clearClosedAt ? null : (closedAt ?? this.closedAt),
    stopLoss: stopLoss ?? this.stopLoss,
    target: target ?? this.target,
    size: size ?? this.size,
    pnl: pnl ?? this.pnl,
    pnlPercent: pnlPercent ?? this.pnlPercent,
    rMultiple: rMultiple ?? this.rMultiple,
    outcome: outcome ?? this.outcome,
    // Detaching a strategy needs its own flag: `strategyId: null` is
    // indistinguishable from "leave it alone" in a copyWith.
    strategy: clearStrategy ? null : (strategy ?? this.strategy),
    tags: tags ?? this.tags,
    notes: notes ?? this.notes,
    screenshotUrl: screenshotUrl ?? this.screenshotUrl,
    psychologyScore: psychologyScore ?? this.psychologyScore,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    content: content ?? this.content,
    strategyId: clearStrategy ? null : (strategyId ?? this.strategyId),
    linkedNoteIds: linkedNoteIds ?? this.linkedNoteIds,
    isPublic: isPublic ?? this.isPublic,
    updatedAt: updatedAt ?? this.updatedAt,
    wordCount: wordCount ?? this.wordCount,
    checklistDone: checklistDone ?? this.checklistDone,
    checklistTotal: checklistTotal ?? this.checklistTotal,
    hasImages: hasImages ?? this.hasImages,
    hasCode: hasCode ?? this.hasCode,
    isFavorite: isFavorite ?? this.isFavorite,
  );
}

/// Where a strategy sits in its own lifecycle.
///
/// A playbook is not born tradeable: it is written, forward-tested, promoted,
/// and eventually retired. Without this, a library of twelve strategies gives
/// no way to tell the two the trader is actually risking money on from the ten
/// that are still ideas.
enum AppStrategyStatus {
  draft,
  testing,
  live,
  retired;

  String get label => switch (this) {
    AppStrategyStatus.draft => 'Draft',
    AppStrategyStatus.testing => 'Testing',
    AppStrategyStatus.live => 'Live',
    AppStrategyStatus.retired => 'Retired',
  };

  IconData get icon => switch (this) {
    AppStrategyStatus.draft => Icons.edit_note_rounded,
    AppStrategyStatus.testing => Icons.science_outlined,
    AppStrategyStatus.live => Icons.play_circle_outline_rounded,
    AppStrategyStatus.retired => Icons.archive_outlined,
  };

  UiIntent get intent => switch (this) {
    AppStrategyStatus.draft => UiIntent.neutral,
    AppStrategyStatus.testing => UiIntent.warning,
    AppStrategyStatus.live => UiIntent.bullish,
    AppStrategyStatus.retired => UiIntent.neutral,
  };

  /// Value stored in the backend `status` column.
  String get wireId => name;

  static AppStrategyStatus fromId(String? id) =>
      AppStrategyStatus.values.firstWhere(
        (AppStrategyStatus s) => s.wireId == id || s.name == id,
        orElse: () => AppStrategyStatus.draft,
      );
}

/// A strategy note: the rules of a playbook, its rolled-up performance, and
/// everything it is linked to.
///
/// [content] is the playbook itself in markdown — entry and exit conditions,
/// invalidation, sizing. [summary] is the one-paragraph version a card shows.
/// The performance fields are *derived from the journal*, never typed: they are
/// what the linked entries in [linkedJournalIds] actually did.
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
    this.userId = '',
    this.content = '',
    this.status = AppStrategyStatus.draft,
    this.tags = const <String>[],
    this.linkedTickers = const <String>[],
    this.linkedNoteIds = const <String>[],
    this.linkedJournalIds = const <String>[],
    this.createdAt,
    this.wordCount = 0,
    this.checklistDone = 0,
    this.checklistTotal = 0,
    this.hasImages = false,
    this.hasCode = false,
  });

  final String id;
  final String name;

  /// The elevator pitch. One paragraph, plain text, safe to render in a card.
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

  final String userId;

  /// Raw markdown: the playbook. The only authoritative copy of the rules.
  final String content;
  final AppStrategyStatus status;
  final List<String> tags;

  /// Instruments the playbook is written for.
  final List<String> linkedTickers;

  /// Trader notes about this strategy. The mirror of [AppNote.strategyId].
  final List<String> linkedNoteIds;

  /// Journal entries traded under this playbook. The mirror of
  /// [AppTrade.strategyId].
  final List<String> linkedJournalIds;

  final DateTime? createdAt;
  final int wordCount;
  final int checklistDone;
  final int checklistTotal;
  final bool hasImages;
  final bool hasCode;

  bool get hasChecklist => checklistTotal > 0;

  bool get hasPlaybook => content.trim().isNotEmpty;

  bool get isEmpty => name.trim().isEmpty && content.trim().isEmpty;

  /// Total records pointing at this playbook — the number the library card puts
  /// next to the link icon.
  int get linkCount =>
      linkedNoteIds.length + linkedJournalIds.length + linkedTickers.length;

  AppStrategy withDerivedCounts() {
    final AppMarkdownStats stats = AppMarkdownStats.of(content);
    return copyWith(
      wordCount: stats.wordCount,
      checklistTotal: stats.checklistTotal,
      checklistDone: stats.checklistDone,
      hasImages: stats.hasImages,
      hasCode: stats.hasCode,
    );
  }

  AppStrategy copyWith({
    String? id,
    String? name,
    String? summary,
    String? category,
    bool? isPublic,
    bool? isFavorite,
    int? trades,
    double? winRate,
    double? avgR,
    double? netPnl,
    DateTime? updatedAt,
    int? versionCount,
    List<double>? equityCurve,
    String? userId,
    String? content,
    AppStrategyStatus? status,
    List<String>? tags,
    List<String>? linkedTickers,
    List<String>? linkedNoteIds,
    List<String>? linkedJournalIds,
    DateTime? createdAt,
    int? wordCount,
    int? checklistDone,
    int? checklistTotal,
    bool? hasImages,
    bool? hasCode,
  }) => AppStrategy(
    id: id ?? this.id,
    name: name ?? this.name,
    summary: summary ?? this.summary,
    category: category ?? this.category,
    isPublic: isPublic ?? this.isPublic,
    isFavorite: isFavorite ?? this.isFavorite,
    trades: trades ?? this.trades,
    winRate: winRate ?? this.winRate,
    avgR: avgR ?? this.avgR,
    netPnl: netPnl ?? this.netPnl,
    updatedAt: updatedAt ?? this.updatedAt,
    versionCount: versionCount ?? this.versionCount,
    equityCurve: equityCurve ?? this.equityCurve,
    userId: userId ?? this.userId,
    content: content ?? this.content,
    status: status ?? this.status,
    tags: tags ?? this.tags,
    linkedTickers: linkedTickers ?? this.linkedTickers,
    linkedNoteIds: linkedNoteIds ?? this.linkedNoteIds,
    linkedJournalIds: linkedJournalIds ?? this.linkedJournalIds,
    createdAt: createdAt ?? this.createdAt,
    wordCount: wordCount ?? this.wordCount,
    checklistDone: checklistDone ?? this.checklistDone,
    checklistTotal: checklistTotal ?? this.checklistTotal,
    hasImages: hasImages ?? this.hasImages,
    hasCode: hasCode ?? this.hasCode,
  );
}

/// One saved revision of a strategy playbook.
///
/// [content] is the full body as it stood at [savedAt], not a diff. Rules
/// documents are small and a restore has to be exact, so storing the snapshot
/// costs little and removes any chance of a replay producing a body the trader
/// never wrote.
@immutable
class AppStrategyVersion {
  const AppStrategyVersion({
    required this.id,
    required this.version,
    required this.savedAt,
    this.author,
    this.note,
    this.isCurrent = false,
    this.strategyId = '',
    this.content = '',
    this.summary,
    this.wordCount = 0,
  });

  final String id;
  final int version;
  final DateTime savedAt;
  final String? author;

  /// The changelog line the trader wrote when saving.
  final String? note;
  final bool isCurrent;
  final String strategyId;

  /// Full markdown snapshot of the playbook at this revision.
  final String content;
  final String? summary;
  final int wordCount;

  String get label => 'v$version';

  AppStrategyVersion copyWith({
    String? id,
    int? version,
    DateTime? savedAt,
    String? author,
    String? note,
    bool? isCurrent,
    String? strategyId,
    String? content,
    String? summary,
    int? wordCount,
  }) => AppStrategyVersion(
    id: id ?? this.id,
    version: version ?? this.version,
    savedAt: savedAt ?? this.savedAt,
    author: author ?? this.author,
    note: note ?? this.note,
    isCurrent: isCurrent ?? this.isCurrent,
    strategyId: strategyId ?? this.strategyId,
    content: content ?? this.content,
    summary: summary ?? this.summary,
    wordCount: wordCount ?? this.wordCount,
  );
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
    this.writingAttachment,
    this.likes = 0,
    this.comments = 0,
    this.views = 0,
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

  /// The one optional Writing Desk source carried by this post. Kept separate
  /// from media attachments so multiple images can never accidentally permit
  /// multiple notes, journal entries or strategies.
  final AppWritingRecordPostAttachment? writingAttachment;
  final int likes;
  final int comments;
  final int views;
  final bool liked;
  final bool saved;
}

abstract class AppPostAttachment {
  const AppPostAttachment();
}

/// Marker for the single record-level attachment slot on [AppPost].
abstract class AppWritingRecordPostAttachment extends AppPostAttachment {
  const AppWritingRecordPostAttachment();
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

/// What a note is *for*. Drives the icon, the colour of its type chip and the
/// starter template offered when a note of that kind is created.
enum AppNoteType {
  general,
  analysis,
  plan,
  review,
  idea,
  cheatSheet;

  String get label => switch (this) {
    AppNoteType.general => 'Note',
    AppNoteType.analysis => 'Analysis',
    AppNoteType.plan => 'Trade Plan',
    AppNoteType.review => 'Review',
    AppNoteType.idea => 'Idea',
    AppNoteType.cheatSheet => 'Cheat Sheet',
  };

  IconData get icon => switch (this) {
    AppNoteType.general => Icons.sticky_note_2_outlined,
    AppNoteType.analysis => Icons.query_stats_rounded,
    AppNoteType.plan => Icons.flag_outlined,
    AppNoteType.review => Icons.rate_review_outlined,
    AppNoteType.idea => Icons.lightbulb_outline_rounded,
    AppNoteType.cheatSheet => Icons.menu_book_outlined,
  };

  /// Semantic colour for the type chip. `UiIntent` has no `secondary`, so a
  /// cheat sheet borrows `neutral` — it is reference material, not a signal.
  UiIntent get intent => switch (this) {
    AppNoteType.general => UiIntent.neutral,
    AppNoteType.analysis => UiIntent.info,
    AppNoteType.plan => UiIntent.primary,
    AppNoteType.review => UiIntent.warning,
    AppNoteType.idea => UiIntent.bullish,
    AppNoteType.cheatSheet => UiIntent.neutral,
  };

  /// The value stored in the backend `note_type` column. Snake case, because
  /// every other column value in `database/` is — which is why this is not just
  /// [name]: `cheatSheet` goes over the wire as `cheat_sheet`.
  String get wireId => switch (this) {
    AppNoteType.cheatSheet => 'cheat_sheet',
    _ => name,
  };

  /// Parses the wire value used by the backend `note_type` column, accepting
  /// both [wireId] and the raw enum [name], and falling back to
  /// [AppNoteType.general] for anything a newer server sends.
  static AppNoteType fromId(String? id) => AppNoteType.values.firstWhere(
    (AppNoteType t) => t.wireId == id || t.name == id,
    orElse: () => AppNoteType.general,
  );
}

/// A long-form markdown note. [content] is the raw markdown source — the only
/// authoritative copy of the body. Everything else on this model is either
/// user-set metadata or a counter derived from the source at save time, so a
/// list of notes can be rendered without parsing markdown for every card.
@immutable
class AppNote {
  const AppNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.userId = '',
    this.noteType = AppNoteType.general,
    this.tags = const <String>[],
    this.linkedTickers = const <String>[],
    this.strategyId,
    this.strategyName,
    this.linkedJournalIds = const <String>[],
    this.isPublic = false,
    this.wordCount = 0,
    this.checklistDone = 0,
    this.checklistTotal = 0,
    this.hasImages = false,
    this.hasCode = false,
    this.viewCount = 0,
    this.likeCount = 0,
    this.liked = false,
    this.isFavorite = false,
    this.comments = const <AppNoteComment>[],
  });

  final String id;
  final String userId;
  final String title;

  /// Raw markdown. Never pre-rendered HTML — the preview and the PDF export
  /// both parse this, so a stored rendering would drift from one of them.
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AppNoteType noteType;
  final List<String> tags;
  final List<String> linkedTickers;
  final String? strategyId;
  final String? strategyName;
  final List<String> linkedJournalIds;
  final bool isPublic;
  final int wordCount;
  final int checklistDone;
  final int checklistTotal;
  final bool hasImages;
  final bool hasCode;
  final int viewCount;
  final int likeCount;
  final bool liked;
  final bool isFavorite;
  final List<AppNoteComment> comments;

  bool get hasChecklist => checklistTotal > 0;

  bool get isEmpty => title.trim().isEmpty && content.trim().isEmpty;

  /// Re-derives [wordCount], the checklist tallies and the media flags from
  /// [content] so a caller that edits the body never has to keep the counters
  /// in step by hand.
  AppNote withDerivedCounts() {
    final AppMarkdownStats stats = AppMarkdownStats.of(content);
    return copyWith(
      wordCount: stats.wordCount,
      checklistTotal: stats.checklistTotal,
      checklistDone: stats.checklistDone,
      hasImages: stats.hasImages,
      hasCode: stats.hasCode,
    );
  }

  AppNote copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    AppNoteType? noteType,
    List<String>? tags,
    List<String>? linkedTickers,
    String? strategyId,
    String? strategyName,
    bool clearStrategy = false,
    List<String>? linkedJournalIds,
    bool? isPublic,
    int? wordCount,
    int? checklistDone,
    int? checklistTotal,
    bool? hasImages,
    bool? hasCode,
    int? viewCount,
    int? likeCount,
    bool? liked,
    bool? isFavorite,
    List<AppNoteComment>? comments,
  }) => AppNote(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    noteType: noteType ?? this.noteType,
    tags: tags ?? this.tags,
    linkedTickers: linkedTickers ?? this.linkedTickers,
    // Detaching a strategy needs its own flag: `strategyId: null` is
    // indistinguishable from "leave it alone" in a copyWith.
    strategyId: clearStrategy ? null : (strategyId ?? this.strategyId),
    strategyName: clearStrategy ? null : (strategyName ?? this.strategyName),
    linkedJournalIds: linkedJournalIds ?? this.linkedJournalIds,
    isPublic: isPublic ?? this.isPublic,
    wordCount: wordCount ?? this.wordCount,
    checklistDone: checklistDone ?? this.checklistDone,
    checklistTotal: checklistTotal ?? this.checklistTotal,
    hasImages: hasImages ?? this.hasImages,
    hasCode: hasCode ?? this.hasCode,
    viewCount: viewCount ?? this.viewCount,
    likeCount: likeCount ?? this.likeCount,
    liked: liked ?? this.liked,
    isFavorite: isFavorite ?? this.isFavorite,
    comments: comments ?? this.comments,
  );
}

@immutable
class AppNoteComment {
  const AppNoteComment({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String authorName;
  final String body;
  final DateTime createdAt;
}

/// How much of a note card is shown in the list.
enum AppNoteDensity {
  /// Title and footer only — the most notes per screen.
  titleOnly,

  /// Title, body preview and footer.
  comfortable,

  /// Everything, including the tag row.
  full,
}

/// Ordering applied to the note list.
enum AppNoteSort {
  recentlyUpdated,
  recentlyCreated,
  titleAscending,
  longestFirst;

  String get label => switch (this) {
    AppNoteSort.recentlyUpdated => 'Last edited',
    AppNoteSort.recentlyCreated => 'Newest',
    AppNoteSort.titleAscending => 'Title A–Z',
    AppNoteSort.longestFirst => 'Longest',
  };
}

/// Ordering applied to the journal list.
///
/// A journal is read two ways: chronologically, to reconstruct a week, and by
/// magnitude, to find the trade that actually moved the account. Both belong
/// here — sorting by P/L is the fastest route to the entry worth re-reading.
enum AppJournalSort {
  recentFirst,
  oldestFirst,
  biggestWin,
  biggestLoss,
  bestR,
  worstR,
  tickerAscending;

  String get label => switch (this) {
    AppJournalSort.recentFirst => 'Newest',
    AppJournalSort.oldestFirst => 'Oldest',
    AppJournalSort.biggestWin => 'Biggest win',
    AppJournalSort.biggestLoss => 'Biggest loss',
    AppJournalSort.bestR => 'Best R',
    AppJournalSort.worstR => 'Worst R',
    AppJournalSort.tickerAscending => 'Ticker A–Z',
  };
}

/// Ordering applied to the strategy library.
enum AppStrategySort {
  recentlyUpdated,
  bestWinRate,
  bestNetPnl,
  mostTraded,
  nameAscending;

  String get label => switch (this) {
    AppStrategySort.recentlyUpdated => 'Last edited',
    AppStrategySort.bestWinRate => 'Win rate',
    AppStrategySort.bestNetPnl => 'Net P/L',
    AppStrategySort.mostTraded => 'Most traded',
    AppStrategySort.nameAscending => 'Name A–Z',
  };
}

/// The four record types that can be linked to one another.
///
/// Trader notes, journal entries and strategy playbooks form a triangle, and
/// tickers hang off all three. One enum for all four means a "linked records"
/// panel, a link picker and a `tradex://` URL can be written once instead of
/// three times per direction.
enum AppLinkKind {
  note,
  journal,
  strategy,
  ticker,
  aiCopilot,
  communityPost,
  messageThread;

  String get label => switch (this) {
    AppLinkKind.note => 'Note',
    AppLinkKind.journal => 'Journal entry',
    AppLinkKind.strategy => 'Strategy',
    AppLinkKind.ticker => 'Ticker',
    AppLinkKind.aiCopilot => 'AI Copilot',
    AppLinkKind.communityPost => 'Community Post',
    AppLinkKind.messageThread => 'Conversation',
  };

  /// Plural used in section headers.
  String get plural => switch (this) {
    AppLinkKind.note => 'Notes',
    AppLinkKind.journal => 'Journal entries',
    AppLinkKind.strategy => 'Strategies',
    AppLinkKind.ticker => 'Tickers',
    AppLinkKind.aiCopilot => 'AI Copilots',
    AppLinkKind.communityPost => 'Community Posts',
    AppLinkKind.messageThread => 'Conversations',
  };

  IconData get icon => switch (this) {
    AppLinkKind.note => Icons.sticky_note_2_outlined,
    AppLinkKind.journal => Icons.menu_book_outlined,
    AppLinkKind.strategy => Icons.account_tree_outlined,
    AppLinkKind.ticker => Icons.candlestick_chart_outlined,
    AppLinkKind.aiCopilot => Icons.auto_awesome_rounded,
    AppLinkKind.communityPost => Icons.public_rounded,
    AppLinkKind.messageThread => Icons.chat_bubble_outline_rounded,
  };

  UiIntent get intent => switch (this) {
    AppLinkKind.note => UiIntent.info,
    AppLinkKind.journal => UiIntent.primary,
    AppLinkKind.strategy => UiIntent.bullish,
    AppLinkKind.ticker => UiIntent.warning,
    AppLinkKind.aiCopilot => UiIntent.primary,
    AppLinkKind.communityPost => UiIntent.info,
    AppLinkKind.messageThread => UiIntent.success,
  };

  /// The workspace destination id this kind opens in, matching the ids
  /// `RoleNavigationConfig` uses. Tickers open the matching Markets detail.
  String? get destinationId => switch (this) {
    AppLinkKind.note => 'notes',
    AppLinkKind.journal => 'journal',
    AppLinkKind.strategy => 'strategies',
    AppLinkKind.ticker => 'market',
    AppLinkKind.aiCopilot => 'ai_copilot',
    AppLinkKind.communityPost => 'community_feed',
    AppLinkKind.messageThread => 'messages',
  };

  /// Host segment used by `tradex://` deep links.
  String get host => switch (this) {
    AppLinkKind.note => 'note',
    AppLinkKind.journal => 'journal',
    AppLinkKind.strategy => 'strategy',
    AppLinkKind.ticker => 'ticker',
    AppLinkKind.aiCopilot => 'copilot',
    AppLinkKind.communityPost => 'community',
    AppLinkKind.messageThread => 'message',
  };

  static AppLinkKind? fromHost(String? host) => switch (host) {
    'note' || 'notes' => AppLinkKind.note,
    'journal' || 'entry' || 'trade' => AppLinkKind.journal,
    'strategy' || 'strategies' => AppLinkKind.strategy,
    'ticker' || 'symbol' => AppLinkKind.ticker,
    'copilot' || 'ai' || 'ai_copilot' => AppLinkKind.aiCopilot,
    'community' || 'post' || 'posts' => AppLinkKind.communityPost,
    'message' || 'messages' || 'chat' => AppLinkKind.messageThread,
    _ => null,
  };
}

/// One end of a link, flattened for display.
///
/// Resolved from the real record so a panel never has to know whether it is
/// showing a note, a trade or a playbook — the graph hands it labels, and the
/// [kind] carries the colour and icon.
@immutable
class AppLinkRef {
  const AppLinkRef({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    this.meta,
    this.intent,
    this.icon,
    this.missing = false,
  });

  /// A link whose target no longer resolves — a note the trader deleted, say.
  /// Shown greyed out rather than dropped, because silently losing a link the
  /// trader created is worse than telling them it broke.
  factory AppLinkRef.missing(AppLinkKind kind, String id) => AppLinkRef(
    kind: kind,
    id: id,
    title: 'Deleted ${kind.label.toLowerCase()}',
    subtitle: id,
    missing: true,
  );

  final AppLinkKind kind;
  final String id;
  final String title;
  final String? subtitle;

  /// Right-aligned trailing text — a P/L, a win rate, a relative timestamp.
  final String? meta;

  /// Overrides [AppLinkKind.intent], so a losing journal entry can read red.
  final UiIntent? intent;
  final IconData? icon;
  final bool missing;

  UiIntent get effectiveIntent =>
      missing ? UiIntent.neutral : (intent ?? kind.intent);

  IconData get effectiveIcon => icon ?? kind.icon;

  /// The internal URL that reopens this record. Written into markdown bodies by
  /// the editors and parsed back by `AppDeepLink`.
  Uri get uri => Uri(scheme: 'tradex', host: kind.host, path: '/$id');

  /// The markdown a link inserter drops at the cursor.
  String get markdownLink => '[$title]($uri)';
}

/// Everything linked to one record, grouped by kind.
@immutable
class AppLinkBundle {
  const AppLinkBundle({
    this.notes = const <AppLinkRef>[],
    this.journal = const <AppLinkRef>[],
    this.strategies = const <AppLinkRef>[],
    this.tickers = const <AppLinkRef>[],
  });

  static const AppLinkBundle empty = AppLinkBundle();

  final List<AppLinkRef> notes;
  final List<AppLinkRef> journal;
  final List<AppLinkRef> strategies;
  final List<AppLinkRef> tickers;

  bool get isEmpty =>
      notes.isEmpty && journal.isEmpty && strategies.isEmpty && tickers.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int get length =>
      notes.length + journal.length + strategies.length + tickers.length;

  List<AppLinkRef> get all => <AppLinkRef>[
    ...strategies,
    ...journal,
    ...notes,
    ...tickers,
  ];

  List<AppLinkRef> of(AppLinkKind kind) => switch (kind) {
    AppLinkKind.note => notes,
    AppLinkKind.journal => journal,
    AppLinkKind.strategy => strategies,
    AppLinkKind.ticker => tickers,
    _ => const <AppLinkRef>[],
  };
}

/// Buckets the calculator hub groups its tools into.
enum AppCalculatorCategory {
  trading,
  options,
  investing,
  currency,
  tax;

  String get label => switch (this) {
    AppCalculatorCategory.trading => 'Trading',
    AppCalculatorCategory.options => 'Options',
    AppCalculatorCategory.investing => 'Investing',
    AppCalculatorCategory.currency => 'Currency',
    AppCalculatorCategory.tax => 'Tax',
  };

  IconData get icon => switch (this) {
    AppCalculatorCategory.trading => Icons.candlestick_chart_outlined,
    AppCalculatorCategory.options => Icons.auto_graph_outlined,
    AppCalculatorCategory.investing => Icons.savings_outlined,
    AppCalculatorCategory.currency => Icons.currency_exchange_outlined,
    AppCalculatorCategory.tax => Icons.receipt_long_outlined,
  };

  UiIntent get intent => switch (this) {
    AppCalculatorCategory.trading => UiIntent.primary,
    AppCalculatorCategory.options => UiIntent.info,
    AppCalculatorCategory.investing => UiIntent.success,
    AppCalculatorCategory.currency => UiIntent.warning,
    AppCalculatorCategory.tax => UiIntent.neutral,
  };
}

/// Catalog entry for one calculator. Pure presentation metadata — the maths
/// lives in `lib/features/calculators/logic/`, the screen in `.../ui/`.
@immutable
class AppCalculatorMeta {
  const AppCalculatorMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    this.tags = const <String>[],
  });

  /// Stable key used for routing inside the calculators feature.
  final String id;
  final String name;
  final String description;
  final AppCalculatorCategory category;
  final IconData icon;

  /// Extra search terms — the hub matches these as well as [name].
  final List<String> tags;
}
