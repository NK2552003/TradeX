-- reads.sql (Messages)
-- Queries powering the Inbox list, Unread counters, and Thread Message History.

-- 1. Get inbox threads with peer profile and presence
SELECT 
    t.id,
    t.type,
    t.title,
    t.is_pinned,
    t.is_archived,
    t.is_request,
    t.last_message_preview,
    t.last_message_at,
    -- Peer profile for direct chats
    p.id AS peer_id,
    p.handle AS peer_handle,
    p.display_name AS peer_name,
    p.avatar_url AS peer_avatar,
    COALESCE(pr.status, 'offline') AS peer_presence,
    -- Unread count for current user
    (
        SELECT COUNT(*)
        FROM chat_messages m
        WHERE m.thread_id = t.id
          AND m.created_at > cp.last_read_at
          AND m.sender_id <> auth.uid()
    ) AS unread_count
FROM chat_threads t
JOIN chat_participants cp ON cp.thread_id = t.id AND cp.user_id = auth.uid()
-- Join other participant for direct messaging peer details
LEFT JOIN chat_participants other_cp ON other_cp.thread_id = t.id AND other_cp.user_id <> auth.uid()
LEFT JOIN profiles p ON p.id = other_cp.user_id
LEFT JOIN chat_user_presence pr ON pr.user_id = p.id
WHERE t.is_archived = false
ORDER BY t.is_pinned DESC, t.last_message_at DESC;

-- 2. Fetch paginated thread messages with sender, attachments, and reactions
SELECT 
    m.id,
    m.thread_id,
    m.sender_id,
    p.handle AS sender_handle,
    p.display_name AS sender_name,
    p.avatar_url AS sender_avatar,
    (m.sender_id = auth.uid()) AS is_mine,
    m.body,
    m.reply_to_id,
    m.system_notice,
    m.status,
    m.created_at,
    -- Attachments aggregate
    COALESCE(json_agg(DISTINCT att.*) FILTER (WHERE att.id IS NOT NULL), '[]') AS attachments,
    -- Shared references aggregate
    COALESCE(json_agg(DISTINCT ref.*) FILTER (WHERE ref.id IS NOT NULL), '[]') AS shared_refs,
    -- Reactions aggregate
    COALESCE(json_agg(DISTINCT rx.*) FILTER (WHERE rx.id IS NOT NULL), '[]') AS reactions
FROM chat_messages m
JOIN profiles p ON p.id = m.sender_id
LEFT JOIN chat_attachments att ON att.message_id = m.id
LEFT JOIN chat_shared_refs ref ON ref.message_id = m.id
LEFT JOIN chat_reactions rx ON rx.message_id = m.id
WHERE m.thread_id = :thread_id
GROUP BY m.id, p.id
ORDER BY m.created_at ASC
LIMIT :limit OFFSET :offset;
