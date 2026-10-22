# Backend Feature Audit: Trade Journal

**Component:** `lib/features/journal/`  
**Database Tables:** `public.journal_entries`, `public.strategies`  
**Storage Bucket:** `journal-attachments`  
**Files Evaluated:**  
- `lib/features/journal/data/journal_repository.dart`  
- `database/migrations/001_core_schema.sql`  

---

## 1. Fatal Schema Mismatch Bug

- **`strategies(name)` vs `strategies(title)` (`journal_repository.dart:207, 450, 490, 536`):**
  - Client queries `.select('*, strategies(name)')`.
  - In `strategies`, the column is named `title`.
  - Throws `PGRST100: column strategies.name does not exist` on every read and write, failing 100% of live journal synchronizations!
  - **Action:** Update client repository to `.select('*, strategies(title)')`.

---

## 2. Storage Bucket Upload Rejection & URL Flaws

- **Upload Path Rejection (403):**
  - Repository uploads to `$entryId/$fileName`.
  - Storage policy requires `(storage.foldername(name))[1] = auth.uid()`.
  - **Action:** Prefix upload path with `client.auth.currentUser!.id`.
- **Public URL on Private Bucket:**
  - Invoking `.getPublicUrl()` on private bucket `journal-attachments` produces 403 Forbidden URLs.
  - **Action:** Use `.createSignedUrl(ref, 3600)`.
