-- reads.sql (Community)
-- Queries for feed timeline, channel filtering, post details, comments tree, and author profiles.

-- 1. Main Feed Query (Chronological or Trending)
SELECT 
    p.id,
    p.title,
    p.body,
    p.excerpt,
    p.kind,
    p.channel_id,
    p.tickers,
    p.tags,
    p.views_count,
    p.likes_count,
    p.comments_count,
    p.reposts_count,
    p.bookmarks_count,
    p.is_pinned,
    p.is_featured,
    p.created_at,
    -- Author Details
    a.id AS author_id,
    a.handle AS author_handle,
    a.display_name AS author_name,
    a.avatar_url AS author_avatar,
    a.subscription_tier AS author_tier,
    -- Trade Setup Details
    s.ticker AS setup_ticker,
    s.side AS setup_side,
    s.entry AS setup_entry,
    s.stop_loss AS setup_stop_loss,
    s.target1 AS setup_target1,
    s.target2 AS setup_target2,
    s.timeframe AS setup_timeframe,
    s.chart_url AS setup_chart_url,
    -- User Interactions (Current Authenticated User)
    EXISTS(SELECT 1 FROM community_likes l WHERE l.post_id = p.id AND l.user_id = auth.uid()) AS is_liked,
    EXISTS(SELECT 1 FROM community_bookmarks b WHERE b.post_id = p.id AND b.user_id = auth.uid()) AS is_bookmarked,
    EXISTS(SELECT 1 FROM community_reposts r WHERE r.post_id = p.id AND r.user_id = auth.uid()) AS is_reposted
FROM community_posts p
JOIN profiles a ON a.id = p.author_id
LEFT JOIN community_post_trade_setups s ON s.post_id = p.id
WHERE (:channel_id IS NULL OR p.channel_id = :channel_id)
ORDER BY p.is_pinned DESC, p.created_at DESC
LIMIT :limit OFFSET :offset;

-- 2. Post Thread Details & Comments Tree
SELECT 
    c.id,
    c.post_id,
    c.parent_id,
    c.body,
    c.likes_count,
    c.created_at,
    a.id AS author_id,
    a.handle AS author_handle,
    a.display_name AS author_name,
    a.avatar_url AS author_avatar
FROM community_comments c
JOIN profiles a ON a.id = c.author_id
WHERE c.post_id = :post_id
ORDER BY c.created_at ASC;

-- 3. Poll Details with Realtime Vote Percentages
SELECT 
    o.id AS option_id,
    o.option_text,
    o.votes_count,
    ROUND((o.votes_count::numeric / NULLIF((SELECT SUM(votes_count) FROM community_poll_options WHERE poll_id = :poll_id), 0)) * 100, 1) AS percentage,
    EXISTS(SELECT 1 FROM community_poll_votes v WHERE v.poll_id = :poll_id AND v.option_id = o.id AND v.user_id = auth.uid()) AS is_voted_by_me
FROM community_poll_options o
WHERE o.poll_id = :poll_id
ORDER BY o.id ASC;
