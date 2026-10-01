-- reads.sql (AI Assistant)
-- Production read queries for AI Copilot screens and views.

-- 1. Fetch all threads for active user
SELECT 
    t.id,
    t.title,
    t.persona,
    t.pinned,
    t.created_at,
    t.updated_at,
    (SELECT COUNT(*) FROM ai_messages m WHERE m.thread_id = t.id AND m.role <> 'system') AS message_count,
    (SELECT m.body FROM ai_messages m WHERE m.thread_id = t.id AND NOT m.pending AND m.body <> '' ORDER BY m.created_at DESC LIMIT 1) AS preview
FROM ai_threads t
WHERE t.user_id = auth.uid()
ORDER BY t.pinned DESC, t.updated_at DESC;

-- 2. Fetch messages in active thread with attached chart setup
SELECT 
    m.id,
    m.thread_id,
    m.role,
    m.body,
    m.pending,
    m.error,
    m.sources,
    m.attachments,
    m.created_at,
    s.id AS setup_id,
    s.symbol AS setup_symbol,
    s.timeframe AS setup_timeframe,
    s.pattern AS setup_pattern,
    s.direction AS setup_direction,
    s.entry AS setup_entry,
    s.stop_loss AS setup_stop_loss,
    s.target1 AS setup_target1,
    s.target2 AS setup_target2,
    s.confidence AS setup_confidence,
    s.rationale AS setup_rationale
FROM ai_messages m
LEFT JOIN ai_chart_setups s ON s.id = m.chart_setup_id
WHERE m.thread_id = :thread_id
ORDER BY m.created_at ASC;

-- 3. Fetch latest market insights
SELECT 
    id,
    title,
    body,
    confidence,
    sentiment_score,
    tickers,
    created_at
FROM ai_insights
WHERE user_id = auth.uid()
ORDER BY created_at DESC
LIMIT 20;

-- 4. Check user quota before invoking generation
SELECT 
    daily_limit,
    daily_used,
    (daily_limit - daily_used) AS remaining,
    reset_at
FROM ai_quotas
WHERE user_id = auth.uid();
