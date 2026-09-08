ALTER TABLE strategies ENABLE ROW LEVEL SECURITY;
-- strategies
DROP POLICY IF EXISTS strategies_own_all ON strategies;
CREATE POLICY strategies_own_all ON strategies FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS strategies_public_read ON strategies;
CREATE POLICY strategies_public_read ON strategies FOR SELECT USING (visibility = 'public');

-- strategy versions
DROP POLICY IF EXISTS strategy_versions_own_all ON strategy_versions;
CREATE POLICY strategy_versions_own_all ON strategy_versions
FOR ALL
USING (
  auth.uid() = (SELECT s.user_id FROM strategies s WHERE s.id = strategy_versions.strategy_id)
)
WITH CHECK (
  auth.uid() = (SELECT s.user_id FROM strategies s WHERE s.id = strategy_versions.strategy_id)
);

-- journal entries
DROP POLICY IF EXISTS journal_entries_own_all ON journal_entries;
CREATE POLICY journal_entries_own_all ON journal_entries FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS journal_entries_public_read ON journal_entries;
CREATE POLICY journal_entries_public_read ON journal_entries
FOR SELECT
USING (
  is_public = true
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = journal_entries.user_id
      AND p.public_journals = true
  )
);

-- journal links
DROP POLICY IF EXISTS journal_links_own_all ON journal_entry_links;
CREATE POLICY journal_links_own_all ON journal_entry_links
FOR ALL
USING (
  auth.uid() = (SELECT je.user_id FROM journal_entries je WHERE je.id = source_entry_id)
  AND auth.uid() = (SELECT je.user_id FROM journal_entries je WHERE je.id = target_entry_id)
)
WITH CHECK (
  auth.uid() = (SELECT je.user_id FROM journal_entries je WHERE je.id = source_entry_id)
  AND auth.uid() = (SELECT je.user_id FROM journal_entries je WHERE je.id = target_entry_id)
);




ALTER TABLE strategy_versions ENABLE ROW LEVEL SECURITY;
-- TODO: Backend needs to implement RLS policies for table strategy_versions
CREATE POLICY strategy_versions_select ON strategy_versions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY strategy_versions_insert ON strategy_versions FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY strategy_versions_update ON strategy_versions FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY strategy_versions_delete ON strategy_versions FOR DELETE USING (user_id = auth.uid());


ALTER TABLE strategy_attachments ENABLE ROW LEVEL SECURITY;
-- TODO: Backend needs to implement RLS policies for table strategy_attachments
CREATE POLICY strategy_attachments_select ON strategy_attachments FOR SELECT USING (user_id = auth.uid());
CREATE POLICY strategy_attachments_insert ON strategy_attachments FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY strategy_attachments_update ON strategy_attachments FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY strategy_attachments_delete ON strategy_attachments FOR DELETE USING (user_id = auth.uid());

