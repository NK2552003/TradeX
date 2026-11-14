-- 20261103020000_update_quota_and_likes_rls.sql
-- 1. Restrict community_likes reads to posts the caller can see, and replace FOR ALL with write-specific policies
ALTER TABLE public.community_posts
  ADD COLUMN IF NOT EXISTS admin_hidden boolean NOT NULL DEFAULT false;

DROP POLICY IF EXISTS "Public read for likes" ON public.community_likes;
DROP POLICY IF EXISTS "Users manage own likes" ON public.community_likes;
DROP POLICY IF EXISTS community_likes_manage ON public.community_likes;
DROP POLICY IF EXISTS community_likes_visible_post_read ON public.community_likes;
DROP POLICY IF EXISTS community_likes_insert ON public.community_likes;
DROP POLICY IF EXISTS community_likes_update ON public.community_likes;
DROP POLICY IF EXISTS community_likes_delete ON public.community_likes;

CREATE POLICY community_likes_visible_post_read
    ON public.community_likes FOR SELECT
    TO authenticated, anon
    USING (
      EXISTS (
        SELECT 1 FROM public.community_posts p
        WHERE p.id = community_likes.post_id
          AND NOT COALESCE(p.admin_hidden, false)
      )
    );

CREATE POLICY community_likes_insert
    ON public.community_likes FOR INSERT
    TO authenticated
    WITH CHECK (
      user_id = (SELECT auth.uid())
      AND EXISTS (
        SELECT 1 FROM public.community_posts p
        WHERE p.id = community_likes.post_id
          AND NOT COALESCE(p.admin_hidden, false)
      )
    );

CREATE POLICY community_likes_update
    ON public.community_likes FOR UPDATE
    TO authenticated
    USING (
      user_id = (SELECT auth.uid())
      AND EXISTS (
        SELECT 1 FROM public.community_posts p
        WHERE p.id = community_likes.post_id
          AND NOT COALESCE(p.admin_hidden, false)
      )
    )
    WITH CHECK (
      user_id = (SELECT auth.uid())
      AND EXISTS (
        SELECT 1 FROM public.community_posts p
        WHERE p.id = community_likes.post_id
          AND NOT COALESCE(p.admin_hidden, false)
      )
    );

CREATE POLICY community_likes_delete
    ON public.community_likes FOR DELETE
    TO authenticated
    USING (
      user_id = (SELECT auth.uid())
      AND EXISTS (
        SELECT 1 FROM public.community_posts p
        WHERE p.id = community_likes.post_id
          AND NOT COALESCE(p.admin_hidden, false)
      )
    );

-- 2. Update get_customer_quota_usage to fall back to profiles.subscription_tier
CREATE OR REPLACE FUNCTION public.get_customer_quota_usage(target_user_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE actor_id uuid := auth.uid();
DECLARE effective_user_id uuid := COALESCE(target_user_id, auth.uid());
DECLARE effective_tier text := 'free';
DECLARE published_limits jsonb;
DECLARE note_count integer;
DECLARE trade_count integer;
DECLARE playbook_count integer;
DECLARE ai_count integer;
BEGIN
  IF actor_id IS NULL OR effective_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF effective_user_id <> actor_id AND NOT is_user_admin() THEN
    RAISE EXCEPTION 'Quota access denied' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = effective_user_id) THEN
    RAISE EXCEPTION 'Account not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT s.tier INTO effective_tier FROM public.subscriptions s
    WHERE s.user_id = effective_user_id
      AND s.status IN ('active', 'trialing', 'canceled')
      AND (s.expires_at IS NULL OR s.expires_at > now())
    LIMIT 1;

  IF effective_tier IS NULL THEN
    SELECT subscription_tier INTO effective_tier FROM public.profiles WHERE id = effective_user_id;
  END IF;

  effective_tier := COALESCE(effective_tier, 'free');
  IF effective_tier = 'basic' THEN
    effective_tier := 'premium';
  ELSIF effective_tier = 'pro' THEN
    effective_tier := 'enterprise';
  END IF;

  SELECT plan->'limits' INTO published_limits
    FROM public.pricing_catalogues c,
         jsonb_array_elements(c.catalogue->'plans') plan
    WHERE c.id = 'default' AND c.published
      AND plan->>'tier' = effective_tier
    LIMIT 1;

  IF published_limits IS NULL THEN
    SELECT plan->'limits' INTO published_limits
      FROM public.pricing_catalogues c,
           jsonb_array_elements(c.catalogue->'plans') plan
      WHERE c.id = 'default' AND c.published
        AND plan->>'tier' = 'free'
      LIMIT 1;
  END IF;

  SELECT count(*) INTO note_count FROM public.trader_notes WHERE user_id = effective_user_id;
  SELECT count(*) INTO trade_count FROM public.journal_entries WHERE user_id = effective_user_id;
  SELECT count(*) INTO playbook_count FROM public.strategies
    WHERE user_id = effective_user_id AND status = 'live';
  SELECT count(*) INTO ai_count FROM public.ai_insight_requests
    WHERE user_id = effective_user_id
      AND requested_at >= date_trunc('month', now())
      AND requested_at < date_trunc('month', now()) + interval '1 month';

  RETURN jsonb_build_object(
    'user_id', effective_user_id,
    'tier', effective_tier,
    'limits', published_limits,
    'notes_used', note_count,
    'trades_used', trade_count,
    'live_playbooks_used', playbook_count,
    'ai_queries_used', ai_count,
    'window_started_at', date_trunc('month', now())
  );
END;
$$;
REVOKE ALL ON FUNCTION public.get_customer_quota_usage(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_customer_quota_usage(uuid) TO authenticated;
