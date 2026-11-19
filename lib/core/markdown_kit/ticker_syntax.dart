import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:alphajournal/core/app-ui/models/app_models.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

/// Matches cashtag / ticker patterns like `$AAPL`, `$BTCUSDT`, `$^NSEI` in inline markdown.
///
/// Ensures single currency mentions (e.g. `$100`, `$50.25`) and LaTeX math
/// (e.g. `$$x+y$$`, `$x$`) are not mistakenly parsed as financial tickers.
class TickerInlineSyntax extends md.InlineSyntax {
  TickerInlineSyntax()
    : super(r'(?<![\$\w])\$([A-Za-z\^][A-Za-z0-9\.\-\_\^\=]{0,9})\b(?!\$)');

  static final RegExp regex = RegExp(
    r'(?<![\$\w])\$([A-Za-z\^][A-Za-z0-9\.\-\_\^\=]{0,9})\b(?!\$)',
  );

  @override
  RegExp get pattern => regex;

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final String symbol = (match[1] ?? '').trim();
    if (symbol.isEmpty) return false;
    final md.Element el = md.Element.text('ticker', symbol);
    el.attributes['symbol'] = symbol;
    parser.addNode(el);
    return true;
  }
}

/// Renders a clickable ticker badge pill with a candlestick chart icon.
class TickerElementBuilder extends MarkdownElementBuilder {
  TickerElementBuilder({this.onOpenRef});

  final void Function(AppLinkRef ref)? onOpenRef;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String rawSymbol =
        element.attributes['symbol'] ?? element.textContent;
    final String symbol = rawSymbol.toUpperCase();

    return Builder(
      builder: (BuildContext context) {
        final colors = context.uiColors;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              onOpenRef?.call(
                AppLinkRef(kind: AppLinkKind.ticker, id: symbol, title: symbol),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.28),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.candlestick_chart_outlined,
                    size: 11,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '\$$symbol',
                    style: TextStyle(
                      fontSize: (preferredStyle?.fontSize ?? 13) * 0.9,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                      fontFamily: preferredStyle?.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
