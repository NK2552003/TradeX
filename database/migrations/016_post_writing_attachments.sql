-- 016_post_writing_attachments.sql
--
-- Prepares social posts to reference zero or one Writing Desk record without
-- implementing a feed or composer. The source must belong to the post author
-- and already be public; publication is an explicit Writing Desk action, never
-- a side effect of inserting a post.

BEGIN;

ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS note_id UUID
    REFERENCES trader_notes(id) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD COLUMN IF NOT EXISTS journal_entry_id UUID
    REFERENCES journal_entries(id) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD COLUMN IF NOT EXISTS strategy_id UUID
    REFERENCES strategies(id) ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_one_writing_attachment;
ALTER TABLE posts ADD CONSTRAINT posts_one_writing_attachment CHECK (
  num_nonnulls(note_id, journal_entry_id, strategy_id) <= 1
);

CREATE INDEX IF NOT EXISTS idx_posts_note
  ON posts(note_id) WHERE note_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_posts_journal_entry
  ON posts(journal_entry_id) WHERE journal_entry_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_posts_strategy
  ON posts(strategy_id) WHERE strategy_id IS NOT NULL;

CREATE OR REPLACE FUNCTION validate_post_writing_attachment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  source_owner UUID;
  source_public BOOLEAN;
BEGIN
  IF NEW.note_id IS NOT NULL THEN
    SELECT user_id, is_public
      INTO source_owner, source_public
      FROM trader_notes WHERE id = NEW.note_id;
  ELSIF NEW.journal_entry_id IS NOT NULL THEN
    SELECT e.user_id, e.is_public AND p.public_journals
      INTO source_owner, source_public
      FROM journal_entries e
      JOIN profiles p ON p.id = e.user_id
      WHERE e.id = NEW.journal_entry_id;
  ELSIF NEW.strategy_id IS NOT NULL THEN
    SELECT user_id, visibility = 'public'
      INTO source_owner, source_public
      FROM strategies WHERE id = NEW.strategy_id;
  ELSE
    RETURN NEW;
  END IF;

  IF source_owner IS NULL OR source_owner <> NEW.user_id THEN
    RAISE EXCEPTION 'A post attachment must belong to the post author';
  END IF;
  IF source_public IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'A post attachment must be public before it is posted';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_posts_validate_writing_attachment ON posts;
CREATE TRIGGER trg_posts_validate_writing_attachment
  BEFORE INSERT OR UPDATE OF user_id, note_id, journal_entry_id, strategy_id
  ON posts
  FOR EACH ROW EXECUTE FUNCTION validate_post_writing_attachment();

COMMIT;
