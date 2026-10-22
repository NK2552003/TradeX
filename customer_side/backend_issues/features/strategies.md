# Backend Feature Audit: Strategies & Playbooks

**Component:** `lib/features/strategies/`  
**Database Tables:** `public.strategies`, `public.strategy_versions`, `public.note_link_edges`  
**Storage Bucket:** `strategy-attachments`  
**Files Evaluated:**  
- `lib/features/strategies/data/strategies_repository.dart`  
- `database/rls_policies.sql` (Lines 98–108 and 513–519)  
- `database/migrations/011_note_link_graph.sql`  

---

## 1. Missing RLS Policy on Public Playbooks

- **`strategy_versions_public_read` Missing:**
  - `strategy_versions` only has policy `strategy_versions_own_all`.
  - External visitors viewing a shared public playbook cannot view version changelogs.
  - **Action:** Add `strategy_versions_public_read` policy checking `s.visibility = 'public'`.

---

## 2. Storage Upload Rejection & Trigger Races

- **Storage Path 403:**
  - Upload path `$strategyId/$uuid.$ext` fails `(storage.foldername(name))[1] = auth.uid()`.
  - **Action:** Prefix path with `client.auth.currentUser!.id`.
- **Mirror Array Overwrites:**
  - `StrategiesRepositoryImpl.linkNote` manually overwrites `linked_note_ids` array, racing against triggers in `011_note_link_graph.sql`.
  - **Action:** Rely strictly on PostgreSQL trigger updates.
