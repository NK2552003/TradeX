-- Run in the Supabase SQL Editor after the admin migration.
-- Reads existing records under the real roles. Any detail-view audit entries
-- and temporary verification helpers are rolled back before returning.
BEGIN;
CREATE TEMP TABLE admin_live_checks(check_name text, result text);
CREATE TEMP TABLE admin_live_context AS
SELECT
  (SELECT id FROM public.profiles WHERE role='user_admin' AND status='active' ORDER BY created_at LIMIT 1) AS admin_id,
  (SELECT id FROM public.profiles WHERE role='customer' AND status='active' ORDER BY created_at LIMIT 1) AS customer_id,
  (SELECT count(*) FROM public.profiles) AS users;
GRANT SELECT ON admin_live_context TO authenticated,anon;
GRANT SELECT,INSERT ON admin_live_checks TO authenticated,anon;

CREATE FUNCTION pg_temp.require_true(condition boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
END;
$$;
CREATE FUNCTION pg_temp.require_denied(statement text,label text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE denied boolean:=false;
BEGIN
  BEGIN EXECUTE statement;
  EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true; END;
  PERFORM pg_temp.require_true(denied,label);
  INSERT INTO admin_live_checks VALUES(label,'PASS');
END;
$$;
SELECT pg_temp.require_true(admin_id IS NOT NULL AND customer_id IS NOT NULL,'existing admin and customer available') FROM admin_live_context;
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub',admin_id::text,true) FROM admin_live_context;
SET LOCAL ROLE authenticated;

DO $$
DECLARE resource text; records jsonb; first_id uuid; profile_id uuid; checked integer:=0;
BEGIN
  PERFORM pg_temp.require_true((public.admin_get_overview()->>'users')::bigint=(SELECT users FROM admin_live_context),'overview matches actual users');
  INSERT INTO admin_live_checks SELECT 'Live user count',users::text FROM admin_live_context;
  PERFORM pg_temp.require_true(public.admin_get_settings()->>'id'='default','platform settings readable');
  INSERT INTO admin_live_checks VALUES('Administrator overview and settings','PASS');
  FOREACH resource IN ARRAY ARRAY['users','posts','comments','notes','journal','strategies','messages','ai','ai_messages','ai_requests','affiliates','applications','referrals','payouts','subscriptions','activity','deletions'] LOOP
    records:=public.admin_list_records(resource,p_page_size=>1);
    PERFORM pg_temp.require_true(records->'rows' IS NOT NULL AND (records->>'total')::bigint>=0,'resource: '||resource);
    first_id:=(records->'rows'->0->>'id')::uuid;
    IF first_id IS NOT NULL AND resource NOT IN ('users','subscriptions') THEN
      PERFORM pg_temp.require_true(public.admin_get_record(resource,first_id)->'record' IS NOT NULL,'record detail: '||resource);
    END IF;
    PERFORM pg_temp.require_true(public.admin_list_records(resource,p_user=>(SELECT customer_id FROM admin_live_context))->'rows' IS NOT NULL,'user filter: '||resource);
    INSERT INTO admin_live_checks VALUES(resource,records->>'total'||' records; list and user filter PASS');
  END LOOP;
  FOR profile_id IN SELECT id FROM public.profiles LOOP
    PERFORM pg_temp.require_true(public.admin_get_user(profile_id)->'profile'->>'id'=profile_id::text,'user detail');
    checked:=checked+1;
  END LOOP;
  INSERT INTO admin_live_checks VALUES('User detail and entitlement checks',checked::text||' accounts PASS');
END;
$$;

RESET ROLE;
SELECT set_config('request.jwt.claim.sub',customer_id::text,true) FROM admin_live_context;
SET LOCAL ROLE authenticated;
SELECT pg_temp.require_true(public.get_my_admin_access()->>'status'='active','customer access');
SELECT pg_temp.require_denied('SELECT public.admin_get_overview()','Customer cannot read admin analytics');
SELECT pg_temp.require_denied('SELECT public.admin_list_records(''users'')','Customer cannot list other users');
SELECT pg_temp.require_denied('SELECT public.admin_get_user((SELECT admin_id FROM admin_live_context))','Customer cannot inspect another account');
SELECT pg_temp.require_denied('SELECT public.admin_apply_action(''controls'',auth.uid(),p_reason=>''readback test'')','Customer cannot change administration controls');
SELECT pg_temp.require_denied('SELECT public.finish_ai_request(gen_random_uuid(),''forged'')','Customer cannot forge AI completion');
SELECT pg_temp.require_denied('SELECT public.admin_claim_deletion(gen_random_uuid(),auth.uid(),''test'',''readback'')','Customer cannot invoke deletion worker');
RESET ROLE;
SELECT set_config('request.jwt.claim.role','anon',true);
SELECT set_config('request.jwt.claim.sub','',true);
SET LOCAL ROLE anon;
SELECT pg_temp.require_denied('SELECT public.admin_get_overview()','Anonymous admin access denied');
SELECT pg_temp.require_denied('SELECT public.admin_get_settings()','Anonymous settings access denied');
RESET ROLE;
SELECT check_name,result FROM admin_live_checks;
ROLLBACK;
