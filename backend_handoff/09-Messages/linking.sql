-- linking.sql (Messages)
-- Sharing and linking domain records into chat conversations.

-- 1. Share a Note, Journal Entry, or Strategy into a Chat Thread
INSERT INTO chat_messages (thread_id, sender_id, body)
VALUES (:thread_id, auth.uid(), :optional_note_text)
RETURNING id INTO v_message_id;

INSERT INTO chat_shared_refs (
    message_id,
    ref_id,
    kind,
    title,
    subtitle,
    ticker,
    tags
) VALUES (
    v_message_id,
    :ref_id,
    :kind,     -- 'note' | 'journal' | 'strategy' | 'aiCopilot' | 'communityPost'
    :title,
    :subtitle,
    :ticker,
    :tags
);

-- 2. Bidirectional Link in Universal Link Graph
SELECT create_universal_link(
    'messageThread',
    :thread_id::text,
    :kind,
    :ref_id,
    'Shared in Conversation'
);
