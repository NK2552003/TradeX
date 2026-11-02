-- 20261102070000_community_follows_triggers_and_counts.sql
-- Ensure community_follows has public read permissions and trigger-maintained followers/following counts on profiles.

-- 1. Ensure columns exist on profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS followers_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS following_count INTEGER NOT NULL DEFAULT 0;

-- 2. Ensure community_follows table exists and has proper indexes
CREATE TABLE IF NOT EXISTS public.community_follows (
    follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    following_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, following_id),
    CHECK (follower_id <> following_id)
);

CREATE INDEX IF NOT EXISTS idx_community_follows_follower ON public.community_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_community_follows_following ON public.community_follows(following_id);

-- 3. RLS Policies: Public read for everyone, authenticated insert/delete for follower
ALTER TABLE public.community_follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read for follows" ON public.community_follows;
DROP POLICY IF EXISTS "Public read for community follows" ON public.community_follows;
CREATE POLICY "Public read for community follows"
    ON public.community_follows FOR SELECT
    TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS "Manage community follows" ON public.community_follows;
CREATE POLICY "Manage community follows"
    ON public.community_follows FOR ALL
    TO authenticated
    USING (auth.uid() = follower_id)
    WITH CHECK (auth.uid() = follower_id);

-- 4. Trigger function to automatically maintain followers_count and following_count on public.profiles
CREATE OR REPLACE FUNCTION public.sync_community_follow_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Increment followers_count for following_id
        UPDATE public.profiles
        SET followers_count = COALESCE(followers_count, 0) + 1,
            updated_at = now()
        WHERE id = NEW.following_id;

        -- Increment following_count for follower_id
        UPDATE public.profiles
        SET following_count = COALESCE(following_count, 0) + 1,
            updated_at = now()
        WHERE id = NEW.follower_id;

        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Decrement followers_count for following_id
        UPDATE public.profiles
        SET followers_count = GREATEST(0, COALESCE(followers_count, 0) - 1),
            updated_at = now()
        WHERE id = OLD.following_id;

        -- Decrement following_count for follower_id
        UPDATE public.profiles
        SET following_count = GREATEST(0, COALESCE(following_count, 0) - 1),
            updated_at = now()
        WHERE id = OLD.follower_id;

        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_community_follow_counts ON public.community_follows;
CREATE TRIGGER trg_sync_community_follow_counts
    AFTER INSERT OR DELETE ON public.community_follows
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_community_follow_counts();

-- 5. Backfill counts from existing community_follows records
UPDATE public.profiles p
SET followers_count = (
    SELECT COUNT(*) FROM public.community_follows cf WHERE cf.following_id = p.id
),
following_count = (
    SELECT COUNT(*) FROM public.community_follows cf WHERE cf.follower_id = p.id
);
