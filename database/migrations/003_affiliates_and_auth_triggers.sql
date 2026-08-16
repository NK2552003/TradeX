-- Migration 003: Affiliate system schema and automated auth.users triggers

-- 1. Create Affiliate Profiles Table
CREATE TABLE IF NOT EXISTS affiliate_profiles (
  id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  affiliate_code TEXT UNIQUE NOT NULL,
  tier TEXT NOT NULL DEFAULT 'standard' CHECK (tier IN ('standard', 'silver', 'gold', 'platinum')),
  commission_rate NUMERIC NOT NULL DEFAULT 0.15 CHECK (commission_rate >= 0.0 AND commission_rate <= 1.0),
  total_referrals INTEGER NOT NULL DEFAULT 0 CHECK (total_referrals >= 0),
  active_referrals INTEGER NOT NULL DEFAULT 0 CHECK (active_referrals >= 0),
  total_earnings NUMERIC NOT NULL DEFAULT 0.00 CHECK (total_earnings >= 0.0),
  unpaid_balance NUMERIC NOT NULL DEFAULT 0.00 CHECK (unpaid_balance >= 0.0),
  paid_earnings NUMERIC NOT NULL DEFAULT 0.00 CHECK (paid_earnings >= 0.0),
  payout_method TEXT CHECK (payout_method IN ('bank_transfer', 'paypal', 'stripe', 'crypto')),
  payout_details JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('pending', 'active', 'suspended')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Create Affiliate Referrals Table (tracking customer conversion to affiliate)
CREATE TABLE IF NOT EXISTS affiliate_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  referred_user_id UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  referral_code TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'converted' CHECK (status IN ('pending', 'converted', 'churned')),
  bonus_awarded NUMERIC NOT NULL DEFAULT 50.00 CHECK (bonus_awarded >= 0.0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Create Affiliate Payouts Table
CREATE TABLE IF NOT EXISTS affiliate_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  currency TEXT NOT NULL DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'paid', 'failed', 'cancelled')),
  payout_method TEXT,
  transaction_reference TEXT,
  notes TEXT,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for Affiliate queries
CREATE INDEX IF NOT EXISTS idx_affiliate_profiles_code ON affiliate_profiles(affiliate_code);
CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_affiliate ON affiliate_referrals(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_referred ON affiliate_referrals(referred_user_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_payouts_affiliate ON affiliate_payouts(affiliate_id, status);

-- 4. Automated User Sign-up Trigger Function for Supabase auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user_signup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
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
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'customer');
  v_handle := COALESCE(NEW.raw_user_meta_data->>'handle', LOWER(SPLIT_PART(NEW.email, '@', 1)));
  v_display_name := COALESCE(NEW.raw_user_meta_data->>'display_name', SPLIT_PART(NEW.email, '@', 1));
  v_admin_key := NEW.raw_user_meta_data->>'admin_key';
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
    WHERE referral_code = v_referred_by_code OR handle = v_referred_by_code;

    IF v_referrer_id IS NOT NULL THEN
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
        'converted',
        50.00
      )
      ON CONFLICT (referred_user_id) DO NOTHING;

      -- Increment referral stats for affiliate profile if applicable
      UPDATE public.affiliate_profiles
      SET 
        total_referrals = total_referrals + 1,
        active_referrals = active_referrals + 1,
        unpaid_balance = unpaid_balance + 50.00,
        total_earnings = total_earnings + 50.00
      WHERE id = v_referrer_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger binding to auth.users (if running inside Supabase context)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_signup();
