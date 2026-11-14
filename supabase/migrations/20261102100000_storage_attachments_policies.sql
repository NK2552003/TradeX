-- =============================================================================
-- Migration: 20261102100000_storage_attachments_policies.sql
-- Purpose:
--   Configure permissive policies on storage.objects for community-attachments
--   and message/chat attachments so authenticated users can upload media,
--   photos, technical charts, documents, and voice notes without RLS errors.
-- =============================================================================

BEGIN;

-- Ensure public bucket exists for community post media only (never direct-message attachments)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'community-attachments',
    'community-attachments',
    true,
    15728640,
    ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf']
  ),
  (
    'chat-attachments',
    'chat-attachments',
    false,
    15728640,
    ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf', 'audio/webm', 'audio/mp4', 'audio/mpeg', 'audio/wav', 'audio/ogg', 'application/octet-stream']
  )
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Remove legacy cross-user chat policy if present
DROP POLICY IF EXISTS community_attachments_chat_authenticated_all ON storage.objects;

-- 1. Authenticated traders can upload only under their own user prefix (excluding chat paths)
DROP POLICY IF EXISTS "Allow authenticated uploads to community-attachments" ON storage.objects;
CREATE POLICY "Allow authenticated uploads to community-attachments"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'community-attachments'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND (storage.foldername(name))[1] <> 'chat'
  AND COALESCE((storage.foldername(name))[2], '') <> 'chat'
);

-- 2. Authenticated traders can update only their own non-chat community uploads
DROP POLICY IF EXISTS "Allow authenticated update own community-attachments" ON storage.objects;
CREATE POLICY "Allow authenticated update own community-attachments"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'community-attachments'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND (storage.foldername(name))[1] <> 'chat'
  AND COALESCE((storage.foldername(name))[2], '') <> 'chat'
)
WITH CHECK (
  bucket_id = 'community-attachments'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND (storage.foldername(name))[1] <> 'chat'
  AND COALESCE((storage.foldername(name))[2], '') <> 'chat'
);

-- 3. Authenticated traders can delete only their own non-chat community uploads
DROP POLICY IF EXISTS "Allow authenticated delete own community-attachments" ON storage.objects;
CREATE POLICY "Allow authenticated delete own community-attachments"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'community-attachments'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND (storage.foldername(name))[1] <> 'chat'
  AND COALESCE((storage.foldername(name))[2], '') <> 'chat'
);

-- 4. Public read access for non-chat community media in community-attachments
DROP POLICY IF EXISTS "Allow public read community-attachments" ON storage.objects;
CREATE POLICY "Allow public read community-attachments"
ON storage.objects FOR SELECT TO public
USING (
  bucket_id = 'community-attachments'
  AND (storage.foldername(name))[1] <> 'chat'
  AND COALESCE((storage.foldername(name))[2], '') <> 'chat'
);

COMMIT;
