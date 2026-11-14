-- =============================================================================
-- Migration 042: Chat Storage Policies & View Increment Fix
-- =============================================================================

-- 1. Storage RLS: Remove legacy permissive chat branch on community-attachments;
-- restrict community-attachments to owner-scoped non-chat objects only.
DROP POLICY IF EXISTS community_attachments_chat_authenticated_all ON storage.objects;

-- 2. Increment post views on community_posts (requiring visibility & authenticated deduplication)
CREATE OR REPLACE FUNCTION increment_post_views(p_post_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID;
  v_author_id UUID;
  v_is_public BOOLEAN;
  v_moderation_status TEXT;
  v_admin_hidden BOOLEAN;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL OR NOT tradex_private.account_active(v_user_id) THEN
    RETURN;
  END IF;

  SELECT author_id, is_public, moderation_status, COALESCE(admin_hidden, false)
    INTO v_author_id, v_is_public, v_moderation_status, v_admin_hidden
    FROM public.community_posts
   WHERE id = p_post_id;

  IF v_author_id IS NULL THEN
    RETURN;
  END IF;

  IF v_admin_hidden AND NOT public.is_user_admin() THEN
    RETURN;
  END IF;

  IF NOT (
    (v_moderation_status = 'approved' AND v_is_public = true)
    OR v_user_id = v_author_id
    OR public.is_user_admin()
  ) THEN
    RETURN;
  END IF;

  IF v_user_id <> v_author_id
     AND NOT public.is_user_admin()
     AND public.are_blocked(v_user_id, v_author_id) THEN
    RETURN;
  END IF;

  INSERT INTO public.post_views (post_id, user_id)
  VALUES (p_post_id, v_user_id)
  ON CONFLICT (post_id, user_id) DO NOTHING;

  IF FOUND THEN
    PERFORM set_config('tradex.trusted_counter_write', 'on', true);
    UPDATE public.community_posts
       SET views_count = COALESCE(views_count, 0) + 1
     WHERE id = p_post_id;
    PERFORM set_config('tradex.trusted_counter_write', 'off', true);
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_post_views(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.increment_post_views(UUID) TO authenticated, service_role;
