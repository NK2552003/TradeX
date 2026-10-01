-- Source: 009_journal_notes.sql
-- 009_journal_notes.sql
--
-- Journal Notes: brings `journal_entries` up to the shipped `AppTrade` model and
-- adds the attachments table behind the `journal-attachments` bucket.
--
-- A journal entry is a trade *and* the write-up attached to it — one row, never
-- two. See lib/features/journal/data/journal_repository.dart for the contract
-- and docs_/LINKED_NOTES_BACKEND_HANDOFF.md section 3.2 for the reasoning behind
-- every column here.
--
-- RLS policies live in database/rls_policies.sql (repo convention, applied after
-- all migrations per database/README.md). This file only *enables* row level
-- security on the new table, so it is never reachable through the anon key in
-- the window between the two steps.

BEGIN;

ALTER TABLE journal_entries
  ADD COLUMN IF NOT EXISTS title            TEXT    NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS opened_at        TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS closed_at        TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS pnl_percent      NUMERIC,
  ADD COLUMN IF NOT EXISTS r_multiple       NUMERIC,
  ADD COLUMN IF NOT EXISTS psychology_score INTEGER
    CHECK (psychology_score IS NULL OR psychology_score BETWEEN 1 AND 10),
  ADD COLUMN IF NOT EXISTS linked_note_ids  UUID[]  NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS word_count       INTEGER NOT NULL DEFAULT 0
    CHECK (word_count >= 0),
  ADD COLUMN IF NOT EXISTS checklist_done   INTEGER NOT NULL DEFAULT 0
    CHECK (checklist_done >= 0),
  ADD COLUMN IF NOT EXISTS checklist_total  INTEGER NOT NULL DEFAULT 0
    CHECK (checklist_total >= checklist_done),
  ADD COLUMN IF NOT EXISTS has_images       BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS has_code         BOOLEAN NOT NULL DEFAULT false;

-- Backfill before tightening: opened_at is the trade's own clock, not the row's,
-- but for rows written before the column existed they are the best we have.
UPDATE journal_entries SET opened_at = created_at WHERE opened_at IS NULL;
ALTER TABLE journal_entries ALTER COLUMN opened_at SET NOT NULL;

-- Normalise legacy free-text values before constraining them. The client has
-- always written lowercase enum wire ids; hand-seeded rows may not have.
UPDATE journal_entries SET side    = lower(side)    WHERE side    <> lower(side);
UPDATE journal_entries SET outcome = lower(outcome) WHERE outcome <> lower(outcome);

-- `outcome` is written by the client, which derives it from pnl unless the
-- trader overrides it; `outcome_source` records which of the two happened.
-- NOT VALID: existing rows are grandfathered so this migration cannot fail on
-- data it did not write. Clean the legacy rows, then run
--   ALTER TABLE journal_entries VALIDATE CONSTRAINT <name>;
ALTER TABLE journal_entries
  DROP CONSTRAINT IF EXISTS journal_entries_outcome_check,
  DROP CONSTRAINT IF EXISTS journal_entries_side_check,
  DROP CONSTRAINT IF EXISTS journal_entries_outcome_source_check,
  DROP CONSTRAINT IF EXISTS journal_entries_open_has_no_exit;

ALTER TABLE journal_entries
  ADD CONSTRAINT journal_entries_outcome_check
    CHECK (outcome IS NULL OR outcome IN ('win', 'loss', 'breakeven', 'open'))
    NOT VALID,
  ADD CONSTRAINT journal_entries_side_check
    CHECK (side IS NULL OR side IN ('long', 'short'))
    NOT VALID,
  ADD CONSTRAINT journal_entries_outcome_source_check
    CHECK (outcome_source IN ('auto', 'manual'))
    NOT VALID,
  -- An open trade has no exit and no close. A "closed" row with no exit price
  -- silently corrupts every playbook win rate derived from it.
  ADD CONSTRAINT journal_entries_open_has_no_exit
    CHECK (outcome IS DISTINCT FROM 'open'
           OR (exit_price IS NULL AND closed_at IS NULL))
    NOT VALID;

-- Bug fix, not a feature: strategy_id must NOT cascade-delete the trade.
-- Deleting a playbook unfiles its trades; it does not destroy the trader's
-- record of them. trader_notes.strategy_id already gets this right.
ALTER TABLE journal_entries
  DROP CONSTRAINT IF EXISTS journal_entries_strategy_id_fkey,
  ADD CONSTRAINT journal_entries_strategy_id_fkey
    FOREIGN KEY (strategy_id) REFERENCES strategies(id)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- A journal entry's attachments belong to the journal, not to the notes bucket:
-- a trader who deletes a note must not lose the screenshot that proves what a
-- trade looked like.
CREATE TABLE IF NOT EXISTS journal_entry_attachments (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id     UUID NOT NULL REFERENCES journal_entries(id)
                 ON DELETE CASCADE ON UPDATE CASCADE,
  user_id      UUID NOT NULL REFERENCES profiles(id)
                 ON DELETE CASCADE ON UPDATE CASCADE,
  storage_path TEXT NOT NULL UNIQUE,
  filename     TEXT NOT NULL,
  mime_type    TEXT,
  byte_size    BIGINT CHECK (byte_size IS NULL OR byte_size BETWEEN 0 AND 10485760),
  is_image     BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_journal_entry_attachments_entry
  ON journal_entry_attachments(entry_id);
CREATE INDEX IF NOT EXISTS idx_journal_entry_attachments_user
  ON journal_entry_attachments(user_id);

-- The order the journal index actually reads: newest trade first, per owner.
-- Not created_at — a trade backfilled today belongs where it happened.
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_sortdate
  ON journal_entries(user_id, (COALESCE(closed_at, opened_at)) DESC);

-- The prompt the journal leads with: trades with no playbook. Partial, because
-- a filed trade never needs to appear in this query again.
CREATE INDEX IF NOT EXISTS idx_journal_entries_unfiled
  ON journal_entries(user_id) WHERE strategy_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_journal_entries_notes_gin
  ON journal_entries USING GIN (linked_note_ids);

CREATE INDEX IF NOT EXISTS idx_journal_entries_search_gin
  ON journal_entries USING GIN (
    to_tsvector('english',
      coalesce(title, '') || ' ' || coalesce(ticker, '') || ' ' || content)
  );

-- `screenshots TEXT[]` stays for now and is write-frozen: uploadAttachment
-- returns a journal_entry_attachments.storage_path and the client embeds it in
-- the markdown body. Nothing in the app reads the legacy array.

ALTER TABLE journal_entry_attachments ENABLE ROW LEVEL SECURITY;

COMMIT;


