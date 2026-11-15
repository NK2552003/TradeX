-- Allow authenticated account owners to rotate their E2EE key-wrapping salt
-- and encrypted backup (for example when changing their account password or
-- migrating a legacy recovery passphrase to their login password), while
-- strictly enforcing that identity public keys remain immutable.

GRANT UPDATE (salt, backup) ON public.message_identities TO authenticated;

DROP POLICY IF EXISTS identity_rekey ON public.message_identities;
CREATE POLICY identity_rekey
  ON public.message_identities
  FOR UPDATE
  TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE OR REPLACE FUNCTION private.enforce_immutable_message_identity_keys()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.user_id IS DISTINCT FROM OLD.user_id
     OR NEW.public_key IS DISTINCT FROM OLD.public_key
     OR NEW.signing_key IS DISTINCT FROM OLD.signing_key THEN
    RAISE EXCEPTION 'Message identity public keys are immutable.'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.enforce_immutable_message_identity_keys()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enforce_immutable_message_identity_keys
  ON public.message_identities;
CREATE TRIGGER enforce_immutable_message_identity_keys
  BEFORE UPDATE ON public.message_identities
  FOR EACH ROW
  EXECUTE FUNCTION private.enforce_immutable_message_identity_keys();
