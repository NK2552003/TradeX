-- =============================================================================
-- Migration: 20261102100000_storage_attachments_policies.sql
-- Purpose:
--   Configure permissive policies on storage.objects for community-attachments
--   and message/chat attachments so authenticated users can upload media,
--   photos, technical charts, documents, and voice notes without RLS errors.
-- =============================================================================

BEGIN;

-- Ensure bucket exists and is public for fast CDN media serving
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'community-attachments',
  'community-attachments',
  true,
  15728640,
  ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf', 'audio/webm', 'audio/mp4', 'audio/mpeg', 'audio/wav', 'audio/ogg', 'application/octet-stream']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 15728640,
  allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf', 'audio/webm', 'audio/mp4', 'audio/mpeg', 'audio/wav', 'audio/ogg', 'application/octet-stream'];

-- 1. Permissive policy: Authenticated traders can upload to community-attachments
DROP POLICY IF EXISTS "Allow authenticated uploads to community-attachments" ON storage.objects;
CREATE POLICY "Allow authenticated uploads to community-attachments"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'community-attachments'
  AND (auth.uid() IS NOT NULL)
);

-- 2. Permissive policy: Authenticated traders can update/upsert their own uploads
DROP POLICY IF EXISTS "Allow authenticated update own community-attachments" ON storage.objects;
CREATE POLICY "Allow authenticated update own community-attachments"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'community-attachments'
  AND (owner = auth.uid() OR split_part(name, '/', 1) = auth.uid()::text)
);

-- 3. Permissive policy: Authenticated traders can delete their own uploads
DROP POLICY IF EXISTS "Allow authenticated delete own community-attachments" ON storage.objects;
CREATE POLICY "Allow authenticated delete own community-attachments"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'community-attachments'
  AND (owner = auth.uid() OR split_part(name, '/', 1) = auth.uid()::text)
);

-- 4. Permissive policy: Public read access for community-attachments
DROP POLICY IF EXISTS "Allow public read community-attachments" ON storage.objects;
CREATE POLICY "Allow public read community-attachments"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'community-attachments');

COMMIT;
