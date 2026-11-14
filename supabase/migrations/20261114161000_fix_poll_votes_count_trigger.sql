-- Migration: Fix record "new" has no field "votes_count" (42703) when creating polls or updating community posts/comments
-- Root Cause:
--   tradex_private.protect_community_derived_counters() is attached to community_posts,
--   community_comments, and community_poll_options.
--   On non-counter UPDATEs to community_posts (such as publishing a post after inserting
--   its poll options in CommunityPostWriter.create), the first IF branch evaluated to FALSE
--   and PL/pgSQL fell through to ELSIF TG_TABLE_NAME = 'community_poll_options' AND NEW.votes_count ...,
--   attempting to resolve NEW.votes_count on a community_posts record and failing with SQLSTATE 42703.

BEGIN;

ALTER TABLE IF EXISTS public.community_poll_options
  ADD COLUMN IF NOT EXISTS votes_count integer NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION tradex_private.protect_community_derived_counters()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_new jsonb;
  v_old jsonb;
BEGIN
  IF COALESCE(current_setting('tradex.trusted_counter_write', true), '') = 'on' THEN
    RETURN NEW;
  END IF;

  v_new := to_jsonb(NEW);

  IF TG_OP = 'INSERT' THEN
    IF TG_TABLE_NAME = 'community_posts' THEN
      NEW := jsonb_populate_record(
        NEW,
        jsonb_build_object(
          'views_count', 0,
          'likes_count', 0,
          'comments_count', 0,
          'reposts_count', 0,
          'bookmarks_count', 0
        )
      );
    ELSIF TG_TABLE_NAME = 'community_comments' THEN
      NEW := jsonb_populate_record(NEW, jsonb_build_object('likes_count', 0));
    ELSIF TG_TABLE_NAME = 'community_poll_options' THEN
      NEW := jsonb_populate_record(NEW, jsonb_build_object('votes_count', 0));
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    v_old := to_jsonb(OLD);
    IF TG_TABLE_NAME = 'community_posts' THEN
      IF (v_new->'views_count') IS DISTINCT FROM (v_old->'views_count')
        OR (v_new->'likes_count') IS DISTINCT FROM (v_old->'likes_count')
        OR (v_new->'comments_count') IS DISTINCT FROM (v_old->'comments_count')
        OR (v_new->'reposts_count') IS DISTINCT FROM (v_old->'reposts_count')
        OR (v_new->'bookmarks_count') IS DISTINCT FROM (v_old->'bookmarks_count')
      THEN
        RAISE EXCEPTION 'Derived engagement counters cannot be modified directly' USING ERRCODE = '42501';
      END IF;
    ELSIF TG_TABLE_NAME = 'community_comments' THEN
      IF (v_new->'likes_count') IS DISTINCT FROM (v_old->'likes_count') THEN
        RAISE EXCEPTION 'Derived engagement counters cannot be modified directly' USING ERRCODE = '42501';
      END IF;
    ELSIF TG_TABLE_NAME = 'community_poll_options' THEN
      IF (v_new->'votes_count') IS DISTINCT FROM (v_old->'votes_count') THEN
        RAISE EXCEPTION 'Derived engagement counters cannot be modified directly' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_community_poll_votes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM set_config('tradex.trusted_counter_write', 'on', true);
  IF TG_OP = 'INSERT' THEN
    UPDATE public.community_poll_options SET votes_count = votes_count + 1 WHERE id = NEW.option_id;
  ELSIF TG_OP = 'UPDATE' AND NEW.option_id IS DISTINCT FROM OLD.option_id THEN
    UPDATE public.community_poll_options SET votes_count = GREATEST(0, votes_count - 1) WHERE id = OLD.option_id;
    UPDATE public.community_poll_options SET votes_count = votes_count + 1 WHERE id = NEW.option_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.community_poll_options SET votes_count = GREATEST(0, votes_count - 1) WHERE id = OLD.option_id;
  END IF;
  PERFORM set_config('tradex.trusted_counter_write', 'off', true);
  RETURN NULL;
END;
$$;

COMMIT;
