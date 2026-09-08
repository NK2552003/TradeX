import sys

with open('lib/core/widgets/app_scaffold.dart', 'r') as f:
    content = f.read()

# 1. Remove imports
content = content.replace("import 'package:tradex/features/markets/ui/markets_screen.dart';", "")
content = content.replace("import 'package:tradex/features/markets/ui/news_screen.dart';", "")

# 2. Remove watchlists, markets, news blocks
to_remove = """    'watchlists' => MarketsScreen(
      key: const ValueKey('watchlists'),
      watchlist: true,
      onOpenRef: _openLinkRef,
    ),
    'markets' => MarketsScreen(
      key: const ValueKey('markets'),
      openRequest: _linkRequest,
      onOpenRef: _openLinkRef,
    ),
    'news' => NewsScreen(
      onOpenRef: _openLinkRef,
      onOpenSymbol: (symbol) => _openLinkRef(
        AppLinkRef(kind: AppLinkKind.ticker, id: symbol, title: symbol),
      ),
    ),"""

if to_remove in content:
    content = content.replace(to_remove, "")
else:
    print("Could not find blocks")

# 3. Fix researchPanelBuilder
to_remove2 = """            researchPanelBuilder: _effectiveRole != UserRole.customer
                ? null
                : (context, close, overlay) => ResearchRail(
                    onClose: close,
                    onOpenSymbol: (symbol) {
                      if (overlay) close();
                      _openLinkRef(
                        AppLinkRef(
                          kind: AppLinkKind.ticker,
                          id: symbol,
                          title: symbol,
                        ),
                      );
                    },
                    onOpenRef: (ref) {
                      if (overlay) close();
                      _openLinkRef(ref);
                    },
                  ),"""

if to_remove2 in content:
    content = content.replace(to_remove2, "            researchPanelBuilder: null,")
else:
    print("Could not find research panel builder")

with open('lib/core/widgets/app_scaffold.dart', 'w') as f:
    f.write(content)
