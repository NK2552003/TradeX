# Design Brief: Market Overview and Community Market Wire

## Job to Be Done

Help traders scan the newest available market stories, trends, global benchmarks, and asset moves in seconds.

## Context

- Platform: Flutter across mobile, tablet, and desktop web.
- Audience: Mixed-experience traders who revisit market data frequently.
- Entry state: Time-sensitive and comparison-focused; stale or empty information must be obvious.

## Design Direction

- Feel: Compact, professional, data-honest.
- Density: Rich information inside visually quiet reusable surfaces.
- Hierarchy: Instrument name first, then price/change, with sparklines as supporting context.

## Content Hierarchy

1. Newest available market stories and live market trends.
2. Global index groups by region.
3. Commodities, currencies/crypto, and Treasury yields.
4. Source freshness and loading state.

Empty sections collapse completely. Loading quotes use skeletons rather than fabricated prices. “Today” appears only when the newest article is from the current local date.

## Constraints

- Use AlphaJournal components from `app_ui.dart` and `flutter_ui.dart`.
- Use context design tokens for spacing, sizing, colors, and typography.
- Keep layouts responsive at compact, medium, and expanded widths.
- Preserve accessible semantics and readable signed price changes.

## Design DNA

- Scanability over ornamental table chrome.
- Natural card heights over clipped or internally scrolling panels.
- Progressive disclosure and graceful absence over empty placeholder shells.
