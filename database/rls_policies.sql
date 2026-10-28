BEGIN;

-- Enable Row Level Security idempotently on all application tables
ALTER TABLE IF EXISTS profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS affiliate_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS affiliate_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS affiliate_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS strategies ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS strategy_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS journal_entry_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS watchlist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS saved_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS ai_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS ai_insight_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS revenuecat_webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS trader_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS trader_note_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS trader_note_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS trader_note_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS trader_note_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS journal_entry_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS strategy_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS note_journal_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS post_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS trader_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS trader_checklists ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS data_export_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS desk_risk_policies ENABLE ROW LEVEL SECURITY;

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
CREATE POLICY subscriptions_own_read ON subscriptions FOR SELECT USING (auth.uid() = user_id OR is_user_admin());
DROP POLICY IF EXISTS subscriptions_own_write ON subscriptions;
DROP POLICY IF EXISTS subscriptions_admin_write ON subscriptions;
CREATE POLICY subscriptions_admin_write ON subscriptions FOR ALL TO authenticated
    USING (is_user_admin()) WITH CHECK (is_user_admin());

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

-- AI quota requests are user-owned and metered by the trigger in migration 034.
DROP POLICY IF EXISTS ai_insight_requests_own_read ON ai_insight_requests;
CREATE POLICY ai_insight_requests_own_read ON ai_insight_requests FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR is_user_admin());
DROP POLICY IF EXISTS ai_insight_requests_own_insert ON ai_insight_requests;
CREATE POLICY ai_insight_requests_own_insert ON ai_insight_requests FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());
-- revenuecat_webhook_events remains service-role only.

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
-- post_views
DROP POLICY IF EXISTS post_views_own_all ON post_views;
CREATE POLICY post_views_own_all ON post_views FOR ALL USING (auth.uid() = user_id OR user_id IS NULL) WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- trader_preferences & checklists
DROP POLICY IF EXISTS trader_preferences_own_all ON trader_preferences;
CREATE POLICY trader_preferences_own_all ON trader_preferences FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS trader_checklists_own_all ON trader_checklists;
CREATE POLICY trader_checklists_own_all ON trader_checklists FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- invoices
DROP POLICY IF EXISTS invoices_own_read ON invoices;
CREATE POLICY invoices_own_read ON invoices FOR SELECT USING (auth.uid() = user_id OR is_user_admin());
DROP POLICY IF EXISTS invoices_admin_write ON invoices;
CREATE POLICY invoices_admin_write ON invoices FOR ALL USING (is_user_admin()) WITH CHECK (is_user_admin());

-- data_export_requests
DROP POLICY IF EXISTS data_export_requests_own_all ON data_export_requests;
CREATE POLICY data_export_requests_own_all ON data_export_requests FOR ALL USING (auth.uid() = user_id OR is_user_admin()) WITH CHECK (auth.uid() = user_id OR is_user_admin());

-- organizations
DROP POLICY IF EXISTS organizations_read ON organizations;
CREATE POLICY organizations_read ON organizations FOR SELECT USING (true);
DROP POLICY IF EXISTS organizations_owner_all ON organizations;
CREATE POLICY organizations_owner_all ON organizations FOR ALL USING (auth.uid() = owner_id OR is_user_admin()) WITH CHECK (auth.uid() = owner_id OR is_user_admin());

-- organization_members
DROP POLICY IF EXISTS organization_members_read ON organization_members;
CREATE POLICY organization_members_read ON organization_members FOR SELECT USING (true);
DROP POLICY IF EXISTS organization_members_admin_write ON organization_members;
CREATE POLICY organization_members_admin_write ON organization_members FOR ALL
USING (
  is_user_admin()
  OR auth.uid() = user_id
  OR auth.uid() IN (SELECT o.owner_id FROM organizations o WHERE o.id = organization_members.organization_id)
)
WITH CHECK (
  is_user_admin()
  OR auth.uid() = user_id
  OR auth.uid() IN (SELECT o.owner_id FROM organizations o WHERE o.id = organization_members.organization_id)
);

-- desk_risk_policies
DROP POLICY IF EXISTS desk_risk_policies_read ON desk_risk_policies;
CREATE POLICY desk_risk_policies_read ON desk_risk_policies FOR SELECT USING (true);
DROP POLICY IF EXISTS desk_risk_policies_admin_write ON desk_risk_policies;
CREATE POLICY desk_risk_policies_admin_write ON desk_risk_policies FOR ALL USING (auth.uid() = admin_id OR is_user_admin()) WITH CHECK (auth.uid() = admin_id OR is_user_admin());

-- ============================================================
-- FINANCIAL REFERENCE & MARKET DATA TABLES (Public Read, Admin Write)
-- ============================================================
DO $$
DECLARE
  tbl text;
  market_tables text[] := ARRAY[
    'tickers',
    'stock_quotes',
    'stock_fundamentals',
    'stock_price_history',
    'news_articles',
    'news_article_tickers',
    'news_topics',
    'news_article_topics',
    'screener_categories',
    'screener_results',
    'index_metadata',
    'sector_metadata',
    'options_expirations',
    'options_contracts',
    'dividends',
    'stock_splits',
    'analyst_recommendations',
    'holders'
  ];
BEGIN
  FOREACH tbl IN ARRAY market_tables LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
      EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', tbl);
      EXECUTE format('DROP POLICY IF EXISTS %I_public_read ON %I;', tbl, tbl);
      EXECUTE format('CREATE POLICY %I_public_read ON %I FOR SELECT USING (true);', tbl, tbl);
      EXECUTE format('DROP POLICY IF EXISTS %I_admin_write ON %I;', tbl, tbl);
      EXECUTE format('CREATE POLICY %I_admin_write ON %I FOR ALL USING (is_user_admin()) WITH CHECK (is_user_admin());', tbl, tbl);
    END IF;
  END LOOP;
END $$;

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

DROP POLICY IF EXISTS community_attachments_owner_all ON storage.objects;
CREATE POLICY community_attachments_owner_all ON storage.objects
FOR ALL
USING (bucket_id = 'community-attachments'
       AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'community-attachments'
       AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS community_attachments_objects_public_read ON storage.objects;
CREATE POLICY community_attachments_objects_public_read ON storage.objects
FOR SELECT
USING (bucket_id = 'community-attachments');

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

-- ============================================================================
-- 017 AI Assistant RLS
-- ============================================================================
ALTER TABLE ai_chart_setups ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_quotas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_chart_setups_manage ON ai_chart_setups;
CREATE POLICY ai_chart_setups_manage ON ai_chart_setups FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_threads_manage ON ai_threads;
CREATE POLICY ai_threads_manage ON ai_threads FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_messages_manage ON ai_messages;
CREATE POLICY ai_messages_manage ON ai_messages FOR ALL
    USING (EXISTS (SELECT 1 FROM ai_threads WHERE ai_threads.id = ai_messages.thread_id AND ai_threads.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM ai_threads WHERE ai_threads.id = ai_messages.thread_id AND ai_threads.user_id = auth.uid()));

DROP POLICY IF EXISTS ai_insights_manage ON ai_insights;
CREATE POLICY ai_insights_manage ON ai_insights FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS ai_quotas_select ON ai_quotas;
CREATE POLICY ai_quotas_select ON ai_quotas FOR SELECT USING (auth.uid() = user_id);

-- ============================================================================
-- 018 Messages Realtime RLS
-- ============================================================================
ALTER TABLE chat_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_shared_refs ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_user_presence ENABLE ROW LEVEL SECURITY;

-- Helper to break RLS infinite recursion
CREATE OR REPLACE FUNCTION public.user_is_chat_participant(p_thread_id uuid, p_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_participants
    WHERE thread_id = p_thread_id AND user_id = p_user_id
  );
$$;

DROP POLICY IF EXISTS chat_threads_select ON chat_threads;
CREATE POLICY chat_threads_select ON chat_threads FOR SELECT
    USING (created_by = auth.uid() OR public.user_is_chat_participant(id, auth.uid()));

DROP POLICY IF EXISTS chat_threads_insert ON chat_threads;
CREATE POLICY chat_threads_insert ON chat_threads FOR INSERT WITH CHECK (auth.uid() = created_by);

DROP POLICY IF EXISTS chat_threads_update ON chat_threads;
CREATE POLICY chat_threads_update ON chat_threads FOR UPDATE
    USING (created_by = auth.uid() OR public.user_is_chat_participant(id, auth.uid()));

DROP POLICY IF EXISTS chat_participants_select ON chat_participants;
CREATE POLICY chat_participants_select ON chat_participants FOR SELECT
    USING (user_id = auth.uid() OR public.user_is_chat_participant(thread_id, auth.uid()));

DROP POLICY IF EXISTS chat_participants_manage ON chat_participants;
CREATE POLICY chat_participants_manage ON chat_participants FOR ALL
    USING (auth.uid() = user_id OR public.user_is_chat_participant(thread_id, auth.uid()))
    WITH CHECK (auth.uid() = user_id OR public.user_is_chat_participant(thread_id, auth.uid()));

DROP POLICY IF EXISTS chat_messages_select ON chat_messages;
CREATE POLICY chat_messages_select ON chat_messages FOR SELECT
    USING (sender_id = auth.uid() OR public.user_is_chat_participant(thread_id, auth.uid()));

DROP POLICY IF EXISTS chat_messages_insert ON chat_messages;
CREATE POLICY chat_messages_insert ON chat_messages FOR INSERT
    WITH CHECK (auth.uid() = sender_id AND EXISTS (SELECT 1 FROM chat_participants WHERE chat_participants.thread_id = chat_messages.thread_id AND chat_participants.user_id = auth.uid()));

DROP POLICY IF EXISTS chat_messages_delete ON chat_messages;
CREATE POLICY chat_messages_delete ON chat_messages FOR DELETE USING (auth.uid() = sender_id);

DROP POLICY IF EXISTS chat_reactions_manage ON chat_reactions;
CREATE POLICY chat_reactions_manage ON chat_reactions FOR ALL
    USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM chat_messages m JOIN chat_participants p ON p.thread_id = m.thread_id WHERE m.id = chat_reactions.message_id AND p.user_id = auth.uid()))
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS chat_attachments_manage ON chat_attachments;
CREATE POLICY chat_attachments_manage ON chat_attachments FOR ALL
    USING (EXISTS (SELECT 1 FROM chat_messages m JOIN chat_participants p ON p.thread_id = m.thread_id WHERE m.id = chat_attachments.message_id AND p.user_id = auth.uid()));

DROP POLICY IF EXISTS chat_shared_refs_manage ON chat_shared_refs;
CREATE POLICY chat_shared_refs_manage ON chat_shared_refs FOR ALL
    USING (EXISTS (SELECT 1 FROM chat_messages m JOIN chat_participants p ON p.thread_id = m.thread_id WHERE m.id = chat_shared_refs.message_id AND p.user_id = auth.uid()));

DROP POLICY IF EXISTS chat_user_presence_select ON chat_user_presence;
CREATE POLICY chat_user_presence_select ON chat_user_presence FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS chat_user_presence_manage ON chat_user_presence;
CREATE POLICY chat_user_presence_manage ON chat_user_presence FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 019 Community RLS
-- ============================================================================
ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_post_trade_setups ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_post_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_reposts ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_poll_votes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS community_posts_read ON community_posts;
DROP POLICY IF EXISTS community_posts_manage ON community_posts;
DROP POLICY IF EXISTS community_posts_reviewed_read ON community_posts;
DROP POLICY IF EXISTS community_posts_author_insert ON community_posts;
DROP POLICY IF EXISTS community_posts_author_update ON community_posts;
DROP POLICY IF EXISTS community_posts_author_delete ON community_posts;

CREATE POLICY community_posts_reviewed_read ON community_posts FOR SELECT
  TO anon, authenticated USING (
    (
      (moderation_status = 'approved' AND is_public = true)
      OR (auth.uid() = author_id)
      OR is_user_admin()
    )
    AND (
      auth.uid() IS NULL
      OR auth.uid() = author_id
      OR is_user_admin()
      OR NOT are_blocked(auth.uid(), author_id)
    )
  );

CREATE POLICY community_posts_author_insert ON community_posts FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = author_id);

CREATE POLICY community_posts_author_update ON community_posts FOR UPDATE
  TO authenticated
  USING (auth.uid() = author_id OR is_user_admin())
  WITH CHECK (auth.uid() = author_id OR is_user_admin());

CREATE POLICY community_posts_author_delete ON community_posts FOR DELETE
  TO authenticated
  USING (auth.uid() = author_id OR is_user_admin());

DROP POLICY IF EXISTS community_setups_read ON community_post_trade_setups;
CREATE POLICY community_setups_read ON community_post_trade_setups FOR SELECT TO authenticated, anon
    USING (EXISTS (SELECT 1 FROM community_posts p WHERE p.id = post_id
      AND ((p.moderation_status = 'approved' AND p.is_public = true) OR p.author_id = auth.uid() OR is_user_admin())));

DROP POLICY IF EXISTS community_setups_manage ON community_post_trade_setups;
CREATE POLICY community_setups_manage ON community_post_trade_setups FOR ALL
    USING (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()));

DROP POLICY IF EXISTS community_attachments_read ON community_post_attachments;
CREATE POLICY community_attachments_read ON community_post_attachments FOR SELECT TO authenticated, anon
    USING (EXISTS (SELECT 1 FROM community_posts p WHERE p.id = post_id
      AND ((p.moderation_status = 'approved' AND p.is_public = true) OR p.author_id = auth.uid() OR is_user_admin())));

DROP POLICY IF EXISTS community_attachments_manage ON community_post_attachments;
CREATE POLICY community_attachments_manage ON community_post_attachments FOR ALL
    USING (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()));

-- Drop legacy permissive policies from migration 034 if present
DROP POLICY IF EXISTS community_comments_reviewed_read ON community_comments;
DROP POLICY IF EXISTS community_comments_review_update ON community_comments;
DROP POLICY IF EXISTS community_comments_review_delete ON community_comments;

-- Helper function to check if parent post author is blocked outside caller RLS
CREATE OR REPLACE FUNCTION public.is_community_post_author_blocked(p_post_id uuid, p_viewer_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.community_posts p
    WHERE p.id = p_post_id
      AND public.are_blocked(p_viewer_id, p.author_id)
  );
$$;

REVOKE ALL ON FUNCTION public.is_community_post_author_blocked(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_community_post_author_blocked(uuid, uuid) TO anon, authenticated;

-- Helper function to validate comment parent authorization outside caller RLS
-- Does not treat missing or RLS-hidden parent as permission
CREATE OR REPLACE FUNCTION public.can_comment_on_community_post(p_post_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
DECLARE
  v_author_id uuid;
  v_is_public boolean;
  v_moderation_status text;
BEGIN
  IF p_post_id IS NULL OR p_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF public.is_user_admin() THEN
    RETURN TRUE;
  END IF;

  -- Look up parent post outside caller RLS
  SELECT author_id, is_public, moderation_status
  INTO v_author_id, v_is_public, v_moderation_status
  FROM public.community_posts
  WHERE id = p_post_id;

  -- Missing or inaccessible parent is NOT permission
  IF v_author_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Parent must be approved and public, or user is the author
  IF NOT (
    (v_moderation_status = 'approved' AND v_is_public = true)
    OR v_author_id = p_user_id
  ) THEN
    RETURN FALSE;
  END IF;

  -- Block check: if either user blocked the other, comment insertion is forbidden
  IF public.are_blocked(p_user_id, v_author_id) THEN
    RETURN FALSE;
  END IF;

  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.can_comment_on_community_post(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_comment_on_community_post(uuid, uuid) TO anon, authenticated;

-- Trigger function for comment update: permits ordinary edits if post_id is unchanged;
-- verifies destination post authorization if reparenting is attempted
CREATE OR REPLACE FUNCTION public.check_community_comment_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.post_id IS DISTINCT FROM OLD.post_id THEN
    IF NOT public.can_comment_on_community_post(NEW.post_id, auth.uid()) THEN
      RAISE EXCEPTION 'Cannot reparent comment to destination post';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.check_community_comment_update() FROM PUBLIC, anon, authenticated;

-- 3. Hardened RLS policies for community_comments
ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read for comments" ON community_comments;
DROP POLICY IF EXISTS "Users can create comments" ON community_comments;
DROP POLICY IF EXISTS "Authors manage own comments" ON community_comments;
DROP POLICY IF EXISTS "Authors delete own comments" ON community_comments;
DROP POLICY IF EXISTS community_comments_read ON community_comments;
DROP POLICY IF EXISTS community_comments_insert ON community_comments;
DROP POLICY IF EXISTS community_comments_manage ON community_comments;
DROP POLICY IF EXISTS community_comments_author_update ON community_comments;
DROP POLICY IF EXISTS community_comments_author_delete ON community_comments;
DROP POLICY IF EXISTS community_comments_reviewed_read ON community_comments;
DROP POLICY IF EXISTS community_comments_review_update ON community_comments;
DROP POLICY IF EXISTS community_comments_review_delete ON community_comments;

CREATE POLICY community_comments_read ON community_comments FOR SELECT
  TO anon, authenticated USING (
    (
      (moderation_status = 'approved' AND EXISTS (
        SELECT 1 FROM community_posts p
        WHERE p.id = post_id
        AND p.moderation_status = 'approved'
        AND p.is_public = true
      ))
      OR author_id = auth.uid()
      OR is_user_admin()
    )
    AND (
      auth.uid() IS NULL
      OR author_id = auth.uid()
      OR is_user_admin()
      OR NOT are_blocked(auth.uid(), author_id)
    )
    AND (
      auth.uid() IS NULL
      OR is_user_admin()
      OR NOT is_community_post_author_blocked(post_id, auth.uid())
    )
  );

CREATE POLICY community_comments_author_insert ON community_comments FOR INSERT
  TO authenticated WITH CHECK (
    auth.uid() = author_id
    AND can_comment_on_community_post(post_id, auth.uid())
  );

CREATE POLICY community_comments_author_update ON community_comments FOR UPDATE
  TO authenticated
  USING (auth.uid() = author_id OR is_user_admin())
  WITH CHECK (auth.uid() = author_id OR is_user_admin());

CREATE POLICY community_comments_author_delete ON community_comments FOR DELETE
  TO authenticated
  USING (auth.uid() = author_id OR is_user_admin());

DROP TRIGGER IF EXISTS trg_check_community_comment_update ON public.community_comments;
CREATE TRIGGER trg_check_community_comment_update
BEFORE UPDATE ON public.community_comments
FOR EACH ROW EXECUTE FUNCTION public.check_community_comment_update();


DROP POLICY IF EXISTS community_likes_manage ON community_likes;
CREATE POLICY community_likes_manage ON community_likes FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS community_bookmarks_manage ON community_bookmarks;
CREATE POLICY community_bookmarks_manage ON community_bookmarks FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS community_reposts_manage ON community_reposts;
CREATE POLICY community_reposts_manage ON community_reposts FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS community_follows_manage ON community_follows;
CREATE POLICY community_follows_manage ON community_follows FOR ALL
    USING (auth.uid() = follower_id) WITH CHECK (auth.uid() = follower_id);

DROP POLICY IF EXISTS community_polls_read ON community_polls;
CREATE POLICY community_polls_read ON community_polls FOR SELECT TO authenticated, anon
    USING (EXISTS (SELECT 1 FROM community_posts p WHERE p.id = post_id
      AND ((p.moderation_status = 'approved' AND p.is_public = true) OR p.author_id = auth.uid() OR is_user_admin())));

DROP POLICY IF EXISTS community_poll_options_read ON community_poll_options;
CREATE POLICY community_poll_options_read ON community_poll_options FOR SELECT TO authenticated, anon
    USING (EXISTS (SELECT 1 FROM community_polls poll WHERE poll.id = poll_id));

DROP POLICY IF EXISTS community_poll_votes_manage ON community_poll_votes;
CREATE POLICY community_poll_votes_manage ON community_poll_votes FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 020 Universal Link Graph RLS
-- ============================================================================
ALTER TABLE universal_link_edges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS universal_link_edges_manage ON universal_link_edges;
CREATE POLICY universal_link_edges_manage ON universal_link_edges FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- 021 Unified Comments & Visibility RLS
-- ============================================================================
ALTER TABLE unified_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE unified_comment_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS unified_comments_select ON unified_comments;
CREATE POLICY unified_comments_select ON unified_comments FOR SELECT TO authenticated, anon USING (
    CASE entity_type
        WHEN 'note' THEN
            EXISTS (SELECT 1 FROM trader_notes WHERE id = entity_id::uuid AND (is_public = true OR user_id = auth.uid()))
        WHEN 'strategy' THEN
            EXISTS (SELECT 1 FROM strategies WHERE id = entity_id::uuid AND (visibility = 'public' OR user_id = auth.uid()))
        WHEN 'journal' THEN
            EXISTS (SELECT 1 FROM journal_entries WHERE id = entity_id::uuid AND (is_public = true OR user_id = auth.uid()))
        WHEN 'post' THEN
            EXISTS (SELECT 1 FROM community_posts WHERE id = entity_id::uuid AND (is_public = true OR author_id = auth.uid()))
        ELSE false
    END
);

DROP POLICY IF EXISTS unified_comments_insert ON unified_comments;
CREATE POLICY unified_comments_insert ON unified_comments FOR INSERT TO authenticated WITH CHECK (
    auth.uid() = author_id AND (
        CASE entity_type
            WHEN 'note' THEN
                EXISTS (SELECT 1 FROM trader_notes WHERE id = entity_id::uuid AND (is_public = true OR user_id = auth.uid()))
            WHEN 'strategy' THEN
                EXISTS (SELECT 1 FROM strategies WHERE id = entity_id::uuid AND (visibility = 'public' OR user_id = auth.uid()))
            WHEN 'journal' THEN
                EXISTS (SELECT 1 FROM journal_entries WHERE id = entity_id::uuid AND (is_public = true OR user_id = auth.uid()))
            WHEN 'post' THEN
                EXISTS (SELECT 1 FROM community_posts WHERE id = entity_id::uuid AND (is_public = true OR author_id = auth.uid()))
            ELSE false
        END
    )
);

DROP POLICY IF EXISTS unified_comments_manage ON unified_comments;
CREATE POLICY unified_comments_manage ON unified_comments FOR ALL TO authenticated
    USING (auth.uid() = author_id)
    WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS unified_comment_likes_manage ON unified_comment_likes;
CREATE POLICY unified_comment_likes_manage ON unified_comment_likes FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- community_comment_likes
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.community_comment_likes (
    comment_id UUID NOT NULL REFERENCES public.community_comments(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    reaction TEXT NOT NULL DEFAULT '👍',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (comment_id, user_id)
);

ALTER TABLE public.community_comment_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read comment likes" ON public.community_comment_likes;
CREATE POLICY "Public read comment likes"
    ON public.community_comment_likes FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Users manage own comment likes" ON public.community_comment_likes;
CREATE POLICY "Users manage own comment likes"
    ON public.community_comment_likes FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);



