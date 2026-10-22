# Frontend Feature Audit: Market Intelligence & Charts

**Component:** `lib/features/market_data/`  
**Target Files:**  
- `lib/features/market_data/presentation/market_root_screen.dart`  
- `lib/features/market_data/presentation/market_instrument_view.dart`  
- `lib/features/market_data/presentation/market_movers_panel.dart`  

---

## 1. Gesture Conflicts & Mobile Navigation

- **Candlestick Pan Gesture Hijacks System Back (`market_instrument_view.dart:250-310`):**
  - Unconstrained `HorizontalDragGestureRecognizer` across the entire chart captures Android and iOS edge back swipes.
  - Traps user on the detail chart view.
  - **Action:** Add 16px edge padding or require 2-finger pan gestures for mobile chart scrubbing.

---

## 2. Layout & Touch Target Flaws

- **Mover Ticker Chip Wrapping (`market_movers_panel.dart:80-140`):**
  - On screens < 360px wide, ticker pills wrap awkwardly and clip 24h percentage badges.
  - Touch targets measure 32x24px, violating WCAG 48x48px requirement.
  - **Action:** Increase chip touch area and apply `BoxConstraints(minHeight: 48)`.

---

## 3. Mandatory Regulatory Disclaimers

- **Missing Non-Advisory Notice (`market_root_screen.dart:1-50`):**
  - Displays "Strong Buy", "Bullish Breakout", and top gainers without disclaimers.
  - **Action:** Add a persistent banner: *"Market data delayed by 15 mins. TradeX is an analytics platform, not a SEBI/FINRA registered investment advisor."*
