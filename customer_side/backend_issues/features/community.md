# Backend Feature Audit: Community & Social Trading

**Component:** `lib/features/community/`  
**Database Tables:** `public.community_posts`, `public.community_comments`, `public.blocks`  
**Files Evaluated:**  
- `lib/features/community/data/community_repository.dart`  
- `database/migrations/001_core_schema.sql`  
- `database/rls_policies.sql` (Lines 701–732)  

---

## 1. RLS & Security Vulnerabilities

### 1.1. Missing Block Filter on Posts & Comments
- **Location:** `database/rls_policies.sql:701-732`.
- **Defect:** `community_posts_read` policy allows `SELECT USING (true)`. It does not check the `blocks` table. Blocked users can query and read posts and comments of the user who blocked them.
- **Action:** Add `NOT EXISTS (SELECT 1 FROM blocks WHERE (blocker_id = author_id AND blocked_id = auth.uid()) OR (blocker_id = auth.uid() AND blocked_id = author_id))`.

### 1.2. Client-Side Post Deletion IDOR
- **Location:** `community_repository.dart:1224`.
- **Defect:** Executes `.delete().eq('id', postId)` without ensuring server-side RLS prevents deleting posts owned by other users.
- **Action:** Verify `community_posts_delete` policy has `USING (auth.uid() = author_id)`.

---

## 2. PostgREST Column Mismatches

- **Non-Existent Profile Columns:**
  - Client query selects `profiles(username, win_rate, verified)`.
  - In `profiles`, columns are `display_name`, `handle`, and `status`. There is no `username` or `win_rate`.
  - **Action:** Update client select query to match real `profiles` schema.
