BEGIN;

-- Restore the canonical registration-cap function when an older partial
-- migration history did not create it.
CREATE OR REPLACE FUNCTION public.enforce_user_registration_cap()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_non_admin_count integer;
BEGIN
  IF NEW.role = 'user_admin' THEN
    RETURN NEW;
  END IF;

  SELECT COUNT(*)::integer
    INTO v_non_admin_count
    FROM public.profiles
   WHERE role <> 'user_admin';

  IF v_non_admin_count >= 100 THEN
    RAISE EXCEPTION 'Platform capacity reached (100 users). New user registration is currently disabled.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.profiles') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_enforce_user_registration_cap ON public.profiles;
    CREATE TRIGGER trg_enforce_user_registration_cap
      BEFORE INSERT ON public.profiles
      FOR EACH ROW
      EXECUTE FUNCTION public.enforce_user_registration_cap();
  END IF;
END
$$;

REVOKE ALL ON FUNCTION public.enforce_user_registration_cap()
  FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
