-- 011_note_link_graph.sql
--
-- The link graph. Three edge types, one join table:
--
--   note  <-> journal   many-to-many, `note_journal_links` (this file)
--   journal -> strategy many-to-one,  `journal_entries.strategy_id`
--   note    -> strategy many-to-one,  `trader_notes.strategy_id`
--
-- Every edge is readable from both ends. The join table and the two strategy_id
-- columns are the source of truth; the four `linked_*_ids` arrays on the parent
-- rows are mirrors, rebuilt by the triggers below and never written by a client.
-- See docs_/LINKED_NOTES_BACKEND_HANDOFF.md sections 2 and 3.4.
--
-- There is deliberately no note <-> note edge: related notes are derived from
-- shared tags. And there is no `note_strategy_links` table: AppNote.strategyId
-- is a single nullable id, so a join table would hold rows no client could
-- produce or resolve.

BEGIN;

CREATE TABLE IF NOT EXISTS note_journal_links (
  note_id    UUID NOT NULL REFERENCES trader_notes(id)
               ON DELETE CASCADE ON UPDATE CASCADE,
  entry_id   UUID NOT NULL REFERENCES journal_entries(id)
               ON DELETE CASCADE ON UPDATE CASCADE,
  -- Denormalised owner: without it every RLS check on this table needs two
  -- subqueries, on the hot path of every linked-records panel in the app.
  user_id    UUID NOT NULL REFERENCES profiles(id)
               ON DELETE CASCADE ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Linking twice is the same as linking once. The caller is a picker the
  -- trader can reopen, and linkNote() is specified as idempotent.
  PRIMARY KEY (note_id, entry_id)
);

CREATE INDEX IF NOT EXISTS idx_note_journal_links_entry ON note_journal_links(entry_id);
CREATE INDEX IF NOT EXISTS idx_note_journal_links_user  ON note_journal_links(user_id);

-- Seed from the array that shipped before this table existed. Do this BEFORE the
-- triggers are created: after that point the array is derived from the table, so
-- skipping the seed would silently delete every link a trader already made.
INSERT INTO note_journal_links (note_id, entry_id, user_id)
SELECT n.id, e.id, n.user_id
  FROM trader_notes n
  CROSS JOIN LATERAL unnest(n.linked_journal_ids) AS l(entry_id)
  JOIN journal_entries e ON e.id = l.entry_id AND e.user_id = n.user_id
ON CONFLICT DO NOTHING;

-- Two triggers, because the two jobs need opposite timings: ownership has to be
-- settled *before* the row lands, and the mirrors can only be rebuilt *after*.

CREATE OR REPLACE FUNCTION validate_note_journal_link()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  n_owner UUID;
  e_owner UUID;
BEGIN
  SELECT user_id INTO n_owner FROM trader_notes    WHERE id = NEW.note_id;
  SELECT user_id INTO e_owner FROM journal_entries WHERE id = NEW.entry_id;
  IF n_owner IS NULL OR e_owner IS NULL OR n_owner <> e_owner THEN
    RAISE EXCEPTION 'note_journal_links: note and entry must share one owner';
  END IF;
  NEW.user_id := n_owner;   -- never trust a client-supplied owner
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION sync_note_journal_mirrors()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  n_id UUID := COALESCE(NEW.note_id,  OLD.note_id);
  e_id UUID := COALESCE(NEW.entry_id, OLD.entry_id);
BEGIN
  -- Recompute, never increment. An append that runs twice leaves a duplicate id
  -- in the array, and the client's union then renders one link as two.
  -- Both UPDATEs may match zero rows: on a cascade delete the parent is already
  -- gone. That is correct and silent — do not look the parent up first.
  UPDATE trader_notes SET linked_journal_ids = COALESCE(
    (SELECT array_agg(entry_id ORDER BY created_at DESC)
       FROM note_journal_links WHERE note_id = n_id), '{}')
   WHERE id = n_id;

  UPDATE journal_entries SET linked_note_ids = COALESCE(
    (SELECT array_agg(note_id ORDER BY created_at DESC)
       FROM note_journal_links WHERE entry_id = e_id), '{}')
   WHERE id = e_id;

  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_note_journal_links_validate ON note_journal_links;
CREATE TRIGGER trg_note_journal_links_validate
  BEFORE INSERT ON note_journal_links
  FOR EACH ROW EXECUTE FUNCTION validate_note_journal_link();

DROP TRIGGER IF EXISTS trg_note_journal_links_sync ON note_journal_links;
CREATE TRIGGER trg_note_journal_links_sync
  AFTER INSERT OR DELETE ON note_journal_links
  FOR EACH ROW EXECUTE FUNCTION sync_note_journal_mirrors();

-- The strategy mirrors work the same way, driven from the child tables.
CREATE OR REPLACE FUNCTION rebuild_strategy_mirrors(p_strategy UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF p_strategy IS NULL THEN RETURN; END IF;
  UPDATE strategies SET
    linked_journal_ids = COALESCE((
      SELECT array_agg(e.id ORDER BY COALESCE(e.closed_at, e.opened_at) DESC)
        FROM journal_entries e WHERE e.strategy_id = p_strategy), '{}'),
    linked_note_ids = COALESCE((
      SELECT array_agg(n.id ORDER BY n.updated_at DESC)
        FROM trader_notes n WHERE n.strategy_id = p_strategy), '{}')
   WHERE id = p_strategy;
END $$;

-- Rebuild for BOTH the old and the new strategy_id. Rebuilding only the new one
-- is the bug to avoid: refiling a trade would leave it listed under the playbook
-- it just left, forever.
CREATE OR REPLACE FUNCTION sync_strategy_mirrors()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF TG_OP <> 'INSERT' THEN PERFORM rebuild_strategy_mirrors(OLD.strategy_id); END IF;
  IF TG_OP <> 'DELETE' THEN PERFORM rebuild_strategy_mirrors(NEW.strategy_id); END IF;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_journal_entries_strategy_mirror ON journal_entries;
CREATE TRIGGER trg_journal_entries_strategy_mirror
  AFTER INSERT OR DELETE OR UPDATE OF strategy_id ON journal_entries
  FOR EACH ROW EXECUTE FUNCTION sync_strategy_mirrors();

DROP TRIGGER IF EXISTS trg_trader_notes_strategy_mirror ON trader_notes;
CREATE TRIGGER trg_trader_notes_strategy_mirror
  AFTER INSERT OR DELETE OR UPDATE OF strategy_id ON trader_notes
  FOR EACH ROW EXECUTE FUNCTION sync_strategy_mirrors();

-- One full pass, so every mirror matches truth the moment this migration ends.
SELECT rebuild_strategy_mirrors(id) FROM strategies;

UPDATE trader_notes n SET linked_journal_ids = COALESCE(
  (SELECT array_agg(l.entry_id ORDER BY l.created_at DESC)
     FROM note_journal_links l WHERE l.note_id = n.id), '{}');

UPDATE journal_entries e SET linked_note_ids = COALESCE(
  (SELECT array_agg(l.note_id ORDER BY l.created_at DESC)
     FROM note_journal_links l WHERE l.entry_id = e.id), '{}');

ALTER TABLE note_journal_links ENABLE ROW LEVEL SECURITY;

COMMIT;
