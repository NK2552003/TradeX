-- =============================================================================
-- TradeX Consolidated Security, Isolation, Billing & Storage Migration (changes_50.sql)
-- Resolves Issues:
--   #83: [BACKEND & FRONTEND] Move direct-message attachments to private storage
--   #84: [BACKEND] Enforce account isolation in the portfolio_stats view
--   #85: [BACKEND] Block cross-user changes to legacy chat attachments
--   #86: [BACKEND] Prevent the legacy chat RPC from exposing third-party membership
--   #87: [BACKEND] Restrict community reaction reads to posts the caller can see
--   #89: [BACKEND] Restrict desk risk configuration writes to administrators
--   #90: [BACKEND & FRONTEND] Enforce strategy visibility on attachment downloads
--   #92: [BACKEND] Make subscription updates atomic across billing providers
--   #93: [BACKEND] Prevent unauthorized changes to community post view counts
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 0. Ensure Private Helper Schema & Core Helpers Exist
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS tradex_private;
REVOKE ALL ON SCHEMA tradex_private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA tradex_private TO authenticated, service_role;

CREATE OR REPLACE FUNCTION tradex_private.try_parse_uuid(p_value text)
RETURNS uuid
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
BEGIN
  IF p_value IS NULL OR p_value !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RETURN NULL;
  END IF;
  RETURN p_value::uuid;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.account_active(p_user uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p_user IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_user
      AND COALESCE(status, 'active') = 'active'
  );
$$;

-- Remove any 1-arg overload of tradex_private.is_admin(uuid) so 0-arg calls from
-- existing triggers (e.g. tradex_private.guard_feature_write) are never ambiguous (42725).
DROP FUNCTION IF EXISTS tradex_private.is_admin(uuid);

CREATE OR REPLACE FUNCTION tradex_private.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'user_admin'
      AND COALESCE(status, 'active') = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_admin_caller()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT tradex_private.is_admin();
$$;

CREATE OR REPLACE FUNCTION public.is_user_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT tradex_private.is_admin();
$$;

-- -----------------------------------------------------------------------------
-- 1. Issue #84: Enforce Account Isolation in the portfolio_stats View
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_relkind "char";
BEGIN
  SELECT c.relkind INTO v_relkind
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname = 'portfolio_stats';

  IF v_relkind = 'r' THEN
    EXECUTE 'DROP TABLE public.portfolio_stats CASCADE';
  ELSIF v_relkind = 'm' THEN
    EXECUTE 'DROP MATERIALIZED VIEW public.portfolio_stats CASCADE';
  END IF;
END $$;

CREATE OR REPLACE VIEW public.portfolio_stats
WITH (security_invoker = true) AS
SELECT
  user_id,
  SUM(pnl) AS total_pnl,
  AVG(CASE WHEN pnl > 0 THEN 1.0 ELSE 0.0 END) AS win_rate,
  AVG(
    CASE
      WHEN (entry_price - stop_loss) <> 0 THEN ABS(target - entry_price) / ABS(entry_price - stop_loss)
      ELSE NULL
    END
  ) AS avg_rr,
  MIN(pnl) AS worst_trade_pnl,
  MAX(pnl) AS best_trade_pnl
FROM public.journal_entries
WHERE pnl IS NOT NULL
  AND user_id = (SELECT auth.uid())
GROUP BY user_id;

REVOKE ALL ON public.portfolio_stats FROM PUBLIC, anon;
GRANT SELECT ON public.portfolio_stats TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. Issue #86: Prevent Legacy Chat RPC from Exposing Third-Party Membership
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tradex_private.chat_member(p_thread uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT tradex_private.account_active(auth.uid()) AND EXISTS (
    SELECT 1 FROM public.chat_participants
    WHERE thread_id = p_thread AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION tradex_private.chat_owner(p_thread uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT tradex_private.account_active(auth.uid()) AND EXISTS (
    SELECT 1 FROM public.chat_threads
    WHERE id = p_thread AND created_by = auth.uid()
  );
$$;

DO $$
DECLARE
  p record;
BEGIN
  FOR p IN
    SELECT tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('chat_threads', 'chat_participants', 'chat_messages', 'chat_attachments', 'chat_shared_refs', 'chat_reactions')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', p.policyname, p.tablename);
  END LOOP;
END $$;

CREATE POLICY chat_read ON public.chat_threads FOR SELECT TO authenticated
  USING (tradex_private.chat_member(id) OR tradex_private.chat_owner(id));

CREATE POLICY chat_create ON public.chat_threads FOR INSERT TO authenticated
  WITH CHECK (created_by = (SELECT auth.uid()) AND tradex_private.account_active(auth.uid()));

CREATE POLICY chat_update ON public.chat_threads FOR UPDATE TO authenticated
  USING (tradex_private.chat_member(id) OR tradex_private.chat_owner(id))
  WITH CHECK (tradex_private.chat_member(id) OR tradex_private.chat_owner(id));

CREATE POLICY participants_read ON public.chat_participants FOR SELECT TO authenticated
  USING (tradex_private.chat_member(thread_id) OR tradex_private.chat_owner(thread_id));

CREATE POLICY participants_insert ON public.chat_participants FOR INSERT TO authenticated
  WITH CHECK (tradex_private.chat_owner(thread_id) OR (user_id = (SELECT auth.uid()) AND tradex_private.chat_member(thread_id)));

CREATE POLICY participants_update ON public.chat_participants FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()) AND tradex_private.chat_member(thread_id))
  WITH CHECK (user_id = (SELECT auth.uid()) AND tradex_private.chat_member(thread_id));

CREATE POLICY participants_delete ON public.chat_participants FOR DELETE TO authenticated
  USING ((user_id = (SELECT auth.uid()) AND tradex_private.chat_member(thread_id)) OR tradex_private.chat_owner(thread_id));

ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS admin_hidden boolean NOT NULL DEFAULT false;

CREATE POLICY messages_read ON public.chat_messages FOR SELECT TO authenticated
  USING (tradex_private.chat_member(thread_id) AND NOT COALESCE(admin_hidden, false));

CREATE POLICY messages_insert ON public.chat_messages FOR INSERT TO authenticated
  WITH CHECK (sender_id = (SELECT auth.uid()) AND tradex_private.chat_member(thread_id) AND NOT COALESCE(admin_hidden, false));

CREATE POLICY messages_update ON public.chat_messages FOR UPDATE TO authenticated
  USING (sender_id = (SELECT auth.uid()) AND tradex_private.chat_member(thread_id) AND NOT COALESCE(admin_hidden, false))
  WITH CHECK (sender_id = (SELECT auth.uid()) AND tradex_private.chat_member(thread_id) AND NOT COALESCE(admin_hidden, false));

CREATE POLICY messages_delete ON public.chat_messages FOR DELETE TO authenticated
  USING (sender_id = (SELECT auth.uid()) AND tradex_private.chat_member(thread_id) AND NOT COALESCE(admin_hidden, false));

CREATE POLICY chat_reactions_read ON public.chat_reactions FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.chat_messages m
    WHERE m.id = chat_reactions.message_id
      AND tradex_private.chat_member(m.thread_id)
      AND NOT COALESCE(m.admin_hidden, false)
  ));

CREATE POLICY chat_reactions_insert ON public.chat_reactions FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.chat_messages m
      WHERE m.id = chat_reactions.message_id
        AND tradex_private.chat_member(m.thread_id)
        AND NOT COALESCE(m.admin_hidden, false)
    )
  );

CREATE POLICY chat_reactions_delete ON public.chat_reactions FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY chat_shared_refs_read ON public.chat_shared_refs FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.chat_messages m
    WHERE m.id = chat_shared_refs.message_id
      AND tradex_private.chat_member(m.thread_id)
      AND NOT COALESCE(m.admin_hidden, false)
  ));

CREATE POLICY chat_shared_refs_insert ON public.chat_shared_refs FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.chat_messages m
    WHERE m.id = chat_shared_refs.message_id
      AND m.sender_id = (SELECT auth.uid())
      AND tradex_private.chat_member(m.thread_id)
      AND NOT COALESCE(m.admin_hidden, false)
  ));

-- Drop the legacy third-party membership probe without CASCADE
DROP FUNCTION IF EXISTS public.user_is_chat_participant(uuid, uuid);

-- Harden legacy is_conversation_member RPC so 2-arg form never leaks third-party membership
CREATE OR REPLACE FUNCTION public.is_conversation_member(target_conv_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RETURN FALSE;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'conversation_participants') THEN
    IF EXISTS (
      SELECT 1 FROM public.conversation_participants
      WHERE conversation_id = target_conv_id AND user_id = v_caller
    ) THEN
      RETURN TRUE;
    END IF;
  END IF;

  RETURN tradex_private.chat_member(target_conv_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.is_conversation_member(target_conv_id uuid, target_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL OR target_user_id IS NULL OR target_user_id <> v_caller THEN
    RETURN FALSE;
  END IF;
  RETURN public.is_conversation_member(target_conv_id);
END;
$$;

REVOKE ALL ON FUNCTION public.is_conversation_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_conversation_member(uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_conversation_member(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_conversation_member(uuid, uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. Issues #83 & #85: Private Direct-Message Storage & Legacy Chat Path Hardening
-- -----------------------------------------------------------------------------
ALTER TABLE public.chat_attachments ADD COLUMN IF NOT EXISTS storage_path text;

-- Normalize chat attachment object paths and convert legacy layouts
CREATE OR REPLACE FUNCTION public.normalize_chat_attachment_path(
  p_raw text,
  p_thread_id uuid DEFAULT NULL,
  p_sender_id uuid DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  v_clean text;
  v_parts text[];
  v_idx int;
  v_seg1 uuid;
  v_seg2 uuid;
  v_file text;
BEGIN
  IF p_raw IS NULL THEN
    RETURN NULL;
  END IF;
  v_clean := btrim(p_raw);
  IF v_clean = '' OR v_clean LIKE 'data:%' THEN
    RETURN v_clean;
  END IF;

  -- Strip query string
  IF position('?' IN v_clean) > 0 THEN
    v_clean := split_part(v_clean, '?', 1);
  END IF;

  -- Extract path after bucket segment if a full Storage URL was passed
  IF v_clean ~* '^https?://' THEN
    IF position('/chat-attachments/' IN v_clean) > 0 THEN
      v_clean := split_part(v_clean, '/chat-attachments/', 2);
    ELSIF position('/community-attachments/' IN v_clean) > 0 THEN
      v_clean := split_part(v_clean, '/community-attachments/', 2);
    ELSE
      RETURN v_clean;
    END IF;
  END IF;

  v_clean := regexp_replace(v_clean, '^/+', '');
  v_clean := regexp_replace(v_clean, '^chat-attachments/+', '');
  v_clean := regexp_replace(v_clean, '^community-attachments/+', '');

  IF position('..' IN v_clean) > 0 THEN
    RETURN NULL;
  END IF;

  v_parts := string_to_array(v_clean, '/');

  -- Layout A (canonical): <thread_id>/<uploader_id>/<filename>
  IF array_length(v_parts, 1) = 3 AND v_parts[1] <> 'chat' AND v_parts[2] <> 'chat' THEN
    v_seg1 := tradex_private.try_parse_uuid(v_parts[1]);
    v_seg2 := tradex_private.try_parse_uuid(v_parts[2]);
    v_file := btrim(v_parts[3]);
    IF v_seg1 IS NOT NULL AND v_seg2 IS NOT NULL AND v_file <> '' THEN
      RETURN v_seg1::text || '/' || v_seg2::text || '/' || v_file;
    END IF;
  END IF;

  -- Layout B (legacy 1): <uploader_id>/chat/<thread_id>/<filename>
  IF array_length(v_parts, 1) = 4 AND v_parts[2] = 'chat' THEN
    v_seg2 := tradex_private.try_parse_uuid(v_parts[1]); -- uploader
    v_seg1 := tradex_private.try_parse_uuid(v_parts[3]); -- thread
    v_file := btrim(v_parts[4]);
    IF v_seg1 IS NOT NULL AND v_seg2 IS NOT NULL AND v_file <> '' THEN
      RETURN v_seg1::text || '/' || v_seg2::text || '/' || v_file;
    END IF;
  END IF;

  -- Layout C (legacy 2): chat/<thread_id>/<filename>
  IF array_length(v_parts, 1) = 3 AND v_parts[1] = 'chat' THEN
    v_seg1 := tradex_private.try_parse_uuid(v_parts[2]); -- thread
    v_file := btrim(v_parts[3]);
    IF v_seg1 IS NOT NULL AND p_sender_id IS NOT NULL AND v_file <> '' THEN
      RETURN v_seg1::text || '/' || p_sender_id::text || '/' || v_file;
    END IF;
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.validate_chat_attachment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_thread_id uuid;
  v_sender_id uuid;
  v_admin_hidden boolean;
  v_candidate text;
  v_parts text[];
BEGIN
  SELECT thread_id, sender_id, COALESCE(admin_hidden, false)
    INTO v_thread_id, v_sender_id, v_admin_hidden
    FROM public.chat_messages
   WHERE id = NEW.message_id;

  IF v_thread_id IS NULL OR v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Chat attachment must reference a valid conversation message' USING ERRCODE = '42501';
  END IF;

  IF v_admin_hidden THEN
    RAISE EXCEPTION 'Cannot attach files to a restricted message' USING ERRCODE = '42501';
  END IF;

  IF auth.uid() IS NOT NULL THEN
    IF v_sender_id <> auth.uid() OR NOT tradex_private.chat_member(v_thread_id) THEN
      RAISE EXCEPTION 'Unauthorized chat attachment write' USING ERRCODE = '42501';
    END IF;
  END IF;

  v_candidate := COALESCE(NULLIF(btrim(NEW.storage_path), ''), NULLIF(btrim(NEW.url), ''));

  IF v_candidate IS NOT NULL AND v_candidate <> '' AND v_candidate NOT LIKE 'data:%' THEN
    -- For tradeSetup / chart attachments without a storage file, allow empty url
    IF position('/' IN v_candidate) > 0 OR v_candidate ~* '^https?://' THEN
      v_candidate := public.normalize_chat_attachment_path(v_candidate, v_thread_id, v_sender_id);
      IF v_candidate IS NULL THEN
        RAISE EXCEPTION 'Invalid chat attachment storage path' USING ERRCODE = '42501';
      END IF;
      v_parts := string_to_array(v_candidate, '/');
      IF array_length(v_parts, 1) <> 3
         OR v_parts[1] <> v_thread_id::text
         OR v_parts[2] <> v_sender_id::text
         OR btrim(v_parts[3]) = '' THEN
        RAISE EXCEPTION 'Chat attachment path must match <thread_id>/<uploader_id>/<filename>' USING ERRCODE = '42501';
      END IF;
      NEW.storage_path := v_candidate;
      NEW.url := v_candidate;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_chat_attachment ON public.chat_attachments;
CREATE TRIGGER trg_validate_chat_attachment
  BEFORE INSERT OR UPDATE ON public.chat_attachments
  FOR EACH ROW EXECUTE FUNCTION tradex_private.validate_chat_attachment();

CREATE POLICY chat_attachments_read ON public.chat_attachments FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.chat_messages m
    WHERE m.id = chat_attachments.message_id
      AND tradex_private.chat_member(m.thread_id)
      AND NOT COALESCE(m.admin_hidden, false)
  ));

CREATE POLICY chat_attachments_insert ON public.chat_attachments FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.chat_messages m
    WHERE m.id = chat_attachments.message_id
      AND m.sender_id = (SELECT auth.uid())
      AND tradex_private.chat_member(m.thread_id)
      AND NOT COALESCE(m.admin_hidden, false)
  ));

CREATE POLICY chat_attachments_delete ON public.chat_attachments FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.chat_messages m
    WHERE m.id = chat_attachments.message_id
      AND m.sender_id = (SELECT auth.uid())
      AND tradex_private.chat_member(m.thread_id)
      AND NOT COALESCE(m.admin_hidden, false)
  ));

-- Authorization helper for reading objects from private chat-attachments bucket
CREATE OR REPLACE FUNCTION tradex_private.can_read_chat_attachment(p_object_name text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_parts text[];
  v_thread_id uuid;
  v_uploader_id uuid;
  v_has_linked_record boolean;
BEGIN
  IF v_caller IS NULL OR NOT tradex_private.account_active(v_caller) OR p_object_name IS NULL THEN
    RETURN FALSE;
  END IF;

  IF position('..' IN p_object_name) > 0 THEN
    RETURN FALSE;
  END IF;

  v_parts := string_to_array(p_object_name, '/');
  IF array_length(v_parts, 1) <> 3 OR btrim(v_parts[3]) = '' THEN
    RETURN FALSE;
  END IF;

  v_thread_id := tradex_private.try_parse_uuid(v_parts[1]);
  v_uploader_id := tradex_private.try_parse_uuid(v_parts[2]);

  IF v_thread_id IS NULL OR v_uploader_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Caller must currently be an active member of the conversation
  IF NOT tradex_private.chat_member(v_thread_id) THEN
    RETURN FALSE;
  END IF;

  -- Check if the object is linked to a saved message attachment
  SELECT EXISTS (
    SELECT 1
    FROM public.chat_attachments ca
    WHERE ca.storage_path = p_object_name OR ca.url = p_object_name
  ) INTO v_has_linked_record;

  IF v_has_linked_record THEN
    RETURN EXISTS (
      SELECT 1
      FROM public.chat_attachments ca
      JOIN public.chat_messages cm ON cm.id = ca.message_id
      WHERE (ca.storage_path = p_object_name OR ca.url = p_object_name)
        AND cm.thread_id = v_thread_id
        AND cm.sender_id = v_uploader_id
        AND NOT COALESCE(cm.admin_hidden, false)
    );
  END IF;

  -- Before the message row is saved, only the uploader can preview their staged upload
  RETURN v_uploader_id = v_caller;
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.can_write_chat_attachment(p_object_name text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_parts text[];
  v_thread_id uuid;
  v_uploader_id uuid;
BEGIN
  IF v_caller IS NULL OR NOT tradex_private.account_active(v_caller) OR p_object_name IS NULL THEN
    RETURN FALSE;
  END IF;

  IF position('..' IN p_object_name) > 0 THEN
    RETURN FALSE;
  END IF;

  v_parts := string_to_array(p_object_name, '/');
  IF array_length(v_parts, 1) <> 3 OR btrim(v_parts[3]) = '' THEN
    RETURN FALSE;
  END IF;

  v_thread_id := tradex_private.try_parse_uuid(v_parts[1]);
  v_uploader_id := tradex_private.try_parse_uuid(v_parts[2]);

  IF v_thread_id IS NULL OR v_uploader_id IS NULL OR v_uploader_id <> v_caller THEN
    RETURN FALSE;
  END IF;

  RETURN tradex_private.chat_member(v_thread_id);
END;
$$;

-- Provision & configure Storage buckets and policies when storage schema is present
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'storage') THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES
      (
        'chat-attachments',
        'chat-attachments',
        false,
        15728640,
        ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf', 'audio/webm', 'audio/mp4', 'audio/mpeg', 'audio/wav', 'audio/ogg', 'application/octet-stream']
      ),
      (
        'strategy-attachments',
        'strategy-attachments',
        false,
        10485760,
        ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf']
      ),
      (
        'community-attachments',
        'community-attachments',
        true,
        15728640,
        ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf']
      )
    ON CONFLICT (id) DO UPDATE SET
      public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

    -- Migrate existing legacy chat objects from community-attachments to chat-attachments in-place
    WITH legacy_candidates AS (
      SELECT
        o.id,
        CASE
          WHEN split_part(o.name, '/', 2) = 'chat'
            THEN split_part(o.name, '/', 3) || '/' || split_part(o.name, '/', 1) || '/' || split_part(o.name, '/', 4)
          WHEN split_part(o.name, '/', 1) = 'chat'
            THEN split_part(o.name, '/', 2) || '/' || COALESCE(o.owner::text, (
              SELECT cm.sender_id::text
              FROM public.chat_attachments ca
              JOIN public.chat_messages cm ON cm.id = ca.message_id
              WHERE ca.url LIKE '%' || o.name || '%'
              LIMIT 1
            )) || '/' || split_part(o.name, '/', 3)
        END AS new_name,
        o.created_at
      FROM storage.objects o
      WHERE o.bucket_id = 'community-attachments'
        AND (
          (split_part(o.name, '/', 2) = 'chat'
            AND tradex_private.try_parse_uuid(split_part(o.name, '/', 1)) IS NOT NULL
            AND tradex_private.try_parse_uuid(split_part(o.name, '/', 3)) IS NOT NULL
            AND split_part(o.name, '/', 4) <> '')
          OR
          (split_part(o.name, '/', 1) = 'chat'
            AND tradex_private.try_parse_uuid(split_part(o.name, '/', 2)) IS NOT NULL
            AND split_part(o.name, '/', 3) <> ''
            AND COALESCE(o.owner::text, (
              SELECT cm.sender_id::text
              FROM public.chat_attachments ca
              JOIN public.chat_messages cm ON cm.id = ca.message_id
              WHERE ca.url LIKE '%' || o.name || '%'
              LIMIT 1
            )) IS NOT NULL)
        )
    ),
    deduped_candidates AS (
      SELECT DISTINCT ON (new_name) id, new_name
      FROM legacy_candidates
      WHERE new_name IS NOT NULL
      ORDER BY new_name, created_at DESC NULLS LAST, id
    )
    UPDATE storage.objects target
    SET
      bucket_id = 'chat-attachments',
      name = dc.new_name,
      updated_at = now()
    FROM deduped_candidates dc
    WHERE target.id = dc.id
      AND NOT EXISTS (
        SELECT 1
        FROM storage.objects existing
        WHERE existing.bucket_id = 'chat-attachments'
          AND existing.name = dc.new_name
      );

    -- Remove any remaining duplicate legacy chat objects from public community-attachments bucket
    BEGIN
      PERFORM set_config('storage.allow_delete_query', 'true', true);
      DELETE FROM storage.objects o
      WHERE o.bucket_id = 'community-attachments'
        AND (
          split_part(o.name, '/', 1) = 'chat'
          OR split_part(o.name, '/', 2) = 'chat'
        );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    -- Drop legacy permissive chat policy on community-attachments (Issue #85)
    EXECUTE 'DROP POLICY IF EXISTS community_attachments_chat_authenticated_all ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS community_attachments_owner_all ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS community_attachments_owner_insert ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS community_attachments_owner_update ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS community_attachments_owner_delete ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS community_attachments_objects_public_read ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "Allow authenticated uploads to community-attachments" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "Allow authenticated update own community-attachments" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "Allow authenticated delete own community-attachments" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "Allow public read community-attachments" ON storage.objects';

    -- Recreate strict owner-only non-chat policies for community-attachments
    EXECUTE $pol$
      CREATE POLICY community_attachments_owner_insert ON storage.objects
      FOR INSERT TO authenticated
      WITH CHECK (
        bucket_id = 'community-attachments'
        AND split_part(name, '/', 1) = (SELECT auth.uid())::text
        AND split_part(name, '/', 1) <> 'chat'
        AND split_part(name, '/', 2) <> 'chat'
        AND position('..' IN name) = 0
      )
    $pol$;

    EXECUTE $pol$
      CREATE POLICY community_attachments_owner_update ON storage.objects
      FOR UPDATE TO authenticated
      USING (
        bucket_id = 'community-attachments'
        AND split_part(name, '/', 1) = (SELECT auth.uid())::text
        AND split_part(name, '/', 1) <> 'chat'
        AND split_part(name, '/', 2) <> 'chat'
      )
      WITH CHECK (
        bucket_id = 'community-attachments'
        AND split_part(name, '/', 1) = (SELECT auth.uid())::text
        AND split_part(name, '/', 1) <> 'chat'
        AND split_part(name, '/', 2) <> 'chat'
        AND position('..' IN name) = 0
      )
    $pol$;

    EXECUTE $pol$
      CREATE POLICY community_attachments_owner_delete ON storage.objects
      FOR DELETE TO authenticated
      USING (
        bucket_id = 'community-attachments'
        AND split_part(name, '/', 1) = (SELECT auth.uid())::text
        AND split_part(name, '/', 1) <> 'chat'
        AND split_part(name, '/', 2) <> 'chat'
      )
    $pol$;

    EXECUTE $pol$
      CREATE POLICY community_attachments_objects_public_read ON storage.objects
      FOR SELECT TO anon, authenticated
      USING (
        bucket_id = 'community-attachments'
        AND split_part(name, '/', 1) <> 'chat'
        AND split_part(name, '/', 2) <> 'chat'
      )
    $pol$;

    -- Private chat-attachments policies (Issue #83: no arbitrary overwrite/update policy)
    EXECUTE 'DROP POLICY IF EXISTS chat_attachments_member_insert ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS chat_attachments_member_read ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS chat_attachments_uploader_delete ON storage.objects';

    EXECUTE $pol$
      CREATE POLICY chat_attachments_member_insert ON storage.objects
      FOR INSERT TO authenticated
      WITH CHECK (
        bucket_id = 'chat-attachments'
        AND tradex_private.can_write_chat_attachment(name)
      )
    $pol$;

    EXECUTE $pol$
      CREATE POLICY chat_attachments_member_read ON storage.objects
      FOR SELECT TO authenticated
      USING (
        bucket_id = 'chat-attachments'
        AND tradex_private.can_read_chat_attachment(name)
      )
    $pol$;

    EXECUTE $pol$
      CREATE POLICY chat_attachments_uploader_delete ON storage.objects
      FOR DELETE TO authenticated
      USING (
        bucket_id = 'chat-attachments'
        AND tradex_private.can_write_chat_attachment(name)
      )
    $pol$;

    -- Issue #90: Private strategy-attachments policies requiring matching owner AND strategy
    EXECUTE 'DROP POLICY IF EXISTS strategy_attachments_owner_all ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS strategy_attachments_objects_public_read ON storage.objects';

    EXECUTE $pol$
      CREATE POLICY strategy_attachments_owner_all ON storage.objects
      FOR ALL TO authenticated
      USING (
        bucket_id = 'strategy-attachments'
        AND split_part(name, '/', 1) = (SELECT auth.uid())::text
        AND EXISTS (
          SELECT 1 FROM public.strategies s
          WHERE s.id::text = split_part(storage.objects.name, '/', 2)
            AND s.user_id = (SELECT auth.uid())
        )
      )
      WITH CHECK (
        bucket_id = 'strategy-attachments'
        AND split_part(name, '/', 1) = (SELECT auth.uid())::text
        AND EXISTS (
          SELECT 1 FROM public.strategies s
          WHERE s.id::text = split_part(storage.objects.name, '/', 2)
            AND s.user_id = (SELECT auth.uid())
        )
      )
    $pol$;

    EXECUTE $pol$
      CREATE POLICY strategy_attachments_objects_public_read ON storage.objects
      FOR SELECT TO anon, authenticated
      USING (
        bucket_id = 'strategy-attachments'
        AND EXISTS (
          SELECT 1 FROM public.strategies s
          WHERE s.id::text = split_part(storage.objects.name, '/', 2)
            AND s.user_id::text = split_part(storage.objects.name, '/', 1)
            AND (
              s.visibility = 'public'
              OR s.user_id = (SELECT auth.uid())
            )
            AND (
              EXISTS (
                SELECT 1 FROM public.strategy_attachments sa
                WHERE sa.storage_path = storage.objects.name
                  AND sa.strategy_id = s.id
                  AND sa.user_id = s.user_id
              )
              OR NOT EXISTS (
                SELECT 1 FROM public.strategy_attachments sa
                WHERE sa.storage_path = storage.objects.name
              )
            )
        )
      )
    $pol$;
  END IF;
END $$;

-- Migrate existing chat_attachments rows from legacy URLs/paths to canonical <thread_id>/<sender_id>/<filename>
UPDATE public.chat_attachments ca
SET
  storage_path = public.normalize_chat_attachment_path(COALESCE(ca.storage_path, ca.url), cm.thread_id, cm.sender_id),
  url = public.normalize_chat_attachment_path(COALESCE(ca.storage_path, ca.url), cm.thread_id, cm.sender_id)
FROM public.chat_messages cm
WHERE cm.id = ca.message_id
  AND COALESCE(ca.storage_path, ca.url) IS NOT NULL
  AND COALESCE(ca.storage_path, ca.url) NOT LIKE 'data:%'
  AND public.normalize_chat_attachment_path(COALESCE(ca.storage_path, ca.url), cm.thread_id, cm.sender_id) IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 4. Issue #87: Restrict Community Reaction Reads to Visible Posts
-- -----------------------------------------------------------------------------
ALTER TABLE public.community_posts
  ADD COLUMN IF NOT EXISTS admin_hidden boolean NOT NULL DEFAULT false;

ALTER TABLE public.community_comments
  ADD COLUMN IF NOT EXISTS admin_hidden boolean NOT NULL DEFAULT false;

ALTER TABLE public.community_likes ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  p record;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'community_likes'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.community_likes', p.policyname);
  END LOOP;
END $$;

CREATE POLICY community_likes_visible_post_read
  ON public.community_likes FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.community_posts p
      WHERE p.id = community_likes.post_id
        AND NOT COALESCE(p.admin_hidden, false)
    )
  );

CREATE POLICY community_likes_insert
  ON public.community_likes FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.community_posts p
      WHERE p.id = community_likes.post_id
        AND NOT COALESCE(p.admin_hidden, false)
    )
  );

CREATE POLICY community_likes_update
  ON public.community_likes FOR UPDATE
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.community_posts p
      WHERE p.id = community_likes.post_id
        AND NOT COALESCE(p.admin_hidden, false)
    )
  )
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.community_posts p
      WHERE p.id = community_likes.post_id
        AND NOT COALESCE(p.admin_hidden, false)
    )
  );

CREATE POLICY community_likes_delete
  ON public.community_likes FOR DELETE
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.community_posts p
      WHERE p.id = community_likes.post_id
        AND NOT COALESCE(p.admin_hidden, false)
    )
  );

-- Also apply visibility-scoped read and write policies to community_comment_likes
DO $$
DECLARE
  p record;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'community_comment_likes') THEN
    FOR p IN
      SELECT policyname FROM pg_policies
      WHERE schemaname = 'public' AND tablename = 'community_comment_likes'
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.community_comment_likes', p.policyname);
    END LOOP;

    EXECUTE $pol$
      CREATE POLICY community_comment_likes_visible_read
        ON public.community_comment_likes FOR SELECT
        TO anon, authenticated
        USING (
          EXISTS (
            SELECT 1 FROM public.community_comments c
            WHERE c.id = community_comment_likes.comment_id
              AND NOT COALESCE(c.admin_hidden, false)
          )
        )
    $pol$;

    EXECUTE $pol$
      CREATE POLICY community_comment_likes_insert
        ON public.community_comment_likes FOR INSERT
        TO authenticated
        WITH CHECK (
          user_id = (SELECT auth.uid())
          AND EXISTS (
            SELECT 1 FROM public.community_comments c
            WHERE c.id = community_comment_likes.comment_id
              AND NOT COALESCE(c.admin_hidden, false)
          )
        )
    $pol$;

    EXECUTE $pol$
      CREATE POLICY community_comment_likes_update
        ON public.community_comment_likes FOR UPDATE
        TO authenticated
        USING (
          user_id = (SELECT auth.uid())
          AND EXISTS (
            SELECT 1 FROM public.community_comments c
            WHERE c.id = community_comment_likes.comment_id
              AND NOT COALESCE(c.admin_hidden, false)
          )
        )
        WITH CHECK (
          user_id = (SELECT auth.uid())
          AND EXISTS (
            SELECT 1 FROM public.community_comments c
            WHERE c.id = community_comment_likes.comment_id
              AND NOT COALESCE(c.admin_hidden, false)
          )
        )
    $pol$;

    EXECUTE $pol$
      CREATE POLICY community_comment_likes_delete
        ON public.community_comment_likes FOR DELETE
        TO authenticated
        USING (
          user_id = (SELECT auth.uid())
          AND EXISTS (
            SELECT 1 FROM public.community_comments c
            WHERE c.id = community_comment_likes.comment_id
              AND NOT COALESCE(c.admin_hidden, false)
          )
        )
    $pol$;
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 5. Issue #89: Restrict Desk Risk Configuration Writes to Administrators
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.desk_risk_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_name text NOT NULL DEFAULT 'TradeX Institutional Trading Desk',
  base_currency text NOT NULL DEFAULT 'INR',
  max_firm_leverage numeric NOT NULL DEFAULT 5.0 CHECK (max_firm_leverage >= 1.0 AND max_firm_leverage <= 100.0),
  max_daily_loss_percent numeric NOT NULL DEFAULT 3.0 CHECK (max_daily_loss_percent > 0 AND max_daily_loss_percent <= 50.0),
  max_total_drawdown_percent numeric NOT NULL DEFAULT 8.0 CHECK (max_total_drawdown_percent > 0 AND max_total_drawdown_percent <= 90.0),
  circuit_breaker_threshold_percent numeric NOT NULL DEFAULT 5.0 CHECK (circuit_breaker_threshold_percent > 0),
  auto_freeze_on_breach boolean NOT NULL DEFAULT true,
  allow_crypto boolean NOT NULL DEFAULT false,
  allow_options boolean NOT NULL DEFAULT true,
  require_manager_order_approval boolean NOT NULL DEFAULT true,
  approval_threshold_inr numeric NOT NULL DEFAULT 250000 CHECK (approval_threshold_inr >= 0),
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'organization_members') THEN
    ALTER TABLE public.organization_members
      ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'admin_audit_logs') THEN
    ALTER TABLE public.admin_audit_logs
      ALTER COLUMN id SET DEFAULT gen_random_uuid();
    ALTER TABLE public.admin_audit_logs
      ADD COLUMN IF NOT EXISTS details text NOT NULL DEFAULT '';
    ALTER TABLE public.admin_audit_logs
      ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;
    ALTER TABLE public.admin_audit_logs
      ADD COLUMN IF NOT EXISTS target_id text NOT NULL DEFAULT 'default';
    ALTER TABLE public.admin_audit_logs
      ADD COLUMN IF NOT EXISTS ip_address text NOT NULL DEFAULT '';
    ALTER TABLE public.admin_audit_logs
      ADD COLUMN IF NOT EXISTS sha256_hash text NOT NULL DEFAULT '';
  END IF;
END $$;

ALTER TABLE public.desk_risk_configs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.desk_risk_configs FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.desk_risk_configs TO authenticated;
GRANT ALL ON public.desk_risk_configs TO service_role;

DROP POLICY IF EXISTS desk_risk_configs_read ON public.desk_risk_configs;
DROP POLICY IF EXISTS desk_risk_configs_write ON public.desk_risk_configs;
DROP POLICY IF EXISTS desk_risk_configs_read_policy ON public.desk_risk_configs;
DROP POLICY IF EXISTS desk_risk_configs_admin_write_policy ON public.desk_risk_configs;

CREATE POLICY desk_risk_configs_read_policy
  ON public.desk_risk_configs FOR SELECT
  TO authenticated
  USING (
    public.is_admin_caller()
    OR EXISTS (
      SELECT 1 FROM public.organization_members m
      WHERE m.user_id = (SELECT auth.uid())
        AND COALESCE(m.status, 'active') = 'active'
    )
  );

CREATE POLICY desk_risk_configs_admin_write_policy
  ON public.desk_risk_configs FOR ALL
  TO authenticated
  USING (public.is_admin_caller())
  WITH CHECK (public.is_admin_caller());

CREATE OR REPLACE FUNCTION tradex_private.enforce_desk_risk_admin_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_handle text;
  v_role text;
BEGIN
  IF v_actor IS NOT NULL AND NOT public.is_admin_caller() THEN
    RAISE EXCEPTION 'Only administrators may modify desk risk configurations' USING ERRCODE = '42501';
  END IF;

  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    IF v_actor IS NOT NULL THEN
      NEW.updated_by := v_actor;
    END IF;
    NEW.updated_at := now();
  END IF;

  -- Record actor in admin_audit_logs
  IF v_actor IS NOT NULL AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'admin_audit_logs') THEN
    SELECT COALESCE(handle::text, email::text, v_actor::text), COALESCE(role::text, 'user_admin')
      INTO v_handle, v_role
      FROM public.profiles
     WHERE id = v_actor;

    INSERT INTO public.admin_audit_logs (
      actor_id,
      actor_handle,
      actor_role,
      category,
      action,
      target_type,
      target_id,
      target_label,
      severity,
      details,
      metadata,
      created_at
    ) VALUES (
      v_actor,
      COALESCE(v_handle, 'admin'),
      COALESCE(v_role, 'user_admin'),
      'risk_control',
      'DESK_RISK_CONFIG_' || TG_OP,
      'desk_risk_configs',
      COALESCE(CASE WHEN TG_OP = 'DELETE' THEN OLD.id::text ELSE NEW.id::text END, 'default'),
      'Firm-Wide Desk Risk Configuration',
      'info',
      'Administrator updated desk risk configuration',
      jsonb_build_object(
        'actor_id', v_actor,
        'operation', lower(TG_OP),
        'new', CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
        'old', CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END
      ),
      now()
    );
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_desk_risk_configs_admin_write ON public.desk_risk_configs;
CREATE TRIGGER trg_desk_risk_configs_admin_write
  BEFORE INSERT OR UPDATE OR DELETE ON public.desk_risk_configs
  FOR EACH ROW EXECUTE FUNCTION tradex_private.enforce_desk_risk_admin_write();

INSERT INTO public.desk_risk_configs (
  firm_name, base_currency, max_firm_leverage, max_daily_loss_percent,
  max_total_drawdown_percent, circuit_breaker_threshold_percent, auto_freeze_on_breach,
  allow_crypto, allow_options, require_manager_order_approval, approval_threshold_inr
)
SELECT
  'TradeX Institutional Desk (NSE / BSE)', 'INR', 5.0, 3.0, 8.0, 5.0, true, false, true, true, 250000
WHERE NOT EXISTS (SELECT 1 FROM public.desk_risk_configs);

-- -----------------------------------------------------------------------------
-- 6. Issue #92: Atomic Subscription Updates Across Billing Providers
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.billing_provider_entitlements (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK (provider IN ('razorpay', 'revenuecat')),
  tier text NOT NULL CHECK (tier IN ('free', 'premium', 'enterprise')),
  status text NOT NULL CHECK (status IN ('active', 'canceled', 'expired', 'authenticated', 'created')),
  provider_subscription_id text,
  revenuecat_id text,
  billing_cycle text CHECK (billing_cycle IN ('monthly', 'annual')),
  renewed_at timestamptz,
  expires_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, provider)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_billing_provider_entitlements_user_provider
  ON public.billing_provider_entitlements (user_id, provider);

ALTER TABLE public.billing_provider_entitlements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.billing_provider_entitlements FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.billing_provider_entitlements TO service_role;

CREATE TABLE IF NOT EXISTS public.billing_webhook_receipts (
  provider text NOT NULL CHECK (provider IN ('razorpay', 'revenuecat')),
  event_id text NOT NULL,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (provider, event_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_billing_webhook_receipts_provider_event
  ON public.billing_webhook_receipts (provider, event_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriptions_user_id_unique
  ON public.subscriptions (user_id);

ALTER TABLE public.billing_webhook_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.billing_webhook_receipts FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.billing_webhook_receipts TO service_role;

-- Backfill billing_provider_entitlements from existing subscriptions rows
INSERT INTO public.billing_provider_entitlements (
  user_id, provider, tier, status, provider_subscription_id, revenuecat_id,
  billing_cycle, renewed_at, expires_at, updated_at
)
SELECT
  s.user_id,
  s.billing_provider,
  CASE
    WHEN s.tier IN ('pro', 'enterprise') THEN 'enterprise'
    WHEN s.tier IN ('basic', 'premium') THEN 'premium'
    ELSE 'free'
  END,
  CASE
    WHEN s.status IN ('active', 'canceled', 'expired', 'authenticated', 'created') THEN s.status
    ELSE 'active'
  END,
  s.provider_subscription_id,
  s.revenuecat_id,
  CASE WHEN s.billing_cycle IN ('monthly', 'annual') THEN s.billing_cycle ELSE NULL END,
  s.renewed_at,
  s.expires_at,
  COALESCE(s.updated_at, now())
FROM public.subscriptions s
WHERE s.billing_provider IN ('razorpay', 'revenuecat')
ON CONFLICT (user_id, provider) DO NOTHING;

CREATE OR REPLACE FUNCTION public.reconcile_billing_entitlement(
  p_user_id uuid,
  p_provider text,
  p_tier text,
  p_status text,
  p_provider_subscription_id text DEFAULT NULL,
  p_revenuecat_id text DEFAULT NULL,
  p_billing_cycle text DEFAULT NULL,
  p_renewed_at timestamptz DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL,
  p_event_id text DEFAULT NULL,
  p_event_type text DEFAULT 'UNKNOWN',
  p_intent_id uuid DEFAULT NULL,
  p_intent_status text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now timestamptz := now();
  v_norm_tier text;
  v_norm_status text;
  v_existing_rp public.billing_provider_entitlements%ROWTYPE;
  v_rp public.billing_provider_entitlements%ROWTYPE;
  v_rc public.billing_provider_entitlements%ROWTYPE;
  v_rp_valid boolean := false;
  v_rc_valid boolean := false;
  v_effective_tier text := 'free';
  v_effective_status text := 'canceled';
  v_effective_provider text;
  v_effective_sub_id text;
  v_effective_rc_id text;
  v_effective_cycle text;
  v_effective_renewed timestamptz;
  v_effective_expires timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Account user_id is required' USING ERRCODE = '22023';
  END IF;
  IF p_provider NOT IN ('razorpay', 'revenuecat') THEN
    RAISE EXCEPTION 'Unsupported billing provider: %', p_provider USING ERRCODE = '22023';
  END IF;

  -- Serialize all billing reconciliations for this account within the transaction
  PERFORM pg_advisory_xact_lock(hashtext('billing_reconcile'), hashtext(p_user_id::text));

  -- Lock the profile row to verify account existence and serialize tier writes
  PERFORM 1 FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Account not found' USING ERRCODE = 'P0002';
  END IF;

  -- Seed provider entitlements from current subscriptions row if not yet tracked
  INSERT INTO public.billing_provider_entitlements (
    user_id, provider, tier, status, provider_subscription_id, revenuecat_id,
    billing_cycle, renewed_at, expires_at, updated_at
  )
  SELECT
    s.user_id,
    s.billing_provider,
    CASE
      WHEN s.tier IN ('pro', 'enterprise') THEN 'enterprise'
      WHEN s.tier IN ('basic', 'premium') THEN 'premium'
      ELSE 'free'
    END,
    CASE
      WHEN s.status IN ('active', 'canceled', 'expired', 'authenticated', 'created') THEN s.status
      ELSE 'active'
    END,
    s.provider_subscription_id,
    s.revenuecat_id,
    CASE WHEN s.billing_cycle IN ('monthly', 'annual') THEN s.billing_cycle ELSE NULL END,
    s.renewed_at,
    s.expires_at,
    COALESCE(s.updated_at, v_now)
  FROM public.subscriptions s
  WHERE s.user_id = p_user_id
    AND s.billing_provider IN ('razorpay', 'revenuecat')
  ON CONFLICT (user_id, provider) DO NOTHING;

  v_norm_tier := CASE
    WHEN p_tier IN ('pro', 'enterprise') THEN 'enterprise'
    WHEN p_tier IN ('basic', 'premium') THEN 'premium'
    ELSE 'free'
  END;

  v_norm_status := CASE
    WHEN p_status IN ('active', 'canceled', 'expired', 'authenticated', 'created') THEN p_status
    ELSE 'canceled'
  END;

  -- Update checkout intent if supplied
  IF p_intent_id IS NOT NULL AND p_intent_status IS NOT NULL THEN
    UPDATE public.billing_checkout_intents
       SET status = p_intent_status,
           updated_at = v_now
     WHERE id = p_intent_id
       AND user_id = p_user_id;
  END IF;

  -- Update the provider-specific entitlement state (preventing an old inactive Razorpay checkout
  -- from overwriting a newer active Razorpay subscription for the same user)
  IF p_provider = 'razorpay' THEN
    SELECT * INTO v_existing_rp
      FROM public.billing_provider_entitlements
     WHERE user_id = p_user_id AND provider = 'razorpay';

    IF FOUND
       AND v_norm_tier = 'free'
       AND v_existing_rp.provider_subscription_id IS DISTINCT FROM p_provider_subscription_id
       AND v_existing_rp.tier = 'enterprise'
       AND v_existing_rp.status IN ('active', 'canceled')
       AND v_existing_rp.expires_at IS NOT NULL
       AND v_existing_rp.expires_at > v_now THEN
      -- Preserve the newer active Razorpay subscription
      NULL;
    ELSE
      INSERT INTO public.billing_provider_entitlements (
        user_id, provider, tier, status, provider_subscription_id, revenuecat_id,
        billing_cycle, renewed_at, expires_at, updated_at
      ) VALUES (
        p_user_id, 'razorpay', v_norm_tier, v_norm_status, p_provider_subscription_id, NULL,
        CASE WHEN p_billing_cycle IN ('monthly', 'annual') THEN p_billing_cycle ELSE NULL END,
        p_renewed_at, COALESCE(p_expires_at, v_now), v_now
      )
      ON CONFLICT (user_id, provider) DO UPDATE SET
        tier = EXCLUDED.tier,
        status = EXCLUDED.status,
        provider_subscription_id = EXCLUDED.provider_subscription_id,
        billing_cycle = EXCLUDED.billing_cycle,
        renewed_at = EXCLUDED.renewed_at,
        expires_at = EXCLUDED.expires_at,
        updated_at = v_now;
    END IF;
  ELSE
    INSERT INTO public.billing_provider_entitlements (
      user_id, provider, tier, status, provider_subscription_id, revenuecat_id,
      billing_cycle, renewed_at, expires_at, updated_at
    ) VALUES (
      p_user_id, 'revenuecat', v_norm_tier, v_norm_status, NULL, COALESCE(p_revenuecat_id, p_user_id::text),
      CASE WHEN p_billing_cycle IN ('monthly', 'annual') THEN p_billing_cycle ELSE NULL END,
      p_renewed_at, COALESCE(p_expires_at, v_now), v_now
    )
    ON CONFLICT (user_id, provider) DO UPDATE SET
      tier = EXCLUDED.tier,
      status = EXCLUDED.status,
      revenuecat_id = EXCLUDED.revenuecat_id,
      billing_cycle = EXCLUDED.billing_cycle,
      renewed_at = EXCLUDED.renewed_at,
      expires_at = EXCLUDED.expires_at,
      updated_at = v_now;
  END IF;

  -- Evaluate effective entitlement across providers while holding the account lock
  SELECT * INTO v_rp
    FROM public.billing_provider_entitlements
   WHERE user_id = p_user_id AND provider = 'razorpay';

  SELECT * INTO v_rc
    FROM public.billing_provider_entitlements
   WHERE user_id = p_user_id AND provider = 'revenuecat';

  v_rp_valid := v_rp.user_id IS NOT NULL
    AND v_rp.tier = 'enterprise'
    AND v_rp.status IN ('active', 'canceled')
    AND v_rp.expires_at IS NOT NULL
    AND v_rp.expires_at > v_now;

  v_rc_valid := v_rc.user_id IS NOT NULL
    AND v_rc.tier = 'premium'
    AND v_rc.status IN ('active', 'canceled')
    AND v_rc.expires_at IS NOT NULL
    AND v_rc.expires_at > v_now;

  IF v_rp_valid THEN
    v_effective_tier := 'enterprise';
    v_effective_status := v_rp.status;
    v_effective_provider := 'razorpay';
    v_effective_sub_id := v_rp.provider_subscription_id;
    v_effective_rc_id := NULL;
    v_effective_cycle := v_rp.billing_cycle;
    v_effective_renewed := v_rp.renewed_at;
    v_effective_expires := v_rp.expires_at;
  ELSIF v_rc_valid THEN
    v_effective_tier := 'premium';
    v_effective_status := v_rc.status;
    v_effective_provider := 'revenuecat';
    v_effective_sub_id := NULL;
    v_effective_rc_id := v_rc.revenuecat_id;
    v_effective_cycle := v_rc.billing_cycle;
    v_effective_renewed := v_rc.renewed_at;
    v_effective_expires := v_rc.expires_at;
  ELSE
    v_effective_tier := 'free';
    v_effective_status := 'canceled';
    v_effective_provider := p_provider;
    v_effective_sub_id := CASE WHEN p_provider = 'razorpay' THEN p_provider_subscription_id ELSE NULL END;
    v_effective_rc_id := CASE WHEN p_provider = 'revenuecat' THEN COALESCE(p_revenuecat_id, p_user_id::text) ELSE NULL END;
    v_effective_cycle := CASE WHEN p_billing_cycle IN ('monthly', 'annual') THEN p_billing_cycle ELSE NULL END;
    v_effective_renewed := NULL;
    v_effective_expires := v_now;
  END IF;

  INSERT INTO public.subscriptions (
    user_id,
    tier,
    status,
    billing_provider,
    provider_subscription_id,
    revenuecat_id,
    billing_cycle,
    renewed_at,
    expires_at,
    updated_at
  ) VALUES (
    p_user_id,
    v_effective_tier,
    v_effective_status,
    v_effective_provider,
    v_effective_sub_id,
    v_effective_rc_id,
    v_effective_cycle,
    v_effective_renewed,
    v_effective_expires,
    v_now
  )
  ON CONFLICT (user_id) DO UPDATE SET
    tier = EXCLUDED.tier,
    status = EXCLUDED.status,
    billing_provider = EXCLUDED.billing_provider,
    provider_subscription_id = EXCLUDED.provider_subscription_id,
    revenuecat_id = EXCLUDED.revenuecat_id,
    billing_cycle = EXCLUDED.billing_cycle,
    renewed_at = EXCLUDED.renewed_at,
    expires_at = EXCLUDED.expires_at,
    updated_at = v_now;

  UPDATE public.profiles
     SET subscription_tier = v_effective_tier,
         updated_at = v_now
   WHERE id = p_user_id;

  IF p_event_id IS NOT NULL AND btrim(p_event_id) <> '' THEN
    INSERT INTO public.billing_webhook_receipts (provider, event_id, user_id, event_type, processed_at)
    VALUES (p_provider, p_event_id, p_user_id, COALESCE(p_event_type, 'UNKNOWN'), v_now)
    ON CONFLICT (provider, event_id) DO UPDATE SET
      processed_at = EXCLUDED.processed_at;

    IF p_provider = 'revenuecat' AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'revenuecat_webhook_events') THEN
      INSERT INTO public.revenuecat_webhook_events (event_id, event_type, processed_at)
      VALUES (p_event_id, COALESCE(p_event_type, 'UNKNOWN'), v_now)
      ON CONFLICT (event_id) DO UPDATE SET
        event_type = EXCLUDED.event_type,
        processed_at = EXCLUDED.processed_at;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'tier', v_effective_tier,
    'status', v_effective_status,
    'billing_provider', v_effective_provider,
    'expires_at', v_effective_expires
  );
END;
$$;

REVOKE ALL ON FUNCTION public.reconcile_billing_entitlement(
  uuid, text, text, text, text, text, text, timestamptz, timestamptz, text, text, uuid, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_billing_entitlement(
  uuid, text, text, text, text, text, text, timestamptz, timestamptz, text, text, uuid, text
) TO service_role;

-- -----------------------------------------------------------------------------
-- 7. Issue #93: Prevent Unauthorized Changes to Community Post View Counts
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.post_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_post_views_unique_post_user
  ON public.post_views (post_id, user_id);

ALTER TABLE public.post_views ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.post_views FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.post_views TO service_role;

-- Ensure votes_count exists on community_poll_options across all environments
ALTER TABLE IF EXISTS public.community_poll_options
  ADD COLUMN IF NOT EXISTS votes_count integer NOT NULL DEFAULT 0;

-- Trigger to block direct client writes to derived engagement counters on community tables
CREATE OR REPLACE FUNCTION tradex_private.protect_community_derived_counters()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_new jsonb;
  v_old jsonb;
BEGIN
  IF COALESCE(current_setting('tradex.trusted_counter_write', true), '') = 'on' THEN
    RETURN NEW;
  END IF;

  v_new := to_jsonb(NEW);

  IF TG_OP = 'INSERT' THEN
    IF TG_TABLE_NAME = 'community_posts' THEN
      NEW := jsonb_populate_record(
        NEW,
        jsonb_build_object(
          'views_count', 0,
          'likes_count', 0,
          'comments_count', 0,
          'reposts_count', 0,
          'bookmarks_count', 0
        )
      );
    ELSIF TG_TABLE_NAME = 'community_comments' THEN
      NEW := jsonb_populate_record(NEW, jsonb_build_object('likes_count', 0));
    ELSIF TG_TABLE_NAME = 'community_poll_options' THEN
      NEW := jsonb_populate_record(NEW, jsonb_build_object('votes_count', 0));
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    v_old := to_jsonb(OLD);
    IF TG_TABLE_NAME = 'community_posts' THEN
      IF (v_new->'views_count') IS DISTINCT FROM (v_old->'views_count')
        OR (v_new->'likes_count') IS DISTINCT FROM (v_old->'likes_count')
        OR (v_new->'comments_count') IS DISTINCT FROM (v_old->'comments_count')
        OR (v_new->'reposts_count') IS DISTINCT FROM (v_old->'reposts_count')
        OR (v_new->'bookmarks_count') IS DISTINCT FROM (v_old->'bookmarks_count')
      THEN
        RAISE EXCEPTION 'Derived engagement counters cannot be modified directly' USING ERRCODE = '42501';
      END IF;
    ELSIF TG_TABLE_NAME = 'community_comments' THEN
      IF (v_new->'likes_count') IS DISTINCT FROM (v_old->'likes_count') THEN
        RAISE EXCEPTION 'Derived engagement counters cannot be modified directly' USING ERRCODE = '42501';
      END IF;
    ELSIF TG_TABLE_NAME = 'community_poll_options' THEN
      IF (v_new->'votes_count') IS DISTINCT FROM (v_old->'votes_count') THEN
        RAISE EXCEPTION 'Derived engagement counters cannot be modified directly' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_community_derived_counters ON public.community_posts;
CREATE TRIGGER trg_protect_community_derived_counters
  BEFORE INSERT OR UPDATE ON public.community_posts
  FOR EACH ROW EXECUTE FUNCTION tradex_private.protect_community_derived_counters();

DROP TRIGGER IF EXISTS trg_protect_community_derived_counters ON public.community_comments;
CREATE TRIGGER trg_protect_community_derived_counters
  BEFORE INSERT OR UPDATE ON public.community_comments
  FOR EACH ROW EXECUTE FUNCTION tradex_private.protect_community_derived_counters();

DROP TRIGGER IF EXISTS trg_protect_community_derived_counters ON public.community_poll_options;
CREATE TRIGGER trg_protect_community_derived_counters
  BEFORE INSERT OR UPDATE ON public.community_poll_options
  FOR EACH ROW EXECUTE FUNCTION tradex_private.protect_community_derived_counters();

-- Update trusted counter maintenance triggers to set tradex.trusted_counter_write = 'on'
CREATE OR REPLACE FUNCTION public.update_community_post_likes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM set_config('tradex.trusted_counter_write', 'on', true);
  IF TG_OP = 'INSERT' THEN
    UPDATE public.community_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.community_posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id;
  END IF;
  PERFORM set_config('tradex.trusted_counter_write', 'off', true);
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_community_post_comments()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM set_config('tradex.trusted_counter_write', 'on', true);
  IF TG_OP = 'INSERT' THEN
    UPDATE public.community_posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.community_posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = OLD.post_id;
  END IF;
  PERFORM set_config('tradex.trusted_counter_write', 'off', true);
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_community_post_reposts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM set_config('tradex.trusted_counter_write', 'on', true);
  IF TG_OP = 'INSERT' THEN
    UPDATE public.community_posts SET reposts_count = reposts_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.community_posts SET reposts_count = GREATEST(0, reposts_count - 1) WHERE id = OLD.post_id;
  END IF;
  PERFORM set_config('tradex.trusted_counter_write', 'off', true);
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_community_poll_votes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM set_config('tradex.trusted_counter_write', 'on', true);
  IF TG_OP = 'INSERT' THEN
    UPDATE public.community_poll_options SET votes_count = votes_count + 1 WHERE id = NEW.option_id;
  ELSIF TG_OP = 'UPDATE' AND NEW.option_id IS DISTINCT FROM OLD.option_id THEN
    UPDATE public.community_poll_options SET votes_count = GREATEST(0, votes_count - 1) WHERE id = OLD.option_id;
    UPDATE public.community_poll_options SET votes_count = votes_count + 1 WHERE id = NEW.option_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.community_poll_options SET votes_count = GREATEST(0, votes_count - 1) WHERE id = OLD.option_id;
  END IF;
  PERFORM set_config('tradex.trusted_counter_write', 'off', true);
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_community_comment_likes_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM set_config('tradex.trusted_counter_write', 'on', true);
  IF TG_OP = 'INSERT' THEN
    UPDATE public.community_comments SET likes_count = likes_count + 1 WHERE id = NEW.comment_id;
    PERFORM set_config('tradex.trusted_counter_write', 'off', true);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.community_comments SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.comment_id;
    PERFORM set_config('tradex.trusted_counter_write', 'off', true);
    RETURN OLD;
  END IF;
  PERFORM set_config('tradex.trusted_counter_write', 'off', true);
  RETURN NULL;
END;
$$;

-- Hardened increment_post_views requiring caller authentication, post visibility, and deduplication
CREATE OR REPLACE FUNCTION public.increment_post_views(p_post_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid;
  v_author_id uuid;
  v_is_public boolean;
  v_moderation_status text;
  v_admin_hidden boolean;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL OR NOT tradex_private.account_active(v_user_id) THEN
    RETURN;
  END IF;

  SELECT author_id, is_public, moderation_status, COALESCE(admin_hidden, false)
    INTO v_author_id, v_is_public, v_moderation_status, v_admin_hidden
    FROM public.community_posts
   WHERE id = p_post_id;

  IF v_author_id IS NULL THEN
    RETURN;
  END IF;

  IF v_admin_hidden AND NOT public.is_user_admin() THEN
    RETURN;
  END IF;

  IF NOT (
    (v_moderation_status = 'approved' AND v_is_public = true)
    OR v_user_id = v_author_id
    OR public.is_user_admin()
  ) THEN
    RETURN;
  END IF;

  IF v_user_id <> v_author_id
     AND NOT public.is_user_admin()
     AND public.are_blocked(v_user_id, v_author_id) THEN
    RETURN;
  END IF;

  INSERT INTO public.post_views (post_id, user_id)
  VALUES (p_post_id, v_user_id)
  ON CONFLICT (post_id, user_id) DO NOTHING;

  IF FOUND THEN
    PERFORM set_config('tradex.trusted_counter_write', 'on', true);
    UPDATE public.community_posts
       SET views_count = COALESCE(views_count, 0) + 1
     WHERE id = p_post_id;
    PERFORM set_config('tradex.trusted_counter_write', 'off', true);
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_post_views(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.increment_post_views(uuid) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
