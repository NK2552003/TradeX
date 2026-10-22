# Frontend Feature Audit: Watchlists

**Component:** `lib/features/watchlists/`  
**Target Files:**  
- `lib/features/watchlists/presentation/watchlists_page.dart`  
- `lib/features/watchlists/data/watchlist_repository.dart`  

---

## 1. Dead Buttons & Broken Interactions

| UI Control | File & Line | Failure Mechanism | Priority |
|---|---|---|:---:|
| "Add Symbol" Button | `watchlists_page.dart:61-74` | Emits dummy `UiToast('Symbol search and watchlist picker opened.')`; no dialog opens! | Critical |
| Watchlist Ticker Row Tap | `watchlists_page.dart:83-85` | Sets `_selectedTicker = ticker`, but `_selectedTicker` is never read in widget tree; no chart opens! | High |

---

## 2. Visual & Pricing Distortion

- **Price Alert Threshold Rendered as Live Price (`watchlist_repository.dart:88-95`):**
  - Displays user alert threshold (e.g. $250.00) or fallback $100.00 as current stock price with 0.0% change.
  - **Action:** Connect UI to real price stream via `MarketDataService`.
