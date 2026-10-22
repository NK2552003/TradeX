# Backend Feature Audit: Market Intelligence & Feeds

**Component:** `lib/features/market_data/`  
**Assets Inventory:** `assets/data/` (~22 MB static JSON)  
**Files Evaluated:**  
- `lib/features/market_data/data/asset_market_repository.dart`  
- `lib/features/calculators/services/market_data_service.dart`  

---

## 1. 0% Live Backend Connectivity

- **22 MB of Static Assets Bundled at Compile-Time:**
  - `stock_detail.json` (~10 MB)
  - `screeners.json` (~6.2 MB)
  - `quotes.json` (~4.2 MB)
  - `manifest.json`, `all_news.json`, `fundamentals.json`
  - The app never contacts an exchange API or WebSocket. All quotes and candlestick histories are frozen in time.
  - **Action:** Deploy Supabase Edge Function `functions/v1/market-quotes` proxying live exchange feeds (Polygon.io, AlphaVantage, or NSE/BSE brokers) with Redis caching.

---

## 2. Unproxied Yahoo Finance Web CORS Failure

- **Direct Client-Side Scraping (`market_data_service.dart:150-180`):**
  - Calls `query1.finance.yahoo.com` directly from Flutter Web.
  - Fails 100% on browsers due to missing CORS headers (`Access-Control-Allow-Origin`).
  - Triggers IP rate-limiting (HTTP 429).
  - **Action:** Proxy all market quote requests through backend Edge Functions.
