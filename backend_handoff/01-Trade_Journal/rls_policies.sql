ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
-- TODO: Backend needs to implement RLS policies for table journal_entries
CREATE POLICY journal_entries_select ON journal_entries FOR SELECT USING (user_id = auth.uid());
CREATE POLICY journal_entries_insert ON journal_entries FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY journal_entries_update ON journal_entries FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY journal_entries_delete ON journal_entries FOR DELETE USING (user_id = auth.uid());


ALTER TABLE journal_entry_links ENABLE ROW LEVEL SECURITY;
-- TODO: Backend needs to implement RLS policies for table journal_entry_links
CREATE POLICY journal_entry_links_select ON journal_entry_links FOR SELECT USING (user_id = auth.uid());
CREATE POLICY journal_entry_links_insert ON journal_entry_links FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY journal_entry_links_update ON journal_entry_links FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY journal_entry_links_delete ON journal_entry_links FOR DELETE USING (user_id = auth.uid());


ALTER TABLE journal_entry_attachments ENABLE ROW LEVEL SECURITY;
-- TODO: Backend needs to implement RLS policies for table journal_entry_attachments
CREATE POLICY journal_entry_attachments_select ON journal_entry_attachments FOR SELECT USING (user_id = auth.uid());
CREATE POLICY journal_entry_attachments_insert ON journal_entry_attachments FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY journal_entry_attachments_update ON journal_entry_attachments FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY journal_entry_attachments_delete ON journal_entry_attachments FOR DELETE USING (user_id = auth.uid());


ALTER TABLE note_journal_links ENABLE ROW LEVEL SECURITY;
-- TODO: Backend needs to implement RLS policies for table note_journal_links
CREATE POLICY note_journal_links_select ON note_journal_links FOR SELECT USING (user_id = auth.uid());
CREATE POLICY note_journal_links_insert ON note_journal_links FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY note_journal_links_update ON note_journal_links FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY note_journal_links_delete ON note_journal_links FOR DELETE USING (user_id = auth.uid());

