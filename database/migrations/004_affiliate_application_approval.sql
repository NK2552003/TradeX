-- Migration 004: Affiliate Application table & Approval Stored Procedure (RPC)

-- 1. Create Affiliate Applications Table
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
AS $$
DECLARE
  v_app RECORD;
  v_referral_code TEXT;
BEGIN
  -- Fetch application
  SELECT * INTO v_app
  FROM public.affiliate_applications
  WHERE id = p_application_id;

  IF v_app IS NULL THEN
    RAISE EXCEPTION 'Application not found with ID %', p_application_id;
  END IF;

  IF v_app.status = 'approved' THEN
    RETURN jsonb_build_object('success', true, 'message', 'Application already approved');
  END IF;

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
    CASE WHEN v_app.upi_id IS NOT NULL THEN 'upi' ELSE 'bank_transfer' END,
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
