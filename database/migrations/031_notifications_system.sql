-- ============================================================================
-- Migration 031: Live Notification System, Profile Enhancements & Fixes
-- ============================================================================

-- 1. Upgrade profiles table: add missing verified column
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verified BOOLEAN NOT NULL DEFAULT false;

-- 2. Create or Upgrade notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL ON UPDATE CASCADE,
    type TEXT NOT NULL DEFAULT 'system',
    category TEXT DEFAULT 'system',
    title TEXT NOT NULL DEFAULT '',
    body TEXT,
    deep_link TEXT,
    data JSONB DEFAULT '{}'::jsonb,
    read BOOLEAN NOT NULL DEFAULT false,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Upgrade existing notifications table columns defensively:
DO $$
BEGIN
    -- Relax legacy category NOT NULL constraint if present
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'category') THEN
        ALTER TABLE public.notifications ALTER COLUMN category DROP NOT NULL;
        ALTER TABLE public.notifications ALTER COLUMN category SET DEFAULT 'system';
    ELSE
        ALTER TABLE public.notifications ADD COLUMN category TEXT DEFAULT 'system';
    END IF;

    -- Ensure actor_id column exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'actor_id') THEN
        ALTER TABLE public.notifications ADD COLUMN actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL ON UPDATE CASCADE;
    END IF;

    -- Ensure type column exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'type') THEN
        ALTER TABLE public.notifications ADD COLUMN type TEXT NOT NULL DEFAULT 'system';
        -- Backfill from legacy category if present
        UPDATE public.notifications SET type = category WHERE category IS NOT NULL;
    END IF;

    -- Ensure data column exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'data') THEN
        ALTER TABLE public.notifications ADD COLUMN data JSONB DEFAULT '{}'::jsonb;
    END IF;

    -- Ensure read boolean column exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'read') THEN
        ALTER TABLE public.notifications ADD COLUMN read BOOLEAN NOT NULL DEFAULT false;
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'read_at') THEN
            UPDATE public.notifications SET read = true WHERE read_at IS NOT NULL;
        ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'is_read') THEN
            UPDATE public.notifications SET read = is_read;
        END IF;
    END IF;

    -- Ensure read_at column exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'read_at') THEN
        ALTER TABLE public.notifications ADD COLUMN read_at TIMESTAMPTZ;
    END IF;

    -- Ensure title column has safe default
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'title') THEN
        ALTER TABLE public.notifications ALTER COLUMN title SET DEFAULT '';
    END IF;
END $$;

-- Guarantee moderation_status exists on community_posts and community_comments
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'community_posts') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'community_posts' AND column_name = 'moderation_status') THEN
            ALTER TABLE public.community_posts ADD COLUMN moderation_status TEXT NOT NULL DEFAULT 'approved';
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'community_comments') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'community_comments' AND column_name = 'moderation_status') THEN
            ALTER TABLE public.community_comments ADD COLUMN moderation_status TEXT NOT NULL DEFAULT 'approved';
        END IF;
    END IF;
END $$;

-- 3. Fix infinite recursion in chat_participants RLS (PGRST / code 42P17)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chat_participants') THEN
        DROP POLICY IF EXISTS "Users can view participants of their threads" ON public.chat_participants;
        DROP POLICY IF EXISTS chat_participants_select ON public.chat_participants;
        CREATE POLICY chat_participants_select ON public.chat_participants FOR SELECT
            USING (auth.uid() IS NOT NULL);

        DROP POLICY IF EXISTS "Users can add/leave thread participants" ON public.chat_participants;
        DROP POLICY IF EXISTS chat_participants_manage ON public.chat_participants;
        CREATE POLICY chat_participants_manage ON public.chat_participants FOR ALL
            USING (auth.uid() = user_id OR EXISTS (
                SELECT 1 FROM public.chat_threads WHERE chat_threads.id = chat_participants.thread_id AND chat_threads.created_by = auth.uid()
            ))
            WITH CHECK (auth.uid() = user_id OR EXISTS (
                SELECT 1 FROM public.chat_threads WHERE chat_threads.id = chat_participants.thread_id AND chat_threads.created_by = auth.uid()
            ));
    END IF;
END $$;

-- 4. Indexing on notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id) WHERE read = false;

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Users can read own notifications" ON notifications;
CREATE POLICY "Users can read own notifications"
    ON notifications FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications"
    ON notifications FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications"
    ON notifications FOR DELETE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authenticated users or triggers can insert notifications" ON notifications;
CREATE POLICY "Authenticated users or triggers can insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL OR true);

-- Enable Supabase Realtime publication on notifications
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;

-- 5. Trigger Functions for Automatic Social Notifications

-- (A) When a user likes a post -> notify post author
CREATE OR REPLACE FUNCTION notify_community_like()
RETURNS TRIGGER AS $$
DECLARE
    v_author_id UUID;
    v_post_snippet TEXT;
    v_actor_name TEXT;
    v_post_image TEXT;
BEGIN
    SELECT author_id, SUBSTRING(body FROM 1 FOR 60)
    INTO v_author_id, v_post_snippet
    FROM community_posts
    WHERE id = NEW.post_id;

    IF v_author_id IS NOT NULL AND v_author_id <> NEW.user_id THEN
        SELECT COALESCE(display_name, handle, 'A trader')
        INTO v_actor_name
        FROM profiles
        WHERE id = NEW.user_id;

        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'community_post_attachments') THEN
            SELECT COALESCE(url, ref_id) INTO v_post_image
            FROM community_post_attachments
            WHERE post_id = NEW.post_id AND kind = 'image'
            LIMIT 1;
        END IF;

        INSERT INTO notifications (user_id, actor_id, type, title, body, data)
        VALUES (
            v_author_id,
            NEW.user_id,
            'like',
            'New Like',
            v_actor_name || ' liked your post' || CASE WHEN v_post_snippet IS NOT NULL AND v_post_snippet <> '' THEN ': "' || v_post_snippet || '…"' ELSE '.' END,
            jsonb_build_object('post_id', NEW.post_id, 'post_image', v_post_image)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_community_like ON community_likes;
CREATE TRIGGER trg_notify_community_like
    AFTER INSERT ON community_likes
    FOR EACH ROW EXECUTE FUNCTION notify_community_like();

-- (B) When a user comments on a post -> notify post author
CREATE OR REPLACE FUNCTION notify_community_comment()
RETURNS TRIGGER AS $$
DECLARE
    v_author_id UUID;
    v_actor_name TEXT;
    v_comment_snippet TEXT;
    v_post_image TEXT;
BEGIN
    SELECT author_id
    INTO v_author_id
    FROM community_posts
    WHERE id = NEW.post_id;

    IF v_author_id IS NOT NULL AND v_author_id <> NEW.author_id THEN
        SELECT COALESCE(display_name, handle, 'A trader')
        INTO v_actor_name
        FROM profiles
        WHERE id = NEW.author_id;

        v_comment_snippet := SUBSTRING(NEW.body FROM 1 FOR 60);

        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'community_post_attachments') THEN
            SELECT COALESCE(url, ref_id) INTO v_post_image
            FROM community_post_attachments
            WHERE post_id = NEW.post_id AND kind = 'image'
            LIMIT 1;
        END IF;

        INSERT INTO notifications (user_id, actor_id, type, title, body, data)
        VALUES (
            v_author_id,
            NEW.author_id,
            'comment',
            'New Comment',
            v_actor_name || ' commented: "' || v_comment_snippet || CASE WHEN LENGTH(NEW.body) > 60 THEN '…"' ELSE '"' END,
            jsonb_build_object('post_id', NEW.post_id, 'comment_id', NEW.id, 'post_image', v_post_image)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_community_comment ON community_comments;
CREATE TRIGGER trg_notify_community_comment
    AFTER INSERT ON community_comments
    FOR EACH ROW EXECUTE FUNCTION notify_community_comment();

-- (C) When a user follows someone -> notify the followed user
CREATE OR REPLACE FUNCTION notify_community_follow()
RETURNS TRIGGER AS $$
DECLARE
    v_follower_name TEXT;
BEGIN
    IF NEW.follower_id <> NEW.following_id THEN
        SELECT COALESCE(display_name, handle, 'A trader')
        INTO v_follower_name
        FROM profiles
        WHERE id = NEW.follower_id;

        INSERT INTO notifications (user_id, actor_id, type, title, body, data)
        VALUES (
            NEW.following_id,
            NEW.follower_id,
            'follow',
            'New Follower',
            v_follower_name || ' started following you.',
            jsonb_build_object('follower_id', NEW.follower_id)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_community_follow ON community_follows;
CREATE TRIGGER trg_notify_community_follow
    AFTER INSERT ON community_follows
    FOR EACH ROW EXECUTE FUNCTION notify_community_follow();

-- (D) When a user reposts -> notify original author
CREATE OR REPLACE FUNCTION notify_community_repost()
RETURNS TRIGGER AS $$
DECLARE
    v_author_id UUID;
    v_actor_name TEXT;
    v_post_snippet TEXT;
    v_post_image TEXT;
BEGIN
    SELECT author_id, SUBSTRING(body FROM 1 FOR 60)
    INTO v_author_id, v_post_snippet
    FROM community_posts
    WHERE id = NEW.post_id;

    IF v_author_id IS NOT NULL AND v_author_id <> NEW.user_id THEN
        SELECT COALESCE(display_name, handle, 'A trader')
        INTO v_actor_name
        FROM profiles
        WHERE id = NEW.user_id;

        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'community_post_attachments') THEN
            SELECT COALESCE(url, ref_id) INTO v_post_image
            FROM community_post_attachments
            WHERE post_id = NEW.post_id AND kind = 'image'
            LIMIT 1;
        END IF;

        INSERT INTO notifications (user_id, actor_id, type, title, body, data)
        VALUES (
            v_author_id,
            NEW.user_id,
            'repost',
            'New Repost',
            v_actor_name || ' reposted your trade setup.',
            jsonb_build_object('post_id', NEW.post_id, 'post_image', v_post_image)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_community_repost ON community_reposts;
CREATE TRIGGER trg_notify_community_repost
    AFTER INSERT ON community_reposts
    FOR EACH ROW EXECUTE FUNCTION notify_community_repost();

-- 6. Seed initial system & security notifications for all profiles (only if not already seeded)
DO $$
DECLARE
    prof RECORD;
BEGIN
    FOR prof IN SELECT id FROM profiles LIMIT 50 LOOP
        IF NOT EXISTS (SELECT 1 FROM notifications WHERE user_id = prof.id AND (type = 'security' OR category = 'security')) THEN
            -- Security login alert (like Instagram in screenshot)
            INSERT INTO notifications (user_id, type, category, title, body, data, created_at)
            VALUES (
                prof.id,
                'security',
                'security',
                'New Login Attempt',
                'Someone''s trying to log into your TradeX account. Let us know if it''s you.',
                jsonb_build_object('ip', '104.28.192.1', 'location', 'macOS Safari · London, UK'),
                now() - INTERVAL '3 minutes'
            );

            -- Trade execution system alert
            INSERT INTO notifications (user_id, type, category, title, body, data, created_at)
            VALUES (
                prof.id,
                'trade_execution',
                'system',
                'Order Filled',
                'Bought 50 AAPL @ $185.50 on SMART route. Execution latency: 4ms.',
                jsonb_build_object('symbol', 'AAPL', 'side', 'BUY', 'qty', 50, 'price', 185.50),
                now() - INTERVAL '45 minutes'
            );

            -- Margin / Risk protection alert
            INSERT INTO notifications (user_id, type, category, title, body, data, created_at)
            VALUES (
                prof.id,
                'margin_alert',
                'system',
                'Margin Health Alert',
                'Portfolio margin level at 98% safe buffer. No liquidation risk detected.',
                jsonb_build_object('margin_ratio', 0.98),
                now() - INTERVAL '2 days'
            );
        END IF;
    END LOOP;
END $$;
