-- 032_community_reactions.sql
--
-- Adds rich emoji reaction support to community post cards
-- Matches reactions: 👍 (Like), 🚀 (Bullish), 💡 (Insightful), 🔥 (Fire), ❤️ (Love)

ALTER TABLE community_likes
    ADD COLUMN IF NOT EXISTS reaction TEXT NOT NULL DEFAULT '👍';

DROP POLICY IF EXISTS "Users manage own likes" ON community_likes;
CREATE POLICY "Users manage own likes"
    ON community_likes FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_community_likes_post_reaction
    ON community_likes(post_id, reaction);
