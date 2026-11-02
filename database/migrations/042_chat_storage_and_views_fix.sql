-- =============================================================================
-- Migration 042: Chat Storage Policies & View Increment Fix
-- =============================================================================

-- 1. Storage RLS: Ensure authenticated users can upload chat attachments
-- Supports both <user_id>/chat/<thread_id>/<file> and chat/<thread_id>/<file>
DROP POLICY IF EXISTS community_attachments_chat_authenticated_all ON storage.objects;
CREATE POLICY community_attachments_chat_authenticated_all ON storage.objects
FOR ALL
TO authenticated
USING (
  bucket_id = 'community-attachments'
  AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR (storage.foldername(name))[1] = 'chat'
  )
)
WITH CHECK (
  bucket_id = 'community-attachments'
  AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR (storage.foldername(name))[1] = 'chat'
  )
);

-- 2. Increment post views on community_posts (instead of legacy posts relation)
CREATE OR REPLACE FUNCTION increment_post_views(p_post_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NOT NULL THEN
    INSERT INTO post_views (post_id, user_id)
    VALUES (p_post_id, v_user_id)
    ON CONFLICT (post_id, user_id) DO NOTHING;

    IF FOUND THEN
      UPDATE community_posts SET views_count = views_count + 1 WHERE id = p_post_id;
    END IF;
  ELSE
    UPDATE community_posts SET views_count = views_count + 1 WHERE id = p_post_id;
  END IF;
END;
$$;
