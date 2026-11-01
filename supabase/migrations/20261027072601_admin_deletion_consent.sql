-- Account removal cascades all account-owned data. Never execute a legacy
-- selective-retention request as if it consented to full removal.
BEGIN;

CREATE OR REPLACE FUNCTION public.admin_claim_deletion(p_request uuid,p_actor uuid,p_confirmation text,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.account_deletion_requests%ROWTYPE; p public.profiles%ROWTYPE;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=p_actor AND role='user_admin' AND status='active') THEN
    RAISE EXCEPTION 'Active administrator required' USING ERRCODE='42501';
  END IF;
  SELECT * INTO r FROM public.account_deletion_requests WHERE id=p_request FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deletion request not found'; END IF;
  IF r.status='completed' THEN RETURN jsonb_build_object('completed',true); END IF;
  IF r.status='cancelled' OR (r.status='processing' AND r.processing_started_at>now()-interval '10 minutes') THEN
    RAISE EXCEPTION 'Deletion is cancelled or already in progress';
  END IF;
  IF r.scheduled_purge_at>now() THEN RAISE EXCEPTION 'The deletion grace period has not ended'; END IF;
  IF r.data_purge_condition NOT IN ('immediate_purge','after_30_day_grace')
    OR r.purge_journals_notes_strategies IS DISTINCT FROM true
    OR r.purge_community_messages IS DISTINCT FROM true
    OR r.purge_ai_workspace IS DISTINCT FROM true
    OR r.purge_affiliate_campaigns IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'This request asks to retain account-owned data. Cancel it and obtain consent for full account deletion, or manage individual records instead';
  END IF;
  SELECT * INTO p FROM public.profiles WHERE id=r.user_id FOR UPDATE;
  IF NOT FOUND THEN
    -- Auth removal can succeed before the completion receipt reaches the
    -- database. Reconcile that job instead of leaving it permanently failed.
    IF r.subject_user_id IS NOT NULL AND r.status IN ('processing','failed','data_purged')
      AND NOT EXISTS(SELECT 1 FROM auth.users WHERE id=r.subject_user_id)
      AND r.user_handle IS NOT DISTINCT FROM trim(p_confirmation)
      AND p_reason IS NOT NULL AND length(trim(p_reason)) BETWEEN 3 AND 2000 THEN
      UPDATE public.account_deletion_requests SET status='processing',processing_started_at=now(),
        reviewed_by=p_actor,review_notes=p_reason,last_error=NULL,updated_at=now() WHERE id=p_request;
      RETURN jsonb_build_object('user_id',r.subject_user_id,'completed',false,'auth_deleted',true);
    END IF;
    RAISE EXCEPTION 'Account no longer exists';
  END IF;
  IF p.id=p_actor OR p.role='user_admin' THEN RAISE EXCEPTION 'Administrator accounts cannot be deleted'; END IF;
  IF p.handle::text IS DISTINCT FROM trim(p_confirmation) OR p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 3 AND 2000 THEN
    RAISE EXCEPTION 'Confirmation and reason are required';
  END IF;
  IF EXISTS(SELECT 1 FROM public.subscriptions WHERE user_id=p.id
    AND billing_provider IS NOT NULL AND status IN ('active','trialing','past_due')) THEN
    RAISE EXCEPTION 'Cancel the subscription with the billing provider before deleting this account';
  END IF;
  UPDATE public.account_deletion_requests SET subject_user_id=p.id,status='processing',processing_started_at=now(),
    reviewed_by=p_actor,review_notes=p_reason,last_error=NULL,updated_at=now() WHERE id=p_request;
  UPDATE public.profiles SET status='suspended',updated_at=now() WHERE id=p.id;
  IF to_regclass('auth.sessions') IS NOT NULL THEN
    EXECUTE 'DELETE FROM auth.sessions WHERE user_id=$1' USING p.id;
  END IF;
  RETURN jsonb_build_object('user_id',p.id,'completed',false);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_claim_deletion(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_claim_deletion(uuid,uuid,text,text) TO service_role;

COMMIT;
