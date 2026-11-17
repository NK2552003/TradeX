-- Keep push delivery and client notification preferences on the same owned row.
-- This is additive and safe to re-run against projects that received legacy
-- database/migrations/006_notifications_and_security.sql.
alter table public.trader_preferences
  add column if not exists notification_settings jsonb not null default '{}'::jsonb;

comment on column public.trader_preferences.notification_settings is
  'Per-user notification channel, category, and quiet-hours preferences.';
