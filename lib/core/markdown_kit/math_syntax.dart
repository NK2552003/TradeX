import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// Matches `$$...$$` LaTeX blocks (rendered centered, display-style).
/// Registered *before* [MathInlineSyntax] so a `$$` pair is never mistaken
/// for two adjacent inline `$...$` spans.
class MathBlockSyntax extends md.InlineSyntax {
  MathBlockSyntax() : super(r'\$\$([\s\S]+?)\$\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final String tex = (match[1] ?? '').trim();
    if (tex.isEmpty) return false;
    parser.addNode(md.Element.text('math_block', tex));
    return true;
  }
}

/// Matches inline `$...$` LaTeX. Requires non-`$` content with no adjacent
/// `$` on either side (so it never fires inside a `$$...$$` block), forbids a
/// leading/trailing space inside the delimiters, and forbids a closing `$`
/// immediately followed by a digit (e.g. `$1.75 trillion ... $1.5 trillion`)
/// plus URLs / markdown links / currency prose so financial amounts never get
/// misparsed as LaTeX math. A literal dollar sign can still be escaped as `\$`.
class MathInlineSyntax extends md.InlineSyntax {
  MathInlineSyntax() : super(r'(?<!\$)\$(?!\$)(\S(?:[^$\n]*?\S)?)\$(?![\$\d])');

  static final RegExp _hasMathOperator = RegExp(
    r'[\\^_=<>±×÷≤≥≠≈∑∫√]',
  );
  static final RegExp _currencyStart = RegExp(
    r'^\d[\d,.]*(?:\s|[kKmMbBtT]\b)',
  );
  static final RegExp _multiWordProse = RegExp(
    r'[A-Za-z]{3,}\s+[A-Za-z]{2,}\s+[A-Za-z]{3,}',
  );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final String tex = (match[1] ?? '').trim();
    if (tex.isEmpty) return false;
    if (tex.contains('http://') ||
        tex.contains('https://') ||
        tex.contains('](')) {
      return false;
    }
    if (!_hasMathOperator.hasMatch(tex) &&
        (_currencyStart.hasMatch(tex) || _multiWordProse.hasMatch(tex))) {
      return false;
    }
    parser.addNode(md.Element.text('math_inline', tex));
    return true;
  }
}

/// Matches `==highlighted text==` (a common GFM-adjacent extension used by
/// Obsidian/Notion-style editors; not part of core GFM but widely expected
/// by anyone coming from those apps).
class HighlightMarkSyntax extends md.InlineSyntax {
  HighlightMarkSyntax() : super(r'==([^=\n]+)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final String text = match[1] ?? '';
    if (text.isEmpty) return false;
    parser.addNode(md.Element.text('mark', text));
    return true;
  }
}

class MathInlineBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String tex = element.textContent;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Math.tex(
          tex,
          mathStyle: MathStyle.text,
          textStyle: preferredStyle,
          onErrorFallback: (FlutterMathException e) => Text(
            '\$$tex\$',
            style: preferredStyle?.copyWith(
              color: Colors.redAccent,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

class MathBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String tex = element.textContent;
    // MathBlockSyntax is an inline parser extension, so flutter_markdown
    // places this node inside a paragraph. Declaring it as a block element
    // corrupts the builder's inline stack and triggers `_inlines.isEmpty` at
    // the end of parsing. Keep it inline and return a span-compatible widget.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Math.tex(
          tex,
          mathStyle: MathStyle.display,
          textStyle: preferredStyle,
          onErrorFallback: (FlutterMathException e) => Text(
            '\$\$$tex\$\$',
            style: preferredStyle?.copyWith(
              color: Colors.redAccent,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

class HighlightMarkBuilder extends MarkdownElementBuilder {
  HighlightMarkBuilder({required this.dark});
  final bool dark;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0x664D9F45).withValues(alpha: 0.35)
            : const Color(0xFFFFF3A3),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(element.textContent, style: preferredStyle),
    );
  }
}
