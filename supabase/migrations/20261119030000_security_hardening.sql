BEGIN;

-- Application roles may use objects explicitly granted to them, but must not
-- be able to create attacker-controlled objects in the API-exposed schema.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. Remove that
-- default so every future RPC must name its intended callers explicitly.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Public share RPCs expose an intentionally reduced, publication-only shape.
-- Keep them available, but replace implicit PUBLIC execution with named roles.
DO $$
BEGIN
  IF to_regprocedure('public.public_document(text,uuid)') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.public_document(text,uuid) FROM PUBLIC, anon, authenticated';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.public_document(text,uuid) TO anon, authenticated, service_role';
  END IF;
  IF to_regprocedure('public.public_refs(text,uuid)') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.public_refs(text,uuid) FROM PUBLIC, anon, authenticated';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.public_refs(text,uuid) TO anon, authenticated, service_role';
  END IF;
  IF to_regprocedure('public.public_strategy_performance(uuid)') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.public_strategy_performance(uuid) FROM PUBLIC, anon, authenticated';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.public_strategy_performance(uuid) TO anon, authenticated, service_role';
  END IF;
END
$$;

-- These helpers bypass RLS only to answer whether the signed-in caller is an
-- active administrator. Anonymous and implicit PUBLIC execution are not needed.
DO $$
BEGIN
  IF to_regprocedure('public.is_admin_caller()') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.is_admin_caller() FROM PUBLIC, anon, authenticated';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.is_admin_caller() TO authenticated, service_role';
  END IF;
  IF to_regprocedure('public.is_user_admin()') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.is_user_admin() FROM PUBLIC, anon, authenticated';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.is_user_admin() TO authenticated, service_role';
  END IF;
END
$$;

-- Trigger entry points must never be callable as RPCs. PostgreSQL invokes them
-- from their registered triggers without granting client roles EXECUTE.
DO $$
DECLARE
  v_signature text;
  v_signatures text[] := ARRAY[
    'public.enforce_user_registration_cap()',
    'public.enforce_published_customer_quota()',
    'public.update_community_post_likes()',
    'public.update_community_post_comments()',
    'public.update_community_post_reposts()',
    'public.update_community_poll_votes()',
    'public.trg_community_comment_likes_count()'
  ];
BEGIN
  FOREACH v_signature IN ARRAY v_signatures
  LOOP
    IF to_regprocedure(v_signature) IS NOT NULL THEN
      EXECUTE 'REVOKE ALL ON FUNCTION ' || v_signature
        || ' FROM PUBLIC, anon, authenticated';
    END IF;
  END LOOP;
END
$$;

COMMIT;
