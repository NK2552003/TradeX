# Backend Architecture: Database Schema & Migration Fixes

**Target Audience:** Supabase Database Engineers / Backend Developers  
**Scope:** PostgreSQL Schema Mismatches, Foreign Key Constraints, Column Renames, and UUID Type Collisions  
**Date:** 2026-10-21  

---

## 1. Executive Summary & Schema Disconnect

Multiple PostgreSQL column name mismatches and type syntax errors exist between the database migrations and client Dart repositories. These discrepancies cause **PostgREST HTTP 400 errors (`PGRST100`, `PGRST104`, `22P02`) that crash live database synchronization and force the app into offline mock fallbacks**.

---

## 2. In-Depth Schema Collision Breakdown

### 2.1. Journal `strategies(name)` vs `strategies(title)`
- **Location:** `lib/features/journal/data/journal_repository.dart` (Lines 207, 450, 490, 536).
- **Client Code:**
  ```dart
  .select('*, strategies(name)')
  ```
- **Database Schema (`database/migrations/001_core_schema.sql`):**
  ```sql
  CREATE TABLE IF NOT EXISTS strategies (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES profiles(id),
      title VARCHAR(255) NOT NULL, -- Column is TITLE, not NAME!
      ...
  );
  ```
- **Error:** When PostgREST processes the foreign table selection, it looks for column `name` on `strategies`. Because the column is `title`, PostgREST aborts with `column strategies.name does not exist` (code `PGRST100`).
- **Remediation:** Either create an alias view or update the client query to `.select('*, strategies(title)')`.

---

### 2.2. Watchlist Schema Desynchronization
- **Location:** `lib/features/watchlists/data/watchlist_repository.dart` (Lines 76–88).
- **Client Query:**
  ```dart
  .from('watchlist_items')
  .select('id, ticker, category, is_favorite, price_alert_threshold, watchlists!inner(user_id, name)')
  ```
- **Database Schema (`backend_handoff/05-Watchlist/tables.sql`):**
  ```sql
  CREATE TABLE IF NOT EXISTS watchlist_items (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      watchlist_id UUID NOT NULL REFERENCES watchlists(id) ON DELETE CASCADE,
      symbol VARCHAR(20) NOT NULL,
      added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE(watchlist_id, symbol)
  );
  ```
- **Error:** The SQL table uses `symbol`. The client queries `ticker`, `category`, `is_favorite`, and `price_alert_threshold`. None of these 4 columns exist in the database!
- **Remediation SQL Migration:**
  ```sql
  ALTER TABLE public.watchlist_items 
      RENAME COLUMN symbol TO ticker;

  ALTER TABLE public.watchlist_items 
      ADD COLUMN IF NOT EXISTS category VARCHAR(64) DEFAULT 'General',
      ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS price_alert_threshold NUMERIC;
  ```

---

### 2.3. Synthetic String IDs Crashing UUID Columns (Error `22P02`)
- **Affected Repositories:**
  - `entity_ticker_links_repository.dart:206`: generates `'etl_0001_${timestamp}'`.
  - `ai_assistant_repository.dart:398`: generates `'note_ai_${uid}'`.
  - `workspace_post_service.dart:190`: generates `'post-${timestamp}'`.
- **Database Schema:** `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`.
- **Error:** When PostgREST attempts to execute the upsert:
  ```
  ERROR: 22P02: invalid input syntax for type uuid: "etl_0001_1729503810291"
  ```
- **Remediation:** Remove client-side string prefixes. Ensure all client entities generate valid `Uuid().v4()` strings or omit the `id` field from insert payloads to let PostgreSQL assign standard UUIDs.

---

### 2.4. Unused `calculator_history` Table
- **Location:** `backend_handoff/06-Calculator_History/tables.sql`.
- **Issue:** The table was created in SQL handoff:
  ```sql
  CREATE TABLE IF NOT EXISTS calculator_history (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
      calculator_type VARCHAR(64) NOT NULL,
      inputs JSONB NOT NULL,
      outputs JSONB NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
  ```
  However, it has **zero occurrences** across the entire Flutter application.
- **Remediation:** Expose standard PostgREST endpoints and grant authenticated select/insert RLS policies so clients can persist calculation history.
