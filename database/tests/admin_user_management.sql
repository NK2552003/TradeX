-- Run with psql -v ON_ERROR_STOP=1 or in the authenticated Supabase SQL Editor.
-- Every fixture, change and helper is rolled back.
BEGIN;
SELECT set_config('request.jwt.claim.role','service_role',true);
-- Exercise public-content policies even when a local fixture has older grants.
-- These grants, like the test records, disappear at ROLLBACK.
GRANT SELECT ON public.community_posts,public.community_comments TO anon;
CREATE TEMP TABLE admin_test_results(check_name text,result text);
GRANT SELECT,INSERT ON admin_test_results TO authenticated,anon,service_role;
CREATE TEMP TABLE admin_test_ids(name text PRIMARY KEY,id uuid NOT NULL DEFAULT gen_random_uuid());
INSERT INTO admin_test_ids(name) VALUES ('admin'),('user'),('stranger'),('delete_user'),('post'),('pending_post'),('public_comment'),('pending_comment'),('pending_parent_comment'),('note'),('application'),('thread'),('ai_thread');
GRANT SELECT ON admin_test_ids TO authenticated,anon,service_role;
CREATE FUNCTION pg_temp.test_id(p_name text) RETURNS uuid LANGUAGE sql AS $$
  SELECT id FROM pg_temp.admin_test_ids WHERE name=p_name;
$$;
CREATE FUNCTION pg_temp.assert_true(condition boolean,label text) RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
  INSERT INTO pg_temp.admin_test_results VALUES(label,'PASS');
  RETURN 'PASS: '||label;
END;
$$;
CREATE FUNCTION pg_temp.assert_denied(statement text,label text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE denied boolean := false;
BEGIN
  BEGIN EXECUTE statement;
  EXCEPTION WHEN SQLSTATE '42501' OR SQLSTATE 'P0001' OR SQLSTATE '22023' THEN denied:=true; END;
  RETURN pg_temp.assert_true(denied,label);
END;
$$;
INSERT INTO auth.users(id,email)
  SELECT id,'admin-check-'||name||'@example.invalid' FROM admin_test_ids WHERE name IN ('admin','user','stranger','delete_user');
INSERT INTO public.profiles(id,handle,display_name,email,role,status)
  SELECT id,'admincheck_'||name,'Admin check '||name,'admin-check-'||name||'@example.invalid',
    CASE WHEN name='admin' THEN 'user_admin' ELSE 'customer' END,'active'
  FROM admin_test_ids WHERE name IN ('admin','user','stranger','delete_user')
  ON CONFLICT(id) DO UPDATE SET role=excluded.role,status=excluded.status,handle=excluded.handle;
INSERT INTO public.community_posts(id,author_id,title,body,moderation_status,is_public)
  VALUES(pg_temp.test_id('post'),pg_temp.test_id('user'),'Admin regression post','Pending review','pending',true),
    (pg_temp.test_id('pending_post'),pg_temp.test_id('user'),'Unreviewed regression post','Not public before approval','pending',true);
INSERT INTO public.community_comments(id,post_id,author_id,body,moderation_status)
  VALUES(pg_temp.test_id('public_comment'),pg_temp.test_id('post'),pg_temp.test_id('user'),'Comment for approval','pending'),
    (pg_temp.test_id('pending_comment'),pg_temp.test_id('post'),pg_temp.test_id('user'),'Unreviewed comment','pending'),
    (pg_temp.test_id('pending_parent_comment'),pg_temp.test_id('pending_post'),pg_temp.test_id('user'),'Comment under unreviewed post','pending');
INSERT INTO public.trader_notes(id,user_id,title,is_public)
  VALUES(pg_temp.test_id('note'),pg_temp.test_id('user'),'Admin regression note',true);
INSERT INTO public.affiliate_applications(id,user_id,full_name,email,status,upi_id,account_holder)
  VALUES(pg_temp.test_id('application'),pg_temp.test_id('user'),'Admin check user','admin-check-user@example.invalid','pending','test@bank','Test User');
INSERT INTO public.chat_threads(id,created_by,title)
  VALUES(pg_temp.test_id('thread'),pg_temp.test_id('user'),'Private test conversation');
INSERT INTO public.chat_participants(thread_id,user_id)
  VALUES(pg_temp.test_id('thread'),pg_temp.test_id('user'));

SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub',pg_temp.test_id('user')::text,true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(public.get_my_admin_access()->>'status'='active','current account access');
SELECT pg_temp.assert_denied('SELECT public.admin_get_overview()','customers cannot read admin analytics');
SELECT pg_temp.assert_denied('SELECT public.admin_get_user(pg_temp.test_id(''stranger''))','customers cannot read user details');
SELECT pg_temp.assert_denied('SELECT public.admin_apply_action(''controls'',pg_temp.test_id(''user''),p_reason=>''bypass'')','customers cannot change permissions');
SELECT pg_temp.assert_denied('UPDATE public.profiles SET role=''user_admin'' WHERE id=auth.uid()','customers cannot elevate their role');
SELECT pg_temp.assert_denied('UPDATE public.profiles SET admin_controls=''{"features":{"ai":false}}'' WHERE id=auth.uid()','customers cannot edit controls directly');
SELECT pg_temp.assert_denied('DELETE FROM public.admin_audit_logs','audit history cannot be erased by customers');
SELECT pg_temp.assert_denied('SELECT public.finish_ai_request(gen_random_uuid(),''forged'')','clients cannot forge AI output');
SELECT pg_temp.assert_denied('SELECT public.admin_claim_deletion(gen_random_uuid(),auth.uid(),''handle'',''bypass'')','clients cannot claim account deletion');
SELECT pg_temp.assert_true((SELECT count(*) FROM public.chat_threads WHERE id=pg_temp.test_id('thread'))=1,'conversation owner can read without RLS recursion');

RESET ROLE;
SELECT set_config('request.jwt.claim.sub',pg_temp.test_id('stranger')::text,true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true((SELECT count(*) FROM public.chat_participants WHERE thread_id=pg_temp.test_id('thread'))=0,'conversation membership is private');
SELECT pg_temp.assert_denied('INSERT INTO public.chat_participants(thread_id,user_id) VALUES(pg_temp.test_id(''thread''),auth.uid())','strangers cannot join private conversations');

RESET ROLE;
SELECT set_config('request.jwt.claim.sub',pg_temp.test_id('admin')::text,true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true((public.admin_get_overview()->>'users')::integer=(SELECT count(*) FROM public.profiles),'analytics count actual profiles');
SELECT pg_temp.assert_true((public.admin_list_records('users',p_user=>pg_temp.test_id('user'))->>'total')::integer=1,'user filter is exact');
SELECT pg_temp.assert_true(jsonb_array_length(public.admin_list_records('users',p_page_size=>1)->'rows')=1,'record lists are paginated');
SELECT pg_temp.assert_true(public.admin_list_records(resource)->'rows' IS NOT NULL,'read resource: '||resource)
  FROM unnest(ARRAY['users','posts','comments','notes','journal','strategies','messages','ai','ai_messages','ai_requests','affiliates','applications','referrals','payouts','subscriptions','activity','deletions']) resource;
SELECT pg_temp.assert_denied('SELECT public.admin_apply_action(''admin_note'',pg_temp.test_id(''user''),p_reason=>NULL)','administration requires an audit reason');
SELECT pg_temp.assert_denied('SELECT public.admin_apply_action(''role'',auth.uid(),p_value=>''{"role":"customer"}'',p_reason=>''self demotion'')','administrators cannot remove their own role');
SELECT public.admin_apply_action('controls',pg_temp.test_id('user'),p_value=>'{"features":{"posts":false,"notes":false},"limits":{"notes":1,"ai_queries_per_month":1,"ai_queries_per_day":1}}',p_reason=>'Test user restrictions');
SELECT public.admin_apply_action('moderate_post',pg_temp.test_id('user'),pg_temp.test_id('post'),'{"status":"approved"}','Reviewed test content');
SELECT public.admin_apply_action('moderate_comment',pg_temp.test_id('user'),pg_temp.test_id('public_comment'),'{"status":"approved"}','Reviewed test comment');
SELECT public.admin_apply_action('moderate_comment',pg_temp.test_id('user'),pg_temp.test_id('pending_parent_comment'),'{"status":"approved"}','Reviewed comment still requires approved parent');
SELECT public.admin_apply_action('restrict_record',pg_temp.test_id('user'),pg_temp.test_id('note'),'{"resource":"notes"}','Restricted test note');
SELECT public.admin_apply_action('subscription_access',pg_temp.test_id('user'),p_value=>jsonb_build_object('tier','premium','expires_at',now()+interval '7 days'),p_reason=>'Temporary access test');
SELECT pg_temp.assert_true(public.admin_get_user(pg_temp.test_id('user'))->>'effective_tier'='premium','subscription override grants temporary app access');
SELECT public.admin_apply_action('clear_subscription_access',pg_temp.test_id('user'),p_reason=>'Remove temporary access');
SELECT pg_temp.assert_true(public.admin_get_user(pg_temp.test_id('user'))->>'effective_tier'='free','removing override returns to billing entitlement');
SELECT public.admin_apply_action('review_application',pg_temp.test_id('user'),pg_temp.test_id('application'),'{"status":"approved"}','Approved application test');
SELECT pg_temp.assert_true(public.admin_get_user(pg_temp.test_id('user'))->'affiliate'->>'status'='active','approval activates affiliate profile');
SELECT pg_temp.assert_denied('SELECT public.admin_apply_action(''review_application'',pg_temp.test_id(''user''),pg_temp.test_id(''application''),''{"status":"rejected"}'',''duplicate review'')','reviewed applications cannot be reviewed again');

RESET ROLE;
SELECT pg_temp.assert_true((SELECT payout_details->>'upi_id'='test@bank' FROM public.affiliate_profiles WHERE id=pg_temp.test_id('user')),'approval preserves payout destination');
SELECT set_config('request.jwt.claim.sub',pg_temp.test_id('user')::text,true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true((public.get_my_admin_access()->'features'->>'posts')::boolean=false,'effective permissions reach the account');
SELECT pg_temp.assert_true((SELECT moderation_status FROM public.community_posts WHERE id=pg_temp.test_id('post'))='approved','post review decision is persisted');
SELECT pg_temp.assert_true((SELECT count(*) FROM public.trader_notes WHERE id=pg_temp.test_id('note'))=0,'restricted content disappears for its owner');
SELECT pg_temp.assert_denied('INSERT INTO public.community_posts(author_id,body) VALUES(auth.uid(),''blocked post'')','posting restriction is enforced by database');
SELECT pg_temp.assert_denied('INSERT INTO public.trader_notes(user_id,title) VALUES(auth.uid(),''blocked note'')','notes restriction is enforced by database');
SELECT public.record_account_activity('overview');
SELECT public.record_account_activity('overview');
SELECT public.reserve_ai_request('chat','Test prompt',pg_temp.test_id('ai_thread'));
SELECT pg_temp.assert_denied('SELECT public.reserve_ai_request(''completion'',''quota bypass'')','AI quota prevents an extra provider request');
SELECT pg_temp.assert_denied('DELETE FROM public.ai_insight_requests WHERE user_id=auth.uid()','users cannot reset their AI usage');

RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*) FROM public.admin_audit_logs WHERE actor_id=pg_temp.test_id('user') AND action='page_viewed' AND target_id='overview')=1,'navigation activity is deduplicated');
INSERT INTO admin_test_ids(name,id) SELECT 'request',id FROM public.ai_insight_requests WHERE user_id=pg_temp.test_id('user');
SELECT set_config('request.jwt.claim.sub','',true);
SET LOCAL ROLE service_role;
SELECT public.finish_ai_request(pg_temp.test_id('request'),'Saved provider response',p_provider=>'test',p_model=>'fixture',p_input_tokens=>10,p_output_tokens=>20);
RESET ROLE;
SELECT pg_temp.assert_true((SELECT status='completed' AND input_tokens=10 AND output_tokens=20 FROM public.ai_insight_requests WHERE id=pg_temp.test_id('request')),'AI provider usage and response are persisted');
SELECT pg_temp.assert_true((SELECT count(*) FROM public.ai_messages WHERE thread_id=pg_temp.test_id('ai_thread'))=2,'both AI turns belong to the persisted conversation');

SET LOCAL ROLE anon;
SELECT pg_temp.assert_true(public.public_document('note',pg_temp.test_id('note')) IS NULL,'public links cannot reveal restricted notes');
SELECT pg_temp.assert_true((SELECT count(*) FROM public.community_posts WHERE id=pg_temp.test_id('post'))=1,'approved public posts are readable');
SELECT pg_temp.assert_true((SELECT count(*) FROM public.community_posts WHERE id=pg_temp.test_id('pending_post'))=0,'pending posts are hidden from public reads');
SELECT pg_temp.assert_true((SELECT count(*) FROM public.community_comments WHERE id=pg_temp.test_id('public_comment'))=1,'approved comments on approved posts are public');
SELECT pg_temp.assert_true((SELECT count(*) FROM public.community_comments WHERE id=pg_temp.test_id('pending_comment'))=0,'pending comments are hidden from public reads');
SELECT pg_temp.assert_true((SELECT count(*) FROM public.community_comments WHERE id=pg_temp.test_id('pending_parent_comment'))=0,'comments on unapproved posts remain hidden');
SELECT pg_temp.assert_denied('SELECT public.admin_get_overview()','anonymous callers cannot access administration');

RESET ROLE;
SELECT set_config('request.jwt.claim.sub',pg_temp.test_id('admin')::text,true);
SET LOCAL ROLE authenticated;
SELECT public.admin_apply_action('restore_record',pg_temp.test_id('user'),pg_temp.test_id('note'),'{"resource":"notes"}','Restore note test');
SELECT public.admin_apply_action('controls',pg_temp.test_id('user'),p_value=>'{"features":{},"limits":{"notes":1,"posts_per_day":0}}',p_reason=>'Test quota overrides');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',pg_temp.test_id('user')::text,true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_denied('INSERT INTO public.trader_notes(user_id,title) VALUES(auth.uid(),''over quota'')','per-user note allowance overrides the plan');
SELECT pg_temp.assert_denied('INSERT INTO public.community_posts(author_id,body) VALUES(auth.uid(),''over daily quota'')','daily post allowance is enforced');
SELECT pg_temp.assert_denied('UPDATE public.trader_notes SET created_at=now()-interval ''1 year'' WHERE id=pg_temp.test_id(''note'')','users cannot change record creation times');

RESET ROLE;
SELECT set_config('request.jwt.claim.sub',pg_temp.test_id('admin')::text,true);
SET LOCAL ROLE authenticated;
SELECT public.admin_apply_action('account_status',pg_temp.test_id('user'),p_value=>'{"status":"suspended"}',p_reason=>'Suspension test');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub',pg_temp.test_id('user')::text,true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(public.get_my_admin_access()->>'status'='suspended','suspension is visible with an existing session');
SELECT pg_temp.assert_true((SELECT count(*) FROM public.trader_notes WHERE user_id=auth.uid())=0,'suspension blocks private reads with a stale JWT');
SELECT pg_temp.assert_true((SELECT count(*) FROM public.chat_threads)=0,'suspension blocks private conversations');
SELECT pg_temp.assert_denied('SELECT public.reserve_ai_request(''completion'',''suspended bypass'')','suspension blocks AI');
-- A restrictive SELECT policy can turn a blocked UPDATE into zero affected rows.
WITH restored AS (UPDATE public.profiles SET status='active' WHERE id=auth.uid() RETURNING id)
SELECT pg_temp.assert_true((SELECT count(*) FROM restored)=0,'suspended users cannot restore their own access');

RESET ROLE;
SELECT set_config('request.jwt.claim.sub',pg_temp.test_id('admin')::text,true);
SET LOCAL ROLE authenticated;
SELECT public.admin_apply_action('request_deletion',pg_temp.test_id('delete_user'),p_reason=>'Deletion regression test');
RESET ROLE;
INSERT INTO admin_test_ids(name,id) SELECT 'deletion',id FROM public.account_deletion_requests WHERE user_id=pg_temp.test_id('delete_user');
SELECT set_config('request.jwt.claim.sub','',true);
UPDATE public.account_deletion_requests SET purge_ai_workspace=false WHERE id=pg_temp.test_id('deletion');
SET LOCAL ROLE service_role;
SELECT pg_temp.assert_denied('SELECT public.admin_claim_deletion(pg_temp.test_id(''deletion''),pg_temp.test_id(''admin''),''admincheck_delete_user'',''scope mismatch'')','partial deletion consent cannot authorize full account removal');
RESET ROLE;
UPDATE public.account_deletion_requests SET purge_ai_workspace=true,data_purge_condition='purge_personal_keep_tax_ledger' WHERE id=pg_temp.test_id('deletion');
SET LOCAL ROLE service_role;
SELECT pg_temp.assert_denied('SELECT public.admin_claim_deletion(pg_temp.test_id(''deletion''),pg_temp.test_id(''admin''),''admincheck_delete_user'',''retention mismatch'')','legacy tax-retention requests cannot trigger a cascading deletion');
RESET ROLE;
UPDATE public.account_deletion_requests SET data_purge_condition='immediate_purge' WHERE id=pg_temp.test_id('deletion');
SET LOCAL ROLE service_role;
SELECT public.admin_claim_deletion(pg_temp.test_id('deletion'),pg_temp.test_id('admin'),'admincheck_delete_user','Verified deletion test');
SELECT pg_temp.assert_denied('SELECT public.admin_claim_deletion(pg_temp.test_id(''deletion''),pg_temp.test_id(''admin''),''admincheck_delete_user'',''concurrent claim'')','only one deletion worker can claim a request');
SELECT public.admin_finish_deletion(pg_temp.test_id('deletion'),pg_temp.test_id('admin'),'Test interrupted cleanup');
RESET ROLE;
DELETE FROM auth.users WHERE id=pg_temp.test_id('delete_user');
SET LOCAL ROLE service_role;
SELECT pg_temp.assert_true((public.admin_claim_deletion(pg_temp.test_id('deletion'),pg_temp.test_id('admin'),'admincheck_delete_user','Reconcile interrupted deletion')->>'auth_deleted')::boolean,'deletion recovers after auth removal before receipt');
SELECT public.admin_finish_deletion(pg_temp.test_id('deletion'),pg_temp.test_id('admin'));
SELECT pg_temp.assert_true((public.admin_claim_deletion(pg_temp.test_id('deletion'),pg_temp.test_id('admin'),'admincheck_delete_user','Retry completed deletion')->>'completed')::boolean,'completed deletion retry is idempotent');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*) FROM public.admin_audit_logs WHERE subject_user_id=pg_temp.test_id('delete_user') AND action='account_deleted')=1,'deletion history survives account removal');
SELECT set_config('request.jwt.claim.sub',pg_temp.test_id('stranger')::text,true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(public.request_account_deletion_with_conditions('Self-service request',p_data_purge_condition=>'after_30_day_grace')->>'status'='grace_period','customer deletion requests enter the real queue');
SELECT pg_temp.assert_true(public.get_my_admin_access()->>'status'='suspended','customer deletion request locks account access');
SELECT pg_temp.assert_true(public.request_account_deletion_with_conditions('Retry self-service request')->>'status'='grace_period','customer deletion request retries preserve the original request');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*) FROM public.account_deletion_requests WHERE user_id=pg_temp.test_id('stranger'))=1,'customer retries do not duplicate deletion jobs');
SELECT 'All administration database checks passed; fixtures rolled back.' AS result;
SELECT check_name,result FROM admin_test_results ORDER BY check_name;
ROLLBACK;
