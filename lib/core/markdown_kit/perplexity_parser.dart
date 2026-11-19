import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Citation / source record displayed in the Perplexity sources rail and sheet.
@immutable
class PerplexitySource {
  const PerplexitySource({
    required this.index,
    required this.url,
    required this.title,
    required this.domain,
    this.snippet = '',
    this.publisher = '',
    this.publishedAt = '',
  });

  final int index;
  final String url;
  final String title;
  final String domain;
  final String snippet;
  final String publisher;
  final String publishedAt;
}

/// Visual media item (image, chart screenshot, avatar, logo) extracted for
/// the Perplexity Media gallery and fullscreen lightbox.
@immutable
class PerplexityMediaItem {
  const PerplexityMediaItem({
    required this.url,
    this.caption = '',
    this.sourceUrl = '',
    this.domain = '',
  });

  final String url;
  final String caption;
  final String sourceUrl;
  final String domain;
}

/// One research/execution step shown in Perplexity's Pro Search steps log.
@immutable
class PerplexitySearchStep {
  const PerplexitySearchStep({
    required this.title,
    this.detail = '',
    this.status = 'done',
  });

  final String title;
  final String detail;
  final String status;
}

/// Extracted card summary pill shown in the Perplexity answer header and Cards tab.
@immutable
class PerplexityCardSummary {
  const PerplexityCardSummary({
    required this.tag,
    required this.label,
    this.ticker,
    this.rawSpec = '',
  });

  final String tag;
  final String label;
  final String? ticker;
  final String rawSpec;
}

/// Complete Perplexity-style structural analysis of an assistant response.
@immutable
class PerplexityAnswerMeta {
  const PerplexityAnswerMeta({
    required this.cleanMarkdown,
    required this.sources,
    required this.followUps,
    required this.cards,
    required this.tickers,
    this.media = const <PerplexityMediaItem>[],
    this.steps = const <PerplexitySearchStep>[],
    this.hasStructuredBlocks = false,
  });

  final String cleanMarkdown;
  final List<PerplexitySource> sources;
  final List<String> followUps;
  final List<PerplexityCardSummary> cards;
  final List<String> tickers;
  final List<PerplexityMediaItem> media;
  final List<PerplexitySearchStep> steps;
  final bool hasStructuredBlocks;

  bool get isRichAnswer =>
      sources.isNotEmpty ||
      cards.isNotEmpty ||
      followUps.isNotEmpty ||
      media.isNotEmpty ||
      steps.isNotEmpty;
}

/// All fenced block language tags handled by [PerplexityCardBlock], [ChartBlock],
/// or streaming card skeleton substitution.
class PerplexityBlockTags {
  const PerplexityBlockTags._();

  static const Set<String> perplexityCards = <String>{
    'loading_card',
    'research_panel',
    'company',
    'stock',
    'equity',
    'crypto',
    'etf',
    'entity_company',
    'person',
    'profile',
    'executive',
    'founder',
    'investor',
    'analyst',
    'bio',
    'person_profile',
    'news',
    'headlines',
    'articles',
    'compare',
    'comparison',
    'pros_cons',
    'bull_bear',
    'swot',
    'versus',
    'timeline',
    'events',
    'catalysts',
    'roadmap',
    'factbox',
    'entity',
    'concept',
    'product',
    'software',
    'service',
    'book',
    'place',
    'location',
    'glossary',
    'setup',
    'trade_setup',
    'signal',
    'order_plan',
    'verdict',
    'takeaways',
    'summary',
    'faq',
    'accordion',
    'checklist',
    'steps',
    'how_to',
    'quote',
    'earnings',
    'earnings_call',
    'quarter',
    'financials',
    'income_statement',
    'balance_sheet',
    'cash_flow',
    'valuation',
    'macro',
    'economic',
    'fed',
    'rates',
    'calendar',
    'ratings',
    'price_target',
    'insider',
    'ownership',
    'screener',
    'watchlist',
    'movers',
    'sector',
    'peers',
    'leaderboard',
    'ranking',
    'sentiment',
    'options_flow',
    'social_pulse',
    'media',
    'gallery',
    'images',
    'links',
    'web_results',
    'bookmarks',
    'resources',
    'citations',
    'video',
    'videos',
    'youtube',
    'podcast',
    'webinar',
    'stream',
    'weather',
    'market_pulse',
    'indices',
    'commodities',
    'fx',
    'snapshot',
    'scoreboard',
    'match',
    'event_schedule',
    'earnings_calendar',
    'schedule',
    'scenarios',
    'probabilities',
    'poll',
    'distribution',
    'sensitivity',
    'backtest',
    'strategy_stats',
    'performance',
    'quant',
    'portfolio',
    'allocation',
    'holdings',
    'weights',
    'rebalance',
    'filing',
    'sec_filing',
    'document',
    'report',
    'paper',
    'transcript',
    'wiki',
    'encyclopedia',
    'definition',
    'define',
    'risk_plan',
    'sizing',
    'execution',
    'workflow',
    'playbook',
    'tutorial',
    'guide',
    'formula',
    'calculation',
    'math_card',
    'card',
    'cards',
  };

  static const Set<String> followUpTags = <String>{'followups', 'related'};

  static const Set<String> searchStepTags = <String>{
    'research_steps',
    'search_steps',
    'search_log',
  };

  static const Set<String> chartAndDiagramTags = <String>{
    'chart',
    'graph',
    'plot',
    'bar',
    'line',
    'area',
    'combo',
    'pie',
    'donut',
    'candle',
    'candles',
    'ohlc',
    'waterfall',
    'barlist',
    'ranking',
    'kpi',
    'metrics',
    'spark',
    'sparkline',
    'mermaid',
    'flowchart',
  };

  static bool isStructured(String tag) {
    final String lower = tag.toLowerCase().trim();
    return perplexityCards.contains(lower) ||
        followUpTags.contains(lower) ||
        searchStepTags.contains(lower) ||
        chartAndDiagramTags.contains(lower);
  }

  static String friendlyLabel(String rawTag) {
    return switch (rawTag.toLowerCase().trim()) {
      'company' ||
      'stock' ||
      'equity' ||
      'crypto' ||
      'etf' ||
      'entity_company' => 'Company Dossier',
      'person' ||
      'profile' ||
      'executive' ||
      'founder' ||
      'investor' ||
      'analyst' ||
      'bio' ||
      'person_profile' => 'Person Profile',
      'news' || 'headlines' || 'articles' => 'Market News',
      'compare' ||
      'comparison' ||
      'pros_cons' ||
      'bull_bear' ||
      'swot' ||
      'versus' => 'Comparison',
      'timeline' || 'events' || 'catalysts' || 'roadmap' => 'Timeline',
      'product' || 'software' || 'service' => 'Product & Tool',
      'place' || 'location' => 'Location Guide',
      'factbox' ||
      'entity' ||
      'concept' ||
      'book' ||
      'glossary' => 'Fact Sheet',
      'setup' || 'trade_setup' || 'signal' || 'order_plan' => 'Trade Setup',
      'verdict' || 'takeaways' || 'summary' => 'Key Takeaways',
      'faq' || 'accordion' => 'FAQ Breakdown',
      'checklist' || 'steps' || 'how_to' => 'Action Checklist',
      'quote' => 'Primary Quote',
      'earnings' || 'earnings_call' || 'quarter' => 'Earnings Report',
      'financials' ||
      'income_statement' ||
      'balance_sheet' ||
      'cash_flow' ||
      'valuation' => 'Financial Statements',
      'macro' ||
      'economic' ||
      'fed' ||
      'rates' ||
      'calendar' => 'Macro Calendar',
      'ratings' ||
      'price_target' ||
      'insider' ||
      'ownership' => 'Ratings & Flows',
      'screener' ||
      'watchlist' ||
      'movers' ||
      'sector' ||
      'peers' ||
      'leaderboard' => 'Screener & Movers',
      'sentiment' || 'options_flow' || 'social_pulse' => 'Sentiment & Flow',
      'media' || 'gallery' || 'images' => 'Media Gallery',
      'links' ||
      'web_results' ||
      'bookmarks' ||
      'resources' ||
      'citations' => 'Web Sources',
      'video' ||
      'videos' ||
      'youtube' ||
      'podcast' ||
      'webinar' ||
      'stream' => 'Videos & Briefings',
      'weather' ||
      'market_pulse' ||
      'indices' ||
      'commodities' ||
      'fx' ||
      'snapshot' => 'Live Pulse',
      'scoreboard' ||
      'match' ||
      'event_schedule' ||
      'earnings_calendar' ||
      'schedule' => 'Calendar & Schedule',
      'scenarios' ||
      'probabilities' ||
      'poll' ||
      'distribution' ||
      'sensitivity' => 'Scenario Matrix',
      'backtest' ||
      'strategy_stats' ||
      'performance' ||
      'quant' => 'Backtest Telemetry',
      'portfolio' ||
      'allocation' ||
      'holdings' ||
      'weights' ||
      'rebalance' => 'Portfolio Breakdown',
      'filing' ||
      'sec_filing' ||
      'document' ||
      'report' ||
      'paper' ||
      'transcript' => 'Document Filing',
      'wiki' || 'encyclopedia' || 'definition' || 'define' => 'Knowledge Card',
      'risk_plan' || 'sizing' || 'execution' => 'Risk Plan',
      'workflow' || 'playbook' || 'tutorial' || 'guide' => 'Playbook Guide',
      'formula' || 'calculation' || 'math_card' => 'Formula Breakdown',
      'research_steps' || 'search_steps' || 'search_log' => 'Research Steps',
      'research_panel' => 'Research Brief',
      'card' || 'cards' => 'Research Card',
      'mermaid' || 'flowchart' => 'Diagram',
      'candle' || 'candles' || 'ohlc' => 'Price Action Chart',
      'kpi' || 'metrics' => 'Key Metrics',
      'donut' || 'pie' => 'Breakdown Chart',
      _ => 'Visual Analysis',
    };
  }
}

/// Parses and normalizes markdown replies into Perplexity metadata (sources,
/// structured cards, detected tickers, extracted follow-ups, and streaming-safe
/// markdown).
class PerplexityAnswerParser {
  const PerplexityAnswerParser._();

  static final RegExp _fenceOpenRegex = RegExp(
    r'^ {0,3}(`{3,}|~{3,})\s*([A-Za-z0-9_\-]+)?.*$',
  );
  static final RegExp _mdImageRegex = RegExp(
    r'!\[([^\]]*)\]\(((?:https?://|data:image/)[^\s\)]+)\)',
  );
  static final RegExp _htmlImageRegex = RegExp(
    r'''<img\b[^>]*\bsrc=['"]((?:https?://|data:image/)[^'"]+)['"][^>]*>''',
    caseSensitive: false,
  );
  static final RegExp _htmlAltRegex = RegExp(
    r'''\balt=['"]([^'"]*)['"]''',
    caseSensitive: false,
  );
  static final RegExp _mdLinkRegex = RegExp(
    r'(?<!!)\[([^\]]+)\]\((https?://[^\s\)]+)\)',
  );
  static final RegExp _bareUrlRegex = RegExp(r'https?://[^\s\)\]>]+');
  static final RegExp _tickerRegex = RegExp(
    r'(?<![\$\w])\$([A-Za-z][A-Za-z0-9\.\-]{0,7})\b',
  );
  static final RegExp _trailingRelatedSectionRegex = RegExp(
    r'\n{1,3}(?:#{1,4}\s+|\*\*|\s*)(?:Related(?:\s+Questions)?|Follow-?up(?:\s+Questions)?)\b[^\n]*\n((?:\s*(?:[-*+]|\d+\.)\s+.+\n?)+)\s*$',
    caseSensitive: false,
  );

  /// Analyzes [rawMarkdown] and externally supplied citation/step lists.
  static PerplexityAnswerMeta parse(
    String rawMarkdown, {
    List<String> explicitUrls = const <String>[],
    List<({String url, String title, String domain, String snippet})>
        structuredSources =
        const [],
    List<String> externalSteps = const <String>[],
    String? focus,
    bool isStreaming = false,
  }) {
    final List<String> followUps = <String>[];
    final List<PerplexityCardSummary> cards = <PerplexityCardSummary>[];
    final Set<String> tickers = <String>{};
    final List<_SourceCandidate> candidates = <_SourceCandidate>[];
    final List<_MediaCandidate> mediaCandidates = <_MediaCandidate>[];
    final List<PerplexitySearchStep> steps = <PerplexitySearchStep>[];

    for (final s in structuredSources) {
      if (_isHttpUrl(s.url)) {
        candidates.add(
          _SourceCandidate(
            url: s.url,
            title: s.title,
            domain: s.domain,
            snippet: s.snippet,
          ),
        );
      }
    }
    for (final String url in explicitUrls) {
      if (_isHttpUrl(url)) {
        candidates.add(_SourceCandidate(url: url));
      }
    }

    // Extract tickers mentioned directly in prose ($NVDA, $AAPL).
    for (final RegExpMatch match in _tickerRegex.allMatches(rawMarkdown)) {
      final String? sym = match.group(1)?.toUpperCase();
      if (sym != null && sym.length <= 6) {
        tickers.add(sym);
      }
    }

    final List<String> lines = rawMarkdown.split('\n');
    final List<String> keptLines = <String>[];

    int i = 0;
    while (i < lines.length) {
      final String line = lines[i];
      final RegExpMatch? openMatch = _fenceOpenRegex.firstMatch(line);
      if (openMatch == null) {
        // Extract inline markdown and HTML images from ordinary prose lines.
        for (final RegExpMatch imgMatch in _mdImageRegex.allMatches(line)) {
          final String alt = (imgMatch.group(1) ?? '').trim();
          final String url = (imgMatch.group(2) ?? '').trim();
          if (_isMediaUrl(url)) {
            mediaCandidates.add(_MediaCandidate(url: url, caption: alt));
          }
        }
        for (final RegExpMatch htmlImg in _htmlImageRegex.allMatches(line)) {
          final String url = (htmlImg.group(1) ?? '').trim();
          final String alt =
              (_htmlAltRegex.firstMatch(htmlImg.group(0) ?? '')?.group(1) ?? '')
                  .trim();
          if (_isMediaUrl(url)) {
            mediaCandidates.add(_MediaCandidate(url: url, caption: alt));
          }
        }
        // Extract inline markdown links from ordinary prose lines.
        for (final RegExpMatch linkMatch in _mdLinkRegex.allMatches(line)) {
          final String linkTitle = (linkMatch.group(1) ?? '').trim();
          final String url = (linkMatch.group(2) ?? '').trim();
          if (_isHttpUrl(url)) {
            candidates.add(_SourceCandidate(url: url, title: linkTitle));
          }
        }
        keptLines.add(line);
        i++;
        continue;
      }

      final String fenceMarker = openMatch.group(1)!;
      final String fenceChar = fenceMarker[0];
      final int fenceLen = fenceMarker.length;
      final String tag = (openMatch.group(2) ?? '').toLowerCase().trim();

      int closeIndex = -1;
      for (int j = i + 1; j < lines.length; j++) {
        final String candidateLine = lines[j].trim();
        if (candidateLine.startsWith(fenceChar * fenceLen) &&
            candidateLine.replaceAll(fenceChar, '').trim().isEmpty) {
          closeIndex = j;
          break;
        }
      }

      if (closeIndex == -1) {
        // Unclosed block at the tail of the document.
        if (isStreaming && PerplexityBlockTags.isStructured(tag)) {
          if (PerplexityBlockTags.followUpTags.contains(tag) ||
              PerplexityBlockTags.searchStepTags.contains(tag)) {
            // Suppress partial followup/step JSON while still streaming.
            break;
          }
          final String label = PerplexityBlockTags.friendlyLabel(tag);
          keptLines
            ..add('```loading_card')
            ..add(jsonEncode(<String, dynamic>{'kind': tag, 'label': label}))
            ..add('```');
          break;
        }
        // Not streaming: keep original lines if not structured or attempt
        // recovery if structured content already has complete JSON.
        final String partialPayload = lines.sublist(i + 1).join('\n').trim();
        if (PerplexityBlockTags.followUpTags.contains(tag)) {
          final List<String> extracted = _parseFollowUps(partialPayload);
          if (extracted.isNotEmpty) {
            followUps.addAll(extracted);
            break;
          }
        }
        if (PerplexityBlockTags.isStructured(tag) &&
            partialPayload.startsWith('{') &&
            partialPayload.endsWith('}')) {
          keptLines
            ..add(line)
            ..add(partialPayload)
            ..add(fenceChar * fenceLen);
          i = lines.length;
          continue;
        }
        keptLines.addAll(lines.sublist(i));
        break;
      }

      final String blockBody = lines.sublist(i + 1, closeIndex).join('\n');
      if (PerplexityBlockTags.followUpTags.contains(tag)) {
        followUps.addAll(_parseFollowUps(blockBody));
        i = closeIndex + 1;
        continue;
      }
      if (PerplexityBlockTags.searchStepTags.contains(tag)) {
        steps.addAll(_parseSearchSteps(blockBody));
        i = closeIndex + 1;
        continue;
      }

      final String effectiveTag = !PerplexityBlockTags.isStructured(tag)
          ? (_inferStructuredJsonTag(blockBody) ?? tag)
          : tag;

      if (PerplexityBlockTags.isStructured(effectiveTag) &&
          effectiveTag != 'loading_card') {
        final String label = _deriveBlockSummary(
          tag: effectiveTag,
          body: blockBody,
          outTickers: tickers,
          outSources: candidates,
          outMedia: mediaCandidates,
        );
        cards.add(
          PerplexityCardSummary(
            tag: effectiveTag,
            label: label,
            rawSpec: blockBody,
          ),
        );
      }

      if (effectiveTag != tag) {
        keptLines
          ..add('$fenceMarker$effectiveTag')
          ..addAll(lines.sublist(i + 1, closeIndex))
          ..add(lines[closeIndex]);
      } else {
        keptLines.addAll(lines.sublist(i, closeIndex + 1));
      }
      i = closeIndex + 1;
    }

    String cleanMarkdown = keptLines.join('\n').trimRight();

    // If no ```followups fence was emitted, extract a trailing "## Related"
    // / "### Follow-up Questions" bullet list cleanly when settled.
    if (followUps.isEmpty && !isStreaming) {
      final RegExpMatch? trailingRelated = _trailingRelatedSectionRegex
          .firstMatch(cleanMarkdown);
      if (trailingRelated != null) {
        final String bulletBlock = trailingRelated.group(1) ?? '';
        final List<String> parsed = _parseFollowUps(bulletBlock);
        if (parsed.isNotEmpty) {
          followUps.addAll(parsed);
          cleanMarkdown = cleanMarkdown
              .substring(0, trailingRelated.start)
              .trimRight();
        }
      }
    }

    // Deduplicate sources while keeping insertion ordering.
    final Map<String, PerplexitySource> uniqueSources =
        <String, PerplexitySource>{};
    for (final _SourceCandidate candidate in candidates) {
      final String normalizedUrl = _cleanUrl(candidate.url);
      if (!_isHttpUrl(normalizedUrl)) continue;
      final Uri? uri = Uri.tryParse(normalizedUrl);
      final String domain = candidate.domain.isNotEmpty
          ? candidate.domain
          : _domainOf(uri, normalizedUrl);
      final String rawTitle = candidate.title.trim();
      final String cleanTitle = _isGenericTitle(rawTitle) ? domain : rawTitle;

      final PerplexitySource? existing = uniqueSources[normalizedUrl];
      if (existing == null) {
        uniqueSources[normalizedUrl] = PerplexitySource(
          index: uniqueSources.length + 1,
          url: normalizedUrl,
          title: cleanTitle,
          domain: domain,
          snippet: candidate.snippet.trim(),
          publisher: candidate.publisher.trim(),
          publishedAt: candidate.publishedAt.trim(),
        );
      } else {
        uniqueSources[normalizedUrl] = PerplexitySource(
          index: existing.index,
          url: existing.url,
          title: _isGenericTitle(existing.title) && !_isGenericTitle(rawTitle)
              ? rawTitle
              : existing.title,
          domain: existing.domain,
          snippet: existing.snippet.isNotEmpty
              ? existing.snippet
              : candidate.snippet.trim(),
          publisher: existing.publisher.isNotEmpty
              ? existing.publisher
              : candidate.publisher.trim(),
          publishedAt: existing.publishedAt.isNotEmpty
              ? existing.publishedAt
              : candidate.publishedAt.trim(),
        );
      }
    }

    final List<String> dedupedFollowUps = <String>[];
    final Set<String> seenPrompts = <String>{};
    for (final String q in followUps) {
      final String cleaned = q.trim();
      if (cleaned.length < 4) continue;
      final String key = cleaned.toLowerCase();
      if (seenPrompts.add(key)) {
        dedupedFollowUps.add(cleaned);
      }
      if (dedupedFollowUps.length >= 4) break;
    }

    // When settled and rich content is present without explicit follow-ups,
    // offer crisp, contextual Perplexity follow-up prompts.
    if (!isStreaming &&
        dedupedFollowUps.isEmpty &&
        (cards.isNotEmpty || uniqueSources.isNotEmpty || tickers.isNotEmpty)) {
      dedupedFollowUps.addAll(
        _contextualFollowUps(tickers: tickers, cards: cards),
      );
    }

    final Map<String, PerplexityMediaItem> uniqueMedia =
        <String, PerplexityMediaItem>{};
    for (final _MediaCandidate m in mediaCandidates) {
      final String rawMediaUrl = m.url.trim();
      final String normalizedUrl = rawMediaUrl.startsWith('data:image/')
          ? rawMediaUrl
          : _cleanUrl(rawMediaUrl);
      if (!_isMediaUrl(normalizedUrl)) continue;
      final Uri? srcUri = m.sourceUrl.trim().isNotEmpty
          ? Uri.tryParse(m.sourceUrl.trim())
          : null;
      final String domain = srcUri != null && srcUri.host.isNotEmpty
          ? _domainOf(srcUri, '')
          : (_isHttpUrl(normalizedUrl)
                ? _domainOf(Uri.tryParse(normalizedUrl), '')
                : 'Embedded image');
      final PerplexityMediaItem? existing = uniqueMedia[normalizedUrl];
      if (existing != null) {
        final bool enrichSource =
            existing.sourceUrl.isEmpty && m.sourceUrl.trim().isNotEmpty;
        if (enrichSource ||
            (existing.caption.isEmpty && m.caption.trim().isNotEmpty)) {
          uniqueMedia[normalizedUrl] = PerplexityMediaItem(
            url: normalizedUrl,
            caption: enrichSource && m.caption.trim().isNotEmpty
                ? m.caption.trim()
                : (existing.caption.isNotEmpty
                      ? existing.caption
                      : m.caption.trim()),
            sourceUrl: enrichSource ? m.sourceUrl.trim() : existing.sourceUrl,
            domain: enrichSource ? domain : existing.domain,
          );
        }
        continue;
      }
      uniqueMedia[normalizedUrl] = PerplexityMediaItem(
        url: normalizedUrl,
        caption: m.caption.trim(),
        sourceUrl: m.sourceUrl.trim(),
        domain: domain,
      );
    }

    final List<PerplexitySearchStep> resolvedSteps = _buildSteps(
      parsedSteps: steps,
      externalSteps: externalSteps,
      focus: focus,
      tickers: tickers,
      sources: uniqueSources.values.toList(growable: false),
      cards: cards,
      isStreaming: isStreaming,
    );

    return PerplexityAnswerMeta(
      cleanMarkdown: cleanMarkdown,
      sources: uniqueSources.values.toList(growable: false),
      followUps: dedupedFollowUps,
      cards: cards,
      tickers: tickers.toList(growable: false),
      media: uniqueMedia.values.toList(growable: false),
      steps: resolvedSteps,
      hasStructuredBlocks: cards.isNotEmpty,
    );
  }

  /// Tolerant decoder for LLM-generated JSON / JSON-array / key-value specs.
  static dynamic parseFlexibleJson(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // 1. Direct JSON decode
    try {
      return jsonDecode(trimmed);
    } catch (_) {}

    // 2. Sanitize smart quotes, trailing commas, and non-standard tokens
    final String normalized = trimmed
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll(RegExp(r',\s*([\]}])'), r'$1')
        .replaceAll(RegExp(r'\bundefined\b'), 'null')
        .replaceAll(RegExp(r'\bNaN\b'), 'null');

    try {
      return jsonDecode(normalized);
    } catch (_) {}

    // 3. Extract outermost JSON object or array slice if prose slipped inside fence
    final int firstBrace = normalized.indexOf('{');
    final int lastBrace = normalized.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      try {
        return jsonDecode(normalized.substring(firstBrace, lastBrace + 1));
      } catch (_) {}
    }

    final int firstBracket = normalized.indexOf('[');
    final int lastBracket = normalized.lastIndexOf(']');
    if (firstBracket >= 0 && lastBracket > firstBracket) {
      try {
        return jsonDecode(normalized.substring(firstBracket, lastBracket + 1));
      } catch (_) {}
    }

    return null;
  }

  /// Convenience wrapper returning a normalized `Map<String, dynamic>` when the
  /// block can be decoded cleanly as an object, array wrapper, or key-value list.
  static Map<String, dynamic>? parseCardMap(
    String raw, {
    String? fallbackKind,
  }) {
    final dynamic decoded = parseFlexibleJson(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    if (decoded is List) {
      final String kind = (fallbackKind ?? '').toLowerCase().trim();
      if (kind == 'news' || kind == 'headlines' || kind == 'articles') {
        return <String, dynamic>{'title': 'Latest News', 'items': decoded};
      }
      if (kind == 'timeline' ||
          kind == 'events' ||
          kind == 'catalysts' ||
          kind == 'roadmap') {
        return <String, dynamic>{'title': 'Key Timeline', 'items': decoded};
      }
      if (kind == 'faq' || kind == 'accordion') {
        return <String, dynamic>{'title': 'Common Questions', 'items': decoded};
      }
      if (kind == 'checklist' || kind == 'steps' || kind == 'how_to') {
        return <String, dynamic>{'title': 'Action Checklist', 'items': decoded};
      }
      if (kind == 'cards' || kind == 'card') {
        return <String, dynamic>{'cards': decoded};
      }
      return <String, dynamic>{'items': decoded};
    }

    // Fallback: parse lightweight key: value lines
    final Map<String, dynamic> kv = <String, dynamic>{};
    final List<String> bullets = <String>[];
    for (final String line in raw.split('\n')) {
      final String t = line.trim();
      if (t.isEmpty) continue;
      if (t.startsWith('- ') || t.startsWith('* ')) {
        bullets.add(t.substring(2).trim());
        continue;
      }
      final int colon = t.indexOf(':');
      if (colon > 0 && colon < 32) {
        final String k = t.substring(0, colon).trim();
        final String v = t.substring(colon + 1).trim();
        if (k.isNotEmpty && v.isNotEmpty) {
          kv[_camelKey(k)] = v;
        }
      }
    }
    if (bullets.isNotEmpty) kv['items'] = bullets;
    return kv.isEmpty ? null : kv;
  }

  static String _camelKey(String raw) {
    final List<String> parts = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'));
    if (parts.isEmpty) return raw;
    return <String>[
      parts.first,
      for (final String p in parts.skip(1))
        if (p.isNotEmpty) '${p[0].toUpperCase()}${p.substring(1)}',
    ].join();
  }

  static String? _inferStructuredJsonTag(String raw) {
    final dynamic decoded = parseFlexibleJson(raw);
    if (decoded is! Map) return null;
    final bool hasTable =
        decoded['columns'] is List &&
        (decoded['columns'] as List).isNotEmpty &&
        decoded['rows'] is List;
    final bool hasFormat =
        decoded['format'] is String &&
        (decoded['summary'] is String ||
            decoded['rows'] is List ||
            decoded['evidence'] is List);
    if (hasTable || hasFormat) return 'research_panel';
    if (decoded.containsKey('scenarios') ||
        decoded.containsKey('cases') ||
        (decoded.containsKey('entry') && decoded.containsKey('stopLoss')) ||
        decoded.containsKey('leftItems') ||
        decoded.containsKey('rightItems') ||
        decoded.containsKey('entities') ||
        decoded.containsKey('quadrants') ||
        decoded.containsKey('equityCurve') ||
        decoded.containsKey('profitFactor') ||
        decoded.containsKey('holdings') ||
        decoded.containsKey('allocations') ||
        (decoded.containsKey('accountSize') &&
            decoded.containsKey('riskPct')) ||
        decoded.containsKey('indicators') ||
        decoded.containsKey('releases') ||
        decoded.containsKey('targetMean') ||
        decoded.containsKey('upgrades') ||
        decoded.containsKey('putCallRatio') ||
        decoded.containsKey('fearGreed') ||
        decoded.containsKey('formula') ||
        decoded.containsKey('equation') ||
        decoded.containsKey('marketCap') ||
        decoded.containsKey('peRatio') ||
        (decoded.containsKey('symbol') && decoded.containsKey('price')) ||
        decoded.containsKey('netWorth') ||
        decoded.containsKey('bio') ||
        decoded.containsKey('articles') ||
        decoded.containsKey('filingType') ||
        decoded.containsKey('videoUrl') ||
        decoded.containsKey('videos') ||
        decoded.containsKey('facts') ||
        decoded.containsKey('quote')) {
      return 'card';
    }
    return null;
  }

  static List<String> parseFollowUps(String raw) => _parseFollowUps(raw);

  static List<PerplexitySearchStep> parseSearchSteps(String raw) =>
      _parseSearchSteps(raw);

  static List<String> _parseFollowUps(String raw) {
    final dynamic decoded = parseFlexibleJson(raw);
    if (decoded is List) {
      return decoded
          .map((dynamic e) {
            if (e is Map) {
              return (e['question'] ?? e['prompt'] ?? e['label'] ?? e['title'])
                      ?.toString() ??
                  '';
            }
            return e.toString();
          })
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList();
    }
    if (decoded is Map) {
      final dynamic list =
          decoded['questions'] ??
          decoded['followups'] ??
          decoded['related'] ??
          decoded['items'];
      if (list is List) {
        return list.map((dynamic e) => e.toString().trim()).toList();
      }
    }
    final List<String> out = <String>[];
    for (final String line in raw.split('\n')) {
      String clean = line.trim();
      if (clean.isEmpty) continue;
      clean = clean
          .replaceFirst(RegExp(r'^(?:[-*+]|\d+\.)\s+'), '')
          .replaceAll(RegExp(r'^\[(.*)\]$'), r'$1')
          .replaceAll('**', '')
          .trim();
      if (clean.isNotEmpty && clean.length >= 6) {
        out.add(clean);
      }
    }
    return out;
  }

  static String _deriveBlockSummary({
    required String tag,
    required String body,
    required Set<String> outTickers,
    required List<_SourceCandidate> outSources,
    required List<_MediaCandidate> outMedia,
  }) {
    final Map<String, dynamic>? map = parseCardMap(body, fallbackKind: tag);
    if (map == null) return PerplexityBlockTags.friendlyLabel(tag);

    _collectUrlsAndTickersFromMap(
      map,
      outTickers: outTickers,
      outSources: outSources,
      outMedia: outMedia,
      isMediaBlock: const <String>{
        'media',
        'gallery',
        'images',
      }.contains(tag.toLowerCase().trim()),
    );

    final String? ticker = map['ticker']?.toString().trim();
    final String? name = (map['name'] ?? map['title'])?.toString().trim();
    if (ticker != null &&
        ticker.isNotEmpty &&
        name != null &&
        name.isNotEmpty) {
      return '$name ($ticker)';
    }
    if (name != null && name.isNotEmpty) return name;
    return PerplexityBlockTags.friendlyLabel(tag);
  }

  static void _collectUrlsAndTickersFromMap(
    Map<String, dynamic> map, {
    required Set<String> outTickers,
    required List<_SourceCandidate> outSources,
    required List<_MediaCandidate> outMedia,
    bool isMediaBlock = false,
  }) {
    final dynamic tickerVal = map['ticker'];
    if (tickerVal is String && tickerVal.trim().isNotEmpty) {
      outTickers.add(tickerVal.trim().replaceFirst(r'$', '').toUpperCase());
    }
    final dynamic tickersList = map['tickers'];
    if (tickersList is List) {
      for (final dynamic t in tickersList) {
        final String s = t
            .toString()
            .trim()
            .replaceFirst(r'$', '')
            .toUpperCase();
        if (s.isNotEmpty && s.length <= 8) outTickers.add(s);
      }
    }

    void addUrlCandidate(
      dynamic rawUrl, {
      String title = '',
      String publisher = '',
      String snippet = '',
      String publishedAt = '',
    }) {
      if (rawUrl is! String) return;
      final String url = rawUrl.trim();
      if (_isHttpUrl(url)) {
        outSources.add(
          _SourceCandidate(
            url: url,
            title: title,
            publisher: publisher,
            snippet: snippet,
            publishedAt: publishedAt,
          ),
        );
      }
    }

    void addMediaCandidate(
      dynamic rawUrl, {
      String caption = '',
      String sourceUrl = '',
    }) {
      if (rawUrl is! String) return;
      final String url = rawUrl.trim();
      if (_isMediaUrl(url)) {
        outMedia.add(
          _MediaCandidate(url: url, caption: caption, sourceUrl: sourceUrl),
        );
      }
    }

    final String itemCaption =
        (map['caption'] ?? map['headline'] ?? map['title'] ?? map['name'] ?? '')
            .toString();
    final String itemSourceUrl =
        (map['sourceUrl'] ?? (isMediaBlock ? '' : map['url']) ?? '').toString();
    if (isMediaBlock && map['url'] is String) {
      addMediaCandidate(
        map['url'],
        caption: itemCaption,
        sourceUrl: (map['sourceUrl'] ?? '').toString(),
      );
      if (map['sourceUrl'] is String) {
        addUrlCandidate(map['sourceUrl'], title: itemCaption);
      }
    }
    for (final String imgKey in const <String>[
      'imageUrl',
      'image_url',
      'avatarUrl',
      'avatar_url',
      'logoUrl',
      'logo_url',
      'thumbnail',
      'poster',
      'cover',
      'banner',
      'screenshot',
      'chartImage',
      'image',
    ]) {
      addMediaCandidate(
        map[imgKey],
        caption: itemCaption,
        sourceUrl: itemSourceUrl,
      );
    }

    if (!isMediaBlock) {
      addUrlCandidate(
        map['url'] ?? map['sourceUrl'],
        title:
            map['sourceTitle']?.toString() ??
            map['title']?.toString() ??
            map['name']?.toString() ??
            '',
        publisher: map['publisher']?.toString() ?? '',
        publishedAt: map['publishedAt']?.toString() ?? '',
        snippet: map['claim']?.toString() ?? '',
      );
    }

    final dynamic links = map['links'];
    if (links is List) {
      for (final dynamic link in links) {
        if (link is Map) {
          addUrlCandidate(
            link['url'] ?? link['href'],
            title: link['label']?.toString() ?? link['title']?.toString() ?? '',
          );
        } else if (link is String) {
          addUrlCandidate(link);
        }
      }
    }

    for (final String listKey in const <String>[
      'items',
      'articles',
      'evidence',
      'cards',
      'media',
      'images',
      'rows',
      'results',
      'bookmarks',
      'videos',
      'events',
      'holdings',
      'positions',
      'scenarios',
      'links',
    ]) {
      final dynamic items = map[listKey];
      if (items is List) {
        for (final dynamic item in items) {
          if (item is Map) {
            _collectUrlsAndTickersFromMap(
              Map<String, dynamic>.from(item),
              outTickers: outTickers,
              outSources: outSources,
              outMedia: outMedia,
              isMediaBlock:
                  isMediaBlock || listKey == 'media' || listKey == 'images',
            );
          } else if ((listKey == 'media' || listKey == 'images') &&
              item is String) {
            addMediaCandidate(
              item,
              caption: itemCaption,
              sourceUrl: itemSourceUrl,
            );
          }
        }
      }
    }

    // Catch bare URLs in quote/news metadata if not captured above.
    final dynamic summary = map['summary'];
    if (summary is String) {
      for (final RegExpMatch m in _bareUrlRegex.allMatches(summary)) {
        addUrlCandidate(m.group(0));
      }
    }
  }

  static List<PerplexitySearchStep> _parseSearchSteps(String raw) {
    final dynamic decoded = parseFlexibleJson(raw);
    final List<PerplexitySearchStep> steps = <PerplexitySearchStep>[];
    final List<dynamic> list = decoded is List
        ? decoded
        : (decoded is Map && decoded['steps'] is List)
        ? decoded['steps'] as List<dynamic>
        : const <dynamic>[];
    for (final dynamic entry in list) {
      if (entry is Map) {
        final String title =
            (entry['title'] ??
                    entry['step'] ??
                    entry['query'] ??
                    entry['label'])
                ?.toString()
                .trim() ??
            '';
        final String detail =
            (entry['detail'] ?? entry['description'] ?? entry['result'] ?? '')
                .toString()
                .trim();
        final String status = (entry['status'] ?? 'done').toString().trim();
        if (title.isNotEmpty) {
          steps.add(
            PerplexitySearchStep(title: title, detail: detail, status: status),
          );
        }
      } else {
        final String text = entry.toString().trim();
        if (text.isNotEmpty) {
          steps.add(PerplexitySearchStep(title: text));
        }
      }
    }
    return steps;
  }

  static List<PerplexitySearchStep> _buildSteps({
    required List<PerplexitySearchStep> parsedSteps,
    required List<String> externalSteps,
    required String? focus,
    required Set<String> tickers,
    required List<PerplexitySource> sources,
    required List<PerplexityCardSummary> cards,
    required bool isStreaming,
  }) {
    final List<PerplexitySearchStep> out = <PerplexitySearchStep>[
      ...parsedSteps,
    ];
    for (final String ext in externalSteps) {
      final String clean = ext.trim();
      if (clean.isEmpty) continue;
      if (!out.any((s) => s.title.toLowerCase() == clean.toLowerCase())) {
        out.add(PerplexitySearchStep(title: clean));
      }
    }
    if (out.isEmpty &&
        sources.isEmpty &&
        cards.isEmpty &&
        (focus == null || focus.isEmpty || focus == 'all')) {
      return const <PerplexitySearchStep>[];
    }
    if (out.isEmpty) {
      final String scope = focus != null && focus.isNotEmpty && focus != 'all'
          ? 'Focus: ${focus[0].toUpperCase()}${focus.substring(1)}'
          : 'General & financial scope';
      out.add(
        PerplexitySearchStep(
          title: 'Answer scope & mentioned entities',
          detail: tickers.isEmpty
              ? scope
              : '$scope · Tracked ${tickers.take(5).map((t) => '\$$t').join(', ')}',
        ),
      );
      if (sources.isNotEmpty) {
        final List<String> domains = sources
            .map((s) => s.domain)
            .where((d) => d.isNotEmpty)
            .toSet()
            .take(4)
            .toList();
        out.add(
          PerplexitySearchStep(
            title:
                'Collected ${sources.length} linked ${sources.length == 1 ? 'source' : 'sources'}',
            detail: domains.join(' · '),
            status: isStreaming ? 'active' : 'done',
          ),
        );
      }
      if (cards.isNotEmpty) {
        out.add(
          PerplexitySearchStep(
            title:
                'Synthesized ${cards.length} visual ${cards.length == 1 ? 'card' : 'cards'}',
            detail: cards
                .take(4)
                .map((c) => PerplexityBlockTags.friendlyLabel(c.tag))
                .toSet()
                .join(' · '),
            status: isStreaming ? 'active' : 'done',
          ),
        );
      }
    }
    return out;
  }

  static List<String> _contextualFollowUps({
    required Set<String> tickers,
    required List<PerplexityCardSummary> cards,
  }) {
    if (tickers.isNotEmpty) {
      final String primary = tickers.first;
      return <String>[
        'What are the top catalysts and risks for \$$primary?',
        'Compare \$$primary valuation and growth vs key competitors',
        'Show the latest breaking news affecting \$$primary',
      ];
    }
    if (cards.any(
      (PerplexityCardSummary c) => c.tag == 'person' || c.tag == 'bio',
    )) {
      final String who = cards.first.label;
      return <String>[
        'What are $who’s most notable recent decisions and news?',
        'Show a full career timeline and key milestones for $who',
      ];
    }
    return const <String>[
      'Break down the key numbers and takeaways into a comparison table',
      'What are the biggest risks or counterarguments to watch?',
    ];
  }

  static bool _isHttpUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        ['https', 'http'].contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  static bool _isMediaUrl(String url) {
    final String lower = url.trim().toLowerCase();
    return lower.startsWith('https://') ||
        lower.startsWith('http://') ||
        lower.startsWith('data:image/');
  }

  static String _cleanUrl(String raw) {
    return raw.trim().replaceFirst(RegExp(r'[\.,;\)]+$'), '');
  }

  static String _domainOf(Uri? uri, String fallbackUrl) {
    final String host = uri?.host.toLowerCase() ?? '';
    if (host.isEmpty) return fallbackUrl;
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  static bool _isGenericTitle(String title) {
    if (title.isEmpty) return true;
    final String lower = title.toLowerCase();
    return lower == 'source' ||
        lower == 'link' ||
        lower == 'url' ||
        lower == 'reference' ||
        lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        RegExp(r'^\[\d+\]$').hasMatch(lower) ||
        RegExp(r'^\d+$').hasMatch(lower);
  }
}

class _SourceCandidate {
  const _SourceCandidate({
    required this.url,
    this.title = '',
    this.domain = '',
    this.snippet = '',
    this.publisher = '',
    this.publishedAt = '',
  });

  final String url;
  final String title;
  final String domain;
  final String snippet;
  final String publisher;
  final String publishedAt;
}

class _MediaCandidate {
  const _MediaCandidate({
    required this.url,
    this.caption = '',
    this.sourceUrl = '',
  });

  final String url;
  final String caption;
  final String sourceUrl;
}
