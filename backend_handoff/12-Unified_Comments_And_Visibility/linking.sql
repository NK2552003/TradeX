-- Integration scripts for linking comments and visibility across TradeX

-- 1. Example: Change visibility of a trader note to public
SELECT set_entity_visibility('note', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', true);

-- 2. Example: Change visibility of a trade journal entry to public for peer critique
SELECT set_entity_visibility('journal', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', true);

-- 3. Example: Add comment on a strategy playbook
SELECT add_entity_comment(
    'strategy',
    'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33',
    'Excellent risk-reward on the 200 EMA pullback rules. What is your stop distance on average?',
    NULL,
    'BULLISH'
);

-- 4. Example: React with fire emoji to a comment
SELECT toggle_entity_comment_like('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d44', '🔥');
