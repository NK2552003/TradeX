-- Enhance admin list & overview RPCs with safe live preview excerpts and
-- real database breakdowns (tier mix, role distribution, AI provider usage,
-- moderation queues, and live preview feeds) without exposing encrypted ciphertext
-- or raw payout/identity secrets.

CREATE OR REPLACE FUNCTION tradex_private.admin_safe_preview(p_text text, p_max integer DEFAULT 220)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE
    WHEN p_text IS NULL OR btrim(p_text) = '' THEN ''
    WHEN btrim(p_text) LIKE 'e2ee:v1:%' THEN 'End-to-end encrypted content'
    ELSE left(regexp_replace(btrim(p_text), '\s+', ' ', 'g'), GREATEST(1, p_max))
  END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.admin_list(
  p_resource text, p_user uuid DEFAULT NULL, p_search text DEFAULT '', p_status text DEFAULT 'all',
  p_page integer DEFAULT 0, p_page_size integer DEFAULT 25,
  p_from timestamptz DEFAULT NULL, p_to timestamptz DEFAULT NULL, p_parent uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE source text; filtered text; total bigint; rows jsonb;
BEGIN
  PERFORM tradex_private.require_admin();
  IF p_page<0 OR p_page_size<1 OR p_page_size>100 OR length(p_search)>200 THEN
    RAISE EXCEPTION 'Invalid page or search' USING ERRCODE='22023';
  END IF;
  CASE p_resource
  WHEN 'users' THEN source := $q$
    SELECT jsonb_build_object(
      'id', p.id,
      'user_id', p.id,
      'title', coalesce(nullif(p.display_name,''), p.handle::text),
      'display_name', p.display_name,
      'handle', p.handle,
      'email', p.email,
      'avatar_url', p.avatar_url,
      'role', p.role,
      'status', p.status,
      'created_at', p.created_at,
      'last_active_at', p.last_active_at,
      'tier', tradex_private.effective_tier(p.id),
      'posts_count', (SELECT count(*) FROM public.community_posts cp WHERE cp.author_id = p.id),
      'notes_count', (SELECT count(*) FROM public.trader_notes tn WHERE tn.user_id = p.id),
      'journal_count', (SELECT count(*) FROM public.journal_entries je WHERE je.user_id = p.id),
      'ai_count', (SELECT count(*) FROM public.ai_insight_requests air WHERE air.user_id = p.id)
    ) AS j FROM public.profiles p$q$;
  WHEN 'posts' THEN source := $q$
    SELECT (to_jsonb(t) - 'body') || jsonb_build_object(
      'user_id', t.author_id,
      'body', tradex_private.admin_safe_preview(t.body, 280),
      'preview', tradex_private.admin_safe_preview(t.body, 220),
      'author', coalesce(p.display_name, p.handle::text),
      'author_handle', p.handle,
      'author_avatar_url', p.avatar_url,
      'status', t.moderation_status
    ) j
    FROM public.community_posts t JOIN public.profiles p ON p.id = t.author_id$q$;
  WHEN 'comments' THEN source := $q$
    SELECT (to_jsonb(t) - 'body') || jsonb_build_object(
      'user_id', t.author_id,
      'parent_id', t.post_id,
      'title', tradex_private.admin_safe_preview(t.body, 120),
      'preview', tradex_private.admin_safe_preview(t.body, 220),
      'author', coalesce(p.display_name, p.handle::text),
      'author_handle', p.handle,
      'status', t.moderation_status
    ) j
    FROM public.community_comments t JOIN public.profiles p ON p.id = t.author_id$q$;
  WHEN 'notes' THEN source := $q$
    SELECT (to_jsonb(t) - 'content') || jsonb_build_object(
      'author', coalesce(p.display_name, p.handle::text),
      'author_handle', p.handle,
      'preview', tradex_private.admin_safe_preview(coalesce(nullif(to_jsonb(t)->>'summary', ''), to_jsonb(t)->>'content'), 220),
      'status', CASE WHEN t.admin_hidden THEN 'restricted' WHEN t.is_public THEN 'public' ELSE 'private' END
    ) j
    FROM public.trader_notes t JOIN public.profiles p ON p.id = t.user_id$q$;
  WHEN 'journal' THEN source := $q$
    SELECT (to_jsonb(t) - ARRAY['content','psychology','mistakes_made','lessons_learned']) || jsonb_build_object(
      'author', coalesce(p.display_name, p.handle::text),
      'author_handle', p.handle,
      'preview', tradex_private.admin_safe_preview(coalesce(nullif(to_jsonb(t)->>'summary', ''), to_jsonb(t)->>'content'), 220),
      'status', CASE WHEN t.admin_hidden THEN 'restricted' WHEN t.is_public THEN 'public' ELSE 'private' END
    ) j
    FROM public.journal_entries t JOIN public.profiles p ON p.id = t.user_id$q$;
  WHEN 'strategies' THEN source := $q$
    SELECT (to_jsonb(t) - ARRAY['content','ai_summary']) || jsonb_build_object(
      'author', coalesce(p.display_name, p.handle::text),
      'author_handle', p.handle,
      'preview', tradex_private.admin_safe_preview(coalesce(nullif(to_jsonb(t)->>'summary', ''), nullif(to_jsonb(t)->>'ai_summary', ''), to_jsonb(t)->>'content'), 220),
      'status', CASE WHEN t.admin_hidden THEN 'restricted' ELSE t.status END
    ) j
    FROM public.strategies t JOIN public.profiles p ON p.id = t.user_id$q$;
  WHEN 'messages' THEN source := $q$
    SELECT (to_jsonb(t) - 'body') || jsonb_build_object(
      'user_id', t.sender_id,
      'parent_id', t.thread_id,
      'title', tradex_private.admin_safe_preview(t.body, 120),
      'preview', tradex_private.admin_safe_preview(t.body, 220),
      'author', coalesce(p.display_name, p.handle::text),
      'status', CASE WHEN t.admin_hidden THEN 'restricted' ELSE t.status END
    ) j
    FROM public.chat_messages t JOIN public.profiles p ON p.id = t.sender_id$q$;
  WHEN 'ai' THEN source := $q$
    SELECT to_jsonb(t) || jsonb_build_object(
      'author', coalesce(p.display_name, p.handle::text),
      'status', CASE WHEN t.admin_hidden THEN 'restricted' ELSE 'active' END,
      'messages_count', (SELECT count(*) FROM public.ai_messages m WHERE m.thread_id = t.id),
      'preview', coalesce(
        (SELECT tradex_private.admin_safe_preview(m.body, 200)
         FROM public.ai_messages m
         WHERE m.thread_id = t.id
         ORDER BY m.created_at DESC
         LIMIT 1),
        ''
      )
    ) j
    FROM public.ai_threads t JOIN public.profiles p ON p.id = t.user_id$q$;
  WHEN 'ai_messages' THEN source := $q$
    SELECT (to_jsonb(m) - 'body') || jsonb_build_object(
      'user_id', t.user_id,
      'parent_id', m.thread_id,
      'title', tradex_private.admin_safe_preview(m.body, 120),
      'preview', tradex_private.admin_safe_preview(m.body, 220),
      'author', m.role,
      'status', CASE WHEN m.error IS NOT NULL THEN 'failed' ELSE 'complete' END
    ) j
    FROM public.ai_messages m JOIN public.ai_threads t ON t.id = m.thread_id$q$;
  WHEN 'ai_requests' THEN source := $q$
    SELECT (to_jsonb(t) - ARRAY['prompt_text','response_text']) || jsonb_build_object(
      'title', coalesce(nullif(to_jsonb(t)->>'model', ''), t.kind),
      'created_at', t.requested_at,
      'parent_id', t.thread_id,
      'author', coalesce(p.display_name, p.handle::text),
      'preview', tradex_private.admin_safe_preview(t.prompt_text, 180),
      'response_preview', tradex_private.admin_safe_preview(t.response_text, 180)
    ) j
    FROM public.ai_insight_requests t JOIN public.profiles p ON p.id = t.user_id$q$;
  WHEN 'affiliates' THEN source := $q$
    SELECT (to_jsonb(t) - ARRAY['payout_details','pan_number','gstin']) || jsonb_build_object(
      'user_id', t.id,
      'title', coalesce(p.display_name, p.handle::text),
      'email', p.email,
      'handle', p.handle,
      'avatar_url', p.avatar_url
    ) j
    FROM public.affiliate_profiles t JOIN public.profiles p ON p.id = t.id$q$;
  WHEN 'applications' THEN source := $q$
    SELECT (to_jsonb(t) - ARRAY['account_number','pan','date_of_birth','phone']) || jsonb_build_object(
      'title', t.full_name,
      'preview', concat_ws(' · ', nullif(t.primary_platform, ''), nullif(t.audience_reach, ''), nullif(t.channel_handle, '')),
      'status', CASE WHEN t.status = 'pending_review' THEN 'pending' ELSE t.status END
    ) j
    FROM public.affiliate_applications t$q$;
  WHEN 'referrals' THEN source := $q$
    SELECT to_jsonb(t) || jsonb_build_object(
      'user_id', t.affiliate_id,
      'title', coalesce(p.display_name, p.handle::text),
      'author', coalesce(p.display_name, p.handle::text)
    ) j
    FROM public.affiliate_referrals t JOIN public.profiles p ON p.id = t.referred_user_id$q$;
  WHEN 'payouts' THEN source := $q$
    SELECT (to_jsonb(t) - 'payout_details') || jsonb_build_object(
      'user_id', t.affiliate_id,
      'title', coalesce(p.display_name, p.handle::text),
      'email', p.email
    ) j
    FROM public.affiliate_payouts t JOIN public.profiles p ON p.id = t.affiliate_id$q$;
  WHEN 'subscriptions' THEN source := $q$
    SELECT coalesce(to_jsonb(s), '{}'::jsonb) || jsonb_build_object(
      'id', p.id,
      'user_id', p.id,
      'title', coalesce(p.display_name, p.handle::text),
      'email', p.email,
      'handle', p.handle,
      'created_at', p.created_at,
      'status', coalesce(s.status, 'free'),
      'tier', tradex_private.effective_tier(p.id),
      'billing_tier', coalesce(s.tier, 'free'),
      'access_override', p.admin_controls->'subscription_override'
    ) j
    FROM public.profiles p LEFT JOIN public.subscriptions s ON s.user_id = p.id$q$;
  WHEN 'activity' THEN source := $q$
    SELECT (to_jsonb(t) - ARRAY['ip_address','sha256_hash']) || jsonb_build_object(
      'user_id', t.subject_user_id,
      'title', t.action || ' · ' || t.target_label,
      'author', t.actor_handle,
      'preview', coalesce(t.metadata->>'reason', ''),
      'status', t.category
    ) j
    FROM public.admin_audit_logs t$q$;
  WHEN 'deletions' THEN source := $q$
    SELECT to_jsonb(t) || jsonb_build_object(
      'user_id', coalesce(t.user_id, t.subject_user_id),
      'title', t.user_handle,
      'preview', tradex_private.admin_safe_preview(t.reason, 200)
    ) j FROM public.account_deletion_requests t$q$;
  ELSE RAISE EXCEPTION 'Unknown administration resource' USING ERRCODE='22023';
  END CASE;
  filtered := ' FROM (' || source || ') base WHERE '
    || '($1::uuid IS NULL OR j->>''user_id''=$1::text OR j->>''actor_id''=$1::text) '
    || 'AND ($2='''' OR concat_ws('' '',j->>''title'',j->>''email'',j->>''handle'',j->>''author'',j->>''preview'',j->>''id'',j->>''action'') ILIKE ''%'' || $2 || ''%'') '
    || 'AND ($3=''all'' OR j->>''status''=$3) '
    || 'AND ($4::timestamptz IS NULL OR (j->>''created_at'')::timestamptz >= $4) '
    || 'AND ($5::timestamptz IS NULL OR (j->>''created_at'')::timestamptz < $5) '
    || 'AND ($6::uuid IS NULL OR j->>''parent_id''=$6::text)';
  EXECUTE 'SELECT count(*)' || filtered INTO total USING p_user,p_search,p_status,p_from,p_to,p_parent;
  EXECUTE 'SELECT coalesce(jsonb_agg(j),''[]'') FROM (SELECT j' || filtered
    || ' ORDER BY (j->>''created_at'')::timestamptz DESC, j->>''id'' DESC LIMIT $7 OFFSET $8) page'
    INTO rows USING p_user,p_search,p_status,p_from,p_to,p_parent,p_page_size,p_page::bigint*p_page_size;
  RETURN jsonb_build_object('rows',rows,'total',total,'page',p_page,'page_size',p_page_size,'fetched_at',now());
END;
$$;

CREATE OR REPLACE FUNCTION tradex_private.admin_overview(p_days integer DEFAULT 30) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  start_at timestamptz;
  trend jsonb;
  tier_breakdown jsonb;
  role_breakdown jsonb;
  ai_providers jsonb;
  moderation_breakdown jsonb;
  preview_posts jsonb;
  preview_applications jsonb;
  preview_deletions jsonb;
  preview_users jsonb;
BEGIN
  PERFORM tradex_private.require_admin();
  IF p_days NOT IN (7,30,90) THEN RAISE EXCEPTION 'Choose 7, 30 or 90 days'; END IF;
  start_at := date_trunc('day',now())-make_interval(days=>p_days-1);

  SELECT jsonb_agg(jsonb_build_object('date',d,
    'users',(SELECT count(*) FROM public.profiles WHERE created_at>=d AND created_at<d+interval '1 day'),
    'posts',(SELECT count(*) FROM public.community_posts WHERE created_at>=d AND created_at<d+interval '1 day'),
    'messages',(SELECT count(*) FROM public.chat_messages WHERE created_at>=d AND created_at<d+interval '1 day'),
    'ai_requests',(SELECT count(*) FROM public.ai_insight_requests WHERE requested_at>=d AND requested_at<d+interval '1 day')) ORDER BY d)
    INTO trend FROM generate_series(start_at,date_trunc('day',now()),interval '1 day') d;

  SELECT coalesce(jsonb_object_agg(tier_name, cnt), '{}'::jsonb) INTO tier_breakdown
  FROM (
    SELECT tradex_private.effective_tier(p.id) AS tier_name, count(*) AS cnt
    FROM public.profiles p
    GROUP BY 1
  ) tb;

  SELECT coalesce(jsonb_object_agg(role_name, cnt), '{}'::jsonb) INTO role_breakdown
  FROM (
    SELECT coalesce(nullif(p.role, ''), 'customer') AS role_name, count(*) AS cnt
    FROM public.profiles p
    GROUP BY 1
  ) rb;

  SELECT coalesce(jsonb_agg(x), '[]'::jsonb) INTO ai_providers
  FROM (
    SELECT
      coalesce(nullif(to_jsonb(r)->>'provider', ''), 'gateway') AS provider,
      coalesce(nullif(to_jsonb(r)->>'model', ''), r.kind) AS model,
      count(*) AS count,
      coalesce(sum(coalesce((to_jsonb(r)->>'input_tokens')::bigint, 0) + coalesce((to_jsonb(r)->>'output_tokens')::bigint, 0)), 0) AS tokens
    FROM public.ai_insight_requests r
    WHERE r.requested_at >= start_at
    GROUP BY 1, 2
    ORDER BY count DESC
    LIMIT 6
  ) x;

  moderation_breakdown := jsonb_build_object(
    'approved_posts', (SELECT count(*) FROM public.community_posts WHERE moderation_status = 'approved'),
    'pending_posts', (SELECT count(*) FROM public.community_posts WHERE moderation_status = 'pending'),
    'rejected_posts', (SELECT count(*) FROM public.community_posts WHERE moderation_status = 'rejected'),
    'pending_comments', (SELECT count(*) FROM public.community_comments WHERE moderation_status = 'pending')
  );

  preview_posts := (tradex_private.admin_list('posts', p_page_size => 4))->'rows';
  preview_applications := (tradex_private.admin_list('applications', p_page_size => 4))->'rows';
  preview_deletions := (tradex_private.admin_list('deletions', p_page_size => 4))->'rows';
  preview_users := (tradex_private.admin_list('users', p_page_size => 4))->'rows';

  RETURN jsonb_build_object(
    'fetched_at', now(),
    'from', start_at,
    'days', p_days,
    'trend', trend,
    'users', (SELECT count(*) FROM public.profiles),
    'active_accounts', (SELECT count(*) FROM public.profiles WHERE status='active'),
    'suspended_accounts', (SELECT count(*) FROM public.profiles WHERE status='suspended'),
    'new_users', (SELECT count(*) FROM public.profiles WHERE created_at>=start_at),
    'active_users', (SELECT count(DISTINCT actor_id) FROM public.admin_audit_logs WHERE created_at>=start_at AND actor_id IS NOT NULL),
    'affiliates', (SELECT count(*) FROM public.affiliate_profiles WHERE status='active'),
    'pending_applications', (SELECT count(*) FROM public.affiliate_applications WHERE status IN ('pending','pending_review')),
    'posts', (SELECT count(*) FROM public.community_posts),
    'pending_posts', (SELECT count(*) FROM public.community_posts WHERE moderation_status='pending'),
    'pending_comments', (SELECT count(*) FROM public.community_comments WHERE moderation_status='pending'),
    'post_views', (SELECT coalesce(sum(views_count),0) FROM public.community_posts),
    'notes', (SELECT count(*) FROM public.trader_notes),
    'journal', (SELECT count(*) FROM public.journal_entries),
    'strategies', (SELECT count(*) FROM public.strategies),
    'messages', (SELECT count(*) FROM public.chat_messages WHERE created_at>=start_at),
    'ai_requests', (SELECT count(*) FROM public.ai_insight_requests WHERE requested_at>=start_at),
    'subscriptions', (SELECT count(*) FROM public.subscriptions WHERE tier<>'free' AND status IN ('active','trialing','canceled') AND (expires_at IS NULL OR expires_at>now())),
    'access_grants', (SELECT count(*) FROM public.profiles WHERE (admin_controls->'subscription_override'->>'expires_at')::timestamptz>now()),
    'pending_deletions', (SELECT count(*) FROM public.account_deletion_requests WHERE status IN ('pending','grace_period')),
    'history_started_at', (SELECT min(created_at) FROM public.admin_audit_logs WHERE metadata->>'source'='database'),
    'recent_activity', (tradex_private.admin_list('activity', p_page_size=>8))->'rows',
    'tier_breakdown', tier_breakdown,
    'role_breakdown', role_breakdown,
    'ai_providers', ai_providers,
    'moderation_breakdown', moderation_breakdown,
    'preview_posts', preview_posts,
    'preview_applications', preview_applications,
    'preview_deletions', preview_deletions,
    'preview_users', preview_users
  );
END;
$$;

REVOKE ALL ON FUNCTION tradex_private.admin_safe_preview(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION tradex_private.admin_safe_preview(text, integer) TO authenticated;
REVOKE ALL ON FUNCTION tradex_private.admin_list(text,uuid,text,text,integer,integer,timestamptz,timestamptz,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION tradex_private.admin_list(text,uuid,text,text,integer,integer,timestamptz,timestamptz,uuid) TO authenticated;
REVOKE ALL ON FUNCTION tradex_private.admin_overview(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION tradex_private.admin_overview(integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
