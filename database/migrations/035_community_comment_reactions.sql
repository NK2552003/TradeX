-- 035_community_comment_reactions.sql
--
-- Adds support for liking and rich emoji reactions (👍, 🚀, 💡, 🔥, ❤️) on community_comments
CREATE TABLE IF NOT EXISTS public.community_comment_likes (
    comment_id UUID NOT NULL REFERENCES public.community_comments(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    reaction TEXT NOT NULL DEFAULT '👍',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (comment_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_comment_likes_user
    ON public.community_comment_likes(user_id);

CREATE INDEX IF NOT EXISTS idx_community_comment_likes_comment
    ON public.community_comment_likes(comment_id);

ALTER TABLE public.community_comment_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read comment likes" ON public.community_comment_likes;
CREATE POLICY "Public read comment likes"
    ON public.community_comment_likes FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Users manage own comment likes" ON public.community_comment_likes;
CREATE POLICY "Users manage own comment likes"
    ON public.community_comment_likes FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Auto-update likes_count on community_comments
CREATE OR REPLACE FUNCTION public.trg_community_comment_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.community_comments
        SET likes_count = likes_count + 1
        WHERE id = NEW.comment_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.community_comments
        SET likes_count = GREATEST(0, likes_count - 1)
        WHERE id = OLD.comment_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS community_comment_likes_count_trg ON public.community_comment_likes;
CREATE TRIGGER community_comment_likes_count_trg
AFTER INSERT OR DELETE ON public.community_comment_likes
FOR EACH ROW EXECUTE FUNCTION public.trg_community_comment_likes_count();
