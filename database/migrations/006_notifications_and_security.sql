-- Migration 006: Notifications, Organizations & Desk Risk Policies Schema

-- 1. Add notification_settings to trader_preferences
ALTER TABLE public.trader_preferences
  ADD COLUMN IF NOT EXISTS notification_settings JSONB NOT NULL DEFAULT '{}'::jsonb;

-- 2. Organizations Table
CREATE TABLE IF NOT EXISTS public.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  api_keys JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Desk Risk Policies Table
CREATE TABLE IF NOT EXISTS public.desk_risk_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE ON UPDATE CASCADE,
  admin_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  max_drawdown_pct NUMERIC NOT NULL DEFAULT 5.0,
  max_leverage NUMERIC NOT NULL DEFAULT 10.0,
  blocked_tickers TEXT[] NOT NULL DEFAULT '{}'::text[],
  require_stop_loss BOOLEAN NOT NULL DEFAULT true,
  auto_cut_loss BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS Policies
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.desk_risk_policies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS orgs_owner_all ON public.organizations;
CREATE POLICY orgs_owner_all ON public.organizations
  FOR ALL USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS desk_risk_admin_all ON public.desk_risk_policies;
CREATE POLICY desk_risk_admin_all ON public.desk_risk_policies
  FOR ALL USING (auth.uid() = admin_id) WITH CHECK (auth.uid() = admin_id);
