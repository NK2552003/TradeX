import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tradex/core/app-ui/motion/ai_typing_indicator.dart';

const typingCursorMarker = '\uE002';

class TypingCursorSyntax extends md.InlineSyntax {
  TypingCursorSyntax() : super(typingCursorMarker);
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty('typing_cursor'));
    return true;
  }
}

class TypingCursorBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) =>
      const AiTypingCursor();
}
