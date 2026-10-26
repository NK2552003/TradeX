import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Domain models for the AI Assistant feature.
///
/// The conversational primitives ([AppAiMessage], [AppAiPrompt], [AppAiInsight],
/// [AppAiRole]) are reused from the shared `app-ui` layer so the pre-built
/// [AppAiChatBlock] / [AppAiInsightsBlock] render them directly. The types here
/// add only what the assistant feature needs on top: threads, personas, the
/// "create anything" targets, chart setups and the drafts the create flow emits.
///
/// Everything is `@immutable`; nothing holds literal copy — seed content lives in
/// `data/ai_assistant_seed_data.dart`.

// ===========================================================================
// Persona
// ---------------------------------------------------------------------------

/// The analytical lens the copilot answers through. Changes the opening line
/// and the emphasis appended to a reply so the same synthesized intelligence
/// reads differently. Mirrors the persona set proven in the community copilot.
enum AiPersona { momentum, swing, macro, options }

extension AiPersonaX on AiPersona {
  String get label => switch (this) {
    AiPersona.momentum => 'Momentum Scalper',
    AiPersona.swing => 'Swing Strategist',
    AiPersona.macro => 'Macro Economist',
    AiPersona.options => 'Options Quant',
  };

  String get shortLabel => switch (this) {
    AiPersona.momentum => 'Scalper',
    AiPersona.swing => 'Swing',
    AiPersona.macro => 'Macro',
    AiPersona.options => 'Quant',
  };

  /// One-line description shown in the persona selector.
  String get tagline => switch (this) {
    AiPersona.momentum => 'Intraday momentum & order flow',
    AiPersona.swing => 'Multi-day structure & positioning',
    AiPersona.macro => 'Liquidity, rates & cross-asset flow',
    AiPersona.options => 'Volatility surface & Greeks',
  };

  IconData get icon => switch (this) {
    AiPersona.momentum => Icons.bolt_rounded,
    AiPersona.swing => Icons.timeline_rounded,
    AiPersona.macro => Icons.public_rounded,
    AiPersona.options => Icons.functions_rounded,
  };

  /// Opening line prefixed to every answer for this persona.
  String get opener => switch (this) {
    AiPersona.momentum => '⚡ Scalper lens — intraday momentum & order flow:',
    AiPersona.swing => '📈 Swing lens — multi-day structure & positioning:',
    AiPersona.macro => '🌐 Macro lens — liquidity, rates & cross-asset flow:',
    AiPersona.options => '🧮 Quant lens — volatility surface & Greeks:',
  };

  /// Emphasis note appended to every answer for this persona.
  String get emphasis => switch (this) {
    AiPersona.momentum =>
      'Scalper note: only trigger on a confirmed break-and-retest; kill the idea if 1m momentum stalls.',
    AiPersona.swing =>
      'Swing note: scale in against the higher-timeframe demand and hold for the measured move.',
    AiPersona.macro =>
      'Macro note: size down into high-impact prints; the tape follows liquidity, not the narrative.',
    AiPersona.options =>
      'Quant note: express this via defined-risk spreads while IV rank is elevated to stay theta-neutral.',
  };
}

// ===========================================================================
// Create targets
// ---------------------------------------------------------------------------

/// The kinds of records the assistant can generate. Four produce a real record
/// through a feature repository; [chartAnalysis] instead opens the staged chart
/// analyzer overlay.
enum AiCreateTarget { note, journal, strategy, post, chartAnalysis }

extension AiCreateTargetX on AiCreateTarget {
  String get label => switch (this) {
    AiCreateTarget.note => 'Research note',
    AiCreateTarget.journal => 'Journal trade',
    AiCreateTarget.strategy => 'Strategy playbook',
    AiCreateTarget.post => 'Community post',
    AiCreateTarget.chartAnalysis => 'Chart analysis',
  };

  String get description => switch (this) {
    AiCreateTarget.note =>
      'Draft a structured technical note with levels and rationale.',
    AiCreateTarget.journal =>
      'Log a trade idea with entry, stop, targets and R:R.',
    AiCreateTarget.strategy =>
      'Turn a repeatable setup into a rules-based playbook.',
    AiCreateTarget.post => 'Share a setup or take with the community feed.',
    AiCreateTarget.chartAnalysis =>
      'Run pattern detection and extract a trade plan from a chart.',
  };

  /// Verb shown on the primary action button.
  String get actionLabel => switch (this) {
    AiCreateTarget.note => 'Create note',
    AiCreateTarget.journal => 'Log trade',
    AiCreateTarget.strategy => 'Create playbook',
    AiCreateTarget.post => 'Publish post',
    AiCreateTarget.chartAnalysis => 'Analyze chart',
  };

  IconData get icon => switch (this) {
    AiCreateTarget.note => Icons.sticky_note_2_outlined,
    AiCreateTarget.journal => Icons.menu_book_outlined,
    AiCreateTarget.strategy => Icons.account_tree_outlined,
    AiCreateTarget.post => Icons.forum_outlined,
    AiCreateTarget.chartAnalysis => Icons.candlestick_chart_outlined,
  };

  UiIntent get intent => switch (this) {
    AiCreateTarget.note => UiIntent.info,
    AiCreateTarget.journal => UiIntent.primary,
    AiCreateTarget.strategy => UiIntent.bullish,
    AiCreateTarget.post => UiIntent.warning,
    AiCreateTarget.chartAnalysis => UiIntent.neutral,
  };

  /// The Writing-Desk link kind a created record resolves to, so the shell can
  /// reopen it. Posts and chart analysis have no [AppLinkKind] destination.
  AppLinkKind? get linkKind => switch (this) {
    AiCreateTarget.note => AppLinkKind.note,
    AiCreateTarget.journal => AppLinkKind.journal,
    AiCreateTarget.strategy => AppLinkKind.strategy,
    AiCreateTarget.post => null,
    AiCreateTarget.chartAnalysis => null,
  };

  /// True when this target produces a persisted record via a repository.
  bool get createsRecord => this != AiCreateTarget.chartAnalysis;
}

// ===========================================================================
// Trade direction (for chart setups)
// ---------------------------------------------------------------------------

enum AiTradeDirection { long, short }

extension AiTradeDirectionX on AiTradeDirection {
  String get label => switch (this) {
    AiTradeDirection.long => 'Long',
    AiTradeDirection.short => 'Short',
  };

  bool get isLong => this == AiTradeDirection.long;

  AppSide get side =>
      this == AiTradeDirection.long ? AppSide.long : AppSide.short;

  UiIntent get intent => isLong ? UiIntent.bullish : UiIntent.bearish;

  IconData get icon =>
      isLong ? Icons.trending_up_rounded : Icons.trending_down_rounded;
}

// ===========================================================================
// Thread
// ---------------------------------------------------------------------------

/// One conversation with the copilot. Holds its own message list and the
/// persona it was started with.
@immutable
class AiThread {
  const AiThread({
    required this.id,
    required this.title,
    required this.persona,
    required this.messages,
    required this.updatedAt,
    this.pinned = false,
  });

  final String id;
  final String title;
  final AiPersona persona;
  final List<AppAiMessage> messages;
  final DateTime updatedAt;
  final bool pinned;

  /// Preview line for the history list — the most recent non-pending body.
  String get preview {
    for (int i = messages.length - 1; i >= 0; i--) {
      final AppAiMessage m = messages[i];
      if (!m.pending && m.body.trim().isNotEmpty) {
        return m.body.replaceAll('\n', ' ').trim();
      }
    }
    return 'New conversation';
  }

  int get messageCount =>
      messages.where((AppAiMessage m) => m.role != AppAiRole.system).length;

  AiThread copyWith({
    String? title,
    AiPersona? persona,
    List<AppAiMessage>? messages,
    DateTime? updatedAt,
    bool? pinned,
  }) {
    return AiThread(
      id: id,
      title: title ?? this.title,
      persona: persona ?? this.persona,
      messages: messages ?? this.messages,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
    );
  }
}

// ===========================================================================
// Capability
// ---------------------------------------------------------------------------

/// A capability tile in the "what can the copilot do" grid. Tapping it seeds
/// the composer with [promptSeed] (and, when set, jumps to a create target).
@immutable
class AiCapability {
  const AiCapability({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.promptSeed,
    this.target,
    this.badge,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String promptSeed;

  /// When set, the tile routes into the create flow for this target instead of
  /// (or in addition to) seeding a chat prompt.
  final AiCreateTarget? target;

  /// Optional corner label, e.g. "New" or "Pro".
  final String? badge;
}

// ===========================================================================
// Suggested action
// ---------------------------------------------------------------------------

/// A "create from this" chip rendered under the latest assistant answer.
@immutable
class AiSuggestedAction {
  const AiSuggestedAction({required this.target, this.label, this.setupId});

  final AiCreateTarget target;

  /// Overrides the target's default action label.
  final String? label;

  /// When set, the action carries a specific [AiChartSetup] to seed the draft.
  final String? setupId;

  String get effectiveLabel => label ?? target.actionLabel;
  IconData get icon => target.icon;
}

// ===========================================================================
// Chart setup
// ---------------------------------------------------------------------------

/// A detectable chart pattern with a full trade plan. Mirrors the community
/// copilot's preset shape but lives in the model layer so seed data stays
/// separated from the widgets that render it.
@immutable
class AiChartSetup {
  const AiChartSetup({
    required this.id,
    required this.title,
    required this.symbol,
    required this.timeframe,
    required this.pattern,
    required this.direction,
    required this.entry,
    required this.stopLoss,
    required this.target1,
    required this.target2,
    required this.confidence,
    required this.rationale,
    this.previewUrl = '',
  });

  final String id;
  final String title;
  final String symbol;
  final String timeframe;
  final String pattern;
  final AiTradeDirection direction;
  final double entry;
  final double stopLoss;
  final double target1;
  final double target2;

  /// 0–100 AI probability score.
  final int confidence;
  final String rationale;
  final String previewUrl;

  double get risk => (entry - stopLoss).abs();
  double get reward => (target1 - entry).abs();
  double get rrRatio => risk > 0 ? reward / risk : 1.0;
}

// ===========================================================================
// Create draft
// ---------------------------------------------------------------------------

/// The generated content the create flow previews before it commits. The
/// repository turns a draft into a real record and returns an [AppLinkRef] the
/// shell can open (null for posts, which have no Writing-Desk destination).
@immutable
class AiCreateDraft {
  const AiCreateDraft({
    required this.target,
    required this.title,
    required this.body,
    this.tickers = const <String>[],
    this.tags = const <String>[],
    this.setup,
    this.noteType = AppNoteType.analysis,
    this.isFavorite = false,
    this.isPublic = false,
    this.side = AppSide.long,
    this.entryPrice,
    this.stopLoss,
    this.target1,
    this.target2,
    this.quantity = 50.0,
    this.rMultiple,
    this.strategyName,
    this.psychologyScore = 5,
    this.isClosed = false,
    this.category = 'Breakout Momentum',
    this.strategyStatus = AppStrategyStatus.live,
    this.summary,
    this.channel = 'Feed',
  });

  final AiCreateTarget target;
  final String title;
  final String body;
  final List<String> tickers;
  final List<String> tags;

  /// Present for trade-shaped drafts (journal / post / chart analysis exports).
  final AiChartSetup? setup;

  // Note-specific fields
  final AppNoteType noteType;
  final bool isFavorite;
  final bool isPublic;

  // Journal-specific fields
  final AppSide side;
  final double? entryPrice;
  final double? stopLoss;
  final double? target1;
  final double? target2;
  final double quantity;
  final double? rMultiple;
  final String? strategyName;
  final int psychologyScore;
  final bool isClosed;

  // Strategy-specific fields
  final String? category;
  final AppStrategyStatus strategyStatus;
  final String? summary;

  // Post-specific fields
  final String channel;

  AiCreateDraft copyWith({
    String? title,
    String? body,
    List<String>? tickers,
    List<String>? tags,
    AiChartSetup? setup,
    AppNoteType? noteType,
    bool? isFavorite,
    bool? isPublic,
    AppSide? side,
    double? entryPrice,
    double? stopLoss,
    double? target1,
    double? target2,
    double? quantity,
    double? rMultiple,
    String? strategyName,
    int? psychologyScore,
    bool? isClosed,
    String? category,
    AppStrategyStatus? strategyStatus,
    String? summary,
    String? channel,
  }) {
    return AiCreateDraft(
      target: target,
      title: title ?? this.title,
      body: body ?? this.body,
      tickers: tickers ?? this.tickers,
      tags: tags ?? this.tags,
      setup: setup ?? this.setup,
      noteType: noteType ?? this.noteType,
      isFavorite: isFavorite ?? this.isFavorite,
      isPublic: isPublic ?? this.isPublic,
      side: side ?? this.side,
      entryPrice: entryPrice ?? this.entryPrice,
      stopLoss: stopLoss ?? this.stopLoss,
      target1: target1 ?? this.target1,
      target2: target2 ?? this.target2,
      quantity: quantity ?? this.quantity,
      rMultiple: rMultiple ?? this.rMultiple,
      strategyName: strategyName ?? this.strategyName,
      psychologyScore: psychologyScore ?? this.psychologyScore,
      isClosed: isClosed ?? this.isClosed,
      category: category ?? this.category,
      strategyStatus: strategyStatus ?? this.strategyStatus,
      summary: summary ?? this.summary,
      channel: channel ?? this.channel,
    );
  }
}
