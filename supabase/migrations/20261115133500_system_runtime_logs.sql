-- Persistent runtime log archive complementing Supabase Logs Explorer
-- (which retains 1 day on the Free plan). Service roles write operational
-- telemetry here; only active platform admins can read it.

CREATE TABLE IF NOT EXISTS public.system_runtime_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service text NOT NULL CHECK (char_length(trim(service)) > 0),
  level text NOT NULL DEFAULT 'info' CHECK (level IN ('debug', 'info', 'warn', 'error')),
  event text NOT NULL CHECK (char_length(trim(event)) > 0),
  request_id text,
  status integer CHECK (status IS NULL OR (status >= 100 AND status <= 599)),
  duration_ms integer CHECK (duration_ms IS NULL OR duration_ms >= 0),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS system_runtime_logs_created_idx
  ON public.system_runtime_logs (created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS system_runtime_logs_service_level_idx
  ON public.system_runtime_logs (service, level, created_at DESC);

ALTER TABLE public.system_runtime_logs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.system_runtime_logs FROM anon, authenticated;
GRANT SELECT ON public.system_runtime_logs TO authenticated;
GRANT ALL ON public.system_runtime_logs TO service_role;

DROP POLICY IF EXISTS admin_only_read_system_runtime_logs ON public.system_runtime_logs;
CREATE POLICY admin_only_read_system_runtime_logs
  ON public.system_runtime_logs
  FOR SELECT
  TO authenticated
  USING ((SELECT tradex_private.is_admin()));

CREATE OR REPLACE FUNCTION tradex_private.write_system_runtime_log(
  p_service text,
  p_level text,
  p_event text,
  p_request_id text DEFAULT NULL,
  p_status integer DEFAULT NULL,
  p_duration_ms integer DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
  v_level text := CASE WHEN p_level IN ('debug', 'info', 'warn', 'error') THEN p_level ELSE 'info' END;
BEGIN
  INSERT INTO public.system_runtime_logs (
    service,
    level,
    event,
    request_id,
    status,
    duration_ms,
    metadata
  )
  VALUES (
    left(trim(coalesce(p_service, 'system')), 80),
    v_level,
    left(trim(coalesce(p_event, 'event')), 120),
    left(nullif(trim(coalesce(p_request_id, '')), ''), 120),
    p_status,
    CASE WHEN p_duration_ms IS NOT NULL AND p_duration_ms >= 0 THEN p_duration_ms ELSE NULL END,
    coalesce(p_metadata, '{}'::jsonb)
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.prune_system_runtime_logs(
  p_keep_days integer DEFAULT 30
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_deleted integer := 0;
  v_days integer := GREATEST(1, coalesce(p_keep_days, 30));
BEGIN
  DELETE FROM public.system_runtime_logs
  WHERE created_at < now() - make_interval(days => v_days);

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

REVOKE ALL ON FUNCTION tradex_private.write_system_runtime_log(text, text, text, text, integer, integer, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION tradex_private.write_system_runtime_log(text, text, text, text, integer, integer, jsonb) TO service_role;

REVOKE ALL ON FUNCTION tradex_private.prune_system_runtime_logs(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION tradex_private.prune_system_runtime_logs(integer) TO service_role;
