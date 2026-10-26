-- Migration 030: Community Polls, Reposts Triggers & Activity History RLS
-- Enables full lifecycle support for Polls / MCQs, Repost counting, and Activity history reads

BEGIN;

-- 1. Authors can create and manage their own polls
DROP POLICY IF EXISTS "Authors manage polls" ON community_polls;
CREATE POLICY "Authors manage polls"
    ON community_polls FOR ALL
    USING (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()));

-- 2. Authors can create and manage poll options
DROP POLICY IF EXISTS "Authors manage poll options" ON community_poll_options;
CREATE POLICY "Authors manage poll options"
    ON community_poll_options FOR ALL
    USING (EXISTS (
        SELECT 1 FROM community_polls p
        JOIN community_posts cp ON cp.id = p.post_id
        WHERE p.id = poll_id AND cp.author_id = auth.uid()
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM community_polls p
        JOIN community_posts cp ON cp.id = p.post_id
        WHERE p.id = poll_id AND cp.author_id = auth.uid()
    ));

-- 3. Trigger function to automatically maintain votes_count on community_poll_options
CREATE OR REPLACE FUNCTION update_community_poll_votes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE community_poll_options SET votes_count = votes_count + 1 WHERE id = NEW.option_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE community_poll_options SET votes_count = GREATEST(0, votes_count - 1) WHERE id = OLD.option_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_community_poll_votes ON community_poll_votes;
CREATE TRIGGER trigger_community_poll_votes
    AFTER INSERT OR DELETE ON community_poll_votes
    FOR EACH ROW EXECUTE FUNCTION update_community_poll_votes();

-- 4. Trigger function to maintain reposts_count on community_posts
CREATE OR REPLACE FUNCTION update_community_post_reposts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE community_posts SET reposts_count = reposts_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE community_posts SET reposts_count = GREATEST(0, reposts_count - 1) WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_community_post_reposts ON community_reposts;
CREATE TRIGGER trigger_community_post_reposts
    AFTER INSERT OR DELETE ON community_reposts
    FOR EACH ROW EXECUTE FUNCTION update_community_post_reposts();

-- 5. Public read policies for community social graphs (likes, reposts, follows)
DROP POLICY IF EXISTS "Public read for reposts" ON community_reposts;
CREATE POLICY "Public read for reposts"
    ON community_reposts FOR SELECT
    TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS "Public read for likes" ON community_likes;
CREATE POLICY "Public read for likes"
    ON community_likes FOR SELECT
    TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS "Public read for follows" ON community_follows;
CREATE POLICY "Public read for follows"
    ON community_follows FOR SELECT
    TO authenticated, anon
    USING (true);

COMMIT;
