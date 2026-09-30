-- linking.sql (AI Assistant)
-- Linking AI setups and threads with Journal Entries, Notes, Strategies, and Messages.

-- 1. Create a Trade Journal Entry from an AI Setup
INSERT INTO journal_entries (
    user_id,
    symbol,
    side,
    entry_price,
    stop_loss,
    take_profit,
    notes,
    ai_generated
)
SELECT 
    s.user_id,
    s.symbol,
    s.direction,
    s.entry,
    s.stop_loss,
    s.target1,
    'Imported from AI Copilot Setup (' || s.pattern || '): ' || s.rationale,
    true
FROM ai_chart_setups s
WHERE s.id = :setup_id
RETURNING id;

-- 2. Link AI Setup to Universal Link Graph
SELECT create_universal_link(
    'aiCopilot',
    :setup_id::text,
    'journal',
    :new_journal_id::text,
    'Executed AI Setup'
);

-- 3. Link AI Copilot insight to a Note
SELECT create_universal_link(
    'aiCopilot',
    :thread_id::text,
    'note',
    :note_id::text,
    'Research Discussion'
);
