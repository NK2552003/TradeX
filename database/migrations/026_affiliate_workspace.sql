-- Partner workspace: apply after 025. Currency defaults to INR (Indian Rupees).
BEGIN;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS custom_slug text UNIQUE;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS minimum_payout_threshold numeric NOT NULL DEFAULT 100;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS auto_payout_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE public.affiliate_profiles ALTER COLUMN auto_payout_enabled SET DEFAULT false;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'INR' CHECK (currency ~ '^[A-Z]{3}$');
ALTER TABLE public.affiliate_profiles DROP CONSTRAINT IF EXISTS affiliate_profiles_payout_method_check;
ALTER TABLE public.affiliate_profiles ADD CONSTRAINT affiliate_profiles_payout_method_check CHECK (payout_method IN ('bank_transfer','bank_wire','bank_neft','bank_imps','bank_rtgs','paypal','stripe','razorpay','crypto','upi'));
ALTER TABLE public.affiliate_profiles ADD CONSTRAINT affiliate_workspace_slug_check CHECK (custom_slug IS NULL OR custom_slug ~ '^[a-z0-9][a-z0-9_-]{2,39}$') NOT VALID;
UPDATE public.affiliate_profiles SET minimum_payout_threshold=100 WHERE minimum_payout_threshold<100;
ALTER TABLE public.affiliate_profiles ADD CONSTRAINT affiliate_workspace_threshold_check CHECK (minimum_payout_threshold >= 100) NOT VALID;

CREATE TABLE public.affiliate_campaigns (
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
CREATE INDEX affiliate_referrals_campaign_idx ON public.affiliate_referrals(campaign_id);
CREATE INDEX affiliate_referrals_date_idx ON public.affiliate_referrals(affiliate_id,created_at DESC);
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS payout_destination jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS balance_reserved boolean NOT NULL DEFAULT false;
CREATE INDEX affiliate_payouts_date_idx ON public.affiliate_payouts(affiliate_id,created_at DESC);
CREATE TABLE public.affiliate_assets (
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
CREATE POLICY affiliate_workspace_profile_read ON public.affiliate_profiles FOR SELECT TO authenticated USING (id=(SELECT auth.uid()));
CREATE POLICY affiliate_workspace_profile_update ON public.affiliate_profiles FOR UPDATE TO authenticated USING (id=(SELECT auth.uid()) AND status='active') WITH CHECK (id=(SELECT auth.uid()) AND status='active');
CREATE POLICY affiliate_workspace_referral_read ON public.affiliate_referrals FOR SELECT TO authenticated USING (affiliate_id=(SELECT auth.uid()));
CREATE POLICY affiliate_workspace_payout_read ON public.affiliate_payouts FOR SELECT TO authenticated USING (affiliate_id=(SELECT auth.uid()));
CREATE POLICY affiliate_workspace_campaign_read ON public.affiliate_campaigns FOR SELECT TO authenticated USING (affiliate_id=(SELECT auth.uid()));
CREATE POLICY affiliate_workspace_campaign_insert ON public.affiliate_campaigns FOR INSERT TO authenticated WITH CHECK (affiliate_id=(SELECT auth.uid()) AND EXISTS(SELECT 1 FROM public.affiliate_profiles WHERE id=(SELECT auth.uid()) AND status='active'));
CREATE POLICY affiliate_workspace_campaign_update ON public.affiliate_campaigns FOR UPDATE TO authenticated USING (affiliate_id=(SELECT auth.uid()) AND EXISTS(SELECT 1 FROM public.affiliate_profiles WHERE id=(SELECT auth.uid()) AND status='active')) WITH CHECK (affiliate_id=(SELECT auth.uid()));
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
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
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
CREATE TABLE public.affiliate_click_receipts (
 event_key text PRIMARY KEY CHECK(length(event_key)=64),
 campaign_id uuid NOT NULL REFERENCES public.affiliate_campaigns(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX affiliate_click_receipts_campaign_idx ON public.affiliate_click_receipts(campaign_id);
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


CREATE TABLE IF NOT EXISTS public.affiliate_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  city TEXT,
  state TEXT,
  date_of_birth DATE,
  gender TEXT,
  platforms TEXT[],
  primary_platform TEXT,
  channel_handle TEXT,
  audience_reach TEXT,
  niches TEXT[],
  sample_link TEXT,
  account_holder TEXT,
  bank_name TEXT,
  account_number TEXT,
  ifsc TEXT,
  account_type TEXT,
  pan TEXT,
  upi_id TEXT,
  status TEXT NOT NULL DEFAULT 'pending_review' CHECK (status IN ('draft', 'pending', 'pending_review', 'approved', 'rejected', 'suspended')),
  review_notes TEXT,
  submitted_at TIMESTAMPTZ DEFAULT now(),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for user lookup
CREATE INDEX IF NOT EXISTS idx_affiliate_applications_user ON public.affiliate_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_applications_status ON public.affiliate_applications(status);

-- 2. Stored Procedure (RPC) to Approve Affiliate Application
CREATE OR REPLACE FUNCTION public.approve_affiliate_application(
  p_application_id UUID,
  p_review_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_app RECORD;
  v_referral_code TEXT;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='user_admin') THEN RAISE EXCEPTION 'Administrator required'; END IF;
  -- Fetch application
  SELECT * INTO v_app
  FROM public.affiliate_applications
  WHERE id = p_application_id FOR UPDATE;

  IF v_app IS NULL THEN
    RAISE EXCEPTION 'Application not found with ID %', p_application_id;
  END IF;

  IF v_app.status = 'approved' THEN
    RETURN jsonb_build_object('success', true, 'message', 'Application already approved');
  END IF;

  IF v_app.status NOT IN ('pending','pending_review') THEN RAISE EXCEPTION 'Only pending applications can be approved'; END IF;

  -- 1. Update Application Status
  UPDATE public.affiliate_applications
  SET status = 'approved',
      review_notes = p_review_notes,
      reviewed_at = now(),
      updated_at = now()
  WHERE id = p_application_id;

  -- 2. Elevate Profile Role to 'affiliate'
  UPDATE public.profiles
  SET role = 'affiliate',
      updated_at = now()
  WHERE id = v_app.user_id
  RETURNING referral_code INTO v_referral_code;

  -- 3. Upsert Affiliate Profile
  INSERT INTO public.affiliate_profiles (
    id,
    affiliate_code,
    tier,
    commission_rate,
    payout_method,
    payout_details,
    status,
    created_at,
    updated_at
  )
  VALUES (
    v_app.user_id,
    COALESCE(v_referral_code, 'AFF-' || UPPER(SUBSTRING(gen_random_uuid()::text FROM 1 FOR 6))),
    'standard',
    0.30, -- 30% lifetime revenue share
    CASE WHEN nullif(trim(v_app.upi_id),'') IS NOT NULL THEN 'upi' ELSE 'bank_transfer' END,
    jsonb_build_object(
      'account_holder', v_app.account_holder,
      'bank_name', v_app.bank_name,
      'account_number', v_app.account_number,
      'ifsc', v_app.ifsc,
      'account_type', v_app.account_type,
      'pan', v_app.pan,
      'upi_id', v_app.upi_id
    ),
    'active',
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE
  SET status = 'active',
      payout_details = EXCLUDED.payout_details,
      updated_at = now();

  RETURN jsonb_build_object('success', true, 'message', 'Affiliate application approved successfully');
END;
$$;


REVOKE ALL ON FUNCTION public.approve_affiliate_application(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.approve_affiliate_application(uuid,text) TO authenticated;
ALTER TABLE public.affiliate_applications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.affiliate_applications FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.affiliate_applications TO authenticated;
GRANT ALL ON public.affiliate_applications TO service_role;
CREATE POLICY affiliate_workspace_application_read ON public.affiliate_applications FOR SELECT TO authenticated USING (user_id=(SELECT auth.uid()) OR EXISTS(SELECT 1 FROM public.profiles WHERE id=(SELECT auth.uid()) AND role='user_admin'));
CREATE POLICY affiliate_workspace_application_insert ON public.affiliate_applications FOR INSERT TO authenticated WITH CHECK (user_id=(SELECT auth.uid()) AND status IN ('draft','pending','pending_review') AND reviewed_at IS NULL AND review_notes IS NULL);
CREATE POLICY affiliate_workspace_application_update ON public.affiliate_applications FOR UPDATE TO authenticated USING (user_id=(SELECT auth.uid()) AND status IN ('draft','pending','pending_review','rejected')) WITH CHECK (user_id=(SELECT auth.uid()) AND status IN ('draft','pending','pending_review') AND reviewed_at IS NULL AND review_notes IS NULL);
CREATE OR REPLACE FUNCTION public.review_affiliate_application(p_application_id uuid,p_approve boolean,p_review_notes text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='user_admin') THEN RAISE EXCEPTION 'Administrator required'; END IF;
 IF p_approve THEN PERFORM public.approve_affiliate_application(p_application_id,p_review_notes);
 ELSE
  UPDATE public.affiliate_applications SET status='rejected',review_notes=p_review_notes,reviewed_at=now(),updated_at=now() WHERE id=p_application_id AND status IN ('pending','pending_review');
  IF NOT FOUND THEN RAISE EXCEPTION 'Pending application not found'; END IF;
 END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.review_affiliate_application(uuid,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.review_affiliate_application(uuid,boolean,text) TO authenticated;

-- Existing profile-owner policies must not allow self-promotion to administrator.
CREATE OR REPLACE FUNCTION public.affiliate_guard_profile_role() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
BEGIN
 IF current_user IN ('authenticated','anon') THEN
  IF TG_OP='INSERT' THEN
   IF NEW.role<>'customer' OR NEW.admin_key IS NOT NULL THEN RAISE EXCEPTION 'Role assignment is server managed'; END IF;
  ELSIF NEW.role IS DISTINCT FROM OLD.role OR NEW.admin_key IS DISTINCT FROM OLD.admin_key THEN RAISE EXCEPTION 'Role assignment is server managed'; END IF;
 END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.affiliate_guard_profile_role() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER affiliate_guard_profile_role BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.affiliate_guard_profile_role();

CREATE OR REPLACE FUNCTION public.handle_new_user_signup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role TEXT;
  v_handle TEXT;
  v_display_name TEXT;
  v_admin_key TEXT;
  v_referral_code TEXT;
  v_referred_by_code TEXT;
  v_referrer_id UUID;
BEGIN
  v_role := 'customer';
  v_handle := COALESCE(NEW.raw_user_meta_data->>'handle', LOWER(SPLIT_PART(NEW.email, '@', 1)));
  v_display_name := COALESCE(NEW.raw_user_meta_data->>'display_name', SPLIT_PART(NEW.email, '@', 1));
  v_admin_key := NULL;
  v_referral_code := COALESCE(NEW.raw_user_meta_data->>'referral_code', 'REF-' || UPPER(SUBSTRING(gen_random_uuid()::text FROM 1 FOR 8)));
  v_referred_by_code := NEW.raw_user_meta_data->>'referred_by_code';

  -- Insert into public.profiles
  INSERT INTO public.profiles (
    id,
    handle,
    email,
    display_name,
    role,
    status,
    admin_key,
    referral_code,
    referred_by_code,
    subscription_tier
  )
  VALUES (
    NEW.id,
    v_handle,
    NEW.email,
    v_display_name,
    v_role,
    'active',
    v_admin_key,
    v_referral_code,
    v_referred_by_code,
    CASE WHEN v_role = 'user_admin' THEN 'enterprise' ELSE 'free' END
  );

  -- If signing up as Affiliate, create affiliate profile record
  IF v_role = 'affiliate' THEN
    INSERT INTO public.affiliate_profiles (
      id,
      affiliate_code,
      tier,
      commission_rate,
      status
    )
    VALUES (
      NEW.id,
      v_referral_code,
      'standard',
      0.15,
      'active'
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  -- Process referral code if customer was referred
  IF v_referred_by_code IS NOT NULL AND v_referred_by_code <> '' THEN
    SELECT id INTO v_referrer_id
    FROM public.profiles
    WHERE id IN (SELECT id FROM public.affiliate_profiles WHERE status='active' AND (affiliate_code=v_referred_by_code OR custom_slug=v_referred_by_code));

    IF v_referrer_id IS NOT NULL AND v_referrer_id <> NEW.id THEN
      INSERT INTO public.affiliate_referrals (
        affiliate_id,
        referred_user_id,
        referral_code,
        status,
        bonus_awarded
      )
      VALUES (
        v_referrer_id,
        NEW.id,
        v_referred_by_code,
        'pending',
        0.00
      )
      ON CONFLICT (referred_user_id) DO NOTHING;

      -- Attribute only a matching active campaign owned by the referrer.
      UPDATE public.affiliate_referrals r SET campaign_id=c.id,channel=c.channel
      FROM public.affiliate_campaigns c WHERE r.referred_user_id=NEW.id
       AND c.affiliate_id=v_referrer_id AND c.status='active'
       AND c.slug=NEW.raw_user_meta_data->>'utm_campaign';
      -- Increment signup count; billing qualifies and awards commission later.
      UPDATE public.affiliate_profiles
      SET
        total_referrals = total_referrals + 1
      WHERE id = v_referrer_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


REVOKE ALL ON FUNCTION public.handle_new_user_signup() FROM PUBLIC,anon,authenticated;
INSERT INTO public.affiliate_assets(title,format,body,published) VALUES
('Introduce your trading workspace','Social caption','Plan trades, record your reasoning, and review performance with TradeX. Explore: {link}
Affiliate disclosure: I may earn a commission from qualifying subscriptions.',true),
('A better weekly review','Newsletter','Bring your trading notes, strategies, and research into one workspace. Get started: {link}
Affiliate disclosure: I may receive a commission. Trading involves risk.',true),
('Video description starter','Video','Explore the tools in this walkthrough: {link}
This is an affiliate link. I may earn a commission. Trading involves risk; returns are not guaranteed.',true);
COMMIT;
