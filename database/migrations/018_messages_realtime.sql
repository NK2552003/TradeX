-- 018_messages_realtime.sql
--
-- Realtime Messaging: 1-on-1 direct messages, desk group chats, rich media attachments,
-- shared record references, emoji reactions, presence, and Supabase Realtime publication.
--
-- Mirrors models in lib/features/messages/models/messages_models.dart and
-- repository contract in lib/features/messages/data/messages_repository.dart.

CREATE TABLE IF NOT EXISTS chat_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL DEFAULT 'direct' CHECK (type IN ('direct', 'group', 'desk')),
    title TEXT,
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    is_archived BOOLEAN NOT NULL DEFAULT false,
    is_request BOOLEAN NOT NULL DEFAULT false,
    last_message_preview TEXT NOT NULL DEFAULT '',
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_participants (
    thread_id UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (thread_id, user_id)
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE ON UPDATE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    body TEXT NOT NULL DEFAULT '',
    reply_to_id UUID REFERENCES chat_messages(id) ON DELETE SET NULL ON UPDATE CASCADE,
    system_notice BOOLEAN NOT NULL DEFAULT false,
    status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sending', 'sent', 'delivered', 'read', 'failed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE ON UPDATE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('image', 'chart', 'document', 'tradeSetup', 'voice')),
    url TEXT NOT NULL,
    title TEXT NOT NULL DEFAULT '',
    file_size_bytes BIGINT,
    duration_seconds INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_shared_refs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE ON UPDATE CASCADE,
    ref_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    title TEXT NOT NULL,
    subtitle TEXT,
    ticker TEXT,
    tags TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (message_id, user_id, emoji)
);

CREATE TABLE IF NOT EXISTS chat_user_presence (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    status TEXT NOT NULL DEFAULT 'offline' CHECK (status IN ('online', 'away', 'busy', 'offline')),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for lightning fast chat retrieval and message querying
CREATE INDEX IF NOT EXISTS idx_chat_participants_user ON chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_thread_created ON chat_messages(thread_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_attachments_msg ON chat_attachments(message_id);
CREATE INDEX IF NOT EXISTS idx_chat_shared_refs_msg ON chat_shared_refs(message_id);
CREATE INDEX IF NOT EXISTS idx_chat_reactions_msg ON chat_reactions(message_id);

-- Trigger: keep last_message_preview and last_message_at synced on chat_threads
CREATE OR REPLACE FUNCTION update_chat_thread_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE chat_threads
    SET last_message_preview = CASE 
            WHEN NEW.body <> '' THEN SUBSTRING(NEW.body FROM 1 FOR 120)
            ELSE 'Attachment'
        END,
        last_message_at = NEW.created_at,
        updated_at = NEW.created_at
    WHERE id = NEW.thread_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_chat_thread_last_message ON chat_messages;
CREATE TRIGGER trigger_chat_thread_last_message
    AFTER INSERT ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_thread_last_message();

-- Enable Supabase Realtime
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_reactions;
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_user_presence;
    END IF;
END $$;

-- Enable Row Level Security (RLS)
ALTER TABLE chat_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_shared_refs ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_user_presence ENABLE ROW LEVEL SECURITY;

-- Participant-based RLS Policies
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
