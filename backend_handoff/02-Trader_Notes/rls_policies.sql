ALTER TABLE trader_notes ENABLE ROW LEVEL SECURITY;
-- TODO: Backend needs to implement RLS policies for table trader_notes
CREATE POLICY trader_notes_select ON trader_notes FOR SELECT USING (user_id = auth.uid());
CREATE POLICY trader_notes_insert ON trader_notes FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY trader_notes_update ON trader_notes FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY trader_notes_delete ON trader_notes FOR DELETE USING (user_id = auth.uid());


ALTER TABLE trader_note_likes ENABLE ROW LEVEL SECURITY;
-- TODO: Backend needs to implement RLS policies for table trader_note_likes
CREATE POLICY trader_note_likes_select ON trader_note_likes FOR SELECT USING (user_id = auth.uid());
CREATE POLICY trader_note_likes_insert ON trader_note_likes FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY trader_note_likes_update ON trader_note_likes FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY trader_note_likes_delete ON trader_note_likes FOR DELETE USING (user_id = auth.uid());


ALTER TABLE trader_note_comments ENABLE ROW LEVEL SECURITY;
-- TODO: Backend needs to implement RLS policies for table trader_note_comments
CREATE POLICY trader_note_comments_select ON trader_note_comments FOR SELECT USING (user_id = auth.uid());
CREATE POLICY trader_note_comments_insert ON trader_note_comments FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY trader_note_comments_update ON trader_note_comments FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY trader_note_comments_delete ON trader_note_comments FOR DELETE USING (user_id = auth.uid());


ALTER TABLE trader_note_views ENABLE ROW LEVEL SECURITY;
-- TODO: Backend needs to implement RLS policies for table trader_note_views
CREATE POLICY trader_note_views_select ON trader_note_views FOR SELECT USING (user_id = auth.uid());
CREATE POLICY trader_note_views_insert ON trader_note_views FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY trader_note_views_update ON trader_note_views FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY trader_note_views_delete ON trader_note_views FOR DELETE USING (user_id = auth.uid());


ALTER TABLE trader_note_attachments ENABLE ROW LEVEL SECURITY;
-- TODO: Backend needs to implement RLS policies for table trader_note_attachments
CREATE POLICY trader_note_attachments_select ON trader_note_attachments FOR SELECT USING (user_id = auth.uid());
CREATE POLICY trader_note_attachments_insert ON trader_note_attachments FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY trader_note_attachments_update ON trader_note_attachments FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY trader_note_attachments_delete ON trader_note_attachments FOR DELETE USING (user_id = auth.uid());

