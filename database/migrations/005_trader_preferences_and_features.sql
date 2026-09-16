-- Migration 005: Trader Preferences & Risk Checklists Schema

-- 1. Create Trader Preferences Table
CREATE TABLE IF NOT EXISTS public.trader_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  default_position_size_pct NUMERIC NOT NULL DEFAULT 2.0 CHECK (default_position_size_pct > 0 AND default_position_size_pct <= 100),
  default_r_multiple NUMERIC NOT NULL DEFAULT 2.5 CHECK (default_r_multiple > 0),
  default_watchlist_symbols TEXT[] NOT NULL DEFAULT '{"NIFTY50","BANKNIFTY","RELIANCE","TCS","HDFCBANK"}'::text[],
  watchlist_refresh_interval_seconds INTEGER NOT NULL DEFAULT 15 CHECK (watchlist_refresh_interval_seconds >= 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Create Trader Checklists Table
CREATE TABLE IF NOT EXISTS public.trader_checklists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  label TEXT NOT NULL,
  description TEXT,
  done BOOLEAN NOT NULL DEFAULT false,
  icon_name TEXT DEFAULT 'check_box_outline_blank',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for Checklists
CREATE INDEX IF NOT EXISTS idx_trader_checklists_user ON public.trader_checklists(user_id, sort_order ASC);

-- 3. Row-Level Security Policies
ALTER TABLE public.trader_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trader_checklists ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS trader_preferences_own_all ON public.trader_preferences;
CREATE POLICY trader_preferences_own_all ON public.trader_preferences
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS trader_checklists_own_all ON public.trader_checklists;
CREATE POLICY trader_checklists_own_all ON public.trader_checklists
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
