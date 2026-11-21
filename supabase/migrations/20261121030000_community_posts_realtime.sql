-- Enable real-time Postgres Changes streaming for community feed tables and
-- add a partial index supporting fast, bounded new-post polling queries.
--
-- Rollback / remediation notes:
--   ALTER PUBLICATION supabase_realtime DROP TABLE public.community_posts;
--   ALTER PUBLICATION supabase_realtime DROP TABLE public.community_comments;
--   ALTER PUBLICATION supabase_realtime DROP TABLE public.community_post_attachments;
--   ALTER PUBLICATION supabase_realtime DROP TABLE public.community_likes;
--   ALTER PUBLICATION supabase_realtime DROP TABLE public.community_reposts;
--   ALTER PUBLICATION supabase_realtime DROP TABLE public.community_follows;
--   DROP INDEX IF EXISTS public.idx_community_posts_public_approved_created;

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Enable Supabase Realtime replication for community tables
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_table text;
  v_tables text[] := ARRAY[
    'community_posts',
    'community_comments',
    'community_post_attachments',
    'community_likes',
    'community_reposts',
    'community_follows'
  ];
BEGIN
  FOREACH v_table IN ARRAY v_tables LOOP
    IF to_regclass('public.' || v_table) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', v_table);
      IF EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
      ) AND NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = v_table
      ) THEN
        EXECUTE format(
          'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
          v_table
        );
      END IF;
    END IF;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 2. Partial index for fast new-post watermark checks and feed ordering
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_community_posts_public_approved_created
  ON public.community_posts (created_at DESC)
  WHERE is_public = true AND moderation_status = 'approved';

NOTIFY pgrst, 'reload schema';

COMMIT;
