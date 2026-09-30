-- rls_policies.sql (Messages)

ALTER TABLE chat_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_shared_refs ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_user_presence ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view threads they belong to"
    ON chat_threads FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM chat_participants
        WHERE chat_participants.thread_id = chat_threads.id
        AND chat_participants.user_id = auth.uid()
    ));

CREATE POLICY "Users can create threads"
    ON chat_threads FOR INSERT
    WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update threads they belong to"
    ON chat_threads FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM chat_participants
        WHERE chat_participants.thread_id = chat_threads.id
        AND chat_participants.user_id = auth.uid()
    ));

CREATE POLICY "Users can view participants of their threads"
    ON chat_participants FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM chat_participants cp
        WHERE cp.thread_id = chat_participants.thread_id
        AND cp.user_id = auth.uid()
    ));

CREATE POLICY "Users can add/leave thread participants"
    ON chat_participants FOR ALL
    USING (auth.uid() = user_id OR EXISTS (
        SELECT 1 FROM chat_participants cp
        WHERE cp.thread_id = chat_participants.thread_id
        AND cp.user_id = auth.uid()
        AND cp.role = 'admin'
    ));

CREATE POLICY "Users can view messages in their threads"
    ON chat_messages FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM chat_participants
        WHERE chat_participants.thread_id = chat_messages.thread_id
        AND chat_participants.user_id = auth.uid()
    ));

CREATE POLICY "Users can send messages to their threads"
    ON chat_messages FOR INSERT
    WITH CHECK (auth.uid() = sender_id AND EXISTS (
        SELECT 1 FROM chat_participants
        WHERE chat_participants.thread_id = chat_messages.thread_id
        AND chat_participants.user_id = auth.uid()
    ));

CREATE POLICY "Users can delete own messages"
    ON chat_messages FOR DELETE
    USING (auth.uid() = sender_id);

CREATE POLICY "Users can view and add message reactions"
    ON chat_reactions FOR ALL
    USING (auth.uid() = user_id OR EXISTS (
        SELECT 1 FROM chat_messages m
        JOIN chat_participants p ON p.thread_id = m.thread_id
        WHERE m.id = chat_reactions.message_id
        AND p.user_id = auth.uid()
    ))
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view and manage attachments"
    ON chat_attachments FOR ALL
    USING (EXISTS (
        SELECT 1 FROM chat_messages m
        JOIN chat_participants p ON p.thread_id = m.thread_id
        WHERE m.id = chat_attachments.message_id
        AND p.user_id = auth.uid()
    ));

CREATE POLICY "Users can view and manage shared refs"
    ON chat_shared_refs FOR ALL
    USING (EXISTS (
        SELECT 1 FROM chat_messages m
        JOIN chat_participants p ON p.thread_id = m.thread_id
        WHERE m.id = chat_shared_refs.message_id
        AND p.user_id = auth.uid()
    ));

CREATE POLICY "Anyone authenticated can view presence"
    ON chat_user_presence FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can update own presence"
    ON chat_user_presence FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
