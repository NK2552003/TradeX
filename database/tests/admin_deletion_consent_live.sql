-- Validate the deployed guard using temporary requests for an existing account.
-- No deletion worker runs. Every inserted request and audit entry rolls back.
BEGIN;
SELECT set_config('request.jwt.claim.role','service_role',true);
CREATE TEMP TABLE deletion_consent_checks(check_name text,result text);
DO $$
DECLARE actor uuid; subject public.profiles%ROWTYPE; request_id uuid; guarded boolean;
BEGIN
  SELECT id INTO actor FROM public.profiles WHERE role='user_admin' AND status='active' ORDER BY created_at LIMIT 1;
  SELECT * INTO subject FROM public.profiles WHERE role='customer' AND status='active' ORDER BY created_at LIMIT 1;
  IF actor IS NULL OR subject.id IS NULL THEN RAISE EXCEPTION 'An administrator and customer are required for this check'; END IF;
  INSERT INTO public.account_deletion_requests(user_id,subject_user_id,user_handle,user_email,reason,purge_ai_workspace)
    VALUES(subject.id,subject.id,subject.handle::text,subject.email,'Rolled-back consent verification',false)
    RETURNING id INTO request_id;
  guarded:=false;
  BEGIN
    PERFORM public.admin_claim_deletion(request_id,actor,subject.handle::text,'Verify partial consent protection');
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM NOT LIKE 'This request asks to retain account-owned data.%' THEN RAISE; END IF;
    guarded:=true;
  END;
  IF NOT guarded THEN RAISE EXCEPTION 'Partial-retention deletion was not blocked'; END IF;
  INSERT INTO deletion_consent_checks VALUES('Partial retention cannot authorize full deletion','PASS');
  UPDATE public.account_deletion_requests SET purge_ai_workspace=true,data_purge_condition='purge_personal_keep_tax_ledger' WHERE id=request_id;
  guarded:=false;
  BEGIN
    PERFORM public.admin_claim_deletion(request_id,actor,subject.handle::text,'Verify legacy retention protection');
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM NOT LIKE 'This request asks to retain account-owned data.%' THEN RAISE; END IF;
    guarded:=true;
  END;
  IF NOT guarded THEN RAISE EXCEPTION 'Legacy tax-retention deletion was not blocked'; END IF;
  INSERT INTO deletion_consent_checks VALUES('Legacy tax retention cannot authorize full deletion','PASS');
  IF (SELECT status FROM public.profiles WHERE id=subject.id)<>'active'
    OR (SELECT status FROM public.account_deletion_requests WHERE id=request_id)<>'pending' THEN
    RAISE EXCEPTION 'A denied claim changed the account or request';
  END IF;
  INSERT INTO deletion_consent_checks VALUES('Denied claims preserve account and request status','PASS');
END;
$$;
SELECT * FROM deletion_consent_checks;
ROLLBACK;
