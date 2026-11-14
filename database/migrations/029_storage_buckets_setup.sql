-- =============================================================================
-- Migration 029: Storage Buckets & Policies Setup
--
-- Provisions Supabase Storage buckets for:
--  1. note-attachments      (Notes markdown image & file attachments)
--  2. community-attachments (Community post charts, screenshots, & media)
--  3. journal-attachments   (Trade journal screenshots & broker CSVs)
--  4. strategy-attachments  (Strategy diagrams & illustrations)
-- =============================================================================

-- Step 1: Provision buckets in storage.buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'note-attachments',
    'note-attachments',
    true,
    10485760, -- 10 MB
    ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf', 'text/markdown', 'text/plain']
  ),
  (
    'community-attachments',
    'community-attachments',
    true,
    15728640, -- 15 MB
    ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf']
  ),
  (
    'journal-attachments',
    'journal-attachments',
    false,
    15728640, -- 15 MB (strictly private to trade owner)
    ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'text/csv']
  ),
  (
    'strategy-attachments',
    'strategy-attachments',
    false,
    10485760, -- 10 MB
    ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf']
  ),
  (
    'chat-attachments',
    'chat-attachments',
    false,
    15728640, -- 15 MB (strictly private to active conversation members)
    ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf', 'audio/webm', 'audio/mp4', 'audio/mpeg', 'audio/wav', 'audio/ogg', 'application/octet-stream']
  )
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Step 2: Storage Object RLS Policies

-- A. Note Attachments
DROP POLICY IF EXISTS note_attachments_owner_all ON storage.objects;
CREATE POLICY note_attachments_owner_all ON storage.objects
FOR ALL
TO authenticated
USING (
  bucket_id = 'note-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'note-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS note_attachments_public_read ON storage.objects;
CREATE POLICY note_attachments_public_read ON storage.objects
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'note-attachments'
  AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR EXISTS (
      SELECT 1 FROM trader_notes n
      WHERE n.id::text = (storage.foldername(name))[2]
        AND n.is_public = true
    )
  )
);

-- B. Community Attachments
DROP POLICY IF EXISTS community_attachments_owner_all ON storage.objects;
CREATE POLICY community_attachments_owner_all ON storage.objects
FOR ALL
TO authenticated
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

DROP POLICY IF EXISTS community_attachments_objects_public_read ON storage.objects;
CREATE POLICY community_attachments_objects_public_read ON storage.objects
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'community-attachments'
  AND (storage.foldername(name))[1] <> 'chat'
  AND COALESCE((storage.foldername(name))[2], '') <> 'chat'
);

-- C. Journal Attachments (Owner Only - Zero Public Read)
DROP POLICY IF EXISTS journal_attachments_owner_all ON storage.objects;
CREATE POLICY journal_attachments_owner_all ON storage.objects
FOR ALL
TO authenticated
USING (
  bucket_id = 'journal-attachments'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
)
WITH CHECK (
  bucket_id = 'journal-attachments'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

-- D. Strategy Attachments (Private Bucket - Requires Matching Owner & Strategy)
DROP POLICY IF EXISTS strategy_attachments_owner_all ON storage.objects;
CREATE POLICY strategy_attachments_owner_all ON storage.objects
FOR ALL
TO authenticated
USING (
  bucket_id = 'strategy-attachments'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.strategies s
    WHERE s.id::text = (storage.foldername(name))[2]
      AND s.user_id = (SELECT auth.uid())
  )
)
WITH CHECK (
  bucket_id = 'strategy-attachments'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.strategies s
    WHERE s.id::text = (storage.foldername(name))[2]
      AND s.user_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS strategy_attachments_objects_public_read ON storage.objects;
CREATE POLICY strategy_attachments_objects_public_read ON storage.objects
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'strategy-attachments'
  AND EXISTS (
    SELECT 1 FROM public.strategies s
    WHERE s.id::text = (storage.foldername(name))[2]
      AND s.user_id::text = (storage.foldername(name))[1]
      AND (
        s.visibility = 'public'
        OR s.user_id = (SELECT auth.uid())
      )
      AND (
        EXISTS (
          SELECT 1 FROM public.strategy_attachments sa
          WHERE sa.storage_path = storage.objects.name
            AND sa.strategy_id = s.id
            AND sa.user_id = s.user_id
        )
        OR NOT EXISTS (
          SELECT 1 FROM public.strategy_attachments sa
          WHERE sa.storage_path = storage.objects.name
        )
      )
  )
);
