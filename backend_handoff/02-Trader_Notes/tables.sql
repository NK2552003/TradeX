-- Source: 007_trader_notes.sql
-- 007_trader_notes.sql
--
-- Trader Notes: long-form markdown notes, one row per note, plus the
-- attachments referenced from a note body.
--
-- The column set mirrors `AppNote` in lib/core/app-ui/models/app_models.dart
-- and the contract in lib/features/notes/data/notes_repository.dart, so a
-- Supabase implementation of `NotesRepository` can select the row and build the
-- model without a translation layer. See docs_/NOTES_BACKEND_HANDOFF.md for the
-- endpoint contract, the storage bucket and the AI Edge Function.
--
-- RLS policies live in database/rls_policies.sql (repo convention, applied
-- after all migrations per database/README.md). This file only *enables* row
-- level security on the new tables, so they are never reachable through the
-- anon key in the window between the two steps: RLS on with no policy denies
-- everything, which is the safe way to fail.

CREATE TABLE IF NOT EXISTS trader_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    title TEXT NOT NULL DEFAULT '',
    -- Raw markdown source. Never a pre-rendered copy: the preview, the PDF
    -- export and any future web reader all parse this same text.
    content TEXT NOT NULL DEFAULT '',
    note_type TEXT NOT NULL DEFAULT 'general'
        CHECK (note_type IN ('general', 'analysis', 'plan', 'review', 'idea', 'cheat_sheet')),
    tags TEXT[] NOT NULL DEFAULT '{}',
    linked_tickers TEXT[] NOT NULL DEFAULT '{}',
    -- Unlike journal_entries.strategy_id this detaches instead of cascading:
    -- retiring a strategy must not delete the write-up explaining why.
    strategy_id UUID REFERENCES strategies(id) ON DELETE SET NULL ON UPDATE CASCADE,
    -- journal_entries.id values. An array cannot carry a foreign key, so a
    -- deleted trade leaves a dangling id here; readers resolve what they can
    -- and drop the rest, which is what the preview screen already does.
    linked_journal_ids UUID[] NOT NULL DEFAULT '{}',
    is_public BOOLEAN NOT NULL DEFAULT false,
    -- Counters derived from `content` at save time so a list of 200 notes can
    -- be rendered without parsing 200 markdown documents.
    word_count INTEGER NOT NULL DEFAULT 0 CHECK (word_count >= 0),
    checklist_done INTEGER NOT NULL DEFAULT 0 CHECK (checklist_done >= 0),
    checklist_total INTEGER NOT NULL DEFAULT 0 CHECK (checklist_total >= checklist_done),
    has_images BOOLEAN NOT NULL DEFAULT false,
    has_code BOOLEAN NOT NULL DEFAULT false,
    view_count INTEGER NOT NULL DEFAULT 0 CHECK (view_count >= 0),
    like_count INTEGER NOT NULL DEFAULT 0 CHECK (like_count >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

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

CREATE TABLE IF NOT EXISTS trader_note_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    note_id UUID NOT NULL REFERENCES trader_notes(id) ON DELETE CASCADE ON UPDATE CASCADE,
    -- Denormalised from the parent note so the RLS policy and the storage path
    -- can be checked without a join on every signed-URL request.
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    -- Object key inside the `note-attachments` bucket, and the value embedded in
    -- the markdown body as local-image://<storage_path>. Unique because
    -- NotesRepository.resolveAttachmentUrl looks the row up by it alone.
    storage_path TEXT NOT NULL UNIQUE,
    filename TEXT NOT NULL,
    mime_type TEXT,
    -- Mirrors the 10 MB bucket limit so an oversized row cannot outlive a
    -- misconfigured bucket.
    byte_size BIGINT CHECK (byte_size IS NULL OR byte_size BETWEEN 0 AND 10485760),
    is_image BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The list screen's default sort, its type filter and its strategy filter.
CREATE INDEX IF NOT EXISTS idx_trader_notes_user_updated ON trader_notes(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_trader_notes_user_type ON trader_notes(user_id, note_type);
CREATE INDEX IF NOT EXISTS idx_trader_notes_user_strategy ON trader_notes(user_id, strategy_id);
-- Tag and ticker chips filter with `tags && ARRAY[...]`, which needs GIN.
CREATE INDEX IF NOT EXISTS idx_trader_notes_tags_gin ON trader_notes USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_trader_notes_tickers_gin ON trader_notes USING GIN (linked_tickers);
-- Partial: the public feed reads a tiny slice of a mostly-private table.
CREATE INDEX IF NOT EXISTS idx_trader_notes_public_updated ON trader_notes(updated_at DESC)
    WHERE is_public = true;
-- Backs the search box once searching moves off the client.
CREATE INDEX IF NOT EXISTS idx_trader_notes_search_gin ON trader_notes
    USING GIN (to_tsvector('english', title || ' ' || content));
CREATE INDEX IF NOT EXISTS idx_trader_note_attachments_note ON trader_note_attachments(note_id);
CREATE INDEX IF NOT EXISTS idx_trader_note_attachments_user ON trader_note_attachments(user_id);
CREATE INDEX IF NOT EXISTS idx_trader_note_comments_note_created
    ON trader_note_comments(note_id, created_at);

-- Redefined here, identical to schema.sql, so this migration also works on a
-- database built incrementally from migrations/ alone.
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trader_notes_updated_at ON trader_notes;
CREATE TRIGGER trg_trader_notes_updated_at
BEFORE UPDATE ON trader_notes
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_trader_note_attachments_updated_at ON trader_note_attachments;
CREATE TRIGGER trg_trader_note_attachments_updated_at
BEFORE UPDATE ON trader_note_attachments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

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

ALTER TABLE trader_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE trader_note_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE trader_note_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE trader_note_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE trader_note_views ENABLE ROW LEVEL SECURITY;


-- Source: 008_trader_note_engagement.sql
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



-- Ticker Linking with Notes (Join Table instead of relying only on TEXT[])
CREATE TABLE IF NOT EXISTS note_ticker_links (
    note_id UUID NOT NULL REFERENCES trader_notes(id) ON DELETE CASCADE,
    symbol TEXT NOT NULL REFERENCES instruments(symbol) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (note_id, symbol)
);
CREATE INDEX IF NOT EXISTS idx_note_ticker_links_symbol ON note_ticker_links(symbol);
CREATE INDEX IF NOT EXISTS idx_note_ticker_links_user ON note_ticker_links(user_id);
