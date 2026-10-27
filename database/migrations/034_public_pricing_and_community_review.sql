BEGIN;

-- The existing editorial catalogue is writable only by authenticated admins.
DROP POLICY IF EXISTS pricing_catalogues_admin_write ON pricing_catalogues;
CREATE POLICY pricing_catalogues_admin_write ON pricing_catalogues
  FOR ALL TO authenticated USING (is_user_admin()) WITH CHECK (is_user_admin());
GRANT INSERT, UPDATE, DELETE ON pricing_catalogues TO authenticated;

-- A client must never grant itself a paid subscription.
DROP POLICY IF EXISTS subscriptions_own_write ON subscriptions;
DROP POLICY IF EXISTS subscriptions_admin_write ON subscriptions;
CREATE POLICY subscriptions_admin_write ON subscriptions
  FOR ALL TO authenticated USING (is_user_admin()) WITH CHECK (is_user_admin());

CREATE OR REPLACE FUNCTION protect_profile_subscription_role()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' AND NOT is_user_admin() THEN
    NEW.role := OLD.role;
    NEW.subscription_tier := OLD.subscription_tier;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS protect_profile_subscription_role_trigger ON profiles;
CREATE TRIGGER protect_profile_subscription_role_trigger
  BEFORE UPDATE ON profiles FOR EACH ROW
  EXECUTE FUNCTION protect_profile_subscription_role();

-- Enforce the same published limits on direct API writes, not just in Flutter.
CREATE OR REPLACE FUNCTION enforce_published_customer_quota()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
DECLARE active_tier TEXT := 'free';
DECLARE limit_key TEXT;
DECLARE quota_limit INTEGER;
DECLARE current_count INTEGER;
BEGIN
  IF TG_TABLE_NAME = 'strategies' THEN
    IF NEW.status <> 'live' OR
       (TG_OP = 'UPDATE' AND OLD.status = 'live') THEN RETURN NEW; END IF;
    limit_key := 'live_playbooks';
  ELSIF TG_TABLE_NAME = 'trader_notes' THEN
    limit_key := 'notes';
  ELSIF TG_TABLE_NAME = 'journal_entries' THEN
    limit_key := 'trades';
  ELSE
    limit_key := 'ai_queries_per_month';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(NEW.user_id::text), hashtext(limit_key));
  SELECT s.tier INTO active_tier FROM subscriptions s
    WHERE s.user_id = NEW.user_id
      AND s.status IN ('active', 'trialing', 'canceled')
      AND (s.expires_at IS NULL OR s.expires_at > now())
    LIMIT 1;
  active_tier := COALESCE(active_tier, 'free');
  SELECT (plan->'limits'->>limit_key)::integer INTO quota_limit
    FROM pricing_catalogues c,
         jsonb_array_elements(c.catalogue->'plans') plan
    WHERE c.id = 'default' AND c.published
      AND plan->>'tier' = active_tier
    LIMIT 1;
  IF quota_limit IS NULL THEN
    RAISE EXCEPTION 'Published subscription limits are unavailable';
  END IF;

  IF TG_TABLE_NAME = 'trader_notes' THEN
    SELECT count(*) INTO current_count FROM trader_notes WHERE user_id = NEW.user_id;
  ELSIF TG_TABLE_NAME = 'journal_entries' THEN
    SELECT count(*) INTO current_count FROM journal_entries WHERE user_id = NEW.user_id;
  ELSIF TG_TABLE_NAME = 'strategies' THEN
    SELECT count(*) INTO current_count FROM strategies
      WHERE user_id = NEW.user_id AND status = 'live';
  ELSE
    SELECT count(*) INTO current_count FROM ai_insight_requests
      WHERE user_id = NEW.user_id AND requested_at >= date_trunc('month', now())
        AND requested_at < date_trunc('month', now()) + interval '1 month';
  END IF;
  IF current_count >= quota_limit THEN
    RAISE EXCEPTION 'Subscription % quota reached (% of %)', limit_key, current_count, quota_limit
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS enforce_note_subscription_quota ON trader_notes;
CREATE TRIGGER enforce_note_subscription_quota BEFORE INSERT ON trader_notes
  FOR EACH ROW EXECUTE FUNCTION enforce_published_customer_quota();
DROP TRIGGER IF EXISTS enforce_trade_subscription_quota ON journal_entries;
CREATE TRIGGER enforce_trade_subscription_quota BEFORE INSERT ON journal_entries
  FOR EACH ROW EXECUTE FUNCTION enforce_published_customer_quota();
DROP TRIGGER IF EXISTS enforce_strategy_subscription_quota ON strategies;
CREATE TRIGGER enforce_strategy_subscription_quota BEFORE INSERT OR UPDATE OF status ON strategies
  FOR EACH ROW EXECUTE FUNCTION enforce_published_customer_quota();
DROP TRIGGER IF EXISTS enforce_ai_subscription_quota ON ai_insight_requests;
CREATE TRIGGER enforce_ai_subscription_quota BEFORE INSERT ON ai_insight_requests
  FOR EACH ROW EXECUTE FUNCTION enforce_published_customer_quota();

ALTER TABLE community_posts
  ADD COLUMN IF NOT EXISTS moderation_status TEXT NOT NULL DEFAULT 'pending';
ALTER TABLE community_posts
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE community_posts
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES profiles(id);
ALTER TABLE community_posts
  ADD COLUMN IF NOT EXISTS moderation_note TEXT;
ALTER TABLE community_posts
  DROP CONSTRAINT IF EXISTS community_posts_moderation_status_check;
ALTER TABLE community_posts
  ADD CONSTRAINT community_posts_moderation_status_check
  CHECK (moderation_status IN ('pending', 'approved', 'rejected'));

-- Preserve already public legacy posts; private drafts require review.
UPDATE community_posts SET moderation_status = 'approved'
WHERE is_public = true AND visibility = 'public'
  AND moderation_status = 'pending' AND reviewed_at IS NULL;

CREATE OR REPLACE FUNCTION enforce_community_post_review()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF is_user_admin() THEN
    IF NEW.moderation_status IN ('approved', 'rejected')
       AND (TG_OP = 'INSERT' OR OLD.moderation_status IS DISTINCT FROM NEW.moderation_status) THEN
      NEW.reviewed_at := now();
      NEW.reviewed_by := auth.uid();
    END IF;
    RETURN NEW;
  END IF;
  NEW.is_pinned := false;
  NEW.is_featured := false;
  IF TG_OP = 'INSERT' OR NEW.moderation_status IS DISTINCT FROM OLD.moderation_status
      OR NEW.body IS DISTINCT FROM OLD.body
      OR NEW.title IS DISTINCT FROM OLD.title
      OR NEW.tickers IS DISTINCT FROM OLD.tickers
      OR NEW.tags IS DISTINCT FROM OLD.tags
      OR NEW.is_public IS DISTINCT FROM OLD.is_public
      OR NEW.visibility IS DISTINCT FROM OLD.visibility THEN
    NEW.moderation_status := 'pending';
    NEW.reviewed_at := NULL;
    NEW.reviewed_by := NULL;
    NEW.moderation_note := NULL;
  ELSE
    NEW.moderation_status := OLD.moderation_status;
    NEW.reviewed_at := OLD.reviewed_at;
    NEW.reviewed_by := OLD.reviewed_by;
    NEW.moderation_note := OLD.moderation_note;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS enforce_community_post_review_trigger ON community_posts;
CREATE TRIGGER enforce_community_post_review_trigger
  BEFORE INSERT OR UPDATE ON community_posts
  FOR EACH ROW EXECUTE FUNCTION enforce_community_post_review();

DROP POLICY IF EXISTS "Public read for community posts" ON community_posts;
DROP POLICY IF EXISTS "Authors manage own posts" ON community_posts;
DROP POLICY IF EXISTS community_posts_read ON community_posts;
DROP POLICY IF EXISTS community_posts_manage ON community_posts;
CREATE POLICY community_posts_reviewed_read ON community_posts FOR SELECT
  TO anon, authenticated USING (
    (moderation_status = 'approved' AND is_public = true)
    OR (auth.uid() = author_id) OR is_user_admin()
  );
CREATE POLICY community_posts_author_insert ON community_posts FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = author_id);
CREATE POLICY community_posts_author_update ON community_posts FOR UPDATE
  TO authenticated USING (auth.uid() = author_id OR is_user_admin())
  WITH CHECK (auth.uid() = author_id OR is_user_admin());
CREATE POLICY community_posts_author_delete ON community_posts FOR DELETE
  TO authenticated USING (auth.uid() = author_id OR is_user_admin());
CREATE INDEX IF NOT EXISTS idx_community_posts_review_queue
  ON community_posts (created_at DESC) WHERE moderation_status = 'pending';

-- Editing an attachment or trade setup sends an approved post back to review.
CREATE OR REPLACE FUNCTION reopen_community_post_review()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
DECLARE target_post UUID;
BEGIN
  IF is_user_admin() THEN RETURN COALESCE(NEW, OLD); END IF;
  target_post := CASE WHEN TG_OP = 'DELETE' THEN OLD.post_id ELSE NEW.post_id END;
  UPDATE community_posts SET moderation_status = 'pending' WHERE id = target_post;
  RETURN COALESCE(NEW, OLD);
END;
$$;
DROP TRIGGER IF EXISTS review_community_attachments ON community_post_attachments;
CREATE TRIGGER review_community_attachments AFTER INSERT OR UPDATE OR DELETE
  ON community_post_attachments FOR EACH ROW EXECUTE FUNCTION reopen_community_post_review();
DROP TRIGGER IF EXISTS review_community_setups ON community_post_trade_setups;
CREATE TRIGGER review_community_setups AFTER INSERT OR UPDATE OR DELETE
  ON community_post_trade_setups FOR EACH ROW EXECUTE FUNCTION reopen_community_post_review();

ALTER TABLE community_comments
  ADD COLUMN IF NOT EXISTS moderation_status TEXT NOT NULL DEFAULT 'pending';
ALTER TABLE community_comments
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE community_comments
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES profiles(id);
ALTER TABLE community_comments
  ADD COLUMN IF NOT EXISTS moderation_note TEXT;
ALTER TABLE community_comments
  DROP CONSTRAINT IF EXISTS community_comments_moderation_status_check;
ALTER TABLE community_comments
  ADD CONSTRAINT community_comments_moderation_status_check
  CHECK (moderation_status IN ('pending', 'approved', 'rejected'));
UPDATE community_comments SET moderation_status = 'approved'
  WHERE moderation_status = 'pending' AND reviewed_at IS NULL;

CREATE OR REPLACE FUNCTION enforce_community_comment_review()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF is_user_admin() THEN
    IF NEW.moderation_status IN ('approved', 'rejected')
      AND (TG_OP = 'INSERT' OR OLD.moderation_status IS DISTINCT FROM NEW.moderation_status) THEN
      NEW.reviewed_at := now();
      NEW.reviewed_by := auth.uid();
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' OR NEW.body IS DISTINCT FROM OLD.body THEN
    NEW.moderation_status := 'pending';
    NEW.reviewed_at := NULL;
    NEW.reviewed_by := NULL;
    NEW.moderation_note := NULL;
  ELSE
    NEW.moderation_status := OLD.moderation_status;
    NEW.reviewed_at := OLD.reviewed_at;
    NEW.reviewed_by := OLD.reviewed_by;
    NEW.moderation_note := OLD.moderation_note;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS enforce_community_comment_review_trigger ON community_comments;
CREATE TRIGGER enforce_community_comment_review_trigger
  BEFORE INSERT OR UPDATE ON community_comments
  FOR EACH ROW EXECUTE FUNCTION enforce_community_comment_review();
DROP POLICY IF EXISTS "Public read for comments" ON community_comments;
DROP POLICY IF EXISTS community_comments_read ON community_comments;
CREATE POLICY community_comments_reviewed_read ON community_comments
  FOR SELECT TO anon, authenticated USING (
    ((moderation_status = 'approved' AND EXISTS (
      SELECT 1 FROM community_posts p WHERE p.id = post_id
        AND p.moderation_status = 'approved' AND p.is_public = true
    )) OR author_id = auth.uid() OR is_user_admin())
  );
DROP POLICY IF EXISTS "Authors manage own comments" ON community_comments;
DROP POLICY IF EXISTS "Authors delete own comments" ON community_comments;
DROP POLICY IF EXISTS community_comments_manage ON community_comments;
CREATE POLICY community_comments_review_update ON community_comments
  FOR UPDATE TO authenticated USING (author_id = auth.uid() OR is_user_admin())
  WITH CHECK (author_id = auth.uid() OR is_user_admin());
CREATE POLICY community_comments_review_delete ON community_comments
  FOR DELETE TO authenticated USING (author_id = auth.uid() OR is_user_admin());
CREATE INDEX IF NOT EXISTS idx_community_comments_review_queue
  ON community_comments (created_at DESC) WHERE moderation_status = 'pending';

-- Public counters include approved comments only.
CREATE OR REPLACE FUNCTION update_community_post_comments()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.moderation_status = 'approved' THEN
    UPDATE community_posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' AND OLD.moderation_status = 'approved' THEN
    UPDATE community_posts SET comments_count = GREATEST(0, comments_count - 1)
      WHERE id = OLD.post_id;
  ELSIF TG_OP = 'UPDATE' AND NEW.moderation_status IS DISTINCT FROM OLD.moderation_status THEN
    UPDATE community_posts SET comments_count = GREATEST(0, comments_count +
      CASE WHEN NEW.moderation_status = 'approved' THEN 1 ELSE -1 END)
      WHERE id = NEW.post_id;
  END IF;
  RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS trigger_community_post_comments ON community_comments;
CREATE TRIGGER trigger_community_post_comments
  AFTER INSERT OR UPDATE OR DELETE ON community_comments
  FOR EACH ROW EXECUTE FUNCTION update_community_post_comments();
UPDATE community_posts p SET comments_count = (
  SELECT count(*) FROM community_comments c
  WHERE c.post_id = p.id AND c.moderation_status = 'approved'
);

-- Related rows cannot reveal pending post content to the public.
DROP POLICY IF EXISTS "Public read for setups and attachments" ON community_post_trade_setups;
DROP POLICY IF EXISTS community_setups_read ON community_post_trade_setups;
CREATE POLICY community_setups_reviewed_read ON community_post_trade_setups
  FOR SELECT TO anon, authenticated USING (EXISTS (
    SELECT 1 FROM community_posts p WHERE p.id = post_id
      AND (p.moderation_status = 'approved' OR p.author_id = auth.uid() OR is_user_admin())
  ));
DROP POLICY IF EXISTS "Public read for post attachments" ON community_post_attachments;
DROP POLICY IF EXISTS community_attachments_read ON community_post_attachments;
CREATE POLICY community_attachments_reviewed_read ON community_post_attachments
  FOR SELECT TO anon, authenticated USING (EXISTS (
    SELECT 1 FROM community_posts p WHERE p.id = post_id
      AND (p.moderation_status = 'approved' OR p.author_id = auth.uid() OR is_user_admin())
  ));
DROP POLICY IF EXISTS "Public read for polls" ON community_polls;
DROP POLICY IF EXISTS community_polls_read ON community_polls;
CREATE POLICY community_polls_reviewed_read ON community_polls
  FOR SELECT TO anon, authenticated USING (EXISTS (
    SELECT 1 FROM community_posts p WHERE p.id = post_id
      AND ((p.moderation_status = 'approved' AND p.is_public = true) OR p.author_id = auth.uid() OR is_user_admin())
  ));
DROP POLICY IF EXISTS "Public read for poll options" ON community_poll_options;
DROP POLICY IF EXISTS community_poll_options_read ON community_poll_options;
CREATE POLICY community_poll_options_reviewed_read ON community_poll_options
  FOR SELECT TO anon, authenticated USING (EXISTS (
    SELECT 1 FROM community_polls poll WHERE poll.id = poll_id
  ));

COMMIT;
