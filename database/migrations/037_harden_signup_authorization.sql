-- Migration 037: Harden Signup Authorization, Role/Tier Defaults, and OTP Security
-- Never trust self-signup raw_user_meta_data for admin authorization or enterprise entitlements.

BEGIN;

-- 1. Hardened signup trigger: strictly force role='customer', admin_key=NULL, tier='free'
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
  -- Self-signup is strictly restricted to customer role with free tier.
  -- Metadata role, admin_key, and tier are deliberately ignored to prevent privilege escalation.
  v_role := 'customer';
  v_admin_key := NULL;
  v_handle := COALESCE(NEW.raw_user_meta_data->>'handle', LOWER(SPLIT_PART(NEW.email, '@', 1)));
  v_display_name := COALESCE(NEW.raw_user_meta_data->>'display_name', SPLIT_PART(NEW.email, '@', 1));
  v_referral_code := COALESCE(NEW.raw_user_meta_data->>'referral_code', 'REF-' || UPPER(SUBSTRING(gen_random_uuid()::text FROM 1 FOR 8)));
  v_referred_by_code := NEW.raw_user_meta_data->>'referred_by_code';

  -- Insert into public.profiles with guaranteed safe defaults
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
    'free'
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    updated_at = now();

  -- Process referral attribution if present
  IF v_referred_by_code IS NOT NULL AND v_referred_by_code <> '' THEN
    SELECT id INTO v_referrer_id
    FROM public.affiliate_profiles
    WHERE affiliate_code = v_referred_by_code;

    IF v_referrer_id IS NOT NULL THEN
      INSERT INTO public.affiliate_referrals (
        referrer_id,
        referred_user_id,
        status,
        attributed_at
      )
      VALUES (
        v_referrer_id,
        NEW.id,
        'active',
        now()
      )
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Secure execution privileges
REVOKE ALL ON FUNCTION public.handle_new_user_signup() FROM PUBLIC, anon, authenticated;

-- 2. Guard profile updates against self-promotion to admin or arbitrary role tampering
CREATE OR REPLACE FUNCTION public.affiliate_guard_profile_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  IF current_user IN ('authenticated', 'anon') THEN
    IF TG_OP = 'INSERT' THEN
      IF NEW.role <> 'customer'
         OR NEW.admin_key IS NOT NULL
         OR (NEW.subscription_tier <> 'free' AND NOT public.is_user_admin()) THEN
        RAISE EXCEPTION 'Role and entitlement assignment is server managed';
      END IF;
    ELSIF NEW.role IS DISTINCT FROM OLD.role OR NEW.admin_key IS DISTINCT FROM OLD.admin_key THEN
      RAISE EXCEPTION 'Role assignment is server managed';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.affiliate_guard_profile_role() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS affiliate_guard_profile_role ON public.profiles;
CREATE TRIGGER affiliate_guard_profile_role
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.affiliate_guard_profile_role();

COMMIT;
