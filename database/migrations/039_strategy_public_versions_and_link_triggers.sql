-- 039_strategy_public_versions_and_link_triggers.sql
--
-- Strategies Hardening (Issue #40):
-- 1. Authorize public strategy versions when parent strategy is public, retaining owner access
-- 2. Protect strategy mirror columns (linked_note_ids, linked_journal_ids) from manual client overwrite races
-- 3. Ensure strategy attachments and storage objects respect parent strategy visibility

BEGIN;

-- 1. Strategy Versions RLS: public read for public strategies; owner all
ALTER TABLE strategy_versions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS strategy_versions_own_all ON strategy_versions;
CREATE POLICY strategy_versions_own_all ON strategy_versions
FOR ALL
TO authenticated
USING (
  auth.uid() = (SELECT s.user_id FROM strategies s WHERE s.id = strategy_versions.strategy_id)
)
WITH CHECK (
  auth.uid() = (SELECT s.user_id FROM strategies s WHERE s.id = strategy_versions.strategy_id)
);

DROP POLICY IF EXISTS strategy_versions_public_read ON strategy_versions;
CREATE POLICY strategy_versions_public_read ON strategy_versions
FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1 FROM strategies s
    WHERE s.id = strategy_versions.strategy_id
      AND s.visibility = 'public'
  )
);

-- 2. Link Graph Mirror Protection: prevent manual client updates from racing with database triggers
CREATE OR REPLACE FUNCTION rebuild_strategy_mirrors(p_strategy UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF p_strategy IS NULL THEN RETURN; END IF;
  PERFORM set_config('trader.rebuilding_mirrors', 'on', true);
  UPDATE strategies SET
    linked_journal_ids = COALESCE((
      SELECT array_agg(e.id ORDER BY COALESCE(e.closed_at, e.opened_at) DESC)
        FROM journal_entries e WHERE e.strategy_id = p_strategy), '{}'),
    linked_note_ids = COALESCE((
      SELECT array_agg(n.id ORDER BY n.updated_at DESC)
        FROM trader_notes n WHERE n.strategy_id = p_strategy), '{}')
   WHERE id = p_strategy;
  PERFORM set_config('trader.rebuilding_mirrors', 'off', true);
END $$;

CREATE OR REPLACE FUNCTION protect_strategy_mirror_columns()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- If rebuild_strategy_mirrors() is executing, allow the update
  IF current_setting('trader.rebuilding_mirrors', true) = 'on' THEN
    RETURN NEW;
  END IF;

  -- Otherwise, preserve the trigger-maintained mirror arrays and prevent client race overwrites
  NEW.linked_note_ids := OLD.linked_note_ids;
  NEW.linked_journal_ids := OLD.linked_journal_ids;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_protect_strategy_mirrors ON strategies;
CREATE TRIGGER trg_protect_strategy_mirrors
  BEFORE UPDATE OF linked_note_ids, linked_journal_ids ON strategies
  FOR EACH ROW EXECUTE FUNCTION protect_strategy_mirror_columns();

-- 3. Strategy Attachments Table RLS
ALTER TABLE strategy_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS strategy_attachments_own_all ON strategy_attachments;
CREATE POLICY strategy_attachments_own_all ON strategy_attachments
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (
  auth.uid() = user_id
  AND auth.uid() = (
    SELECT s.user_id FROM strategies s WHERE s.id = strategy_attachments.strategy_id
  )
);

DROP POLICY IF EXISTS strategy_attachments_public_read ON strategy_attachments;
CREATE POLICY strategy_attachments_public_read ON strategy_attachments
FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1 FROM strategies s
    WHERE s.id = strategy_attachments.strategy_id AND s.visibility = 'public'
  )
);

-- 4. Storage Objects RLS for strategy-attachments bucket (private bucket, matching strategy & owner)
UPDATE storage.buckets SET public = false WHERE id = 'strategy-attachments';

DROP POLICY IF EXISTS strategy_attachments_owner_all ON storage.objects;
CREATE POLICY strategy_attachments_owner_all ON storage.objects
FOR ALL
TO authenticated
USING (
  bucket_id = 'strategy-attachments'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.strategies s
    WHERE s.id::text = (storage.foldername(name))[2]
      AND s.user_id = (SELECT auth.uid())
  )
)
WITH CHECK (
  bucket_id = 'strategy-attachments'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  AND EXISTS (
    SELECT 1 FROM public.strategies s
    WHERE s.id::text = (storage.foldername(name))[2]
      AND s.user_id = (SELECT auth.uid())
  )
);

DROP POLICY IF EXISTS strategy_attachments_objects_public_read ON storage.objects;
CREATE POLICY strategy_attachments_objects_public_read ON storage.objects
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'strategy-attachments'
  AND EXISTS (
    SELECT 1 FROM public.strategies s
     WHERE s.id::text = (storage.foldername(name))[2]
       AND s.user_id::text = (storage.foldername(name))[1]
       AND (
         s.visibility = 'public'
         OR s.user_id = (SELECT auth.uid())
       )
       AND (
         EXISTS (
           SELECT 1 FROM public.strategy_attachments sa
           WHERE sa.storage_path = storage.objects.name
             AND sa.strategy_id = s.id
             AND sa.user_id = s.user_id
         )
         OR NOT EXISTS (
           SELECT 1 FROM public.strategy_attachments sa
           WHERE sa.storage_path = storage.objects.name
         )
       )
  )
);

COMMIT;

