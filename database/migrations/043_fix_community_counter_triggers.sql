-- 043_fix_community_counter_triggers.sql
--
-- Bug: post like/comment counters stayed stuck (e.g. at 2) when other users
-- reacted. The counter triggers ran as the invoking user, so RLS on
-- community_posts (UPDATE only for author/admin) silently made the
-- `UPDATE community_posts SET likes_count = ...` affect 0 rows.
-- Fix: run counter triggers as SECURITY DEFINER, then recompute counts.

CREATE OR REPLACE FUNCTION update_community_post_likes()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM set_config('tradex.trusted_counter_write', 'on', true);
    IF TG_OP = 'INSERT' THEN
        UPDATE community_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE community_posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id;
    END IF;
    PERFORM set_config('tradex.trusted_counter_write', 'off', true);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION update_community_post_comments()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM set_config('tradex.trusted_counter_write', 'on', true);
    IF TG_OP = 'INSERT' THEN
        UPDATE community_posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE community_posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = OLD.post_id;
    END IF;
    PERFORM set_config('tradex.trusted_counter_write', 'off', true);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Resync existing (stale) counters
UPDATE community_posts p
SET likes_count = (SELECT count(*) FROM community_likes l WHERE l.post_id = p.id),
    comments_count = (SELECT count(*) FROM community_comments c WHERE c.post_id = p.id);
