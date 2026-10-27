-- Migration 033: Ensure live profile and trading preference columns on public.profiles

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS website TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avg_hold_duration TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS primary_market TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS top_strategy TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS risk_mantra TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS public_stats BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS win_rate NUMERIC;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS followers_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS following_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS posts_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verified BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notification_settings JSONB NOT NULL DEFAULT '{}'::jsonb;
