import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/linking/link_graph.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';
import 'package:alphajournal/features/linking/link_graph_service.dart';
import 'package:alphajournal/features/market_data/data/asset_market_repository.dart';
import 'package:alphajournal/features/notes/data/notes_repository.dart';
import 'package:alphajournal/features/strategies/data/strategies_repository.dart';
import 'package:alphajournal/features/watchlists/data/watchlist_repository.dart';
import 'package:alphajournal/features/workspace/data/workspace_post_service.dart';
import 'package:uuid/uuid.dart';

import '../models/workspace.dart';
import 'copilot_controller.dart';

/// Categories of AlphaJournal features connected to AI Copilot.
enum CopilotFeatureCategory {
  notes('Notes', Icons.description_outlined, AppLinkKind.note),
  journal('Journal', Icons.candlestick_chart_outlined, AppLinkKind.journal),
  strategies('Strategies', Icons.psychology_outlined, AppLinkKind.strategy),
  community('Community', Icons.forum_outlined, AppLinkKind.communityPost),
  watchlist('Watchlist', Icons.show_chart_rounded, AppLinkKind.ticker);

  const CopilotFeatureCategory(this.label, this.icon, this.linkKind);
  final String label;
  final IconData icon;
  final AppLinkKind linkKind;
}

/// Target feature when saving or publishing an AI Copilot output.
enum CopilotFeatureTarget {
  note('Save as Note', Icons.note_add_outlined),
  journal('Log to Journal', Icons.candlestick_chart_outlined),
  strategy('Save as Strategy', Icons.psychology_outlined),
  community('Share to Community', Icons.forum_outlined);

  const CopilotFeatureTarget(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// A connectable item from Notes, Journal, Strategies, Community, or Watchlist.
@immutable
class CopilotConnectedItem {
  const CopilotConnectedItem({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.markdownContext,
    this.badge,
    this.intent = UiIntent.neutral,
    this.ref,
  });

  final String id;
  final CopilotFeatureCategory category;
  final String title;
  final String subtitle;
  final String markdownContext;
  final String? badge;
  final UiIntent intent;
  final AppLinkRef? ref;

  Json toAttachmentJson() => <String, dynamic>{
    'type': 'input_text',
    'text':
        'Connected ${category.label} Record (${title.trim()}):\n$markdownContext',
  };
}

/// Bridges AI Copilot (Chat & Voice Assistant) with Notes, Journal, Strategies,
/// Community Posts, and Watchlists/Market Data across AlphaJournal.
class CopilotFeatureConnector {
  const CopilotFeatureConnector._();

  static const Uuid _uuid = Uuid();

  /// Loads all connectable records across Notes, Journal, Strategies, Community,
  /// and Watchlists so the user or AI Copilot can reference them directly.
  static Future<List<CopilotConnectedItem>> fetchConnectableItems() async {
    final List<CopilotConnectedItem> items = <CopilotConnectedItem>[];
    final AppLinkGraph graph = AppLinkGraphService.instance.current;

    // 1. Trader Notes
    List<AppNote> notes = graph.noteList;
    if (notes.isEmpty) {
      try {
        notes = await NotesRepositoryScope.repository.fetchAll();
      } catch (_) {}
    }
    for (final AppNote note in notes.take(25)) {
      final String title = note.title.trim().isEmpty
          ? 'Untitled note'
          : note.title.trim();
      final String link = AppDeepLink.markdown(
        kind: AppLinkKind.note,
        id: note.id,
        label: title,
      );
      items.add(
        CopilotConnectedItem(
          id: 'note:${note.id}',
          category: CopilotFeatureCategory.notes,
          title: title,
          subtitle:
              '${note.noteType.label} · ${AppTokens.relativeTime(note.updatedAt)}',
          badge: note.linkedTickers.isNotEmpty
              ? '\$${note.linkedTickers.first}'
              : note.noteType.label,
          intent: note.noteType.intent,
          ref: graph.noteRef(note),
          markdownContext:
              '### Note: $link\n'
              '- **Type**: ${note.noteType.label}\n'
              '- **Tickers**: ${note.linkedTickers.isEmpty ? "None" : note.linkedTickers.map((t) => "\$$t").join(", ")}\n'
              '- **Tags**: ${note.tags.isEmpty ? "None" : note.tags.join(", ")}\n\n'
              '${note.content.trim()}',
        ),
      );
    }

    // 2. Trade Journal Entries
    List<AppTrade> trades = graph.journalList;
    if (trades.isEmpty) {
      try {
        trades = await JournalRepositoryScope.repository.fetchAll();
      } catch (_) {}
    }
    if (trades.isNotEmpty) {
      final int totalTrades = trades.length;
      final int openTrades = trades.where((AppTrade t) => t.isOpen).length;
      final int wins = trades.where((AppTrade t) => t.pnl > 0).length;
      final double winRate = totalTrades == 0
          ? 0.0
          : (wins / totalTrades) * 100.0;
      final double netPnl = trades.fold<double>(
        0.0,
        (double sum, AppTrade t) => sum + t.pnl,
      );
      items.add(
        CopilotConnectedItem(
          id: 'journal:summary',
          category: CopilotFeatureCategory.journal,
          title: 'Full Journal Performance Summary',
          subtitle:
              '$totalTrades trades · ${winRate.toStringAsFixed(1)}% win rate · ${AppTokens.signedMoney(netPnl)}',
          badge: '${winRate.toStringAsFixed(0)}% WR',
          intent: AppTokens.plIntent(netPnl),
          markdownContext:
              '### Trading Journal Summary\n'
              '- **Total Trades**: $totalTrades ($openTrades open)\n'
              '- **Win Rate**: ${winRate.toStringAsFixed(1)}%\n'
              '- **Net PnL**: ${AppTokens.signedMoney(netPnl)}\n',
        ),
      );
    }
    for (final AppTrade trade in trades.take(25)) {
      final String link = AppDeepLink.markdown(
        kind: AppLinkKind.journal,
        id: trade.id,
        label: trade.displayTitle,
      );
      final String sideLabel = AppTokens.sideLabel(trade.side);
      final String exitText = (trade.exit ?? trade.entry).toStringAsFixed(2);
      items.add(
        CopilotConnectedItem(
          id: 'journal:${trade.id}',
          category: CopilotFeatureCategory.journal,
          title: trade.displayTitle,
          subtitle:
              '$sideLabel · Entry ${trade.entry.toStringAsFixed(2)} → Exit $exitText',
          badge: AppTokens.signedMoney(trade.pnl),
          intent: AppTokens.plIntent(trade.pnl),
          ref: graph.journalRef(trade),
          markdownContext:
              '### Journal Trade: $link\n'
              '- **Ticker**: \$${trade.ticker}\n'
              '- **Side**: $sideLabel\n'
              '- **Entry / Exit**: ${trade.entry.toStringAsFixed(2)} / $exitText\n'
              '- **PnL**: ${AppTokens.signedMoney(trade.pnl)} (${trade.pnlPercent.toStringAsFixed(2)}%)\n'
              '- **Strategy**: ${trade.strategy ?? "Unassigned"}\n'
              '- **Setup / Notes**: ${trade.notes ?? (trade.content.isNotEmpty ? trade.content : "No notes recorded.")}',
        ),
      );
    }

    // 3. Strategy Playbooks
    List<AppStrategy> strategies = graph.strategyList;
    if (strategies.isEmpty) {
      try {
        strategies = await StrategiesRepositoryScope.repository.fetchAll();
      } catch (_) {}
    }
    for (final AppStrategy strategy in strategies.take(20)) {
      final String link = AppDeepLink.markdown(
        kind: AppLinkKind.strategy,
        id: strategy.id,
        label: strategy.name,
      );
      items.add(
        CopilotConnectedItem(
          id: 'strategy:${strategy.id}',
          category: CopilotFeatureCategory.strategies,
          title: strategy.name,
          subtitle:
              '${strategy.category ?? "Playbook"} · ${strategy.trades} trades · ${strategy.winRate.toStringAsFixed(1)}% WR',
          badge: '${strategy.winRate.toStringAsFixed(0)}% WR',
          intent: strategy.netPnl >= 0 ? UiIntent.bullish : UiIntent.neutral,
          ref: graph.strategyRef(strategy),
          markdownContext:
              '### Strategy Playbook: $link\n'
              '- **Category**: ${strategy.category ?? "General"}\n'
              '- **Status**: ${strategy.status.label}\n'
              '- **Win Rate**: ${strategy.winRate.toStringAsFixed(1)}% across ${strategy.trades} trades\n'
              '- **Net PnL**: ${AppTokens.signedMoney(strategy.netPnl)}\n'
              '- **Summary**: ${strategy.summary ?? ""}\n\n'
              '${strategy.content.trim()}',
        ),
      );
    }

    // 4. Community Posts
    final List<AppPostLinkInfo> posts = WorkspacePostService.instance.allLinks;
    for (final AppPostLinkInfo post in posts.take(20)) {
      final String link = AppDeepLink.markdown(
        kind: AppLinkKind.communityPost,
        id: post.postId,
        label: post.postTitle,
      );
      items.add(
        CopilotConnectedItem(
          id: 'community:${post.postId}',
          category: CopilotFeatureCategory.community,
          title: post.postTitle,
          subtitle:
              '${post.authorName} (${post.authorHandle}) · ${post.likesCount} likes · ${post.commentsCount} comments',
          badge: 'Post',
          intent: UiIntent.info,
          ref: AppLinkRef(
            kind: AppLinkKind.communityPost,
            id: post.postId,
            title: post.postTitle,
            subtitle: post.authorHandle,
          ),
          markdownContext:
              '### Community Post: $link\n'
              '- **Author**: ${post.authorName} (${post.authorHandle})\n'
              '- **Engagement**: ${post.likesCount} likes, ${post.commentsCount} comments, ${post.sharesCount} shares\n'
              '- **Linked Record**: ${post.recordKind.label} (${post.recordId})',
        ),
      );
    }

    // 5. Watchlist & Market Tickers
    try {
      final List<AppTicker> tickers = await WatchlistRepositoryImpl.instance
          .getWatchlistTickers();
      for (final AppTicker ticker in tickers.take(20)) {
        final String link = AppDeepLink.markdown(
          kind: AppLinkKind.ticker,
          id: ticker.symbol,
          label: '\$${ticker.symbol}',
        );
        items.add(
          CopilotConnectedItem(
            id: 'ticker:${ticker.symbol}',
            category: CopilotFeatureCategory.watchlist,
            title: '${ticker.symbol} · ${ticker.name}',
            subtitle:
                'Price ${ticker.price.toStringAsFixed(2)} · ${AppTokens.signedPercent(ticker.changePercent)}',
            badge: AppTokens.signedPercent(ticker.changePercent),
            intent: AppTokens.plIntent(ticker.changePercent),
            ref: graph.tickerRef(ticker.symbol),
            markdownContext:
                '### Market Symbol: $link (${ticker.name})\n'
                '- **Price**: ${ticker.price.toStringAsFixed(2)}\n'
                '- **Change**: ${AppTokens.signedPercent(ticker.changePercent)}\n'
                '- **Category**: ${ticker.category ?? "Market"}',
          ),
        );
      }
    } catch (_) {}

    return items;
  }

  /// Extracts `$TICKER` symbols from a block of text.
  static List<String> extractTickers(String text) {
    final Set<String> out = <String>{};
    final Iterable<RegExpMatch> dollarMatches = RegExp(
      r'(?<![\$\w])\$([A-Za-z]{2,10})\b',
    ).allMatches(text);
    for (final RegExpMatch m in dollarMatches) {
      final String? s = m.group(1)?.toUpperCase();
      if (s != null && s.isNotEmpty) out.add(s);
    }
    for (final String known in const <String>[
      'NVDA',
      'AAPL',
      'MSFT',
      'TSLA',
      'SPY',
      'QQQ',
      'BTC',
      'ETH',
      'RELIANCE',
      'NIFTY50',
      'HDFCBANK',
      'TCS',
    ]) {
      if (RegExp('\\b$known\\b', caseSensitive: false).hasMatch(text)) {
        out.add(known);
      }
    }
    return out.toList();
  }

  /// Derives a clean title from markdown content.
  static String deriveTitle(
    String markdown, {
    String fallback = 'Copilot Insight',
  }) {
    for (final String raw in markdown.split('\n')) {
      final String line = raw
          .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
          .replaceFirst(RegExp(r'^>\s*\[![A-Z]+\]\s*'), '')
          .replaceFirst(RegExp(r'^[-*+]\s+'), '')
          .replaceAll('**', '')
          .trim();
      if (line.isEmpty || line.startsWith('```') || line.startsWith('|')) {
        continue;
      }
      return line.length <= 68 ? line : '${line.substring(0, 65)}…';
    }
    return fallback;
  }

  /// Saves an AI Copilot message as a Trader Note in [NotesRepository].
  static Future<({AppNote note, AppLinkRef ref})> saveAsNote({
    required String body,
    String? title,
    AppNoteType noteType = AppNoteType.analysis,
    List<String>? tags,
  }) async {
    final List<String> tickers = extractTickers(body);
    final String resolvedTitle = (title == null || title.trim().isEmpty)
        ? deriveTitle(body, fallback: 'Copilot Research Note')
        : title.trim();
    final DateTime now = DateTime.now();
    final AppNote draft = AppNote(
      id: '',
      title: resolvedTitle,
      content: body,
      createdAt: now,
      updatedAt: now,
      noteType: noteType,
      tags: tags ?? const <String>['copilot', 'ai-insight'],
      linkedTickers: tickers,
    );
    final AppNote saved = await NotesRepositoryScope.repository.create(draft);
    final AppLinkRef ref = AppLinkGraphService.instance.current.noteRef(saved);
    return (note: saved, ref: ref);
  }

  /// Logs an AI Copilot trade analysis as a Journal entry in [JournalRepository].
  static Future<({AppTrade trade, AppLinkRef ref})> logAsJournalTrade({
    required String body,
    String? ticker,
    AppSide side = AppSide.long,
    double entry = 100.0,
    double exit = 108.0,
    double pnl = 800.0,
    String? title,
    String? strategyId,
    String? strategyName,
  }) async {
    final List<String> tickers = extractTickers(body);
    final String resolvedTicker = (ticker != null && ticker.trim().isNotEmpty)
        ? ticker.trim().toUpperCase().replaceAll(r'$', '')
        : (tickers.isNotEmpty ? tickers.first : 'NVDA');
    final double pnlPercent = entry > 0
        ? ((exit - entry) / entry) * 100.0
        : 0.0;
    final String sideLabel = AppTokens.sideLabel(side);
    final AppTrade draft = AppTrade(
      id: '',
      ticker: resolvedTicker,
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : '$resolvedTicker $sideLabel Setup',
      side: side,
      entry: entry,
      exit: exit,
      pnl: pnl,
      pnlPercent: side == AppSide.long ? pnlPercent : -pnlPercent,
      openedAt: DateTime.now(),
      closedAt: DateTime.now(),
      outcome: pnl >= 0 ? AppOutcome.win : AppOutcome.loss,
      notes: deriveTitle(body, fallback: 'AI Copilot reviewed trade setup'),
      content: body,
      tags: const <String>['copilot', 'ai-review'],
      strategyId: strategyId,
      strategy: strategyName,
    );
    final AppTrade saved = await JournalRepositoryScope.repository.create(
      draft,
    );
    final AppLinkRef ref = AppLinkGraphService.instance.current.journalRef(
      saved,
    );
    return (trade: saved, ref: ref);
  }

  /// Saves an AI Copilot response as a Strategy Playbook in [StrategiesRepository].
  static Future<({AppStrategy strategy, AppLinkRef ref})> saveAsStrategy({
    required String body,
    String? name,
    String category = 'Momentum & Breakout',
    String? summary,
  }) async {
    final String resolvedName = (name == null || name.trim().isEmpty)
        ? deriveTitle(body, fallback: 'Copilot Playbook')
        : name.trim();
    final AppStrategy draft = AppStrategy(
      id: '',
      name: resolvedName,
      category: category,
      summary: summary?.trim().isNotEmpty == true
          ? summary!.trim()
          : deriveTitle(body, fallback: 'AI-generated trading playbook'),
      content: body,
      status: AppStrategyStatus.live,
      tags: const <String>['copilot', 'playbook'],
      updatedAt: DateTime.now(),
    );
    final AppStrategy saved = await StrategiesRepositoryScope.repository.create(
      draft,
    );
    final AppLinkRef ref = AppLinkGraphService.instance.current.strategyRef(
      saved,
    );
    return (strategy: saved, ref: ref);
  }

  /// Publishes an AI Copilot insight to the Community feed & links it in [WorkspacePostService].
  static Future<({AppPostLinkInfo post, AppLinkRef ref})> publishCommunityPost({
    required String body,
    String? title,
    List<String>? tickers,
    AppLinkKind recordKind = AppLinkKind.note,
    String? recordId,
  }) async {
    final String resolvedTitle = (title == null || title.trim().isEmpty)
        ? deriveTitle(body, fallback: 'Market & Desk Insight')
        : title.trim();
    final String resolvedRecordId = recordId ?? _uuid.v4();
    final String postId = 'post-${DateTime.now().millisecondsSinceEpoch}';
    WorkspacePostService.instance.linkRecord(
      kind: recordKind,
      recordId: resolvedRecordId,
      postTitle: resolvedTitle,
      postId: postId,
      authorName: 'You · Copilot Desk',
      authorHandle: '@trader',
    );
    final AppPostLinkInfo created =
        WorkspacePostService.instance.getPrimaryLink(
          recordKind,
          resolvedRecordId,
        ) ??
        AppPostLinkInfo(
          postId: postId,
          postTitle: resolvedTitle,
          authorName: 'You · Copilot Desk',
          authorHandle: '@trader',
          recordKind: recordKind,
          recordId: resolvedRecordId,
          publishedAt: DateTime.now(),
        );
    final AppLinkRef ref = AppLinkRef(
      kind: AppLinkKind.communityPost,
      id: created.postId,
      title: created.postTitle,
      subtitle: created.authorHandle,
    );
    return (post: created, ref: ref);
  }

  /// Generates a rich, natural-language markdown response connected to the
  /// user's live Notes, Journal, Strategies, Community Posts, and Watchlist
  /// when running in local/voice/offline fallback mode.
  static Future<String> buildConnectedNaturalLanguageReply(
    String prompt,
    CopilotController controller,
  ) async {
    final String lower = prompt.toLowerCase();
    final AppLinkGraph graph = AppLinkGraphService.instance.current;

    List<AppNote> notes = graph.noteList;
    if (notes.isEmpty) {
      try {
        notes = await NotesRepositoryScope.repository.fetchAll();
      } catch (_) {}
    }

    List<AppTrade> trades = graph.journalList;
    if (trades.isEmpty) {
      try {
        trades = await JournalRepositoryScope.repository.fetchAll();
      } catch (_) {}
    }

    List<AppStrategy> strategies = graph.strategyList;
    if (strategies.isEmpty) {
      try {
        strategies = await StrategiesRepositoryScope.repository.fetchAll();
      } catch (_) {}
    }

    final int totalTrades = trades.length;
    final int wins = trades.where((AppTrade t) => t.pnl > 0).length;
    final double winRate = totalTrades == 0
        ? 0.0
        : (wins / totalTrades) * 100.0;
    final double netPnl = trades.fold<double>(
      0.0,
      (double sum, AppTrade t) => sum + t.pnl,
    );
    final List<AppPostLinkInfo> posts = WorkspacePostService.instance.allLinks;
    List<AppTicker> watchlist = <AppTicker>[];
    try {
      watchlist = await WatchlistRepositoryImpl.instance.getWatchlistTickers();
    } catch (_) {}
    if (watchlist.isEmpty) {
      try {
        final snap = await AssetMarketRepository.shared.snapshot();
        watchlist = snap.instruments
            .take(5)
            .map(
              (q) => AppTicker(
                symbol: q.symbol,
                name: q.name,
                price: q.price,
                changePercent: q.changePercent,
              ),
            )
            .toList();
      } catch (_) {}
    }

    final String specialistName = controller.specialist?.name ?? 'Atlas';
    final StringBuffer out = StringBuffer();

    out.writeln('> [!TIP]');
    out.writeln(
      '> **$specialistName Connected Workspace Analysis** — Synchronized with your Notes (${notes.length}), Journal (${trades.length} trades), Playbooks (${strategies.length}), Watchlist (${watchlist.length}), and Community feed (${posts.length} posts).',
    );
    out.writeln();

    // KPI snapshot block rendered with reusable UiMetricCard grid
    out.writeln('```kpi');
    out.writeln(
      '{"title": "Connected Desk Snapshot", "metrics": ['
      '{"label": "Journal Win Rate", "value": "${winRate.toStringAsFixed(1)}%", "change": "$totalTrades trades", "isPositive": ${winRate >= 50}},'
      '{"label": "Net PnL", "value": "${AppTokens.signedMoney(netPnl)}", "change": "$wins wins", "isPositive": ${netPnl >= 0}},'
      '{"label": "Active Playbooks", "value": "${strategies.length}", "change": "${notes.length} notes", "isPositive": true}'
      ']}',
    );
    out.writeln('```');
    out.writeln();

    if (lower.contains('note')) {
      out.writeln('### Connected Trader Notes');
      if (notes.isEmpty) {
        out.writeln(
          'You have no saved notes yet. Use **Save as Note** below to file this response directly into your Notes library.',
        );
      } else {
        for (final AppNote n in notes.take(4)) {
          final String link = AppDeepLink.markdown(
            kind: AppLinkKind.note,
            id: n.id,
            label: n.title.trim().isEmpty ? 'Untitled note' : n.title.trim(),
          );
          out.writeln(
            '- $link · **${n.noteType.label}** (${AppTokens.relativeTime(n.updatedAt)})',
          );
        }
      }
      out.writeln();
    }

    if (lower.contains('journal') ||
        lower.contains('trade') ||
        lower.contains('win') ||
        lower.contains('pnl') ||
        lower.contains('setup')) {
      out.writeln('### Trade Journal & Execution Review');
      if (trades.isNotEmpty) {
        out.writeln('| Trade | Side | Entry | Exit | PnL |');
        out.writeln('| :--- | :--- | ---: | ---: | ---: |');
        for (final AppTrade t in trades.take(5)) {
          final String link = AppDeepLink.markdown(
            kind: AppLinkKind.journal,
            id: t.id,
            label: t.displayTitle,
          );
          final String sideLabel = AppTokens.sideLabel(t.side);
          final String exitText = (t.exit ?? t.entry).toStringAsFixed(2);
          out.writeln(
            '| $link | $sideLabel | ${t.entry.toStringAsFixed(2)} | $exitText | ${AppTokens.signedMoney(t.pnl)} |',
          );
        }
        out.writeln();
      } else {
        out.writeln(
          'No closed trades logged in the current view. Click **Log to Journal** below to record this setup.',
        );
        out.writeln();
      }
    }

    if (lower.contains('strateg') || lower.contains('playbook')) {
      out.writeln('### Strategy Playbooks');
      if (strategies.isNotEmpty) {
        for (final AppStrategy s in strategies.take(4)) {
          final String link = AppDeepLink.markdown(
            kind: AppLinkKind.strategy,
            id: s.id,
            label: s.name,
          );
          out.writeln(
            '- $link — **${s.winRate.toStringAsFixed(1)}% WR** (${s.trades} trades · ${AppTokens.signedMoney(s.netPnl)})',
          );
        }
        out.writeln();
      }
    }

    if (watchlist.isNotEmpty) {
      out.writeln('### Watchlist & Market Pulse');
      out.writeln('```barlist');
      out.writeln('title: Watchlist Relative Strength');
      for (final AppTicker t in watchlist.take(5)) {
        out.writeln('${t.symbol}: ${t.price.toStringAsFixed(2)}');
      }
      out.writeln('```');
      out.writeln();
    }

    if (posts.isNotEmpty &&
        (lower.contains('community') ||
            lower.contains('post') ||
            lower.contains('social') ||
            lower.contains('share'))) {
      out.writeln('### Linked Community Posts');
      for (final AppPostLinkInfo p in posts.take(3)) {
        final String link = AppDeepLink.markdown(
          kind: AppLinkKind.communityPost,
          id: p.postId,
          label: p.postTitle,
        );
        out.writeln(
          '- $link by **${p.authorName}** (${p.likesCount} likes · ${p.commentsCount} comments)',
        );
      }
      out.writeln();
    }

    out.writeln(
      'Use the action buttons below to **Save as Note**, **Log to Journal**, **Save as Strategy**, or **Share to Community**.',
    );
    return out.toString().trim();
  }
}
