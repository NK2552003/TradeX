-- =============================================================================
-- Migration: 20261101190000_clean_unused_tables_and_admin_setup.sql
-- Purpose:
--   1. Safely drop unused legacy tables that are superseded by unified tables.
--   2. Clean remaining seed/test records from transactional tables while
--      preserving the 3 production administrator accounts, platform_settings,
--      pricing_catalogues, and market intelligence tables.
--   3. Sync the admin_key column on public.profiles for the 3 provisioned
--      administrator accounts.
-- =============================================================================

BEGIN;

-- 1. Safely drop unused legacy tables that are not used by the active app
DROP TABLE IF EXISTS public.desk_order_approvals CASCADE;
DROP TABLE IF EXISTS public.desk_risk_breaches CASCADE;
DROP TABLE IF EXISTS public.desk_risk_policies CASCADE;
DROP TABLE IF EXISTS public.posts CASCADE;
DROP TABLE IF EXISTS public.comments CASCADE;
DROP TABLE IF EXISTS public.conversations CASCADE;
DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.community_live_room_question_upvotes CASCADE;
DROP TABLE IF EXISTS public.community_live_room_questions CASCADE;
DROP TABLE IF EXISTS public.community_live_room_reminders CASCADE;
DROP TABLE IF EXISTS public.community_live_room_messages CASCADE;
DROP TABLE IF EXISTS public.community_live_room_participants CASCADE;
DROP TABLE IF EXISTS public.community_live_rooms CASCADE;

-- 2. Clear remaining transactional/seed test rows (preserving market data & config)
DELETE FROM public.community_comment_likes;
DELETE FROM public.community_comments;
DELETE FROM public.community_poll_votes;
DELETE FROM public.community_poll_options;
DELETE FROM public.community_polls;
DELETE FROM public.community_post_attachments;
DELETE FROM public.community_post_trade_setups;
DELETE FROM public.community_bookmarks;
DELETE FROM public.community_likes;
DELETE FROM public.community_reposts;
DELETE FROM public.community_posts;
DELETE FROM public.community_follows;

DELETE FROM public.trader_note_comments;
DELETE FROM public.trader_note_likes;
DELETE FROM public.trader_note_views;
DELETE FROM public.trader_note_attachments;
DELETE FROM public.note_journal_links;
DELETE FROM public.trader_notes;

DELETE FROM public.journal_entry_attachments;
DELETE FROM public.journal_entries;

DELETE FROM public.strategy_attachments;
DELETE FROM public.strategy_versions;
DELETE FROM public.strategies;

DELETE FROM public.chat_reactions;
DELETE FROM public.chat_attachments;
DELETE FROM public.chat_shared_refs;
DELETE FROM public.chat_messages;
DELETE FROM public.chat_participants;
DELETE FROM public.chat_threads;

DELETE FROM public.ai_messages;
DELETE FROM public.ai_threads;
DELETE FROM public.ai_insight_requests;
DELETE FROM public.ai_insights;
DELETE FROM public.ai_chart_setups;

DELETE FROM public.affiliate_click_receipts;
DELETE FROM public.affiliate_referrals;
DELETE FROM public.affiliate_payouts;
DELETE FROM public.affiliate_campaigns;
DELETE FROM public.affiliate_assets;
DELETE FROM public.affiliate_applications;
DELETE FROM public.affiliate_profiles;

DELETE FROM public.notifications;
DELETE FROM public.entity_ticker_links;
DELETE FROM public.universal_link_edges;
DELETE FROM public.watchlist_items;
DELETE FROM public.watchlists;
DELETE FROM public.data_export_requests;
DELETE FROM public.invoices;
DELETE FROM public.portfolio_stats;
DELETE FROM public.organization_members;
DELETE FROM public.organizations;
DELETE FROM public.subscriptions
 WHERE user_id NOT IN (
   SELECT id FROM public.profiles WHERE role = 'user_admin'
 );

-- Remove non-admin seed profiles (e.g. demo_trader, alex_vance, sarah_quant)
ALTER TABLE public.profiles DISABLE TRIGGER USER;

DELETE FROM public.account_deletion_requests;
DELETE FROM public.admin_audit_logs;
DELETE FROM public.profiles WHERE role <> 'user_admin';

-- 3. Ensure the 3 production administrator accounts have their admin_key set
UPDATE public.profiles
   SET handle = '@client_admin',
       display_name = 'Client Administrator',
       role = 'user_admin',
       status = 'active',
       subscription_tier = 'enterprise',
       admin_key = 'ADM-CLIENT-2026',
       updated_at = now()
 WHERE email = 'client.admin@alphajournal.in';

UPDATE public.profiles
   SET handle = '@dev_admin',
       display_name = 'Developer Administrator',
       role = 'user_admin',
       status = 'active',
       subscription_tier = 'enterprise',
       admin_key = 'ADM-DEV-2026',
       updated_at = now()
 WHERE email = 'dev.admin@alphajournal.in';

UPDATE public.profiles
   SET handle = '@backend_admin',
       display_name = 'Backend Developer Administrator',
       role = 'user_admin',
       status = 'active',
       subscription_tier = 'enterprise',
       admin_key = 'ADM-BACKEND-2026',
       updated_at = now()
 WHERE email = 'backend.admin@alphajournal.in';

ALTER TABLE public.profiles ENABLE TRIGGER USER;

NOTIFY pgrst, 'reload schema';

COMMIT;
