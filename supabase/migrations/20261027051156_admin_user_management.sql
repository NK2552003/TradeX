-- Administration uses the existing account, billing, writing, community and chat
-- records. This migration also supports projects which never installed 027.
BEGIN;

CREATE SCHEMA IF NOT EXISTS tradex_private;
REVOKE ALL ON SCHEMA tradex_private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA tradex_private TO authenticated, service_role;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS admin_controls jsonb NOT NULL DEFAULT '{}';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_active_at timestamptz;

CREATE TABLE IF NOT EXISTS public.platform_settings (
  id text PRIMARY KEY CHECK (id = 'default'),
  features jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(features) = 'object'),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);
INSERT INTO public.platform_settings(id) VALUES ('default') ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  actor_handle text NOT NULL,
  actor_role text NOT NULL DEFAULT 'system',
  category text NOT NULL,
  action text NOT NULL,
  severity text NOT NULL DEFAULT 'info',
  target_type text NOT NULL,
  target_id text NOT NULL,
  target_label text NOT NULL,
  ip_address text NOT NULL DEFAULT '',
  sha256_hash text NOT NULL DEFAULT '',
  metadata jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.admin_audit_logs DROP CONSTRAINT IF EXISTS admin_audit_logs_category_check;
ALTER TABLE public.admin_audit_logs ALTER COLUMN ip_address SET DEFAULT '';
ALTER TABLE public.admin_audit_logs ALTER COLUMN sha256_hash SET DEFAULT '';
-- Deliberately not a foreign key: the history survives account deletion.
ALTER TABLE public.admin_audit_logs ADD COLUMN IF NOT EXISTS subject_user_id uuid;
CREATE INDEX IF NOT EXISTS admin_audit_subject_created ON public.admin_audit_logs(subject_user_id, created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS admin_audit_actor_created ON public.admin_audit_logs(actor_id, created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS admin_audit_created_id ON public.admin_audit_logs(created_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  user_handle text NOT NULL,
  user_email text,
  user_role text NOT NULL DEFAULT 'customer',
  reason text NOT NULL,
  feedback text,
  data_purge_condition text NOT NULL DEFAULT 'immediate_purge',
  purge_journals_notes_strategies boolean NOT NULL DEFAULT true,
  purge_community_messages boolean NOT NULL DEFAULT true,
  purge_ai_workspace boolean NOT NULL DEFAULT true,
  purge_affiliate_campaigns boolean NOT NULL DEFAULT true,
  export_requested_before_delete boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'pending',
  scheduled_purge_at timestamptz NOT NULL DEFAULT now(),
  data_purged_at timestamptz,
  purged_tables_summary jsonb NOT NULL DEFAULT '{}',
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  review_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.account_deletion_requests ADD COLUMN IF NOT EXISTS subject_user_id uuid;
ALTER TABLE public.account_deletion_requests ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE public.account_deletion_requests DROP CONSTRAINT IF EXISTS account_deletion_requests_user_id_fkey;
ALTER TABLE public.account_deletion_requests ADD CONSTRAINT account_deletion_requests_user_id_fkey
  FOREIGN KEY(user_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS admin_deletion_subject_status ON public.account_deletion_requests(subject_user_id, status);

ALTER TABLE public.trader_notes ADD COLUMN IF NOT EXISTS admin_hidden boolean NOT NULL DEFAULT false;
ALTER TABLE public.journal_entries ADD COLUMN IF NOT EXISTS admin_hidden boolean NOT NULL DEFAULT false;
ALTER TABLE public.strategies ADD COLUMN IF NOT EXISTS admin_hidden boolean NOT NULL DEFAULT false;
ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS admin_hidden boolean NOT NULL DEFAULT false;
ALTER TABLE public.ai_threads ADD COLUMN IF NOT EXISTS admin_hidden boolean NOT NULL DEFAULT false;
ALTER TABLE public.ai_insight_requests ADD COLUMN IF NOT EXISTS thread_id uuid REFERENCES public.ai_threads(id) ON DELETE SET NULL;
ALTER TABLE public.ai_insight_requests ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'recorded';
ALTER TABLE public.ai_insight_requests ADD COLUMN IF NOT EXISTS prompt_text text;
ALTER TABLE public.ai_insight_requests ADD COLUMN IF NOT EXISTS response_text text;
ALTER TABLE public.ai_insight_requests ADD COLUMN IF NOT EXISTS error text;
ALTER TABLE public.ai_insight_requests ADD COLUMN IF NOT EXISTS provider text;
ALTER TABLE public.ai_insight_requests ADD COLUMN IF NOT EXISTS model text;
ALTER TABLE public.ai_insight_requests ADD COLUMN IF NOT EXISTS input_tokens integer;
ALTER TABLE public.ai_insight_requests ADD COLUMN IF NOT EXISTS output_tokens integer;
ALTER TABLE public.ai_insight_requests ADD COLUMN IF NOT EXISTS completed_at timestamptz;
REVOKE INSERT,UPDATE,DELETE ON public.ai_insight_requests FROM authenticated;
GRANT INSERT(user_id,kind,ticker) ON public.ai_insight_requests TO authenticated;

CREATE INDEX IF NOT EXISTS admin_profiles_created ON public.profiles(created_at DESC, id);
CREATE INDEX IF NOT EXISTS admin_profiles_status ON public.profiles(status, role);
CREATE INDEX IF NOT EXISTS admin_posts_author_created ON public.community_posts(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS admin_chat_sender_created ON public.chat_messages(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS admin_ai_user_requested ON public.ai_insight_requests(user_id, requested_at DESC);

CREATE OR REPLACE FUNCTION tradex_private.account_active(p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT p_user IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_user AND status = 'active'
  );
$$;
CREATE OR REPLACE FUNCTION tradex_private.is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'user_admin' AND status = 'active'
  );
$$;
CREATE OR REPLACE FUNCTION public.is_user_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT tradex_private.is_admin();
$$;
CREATE OR REPLACE FUNCTION public.is_admin_caller() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT tradex_private.is_admin();
$$;

CREATE OR REPLACE FUNCTION tradex_private.require_admin() RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT tradex_private.is_admin() THEN
    RAISE EXCEPTION 'An active administrator account is required' USING ERRCODE = '42501';
  END IF;
  RETURN auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.feature_enabled(p_feature text, p_user uuid DEFAULT auth.uid()) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT coalesce((
    SELECT p.status = 'active'
      AND coalesce((p.admin_controls->'features'->>p_feature)::boolean, true)
      AND coalesce((s.features->>p_feature)::boolean, true)
      AND (p_feature <> 'affiliate' OR EXISTS (
        SELECT 1 FROM public.affiliate_profiles a WHERE a.id=p.id AND a.status='active'
      ))
    FROM public.profiles p CROSS JOIN public.platform_settings s
    WHERE p.id = p_user AND s.id = 'default'
      AND (p_user = auth.uid() OR tradex_private.is_admin())
  ), false);
$$;

-- Complete partially installed affiliate workspaces. Reuse the existing
-- profile, referral and payout ledgers; add only the missing campaign assets.
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS custom_slug text UNIQUE;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS minimum_payout_threshold numeric NOT NULL DEFAULT 100;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS auto_payout_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE public.affiliate_profiles ALTER COLUMN auto_payout_enabled SET DEFAULT false;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'INR' CHECK (currency ~ '^[A-Z]{3}$');
ALTER TABLE public.affiliate_profiles DROP CONSTRAINT IF EXISTS affiliate_profiles_payout_method_check;
ALTER TABLE public.affiliate_profiles ADD CONSTRAINT affiliate_profiles_payout_method_check CHECK (payout_method IN ('bank_transfer','bank_wire','bank_neft','bank_imps','bank_rtgs','paypal','stripe','razorpay','crypto','upi'));
ALTER TABLE public.affiliate_profiles DROP CONSTRAINT IF EXISTS affiliate_workspace_slug_check;
ALTER TABLE public.affiliate_profiles ADD CONSTRAINT affiliate_workspace_slug_check CHECK (custom_slug IS NULL OR custom_slug ~ '^[a-z0-9][a-z0-9_-]{2,39}$') NOT VALID;
ALTER TABLE public.affiliate_profiles DROP CONSTRAINT IF EXISTS affiliate_workspace_threshold_check;
ALTER TABLE public.affiliate_profiles ADD CONSTRAINT affiliate_workspace_threshold_check CHECK (minimum_payout_threshold >= 100) NOT VALID;

CREATE TABLE IF NOT EXISTS public.affiliate_campaigns (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 affiliate_id uuid NOT NULL REFERENCES public.affiliate_profiles(id) ON DELETE CASCADE,
 name text NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80),
 slug text NOT NULL CHECK (slug ~ '^[a-z0-9][a-z0-9-]{2,39}$'),
 channel text NOT NULL CHECK (channel IN ('youtube','newsletter','instagram','website','other')),
 status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused')),
 clicks bigint NOT NULL DEFAULT 0 CHECK (clicks >= 0),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(affiliate_id,slug)
);
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS channel text NOT NULL DEFAULT 'direct';
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS campaign_id uuid REFERENCES public.affiliate_campaigns(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS affiliate_referrals_campaign_idx ON public.affiliate_referrals(campaign_id);
CREATE INDEX IF NOT EXISTS affiliate_referrals_date_idx ON public.affiliate_referrals(affiliate_id,created_at DESC);
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS payout_destination jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS balance_reserved boolean NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS affiliate_payouts_date_idx ON public.affiliate_payouts(affiliate_id,created_at DESC);
CREATE TABLE IF NOT EXISTS public.affiliate_assets (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 title text NOT NULL,
 format text NOT NULL,
 body text NOT NULL,
 published boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.affiliate_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_assets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.affiliate_profiles,public.affiliate_referrals,public.affiliate_payouts,public.affiliate_campaigns,public.affiliate_assets FROM anon,authenticated;
GRANT SELECT ON public.affiliate_profiles,public.affiliate_referrals,public.affiliate_payouts,public.affiliate_campaigns,public.affiliate_assets TO authenticated;
GRANT UPDATE(custom_slug,payout_method,payout_details,minimum_payout_threshold,auto_payout_enabled) ON public.affiliate_profiles TO authenticated;
GRANT INSERT(affiliate_id,name,slug,channel),UPDATE(name,status) ON public.affiliate_campaigns TO authenticated;
GRANT ALL ON public.affiliate_profiles,public.affiliate_referrals,public.affiliate_payouts,public.affiliate_campaigns,public.affiliate_assets TO service_role;
DROP POLICY IF EXISTS affiliate_workspace_profile_read ON public.affiliate_profiles;
CREATE POLICY affiliate_workspace_profile_read ON public.affiliate_profiles FOR SELECT TO authenticated USING (id=(SELECT auth.uid()));
DROP POLICY IF EXISTS affiliate_workspace_profile_update ON public.affiliate_profiles;
CREATE POLICY affiliate_workspace_profile_update ON public.affiliate_profiles FOR UPDATE TO authenticated USING (id=(SELECT auth.uid()) AND status='active') WITH CHECK (id=(SELECT auth.uid()) AND status='active');
DROP POLICY IF EXISTS affiliate_workspace_referral_read ON public.affiliate_referrals;
CREATE POLICY affiliate_workspace_referral_read ON public.affiliate_referrals FOR SELECT TO authenticated USING (affiliate_id=(SELECT auth.uid()));
DROP POLICY IF EXISTS affiliate_workspace_payout_read ON public.affiliate_payouts;
CREATE POLICY affiliate_workspace_payout_read ON public.affiliate_payouts FOR SELECT TO authenticated USING (affiliate_id=(SELECT auth.uid()));
DROP POLICY IF EXISTS affiliate_workspace_campaign_read ON public.affiliate_campaigns;
CREATE POLICY affiliate_workspace_campaign_read ON public.affiliate_campaigns FOR SELECT TO authenticated USING (affiliate_id=(SELECT auth.uid()));
DROP POLICY IF EXISTS affiliate_workspace_campaign_insert ON public.affiliate_campaigns;
CREATE POLICY affiliate_workspace_campaign_insert ON public.affiliate_campaigns FOR INSERT TO authenticated WITH CHECK (affiliate_id=(SELECT auth.uid()) AND EXISTS(SELECT 1 FROM public.affiliate_profiles WHERE id=(SELECT auth.uid()) AND status='active'));
DROP POLICY IF EXISTS affiliate_workspace_campaign_update ON public.affiliate_campaigns;
CREATE POLICY affiliate_workspace_campaign_update ON public.affiliate_campaigns FOR UPDATE TO authenticated USING (affiliate_id=(SELECT auth.uid()) AND EXISTS(SELECT 1 FROM public.affiliate_profiles WHERE id=(SELECT auth.uid()) AND status='active')) WITH CHECK (affiliate_id=(SELECT auth.uid()));
DROP POLICY IF EXISTS affiliate_workspace_asset_read ON public.affiliate_assets;
CREATE POLICY affiliate_workspace_asset_read ON public.affiliate_assets FOR SELECT TO authenticated USING (published AND EXISTS(SELECT 1 FROM public.affiliate_profiles WHERE id=(SELECT auth.uid())));

CREATE OR REPLACE FUNCTION public.affiliate_workspace() RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT jsonb_build_object(
  'profile', (SELECT to_jsonb(p) FROM public.affiliate_profiles p WHERE p.id=(SELECT auth.uid())),
  'campaigns',COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.created_at DESC) FROM public.affiliate_campaigns c WHERE c.affiliate_id=(SELECT auth.uid())),'[]'::jsonb),
  'referrals',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',r.id,'referral_code',r.referral_code,'status',r.status,'bonus_awarded',r.bonus_awarded,'channel',r.channel,'campaign_id',r.campaign_id,'created_at',r.created_at) ORDER BY r.created_at DESC) FROM public.affiliate_referrals r WHERE r.affiliate_id=(SELECT auth.uid())),'[]'::jsonb),
  'payouts',COALESCE((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC) FROM public.affiliate_payouts p WHERE p.affiliate_id=(SELECT auth.uid())),'[]'::jsonb),
  'assets',COALESCE((SELECT jsonb_agg(to_jsonb(a) ORDER BY a.created_at) FROM public.affiliate_assets a WHERE a.published),'[]'::jsonb)
 );
$$;
REVOKE ALL ON FUNCTION public.affiliate_workspace() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.affiliate_workspace() TO authenticated;

-- Reserve under a row lock. The browser cannot write balances or payment status.
CREATE OR REPLACE FUNCTION public.request_affiliate_payout(p_amount numeric) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.affiliate_profiles; result uuid;
BEGIN
 IF NOT tradex_private.feature_enabled('affiliate') THEN RAISE EXCEPTION 'Affiliate access is unavailable' USING ERRCODE='42501'; END IF;
 SELECT * INTO p FROM public.affiliate_profiles WHERE id=auth.uid() FOR UPDATE;
 IF NOT FOUND OR p.status<>'active' THEN RAISE EXCEPTION 'Active affiliate required'; END IF;
 IF p_amount IS NULL OR p_amount::text IN ('NaN','Infinity','-Infinity') OR p_amount<>round(p_amount,2) OR p_amount<greatest(100,p.minimum_payout_threshold) OR p_amount>p.unpaid_balance THEN RAISE EXCEPTION 'Invalid payout amount'; END IF;
 IF p.payout_method IS NULL OR COALESCE(nullif(trim(p.payout_details->>'payout_account'),''),nullif(trim(p.payout_details->>'payout_vpa'),''),nullif(trim(p.payout_details->>'account_number'),''),nullif(trim(p.payout_details->>'upi_id'),'')) IS NULL THEN RAISE EXCEPTION 'Save a payout destination first'; END IF;
 IF EXISTS(SELECT 1 FROM public.affiliate_payouts WHERE affiliate_id=p.id AND status IN ('pending','processing')) THEN RAISE EXCEPTION 'A payout is already in progress'; END IF;
 UPDATE public.affiliate_profiles SET unpaid_balance=unpaid_balance-p_amount,updated_at=now() WHERE id=p.id;
 INSERT INTO public.affiliate_payouts(affiliate_id,amount,currency,payout_method,payout_destination,balance_reserved) VALUES(p.id,p_amount,p.currency,p.payout_method,p.payout_details,true) RETURNING id INTO result;
 RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.request_affiliate_payout(numeric) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_affiliate_payout(numeric) TO authenticated;

-- Provider callbacks use service_role. Terminal state changes are immutable.
CREATE OR REPLACE FUNCTION public.affiliate_settle_payout() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.affiliate_id<>OLD.affiliate_id OR NEW.amount<>OLD.amount OR NEW.currency<>OLD.currency OR NEW.payout_destination IS DISTINCT FROM OLD.payout_destination OR NEW.balance_reserved IS DISTINCT FROM OLD.balance_reserved OR NEW.payout_method IS DISTINCT FROM OLD.payout_method THEN RAISE EXCEPTION 'Payment identity is immutable'; END IF;
 IF NEW.status=OLD.status THEN RETURN NEW; END IF;
 IF NOT OLD.balance_reserved THEN RAISE EXCEPTION 'Legacy payout requires balance reconciliation'; END IF;
 IF OLD.status NOT IN ('pending','processing') THEN RAISE EXCEPTION 'Payment already settled'; END IF;
 IF NEW.status NOT IN ('processing','paid','failed','cancelled') OR (OLD.status='processing' AND NEW.status='pending') THEN RAISE EXCEPTION 'Invalid payout transition'; END IF;
 IF NEW.status IN ('failed','cancelled') THEN
  UPDATE public.affiliate_profiles SET unpaid_balance=unpaid_balance+OLD.amount,updated_at=now() WHERE id=OLD.affiliate_id;
 ELSIF NEW.status='paid' THEN
  IF nullif(trim(NEW.transaction_reference),'') IS NULL THEN RAISE EXCEPTION 'Settlement reference required'; END IF;
  UPDATE public.affiliate_profiles SET paid_earnings=paid_earnings+OLD.amount,updated_at=now() WHERE id=OLD.affiliate_id;
 END IF;
 IF NEW.status IN ('paid','failed','cancelled') THEN NEW.processed_at=now(); END IF;
 NEW.updated_at=now(); RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.affiliate_settle_payout() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS affiliate_settle_payout ON public.affiliate_payouts;
CREATE TRIGGER affiliate_settle_payout BEFORE UPDATE ON public.affiliate_payouts FOR EACH ROW EXECUTE FUNCTION public.affiliate_settle_payout();

-- Billing webhook only: one qualifying award per pending referral, serialized on its row.
CREATE OR REPLACE FUNCTION public.record_affiliate_conversion(p_referral_id uuid,p_commission numeric) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE r public.affiliate_referrals;
BEGIN
 IF p_commission IS NULL OR p_commission::text IN ('NaN','Infinity','-Infinity') OR p_commission<0 OR p_commission<>round(p_commission,2) THEN RAISE EXCEPTION 'Invalid commission'; END IF;
 SELECT * INTO r FROM public.affiliate_referrals WHERE id=p_referral_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Referral not found'; END IF;
 IF r.status='converted' THEN RETURN; END IF;
 IF r.status<>'pending' THEN RAISE EXCEPTION 'Referral cannot qualify'; END IF;
 UPDATE public.affiliate_profiles SET unpaid_balance=unpaid_balance+p_commission,total_earnings=total_earnings+p_commission,active_referrals=active_referrals+1,updated_at=now() WHERE id=r.affiliate_id AND status='active';
 IF NOT FOUND THEN RAISE EXCEPTION 'Affiliate is not active'; END IF;
 UPDATE public.affiliate_referrals SET status='converted',bonus_awarded=p_commission,updated_at=now() WHERE id=r.id;
END;
$$;
REVOKE ALL ON FUNCTION public.record_affiliate_conversion(uuid,numeric) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_affiliate_conversion(uuid,numeric) TO service_role;

-- The landing server deduplicates visits and calls this with its service credential.
CREATE TABLE IF NOT EXISTS public.affiliate_click_receipts (
 event_key text PRIMARY KEY CHECK(length(event_key)=64),
 campaign_id uuid NOT NULL REFERENCES public.affiliate_campaigns(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS affiliate_click_receipts_campaign_idx ON public.affiliate_click_receipts(campaign_id);
ALTER TABLE public.affiliate_click_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.affiliate_click_receipts FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.affiliate_click_receipts TO service_role;
CREATE OR REPLACE FUNCTION public.record_affiliate_click(p_campaign_id uuid,p_event_key text) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
BEGIN
 INSERT INTO public.affiliate_click_receipts(event_key,campaign_id)
 SELECT p_event_key,c.id FROM public.affiliate_campaigns c JOIN public.affiliate_profiles p ON p.id=c.affiliate_id
 WHERE c.id=p_campaign_id AND c.status='active' AND p.status='active'
 ON CONFLICT(event_key) DO NOTHING;
 IF FOUND THEN UPDATE public.affiliate_campaigns SET clicks=clicks+1 WHERE id=p_campaign_id; END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.record_affiliate_click(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_affiliate_click(uuid,text) TO service_role;



CREATE OR REPLACE FUNCTION tradex_private.effective_tier(p_user uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT coalesce(
    (SELECT p.admin_controls->'subscription_override'->>'tier' FROM public.profiles p
      WHERE p.id = p_user
        AND p.admin_controls->'subscription_override'->>'tier' IN ('free','premium','enterprise')
        AND (p.admin_controls->'subscription_override'->>'expires_at')::timestamptz > now()),
    (SELECT s.tier FROM public.subscriptions s WHERE s.user_id = p_user
      AND s.status IN ('active','trialing','canceled') AND (s.expires_at IS NULL OR s.expires_at > now())),
    'free'
  );
$$;

CREATE OR REPLACE FUNCTION tradex_private.write_audit(
  p_subject uuid, p_category text, p_action text, p_type text, p_id text,
  p_label text, p_metadata jsonb DEFAULT '{}'
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor public.profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_actor FROM public.profiles WHERE id = auth.uid();
  INSERT INTO public.admin_audit_logs(actor_id, actor_handle, actor_role, subject_user_id,
    category, action, target_type, target_id, target_label, metadata)
  VALUES(v_actor.id, coalesce(v_actor.handle::text, 'System'), coalesce(v_actor.role, 'system'),
    p_subject, p_category, p_action, p_type, p_id, left(p_label, 200), p_metadata);
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.guard_profile() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND (NEW.role IS DISTINCT FROM OLD.role OR NEW.status IS DISTINCT FROM OLD.status)
    AND EXISTS (SELECT 1 FROM public.account_deletion_requests d
      WHERE d.user_id=OLD.id AND d.status IN ('processing','failed')) THEN
    RAISE EXCEPTION 'Finish the deletion job before changing account access' USING ERRCODE='42501';
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.role='user_admin' AND auth.uid()=OLD.id
    AND (NEW.role<>OLD.role OR NEW.status<>OLD.status) THEN
    RAISE EXCEPTION 'Administrators cannot remove their own access' USING ERRCODE='42501';
  END IF;
  IF TG_OP = 'UPDATE' AND auth.uid() IS NOT NULL AND NOT tradex_private.is_admin()
    AND (NEW.status IS DISTINCT FROM OLD.status OR NEW.role IS DISTINCT FROM OLD.role
      OR NEW.admin_controls IS DISTINCT FROM OLD.admin_controls
      OR NEW.id IS DISTINCT FROM OLD.id OR NEW.created_at IS DISTINCT FROM OLD.created_at
      OR NEW.subscription_tier IS DISTINCT FROM OLD.subscription_tier) THEN
    IF NEW.id=auth.uid() AND NEW.status='suspended'
      AND (to_jsonb(NEW)-ARRAY['status','updated_at'])=(to_jsonb(OLD)-ARRAY['status','updated_at'])
      AND EXISTS (SELECT 1 FROM public.account_deletion_requests d WHERE d.user_id=NEW.id
        AND d.id::text=current_setting('tradex.self_deletion_request',true)
        AND d.status IN ('pending','grace_period')) THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Only administrators can change account access' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS admin_guard_profile ON public.profiles;
CREATE TRIGGER admin_guard_profile BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION tradex_private.guard_profile();

-- Restrictive policies compose with existing owner/public policies. A stale JWT
-- cannot continue reading private tables after the account has been suspended.
DO $$ DECLARE t record; BEGIN
  FOR t IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS admin_active_account ON public.%I', t.relname);
    EXECUTE format('CREATE POLICY admin_active_account ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING ((SELECT tradex_private.account_active(auth.uid()))) WITH CHECK ((SELECT tradex_private.account_active(auth.uid())))', t.relname);
  END LOOP;
END $$;

DROP POLICY IF EXISTS admin_active_account ON storage.objects;
CREATE POLICY admin_active_account ON storage.objects AS RESTRICTIVE FOR ALL TO authenticated
  USING ((SELECT tradex_private.account_active(auth.uid())))
  WITH CHECK ((SELECT tradex_private.account_active(auth.uid())));

ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.platform_settings, public.admin_audit_logs, public.account_deletion_requests FROM anon, authenticated;
GRANT SELECT ON public.platform_settings, public.admin_audit_logs, public.account_deletion_requests TO authenticated;
GRANT ALL ON public.platform_settings, public.admin_audit_logs, public.account_deletion_requests TO service_role;
DO $$ DECLARE t text; p record; BEGIN
  FOREACH t IN ARRAY ARRAY['platform_settings','admin_audit_logs','account_deletion_requests'] LOOP
    FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=t LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', p.policyname, t);
    END LOOP;
    EXECUTE format('CREATE POLICY admin_only_read ON public.%I FOR SELECT TO authenticated USING ((SELECT tradex_private.is_admin()))', t);
  END LOOP;
END $$;

-- All client-facing mutations are introduced below as checked, audited RPCs.

-- Customer requests enter the same durable queue the administrator reviews.
-- Only the trusted deletion worker removes Auth accounts and Storage objects.
CREATE OR REPLACE FUNCTION public.request_account_deletion_with_conditions(
  p_reason text,p_feedback text DEFAULT NULL,p_data_purge_condition text DEFAULT 'immediate_purge',
  p_purge_writing boolean DEFAULT true,p_purge_social boolean DEFAULT true,p_purge_ai boolean DEFAULT true,
  p_purge_affiliate boolean DEFAULT true,p_export_before_delete boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.profiles%ROWTYPE; r public.account_deletion_requests%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
  SELECT * INTO p FROM public.profiles WHERE id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR p.role='user_admin' THEN
    RAISE EXCEPTION 'Administrator accounts must be demoted by another administrator before deletion' USING ERRCODE='42501';
  END IF;
  SELECT * INTO r FROM public.account_deletion_requests WHERE user_id=p.id
    AND status IN ('pending','grace_period','processing','failed') ORDER BY created_at DESC LIMIT 1;
  IF FOUND THEN RETURN to_jsonb(r); END IF;
  IF p.status<>'active' THEN RAISE EXCEPTION 'Contact support about this account' USING ERRCODE='42501'; END IF;
  IF p_data_purge_condition IS NULL OR p_data_purge_condition NOT IN ('immediate_purge','after_30_day_grace','purge_personal_keep_tax_ledger')
    OR p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 3 AND 2000 OR length(p_feedback)>4000 THEN
    RAISE EXCEPTION 'Choose a valid deletion condition and provide a reason' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.account_deletion_requests(user_id,subject_user_id,user_handle,user_email,user_role,
    reason,feedback,data_purge_condition,purge_journals_notes_strategies,purge_community_messages,
    purge_ai_workspace,purge_affiliate_campaigns,export_requested_before_delete,status,scheduled_purge_at)
  VALUES(p.id,p.id,p.handle::text,p.email::text,p.role,trim(p_reason),p_feedback,p_data_purge_condition,
    p_purge_writing,p_purge_social,p_purge_ai,p_purge_affiliate,p_export_before_delete,
    CASE WHEN p_data_purge_condition='after_30_day_grace' THEN 'grace_period' ELSE 'pending' END,
    CASE WHEN p_data_purge_condition='after_30_day_grace' THEN now()+interval '30 days' ELSE now() END)
    RETURNING * INTO r;
  PERFORM set_config('tradex.self_deletion_request',r.id::text,true);
  UPDATE public.profiles SET status='suspended',updated_at=now() WHERE id=p.id;
  PERFORM set_config('tradex.self_deletion_request','',true);
  RETURN to_jsonb(r);
END;
$$;
REVOKE ALL ON FUNCTION public.request_account_deletion_with_conditions(text,text,text,boolean,boolean,boolean,boolean,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.request_account_deletion_with_conditions(text,text,text,boolean,boolean,boolean,boolean,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION tradex_private.guard_feature_write() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_new jsonb; v_old jsonb; v_limit integer; v_count integer;
BEGIN
  v_new := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
  v_old := CASE WHEN TG_OP = 'INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END;
  IF auth.uid() IS NULL OR tradex_private.is_admin() THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;
  IF NOT tradex_private.account_active(auth.uid()) THEN
    RAISE EXCEPTION 'Account access is suspended' USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' AND EXISTS (
    SELECT 1 FROM unnest(ARRAY['user_id','author_id','sender_id','created_by','created_at','requested_at']) k
    WHERE v_new ? k AND v_new->k IS DISTINCT FROM v_old->k
  ) THEN
    RAISE EXCEPTION 'Record ownership and creation time cannot be changed' USING ERRCODE='42501';
  END IF;
  IF TG_OP='INSERT' THEN
    IF v_new ? 'created_at' THEN NEW := jsonb_populate_record(NEW,jsonb_build_object('created_at',now())); END IF;
    IF v_new ? 'requested_at' THEN NEW := jsonb_populate_record(NEW,jsonb_build_object('requested_at',now())); END IF;
  END IF;
  IF TG_OP = 'UPDATE' AND (v_new->'admin_hidden') IS DISTINCT FROM (v_old->'admin_hidden') THEN
    RAISE EXCEPTION 'Only administrators can restore moderated records' USING ERRCODE = '42501';
  END IF;
  IF TG_OP = 'UPDATE' AND TG_TABLE_NAME IN ('community_posts','community_comments','community_poll_options') AND
    (v_new - ARRAY['views_count','likes_count','comments_count','reposts_count','bookmarks_count','votes_count','updated_at']) =
    (v_old - ARRAY['views_count','likes_count','comments_count','reposts_count','bookmarks_count','votes_count','updated_at']) THEN
    RETURN NEW;
  END IF;
  IF TG_OP='UPDATE' AND TG_TABLE_NAME='chat_threads' AND v_new->'created_by' IS DISTINCT FROM v_old->'created_by' THEN
    RAISE EXCEPTION 'Conversation ownership cannot be changed' USING ERRCODE='42501';
  END IF;
  IF NOT tradex_private.feature_enabled(TG_ARGV[0]) THEN
    RAISE EXCEPTION 'Your account does not currently have % access. Contact support.', TG_ARGV[0] USING ERRCODE = '42501';
  END IF;
  IF coalesce((v_old->>'admin_hidden')::boolean, false) THEN
    RAISE EXCEPTION 'This record is restricted by an administrator' USING ERRCODE = '42501';
  END IF;
  IF TG_TABLE_NAME = 'community_posts' AND TG_OP = 'INSERT' THEN
    PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text), hashtext('posts_per_day'));
    SELECT (admin_controls->'limits'->>'posts_per_day')::integer INTO v_limit
      FROM public.profiles WHERE id = auth.uid();
    SELECT count(*) INTO v_count FROM public.community_posts
      WHERE author_id = auth.uid() AND created_at >= date_trunc('day', now());
    IF v_limit IS NOT NULL AND v_count >= v_limit THEN
      RAISE EXCEPTION 'Daily post limit reached (% of %)', v_count, v_limit USING ERRCODE = 'P0001';
    END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.audit_record_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE j jsonb; previous jsonb; owner_id uuid; keys jsonb;
BEGIN
  j := CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
  previous := CASE WHEN TG_OP='INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END;
  SELECT coalesce(jsonb_agg(k), '[]') INTO keys FROM jsonb_object_keys(j) k
    WHERE j->k IS DISTINCT FROM previous->k
      AND k <> ALL(ARRAY['updated_at','last_active_at','views_count','likes_count',
        'comments_count','reposts_count','bookmarks_count','last_message_preview','last_message_at']);
  IF TG_OP='UPDATE' AND keys = '[]'::jsonb THEN RETURN NEW; END IF;
  owner_id := nullif(coalesce(j->>TG_ARGV[0], j->>'user_id', j->>'author_id', j->>'sender_id'), '')::uuid;
  IF TG_TABLE_NAME='ai_messages' THEN
    SELECT user_id INTO owner_id FROM public.ai_threads WHERE id=(j->>'thread_id')::uuid;
  END IF;
  PERFORM tradex_private.write_audit(owner_id, TG_ARGV[1], lower(TG_OP), TG_TABLE_NAME,
    coalesce(j->>'id',j->>'user_id',j->>'thread_id','default'),
    coalesce(nullif(j->>'title',''),nullif(j->>'display_name',''),j->>'handle',TG_TABLE_NAME),
    jsonb_build_object('source','database','changed_fields',keys,
      'previous_status', previous->>'status','status',j->>'status',
      'previous_moderation',previous->>'moderation_status','moderation_status',j->>'moderation_status',
      'reason',nullif(current_setting('tradex.admin_reason',true),''),
      'hidden',j->'admin_hidden'));
  RETURN NULL;
END;
$$;

DO $$ DECLARE entry text[]; BEGIN
  FOREACH entry SLICE 1 IN ARRAY ARRAY[
    ['trader_notes','notes','user_id'],['journal_entries','journal','user_id'],
    ['strategies','strategies','user_id'],['community_posts','posts','author_id'],
    ['community_comments','comments','author_id'],['chat_messages','messages','sender_id'],
    ['ai_threads','ai','user_id'],['ai_messages','ai','user_id'],
    ['ai_insight_requests','ai','user_id'],['affiliate_campaigns','affiliate','affiliate_id']
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS admin_feature_guard ON public.%I',entry[1]);
    EXECUTE format('CREATE TRIGGER admin_feature_guard BEFORE INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION tradex_private.guard_feature_write(%L)',entry[1],entry[2]);
    EXECUTE format('DROP TRIGGER IF EXISTS admin_activity_audit ON public.%I',entry[1]);
    EXECUTE format('CREATE TRIGGER admin_activity_audit AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION tradex_private.audit_record_change(%L,%L)',entry[1],entry[3],entry[2]);
  END LOOP;
  FOREACH entry SLICE 1 IN ARRAY ARRAY[
    ['profiles','users','id'],['subscriptions','subscriptions','user_id'],
    ['affiliate_applications','affiliate','user_id'],['affiliate_profiles','affiliate','id'],
    ['affiliate_payouts','affiliate','affiliate_id'],['account_deletion_requests','users','user_id'],
    ['community_likes','posts','user_id'],['community_bookmarks','posts','user_id'],
    ['community_reposts','posts','user_id'],['community_comment_likes','comments','user_id'],
    ['community_poll_votes','posts','user_id'],['chat_threads','messages','created_by'],
    ['chat_participants','messages','user_id']
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS admin_activity_audit ON public.%I',entry[1]);
    EXECUTE format('CREATE TRIGGER admin_activity_audit AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION tradex_private.audit_record_change(%L,%L)',entry[1],entry[3],entry[2]);
  END LOOP;
END $$;

-- A private lookup breaks the participant -> thread -> participant RLS cycle.
-- A caller cannot use it to probe membership of another account.
CREATE OR REPLACE FUNCTION tradex_private.chat_member(p_thread uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT tradex_private.account_active(auth.uid()) AND EXISTS(
    SELECT 1 FROM public.chat_participants WHERE thread_id=p_thread AND user_id=auth.uid()
  );
$$;
CREATE OR REPLACE FUNCTION tradex_private.chat_owner(p_thread uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT tradex_private.account_active(auth.uid()) AND EXISTS(
    SELECT 1 FROM public.chat_threads WHERE id=p_thread AND created_by=auth.uid()
  );
$$;
DO $$ DECLARE p record; BEGIN
  FOR p IN SELECT tablename,policyname FROM pg_policies WHERE schemaname='public'
    AND tablename IN ('chat_threads','chat_participants','chat_messages') LOOP
    EXECUTE format('DROP POLICY %I ON public.%I',p.policyname,p.tablename);
  END LOOP;
END $$;
CREATE POLICY chat_read ON public.chat_threads FOR SELECT TO authenticated
  USING (tradex_private.chat_member(id) OR tradex_private.chat_owner(id));
CREATE POLICY chat_create ON public.chat_threads FOR INSERT TO authenticated
  WITH CHECK (created_by=(SELECT auth.uid()) AND (SELECT tradex_private.feature_enabled('messages')));
CREATE POLICY chat_update ON public.chat_threads FOR UPDATE TO authenticated
  USING (tradex_private.chat_member(id) OR tradex_private.chat_owner(id))
  WITH CHECK (tradex_private.chat_member(id) OR tradex_private.chat_owner(id));
CREATE POLICY participants_read ON public.chat_participants FOR SELECT TO authenticated
  USING (tradex_private.chat_member(thread_id) OR tradex_private.chat_owner(thread_id));
CREATE POLICY participants_insert ON public.chat_participants FOR INSERT TO authenticated
  WITH CHECK (tradex_private.chat_owner(thread_id) AND (SELECT tradex_private.feature_enabled('messages')));
CREATE POLICY participants_update ON public.chat_participants FOR UPDATE TO authenticated
  USING (user_id=(SELECT auth.uid()) AND tradex_private.chat_member(thread_id))
  WITH CHECK (user_id=(SELECT auth.uid()) AND tradex_private.chat_member(thread_id));
CREATE POLICY participants_delete ON public.chat_participants FOR DELETE TO authenticated
  USING ((user_id=(SELECT auth.uid()) AND tradex_private.chat_member(thread_id)) OR tradex_private.chat_owner(thread_id));
CREATE POLICY messages_read ON public.chat_messages FOR SELECT TO authenticated
  USING (tradex_private.chat_member(thread_id) AND NOT admin_hidden);
CREATE POLICY messages_insert ON public.chat_messages FOR INSERT TO authenticated
  WITH CHECK (sender_id=(SELECT auth.uid()) AND tradex_private.chat_member(thread_id)
    AND (SELECT tradex_private.feature_enabled('messages')) AND NOT admin_hidden);
CREATE POLICY messages_update ON public.chat_messages FOR UPDATE TO authenticated
  USING (sender_id=(SELECT auth.uid()) AND tradex_private.chat_member(thread_id) AND NOT admin_hidden)
  WITH CHECK (sender_id=(SELECT auth.uid()) AND tradex_private.chat_member(thread_id) AND NOT admin_hidden);
CREATE POLICY messages_delete ON public.chat_messages FOR DELETE TO authenticated
  USING (sender_id=(SELECT auth.uid()) AND tradex_private.chat_member(thread_id) AND NOT admin_hidden);

CREATE OR REPLACE FUNCTION tradex_private.refresh_chat_preview() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE thread uuid := CASE WHEN TG_OP='DELETE' THEN OLD.thread_id ELSE NEW.thread_id END;
BEGIN
  UPDATE public.chat_threads t SET
    last_message_preview=coalesce((SELECT left(m.body,120) FROM public.chat_messages m
      WHERE m.thread_id=t.id AND NOT m.admin_hidden ORDER BY m.created_at DESC,m.id DESC LIMIT 1),''),
    last_message_at=(SELECT max(m.created_at) FROM public.chat_messages m WHERE m.thread_id=t.id AND NOT m.admin_hidden),
    updated_at=now()
  WHERE t.id=thread;
  RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS admin_refresh_chat_preview ON public.chat_messages;
CREATE TRIGGER admin_refresh_chat_preview AFTER INSERT OR UPDATE OR DELETE ON public.chat_messages
  FOR EACH ROW EXECUTE FUNCTION tradex_private.refresh_chat_preview();

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['trader_notes','journal_entries','strategies','ai_threads'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS admin_visible_record ON public.%I',t);
    EXECUTE format('CREATE POLICY admin_visible_record ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING (NOT admin_hidden OR (SELECT tradex_private.is_admin())) WITH CHECK (NOT admin_hidden OR (SELECT tradex_private.is_admin()))',t);
  END LOOP;
END $$;

-- One source of effective entitlements for the customer UI and insert triggers.
CREATE OR REPLACE FUNCTION public.get_customer_quota_usage(target_user_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE u uuid := coalesce(target_user_id,auth.uid()); t text; limits jsonb; overrides jsonb;
BEGIN
  IF auth.uid() IS NULL OR (u <> auth.uid() AND NOT tradex_private.is_admin()) THEN
    RAISE EXCEPTION 'Quota access denied' USING ERRCODE='42501';
  END IF;
  IF NOT tradex_private.account_active(auth.uid()) THEN
    RAISE EXCEPTION 'Account access is suspended' USING ERRCODE='42501';
  END IF;
  t := tradex_private.effective_tier(u);
  SELECT plan->'limits' INTO limits FROM public.pricing_catalogues c,
    jsonb_array_elements(c.catalogue->'plans') plan
    WHERE c.id='default' AND c.published AND plan->>'tier'=t LIMIT 1;
  IF limits IS NULL THEN RAISE EXCEPTION 'Published plan limits unavailable' USING ERRCODE='P0002'; END IF;
  SELECT coalesce(admin_controls->'limits','{}') INTO overrides FROM public.profiles WHERE id=u;
  limits := limits || (overrides - 'posts_per_day' - 'ai_queries_per_day');
  RETURN jsonb_build_object('user_id',u,'tier',t,'limits',limits,
    'notes_used',(SELECT count(*) FROM public.trader_notes WHERE user_id=u),
    'trades_used',(SELECT count(*) FROM public.journal_entries WHERE user_id=u),
    'live_playbooks_used',(SELECT count(*) FROM public.strategies WHERE user_id=u AND status='live'),
    'ai_queries_used',(SELECT count(*) FROM public.ai_insight_requests WHERE user_id=u AND requested_at>=date_trunc('month',now()) AND requested_at<date_trunc('month',now())+interval '1 month'),
    'ai_queries_today',(SELECT count(*) FROM public.ai_insight_requests WHERE user_id=u AND requested_at>=date_trunc('day',now())),
    'window_started_at',date_trunc('month',now()));
END;
$$;
CREATE OR REPLACE FUNCTION public.enforce_published_customer_quota()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE usage jsonb; k text; used_key text; maximum integer; used integer; daily_max integer;
BEGIN
  IF auth.uid() IS NULL OR tradex_private.is_admin() THEN RETURN NEW; END IF;
  IF TG_TABLE_NAME='strategies' THEN
    IF NEW.status <> 'live' OR (TG_OP='UPDATE' AND OLD.status='live') THEN RETURN NEW; END IF;
    k:='live_playbooks'; used_key:='live_playbooks_used';
  ELSIF TG_TABLE_NAME='trader_notes' THEN k:='notes'; used_key:='notes_used';
  ELSIF TG_TABLE_NAME='journal_entries' THEN k:='trades'; used_key:='trades_used';
  ELSE k:='ai_queries_per_month'; used_key:='ai_queries_used'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(NEW.user_id::text),hashtext(k));
  usage := public.get_customer_quota_usage(NEW.user_id);
  maximum := (usage->'limits'->>k)::integer;
  used := (usage->>used_key)::integer;
  IF maximum IS NULL OR used>=maximum THEN
    RAISE EXCEPTION 'Account % limit reached (% of %)',k,used,maximum USING ERRCODE='P0001';
  END IF;
  IF TG_TABLE_NAME='ai_insight_requests' THEN
    SELECT daily_limit INTO daily_max FROM public.ai_quotas WHERE user_id=NEW.user_id;
    IF daily_max IS NOT NULL AND (usage->>'ai_queries_today')::integer>=daily_max THEN
      RAISE EXCEPTION 'Daily AI request limit reached' USING ERRCODE='P0001';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.admin_list(
  p_resource text, p_user uuid DEFAULT NULL, p_search text DEFAULT '', p_status text DEFAULT 'all',
  p_page integer DEFAULT 0, p_page_size integer DEFAULT 25,
  p_from timestamptz DEFAULT NULL, p_to timestamptz DEFAULT NULL, p_parent uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE source text; filtered text; total bigint; rows jsonb;
BEGIN
  PERFORM tradex_private.require_admin();
  IF p_page<0 OR p_page_size<1 OR p_page_size>100 OR length(p_search)>200 THEN
    RAISE EXCEPTION 'Invalid page or search' USING ERRCODE='22023';
  END IF;
  CASE p_resource
  WHEN 'users' THEN source := $q$
    SELECT jsonb_build_object('id',p.id,'user_id',p.id,'title',coalesce(nullif(p.display_name,''),p.handle::text),
      'handle',p.handle,'email',p.email,'role',p.role,'status',p.status,'created_at',p.created_at,
      'last_active_at',p.last_active_at,'tier',tradex_private.effective_tier(p.id)) AS j FROM public.profiles p$q$;
  WHEN 'posts' THEN source := $q$
    SELECT (to_jsonb(t)-'body') || jsonb_build_object('user_id',t.author_id,'body',left(t.body,240),
      'author',coalesce(p.display_name,p.handle::text),'status',t.moderation_status) j
    FROM public.community_posts t JOIN public.profiles p ON p.id=t.author_id$q$;
  WHEN 'comments' THEN source := $q$
    SELECT to_jsonb(t) || jsonb_build_object('user_id',t.author_id,'parent_id',t.post_id,
      'title',left(t.body,120),'author',coalesce(p.display_name,p.handle::text),'status',t.moderation_status) j
    FROM public.community_comments t JOIN public.profiles p ON p.id=t.author_id$q$;
  WHEN 'notes' THEN source := $q$
    SELECT (to_jsonb(t)-'content') || jsonb_build_object('author',coalesce(p.display_name,p.handle::text),
      'status',CASE WHEN t.admin_hidden THEN 'restricted' WHEN t.is_public THEN 'public' ELSE 'private' END) j
    FROM public.trader_notes t JOIN public.profiles p ON p.id=t.user_id$q$;
  WHEN 'journal' THEN source := $q$
    SELECT (to_jsonb(t)-ARRAY['content','psychology','mistakes_made','lessons_learned']) ||
      jsonb_build_object('author',coalesce(p.display_name,p.handle::text),
      'status',CASE WHEN t.admin_hidden THEN 'restricted' WHEN t.is_public THEN 'public' ELSE 'private' END) j
    FROM public.journal_entries t JOIN public.profiles p ON p.id=t.user_id$q$;
  WHEN 'strategies' THEN source := $q$
    SELECT (to_jsonb(t)-ARRAY['content','ai_summary']) || jsonb_build_object('author',coalesce(p.display_name,p.handle::text),
      'status',CASE WHEN t.admin_hidden THEN 'restricted' ELSE t.status END) j
    FROM public.strategies t JOIN public.profiles p ON p.id=t.user_id$q$;
  WHEN 'messages' THEN source := $q$
    SELECT (to_jsonb(t)-'body') || jsonb_build_object('user_id',t.sender_id,'parent_id',t.thread_id,
      'title',left(t.body,120),'author',coalesce(p.display_name,p.handle::text),
      'status',CASE WHEN t.admin_hidden THEN 'restricted' ELSE t.status END) j
    FROM public.chat_messages t JOIN public.profiles p ON p.id=t.sender_id$q$;
  WHEN 'ai' THEN source := $q$
    SELECT to_jsonb(t) || jsonb_build_object('author',coalesce(p.display_name,p.handle::text),
      'status',CASE WHEN t.admin_hidden THEN 'restricted' ELSE 'active' END,
      'messages_count',(SELECT count(*) FROM public.ai_messages m WHERE m.thread_id=t.id)) j
    FROM public.ai_threads t JOIN public.profiles p ON p.id=t.user_id$q$;
  WHEN 'ai_messages' THEN source := $q$
    SELECT (to_jsonb(m)-'body') || jsonb_build_object('user_id',t.user_id,'parent_id',m.thread_id,
      'title',left(m.body,120),'author',m.role,'status',CASE WHEN m.error IS NOT NULL THEN 'failed' ELSE 'complete' END) j
    FROM public.ai_messages m JOIN public.ai_threads t ON t.id=m.thread_id$q$;
  WHEN 'ai_requests' THEN source := $q$
    SELECT (to_jsonb(t)-ARRAY['prompt_text','response_text']) || jsonb_build_object('title',t.kind,'created_at',t.requested_at,
      'parent_id',t.thread_id,'author',coalesce(p.display_name,p.handle::text)) j
    FROM public.ai_insight_requests t JOIN public.profiles p ON p.id=t.user_id$q$;
  WHEN 'affiliates' THEN source := $q$
    SELECT (to_jsonb(t)-ARRAY['payout_details','pan_number','gstin']) || jsonb_build_object('user_id',t.id,
      'title',coalesce(p.display_name,p.handle::text),'email',p.email,'handle',p.handle) j
    FROM public.affiliate_profiles t JOIN public.profiles p ON p.id=t.id$q$;
  WHEN 'applications' THEN source := $q$
    SELECT (to_jsonb(t)-ARRAY['account_number','pan','date_of_birth','phone']) || jsonb_build_object('title',t.full_name,
      'status',CASE WHEN t.status='pending_review' THEN 'pending' ELSE t.status END) j
    FROM public.affiliate_applications t$q$;
  WHEN 'referrals' THEN source := $q$
    SELECT to_jsonb(t) || jsonb_build_object('user_id',t.affiliate_id,'title',coalesce(p.display_name,p.handle::text),
      'author',coalesce(p.display_name,p.handle::text)) j
    FROM public.affiliate_referrals t JOIN public.profiles p ON p.id=t.referred_user_id$q$;
  WHEN 'payouts' THEN source := $q$
    SELECT (to_jsonb(t)-'payout_details') || jsonb_build_object('user_id',t.affiliate_id,
      'title',coalesce(p.display_name,p.handle::text)) j
    FROM public.affiliate_payouts t JOIN public.profiles p ON p.id=t.affiliate_id$q$;
  WHEN 'subscriptions' THEN source := $q$
    SELECT coalesce(to_jsonb(s),'{}') || jsonb_build_object('id',p.id,'user_id',p.id,
      'title',coalesce(p.display_name,p.handle::text),'email',p.email,'created_at',p.created_at,
      'status',coalesce(s.status,'free'),'tier',tradex_private.effective_tier(p.id),
      'billing_tier',coalesce(s.tier,'free'),'access_override',p.admin_controls->'subscription_override') j
    FROM public.profiles p LEFT JOIN public.subscriptions s ON s.user_id=p.id$q$;
  WHEN 'activity' THEN source := $q$
    SELECT (to_jsonb(t)-ARRAY['ip_address','sha256_hash']) || jsonb_build_object('user_id',t.subject_user_id,
      'title',t.action || ' · ' || t.target_label,'author',t.actor_handle,'status',t.category) j
    FROM public.admin_audit_logs t$q$;
  WHEN 'deletions' THEN source := $q$
    SELECT to_jsonb(t) || jsonb_build_object('user_id',coalesce(t.user_id,t.subject_user_id),
      'title',t.user_handle) j FROM public.account_deletion_requests t$q$;
  ELSE RAISE EXCEPTION 'Unknown administration resource' USING ERRCODE='22023';
  END CASE;
  filtered := ' FROM (' || source || ') base WHERE '
    || '($1::uuid IS NULL OR j->>''user_id''=$1::text OR j->>''actor_id''=$1::text) '
    || 'AND ($2='''' OR concat_ws('' '',j->>''title'',j->>''email'',j->>''handle'',j->>''author'',j->>''id'',j->>''action'') ILIKE ''%'' || $2 || ''%'') '
    || 'AND ($3=''all'' OR j->>''status''=$3) '
    || 'AND ($4::timestamptz IS NULL OR (j->>''created_at'')::timestamptz >= $4) '
    || 'AND ($5::timestamptz IS NULL OR (j->>''created_at'')::timestamptz < $5) '
    || 'AND ($6::uuid IS NULL OR j->>''parent_id''=$6::text)';
  EXECUTE 'SELECT count(*)' || filtered INTO total USING p_user,p_search,p_status,p_from,p_to,p_parent;
  EXECUTE 'SELECT coalesce(jsonb_agg(j),''[]'') FROM (SELECT j' || filtered
    || ' ORDER BY (j->>''created_at'')::timestamptz DESC, j->>''id'' DESC LIMIT $7 OFFSET $8) page'
    INTO rows USING p_user,p_search,p_status,p_from,p_to,p_parent,p_page_size,p_page::bigint*p_page_size;
  RETURN jsonb_build_object('rows',rows,'total',total,'page',p_page,'page_size',p_page_size,'fetched_at',now());
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.admin_overview(p_days integer DEFAULT 30) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE start_at timestamptz; trend jsonb;
BEGIN
  PERFORM tradex_private.require_admin();
  IF p_days NOT IN (7,30,90) THEN RAISE EXCEPTION 'Choose 7, 30 or 90 days'; END IF;
  start_at := date_trunc('day',now())-make_interval(days=>p_days-1);
  SELECT jsonb_agg(jsonb_build_object('date',d,
    'users',(SELECT count(*) FROM public.profiles WHERE created_at>=d AND created_at<d+interval '1 day'),
    'posts',(SELECT count(*) FROM public.community_posts WHERE created_at>=d AND created_at<d+interval '1 day'),
    'messages',(SELECT count(*) FROM public.chat_messages WHERE created_at>=d AND created_at<d+interval '1 day'),
    'ai_requests',(SELECT count(*) FROM public.ai_insight_requests WHERE requested_at>=d AND requested_at<d+interval '1 day')) ORDER BY d)
    INTO trend FROM generate_series(start_at,date_trunc('day',now()),interval '1 day') d;
  RETURN jsonb_build_object('fetched_at',now(),'from',start_at,'days',p_days,'trend',trend,
    'users',(SELECT count(*) FROM public.profiles),
    'active_accounts',(SELECT count(*) FROM public.profiles WHERE status='active'),
    'suspended_accounts',(SELECT count(*) FROM public.profiles WHERE status='suspended'),
    'new_users',(SELECT count(*) FROM public.profiles WHERE created_at>=start_at),
    'active_users',(SELECT count(DISTINCT actor_id) FROM public.admin_audit_logs WHERE created_at>=start_at AND actor_id IS NOT NULL),
    'affiliates',(SELECT count(*) FROM public.affiliate_profiles WHERE status='active'),
    'pending_applications',(SELECT count(*) FROM public.affiliate_applications WHERE status IN ('pending','pending_review')),
    'posts',(SELECT count(*) FROM public.community_posts),
    'pending_posts',(SELECT count(*) FROM public.community_posts WHERE moderation_status='pending'),
    'pending_comments',(SELECT count(*) FROM public.community_comments WHERE moderation_status='pending'),
    'post_views',(SELECT coalesce(sum(views_count),0) FROM public.community_posts),
    'notes',(SELECT count(*) FROM public.trader_notes),'journal',(SELECT count(*) FROM public.journal_entries),
    'strategies',(SELECT count(*) FROM public.strategies),
    'messages',(SELECT count(*) FROM public.chat_messages WHERE created_at>=start_at),
    'ai_requests',(SELECT count(*) FROM public.ai_insight_requests WHERE requested_at>=start_at),
    'subscriptions',(SELECT count(*) FROM public.subscriptions WHERE tier<>'free' AND status IN ('active','trialing','canceled') AND (expires_at IS NULL OR expires_at>now())),
    'access_grants',(SELECT count(*) FROM public.profiles WHERE (admin_controls->'subscription_override'->>'expires_at')::timestamptz>now()),
    'pending_deletions',(SELECT count(*) FROM public.account_deletion_requests WHERE status IN ('pending','grace_period')),
    'history_started_at',(SELECT min(created_at) FROM public.admin_audit_logs WHERE metadata->>'source'='database'),
    'recent_activity',(tradex_private.admin_list('activity',p_page_size=>8))->'rows');
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.admin_user(p_user uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE profile jsonb; usage jsonb; quota_error text;
BEGIN
  PERFORM tradex_private.require_admin();
  SELECT to_jsonb(p)-'admin_key' INTO profile FROM public.profiles p WHERE p.id=p_user;
  IF profile IS NULL THEN RAISE EXCEPTION 'Account not found' USING ERRCODE='P0002'; END IF;
  BEGIN usage := public.get_customer_quota_usage(p_user);
  EXCEPTION WHEN SQLSTATE 'P0002' THEN quota_error := SQLERRM; END;
  RETURN jsonb_build_object('profile',profile,'effective_tier',tradex_private.effective_tier(p_user),
    'subscription',(SELECT to_jsonb(s) FROM public.subscriptions s WHERE user_id=p_user),
    'affiliate',(SELECT to_jsonb(a)-ARRAY['payout_details','pan_number','gstin'] FROM public.affiliate_profiles a WHERE id=p_user),
    'quota',usage,'quota_error',quota_error,
    'ai_daily_limit',(SELECT daily_limit FROM public.ai_quotas WHERE user_id=p_user),
    'last_sign_in_at',(SELECT last_sign_in_at FROM auth.users WHERE id=p_user),
    'counts',jsonb_build_object(
      'posts',(SELECT count(*) FROM public.community_posts WHERE author_id=p_user),
      'notes',(SELECT count(*) FROM public.trader_notes WHERE user_id=p_user),
      'journal',(SELECT count(*) FROM public.journal_entries WHERE user_id=p_user),
      'strategies',(SELECT count(*) FROM public.strategies WHERE user_id=p_user),
      'messages',(SELECT count(*) FROM public.chat_messages WHERE sender_id=p_user),
      'ai',(SELECT count(*) FROM public.ai_insight_requests WHERE user_id=p_user),
      'views',(SELECT coalesce(sum(views_count),0) FROM public.community_posts WHERE author_id=p_user)),
    'features',(SELECT coalesce(jsonb_object_agg(f,tradex_private.feature_enabled(f,p_user)),'{}')
      FROM unnest(ARRAY['posts','comments','notes','journal','strategies','messages','ai','affiliate']) f));
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.admin_record(p_resource text,p_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE table_name text; id_column text:='id'; j jsonb; owner_id uuid; recent jsonb;
BEGIN
  PERFORM tradex_private.require_admin();
  table_name := CASE p_resource WHEN 'posts' THEN 'community_posts' WHEN 'comments' THEN 'community_comments'
    WHEN 'notes' THEN 'trader_notes' WHEN 'journal' THEN 'journal_entries' WHEN 'strategies' THEN 'strategies'
    WHEN 'messages' THEN 'chat_messages' WHEN 'ai' THEN 'ai_threads' WHEN 'ai_messages' THEN 'ai_messages'
    WHEN 'ai_requests' THEN 'ai_insight_requests' WHEN 'applications' THEN 'affiliate_applications'
    WHEN 'affiliates' THEN 'affiliate_profiles' WHEN 'referrals' THEN 'affiliate_referrals'
    WHEN 'payouts' THEN 'affiliate_payouts' WHEN 'deletions' THEN 'account_deletion_requests'
    WHEN 'activity' THEN 'admin_audit_logs' ELSE NULL END;
  IF table_name IS NULL THEN RAISE EXCEPTION 'Unknown record type'; END IF;
  EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE %I=$1',table_name,id_column) INTO j USING p_id;
  IF j IS NULL THEN RAISE EXCEPTION 'Record not found' USING ERRCODE='P0002'; END IF;
  owner_id := nullif(coalesce(j->>'user_id',j->>'author_id',j->>'sender_id',j->>'affiliate_id',j->>'subject_user_id'), '')::uuid;
  IF p_resource='affiliates' THEN owner_id:=p_id; END IF;
  IF p_resource='ai_messages' THEN SELECT user_id INTO owner_id FROM public.ai_threads WHERE id=(j->>'thread_id')::uuid; END IF;
  IF p_resource IN ('applications','affiliates','payouts') THEN
    j := (j-ARRAY['account_number','pan','payout_details','pan_number','gstin','date_of_birth'])
      || jsonb_build_object('account_last4',right(j->>'account_number',4));
  END IF;
  SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM (
    SELECT action,actor_handle,metadata,created_at FROM public.admin_audit_logs
    WHERE target_id=p_id::text ORDER BY created_at DESC,id DESC LIMIT 20
  ) x;
  IF p_resource<>'activity' THEN
    PERFORM tradex_private.write_audit(owner_id,'access','record_viewed',table_name,p_id::text,
      coalesce(j->>'title',j->>'full_name',table_name),jsonb_build_object('source','database'));
  END IF;
  RETURN jsonb_build_object('record',j,'user_id',owner_id,'activity',recent);
END;
$$;

ALTER TABLE public.affiliate_applications ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION tradex_private.admin_mutate(
  p_action text, p_user uuid DEFAULT NULL, p_record uuid DEFAULT NULL,
  p_value jsonb DEFAULT '{}', p_reason text DEFAULT ''
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor uuid; profile public.profiles%ROWTYPE; before_state jsonb; features jsonb; limits jsonb;
  k text; v jsonb; v_status text; tier text; expiry timestamptz; source text; owner_id uuid;
  application public.affiliate_applications%ROWTYPE; request_id uuid;
BEGIN
  actor:=tradex_private.require_admin();
  IF p_reason IS NULL OR length(trim(p_reason))<3 OR length(p_reason)>2000 THEN
    RAISE EXCEPTION 'Provide a reason between 3 and 2000 characters' USING ERRCODE='22023';
  END IF;
  IF jsonb_typeof(p_value) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Invalid action payload'; END IF;
  IF p_user IS NOT NULL THEN
    SELECT * INTO profile FROM public.profiles WHERE id=p_user FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Account not found' USING ERRCODE='P0002'; END IF;
    before_state:=jsonb_build_object('status',profile.status,'role',profile.role,'controls',profile.admin_controls);
  END IF;
  PERFORM set_config('tradex.admin_reason',p_reason,true);
  CASE p_action
  WHEN 'account_status' THEN
    v_status:=p_value->>'status';
    IF p_user IS NULL OR v_status NOT IN ('active','suspended') THEN RAISE EXCEPTION 'Invalid account status'; END IF;
    IF p_user=actor THEN RAISE EXCEPTION 'You cannot suspend your own administrator account'; END IF;
    IF profile.role='user_admin' THEN RAISE EXCEPTION 'Change the administrator role before suspending this account'; END IF;
    IF v_status='active' AND EXISTS(SELECT 1 FROM public.account_deletion_requests WHERE user_id=p_user AND status IN ('pending','grace_period','processing','failed')) THEN
      RAISE EXCEPTION 'Cancel the deletion request before restoring access';
    END IF;
    UPDATE public.profiles SET status=v_status,updated_at=now() WHERE id=p_user;
  WHEN 'role' THEN
    v_status:=p_value->>'role';
    IF p_user IS NULL OR v_status NOT IN ('customer','affiliate','user_admin') THEN RAISE EXCEPTION 'Invalid role'; END IF;
    IF p_user=actor THEN RAISE EXCEPTION 'You cannot change your own administrator role'; END IF;
    IF v_status='affiliate' AND NOT EXISTS(SELECT 1 FROM public.affiliate_applications WHERE user_id=p_user AND status='approved') THEN
      RAISE EXCEPTION 'Approve an affiliate application first';
    END IF;
    UPDATE public.profiles SET role=v_status,updated_at=now() WHERE id=p_user;
  WHEN 'controls' THEN
    IF p_user IS NULL THEN RAISE EXCEPTION 'Choose an account'; END IF;
    IF p_user=actor THEN RAISE EXCEPTION 'Use another administrator to change your account controls'; END IF;
    features:=coalesce(p_value->'features','{}'); limits:=coalesce(p_value->'limits','{}');
    IF jsonb_typeof(features)<>'object' OR jsonb_typeof(limits)<>'object' THEN RAISE EXCEPTION 'Invalid controls'; END IF;
    FOR k,v IN SELECT * FROM jsonb_each(features) LOOP
      IF k NOT IN ('posts','comments','notes','journal','strategies','messages','ai','affiliate') OR jsonb_typeof(v)<>'boolean' THEN
        RAISE EXCEPTION 'Invalid feature control: %',k;
      END IF;
    END LOOP;
    FOR k,v IN SELECT * FROM jsonb_each(limits) LOOP
      IF k NOT IN ('notes','trades','live_playbooks','ai_queries_per_month','posts_per_day','ai_queries_per_day') THEN
        RAISE EXCEPTION 'Invalid quota: %',k;
      END IF;
      IF v<>'null'::jsonb AND (jsonb_typeof(v)<>'number' OR (v#>>'{}')::numeric<0
        OR (v#>>'{}')::numeric>1000000 OR (v#>>'{}')::numeric<>floor((v#>>'{}')::numeric)) THEN
        RAISE EXCEPTION 'Quotas must be whole numbers from 0 to 1000000';
      END IF;
    END LOOP;
    limits:=jsonb_strip_nulls(limits);
    UPDATE public.profiles SET admin_controls=admin_controls || jsonb_build_object('features',features,'limits',limits),updated_at=now() WHERE id=p_user;
    IF limits ? 'ai_queries_per_day' THEN
      INSERT INTO public.ai_quotas(user_id,daily_limit) VALUES(p_user,(limits->>'ai_queries_per_day')::integer)
        ON CONFLICT(user_id) DO UPDATE SET daily_limit=excluded.daily_limit,updated_at=now();
    ELSE DELETE FROM public.ai_quotas WHERE user_id=p_user; END IF;
  WHEN 'subscription_access' THEN
    IF p_user IS NULL THEN RAISE EXCEPTION 'Choose an account'; END IF;
    tier:=p_value->>'tier'; expiry:=(p_value->>'expires_at')::timestamptz;
    IF tier NOT IN ('free','premium','enterprise') OR expiry IS NULL OR expiry<=now() OR expiry>now()+interval '10 years' THEN
      RAISE EXCEPTION 'Choose a valid plan and future expiry';
    END IF;
    UPDATE public.profiles SET admin_controls=admin_controls || jsonb_build_object('subscription_override',
      jsonb_build_object('tier',tier,'expires_at',expiry)),subscription_tier=tier,updated_at=now() WHERE id=p_user;
  WHEN 'clear_subscription_access' THEN
    IF p_user IS NULL THEN RAISE EXCEPTION 'Choose an account'; END IF;
    UPDATE public.profiles SET admin_controls=admin_controls-'subscription_override',updated_at=now() WHERE id=p_user;
    UPDATE public.profiles SET subscription_tier=tradex_private.effective_tier(p_user) WHERE id=p_user;
  WHEN 'review_application' THEN
    v_status:=p_value->>'status';
    IF v_status NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'Invalid review decision'; END IF;
    SELECT * INTO application FROM public.affiliate_applications WHERE id=p_record FOR UPDATE;
    IF NOT FOUND OR application.user_id IS DISTINCT FROM p_user THEN RAISE EXCEPTION 'Application not found'; END IF;
    IF application.status NOT IN ('pending','pending_review') THEN RAISE EXCEPTION 'This application has already been reviewed'; END IF;
    IF v_status='approved' AND profile.status<>'active' THEN RAISE EXCEPTION 'Restore account access before approving the application'; END IF;
    UPDATE public.affiliate_applications SET status=v_status,reviewed_at=now(),reviewed_by=actor,review_notes=p_reason,updated_at=now() WHERE id=p_record;
    IF v_status='approved' THEN
      INSERT INTO public.affiliate_profiles(id,affiliate_code,status,payout_method,payout_details)
        VALUES(p_user,'th-'||left(replace(p_user::text,'-',''),20),'active',
          CASE WHEN nullif(trim(application.upi_id),'') IS NOT NULL THEN 'upi' ELSE 'bank_transfer' END,
          jsonb_build_object('account_holder',application.account_holder,'bank_name',application.bank_name,
            'account_number',application.account_number,'ifsc',application.ifsc,'account_type',application.account_type,
            'pan',application.pan,'upi_id',application.upi_id))
        ON CONFLICT(id) DO UPDATE SET status='active',payout_method=excluded.payout_method,
          payout_details=excluded.payout_details,updated_at=now();
      UPDATE public.profiles SET role=CASE WHEN role='user_admin' THEN role ELSE 'affiliate' END,updated_at=now() WHERE id=p_user;
    END IF;
  WHEN 'affiliate_controls' THEN
    v_status:=p_value->>'status'; tier:=p_value->>'tier';
    IF p_user IS NULL OR v_status IS NULL OR v_status NOT IN ('active','suspended') OR tier IS NULL OR tier NOT IN ('standard','silver','gold','platinum')
      OR p_value->>'commission_rate' IS NULL OR (p_value->>'commission_rate')::numeric NOT BETWEEN 0 AND 1 THEN RAISE EXCEPTION 'Invalid affiliate controls'; END IF;
    UPDATE public.affiliate_profiles SET status=v_status,tier=p_value->>'tier',commission_rate=(p_value->>'commission_rate')::numeric,updated_at=now() WHERE id=p_user;
    IF NOT FOUND THEN RAISE EXCEPTION 'Affiliate not found'; END IF;
  WHEN 'moderate_post','moderate_comment' THEN
    v_status:=p_value->>'status'; source:=CASE WHEN p_action='moderate_post' THEN 'community_posts' ELSE 'community_comments' END;
    IF v_status NOT IN ('pending','approved','rejected') THEN RAISE EXCEPTION 'Invalid moderation decision'; END IF;
    EXECUTE format('UPDATE public.%I SET moderation_status=$1,moderation_note=$2,reviewed_by=$3,reviewed_at=now(),updated_at=now() WHERE id=$4 RETURNING author_id',source)
      INTO owner_id USING v_status,p_reason,actor,p_record;
    IF owner_id IS NULL THEN RAISE EXCEPTION 'Record not found'; END IF;
    IF p_user IS NOT NULL AND p_user<>owner_id THEN RAISE EXCEPTION 'Record belongs to another account'; END IF;
    p_user:=owner_id;
  WHEN 'post_options' THEN
    UPDATE public.community_posts SET is_pinned=coalesce((p_value->>'is_pinned')::boolean,is_pinned),
      is_featured=coalesce((p_value->>'is_featured')::boolean,is_featured),updated_at=now()
      WHERE id=p_record RETURNING author_id INTO owner_id;
    IF owner_id IS NULL OR (p_user IS NOT NULL AND p_user<>owner_id) THEN RAISE EXCEPTION 'Post not found'; END IF;
    p_user:=owner_id;
  WHEN 'delete_record' THEN
    source:=CASE p_value->>'resource' WHEN 'posts' THEN 'community_posts' WHEN 'comments' THEN 'community_comments'
      WHEN 'notes' THEN 'trader_notes' WHEN 'journal' THEN 'journal_entries' WHEN 'strategies' THEN 'strategies'
      WHEN 'messages' THEN 'chat_messages' WHEN 'ai' THEN 'ai_threads' ELSE NULL END;
    IF source IS NULL OR p_record IS NULL THEN RAISE EXCEPTION 'Choose a supported content record'; END IF;
    k:=CASE WHEN source IN ('community_posts','community_comments') THEN 'author_id'
      WHEN source='chat_messages' THEN 'sender_id' ELSE 'user_id' END;
    EXECUTE format('SELECT %I FROM public.%I WHERE id=$1 FOR UPDATE',k,source) INTO owner_id USING p_record;
    IF owner_id IS NULL OR (p_user IS NOT NULL AND p_user<>owner_id) THEN RAISE EXCEPTION 'Record not found'; END IF;
    p_user:=owner_id;
    EXECUTE format('DELETE FROM public.%I WHERE id=$1',source) USING p_record;
  WHEN 'payout_status' THEN
    v_status:=p_value->>'status';
    IF v_status IS NULL OR v_status NOT IN ('processing','paid','failed','cancelled') THEN RAISE EXCEPTION 'Invalid payout status'; END IF;
    SELECT affiliate_id INTO owner_id FROM public.affiliate_payouts WHERE id=p_record FOR UPDATE;
    IF owner_id IS NULL OR (p_user IS NOT NULL AND p_user<>owner_id) THEN RAISE EXCEPTION 'Payout not found'; END IF;
    IF v_status='paid' AND nullif(trim(p_value->>'transaction_reference'),'') IS NULL THEN RAISE EXCEPTION 'Enter the completed transfer reference'; END IF;
    UPDATE public.affiliate_payouts SET status=v_status,notes=p_reason,
      transaction_reference=coalesce(nullif(trim(p_value->>'transaction_reference'),''),transaction_reference),updated_at=now()
      WHERE id=p_record;
    p_user:=owner_id; source:='affiliate_payouts';
  WHEN 'restrict_record','restore_record','make_private' THEN
    source:=CASE p_value->>'resource' WHEN 'notes' THEN 'trader_notes' WHEN 'journal' THEN 'journal_entries'
      WHEN 'strategies' THEN 'strategies' WHEN 'messages' THEN 'chat_messages' WHEN 'ai' THEN 'ai_threads' ELSE NULL END;
    IF source IS NULL THEN RAISE EXCEPTION 'This record cannot be moderated'; END IF;
    k:=CASE WHEN source='chat_messages' THEN 'sender_id' ELSE 'user_id' END;
    EXECUTE format('SELECT %I FROM public.%I WHERE id=$1 FOR UPDATE',k,source) INTO owner_id USING p_record;
    IF owner_id IS NULL OR (p_user IS NOT NULL AND p_user<>owner_id) THEN RAISE EXCEPTION 'Record not found'; END IF;
    p_user:=owner_id;
    IF p_action='make_private' THEN
      IF source NOT IN ('trader_notes','journal_entries','strategies') THEN RAISE EXCEPTION 'Not a writing record'; END IF;
      EXECUTE format('UPDATE public.%I SET %s,updated_at=now() WHERE id=$1',source,
        CASE WHEN source='strategies' THEN 'visibility=''private''' ELSE 'is_public=false' END) USING p_record;
    ELSE
      EXECUTE format('UPDATE public.%I SET admin_hidden=$1,updated_at=now() WHERE id=$2',source) USING p_action='restrict_record',p_record;
    END IF;
    IF source='chat_messages' THEN
      UPDATE public.chat_threads t SET last_message_preview=coalesce((SELECT left(m.body,120)
        FROM public.chat_messages m WHERE m.thread_id=t.id AND NOT m.admin_hidden ORDER BY m.created_at DESC,m.id DESC LIMIT 1),''),updated_at=now()
        WHERE t.id=(SELECT thread_id FROM public.chat_messages WHERE id=p_record);
    END IF;
  WHEN 'request_deletion' THEN
    IF p_user IS NULL OR p_user=actor OR profile.role='user_admin' THEN RAISE EXCEPTION 'Administrator accounts must be demoted by another administrator before deletion'; END IF;
    IF EXISTS(SELECT 1 FROM public.account_deletion_requests WHERE user_id=p_user AND status IN ('pending','grace_period','processing','failed')) THEN
      RAISE EXCEPTION 'An open deletion request already exists';
    END IF;
    INSERT INTO public.account_deletion_requests(user_id,subject_user_id,user_handle,user_email,user_role,reason,reviewed_by)
      VALUES(p_user,p_user,profile.handle::text,profile.email::text,profile.role,p_reason,actor) RETURNING id INTO request_id;
    UPDATE public.profiles SET status='suspended',updated_at=now() WHERE id=p_user;
  WHEN 'cancel_deletion' THEN
    UPDATE public.account_deletion_requests SET status='cancelled',review_notes=p_reason,reviewed_by=actor,updated_at=now()
      WHERE id=p_record AND status IN ('pending','grace_period') RETURNING user_id INTO owner_id;
    IF owner_id IS NULL THEN RAISE EXCEPTION 'An open deletion request was not found'; END IF;
    p_user:=owner_id;
  WHEN 'admin_note' THEN
    IF p_user IS NULL THEN RAISE EXCEPTION 'Choose an account'; END IF;
  WHEN 'settings' THEN
    features:=p_value->'features';
    IF jsonb_typeof(features) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Invalid platform settings'; END IF;
    FOR k,v IN SELECT * FROM jsonb_each(features) LOOP
      IF k NOT IN ('posts','comments','notes','journal','strategies','messages','ai','affiliate') OR jsonb_typeof(v)<>'boolean' THEN
        RAISE EXCEPTION 'Invalid feature control: %',k;
      END IF;
    END LOOP;
    UPDATE public.platform_settings SET features=p_value->'features',updated_by=actor,updated_at=now() WHERE id='default';
  ELSE RAISE EXCEPTION 'Unknown administrator action' USING ERRCODE='22023';
  END CASE;
  PERFORM tradex_private.write_audit(p_user,'administration',p_action,
    coalesce(source,CASE WHEN p_action='settings' THEN 'platform_settings' ELSE 'profiles' END),
    coalesce(p_record::text,p_user::text,'default'),coalesce(profile.display_name,profile.handle::text,p_action),
    jsonb_build_object('source','database','reason',trim(p_reason),'before',before_state,'changes',p_value));
  RETURN jsonb_build_object('saved',true,'request_id',request_id);
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.admin_settings() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM tradex_private.require_admin();
  RETURN (SELECT to_jsonb(s) FROM public.platform_settings s WHERE id='default');
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.my_access() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE p public.profiles%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in to continue' USING ERRCODE='42501'; END IF;
  SELECT * INTO p FROM public.profiles WHERE id=auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Account not found' USING ERRCODE='P0002'; END IF;
  RETURN jsonb_build_object('user_id',p.id,'status',p.status,'role',p.role,'tier',tradex_private.effective_tier(p.id),
    'affiliate_approved',EXISTS(SELECT 1 FROM public.affiliate_profiles WHERE id=p.id AND status='active'),
    'features',(SELECT jsonb_object_agg(f,tradex_private.feature_enabled(f,p.id))
      FROM unnest(ARRAY['posts','comments','notes','journal','strategies','messages','ai','affiliate']) f));
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.account_activity(p_destination text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.profiles%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
  IF p_destination IS NULL OR p_destination !~ '^[a-z][a-z0-9_]{0,79}$' THEN
    RAISE EXCEPTION 'Invalid destination' USING ERRCODE='22023';
  END IF;
  SELECT * INTO p FROM public.profiles WHERE id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR p.status<>'active' THEN RAISE EXCEPTION 'Account access is suspended' USING ERRCODE='42501'; END IF;
  IF p.last_active_at IS NULL OR p.last_active_at<now()-interval '30 minutes' THEN
    PERFORM tradex_private.write_audit(p.id,'users','app_opened','profiles',p.id::text,p.handle::text,
      jsonb_build_object('source','client','destination',p_destination));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.admin_audit_logs WHERE actor_id=p.id AND action='page_viewed'
    AND target_id=p_destination AND created_at>now()-interval '5 minutes') THEN
    PERFORM tradex_private.write_audit(p.id,'users','page_viewed','app_page',p_destination,p_destination,
      jsonb_build_object('source','client'));
  END IF;
  UPDATE public.profiles SET last_active_at=now() WHERE id=p.id;
END;
$$;

-- Public RPCs are invokers; their private implementations validate the live
-- profile role on every call. No service credential is shipped to Flutter.
CREATE OR REPLACE FUNCTION public.admin_list_records(p_resource text,p_user uuid DEFAULT NULL,p_search text DEFAULT '',p_status text DEFAULT 'all',p_page integer DEFAULT 0,p_page_size integer DEFAULT 25,p_from timestamptz DEFAULT NULL,p_to timestamptz DEFAULT NULL,p_parent uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$ SELECT tradex_private.admin_list(p_resource,p_user,p_search,p_status,p_page,p_page_size,p_from,p_to,p_parent); $$;
CREATE OR REPLACE FUNCTION public.admin_get_overview(p_days integer DEFAULT 30)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$ SELECT tradex_private.admin_overview(p_days); $$;
CREATE OR REPLACE FUNCTION public.admin_get_user(p_user uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$ SELECT tradex_private.admin_user(p_user); $$;
CREATE OR REPLACE FUNCTION public.admin_get_record(p_resource text,p_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT tradex_private.admin_record(p_resource,p_id); $$;
CREATE OR REPLACE FUNCTION public.admin_apply_action(p_action text,p_user uuid DEFAULT NULL,p_record uuid DEFAULT NULL,p_value jsonb DEFAULT '{}',p_reason text DEFAULT '')
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT tradex_private.admin_mutate(p_action,p_user,p_record,p_value,p_reason); $$;
CREATE OR REPLACE FUNCTION public.admin_get_settings()
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$ SELECT tradex_private.admin_settings(); $$;
CREATE OR REPLACE FUNCTION public.get_my_admin_access()
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$ SELECT tradex_private.my_access(); $$;
CREATE OR REPLACE FUNCTION public.record_account_activity(p_destination text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$ SELECT tradex_private.account_activity(p_destination); $$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA tradex_private FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA tradex_private TO service_role;
GRANT EXECUTE ON FUNCTION tradex_private.account_active(uuid),tradex_private.is_admin(),tradex_private.feature_enabled(text,uuid),
  tradex_private.chat_member(uuid),tradex_private.chat_owner(uuid),tradex_private.admin_list(text,uuid,text,text,integer,integer,timestamptz,timestamptz,uuid),
  tradex_private.admin_overview(integer),tradex_private.admin_user(uuid),tradex_private.admin_record(text,uuid),
  tradex_private.admin_mutate(text,uuid,uuid,jsonb,text),tradex_private.admin_settings(),tradex_private.my_access() TO authenticated;
GRANT EXECUTE ON FUNCTION tradex_private.account_activity(text) TO authenticated;
REVOKE ALL ON FUNCTION public.record_account_activity(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.record_account_activity(text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_list_records(text,uuid,text,text,integer,integer,timestamptz,timestamptz,uuid),
  public.admin_get_overview(integer),public.admin_get_user(uuid),public.admin_get_record(text,uuid),
  public.admin_apply_action(text,uuid,uuid,jsonb,text),public.admin_get_settings(),public.get_my_admin_access(),
  public.get_customer_quota_usage(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_list_records(text,uuid,text,text,integer,integer,timestamptz,timestamptz,uuid),
  public.admin_get_overview(integer),public.admin_get_user(uuid),public.admin_get_record(text,uuid),
  public.admin_apply_action(text,uuid,uuid,jsonb,text),public.admin_get_settings(),public.get_my_admin_access(),
  public.get_customer_quota_usage(uuid) TO authenticated;

-- Cover attachment, legacy and child-record write paths as well as parent pages.
DO $$ DECLARE entry text[]; BEGIN
  FOREACH entry SLICE 1 IN ARRAY ARRAY[
    ['trader_note_attachments','notes'],['journal_entry_attachments','journal'],
    ['strategy_versions','strategies'],['strategy_attachments','strategies'],
    ['posts','posts'],['comments','comments'],['unified_comments','comments'],
    ['trader_note_comments','comments'],['messages','messages'],
    ['chat_threads','messages'],['chat_attachments','messages'],['chat_shared_refs','messages'],
    ['ai_chart_setups','ai'],['community_post_trade_setups','posts'],
    ['community_post_attachments','posts'],['community_polls','posts'],['community_poll_options','posts']
  ] LOOP
    IF to_regclass('public.'||entry[1]) IS NULL THEN CONTINUE; END IF;
    EXECUTE format('DROP TRIGGER IF EXISTS admin_feature_guard ON public.%I',entry[1]);
    EXECUTE format('CREATE TRIGGER admin_feature_guard BEFORE INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION tradex_private.guard_feature_write(%L)',entry[1],entry[2]);
  END LOOP;
END $$;

-- Anonymous public reads must respect moderation too.
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['trader_notes','journal_entries','strategies'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS admin_public_visible_record ON public.%I',t);
    EXECUTE format('CREATE POLICY admin_public_visible_record ON public.%I AS RESTRICTIVE FOR SELECT TO anon USING (NOT admin_hidden)',t);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public_strategy_performance(p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN COUNT(*) < 5 THEN NULL ELSE jsonb_build_object(
           'total_trades', COUNT(*),
           'win_rate',     ROUND(100.0 * COUNT(*) FILTER (WHERE c.pnl > 0)
                                 / NULLIF(COUNT(*), 0), 2),
           'avg_r',        ROUND(AVG(c.r_multiple)::numeric, 2),
           'net_pnl',      ROUND(SUM(c.pnl)::numeric, 2)
         ) END
    FROM journal_entries c
   WHERE c.strategy_id = p_id
     AND c.outcome IS DISTINCT FROM 'open' AND NOT c.admin_hidden
     AND EXISTS (SELECT 1 FROM public.strategies s WHERE s.id=p_id
       AND s.visibility='public' AND NOT s.admin_hidden);
$$;

-- Which refs survive the strip. Journal entries never do — the share contract
-- publishes a playbook's figures, not the trades behind them. Both arms
-- re-check the publish flag on BOTH ends: this is reachable by anon, so its
-- arguments are hostile input.
CREATE OR REPLACE FUNCTION public_refs(p_kind text, p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(jsonb_agg(r ORDER BY r ->> 'title'), '[]'::jsonb)
  FROM (
    -- public notes filed under a public strategy
    SELECT jsonb_build_object(
             'kind', 'note', 'id', n.id,
             'title', n.title, 'subtitle', n.note_type
           ) AS r
      FROM trader_notes n
      JOIN strategies s ON s.id = n.strategy_id
     WHERE p_kind = 'strategy'
       AND s.id = p_id AND s.visibility = 'public' AND NOT s.admin_hidden
       AND n.is_public AND NOT n.admin_hidden
    UNION ALL
    -- the public playbook a public note is filed under
    SELECT jsonb_build_object(
             'kind', 'strategy', 'id', s.id,
             'title', s.title, 'subtitle', s.summary
           )
      FROM trader_notes n
      JOIN strategies s ON s.id = n.strategy_id
     WHERE p_kind = 'note'
       AND n.id = p_id AND n.is_public AND NOT n.admin_hidden
       AND s.visibility = 'public' AND NOT s.admin_hidden
  ) refs;
$$;

-- A SECURITY DEFINER function bypasses RLS. That is the point, and it is also
-- why the column list below IS the security boundary: there is no second check
-- behind it. Deliberately absent: both mirror arrays, the raw user_id (handle is
-- the public identity), version_count, and every owner-scoped flag.
--
-- A missing record and a private record return the same thing: no row, hence
-- NULL. Do not raise not-found for one and forbidden for the other — that
-- difference is an oracle a script can walk to enumerate which ids exist.
CREATE OR REPLACE FUNCTION public_document(p_kind text, p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
           'kind', 'strategy', 'id', s.id, 'name', s.title,
           'summary', s.summary, 'body', s.content, 'status', s.status,
           'tags', s.tags, 'tickers', s.linked_tickers,
           'updated_at', s.updated_at,
           'author', jsonb_build_object('handle', p.handle,
                                        'display_name', p.display_name,
                                        'avatar_url', p.avatar_url),
           'performance', public_strategy_performance(s.id),
           'refs', public_refs('strategy', s.id)
         )
    FROM strategies s JOIN profiles p ON p.id = s.user_id
   WHERE p_kind = 'strategy' AND s.id = p_id AND s.visibility = 'public' AND NOT s.admin_hidden
  UNION ALL
  SELECT jsonb_build_object(
           'kind', 'note', 'id', n.id, 'title', n.title,
           'body', n.content, 'note_type', n.note_type,
           'tags', n.tags, 'tickers', n.linked_tickers,
           'updated_at', n.updated_at,
           'like_count', n.like_count, 'view_count', n.view_count,
           'author', jsonb_build_object('handle', p.handle,
                                        'display_name', p.display_name,
                                        'avatar_url', p.avatar_url),
           'refs', public_refs('note', n.id)
         )
    FROM trader_notes n JOIN profiles p ON p.id = n.user_id
   WHERE p_kind = 'note' AND n.id = p_id AND n.is_public AND NOT n.admin_hidden
   LIMIT 1;
$$;

ALTER TABLE public.account_deletion_requests ADD COLUMN IF NOT EXISTS processing_started_at timestamptz;
ALTER TABLE public.account_deletion_requests ADD COLUMN IF NOT EXISTS completed_at timestamptz;
ALTER TABLE public.account_deletion_requests ADD COLUMN IF NOT EXISTS last_error text;
ALTER TABLE public.account_deletion_requests DROP CONSTRAINT IF EXISTS account_deletion_requests_status_check;
ALTER TABLE public.account_deletion_requests ADD CONSTRAINT account_deletion_requests_status_check
  CHECK(status IN ('pending','grace_period','processing','failed','data_purged','completed','cancelled'));

-- Only the server function can claim or finish a permanent deletion. Claims
-- serialize concurrent requests; failed or abandoned jobs can be retried.
CREATE OR REPLACE FUNCTION public.admin_claim_deletion(p_request uuid,p_actor uuid,p_confirmation text,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.account_deletion_requests%ROWTYPE; p public.profiles%ROWTYPE;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=p_actor AND role='user_admin' AND status='active') THEN
    RAISE EXCEPTION 'Active administrator required' USING ERRCODE='42501';
  END IF;
  SELECT * INTO r FROM public.account_deletion_requests WHERE id=p_request FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deletion request not found'; END IF;
  IF r.status='completed' THEN RETURN jsonb_build_object('completed',true); END IF;
  IF r.status='cancelled' OR (r.status='processing' AND r.processing_started_at>now()-interval '10 minutes') THEN
    RAISE EXCEPTION 'Deletion is cancelled or already in progress';
  END IF;
  IF r.scheduled_purge_at>now() THEN RAISE EXCEPTION 'The deletion grace period has not ended'; END IF;
  SELECT * INTO p FROM public.profiles WHERE id=r.user_id FOR UPDATE;
  IF NOT FOUND THEN
    -- Auth removal can succeed before the completion receipt reaches the
    -- database. Reconcile that job instead of leaving it permanently failed.
    IF r.subject_user_id IS NOT NULL AND r.status IN ('processing','failed','data_purged')
      AND NOT EXISTS(SELECT 1 FROM auth.users WHERE id=r.subject_user_id)
      AND r.user_handle IS NOT DISTINCT FROM trim(p_confirmation)
      AND p_reason IS NOT NULL AND length(trim(p_reason)) BETWEEN 3 AND 2000 THEN
      UPDATE public.account_deletion_requests SET status='processing',processing_started_at=now(),
        reviewed_by=p_actor,review_notes=p_reason,last_error=NULL,updated_at=now() WHERE id=p_request;
      RETURN jsonb_build_object('user_id',r.subject_user_id,'completed',false,'auth_deleted',true);
    END IF;
    RAISE EXCEPTION 'Account no longer exists';
  END IF;
  IF p.id=p_actor OR p.role='user_admin' THEN RAISE EXCEPTION 'Administrator accounts cannot be deleted'; END IF;
  IF p.handle::text IS DISTINCT FROM trim(p_confirmation) OR p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 3 AND 2000 THEN
    RAISE EXCEPTION 'Confirmation and reason are required';
  END IF;
  IF EXISTS(SELECT 1 FROM public.subscriptions WHERE user_id=p.id
    AND billing_provider IS NOT NULL AND status IN ('active','trialing','past_due')) THEN
    RAISE EXCEPTION 'Cancel the subscription with the billing provider before deleting this account';
  END IF;
  UPDATE public.account_deletion_requests SET subject_user_id=p.id,status='processing',processing_started_at=now(),
    reviewed_by=p_actor,review_notes=p_reason,last_error=NULL,updated_at=now() WHERE id=p_request;
  UPDATE public.profiles SET status='suspended',updated_at=now() WHERE id=p.id;
  IF to_regclass('auth.sessions') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.sessions WHERE user_id=$1' USING p.id;
  END IF;
  RETURN jsonb_build_object('user_id',p.id,'completed',false);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_deletion_storage_batch(p_request uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid;
BEGIN
  SELECT coalesce(user_id,subject_user_id) INTO u FROM public.account_deletion_requests WHERE id=p_request AND status='processing';
  IF u IS NULL THEN RAISE EXCEPTION 'Deletion has not been claimed'; END IF;
  RETURN (SELECT coalesce(jsonb_agg(x),'[]') FROM (
    SELECT bucket_id,name FROM storage.objects WHERE owner=u OR owner_id=u::text OR split_part(name,'/',1)=u::text
    ORDER BY bucket_id,name LIMIT 100
  ) x);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_finish_deletion(p_request uuid,p_actor uuid,p_error text DEFAULT NULL,p_files integer DEFAULT 0)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.account_deletion_requests%ROWTYPE; a public.profiles%ROWTYPE;
BEGIN
  SELECT * INTO r FROM public.account_deletion_requests WHERE id=p_request FOR UPDATE;
  IF NOT FOUND OR r.reviewed_by IS DISTINCT FROM p_actor OR r.status<>'processing' THEN RAISE EXCEPTION 'Deletion claim changed'; END IF;
  IF p_error IS NULL AND EXISTS(SELECT 1 FROM auth.users WHERE id=r.subject_user_id) THEN RAISE EXCEPTION 'The authentication account still exists'; END IF;
  UPDATE public.account_deletion_requests SET status=CASE WHEN p_error IS NULL THEN 'completed' ELSE 'failed' END,
    completed_at=CASE WHEN p_error IS NULL THEN now() ELSE NULL END,last_error=left(p_error,2000),updated_at=now(),
    user_email=CASE WHEN p_error IS NULL THEN NULL ELSE user_email END,
    purged_tables_summary=jsonb_build_object('storage_files_removed',p_files,'auth_account_deleted',p_error IS NULL)
    WHERE id=p_request;
  SELECT * INTO a FROM public.profiles WHERE id=p_actor;
  INSERT INTO public.admin_audit_logs(actor_id,actor_handle,actor_role,subject_user_id,category,action,target_type,target_id,target_label,metadata)
    VALUES(a.id,coalesce(a.handle::text,'Administrator'),'user_admin',r.subject_user_id,'administration',
      CASE WHEN p_error IS NULL THEN 'account_deleted' ELSE 'account_deletion_failed' END,'profiles',r.subject_user_id::text,
      r.user_handle,jsonb_build_object('source','database','reason',r.review_notes,'request_id',r.id,'files_removed',p_files,'error',left(p_error,2000)));
END;
$$;
REVOKE ALL ON FUNCTION public.admin_claim_deletion(uuid,uuid,text,text),public.admin_deletion_storage_batch(uuid),public.admin_finish_deletion(uuid,uuid,text,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_claim_deletion(uuid,uuid,text,text),public.admin_deletion_storage_batch(uuid),public.admin_finish_deletion(uuid,uuid,text,integer) TO service_role;

-- All AI transports reserve quota before contacting a provider. The trusted
-- gateway alone can record provider output, so usage cannot be reset by clients.
CREATE OR REPLACE FUNCTION tradex_private.reserve_ai_request(
  p_kind text,p_prompt text,p_thread uuid DEFAULT NULL,p_persona text DEFAULT 'swing'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE request_id uuid; usage jsonb; thread_owner uuid; hidden boolean;
BEGIN
  IF NOT tradex_private.feature_enabled('ai') THEN
    RAISE EXCEPTION 'AI is disabled for this account' USING ERRCODE='42501';
  END IF;
  IF p_kind IS NULL OR p_kind NOT IN ('chat','regenerate','completion') OR p_prompt IS NULL
    OR length(trim(p_prompt))=0 OR length(p_prompt)>40000 OR length(p_persona)>80 THEN
    RAISE EXCEPTION 'Invalid AI request' USING ERRCODE='22023';
  END IF;
  IF p_thread IS NOT NULL THEN
    INSERT INTO public.ai_threads(id,user_id,title,persona)
      VALUES(p_thread,auth.uid(),left(trim(p_prompt),80),p_persona) ON CONFLICT(id) DO NOTHING;
    SELECT user_id,admin_hidden INTO thread_owner,hidden FROM public.ai_threads WHERE id=p_thread FOR UPDATE;
    IF thread_owner IS DISTINCT FROM auth.uid() OR hidden THEN
      RAISE EXCEPTION 'Conversation is unavailable' USING ERRCODE='42501';
    END IF;
  END IF;
  INSERT INTO public.ai_insight_requests(user_id,kind,thread_id,prompt_text,status)
    VALUES(auth.uid(),p_kind,p_thread,p_prompt,'reserved') RETURNING id INTO request_id;
  IF p_thread IS NOT NULL AND p_kind<>'regenerate' THEN
    INSERT INTO public.ai_messages(thread_id,role,body) VALUES(p_thread,'user',p_prompt);
    UPDATE public.ai_threads SET updated_at=now() WHERE id=p_thread;
  END IF;
  usage:=public.get_customer_quota_usage();
  RETURN jsonb_build_object('request_id',request_id,'user_id',auth.uid(),'usage',usage);
END;
$$;
CREATE OR REPLACE FUNCTION public.reserve_ai_request(p_kind text,p_prompt text,p_thread uuid DEFAULT NULL,p_persona text DEFAULT 'swing')
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$
  SELECT tradex_private.reserve_ai_request(p_kind,p_prompt,p_thread,p_persona);
$$;
REVOKE ALL ON FUNCTION tradex_private.reserve_ai_request(text,text,uuid,text),public.reserve_ai_request(text,text,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION tradex_private.reserve_ai_request(text,text,uuid,text),public.reserve_ai_request(text,text,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.finish_ai_request(
  p_request uuid,p_body text DEFAULT NULL,p_error text DEFAULT NULL,p_provider text DEFAULT NULL,
  p_model text DEFAULT NULL,p_input_tokens integer DEFAULT NULL,p_output_tokens integer DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.ai_insight_requests%ROWTYPE;
BEGIN
  SELECT * INTO r FROM public.ai_insight_requests WHERE id=p_request FOR UPDATE;
  IF NOT FOUND OR r.status<>'reserved' THEN RAISE EXCEPTION 'AI request is no longer pending'; END IF;
  IF length(p_body)>200000 OR length(p_error)>2000 OR p_input_tokens<0 OR p_output_tokens<0 THEN
    RAISE EXCEPTION 'Invalid provider response';
  END IF;
  IF p_error IS NULL AND nullif(trim(p_body),'') IS NULL THEN RAISE EXCEPTION 'Empty provider response'; END IF;
  IF p_error IS NULL AND NOT EXISTS (
    SELECT 1 FROM public.profiles p CROSS JOIN public.platform_settings s
    WHERE p.id=r.user_id AND p.status='active' AND s.id='default'
      AND coalesce((p.admin_controls->'features'->>'ai')::boolean,true)
      AND coalesce((s.features->>'ai')::boolean,true)
      AND (r.thread_id IS NULL OR EXISTS (
        SELECT 1 FROM public.ai_threads t WHERE t.id=r.thread_id AND t.user_id=r.user_id AND NOT t.admin_hidden))
  ) THEN RAISE EXCEPTION 'AI access is no longer available' USING ERRCODE='42501'; END IF;
  UPDATE public.ai_insight_requests SET status=CASE WHEN p_error IS NULL THEN 'completed' ELSE 'failed' END,
    response_text=p_body,error=p_error,provider=p_provider,model=p_model,input_tokens=p_input_tokens,
    output_tokens=p_output_tokens,completed_at=now(),updated_at=now() WHERE id=p_request;
  IF p_error IS NULL AND r.thread_id IS NOT NULL THEN
    INSERT INTO public.ai_messages(thread_id,role,body) VALUES(r.thread_id,'assistant',p_body);
    UPDATE public.ai_threads SET updated_at=now() WHERE id=r.thread_id;
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.finish_ai_request(uuid,text,text,text,text,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.finish_ai_request(uuid,text,text,text,text,integer,integer) TO service_role;

NOTIFY pgrst,'reload schema';
COMMIT;
