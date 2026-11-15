-- Enable real-time Postgres Changes streaming for all chat tables and
-- guarantee profile provisioning for OAuth (e.g. Google) sign-ins.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Enable Supabase Realtime replication for chat messaging tables
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_table text;
  v_tables text[] := ARRAY[
    'chat_threads',
    'chat_participants',
    'chat_messages',
    'chat_reactions',
    'messages',
    'conversations'
  ];
BEGIN
  FOREACH v_table IN ARRAY v_tables LOOP
    IF to_regclass('public.' || v_table) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', v_table);
      IF EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
      ) AND NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = v_table
      ) THEN
        EXECUTE format(
          'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
          v_table
        );
      END IF;
    END IF;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 2. Guaranteed profile creation for OAuth / new auth users
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM public, anon, authenticated;

CREATE OR REPLACE FUNCTION private.provision_profile_for_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_email text;
  v_meta jsonb;
  v_display_name text;
  v_avatar text;
  v_raw_handle text;
  v_base_handle text;
  v_candidate_handle text;
  v_suffix text;
  v_referral_code text;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
    RETURN;
  END IF;

  SELECT u.email, COALESCE(u.raw_user_meta_data, '{}'::jsonb)
  INTO v_email, v_meta
  FROM auth.users u
  WHERE u.id = p_user_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_email := COALESCE(lower(trim(v_email)), '');
  v_display_name := COALESCE(
    NULLIF(trim(v_meta->>'full_name'), ''),
    NULLIF(trim(v_meta->>'name'), ''),
    NULLIF(split_part(v_email, '@', 1), ''),
    'Trader'
  );
  v_avatar := COALESCE(
    NULLIF(trim(v_meta->>'avatar_url'), ''),
    NULLIF(trim(v_meta->>'picture'), '')
  );

  v_raw_handle := COALESCE(
    NULLIF(trim(v_meta->>'handle'), ''),
    NULLIF(trim(v_meta->>'user_name'), ''),
    NULLIF(trim(v_meta->>'preferred_username'), ''),
    NULLIF(split_part(v_email, '@', 1), ''),
    ''
  );
  v_base_handle := regexp_replace(lower(regexp_replace(v_raw_handle, '^@+', '')), '[^a-z0-9_]+', '_', 'g');
  v_base_handle := trim(both '_' from v_base_handle);
  v_suffix := lower(substr(replace(p_user_id::text, '-', ''), 1, 6));
  IF length(v_base_handle) < 3 THEN
    v_base_handle := 'trader_' || v_suffix;
  END IF;

  v_candidate_handle := '@' || v_base_handle;
  IF EXISTS (
    SELECT 1 FROM public.profiles WHERE lower(handle) = lower(v_candidate_handle)
  ) THEN
    v_candidate_handle := '@' || left(v_base_handle, 20) || '_' || v_suffix;
  END IF;

  v_referral_code := 'REF-TRADEX-' || upper(v_suffix);

  INSERT INTO public.profiles (
    id,
    handle,
    email,
    display_name,
    role,
    status,
    referral_code,
    avatar_url,
    created_at,
    updated_at
  )
  VALUES (
    p_user_id,
    v_candidate_handle,
    v_email,
    v_display_name,
    'customer',
    'active',
    v_referral_code,
    v_avatar,
    now(),
    now()
  )
  ON CONFLICT (id) DO NOTHING;
EXCEPTION WHEN unique_violation THEN
  v_candidate_handle := '@' || left(v_base_handle, 16) || '_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  INSERT INTO public.profiles (
    id,
    handle,
    email,
    display_name,
    role,
    status,
    referral_code,
    avatar_url,
    created_at,
    updated_at
  )
  VALUES (
    p_user_id,
    v_candidate_handle,
    v_email,
    v_display_name,
    'customer',
    'active',
    v_referral_code,
    v_avatar,
    now(),
    now()
  )
  ON CONFLICT (id) DO NOTHING;
END $$;

REVOKE ALL ON FUNCTION private.provision_profile_for_user(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM private.provision_profile_for_user(NEW.id);
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never block auth signup/OAuth if cap or profile hook raises asynchronously.
  RETURN NEW;
END $$;

REVOKE ALL ON FUNCTION private.handle_new_auth_user() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION private.handle_new_auth_user();

CREATE OR REPLACE FUNCTION public.ensure_own_profile()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  PERFORM private.provision_profile_for_user(v_uid);
END $$;

REVOKE ALL ON FUNCTION public.ensure_own_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_own_profile() TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
