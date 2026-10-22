# Backend Feature Audit: Linking & Universal Graph

**Component:** `lib/features/linking/`  
**Database Tables:** `public.entity_ticker_links`, `public.universal_link_edges`  
**Files Evaluated:**  
- `lib/features/linking/entity_ticker_links_repository.dart`  
- `database/schema.sql` (Lines 2593–2620)  

---

## 1. Fatal PostgreSQL Type Syntax Error `22P02`

- **Synthetic String ID Upsert Rejection:**
  - `EntityTickerLinksRepository:206-235` passes ID `etl_0001_${timestamp}` into `entity_ticker_links.id` (`UUID PRIMARY KEY`).
  - PostgreSQL rejects with `ERROR: 22P02: invalid input syntax for type uuid`.
  - Zero cashtags or ticker links are ever saved to the database.
  - **Action:** Omit client `id` or generate standard `Uuid().v4()`.

---

## 2. Foreign Key Violation via Demo User Fallback

- **Invalid User ID Insertion:**
  - `entity_ticker_links_repository.dart:130` falls back to `userId: 'demo_user'`.
  - Violates foreign key constraint referencing `profiles(id)`.
  - **Action:** Require valid authenticated user session; abort sync if unauthenticated.
