-- Active device sessions & cross-device settings preferences

CREATE TABLE IF NOT EXISTS public.user_device_sessions (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id text NOT NULL,
  device_name text NOT NULL DEFAULT 'Unknown Device',
  platform text NOT NULL DEFAULT 'web',
  browser_or_app text NOT NULL DEFAULT '',
  os_name text NOT NULL DEFAULT '',
  user_agent text NOT NULL DEFAULT '',
  ip_address text NOT NULL DEFAULT '',
  location_hint text NOT NULL DEFAULT '',
  is_revoked boolean NOT NULL DEFAULT false,
  revoked_at timestamptz,
  last_active_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, session_id)
);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_user_active
  ON public.user_device_sessions (user_id, is_revoked, last_active_at DESC);

ALTER TABLE public.user_device_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_device_sessions_select_own" ON public.user_device_sessions;
CREATE POLICY "user_device_sessions_select_own"
  ON public.user_device_sessions
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_device_sessions_insert_own" ON public.user_device_sessions;
CREATE POLICY "user_device_sessions_insert_own"
  ON public.user_device_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_device_sessions_update_own" ON public.user_device_sessions;
CREATE POLICY "user_device_sessions_update_own"
  ON public.user_device_sessions
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_device_sessions_delete_own" ON public.user_device_sessions;
CREATE POLICY "user_device_sessions_delete_own"
  ON public.user_device_sessions
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

REVOKE ALL ON public.user_device_sessions FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_device_sessions TO authenticated;

-- Cross-device settings preferences (AI, security prefs, trading/appearance extras)
CREATE TABLE IF NOT EXISTS public.user_app_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  ai_settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  security_settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  trading_extras jsonb NOT NULL DEFAULT '{}'::jsonb,
  appearance_extras jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_app_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_app_preferences_select_own" ON public.user_app_preferences;
CREATE POLICY "user_app_preferences_select_own"
  ON public.user_app_preferences
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_app_preferences_insert_own" ON public.user_app_preferences;
CREATE POLICY "user_app_preferences_insert_own"
  ON public.user_app_preferences
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "user_app_preferences_update_own" ON public.user_app_preferences;
CREATE POLICY "user_app_preferences_update_own"
  ON public.user_app_preferences
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

REVOKE ALL ON public.user_app_preferences FROM anon;
GRANT SELECT, INSERT, UPDATE ON public.user_app_preferences TO authenticated;

-- Register or heartbeat the current device session
CREATE OR REPLACE FUNCTION public.register_my_device_session(
  p_session_id text,
  p_device_name text DEFAULT NULL,
  p_platform text DEFAULT NULL,
  p_browser_or_app text DEFAULT NULL,
  p_os_name text DEFAULT NULL,
  p_user_agent text DEFAULT NULL,
  p_location_hint text DEFAULT NULL
)
RETURNS public.user_device_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sid text := btrim(COALESCE(p_session_id, ''));
  v_ip text := '';
  v_ua text := btrim(COALESCE(p_user_agent, ''));
  v_row public.user_device_sessions;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF v_sid = '' THEN
    RAISE EXCEPTION 'session_id is required';
  END IF;

  IF pg_catalog.to_regclass('auth.sessions') IS NOT NULL
     AND v_sid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    BEGIN
      EXECUTE 'SELECT COALESCE(host(ip), ''''), COALESCE(user_agent, '''') FROM auth.sessions WHERE id = $1::uuid AND user_id = $2'
        INTO v_ip, v_ua
        USING v_sid, v_uid;
    EXCEPTION WHEN OTHERS THEN
      v_ip := '';
    END;
  END IF;

  IF btrim(COALESCE(p_user_agent, '')) <> '' AND btrim(COALESCE(v_ua, '')) = '' THEN
    v_ua := btrim(p_user_agent);
  END IF;

  INSERT INTO public.user_device_sessions (
    user_id,
    session_id,
    device_name,
    platform,
    browser_or_app,
    os_name,
    user_agent,
    ip_address,
    location_hint,
    is_revoked,
    revoked_at,
    last_active_at,
    created_at
  )
  VALUES (
    v_uid,
    v_sid,
    COALESCE(NULLIF(btrim(p_device_name), ''), 'Active Device'),
    COALESCE(NULLIF(btrim(p_platform), ''), 'web'),
    COALESCE(btrim(p_browser_or_app), ''),
    COALESCE(btrim(p_os_name), ''),
    COALESCE(v_ua, ''),
    COALESCE(v_ip, ''),
    COALESCE(btrim(p_location_hint), ''),
    false,
    NULL,
    now(),
    now()
  )
  ON CONFLICT (user_id, session_id) DO UPDATE SET
    device_name = COALESCE(NULLIF(btrim(p_device_name), ''), public.user_device_sessions.device_name),
    platform = COALESCE(NULLIF(btrim(p_platform), ''), public.user_device_sessions.platform),
    browser_or_app = CASE
      WHEN btrim(COALESCE(p_browser_or_app, '')) <> '' THEN btrim(p_browser_or_app)
      ELSE public.user_device_sessions.browser_or_app
    END,
    os_name = CASE
      WHEN btrim(COALESCE(p_os_name, '')) <> '' THEN btrim(p_os_name)
      ELSE public.user_device_sessions.os_name
    END,
    user_agent = CASE
      WHEN v_ua <> '' THEN v_ua
      ELSE public.user_device_sessions.user_agent
    END,
    ip_address = CASE
      WHEN v_ip <> '' THEN v_ip
      ELSE public.user_device_sessions.ip_address
    END,
    location_hint = CASE
      WHEN btrim(COALESCE(p_location_hint, '')) <> '' THEN btrim(p_location_hint)
      ELSE public.user_device_sessions.location_hint
    END,
    last_active_at = now()
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

-- List active sessions across auth.sessions + user_device_sessions for current user
CREATE OR REPLACE FUNCTION public.list_my_active_sessions()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_auth_items jsonb := '[]'::jsonb;
  v_fallback_items jsonb := '[]'::jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF pg_catalog.to_regclass('auth.sessions') IS NOT NULL THEN
    BEGIN
      EXECUTE $sql$
        SELECT COALESCE(
          jsonb_agg(item ORDER BY last_active_ts DESC),
          '[]'::jsonb
        )
        FROM (
          SELECT
            GREATEST(
              COALESCE(uds.last_active_at, s.updated_at, s.created_at),
              COALESCE(s.refreshed_at::timestamptz, s.updated_at, s.created_at)
            ) AS last_active_ts,
            jsonb_build_object(
              'session_id', s.id::text,
              'device_name', COALESCE(NULLIF(uds.device_name, ''), NULLIF(s.tag, ''), 'Signed-in Device'),
              'platform', COALESCE(NULLIF(uds.platform, ''), 'web'),
              'browser_or_app', COALESCE(uds.browser_or_app, ''),
              'os_name', COALESCE(uds.os_name, ''),
              'user_agent', COALESCE(NULLIF(uds.user_agent, ''), COALESCE(s.user_agent, '')),
              'ip_address', COALESCE(NULLIF(uds.ip_address, ''), COALESCE(host(s.ip), '')),
              'location_hint', COALESCE(uds.location_hint, ''),
              'created_at', s.created_at,
              'last_active_at', GREATEST(
                COALESCE(uds.last_active_at, s.updated_at, s.created_at),
                COALESCE(s.refreshed_at::timestamptz, s.updated_at, s.created_at)
              )
            ) AS item
          FROM auth.sessions s
          LEFT JOIN public.user_device_sessions uds
            ON uds.user_id = s.user_id AND uds.session_id = s.id::text
          WHERE s.user_id = $1
            AND (s.not_after IS NULL OR s.not_after > now())
            AND COALESCE(uds.is_revoked, false) = false
        ) rows
      $sql$
      INTO v_auth_items
      USING v_uid;
    EXCEPTION WHEN OTHERS THEN
      v_auth_items := '[]'::jsonb;
    END;
  END IF;

  IF jsonb_array_length(v_auth_items) > 0 THEN
    RETURN v_auth_items;
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'session_id', uds.session_id,
        'device_name', uds.device_name,
        'platform', uds.platform,
        'browser_or_app', uds.browser_or_app,
        'os_name', uds.os_name,
        'user_agent', uds.user_agent,
        'ip_address', uds.ip_address,
        'location_hint', uds.location_hint,
        'created_at', uds.created_at,
        'last_active_at', uds.last_active_at
      )
      ORDER BY uds.last_active_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_fallback_items
  FROM public.user_device_sessions uds
  WHERE uds.user_id = v_uid
    AND uds.is_revoked = false
    AND uds.last_active_at > now() - interval '60 days';

  RETURN v_fallback_items;
END;
$$;

-- Revoke a specific session belonging strictly to auth.uid()
CREATE OR REPLACE FUNCTION public.revoke_my_session(p_session_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_sid text := btrim(COALESCE(p_session_id, ''));
  v_deleted integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF v_sid = '' THEN
    RAISE EXCEPTION 'session_id is required';
  END IF;

  UPDATE public.user_device_sessions
  SET is_revoked = true,
      revoked_at = now()
  WHERE user_id = v_uid
    AND session_id = v_sid;

  IF pg_catalog.to_regclass('auth.sessions') IS NOT NULL
     AND v_sid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    EXECUTE 'DELETE FROM auth.sessions WHERE id = $1::uuid AND user_id = $2'
      USING v_sid, v_uid;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'revoked', true,
    'session_id', v_sid,
    'auth_sessions_deleted', v_deleted
  );
END;
$$;

-- Revoke every session except the kept session for auth.uid()
CREATE OR REPLACE FUNCTION public.revoke_other_my_sessions(p_keep_session_id text DEFAULT '')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_keep text := btrim(COALESCE(p_keep_session_id, ''));
  v_deleted integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.user_device_sessions
  SET is_revoked = true,
      revoked_at = now()
  WHERE user_id = v_uid
    AND (v_keep = '' OR session_id <> v_keep)
    AND is_revoked = false;

  IF pg_catalog.to_regclass('auth.sessions') IS NOT NULL THEN
    IF v_keep ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      EXECUTE 'DELETE FROM auth.sessions WHERE user_id = $1 AND id <> $2::uuid'
        USING v_uid, v_keep;
    ELSE
      EXECUTE 'DELETE FROM auth.sessions WHERE user_id = $1'
        USING v_uid;
    END IF;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'revoked', true,
    'kept_session_id', v_keep,
    'auth_sessions_deleted', v_deleted
  );
END;
$$;

REVOKE ALL ON FUNCTION public.register_my_device_session(text, text, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_my_device_session(text, text, text, text, text, text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.list_my_active_sessions() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_my_active_sessions() TO authenticated;

REVOKE ALL ON FUNCTION public.revoke_my_session(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.revoke_my_session(text) TO authenticated;

REVOKE ALL ON FUNCTION public.revoke_other_my_sessions(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.revoke_other_my_sessions(text) TO authenticated;
