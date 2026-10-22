# Backend Feature Audit: Watchlists

**Component:** `lib/features/watchlists/`  
**Database Tables:** `public.watchlists`, `public.watchlist_items`  
**Files Evaluated:**  
- `lib/features/watchlists/data/watchlist_repository.dart`  
- `backend_handoff/05-Watchlist/tables.sql`  

---

## 1. Fatal PostgREST Schema Mismatch

- **Non-Existent Column Queries:**
  - Client queries: `ticker`, `category`, `is_favorite`, `price_alert_threshold`.
  - Database schema (`005-Watchlist/tables.sql`): `id`, `watchlist_id`, `symbol`, `added_at`.
  - Result: PostgREST returns HTTP 400: `column watchlist_items.ticker does not exist`. Live queries fail 100% of the time.
  - **Action:** Run migration to rename `symbol` to `ticker` and add `category`, `is_favorite`, and `price_alert_threshold` columns to `watchlist_items`.

---

## 2. Missing Live Price Feed Integration

- **Alert Threshold as Price:**
  - Table only stores alert targets, not current prices.
  - **Action:** Create a database view or Edge Function that joins `watchlist_items` with real-time market quote caches.
