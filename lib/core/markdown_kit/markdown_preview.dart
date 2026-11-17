import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'package:tradex/core/app-ui/models/app_models.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/core/markdown_kit/code_block.dart';
import 'package:tradex/core/markdown_kit/html_block.dart';
import 'package:tradex/core/markdown_kit/inline_balance.dart';
import 'package:tradex/core/markdown_kit/markdown_outline.dart';
import 'package:tradex/core/markdown_kit/math_syntax.dart';
import 'package:tradex/core/markdown_kit/scrollable_table.dart';
import 'package:tradex/core/markdown_kit/ticker_syntax.dart';
import 'research/typing_cursor_syntax.dart';

/// Renders Markdown with (near-)full GitHub-Flavored-Markdown support plus
/// the extras a note/journal app benefits from: LaTeX math (`$x$`,
/// `$$x$$`), `==highlighted==` text, syntax-highlighted fenced code blocks,
/// ```mermaid``` flowcharts/diagrams (tap for fullscreen pan+zoom +
/// download), and ```chart``` blocks. One shared widget backs every
/// preview surface in the app (editor's Preview tab, the read-only note/
/// journal screens) so they never drift out of sync with each other.
class RichMarkdownPreview extends StatelessWidget {
  const RichMarkdownPreview({
    super.key,
    required this.data,
    this.imageResolver,
    this.emptyPlaceholder =
        '*Nothing written yet. Switch to Edit and start typing — '
        'headings, checklists, tables, `code`, \$x^2\$ math, and ```mermaid``` '
        'flowcharts are all supported.*',
    this.selectable = true,
    this.shrinkWrap = true,
    this.outlineController,
    this.onOpenRef,
    this.onTapLink,
    this.onPromptTap,
    this.showTypingCursor = false,
    this.maxCollapsedChars,
  });

  /// Raw markdown source.
  final String data;

  /// Resolves image URIs (including the app's `local-image://` /
  /// `local-file://` schemes) to a displayable widget.
  final Widget Function(BuildContext context, Uri uri)? imageResolver;

  final String emptyPlaceholder;
  final bool selectable;
  final bool showTypingCursor;
  final bool shrinkWrap;

  /// When provided, every `#`–`######` heading in [data] is tracked here so a
  /// caller can show a floating "jump to section" index — see
  /// [MarkdownOutlineFab].
  final MarkdownOutlineController? outlineController;

  /// When provided, following a record/ticker link inside this markdown document
  /// (e.g. `$AAPL`, `[Tesla](tradex://ticker/TSLA)`) delegates here.
  final void Function(AppLinkRef ref)? onOpenRef;

  /// Fallback handler for standard non-internal hyperlinks.
  final void Function(String text, String? href, String title)? onTapLink;

  /// Called when an interactive Perplexity card action triggers a follow-up prompt.
  final ValueChanged<String>? onPromptTap;

  /// Optional character limit for feed/card previews (Twitter/Instagram-style
  /// "Show more" / "Show less" fold). When null, renders the full document.
  final int? maxCollapsedChars;

  @override
  Widget build(BuildContext context) {
    if (maxCollapsedChars != null &&
        data.trim().length > maxCollapsedChars! &&
        outlineController == null &&
        !showTypingCursor) {
      return _CollapsibleMarkdownPreview(
        limit: maxCollapsedChars!,
        data: data,
        imageResolver: imageResolver,
        emptyPlaceholder: emptyPlaceholder,
        selectable: selectable,
        shrinkWrap: shrinkWrap,
        onOpenRef: onOpenRef,
        onTapLink: onTapLink,
        onPromptTap: onPromptTap,
      );
    }
    final bool dark = context.ui.brightness == Brightness.dark;
    final String rawContent = data.trim().isEmpty ? emptyPlaceholder : data;
    // Close any unclosed fenced code block before appending the typing cursor
    // or running downstream passes — otherwise an in-flight streaming code
    // block swallows both the cursor marker and `_ensureTrailingInlineContent`'s
    // flush paragraph, triggering flutter_markdown's `_inlines.isEmpty` crash.
    final String content = rawContent.contains('{')
        ? _wrapBareResearchPanelJson(_closeUnclosedFence(rawContent))
        : _closeUnclosedFence(rawContent);
    final endsWithFence = RegExp(
      r'(^|\n)\s*(`{3,}|~{3,})\s*$',
    ).hasMatch(content);
    final String raw = showTypingCursor
        ? '$content${endsWithFence ? '\n' : ''}$typingCursorMarker'
        : content;
    // Raw HTML is pulled out (and replaced with inert placeholder tokens)
    // before any of the markdown-specific normalization passes below run,
    // so a `$`/`==` inside an HTML attribute or an `<img>`'s `alt` text is
    // never mistaken for a dangling math/highlight marker. See
    // html_block.dart for how the placeholders are turned back into
    // widgets via the 'html_node' builder registered in [_markdownBody].
    final Map<String, HtmlNode> htmlRegistry = <String, HtmlNode>{};
    final String htmlProcessed = raw.contains('<')
        ? renderSafeHtml(raw, htmlRegistry)
        : raw;
    final String source = normalizeHeadingBoundaries(
      neutralizeDanglingCustomMarkers(htmlProcessed),
    );
    final MarkdownStyleSheet styleSheet = buildStyleSheet(context);

    final MarkdownOutlineController? outline = outlineController;
    if (outline == null) {
      final Widget rendered =
          (!showTypingCursor && source.length > 2400)
          ? _ProgressiveMarkdownChunks(
              chunks: _splitIntoRenderChunks(source, maxChunkChars: 1200),
              spacing: styleSheet.blockSpacing ?? 14,
              chunkBuilder: (String chunk) => _body(
                context,
                chunk,
                styleSheet,
                dark,
                htmlRegistry,
              ),
            )
          : _body(
              context,
              source,
              styleSheet,
              dark,
              htmlRegistry,
            );
      return selectable && SelectionContainer.maybeOf(context) == null
          ? SelectionArea(child: rendered)
          : rendered;
    }

    // Headings are rendered by flutter_markdown's own h1–h6 path (never by a
    // custom element builder): taking over a block tag with a custom builder
    // hands that tag's whole layout — and flutter_markdown's internal block/
    // text-style bookkeeping for it — to us, which is what previously let a
    // heading's style bleed onto the paragraph that followed it. To still be
    // able to scroll to a heading, the document is split at its heading lines
    // and each section is rendered as its own `MarkdownBody` inside a keyed
    // wrapper. Same parser, same stylesheet, same visual result.
    final List<_MarkdownSection> sections = _splitIntoSections(source);
    final List<MarkdownHeading> collected = <MarkdownHeading>[];
    final Set<String> liveCacheIds = <String>{};
    final Map<String, int> occurrences = <String, int>{};
    final double spacing = styleSheet.blockSpacing ?? 14;

    final List<Widget> children = <Widget>[];
    for (int i = 0; i < sections.length; i++) {
      final _MarkdownSection section = sections[i];
      Widget child = _body(
        context,
        section.markdown,
        styleSheet,
        dark,
        htmlRegistry,
      );

      final String? title = section.title;
      if (title != null && section.level != null) {
        final int occurrence = occurrences[title] ?? 0;
        occurrences[title] = occurrence + 1;
        final String cacheId = '${section.level}::$title::$occurrence';
        liveCacheIds.add(cacheId);
        final GlobalKey key = outline.keyFor(cacheId);
        collected.add(
          MarkdownHeading(level: section.level!, text: title, key: key),
        );
        child = KeyedSubtree(key: key, child: child);
      }

      if (i > 0) children.add(SizedBox(height: spacing));
      children.add(child);
    }

    // The sections above only report their headings once this widget's own
    // build has produced a live element tree, so committing from a post-frame
    // callback guarantees every GlobalKey is attached to a mounted widget
    // before anything tries to scroll to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      outline.commit(collected, liveCacheIds);
    });

    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    return selectable && SelectionContainer.maybeOf(context) == null
        ? SelectionArea(child: column)
        : column;
  }

  Widget _body(
    BuildContext context,
    String source,
    MarkdownStyleSheet styleSheet,
    bool dark,
    Map<String, HtmlNode> htmlRegistry,
  ) {
    // GFM tables are pulled out of the markdown before it ever reaches
    // `MarkdownBody` and rendered by [ScrollableTableBuilder.buildTable]
    // directly, rather than relying on `MarkdownBody`'s `builders['table']`
    // dispatch — see the note on [ScrollableTableBuilder.buildTable] for
    // why. Everything else still goes through `MarkdownBody` exactly as
    // before, just in the (possibly several) chunks the table split leaves
    // it in.
    final ScrollableTableBuilder tableBuilder = ScrollableTableBuilder(
      styleSheet: styleSheet,
      borderColor: context.uiColors.border,
    );
    final List<_SourcePiece> pieces = _extractTableBlocks(source);
    final double spacing = styleSheet.blockSpacing ?? 14;

    final List<Widget> children = <Widget>[];
    for (final _SourcePiece piece in pieces) {
      Widget? child;
      if (piece.alertKind != null) {
        child = _buildAlertCallout(piece);
      } else if (piece.isTable) {
        final md.Element? table = _parseSingleTable(piece.text);
        if (table != null) child = tableBuilder.buildTable(table);
      }
      // Either not a table piece, or it didn't actually parse as one (an
      // over-eager match on ordinary text with pipes in it, say) — fall
      // back to rendering it as plain markdown so nothing is ever lost.
      child ??= _markdownBody(
        context,
        piece.text,
        styleSheet,
        dark,
        tableBuilder,
        htmlRegistry,
      );

      if (children.isNotEmpty) children.add(SizedBox(height: spacing));
      children.add(child);
    }

    if (children.isEmpty) {
      return _markdownBody(
        context,
        source,
        styleSheet,
        dark,
        tableBuilder,
        htmlRegistry,
      );
    }
    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    return selectable && SelectionContainer.maybeOf(context) == null
        ? SelectionArea(child: column)
        : column;
  }

  Widget _markdownBody(
    BuildContext context,
    String source,
    MarkdownStyleSheet styleSheet,
    bool dark,
    ScrollableTableBuilder tableBuilder,
    Map<String, HtmlNode> htmlRegistry,
  ) {
    return MarkdownBody(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      shrinkWrap: shrinkWrap,
      // Selection is handled by a single outer [SelectionArea] rather than
      // per-paragraph [SelectableText] widgets, which avoids heavy Web DOM
      // overhead and blank-height layout glitches during streaming/scrolling.
      selectable: false,
      data: _ensureTrailingInlineContent(source),
      inlineSyntaxes: <md.InlineSyntax>[
        if (showTypingCursor) TypingCursorSyntax(),
        TickerInlineSyntax(),
        MathBlockSyntax(),
        MathInlineSyntax(),
        HighlightMarkSyntax(),
        HtmlPlaceholderSyntax(),
      ],
      builders: <String, MarkdownElementBuilder>{
        if (showTypingCursor) 'typing_cursor': TypingCursorBuilder(),
        'ticker': TickerElementBuilder(onOpenRef: onOpenRef),
        'pre': RichCodeBlockBuilder(
          dark: dark,
          onOpenRef: onOpenRef,
          onTapUrl: (String url) => _handleExternalTap(url, url, ''),
          onPromptTap: onPromptTap,
        ),
        'math_inline': MathInlineBuilder(),
        'math_block': MathBlockBuilder(),
        'mark': HighlightMarkBuilder(dark: dark),
        // Composes with the builders above exactly the same way — see
        // html_block.dart for the safe-HTML-subset parsing this renders.
        'html_node': HtmlInlineBuilder(
          registry: htmlRegistry,
          styleSheet: styleSheet,
          dark: dark,
          tableBuilder: tableBuilder,
          selectable: selectable,
          resolveImage: imageResolver == null
              ? null
              : (Uri uri) => imageResolver!(context, uri),
        ),
        // Kept registered as a harmless fallback for any table that isn't
        // caught by [extractTableBlocks] above (belt and braces — the
        // extraction is line-based and deliberately conservative, so an
        // edge case could in principle slip through to here).
        'table': tableBuilder,
      },
      onTapLink: (String text, String? href, String title) {
        if (href != null) {
          final Uri? uri = Uri.tryParse(href);
          if (uri != null && AppDeepLink.isInternal(uri)) {
            final target = AppDeepLink.target(uri);
            if (target != null && onOpenRef != null) {
              onOpenRef!(
                AppLinkRef(
                  kind: target.kind,
                  id: target.id,
                  title: text.isNotEmpty ? text : target.id,
                ),
              );
              return;
            }
          }
        }
        _handleExternalTap(text, href, title);
      },

      sizedImageBuilder: imageResolver == null
          ? null
          : (MarkdownImageConfig config) => imageResolver!(context, config.uri),
      styleSheet: styleSheet,
    );
  }

  void _handleExternalTap(String text, String? href, String title) {
    if (onTapLink != null) {
      onTapLink!(text, href, title);
      return;
    }
    if (href == null) return;
    final Uri? uri = Uri.tryParse(href);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static MarkdownStyleSheet buildStyleSheet(BuildContext context) {
    final colors = context.uiColors;
    final text = context.uiText;
    return MarkdownStyleSheet(
      p: text.body,
      h1: text.heading.copyWith(
        fontSize: 27,
        fontWeight: FontWeight.w800,
        height: 1.35,
      ),
      h2: text.heading.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      h3: text.subheading.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      h4: text.subheading.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      h5: text.bodyStrong,
      h6: text.bodyStrong.copyWith(color: colors.foregroundMuted),
      em: text.body.copyWith(fontStyle: FontStyle.italic),
      strong: text.body.copyWith(fontWeight: FontWeight.w700),
      del: text.body.copyWith(
        decoration: TextDecoration.lineThrough,
        color: colors.foregroundMuted,
      ),
      blockquote: text.body.copyWith(
        color: colors.foregroundMuted,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: colors.border, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      code: text.numeric.copyWith(
        backgroundColor: colors.surfaceMuted,
        fontSize: (text.numeric.fontSize ?? 13) * 0.95,
      ),
      // Custom code/card builders own their surface; avoid nested chrome.
      codeblockDecoration: const BoxDecoration(),
      codeblockPadding: EdgeInsets.zero,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      listBullet: text.body,
      listIndent: 22,
      checkbox: text.body.copyWith(color: colors.primary),
      tableHead: text.bodyStrong.copyWith(color: colors.foreground),
      tableBody: text.body.copyWith(color: colors.foreground),
      tableBorder: TableBorder.all(color: colors.border, width: 1),
      tableHeadAlign: TextAlign.left,
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),

      // Tables are rendered by [ScrollableTableBuilder] (content-sized columns
      // inside a horizontal scroll view), so no fixed/flex column width is set
      // here — this stylesheet only supplies the shared text/border styling.
      a: text.body.copyWith(
        color: colors.primary,
        decoration: TextDecoration.underline,
      ),
      img: text.body,
      blockSpacing: 14,
    );
  }

  static Widget _buildAlertCallout(_SourcePiece piece) {
    final String kind = (piece.alertKind ?? 'NOTE').toUpperCase();
    final (
      UiIntent intent,
      IconData icon,
      String defaultTitle,
    ) = switch (kind) {
      'TIP' => (UiIntent.bullish, Icons.lightbulb_outline, 'Tip'),
      'IMPORTANT' => (UiIntent.primary, Icons.campaign_outlined, 'Important'),
      'WARNING' => (UiIntent.warning, Icons.warning_amber_rounded, 'Warning'),
      'CAUTION' => (UiIntent.bearish, Icons.error_outline, 'Caution'),
      _ => (UiIntent.info, Icons.info_outline, 'Note'),
    };
    final String title =
        (piece.alertTitle != null && piece.alertTitle!.trim().isNotEmpty)
        ? piece.alertTitle!.trim()
        : defaultTitle;
    return UiCallout(
      title: title,
      message: piece.text.trim().isEmpty ? null : piece.text.trim(),
      intent: intent,
      icon: icon,
    );
  }
}

/// One piece of a document produced by [extractTableBlocks]: either an
/// ordinary markdown chunk, a standalone GFM table block, or a GitHub-style
/// alert blockquote (`> [!NOTE]`, `> [!TIP]`, `> [!WARNING]`, etc.).
class _SourcePiece {
  const _SourcePiece({
    required this.text,
    required this.isTable,
    this.alertKind,
    this.alertTitle,
  });
  final String text;
  final bool isTable;
  final String? alertKind;
  final String? alertTitle;
}

final RegExp _alertHeaderRow = RegExp(
  r'^ {0,3}>\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\](?:[ \t]+(.*))?$',
  caseSensitive: false,
);

/// A GFM table delimiter row: optional leading/trailing `|`, one or more
/// `---`/`:--`/`--:`/`:-:` cells separated by `|`. This is the one line in a
/// table block that can't be mistaken for anything else, so it's what
/// triggers detection — the line above it (already sitting in the buffer)
/// is then reclassified as the table's header row.
final RegExp _tableDelimiterRow = RegExp(
  r'^ {0,3}\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)*\|?\s*$',
);

/// Splits [source] into ordinary markdown chunks, standalone GFM table
/// blocks, and GitHub-style alert callouts, skipping anything inside a fenced
/// code block.
List<_SourcePiece> _extractTableBlocks(String source) {
  final List<String> lines = source.split('\n');
  final List<_SourcePiece> pieces = <_SourcePiece>[];
  List<String> buffer = <String>[];
  bool inFence = false;

  void flushMarkdown() {
    final String text = buffer.join('\n');
    buffer = <String>[];
    if (text.trim().isEmpty) return;
    pieces.add(_SourcePiece(text: text, isTable: false));
  }

  int i = 0;
  while (i < lines.length) {
    final String line = lines[i];

    if (_fence.hasMatch(line)) {
      inFence = !inFence;
      buffer.add(line);
      i++;
      continue;
    }

    if (!inFence) {
      final RegExpMatch? alertMatch = _alertHeaderRow.firstMatch(line);
      if (alertMatch != null) {
        flushMarkdown();
        final String kind = (alertMatch.group(1) ?? 'NOTE').toUpperCase();
        final String? customTitle = alertMatch.group(2);
        final List<String> bodyLines = <String>[];
        int j = i + 1;
        while (j < lines.length) {
          final String next = lines[j];
          final RegExpMatch? quoteLine = RegExp(
            r'^ {0,3}> ?(.*)$',
          ).firstMatch(next);
          if (quoteLine == null) break;
          bodyLines.add(quoteLine.group(1) ?? '');
          j++;
        }
        pieces.add(
          _SourcePiece(
            text: bodyLines.join('\n').trim(),
            isTable: false,
            alertKind: kind,
            alertTitle: customTitle,
          ),
        );
        i = j;
        continue;
      }
    }

    final bool looksLikeDelimiter =
        !inFence && _tableDelimiterRow.hasMatch(line);
    final String? headerCandidate = buffer.isEmpty ? null : buffer.last;
    final bool headerLooksReal =
        headerCandidate != null &&
        headerCandidate.trim().isNotEmpty &&
        headerCandidate.contains('|');

    if (looksLikeDelimiter && headerLooksReal) {
      final String headerLine = buffer.removeLast();
      flushMarkdown();

      final List<String> tableLines = <String>[headerLine, line];
      int j = i + 1;
      while (j < lines.length) {
        final String next = lines[j];
        if (next.trim().isEmpty || !next.contains('|')) break;
        tableLines.add(next);
        j++;
      }
      pieces.add(_SourcePiece(text: tableLines.join('\n'), isTable: true));
      i = j;
      continue;
    }

    buffer.add(line);
    i++;
  }
  flushMarkdown();

  if (pieces.isEmpty) pieces.add(_SourcePiece(text: source, isTable: false));
  return pieces;
}

/// Parses [tableSource] (the raw markdown of a single table block, as
/// produced by [_extractTableBlocks]) and returns its `table` element, or
/// `null` if it didn't actually parse as one — e.g. a false-positive match
/// on ordinary text. The caller falls back to rendering the text as plain
/// markdown in that case, so no content is ever silently dropped.
md.Element? _parseSingleTable(String tableSource) {
  final md.Document document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  final List<md.Node> nodes = document.parseLines(tableSource.split('\n'));
  for (final md.Node node in nodes) {
    if (node is md.Element && node.tag == 'table') return node;
  }
  return null;
}

/// One slice of a document: an ATX heading line plus everything under it
/// until the next heading (or, for the very first slice, any preamble that
/// appears before the first heading — [level] and [title] are null there).
class _MarkdownSection {
  const _MarkdownSection({required this.markdown, this.level, this.title});

  final String markdown;
  final int? level;
  final String? title;
}

/// CommonMark ATX heading: up to 3 leading spaces, 1–6 `#`, then a space/tab
/// or end of line. `#hashtag` (no space) deliberately does NOT match, so
/// inline hashtags typed in note content are never treated as headings.
final RegExp _atxHeading = RegExp(r'^ {0,3}(#{1,6})(?:[ \t]+(.*))?$');
final RegExp _fence = RegExp(r'^ {0,3}(```+|~~~+)');

/// Splits [source] at top-level ATX heading lines. Lines inside fenced code
/// blocks are never treated as headings.
List<_MarkdownSection> _splitIntoSections(String source) {
  final List<String> lines = source.split('\n');
  final List<_MarkdownSection> sections = <_MarkdownSection>[];
  List<String> buffer = <String>[];
  int? level;
  String? title;
  bool inFence = false;

  void flush() {
    final String text = buffer.join('\n');
    if (text.trim().isEmpty && level == null) return;
    sections.add(_MarkdownSection(markdown: text, level: level, title: title));
  }

  for (final String line in lines) {
    if (_fence.hasMatch(line)) {
      inFence = !inFence;
      buffer.add(line);
      continue;
    }

    final RegExpMatch? match = inFence ? null : _atxHeading.firstMatch(line);
    if (match != null) {
      flush();
      buffer = <String>[line];
      level = (match.group(1) ?? '#').length;
      title = _plainHeadingText(match.group(2) ?? '');
      if (title.isEmpty) {
        level = null;
        title = null;
      }
      continue;
    }
    buffer.add(line);
  }
  flush();

  if (sections.isEmpty) {
    sections.add(_MarkdownSection(markdown: source));
  }
  return sections;
}

/// Strips the closing `###` of a closed ATX heading and the most common
/// inline markers, so the outline sheet shows readable labels.
String _plainHeadingText(String raw) {
  String text = raw.replaceFirst(RegExp(r'\s+#+\s*$'), '').trim();
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (Match m) => m.group(1) ?? '',
  );
  text = text.replaceAll(RegExp(r'[*_`~]'), '');
  text = text.replaceAll('==', '');
  return text.trim();
}

/// Guards against `'package:flutter_markdown/src/builder.dart': Failed
/// assertion: '_inlines.isEmpty': is not true` — a long-standing crash in
/// flutter_markdown's widget builder that a handful of other apps have hit
/// with their own custom inline syntaxes. Unlike `*`, `_` and `` ` ``,
/// which the underlying `markdown` package's CommonMark-compliant delimiter
/// algorithm already resolves safely when unmatched, [MathBlockSyntax],
/// [MathInlineSyntax] and [HighlightMarkSyntax] each fire off a single raw
/// regex match with no such bookkeeping. A stray, uncleaned `$` (a price:
/// "cost $20"), `==` (a comparison typed outside a code fence: "if (a ==
/// b)"), or `$$` left with nothing to pair with can leave the parser's
/// internal span stack unbalanced, and that is what flutter_markdown's
/// builder then trips on.
///
/// This runs before the document ever reaches the parser and, per
/// paragraph (never inside a fenced code block, and never touching
/// characters already escaped with `\`), counts each of those three
/// markers; if a marker has an odd number of occurrences — meaning the
/// last one has no partner to close it — a `\` is inserted right before
/// that last occurrence so it renders as a literal character instead of
/// being treated as an opener.
String neutralizeDanglingCustomMarkers(String source) {
  final List<String> lines = source.split('\n');
  final List<String> out = <String>[];
  final List<String> buffer = <String>[];
  bool inFence = false;

  void flush() {
    if (buffer.isEmpty) return;
    out.add(_balanceCustomMarkers(buffer.join('\n')));
    buffer.clear();
  }

  for (final String line in lines) {
    if (_fence.hasMatch(line)) {
      flush();
      out.add(line);
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      out.add(line);
      continue;
    }
    buffer.add(line);
  }
  flush();
  return out.join('\n');
}

String _balanceCustomMarkers(String chunk) {
  String text = chunk;
  // `$$` first, mirroring MathBlockSyntax being registered ahead of
  // MathInlineSyntax, so a balanced `$$formula$$` block is settled before
  // the single-`$` pass ever looks at it.
  text = _neutralizeToken(text, r'$$');
  text = _neutralizeToken(text, '==');
  text = _neutralizeSingleDollar(text);
  return text;
}

/// Pairs up consecutive, non-overlapping, unescaped occurrences of [token]
/// (open, close, open, close, ...). If one is left over with nothing to
/// pair with, a `\` is inserted right before it.
String _neutralizeToken(String text, String token) {
  final int len = token.length;
  final List<int> positions = <int>[];
  int i = 0;
  while (i <= text.length - len) {
    if (text.startsWith(token, i) && (i == 0 || text[i - 1] != '\\')) {
      positions.add(i);
      i += len;
    } else {
      i++;
    }
  }
  if (positions.length.isEven) return text;
  final int last = positions.last;
  return '${text.substring(0, last)}\\${text.substring(last)}';
}

/// Same idea as [_neutralizeToken] for a single `$`, but skips straight
/// over any `$$` pair (already settled by the earlier pass) so a balanced
/// math block is never miscounted as two dangling single dollars.
/// Also skips tickers / cashtags (e.g. `$NVDA`, `$AAPL`) so they are not
/// mistaken for unclosed LaTeX math delimiters.
String _neutralizeSingleDollar(String text) {
  final List<int> positions = <int>[];
  final RegExp tickerPattern = RegExp(
    r'(?<![\$\w])\$[A-Za-z\^][A-Za-z0-9\.\-\_\^\=]{0,9}\b(?!\$)',
  );
  final Set<int> tickerDollarPositions = <int>{};
  for (final Match m in tickerPattern.allMatches(text)) {
    tickerDollarPositions.add(m.start);
  }

  int i = 0;
  while (i < text.length) {
    if (text[i] == r'$' && (i == 0 || text[i - 1] != '\\')) {
      if (i + 1 < text.length && text[i + 1] == r'$') {
        i += 2; // opening half of a `$$` token — already handled
        continue;
      }
      if (i > 0 && text[i - 1] == r'$') {
        i += 1; // closing half of a `$$` token — already handled
        continue;
      }
      if (tickerDollarPositions.contains(i)) {
        i += 1; // cashtag / ticker token — handled by TickerInlineSyntax
        continue;
      }
      positions.add(i);
    }
    i += 1;
  }
  if (positions.length.isEven) return text;
  final int last = positions.last;
  return '${text.substring(0, last)}\\${text.substring(last)}';
}

/// flutter_markdown's builder trips `Failed assertion: '_inlines.isEmpty'`
/// whenever a document (or, here, one of [splitIntoSections]'s per-heading
/// slices) ends while a parent inline element that never received a single
/// child widget is still on its internal stack — see
/// [markdownLeaksInlineStack] for the mechanism. A trailing fenced code
/// block is the most common producer, but it is far from the only one: an
/// indented (4-space) code block, an unterminated fence, a trailing table,
/// or an image-only last paragraph all leave the same dangling entry, and
/// a fence-shaped last line is neither necessary nor sufficient to detect
/// it.
///
/// So instead of guessing from the text, the document is parsed once with
/// the exact same parser configuration the preview uses and the builder's
/// stack bookkeeping is replayed over the resulting AST. Only when that
/// replay predicts a leak is an invisible zero-width-space paragraph
/// appended — enough of an ordinary trailing inline span for
/// flutter_markdown to close out its stack cleanly, with nothing visible
/// to the reader and no stray gap added to documents that don't need it.
String _ensureTrailingInlineContent(String source) {
  if (source.trim().isEmpty) return source;
  if (markdownLeaksInlineStack(source)) {
    final String closed = _closeUnclosedFence(source.trimRight());
    return '$closed\n\n\u200B';
  }
  return source;
}

/// Closes an unterminated CommonMark fenced code block (```` ``` ```` or `~~~`)
/// at the end of [source] so trailing paragraphs/cursors are not swallowed into
/// `<pre><code>`.
String _closeUnclosedFence(String source) {
  final RegExp openFencePattern = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$');
  final RegExp closeFencePattern = RegExp(r'^ {0,3}(`{3,}|~{3,})[ \t]*$');
  String? openChar;
  int openLen = 0;

  for (final String line in source.split('\n')) {
    if (openChar == null) {
      final Match? m = openFencePattern.firstMatch(line);
      if (m != null) {
        final String fence = m.group(1)!;
        final String info = m.group(2) ?? '';
        // Backtick fence info strings cannot contain backticks in CommonMark.
        if (fence[0] == '`' && info.contains('`')) continue;
        openChar = fence[0];
        openLen = fence.length;
      }
    } else {
      final Match? m = closeFencePattern.firstMatch(line);
      if (m != null) {
        final String fence = m.group(1)!;
        if (fence[0] == openChar && fence.length >= openLen) {
          openChar = null;
          openLen = 0;
        }
      }
    }
  }

  if (openChar == null) return source;
  final String prefix = source.endsWith('\n') ? source : '$source\n';
  return '$prefix${openChar * openLen}';
}

/// Wraps standalone top-level bare JSON blocks (not already inside a fenced
/// code block) that match the [ResearchPanel] schema into
/// ```` ```research_panel ```` fences so saved notes or pasted AI outputs
/// render identically to Copilot.
String _wrapBareResearchPanelJson(String source) {
  final List<String> lines = source.split('\n');
  final List<String> out = <String>[];
  bool inFence = false;
  int i = 0;

  while (i < lines.length) {
    final String line = lines[i];
    if (_fence.hasMatch(line)) {
      inFence = !inFence;
      out.add(line);
      i++;
      continue;
    }
    if (!inFence && line.trimLeft().startsWith('{')) {
      int end = -1;
      for (int j = i; j < lines.length; j++) {
        if (j > i && _fence.hasMatch(lines[j])) break;
        final String candidate = lines.sublist(i, j + 1).join('\n');
        if (lines[j].trimRight().endsWith('}') &&
            isStructuredPerplexityJson(candidate)) {
          end = j;
          break;
        }
      }
      if (end != -1) {
        final String candidate = lines.sublist(i, end + 1).join('\n');
        final String fenceTag = isResearchPanelJson(candidate)
            ? 'research_panel'
            : 'card';
        out
          ..add('```$fenceTag')
          ..addAll(lines.sublist(i, end + 1))
          ..add('```');
        i = end + 1;
        continue;
      }
    }
    out.add(line);
    i++;
  }
  return out.join('\n');
}

/// Splits [source] at top-level blank lines outside fenced code blocks into
/// chunks of roughly [maxChunkChars] so huge documents can render progressively
/// without blocking a single frame.
List<String> _splitIntoRenderChunks(
  String source, {
  int maxChunkChars = 1200,
}) {
  final List<String> lines = source.split('\n');
  final List<String> chunks = <String>[];
  final StringBuffer current = StringBuffer();
  bool inFence = false;

  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    if (_fence.hasMatch(line)) inFence = !inFence;
    if (current.isNotEmpty) current.write('\n');
    current.write(line);

    if (!inFence && line.trim().isEmpty && current.length >= maxChunkChars) {
      final String chunk = current.toString().trim();
      if (chunk.isNotEmpty) chunks.add(chunk);
      current.clear();
    }
  }
  final String tail = current.toString().trim();
  if (tail.isNotEmpty) chunks.add(tail);
  return chunks.isEmpty ? <String>[source] : chunks;
}

class _ProgressiveMarkdownChunks extends StatefulWidget {
  const _ProgressiveMarkdownChunks({
    required this.chunks,
    required this.spacing,
    required this.chunkBuilder,
  });

  final List<String> chunks;
  final double spacing;
  final Widget Function(String chunk) chunkBuilder;

  @override
  State<_ProgressiveMarkdownChunks> createState() =>
      _ProgressiveMarkdownChunksState();
}

class _ProgressiveMarkdownChunksState
    extends State<_ProgressiveMarkdownChunks> {
  static const int _initialChunks = 2;
  static const int _chunksPerFrame = 2;

  late int _visibleCount;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.chunks.length.clamp(0, _initialChunks);
    _scheduleNextBatch();
  }

  @override
  void didUpdateWidget(covariant _ProgressiveMarkdownChunks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chunks.length < _visibleCount) {
      _visibleCount = widget.chunks.length;
    }
    _scheduleNextBatch();
  }

  void _scheduleNextBatch() {
    if (_scheduled || _visibleCount >= widget.chunks.length) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _visibleCount >= widget.chunks.length) return;
      setState(() {
        _visibleCount = (_visibleCount + _chunksPerFrame).clamp(
          0,
          widget.chunks.length,
        );
      });
      _scheduleNextBatch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < _visibleCount; i++) ...<Widget>[
          if (i > 0) SizedBox(height: widget.spacing),
          RepaintBoundary(child: widget.chunkBuilder(widget.chunks[i])),
        ],
      ],
    );
  }
}

class _CollapsibleMarkdownPreview extends StatefulWidget {
  const _CollapsibleMarkdownPreview({
    required this.limit,
    required this.data,
    required this.imageResolver,
    required this.emptyPlaceholder,
    required this.selectable,
    required this.shrinkWrap,
    required this.onOpenRef,
    required this.onTapLink,
    required this.onPromptTap,
  });

  final int limit;
  final String data;
  final Widget Function(BuildContext context, Uri uri)? imageResolver;
  final String emptyPlaceholder;
  final bool selectable;
  final bool shrinkWrap;
  final void Function(AppLinkRef ref)? onOpenRef;
  final void Function(String text, String? href, String title)? onTapLink;
  final ValueChanged<String>? onPromptTap;

  @override
  State<_CollapsibleMarkdownPreview> createState() =>
      _CollapsibleMarkdownPreviewState();
}

class _CollapsibleMarkdownPreviewState
    extends State<_CollapsibleMarkdownPreview> {
  bool _expanded = false;

  String _truncate(String input, int limit) {
    if (input.length <= limit) return input;
    int cut = input.lastIndexOf(RegExp(r'\s'), limit);
    if (cut < (limit * 0.5).round()) cut = limit;
    return '${input.substring(0, cut).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    final String effectiveData = _expanded
        ? widget.data
        : _truncate(widget.data, widget.limit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RichMarkdownPreview(
          data: effectiveData,
          imageResolver: widget.imageResolver,
          emptyPlaceholder: widget.emptyPlaceholder,
          selectable: widget.selectable,
          shrinkWrap: widget.shrinkWrap,
          onOpenRef: widget.onOpenRef,
          onTapLink: widget.onTapLink,
          onPromptTap: widget.onPromptTap,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: UiButton(
            label: _expanded ? 'Show less' : 'Show more',
            variant: UiVariant.link,
            size: UiSize.xs,
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
        ),
      ],
    );
  }
}

/// Two independent defenses against a heading silently absorbing text it
/// shouldn't, both applied as a single line-by-line pass before the
/// document ever reaches the markdown parser. Content inside fenced code
/// blocks is left completely untouched by either.
///
/// 1. **Accidental Setext headings.** A line of only `-` (or `=`)
///    characters directly under a line of text — with **no blank line
///    between them** — is CommonMark's Setext heading syntax: it silently
///    turns the line above into a heading and swallows the `-`/`=` line
///    instead of showing it. This app never intentionally writes Setext
///    headings (the toolbar only ever inserts ATX `# ` headings), but
///    people naturally type a `---` divider right after a paragraph.
///
/// 2. **Headings merging with adjacent text.** An ATX heading renders as a
///    cleanly isolated block when it has a blank line on *both* sides.
///    Forcing that removes any lazy-continuation ambiguity.
///
/// Both fixes only ever *insert* blank lines into the source that's handed
/// to the parser (never delete or reorder anything a person wrote), and a
/// blank line between blocks doesn't introduce any visible extra spacing of
/// its own — on-screen gaps come entirely from
/// [MarkdownStyleSheet.blockSpacing].
String normalizeHeadingBoundaries(String source) {
  final List<String> lines = source.split('\n');
  final RegExp setextUnderline = RegExp(r'^ {0,3}([-=])\1*[ \t]*$');
  final RegExp atxHeadingLine = RegExp(r'^ {0,3}#{1,6}(?:[ \t]|$)');
  bool inFence = false;
  final List<String> out = <String>[];

  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];

    if (_fence.hasMatch(line)) {
      inFence = !inFence;
      out.add(line);
      continue;
    }
    if (inFence) {
      out.add(line);
      continue;
    }

    final bool precedingLineNeedsGap =
        out.isNotEmpty && out.last.trim().isNotEmpty;

    if (setextUnderline.hasMatch(line) && precedingLineNeedsGap) {
      out.add('');
    } else if (atxHeadingLine.hasMatch(line) && precedingLineNeedsGap) {
      out.add('');
    }

    out.add(line);

    if (atxHeadingLine.hasMatch(line)) {
      final String? next = i + 1 < lines.length ? lines[i + 1] : null;
      if (next != null && next.trim().isNotEmpty) {
        out.add('');
      }
    }
  }
  return out.join('\n');
}
