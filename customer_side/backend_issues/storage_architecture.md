# Backend Architecture: Supabase Storage & Object Security Audit

**Target Audience:** Supabase Storage & Cloud Infrastructure Engineers  
**Scope:** Storage Buckets, Row Level Security on `storage.objects`, Key Path Conventions, Signed URLs, and Avatar Asset Provisioning.  
**Date:** 2026-10-21  

---

## 1. Executive Summary: 100% Upload Rejection Crisis

A critical structural conflict exists between client repository file upload logic and Supabase Storage RLS policies. This causes **100% of chart screenshots, trade attachments, and strategy diagrams to be rejected by Supabase Storage with HTTP 403 Forbidden**.

```
Client Upload Path:      <entity_id>/<file_name>
PostgreSQL Policy Check: (storage.foldername(name))[1] == auth.uid()
Result:                  403 FORBIDDEN (entity_id != auth.uid())
```

Furthermore, private storage buckets are accessed using public URL generators (`.getPublicUrl()`), rendering all uploaded images broken on the frontend, while a missing `avatars` bucket induces multi-megabyte base64 database bloat.

---

## 2. Technical Root Cause & Remediation

### 2.1. Object Key Path Segment Mismatch
- **Affected Buckets:** `note-attachments`, `journal-attachments`, `strategy-attachments`, `community-attachments`.
- **Database RLS Definition (`database/rls_policies.sql:480-545`):**
  ```sql
  CREATE POLICY note_attachments_owner_all ON storage.objects
  FOR ALL TO authenticated
  USING (
      bucket_id = 'note-attachments'
      AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
      bucket_id = 'note-attachments'
      AND (storage.foldername(name))[1] = auth.uid()::text
  );
  ```
- **The Breakdown:**
  1. `(storage.foldername(name))[1]` extracts the first folder component of the storage key.
  2. The SQL policy demands that this first segment match `auth.uid()::text`.
  3. Client repositories upload files as `$noteId/$fileName`, `$entryId/$fileName`, or `$strategyId/$fileName`.
  4. Because the first segment is the entity UUID (e.g. `c7a2b910-...`) and not the trader's user ID, PostgreSQL denies the insert.
- **Remediation:** Align both the client and server to the 3-tier convention:
  `storagePath = '$userId/$entityId/$fileName'`

---

### 2.2. Private Buckets Accessed via Public URLs
- **Locations:**
  - `journal_repository.dart:740`
  - `notes_repository.dart:780`
  - `strategies_repository.dart:957`
- **Defect:** Repositories invoke `.getPublicUrl(ref)` on buckets configured as `public = false`. Calling `.getPublicUrl()` on a private bucket generates an unsigned link that returns `403 Forbidden` when loaded in Flutter's `Image.network`.
- **Remediation:** Use `createSignedUrl(ref, 3600)` with 1-hour expiration for private assets.

---

### 2.3. Missing `avatars` Bucket & Base64 Database Injection
- **Defect:** `profile_settings_repository.dart:180-195` attempts to upload user profile pictures to bucket `'avatars'`. No migration created the `avatars` bucket. When the upload fails, the client encodes the photo as a 2MB raw base64 string and updates `profiles.avatar_url`.
- **Remediation:** Create the `avatars` bucket with public read permissions.

---

## 3. Master Storage Provisioning SQL Migration Script

Execute the following script in the Supabase SQL Editor to provision all storage buckets and configure compliant RLS policies:

```sql
-- 1. Create all application buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('avatars', 'avatars', true, 5242880, ARRAY['image/png', 'image/jpeg', 'image/webp']),
    ('community-attachments', 'community-attachments', true, 10485760, ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif']),
    ('note-attachments', 'note-attachments', false, 10485760, ARRAY['image/png', 'image/jpeg', 'image/webp', 'application/pdf']),
    ('journal-attachments', 'journal-attachments', false, 10485760, ARRAY['image/png', 'image/jpeg', 'image/webp', 'application/pdf']),
    ('strategy-attachments', 'strategy-attachments', false, 10485760, ARRAY['image/png', 'image/jpeg', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Avatars RLS: Public Read, Owner Write
CREATE POLICY avatars_public_read ON storage.objects
FOR SELECT TO authenticated, anon
USING (bucket_id = 'avatars');

CREATE POLICY avatars_owner_write ON storage.objects
FOR ALL TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

-- 3. Community Attachments RLS: Public Read, Owner Write
CREATE POLICY community_public_read ON storage.objects
FOR SELECT TO authenticated, anon
USING (bucket_id = 'community-attachments');

CREATE POLICY community_owner_write ON storage.objects
FOR ALL TO authenticated
USING (bucket_id = 'community-attachments' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'community-attachments' AND (storage.foldername(name))[1] = auth.uid()::text);

-- 4. Private Attachments (Notes, Journal, Strategies): Owner Only
CREATE POLICY note_attachments_owner_access ON storage.objects
FOR ALL TO authenticated
USING (bucket_id = 'note-attachments' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'note-attachments' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY journal_attachments_owner_access ON storage.objects
FOR ALL TO authenticated
USING (bucket_id = 'journal-attachments' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'journal-attachments' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY strategy_attachments_owner_access ON storage.objects
FOR ALL TO authenticated
USING (bucket_id = 'strategy-attachments' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'strategy-attachments' AND (storage.foldername(name))[1] = auth.uid()::text);
```
