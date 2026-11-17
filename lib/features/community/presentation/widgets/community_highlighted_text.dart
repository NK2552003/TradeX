import 'package:tradex/core/markdown_kit/markdown_preview.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Renders post body text with highlighted and interactive `$TICKER` and `#tag` spans.
class CommunityHighlightedText extends StatelessWidget {
  const CommunityHighlightedText({
    super.key,
    required this.text,
    this.style,
    this.onTagTap,
    this.selectable = false,
  });

  final String text;
  final TextStyle? style;
  final ValueChanged<String>? onTagTap;
  final bool selectable;

  static final RegExp _tagRegex = RegExp(
    r'(tradex://[^\s\)]+|https?://[^\s\)]+|\$[A-Za-z\^][A-Za-z0-9_\.\-]{0,9}\b|#[A-Za-z0-9_]+|@[A-Za-z0-9_]+)',
  );
  static RegExp get tagRegex => _tagRegex;

  @override
  Widget build(BuildContext context) {
    if (RegExp(
      r'(^|\n)\s*(#{1,6} |[-*] |\d+\. |>|```)|\*[^*]+\*|`[^`]+`|\[[^\]]+\]\(',
    ).hasMatch(text)) {
      return RichMarkdownPreview(
        data: text,
        selectable: selectable,
        maxCollapsedChars: 600,
        onOpenRef: (ref) => onTagTap?.call(
          ref.kind == AppLinkKind.ticker ? '\$${ref.id}' : ref.id,
        ),
        onTapLink: (label, href, title) {
          if (href != null &&
              (href.startsWith('https://') ||
                  href.startsWith('http://') ||
                  href.startsWith('tradex://'))) {
            onTagTap?.call(href);
          }
        },
      );
    }
    final UiTheme theme = context.ui;
    final TextStyle effectiveStyle =
        (style ?? context.uiText.body.copyWith(height: 1.45)).copyWith(
          color: style?.color ?? theme.colors.foreground,
        );

    final List<TextSpan> spans = <TextSpan>[];
    int lastIndex = 0;

    for (final Match match in _tagRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: effectiveStyle,
          ),
        );
      }
      final String tag = match.group(0)!;
      spans.add(
        TextSpan(
          text: tag,
          style: effectiveStyle.copyWith(
            color: theme.colors.primary,
            fontWeight: FontWeight.w600,
          ),
          recognizer: onTagTap == null
              ? null
              : (TapGestureRecognizer()..onTap = () => onTagTap!(tag)),
        ),
      );
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(text: text.substring(lastIndex), style: effectiveStyle),
      );
    }

    final TextSpan textSpan = TextSpan(style: effectiveStyle, children: spans);

    if (selectable) {
      return SelectableText.rich(textSpan);
    }
    return Text.rich(textSpan);
  }
}
