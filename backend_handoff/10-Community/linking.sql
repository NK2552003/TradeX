-- linking.sql (Community)
-- Linking community posts with Trade Journal entries, Strategy Playbooks, and Notes.

-- 1. Attach a Trade Journal Execution to a Community Post
INSERT INTO community_post_attachments (
    post_id,
    kind,
    ref_id,
    title,
    url
) VALUES (
    :post_id,
    'journal',
    :journal_entry_id::text,
    :journal_title,
    NULL
);

-- 2. Create Bidirectional Universal Link Edge
SELECT create_universal_link(
    'communityPost',
    :post_id::text,
    'journal',
    :journal_entry_id::text,
    'Shared Trade Record'
);

-- 3. Attach a Strategy Playbook to a Community Post
INSERT INTO community_post_attachments (
    post_id,
    kind,
    ref_id,
    title,
    url
) VALUES (
    :post_id,
    'strategy',
    :strategy_id::text,
    :strategy_title,
    NULL
);

SELECT create_universal_link(
    'communityPost',
    :post_id::text,
    'strategy',
    :strategy_id::text,
    'Referenced Strategy Playbook'
);
