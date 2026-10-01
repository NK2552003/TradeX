-- Source: 010_strategy_notes.sql
-- 010_strategy_notes.sql
--
-- Strategy Notes: brings `strategies` and `strategy_versions` up to the shipped
-- `AppStrategy` / `AppStrategyVersion` models, and adds the attachments table
-- behind the `strategy-attachments` bucket.
--
-- A playbook is markdown, not structured data. `content` was JSONB; the client
-- has always written a markdown body. See
-- docs_/LINKED_NOTES_BACKEND_HANDOFF.md section 3.3.
--
-- The performance figures on a playbook (win rate, average R, net P&L) are NOT
-- columns here. They are derived from the journal entries filed under it — see
-- section 6 of the handoff and the `strategy_performance` view in migration 011.
--
-- RLS policies live in database/rls_policies.sql, applied after all migrations.

BEGIN;

ALTER TABLE strategies
  ADD COLUMN IF NOT EXISTS summary            TEXT,
  ADD COLUMN IF NOT EXISTS status             TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'testing', 'live', 'retired')),
  ADD COLUMN IF NOT EXISTS tags               TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS linked_tickers     TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS linked_note_ids    UUID[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS linked_journal_ids UUID[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS version_count      INTEGER NOT NULL DEFAULT 1
    CHECK (version_count >= 0),
  ADD COLUMN IF NOT EXISTS word_count         INTEGER NOT NULL DEFAULT 0
    CHECK (word_count >= 0),
  ADD COLUMN IF NOT EXISTS checklist_done     INTEGER NOT NULL DEFAULT 0
    CHECK (checklist_done >= 0),
  ADD COLUMN IF NOT EXISTS checklist_total    INTEGER NOT NULL DEFAULT 0
    CHECK (checklist_total >= checklist_done),
  ADD COLUMN IF NOT EXISTS has_images         BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS has_code           BOOLEAN NOT NULL DEFAULT false;

-- The one destructive step in these migrations. Existing rows hold JSONB; the
-- model holds markdown text. Convert rather than drop, and if production already
-- holds *structured* playbook bodies, stop and raise it — a lossy conversion of
-- real playbooks is worth a conversation, not a migration.
ALTER TABLE strategies
  ALTER COLUMN content TYPE TEXT
  USING CASE
    WHEN content IS NULL THEN ''
    WHEN jsonb_typeof(content) = 'string' THEN content #>> '{}'
    ELSE content::text
  END;
ALTER TABLE strategies ALTER COLUMN content SET DEFAULT '';

-- `visibility` carries AppStrategy.isPublic. Two values, not a free-text field.
-- NOT VALID grandfathers rows this migration did not write; clean them, then
--   ALTER TABLE strategies VALIDATE CONSTRAINT strategies_visibility_check;
ALTER TABLE strategies
  DROP CONSTRAINT IF EXISTS strategies_visibility_check;
ALTER TABLE strategies
  ADD CONSTRAINT strategies_visibility_check
    CHECK (visibility IN ('private', 'public')) NOT VALID;

ALTER TABLE strategy_versions
  ADD COLUMN IF NOT EXISTS note       TEXT,
  ADD COLUMN IF NOT EXISTS author_id  UUID REFERENCES profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_current BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS summary    TEXT,
  ADD COLUMN IF NOT EXISTS word_count INTEGER NOT NULL DEFAULT 0
    CHECK (word_count >= 0);

ALTER TABLE strategy_versions
  ALTER COLUMN content TYPE TEXT
  USING CASE
    WHEN content IS NULL THEN ''
    WHEN jsonb_typeof(content) = 'string' THEN content #>> '{}'
    ELSE content::text
  END;
ALTER TABLE strategy_versions ALTER COLUMN content SET DEFAULT '';

-- Backfill: the highest revision of each playbook is the live one.
UPDATE strategy_versions v
   SET is_current = true
 WHERE NOT v.is_current
   AND v.version_number = (
     SELECT MAX(v2.version_number)
       FROM strategy_versions v2
      WHERE v2.strategy_id = v.strategy_id
   );

UPDATE strategies s
   SET version_count = GREATEST(1, (
     SELECT COUNT(*) FROM strategy_versions v WHERE v.strategy_id = s.id
   ));

-- Exactly one live revision per playbook. Without this, "restore v3" can leave
-- two rows claiming to be current and the history screen shows two live badges.
CREATE UNIQUE INDEX IF NOT EXISTS uq_strategy_versions_current
  ON strategy_versions(strategy_id) WHERE is_current;

CREATE INDEX IF NOT EXISTS idx_strategies_user_updated
  ON strategies(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_strategies_user_status
  ON strategies(user_id, status);
CREATE INDEX IF NOT EXISTS idx_strategies_tags_gin
  ON strategies USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_strategies_tickers_gin
  ON strategies USING GIN (linked_tickers);
CREATE INDEX IF NOT EXISTS idx_strategies_journal_gin
  ON strategies USING GIN (linked_journal_ids);

CREATE TABLE IF NOT EXISTS strategy_attachments (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  strategy_id  UUID NOT NULL REFERENCES strategies(id)
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

CREATE INDEX IF NOT EXISTS idx_strategy_attachments_strategy
  ON strategy_attachments(strategy_id);
CREATE INDEX IF NOT EXISTS idx_strategy_attachments_user
  ON strategy_attachments(user_id);

ALTER TABLE strategy_attachments ENABLE ROW LEVEL SECURITY;

COMMIT;


