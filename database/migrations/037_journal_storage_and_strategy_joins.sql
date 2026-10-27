-- =============================================================================
-- Migration 037: Reconcile Strategy Joins & Harden Journal Private Attachments
--
-- 1. Adds `name` column to `strategies` and keeps it in sync with `title`
--    so PostgREST joins on either `strategies(title)` or `strategies(name)` succeed.
-- 2. Adds `strategy_name` mirror to `journal_entries` for fast reads.
-- 3. Ensures RLS policies on `journal_entry_attachments` and storage objects
--    for `journal-attachments` are strictly owner-only (zero public read).
-- =============================================================================

BEGIN;

-- 1. Strategies: Add `name` column and synchronize with `title`
ALTER TABLE public.strategies ADD COLUMN IF NOT EXISTS name TEXT;

-- Backfill existing strategies
UPDATE public.strategies
SET name = title
WHERE name IS NULL OR name = '';

-- Trigger function to bi-directionally sync `title` and `name`
CREATE OR REPLACE FUNCTION public.sync_strategy_title_and_name()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.title IS NOT NULL AND (NEW.name IS NULL OR NEW.name = '') THEN
    NEW.name := NEW.title;
  ELSIF NEW.name IS NOT NULL AND (NEW.title IS NULL OR NEW.title = '') THEN
    NEW.title := NEW.name;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.title IS DISTINCT FROM OLD.title AND NEW.name IS NOT DISTINCT FROM OLD.name THEN
      NEW.name := NEW.title;
    ELSIF NEW.name IS DISTINCT FROM OLD.name AND NEW.title IS NOT DISTINCT FROM OLD.title THEN
      NEW.title := NEW.name;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_strategy_title_and_name ON public.strategies;
CREATE TRIGGER trg_sync_strategy_title_and_name
  BEFORE INSERT OR UPDATE ON public.strategies
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_strategy_title_and_name();

-- 2. Journal Entries: Add `strategy_name` mirror column
ALTER TABLE public.journal_entries ADD COLUMN IF NOT EXISTS strategy_name TEXT;

-- Backfill `strategy_name` from joined strategies
UPDATE public.journal_entries j
SET strategy_name = s.title
FROM public.strategies s
WHERE j.strategy_id = s.id
  AND (j.strategy_name IS NULL OR j.strategy_name = '');

-- Trigger function to populate `strategy_name` when `strategy_id` is set
CREATE OR REPLACE FUNCTION public.sync_journal_entry_strategy_name()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.strategy_id IS NOT NULL THEN
    SELECT COALESCE(s.title, s.name) INTO NEW.strategy_name
    FROM public.strategies s
    WHERE s.id = NEW.strategy_id;
  ELSE
    NEW.strategy_name := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_journal_entry_strategy_name ON public.journal_entries;
CREATE TRIGGER trg_sync_journal_entry_strategy_name
  BEFORE INSERT OR UPDATE OF strategy_id ON public.journal_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_journal_entry_strategy_name();

-- 3. Journal Entry Attachments: Table & RLS verification
CREATE TABLE IF NOT EXISTS public.journal_entry_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id UUID NOT NULL REFERENCES public.journal_entries(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  storage_path TEXT NOT NULL UNIQUE,
  filename TEXT NOT NULL,
  mime_type TEXT,
  byte_size BIGINT CHECK (byte_size IS NULL OR byte_size BETWEEN 0 AND 15728640),
  is_image BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.journal_entry_attachments ENABLE ROW LEVEL SECURITY;

-- Owner-only table access: zero public read
DROP POLICY IF EXISTS journal_entry_attachments_own_all ON public.journal_entry_attachments;
CREATE POLICY journal_entry_attachments_own_all ON public.journal_entry_attachments
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (
  auth.uid() = user_id
  AND auth.uid() = (
    SELECT e.user_id FROM public.journal_entries e WHERE e.id = journal_entry_attachments.entry_id
  )
);

-- Ensure storage bucket `journal-attachments` exists and is strictly private
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'journal-attachments',
  'journal-attachments',
  false,
  15728640, -- 15 MB
  ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'text/csv', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 15728640,
  allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'text/csv', 'application/pdf'];

-- Owner-only storage policy on storage.objects
DROP POLICY IF EXISTS journal_attachments_owner_all ON storage.objects;
CREATE POLICY journal_attachments_owner_all ON storage.objects
FOR ALL
TO authenticated
USING (
  bucket_id = 'journal-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'journal-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Revoke any anonymous or public read policy on journal-attachments storage
DROP POLICY IF EXISTS journal_attachments_public_read ON storage.objects;

COMMIT;
