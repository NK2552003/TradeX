import 'package:flutter/material.dart';

import 'markdown_editor_field.dart';

/// One insertable piece of markdown, described once and reused everywhere the
/// user can reach for it: the mobile Insert sheet, the desktop ribbon's insert
/// menu and the `/` slash palette.
///
/// Keeping the catalogue in one place is what makes the three surfaces agree.
/// Before this existed the toolbar sheet owned its own private template strings,
/// so a snippet added for the slash menu would silently be missing from the
/// sheet.
enum MarkdownSnippetKind {
  /// Standalone block dropped on its own line (table, fence, template).
  block,

  /// Wraps the selection (`**bold**`, `` `code` ``).
  wrap,

  /// Prefixes the current line (`## `, `- [ ] `).
  line,
}

@immutable
class MarkdownSnippet {
  const MarkdownSnippet({
    required this.id,
    required this.label,
    required this.icon,
    required this.group,
    this.kind = MarkdownSnippetKind.block,
    this.body = '',
    this.prefix = '',
    this.suffix = '',
    this.description,
    this.keywords = const <String>[],
  });

  final String id;
  final String label;
  final IconData icon;

  /// Section heading in the Insert sheet and the slash palette.
  final String group;
  final MarkdownSnippetKind kind;

  /// Markdown for [MarkdownSnippetKind.block].
  final String body;

  /// Markers for [MarkdownSnippetKind.wrap] and [MarkdownSnippetKind.line].
  final String prefix;
  final String suffix;

  /// One line of plain English, shown under the label in the slash palette so
  /// the menu is readable by someone who has never written markdown.
  final String? description;

  /// Extra search terms — a user typing `/bullet` should find "Bulleted list".
  final List<String> keywords;

  void applyTo(RichMarkdownEditorFieldState editor) {
    switch (kind) {
      case MarkdownSnippetKind.block:
        editor.insertBlock(body);
      case MarkdownSnippetKind.wrap:
        editor.wrapSelection(prefix, suffix);
      case MarkdownSnippetKind.line:
        editor.prefixCurrentLine(prefix);
    }
  }

  bool matches(String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return label.toLowerCase().contains(needle) ||
        group.toLowerCase().contains(needle) ||
        (description ?? '').toLowerCase().contains(needle) ||
        keywords.any((String k) => k.contains(needle));
  }
}

/// The snippet catalogue.
///
/// Groups are ordered from "things everyone needs" to "things only a trader
/// needs", which is also the order the slash palette lists them in.
class MarkdownSnippets {
  const MarkdownSnippets._();

  static const String groupBasics = 'Basics';
  static const String groupLists = 'Lists';
  static const String groupBlocks = 'Blocks';
  static const String groupTrading = 'Trading';

  static const String tableTemplate =
      '\n| Column 1 | Column 2 | Column 3 |\n| --- | --- | --- |\n| Cell | Cell | Cell |\n\n';
  static const String mermaidTemplate =
      '\n```mermaid\nflowchart TD\n    A[Start] --> B{Decision}\n    B -->|Yes| C[Do the thing]\n    B -->|No| D[Skip it]\n```\n\n';
  static const String chartTemplate =
      '\n```chart\n{\n  "type": "bar",\n  "title": "Chart title",\n  "labels": ["A", "B", "C"],\n  "series": [{"name": "Series", "data": [1, 2, 3]}]\n}\n```\n\n';
  static const String mathBlockTemplate = '\n\$\$\nE = mc^2\n\$\$\n\n';
  static const String codeTemplate = '\n```dart\n\n```\n\n';

  /// A6/A7's trader templates. Written as plain GFM so they survive a round trip
  /// through the PDF export and any future web renderer.
  static const String tradeSetupTemplate =
      '\n| Field | Value |\n'
      '| --- | --- |\n'
      '| Ticker | `\$TICKER` |\n'
      '| Entry | 0.00 |\n'
      '| Stop loss | 0.00 |\n'
      '| Target | 0.00 |\n'
      '| R:R | 1 : 2 |\n'
      '| Setup | Describe the trigger |\n\n';

  static const String weeklyReviewTemplate =
      '\n## What worked\n\n- \n\n'
      '## What did not\n\n- \n\n'
      '## Mistakes to stop repeating\n\n- [ ] \n\n'
      '## Focus for next week\n\n- [ ] \n\n';

  static const String preMarketTemplate =
      '\n## Bias\n\nNeutral until proven otherwise.\n\n'
      '## Key levels\n\n'
      '| Level | Price | Why it matters |\n'
      '| --- | --- | --- |\n'
      '| Resistance | 0.00 |  |\n'
      '| Support | 0.00 |  |\n\n'
      '## Watchlist\n\n- `\$TICKER` — reason\n\n'
      '## Rules for today\n\n'
      '- [ ] No entries in the first 15 minutes\n'
      '- [ ] Max 2 losers, then stop\n'
      '- [ ] Size down until the first win\n\n';

  static const String riskChecklistTemplate =
      '\n- [ ] Setup matches a written strategy\n'
      '- [ ] Stop is at a level, not at a round number\n'
      '- [ ] Risk is under 1% of equity\n'
      '- [ ] R:R is at least 1:2\n'
      '- [ ] I can name what would invalidate this\n\n';

  static const String tradeLogTemplate =
      '\n| Date | Ticker | Side | Entry | Exit | R | Note |\n'
      '| --- | --- | --- | --- | --- | --- | --- |\n'
      '|  |  |  |  |  |  |  |\n\n';

  static const List<MarkdownSnippet> basics = <MarkdownSnippet>[
    MarkdownSnippet(
      id: 'h1',
      label: 'Heading 1',
      icon: Icons.title_rounded,
      group: groupBasics,
      kind: MarkdownSnippetKind.line,
      prefix: '# ',
      description: 'Big section title',
      keywords: <String>['h1', 'title', 'heading'],
    ),
    MarkdownSnippet(
      id: 'h2',
      label: 'Heading 2',
      icon: Icons.text_fields_rounded,
      group: groupBasics,
      kind: MarkdownSnippetKind.line,
      prefix: '## ',
      description: 'Sub-section title',
      keywords: <String>['h2', 'heading'],
    ),
    MarkdownSnippet(
      id: 'h3',
      label: 'Heading 3',
      icon: Icons.short_text_rounded,
      group: groupBasics,
      kind: MarkdownSnippetKind.line,
      prefix: '### ',
      description: 'Smallest title',
      keywords: <String>['h3', 'heading'],
    ),
    MarkdownSnippet(
      id: 'bold',
      label: 'Bold',
      icon: Icons.format_bold_rounded,
      group: groupBasics,
      kind: MarkdownSnippetKind.wrap,
      prefix: '**',
      suffix: '**',
      description: 'Emphasise the selected words',
      keywords: <String>['strong', 'bold'],
    ),
    MarkdownSnippet(
      id: 'italic',
      label: 'Italic',
      icon: Icons.format_italic_rounded,
      group: groupBasics,
      kind: MarkdownSnippetKind.wrap,
      prefix: '*',
      suffix: '*',
      description: 'Slanted text',
      keywords: <String>['em', 'italic'],
    ),
    MarkdownSnippet(
      id: 'highlight',
      label: 'Highlight',
      icon: Icons.border_color_outlined,
      group: groupBasics,
      kind: MarkdownSnippetKind.wrap,
      prefix: '==',
      suffix: '==',
      description: 'Marker pen over the selection',
      keywords: <String>['mark', 'highlight'],
    ),
    MarkdownSnippet(
      id: 'strike',
      label: 'Strikethrough',
      icon: Icons.format_strikethrough_rounded,
      group: groupBasics,
      kind: MarkdownSnippetKind.wrap,
      prefix: '~~',
      suffix: '~~',
      description: 'Cross the selection out',
      keywords: <String>['strike', 'delete'],
    ),
    MarkdownSnippet(
      id: 'link',
      label: 'Link',
      icon: Icons.link_rounded,
      group: groupBasics,
      kind: MarkdownSnippetKind.wrap,
      prefix: '[',
      suffix: '](url)',
      description: 'Turn the selection into a link',
      keywords: <String>['url', 'href', 'link'],
    ),
    MarkdownSnippet(
      id: 'inline-code',
      label: 'Inline code',
      icon: Icons.code_rounded,
      group: groupBasics,
      kind: MarkdownSnippetKind.wrap,
      prefix: '`',
      suffix: '`',
      description: 'Monospace a ticker or a value',
      keywords: <String>['code', 'mono'],
    ),
  ];

  static const List<MarkdownSnippet> lists = <MarkdownSnippet>[
    MarkdownSnippet(
      id: 'bullets',
      label: 'Bulleted list',
      icon: Icons.format_list_bulleted_rounded,
      group: groupLists,
      kind: MarkdownSnippetKind.line,
      prefix: '- ',
      description: 'A dot for each item',
      keywords: <String>['bullet', 'ul', 'list'],
    ),
    MarkdownSnippet(
      id: 'numbers',
      label: 'Numbered list',
      icon: Icons.format_list_numbered_rounded,
      group: groupLists,
      kind: MarkdownSnippetKind.line,
      prefix: '1. ',
      description: 'Steps in order',
      keywords: <String>['ordered', 'ol', 'list'],
    ),
    MarkdownSnippet(
      id: 'checklist',
      label: 'Checklist',
      icon: Icons.checklist_rounded,
      group: groupLists,
      kind: MarkdownSnippetKind.line,
      prefix: '- [ ] ',
      description: 'Tickable boxes you can tap in reading mode',
      keywords: <String>['todo', 'task', 'check'],
    ),
    MarkdownSnippet(
      id: 'quote',
      label: 'Quote',
      icon: Icons.format_quote_rounded,
      group: groupLists,
      kind: MarkdownSnippetKind.line,
      prefix: '> ',
      description: 'Indented callout',
      keywords: <String>['blockquote', 'quote'],
    ),
  ];

  static const List<MarkdownSnippet> blocks = <MarkdownSnippet>[
    MarkdownSnippet(
      id: 'table',
      label: 'Table',
      icon: Icons.table_chart_outlined,
      group: groupBlocks,
      body: tableTemplate,
      description: 'Three columns you can edit',
      keywords: <String>['grid', 'table'],
    ),
    MarkdownSnippet(
      id: 'divider',
      // `***` is an unambiguous thematic break in CommonMark. `---` is too, but
      // only when it is not sitting directly under a line of text — there it is
      // Setext heading syntax and turns the paragraph above into a heading.
      label: 'Divider',
      icon: Icons.horizontal_rule_rounded,
      group: groupBlocks,
      body: '\n***\n\n',
      description: 'Horizontal rule between sections',
      keywords: <String>['hr', 'rule', 'divider', 'separator'],
    ),
    MarkdownSnippet(
      id: 'code-block',
      label: 'Code block',
      icon: Icons.code_off_rounded,
      group: groupBlocks,
      body: codeTemplate,
      description: 'Syntax-highlighted fence',
      keywords: <String>['fence', 'code'],
    ),
    MarkdownSnippet(
      id: 'chart',
      label: 'Chart',
      icon: Icons.insert_chart_outlined,
      group: groupBlocks,
      body: chartTemplate,
      description: 'Bar or line chart from a small JSON block',
      keywords: <String>['graph', 'chart', 'plot'],
    ),
    MarkdownSnippet(
      id: 'flowchart',
      label: 'Flowchart',
      icon: Icons.account_tree_outlined,
      group: groupBlocks,
      body: mermaidTemplate,
      description: 'Mermaid diagram of a decision tree',
      keywords: <String>['mermaid', 'diagram', 'flow'],
    ),
    MarkdownSnippet(
      id: 'math-block',
      label: 'Math block',
      icon: Icons.functions_rounded,
      group: groupBlocks,
      body: mathBlockTemplate,
      description: 'Centred LaTeX formula',
      keywords: <String>['latex', 'math', 'formula'],
    ),
    MarkdownSnippet(
      id: 'math-inline',
      label: 'Inline math',
      icon: Icons.superscript_rounded,
      group: groupBlocks,
      kind: MarkdownSnippetKind.wrap,
      prefix: r'$',
      suffix: r'$',
      description: 'A formula inside a sentence',
      keywords: <String>['latex', 'math'],
    ),
  ];

  static const List<MarkdownSnippet> trading = <MarkdownSnippet>[
    MarkdownSnippet(
      id: 'trade-setup',
      label: 'Trade setup',
      icon: Icons.flag_outlined,
      group: groupTrading,
      body: tradeSetupTemplate,
      description: 'Ticker, entry, stop, target, R:R and trigger',
      keywords: <String>['setup', 'plan', 'entry', 'trade'],
    ),
    MarkdownSnippet(
      id: 'pre-market',
      label: 'Pre-market plan',
      icon: Icons.wb_twilight_rounded,
      group: groupTrading,
      body: preMarketTemplate,
      description: 'Bias, key levels, watchlist and rules for the session',
      keywords: <String>['premarket', 'morning', 'plan'],
    ),
    MarkdownSnippet(
      id: 'weekly-review',
      label: 'Weekly review',
      icon: Icons.rate_review_outlined,
      group: groupTrading,
      body: weeklyReviewTemplate,
      description: 'What worked, what did not, and next week',
      keywords: <String>['review', 'retro', 'weekly'],
    ),
    MarkdownSnippet(
      id: 'risk-checklist',
      label: 'Risk checklist',
      icon: Icons.shield_outlined,
      group: groupTrading,
      body: riskChecklistTemplate,
      description: 'Five boxes to tick before clicking buy',
      keywords: <String>['risk', 'checklist', 'rules'],
    ),
    MarkdownSnippet(
      id: 'trade-log',
      label: 'Trade log table',
      icon: Icons.table_rows_outlined,
      group: groupTrading,
      body: tradeLogTemplate,
      description: 'One row per trade with the R multiple',
      keywords: <String>['log', 'journal', 'table'],
    ),
  ];

  static List<MarkdownSnippet> get all => <MarkdownSnippet>[
    ...basics,
    ...lists,
    ...blocks,
    ...trading,
  ];

  static const List<String> groups = <String>[
    groupBasics,
    groupLists,
    groupBlocks,
    groupTrading,
  ];

  static List<MarkdownSnippet> inGroup(String group) => all
      .where((MarkdownSnippet s) => s.group == group)
      .toList(growable: false);

  static List<MarkdownSnippet> search(String query) => all
      .where((MarkdownSnippet s) => s.matches(query))
      .toList(growable: false);
}
