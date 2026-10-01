-- rls_policies.sql (Community)

ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_post_trade_setups ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_post_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_reposts ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_poll_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read for community posts"
    ON community_posts FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Authors manage own posts"
    ON community_posts FOR ALL
    USING (auth.uid() = author_id)
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Public read for setups and attachments"
    ON community_post_trade_setups FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Authors manage setups"
    ON community_post_trade_setups FOR ALL
    USING (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()));

CREATE POLICY "Public read for post attachments"
    ON community_post_attachments FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Authors manage attachments"
    ON community_post_attachments FOR ALL
    USING (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()));

CREATE POLICY "Public read for comments"
    ON community_comments FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Users can create comments"
    ON community_comments FOR INSERT
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors manage own comments"
    ON community_comments FOR UPDATE
    USING (auth.uid() = author_id);

CREATE POLICY "Authors delete own comments"
    ON community_comments FOR DELETE
    USING (auth.uid() = author_id);

CREATE POLICY "Users manage own likes"
    ON community_likes FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users manage own bookmarks"
    ON community_bookmarks FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users manage own reposts"
    ON community_reposts FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users manage own follows"
    ON community_follows FOR ALL
    USING (auth.uid() = follower_id)
    WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Public read for polls"
    ON community_polls FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Public read for poll options"
    ON community_poll_options FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Users manage own poll votes"
    ON community_poll_votes FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
