-- Public Trader Note engagement: unique views, likes, and comments.
-- Idempotent so environments that received an earlier version of migration 007
-- can upgrade safely. Apply rls_policies.sql after this migration.

BEGIN;

ALTER TABLE trader_notes
  ADD COLUMN IF NOT EXISTS view_count INTEGER NOT NULL DEFAULT 0
    CHECK (view_count >= 0),
  ADD COLUMN IF NOT EXISTS like_count INTEGER NOT NULL DEFAULT 0
    CHECK (like_count >= 0);

CREATE TABLE IF NOT EXISTS trader_note_likes (
  note_id UUID NOT NULL REFERENCES trader_notes(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (note_id, user_id)
);

CREATE TABLE IF NOT EXISTS trader_note_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES trader_notes(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  content TEXT NOT NULL CHECK (length(btrim(content)) BETWEEN 1 AND 2000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS trader_note_views (
  note_id UUID NOT NULL REFERENCES trader_notes(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (note_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_trader_note_comments_note_created
  ON trader_note_comments(note_id, created_at);

DROP TRIGGER IF EXISTS trg_trader_note_comments_updated_at ON trader_note_comments;
CREATE TRIGGER trg_trader_note_comments_updated_at
BEFORE UPDATE ON trader_note_comments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION refresh_trader_note_engagement_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE affected_note_id UUID;
BEGIN
  affected_note_id := COALESCE(NEW.note_id, OLD.note_id);
  UPDATE trader_notes
  SET like_count = (SELECT count(*) FROM trader_note_likes WHERE note_id = affected_note_id),
      view_count = (SELECT count(*) FROM trader_note_views WHERE note_id = affected_note_id)
  WHERE id = affected_note_id;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_trader_note_like_counts ON trader_note_likes;
CREATE TRIGGER trg_trader_note_like_counts
AFTER INSERT OR DELETE ON trader_note_likes
FOR EACH ROW EXECUTE FUNCTION refresh_trader_note_engagement_counts();

DROP TRIGGER IF EXISTS trg_trader_note_view_counts ON trader_note_views;
CREATE TRIGGER trg_trader_note_view_counts
AFTER INSERT OR DELETE ON trader_note_views
FOR EACH ROW EXECUTE FUNCTION refresh_trader_note_engagement_counts();

ALTER TABLE trader_note_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE trader_note_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE trader_note_views ENABLE ROW LEVEL SECURITY;

COMMIT;
