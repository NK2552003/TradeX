BEGIN;

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE strategies ENABLE ROW LEVEL SECURITY;
ALTER TABLE strategy_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entry_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE watchlist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_insight_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE revenuecat_webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE trader_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE trader_note_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE trader_note_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE trader_note_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE trader_note_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entry_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE strategy_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_journal_links ENABLE ROW LEVEL SECURITY;

-- Helper function to check if current user is user_admin
CREATE OR REPLACE FUNCTION is_user_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'user_admin'
  );
$$;

-- profiles
DROP POLICY IF EXISTS profiles_public_read ON profiles;
CREATE POLICY profiles_public_read ON profiles FOR SELECT USING (true);
DROP POLICY IF EXISTS profiles_owner_update ON profiles;
CREATE POLICY profiles_owner_update ON profiles FOR UPDATE USING (auth.uid() = id OR is_user_admin()) WITH CHECK (auth.uid() = id OR is_user_admin());
DROP POLICY IF EXISTS profiles_owner_insert ON profiles;
CREATE POLICY profiles_owner_insert ON profiles FOR INSERT WITH CHECK (auth.uid() = id OR is_user_admin());

-- affiliate_profiles
DROP POLICY IF EXISTS affiliate_profiles_own_read ON affiliate_profiles;
CREATE POLICY affiliate_profiles_own_read ON affiliate_profiles FOR SELECT USING (auth.uid() = id OR is_user_admin());
DROP POLICY IF EXISTS affiliate_profiles_own_update ON affiliate_profiles;
CREATE POLICY affiliate_profiles_own_update ON affiliate_profiles FOR UPDATE USING (auth.uid() = id OR is_user_admin()) WITH CHECK (auth.uid() = id OR is_user_admin());

-- affiliate_referrals
DROP POLICY IF EXISTS affiliate_referrals_own_read ON affiliate_referrals;
CREATE POLICY affiliate_referrals_own_read ON affiliate_referrals FOR SELECT USING (auth.uid() = affiliate_id OR auth.uid() = referred_user_id OR is_user_admin());

-- affiliate_payouts
DROP POLICY IF EXISTS affiliate_payouts_own_read ON affiliate_payouts;
CREATE POLICY affiliate_payouts_own_read ON affiliate_payouts FOR SELECT USING (auth.uid() = affiliate_id OR is_user_admin());
DROP POLICY IF EXISTS affiliate_payouts_admin_all ON affiliate_payouts;
CREATE POLICY affiliate_payouts_admin_all ON affiliate_payouts FOR ALL USING (is_user_admin()) WITH CHECK (is_user_admin());

-- subscriptions
DROP POLICY IF EXISTS subscriptions_own_read ON subscriptions;
CREATE POLICY subscriptions_own_read ON subscriptions FOR SELECT USING (auth.uid() = user_id);

-- device tokens
DROP POLICY IF EXISTS device_tokens_own_all ON device_tokens;
CREATE POLICY device_tokens_own_all ON device_tokens FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- strategies
DROP POLICY IF EXISTS strategies_own_all ON strategies;
CREATE POLICY strategies_own_all ON strategies FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS strategies_public_read ON strategies;
CREATE POLICY strategies_public_read ON strategies FOR SELECT USING (visibility = 'public');

-- strategy versions
DROP POLICY IF EXISTS strategy_versions_own_all ON strategy_versions;
CREATE POLICY strategy_versions_own_all ON strategy_versions
FOR ALL
USING (
  auth.uid() = (SELECT s.user_id FROM strategies s WHERE s.id = strategy_versions.strategy_id)
)
WITH CHECK (
  auth.uid() = (SELECT s.user_id FROM strategies s WHERE s.id = strategy_versions.strategy_id)
);

-- journal entries
DROP POLICY IF EXISTS journal_entries_own_all ON journal_entries;
CREATE POLICY journal_entries_own_all ON journal_entries FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS journal_entries_public_read ON journal_entries;
CREATE POLICY journal_entries_public_read ON journal_entries
FOR SELECT
USING (
  is_public = true
  AND EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = journal_entries.user_id
      AND p.public_journals = true
  )
);

-- journal links
DROP POLICY IF EXISTS journal_links_own_all ON journal_entry_links;
CREATE POLICY journal_links_own_all ON journal_entry_links
FOR ALL
USING (
  auth.uid() = (SELECT je.user_id FROM journal_entries je WHERE je.id = source_entry_id)
  AND auth.uid() = (SELECT je.user_id FROM journal_entries je WHERE je.id = target_entry_id)
)
WITH CHECK (
  auth.uid() = (SELECT je.user_id FROM journal_entries je WHERE je.id = source_entry_id)
  AND auth.uid() = (SELECT je.user_id FROM journal_entries je WHERE je.id = target_entry_id)
);

-- watchlists
DROP POLICY IF EXISTS watchlists_own_all ON watchlists;
CREATE POLICY watchlists_own_all ON watchlists FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS watchlist_items_own_all ON watchlist_items;
CREATE POLICY watchlist_items_own_all ON watchlist_items
FOR ALL
USING (
  auth.uid() = (SELECT w.user_id FROM watchlists w WHERE w.id = watchlist_items.watchlist_id)
)
WITH CHECK (
  auth.uid() = (SELECT w.user_id FROM watchlists w WHERE w.id = watchlist_items.watchlist_id)
);

-- community
DROP POLICY IF EXISTS posts_public_read ON posts;
CREATE POLICY posts_public_read ON posts FOR SELECT USING (true);
DROP POLICY IF EXISTS posts_owner_write ON posts;
CREATE POLICY posts_owner_write ON posts FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS posts_owner_update_delete ON posts;
CREATE POLICY posts_owner_update_delete ON posts FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS posts_owner_delete ON posts;
CREATE POLICY posts_owner_delete ON posts FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS saved_posts_own_all ON saved_posts;
CREATE POLICY saved_posts_own_all ON saved_posts FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS comments_public_read ON comments;
CREATE POLICY comments_public_read ON comments FOR SELECT USING (true);
DROP POLICY IF EXISTS comments_owner_insert ON comments;
CREATE POLICY comments_owner_insert ON comments FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS comments_owner_update_delete ON comments;
CREATE POLICY comments_owner_update_delete ON comments FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS comments_owner_delete ON comments;
CREATE POLICY comments_owner_delete ON comments FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS follows_public_read ON follows;
CREATE POLICY follows_public_read ON follows FOR SELECT USING (true);
DROP POLICY IF EXISTS follows_owner_all ON follows;
CREATE POLICY follows_owner_all ON follows FOR ALL USING (auth.uid() = follower_id) WITH CHECK (auth.uid() = follower_id);

DROP POLICY IF EXISTS likes_public_read ON likes;
CREATE POLICY likes_public_read ON likes FOR SELECT USING (true);
DROP POLICY IF EXISTS likes_owner_all ON likes;
CREATE POLICY likes_owner_all ON likes FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- service role / backend-only tables
-- ai_insights intentionally left without client write policy (cache managed by edge functions).
DROP POLICY IF EXISTS ai_insights_public_read ON ai_insights;
CREATE POLICY ai_insights_public_read ON ai_insights FOR SELECT USING (true);

-- ai_insight_requests + revenuecat_webhook_events: no policies intentionally (service-role only).

-- blocks
DROP POLICY IF EXISTS blocks_own_all ON blocks;
CREATE POLICY blocks_own_all ON blocks FOR ALL USING (auth.uid() = blocker_id) WITH CHECK (auth.uid() = blocker_id);

-- conversations
DROP POLICY IF EXISTS conversations_own_read ON conversations;
CREATE POLICY conversations_own_read ON conversations
FOR SELECT
USING (auth.uid() = user_a_id OR auth.uid() = user_b_id);

DROP POLICY IF EXISTS conversations_paid_insert ON conversations;
CREATE POLICY conversations_paid_insert ON conversations
FOR INSERT
WITH CHECK (
  (auth.uid() = user_a_id OR auth.uid() = user_b_id)
  AND (SELECT p.subscription_tier FROM profiles p WHERE p.id = auth.uid()) IN ('premium', 'enterprise')
  AND NOT are_blocked(user_a_id, user_b_id)
);

-- messages
DROP POLICY IF EXISTS messages_own_conversation_read ON messages;
CREATE POLICY messages_own_conversation_read ON messages
FOR SELECT
USING (
  auth.uid() IN (
    SELECT c.user_a_id FROM conversations c WHERE c.id = messages.conversation_id
    UNION
    SELECT c.user_b_id FROM conversations c WHERE c.id = messages.conversation_id
  )
);

DROP POLICY IF EXISTS messages_paid_insert ON messages;
CREATE POLICY messages_paid_insert ON messages
FOR INSERT
WITH CHECK (
  auth.uid() = sender_id
  AND auth.uid() IN (
    SELECT c.user_a_id FROM conversations c WHERE c.id = messages.conversation_id
    UNION
    SELECT c.user_b_id FROM conversations c WHERE c.id = messages.conversation_id
  )
  AND (SELECT p.subscription_tier FROM profiles p WHERE p.id = auth.uid()) IN ('premium', 'enterprise')
  AND NOT are_blocked(
    sender_id,
    (SELECT CASE WHEN c.user_a_id = sender_id THEN c.user_b_id ELSE c.user_a_id END FROM conversations c WHERE c.id = messages.conversation_id)
  )
);

DROP POLICY IF EXISTS messages_mark_received_read ON messages;
CREATE POLICY messages_mark_received_read ON messages
FOR UPDATE
USING (
  auth.uid() IN (
    SELECT c.user_a_id FROM conversations c WHERE c.id = messages.conversation_id
    UNION
    SELECT c.user_b_id FROM conversations c WHERE c.id = messages.conversation_id
  )
)
WITH CHECK (sender_id <> auth.uid());

-- notifications
DROP POLICY IF EXISTS notifications_own_all ON notifications;
CREATE POLICY notifications_own_all ON notifications FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- trader notes
DROP POLICY IF EXISTS trader_notes_own_all ON trader_notes;
CREATE POLICY trader_notes_own_all ON trader_notes FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS trader_notes_public_read ON trader_notes;
CREATE POLICY trader_notes_public_read ON trader_notes FOR SELECT USING (is_public = true);

DROP POLICY IF EXISTS trader_note_likes_public_read ON trader_note_likes;
CREATE POLICY trader_note_likes_public_read ON trader_note_likes FOR SELECT
USING (EXISTS (SELECT 1 FROM trader_notes n WHERE n.id = note_id AND n.is_public));
DROP POLICY IF EXISTS trader_note_likes_own_write ON trader_note_likes;
CREATE POLICY trader_note_likes_own_write ON trader_note_likes FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (
  auth.uid() = user_id AND
  EXISTS (SELECT 1 FROM trader_notes n WHERE n.id = note_id AND n.is_public)
);

DROP POLICY IF EXISTS trader_note_comments_public_read ON trader_note_comments;
CREATE POLICY trader_note_comments_public_read ON trader_note_comments FOR SELECT
USING (EXISTS (SELECT 1 FROM trader_notes n WHERE n.id = note_id AND n.is_public));
DROP POLICY IF EXISTS trader_note_comments_own_insert ON trader_note_comments;
CREATE POLICY trader_note_comments_own_insert ON trader_note_comments FOR INSERT
WITH CHECK (
  auth.uid() = user_id AND
  EXISTS (SELECT 1 FROM trader_notes n WHERE n.id = note_id AND n.is_public)
);
DROP POLICY IF EXISTS trader_note_comments_own_modify ON trader_note_comments;
CREATE POLICY trader_note_comments_own_modify ON trader_note_comments FOR UPDATE
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS trader_note_comments_own_delete ON trader_note_comments;
CREATE POLICY trader_note_comments_own_delete ON trader_note_comments FOR DELETE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS trader_note_views_own_insert ON trader_note_views;
CREATE POLICY trader_note_views_own_insert ON trader_note_views FOR INSERT
WITH CHECK (
  auth.uid() = user_id AND
  EXISTS (SELECT 1 FROM trader_notes n WHERE n.id = note_id AND n.is_public)
);
DROP POLICY IF EXISTS trader_note_views_owner_read ON trader_note_views;
CREATE POLICY trader_note_views_owner_read ON trader_note_views FOR SELECT
USING (
  auth.uid() = user_id OR
  auth.uid() = (SELECT n.user_id FROM trader_notes n WHERE n.id = note_id)
);

-- trader note attachments
DROP POLICY IF EXISTS trader_note_attachments_own_all ON trader_note_attachments;
CREATE POLICY trader_note_attachments_own_all ON trader_note_attachments
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (
  auth.uid() = user_id
  -- An attachment may only be filed against a note the same user owns,
  -- otherwise a shared note could be used to smuggle rows into someone
  -- else's gallery.
  AND auth.uid() = (SELECT n.user_id FROM trader_notes n WHERE n.id = trader_note_attachments.note_id)
);
-- Without this a public note renders with broken images for every reader but
-- its author, since the preview resolves each attachment row before signing.
DROP POLICY IF EXISTS trader_note_attachments_public_read ON trader_note_attachments;
CREATE POLICY trader_note_attachments_public_read ON trader_note_attachments
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM trader_notes n
    WHERE n.id = trader_note_attachments.note_id AND n.is_public
  )
);

-- note <-> journal links (migration 011)
-- user_id is denormalised onto the join row precisely so this policy is one
-- comparison instead of two subqueries: it is the hot path behind every
-- linked-records panel in the app. Cross-owner edges are rejected by
-- validate_note_journal_link() before the row lands, which is also what assigns
-- user_id -- so WITH CHECK here trusts the trigger, not the client.
DROP POLICY IF EXISTS note_journal_links_own_all ON note_journal_links;
CREATE POLICY note_journal_links_own_all ON note_journal_links
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (
  auth.uid() = (SELECT n.user_id FROM trader_notes n WHERE n.id = note_journal_links.note_id)
);

-- journal entry attachments (migration 009)
-- No public read policy, at any depth. There is no public journal route, so
-- there is no reader to grant.
DROP POLICY IF EXISTS journal_entry_attachments_own_all ON journal_entry_attachments;
CREATE POLICY journal_entry_attachments_own_all ON journal_entry_attachments
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (
  auth.uid() = user_id
  AND auth.uid() = (
    SELECT e.user_id FROM journal_entries e WHERE e.id = journal_entry_attachments.entry_id
  )
);

-- strategy attachments (migration 010)
DROP POLICY IF EXISTS strategy_attachments_own_all ON strategy_attachments;
CREATE POLICY strategy_attachments_own_all ON strategy_attachments
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (
  auth.uid() = user_id
  AND auth.uid() = (
    SELECT s.user_id FROM strategies s WHERE s.id = strategy_attachments.strategy_id
  )
);
-- A published playbook's diagrams travel with it, or it renders with broken
-- images for every reader but its author.
DROP POLICY IF EXISTS strategy_attachments_public_read ON strategy_attachments;
CREATE POLICY strategy_attachments_public_read ON strategy_attachments
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM strategies s
    WHERE s.id = strategy_attachments.strategy_id AND s.visibility = 'public'
  )
);

COMMIT;

-- ---------------------------------------------------------------------------
-- Storage object policies.
--
-- Deliberately a separate transaction: `storage.objects` is owned by
-- supabase_admin, so these must run as a role that can create policies on it
-- (the dashboard SQL editor runs as postgres, which can). A failure here must
-- not roll back the table policies above.
--
-- Create the three private buckets first: note-attachments,
-- journal-attachments, strategy-attachments. Every object key is
-- `<user_id>/<parent_id>/<uuid><ext>`, which is what lets the owner policies be
-- prefix matches rather than joins.
-- ---------------------------------------------------------------------------

BEGIN;

DROP POLICY IF EXISTS note_attachments_owner_all ON storage.objects;
CREATE POLICY note_attachments_owner_all ON storage.objects
FOR ALL
USING (bucket_id = 'note-attachments'
       AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'note-attachments'
       AND (storage.foldername(name))[1] = auth.uid()::text);

-- Compare s.id::text to the path segment rather than casting the segment to
-- uuid: one malformed key would otherwise raise inside a policy, which fails
-- the whole query instead of skipping the one row.
DROP POLICY IF EXISTS note_attachments_public_read ON storage.objects;
CREATE POLICY note_attachments_public_read ON storage.objects
FOR SELECT
USING (
  bucket_id = 'note-attachments'
  AND EXISTS (
    SELECT 1 FROM trader_notes n
     WHERE n.id::text = (storage.foldername(name))[2]
       AND n.is_public
  )
);

-- journal-attachments gets an owner policy and nothing else. A journal entry has
-- no reader other than its owner, so there is nothing to grant, and a "just in
-- case" public read here is how a trade screenshot ends up on a CDN.
DROP POLICY IF EXISTS journal_attachments_owner_all ON storage.objects;
CREATE POLICY journal_attachments_owner_all ON storage.objects
FOR ALL
USING (bucket_id = 'journal-attachments'
       AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'journal-attachments'
       AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS strategy_attachments_owner_all ON storage.objects;
CREATE POLICY strategy_attachments_owner_all ON storage.objects
FOR ALL
USING (bucket_id = 'strategy-attachments'
       AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'strategy-attachments'
       AND (storage.foldername(name))[1] = auth.uid()::text);

-- Without this, granting the attachment *row* to a visitor is not enough:
-- createSignedUrl checks storage.objects RLS for the caller, so the reader gets
-- a row, a request, and a 403.
DROP POLICY IF EXISTS strategy_attachments_objects_public_read ON storage.objects;
CREATE POLICY strategy_attachments_objects_public_read ON storage.objects
FOR SELECT
USING (
  bucket_id = 'strategy-attachments'
  AND EXISTS (
    SELECT 1 FROM strategies s
     WHERE s.id::text = (storage.foldername(name))[2]
       AND s.visibility = 'public'
  )
);

COMMIT;

-- 013 Markets and News
ALTER TABLE instruments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_tickers ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_ticker_links ENABLE ROW LEVEL SECURITY;

-- instruments
DROP POLICY IF EXISTS instruments_read ON instruments;
CREATE POLICY instruments_read ON instruments FOR SELECT USING (true);

-- quotes
DROP POLICY IF EXISTS quotes_read ON quotes;
CREATE POLICY quotes_read ON quotes FOR SELECT USING (true);

-- news_articles
DROP POLICY IF EXISTS news_articles_read ON news_articles;
CREATE POLICY news_articles_read ON news_articles FOR SELECT USING (true);

-- news_tickers
DROP POLICY IF EXISTS news_tickers_read ON news_tickers;
CREATE POLICY news_tickers_read ON news_tickers FOR SELECT USING (true);

-- news_bookmarks
DROP POLICY IF EXISTS news_bookmarks_select ON news_bookmarks;
CREATE POLICY news_bookmarks_select ON news_bookmarks FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS news_bookmarks_insert ON news_bookmarks;
CREATE POLICY news_bookmarks_insert ON news_bookmarks FOR INSERT WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS news_bookmarks_delete ON news_bookmarks;
CREATE POLICY news_bookmarks_delete ON news_bookmarks FOR DELETE USING (user_id = auth.uid());

-- note_ticker_links
DROP POLICY IF EXISTS note_ticker_links_select ON note_ticker_links;
CREATE POLICY note_ticker_links_select ON note_ticker_links FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS note_ticker_links_insert ON note_ticker_links;
CREATE POLICY note_ticker_links_insert ON note_ticker_links FOR INSERT WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS note_ticker_links_delete ON note_ticker_links;
CREATE POLICY note_ticker_links_delete ON note_ticker_links FOR DELETE USING (user_id = auth.uid());

-- 014 Market History
ALTER TABLE market_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS market_history_read ON market_history;
CREATE POLICY market_history_read ON market_history FOR SELECT USING (true);
