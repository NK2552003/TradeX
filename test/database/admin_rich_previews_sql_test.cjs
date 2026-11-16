// Run with NODE_PATH pointing at an installation of @electric-sql/pglite.
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { PGlite } = require('@electric-sql/pglite');

(async () => {
  const db = new PGlite();
  const adminId = '00000000-0000-0000-0000-000000000099';
  const traderId = '00000000-0000-0000-0000-000000000001';
  const affId = '00000000-0000-0000-0000-000000000002';

  await db.exec(`
    CREATE ROLE anon;
    CREATE ROLE authenticated;
    CREATE SCHEMA auth;
    CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
      $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    GRANT USAGE ON SCHEMA auth TO authenticated;
    GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
    INSERT INTO auth.users(id) VALUES ('${adminId}'), ('${traderId}'), ('${affId}');

    CREATE SCHEMA tradex_private;
    GRANT USAGE ON SCHEMA tradex_private TO authenticated;

    CREATE TABLE public.profiles (
      id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
      handle text,
      display_name text,
      email text,
      avatar_url text,
      role text NOT NULL DEFAULT 'customer',
      status text NOT NULL DEFAULT 'active',
      admin_controls jsonb NOT NULL DEFAULT '{}'::jsonb,
      last_active_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.subscriptions (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      tier text NOT NULL DEFAULT 'free',
      status text NOT NULL DEFAULT 'active',
      expires_at timestamptz,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.community_posts (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      author_id uuid NOT NULL REFERENCES public.profiles(id),
      title text,
      body text,
      views_count integer NOT NULL DEFAULT 0,
      likes_count integer NOT NULL DEFAULT 0,
      comments_count integer NOT NULL DEFAULT 0,
      moderation_status text NOT NULL DEFAULT 'pending',
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.community_comments (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      post_id uuid NOT NULL REFERENCES public.community_posts(id),
      author_id uuid NOT NULL REFERENCES public.profiles(id),
      body text,
      likes_count integer NOT NULL DEFAULT 0,
      moderation_status text NOT NULL DEFAULT 'pending',
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.trader_notes (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES public.profiles(id),
      title text,
      summary text,
      content text,
      is_public boolean NOT NULL DEFAULT false,
      admin_hidden boolean NOT NULL DEFAULT false,
      word_count integer NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.journal_entries (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES public.profiles(id),
      title text,
      ticker text,
      side text,
      summary text,
      content text,
      psychology text,
      mistakes_made text,
      lessons_learned text,
      is_public boolean NOT NULL DEFAULT false,
      admin_hidden boolean NOT NULL DEFAULT false,
      word_count integer NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.strategies (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES public.profiles(id),
      title text,
      summary text,
      ai_summary text,
      content text,
      status text NOT NULL DEFAULT 'active',
      admin_hidden boolean NOT NULL DEFAULT false,
      word_count integer NOT NULL DEFAULT 0,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.chat_messages (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      thread_id uuid NOT NULL DEFAULT gen_random_uuid(),
      sender_id uuid NOT NULL REFERENCES public.profiles(id),
      body text,
      status text NOT NULL DEFAULT 'sent',
      admin_hidden boolean NOT NULL DEFAULT false,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.ai_threads (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES public.profiles(id),
      title text,
      persona text DEFAULT 'analyst',
      admin_hidden boolean NOT NULL DEFAULT false,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.ai_messages (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      thread_id uuid NOT NULL REFERENCES public.ai_threads(id),
      role text NOT NULL DEFAULT 'assistant',
      body text,
      error text,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.ai_insight_requests (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES public.profiles(id),
      thread_id uuid,
      kind text NOT NULL DEFAULT 'research',
      provider text NOT NULL DEFAULT 'gemini',
      model text NOT NULL DEFAULT 'gemini-2.5-flash',
      ticker text,
      prompt_text text,
      response_text text,
      input_tokens integer NOT NULL DEFAULT 0,
      output_tokens integer NOT NULL DEFAULT 0,
      status text NOT NULL DEFAULT 'complete',
      requested_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.affiliate_profiles (
      id uuid PRIMARY KEY REFERENCES public.profiles(id),
      status text NOT NULL DEFAULT 'active',
      tier text NOT NULL DEFAULT 'standard',
      commission_rate numeric NOT NULL DEFAULT 0.2,
      payout_details jsonb,
      pan_number text,
      gstin text,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.affiliate_applications (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      full_name text NOT NULL,
      primary_platform text,
      audience_reach text,
      channel_handle text,
      account_number text,
      pan text,
      date_of_birth text,
      phone text,
      status text NOT NULL DEFAULT 'pending_review',
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.affiliate_referrals (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      affiliate_id uuid NOT NULL REFERENCES public.profiles(id),
      referred_user_id uuid NOT NULL REFERENCES public.profiles(id),
      referral_code text,
      status text NOT NULL DEFAULT 'converted',
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.affiliate_payouts (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      affiliate_id uuid NOT NULL REFERENCES public.profiles(id),
      amount numeric NOT NULL DEFAULT 0,
      currency text NOT NULL DEFAULT 'INR',
      status text NOT NULL DEFAULT 'pending',
      payout_details jsonb,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.admin_audit_logs (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      actor_id uuid,
      actor_handle text,
      subject_user_id uuid,
      action text NOT NULL,
      target_label text NOT NULL DEFAULT '',
      category text NOT NULL DEFAULT 'moderation',
      metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
      ip_address text,
      sha256_hash text,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.account_deletion_requests (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid REFERENCES public.profiles(id),
      subject_user_id uuid,
      user_handle text NOT NULL,
      reason text NOT NULL,
      status text NOT NULL DEFAULT 'pending',
      created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE OR REPLACE FUNCTION tradex_private.require_admin() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'user_admin' AND status = 'active'
      ) THEN
        RAISE EXCEPTION 'Administrator access required' USING ERRCODE = '42501';
      END IF;
    END;
    $$;

    CREATE OR REPLACE FUNCTION tradex_private.effective_tier(p_user uuid) RETURNS text
    LANGUAGE sql STABLE SET search_path = '' AS $$
      SELECT coalesce(
        (SELECT s.tier FROM public.subscriptions s
         WHERE s.user_id = p_user AND s.status IN ('active', 'trialing')
         ORDER BY s.created_at DESC LIMIT 1),
        'free'
      );
    $$;

    INSERT INTO public.profiles(id, handle, display_name, email, avatar_url, role, status) VALUES
      ('${adminId}', 'admin_lead', 'Admin Lead', 'admin@alphajournal.in', 'https://cdn.example.com/a.png', 'user_admin', 'active'),
      ('${traderId}', 'jane_trader', 'Jane Trader', 'jane@example.com', 'https://cdn.example.com/j.png', 'customer', 'active'),
      ('${affId}', 'partner_one', 'Partner One', 'partner@example.com', NULL, 'affiliate', 'active');

    INSERT INTO public.subscriptions(user_id, tier, status) VALUES ('${traderId}', 'premium', 'active');
    INSERT INTO public.affiliate_profiles(id, status, tier, commission_rate, pan_number) VALUES ('${affId}', 'active', 'gold', 0.25, 'SECRET');
    INSERT INTO public.affiliate_applications(full_name, primary_platform, audience_reach, channel_handle, account_number, status)
      VALUES ('Creator App', 'YouTube', '45K', '@creator', '1234567890', 'pending_review');
    INSERT INTO public.community_posts(author_id, title, body, views_count, moderation_status)
      VALUES ('${traderId}', 'NVDA Breakout Thesis', 'Strong institutional   volume   on daily breakout.', 42, 'pending');
    INSERT INTO public.trader_notes(user_id, title, content, is_public, word_count) VALUES
      ('${traderId}', 'Encrypted Research', 'e2ee:v1:topsecretciphertextpayload', false, 18),
      ('${traderId}', 'Public Macro Note', 'Fed dot plot   remains restrictive for Q3.', true, 8);
    INSERT INTO public.ai_insight_requests(user_id, kind, provider, model, ticker, prompt_text, response_text, input_tokens, output_tokens)
      VALUES ('${traderId}', 'company', 'gemini', 'gemini-2.5-flash', 'NVDA', 'Summarize NVDA moat', 'NVIDIA dominates GPU datacenter compute.', 120, 280);
    INSERT INTO public.account_deletion_requests(user_id, subject_user_id, user_handle, reason, status)
      VALUES ('${traderId}', '${traderId}', 'jane_trader', 'Moving to another desk', 'pending');
  `);

  const migrationSql = readFileSync(
    resolve(__dirname, '../../supabase/migrations/20261116020000_admin_rich_previews_and_analytics.sql'),
    'utf8',
  );
  await db.exec(migrationSql);

  await db.exec(`
    CREATE OR REPLACE FUNCTION public.admin_list_records(
      p_resource text, p_user uuid DEFAULT NULL, p_search text DEFAULT '', p_status text DEFAULT 'all',
      p_page integer DEFAULT 0, p_page_size integer DEFAULT 25,
      p_from timestamptz DEFAULT NULL, p_to timestamptz DEFAULT NULL, p_parent uuid DEFAULT NULL
    ) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS
    $$ SELECT tradex_private.admin_list(p_resource,p_user,p_search,p_status,p_page,p_page_size,p_from,p_to,p_parent); $$;

    CREATE OR REPLACE FUNCTION public.admin_get_overview(p_days integer DEFAULT 30) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS
    $$ SELECT tradex_private.admin_overview(p_days); $$;

    GRANT EXECUTE ON FUNCTION public.admin_list_records(text,uuid,text,text,integer,integer,timestamptz,timestamptz,uuid),
      public.admin_get_overview(integer) TO authenticated;
  `);

  // 1. Non-admin access fails closed
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${traderId}';`);
  await assert.rejects(db.query(`SELECT public.admin_get_overview(30)`), /Administrator access required/);
  await assert.rejects(db.query(`SELECT public.admin_list_records('notes')`), /Administrator access required/);

  // 2. Safe preview helper masks ciphertext and collapses whitespace
  await db.exec(`SET request.jwt.claim.sub = '${adminId}';`);
  const masked = await db.query(`SELECT tradex_private.admin_safe_preview('  e2ee:v1:secret123  ', 200) AS p`);
  assert.equal(masked.rows[0].p, 'End-to-end encrypted content');
  const collapsed = await db.query(`SELECT tradex_private.admin_safe_preview('  Alpha   desk \n thesis ', 200) AS p`);
  assert.equal(collapsed.rows[0].p, 'Alpha desk thesis');

  // 3. admin_list returns safe previews and strips sensitive fields
  const notesRes = await db.query(`SELECT public.admin_list_records('notes') AS res`);
  const notesRows = notesRes.rows[0].res.rows;
  assert.equal(notesRows.length, 2);
  const encRow = notesRows.find((r) => r.title === 'Encrypted Research');
  const pubRow = notesRows.find((r) => r.title === 'Public Macro Note');
  assert.equal(encRow.preview, 'End-to-end encrypted content');
  assert.equal(encRow.content, undefined);
  assert.equal(pubRow.preview, 'Fed dot plot remains restrictive for Q3.');

  const aiRes = await db.query(`SELECT public.admin_list_records('ai_requests', p_search => 'moat') AS res`);
  assert.equal(aiRes.rows[0].res.rows.length, 1);
  assert.equal(aiRes.rows[0].res.rows[0].preview, 'Summarize NVDA moat');
  assert.equal(aiRes.rows[0].res.rows[0].response_preview, 'NVIDIA dominates GPU datacenter compute.');
  assert.equal(aiRes.rows[0].res.rows[0].prompt_text, undefined);

  const postsRes = await db.query(`SELECT public.admin_list_records('posts') AS res`);
  assert.equal(postsRes.rows[0].res.rows[0].author_avatar_url, 'https://cdn.example.com/j.png');
  assert.equal(postsRes.rows[0].res.rows[0].preview, 'Strong institutional volume on daily breakout.');

  // 4. admin_overview returns new analytics breakdowns & preview feeds alongside base counts
  const ovRes = await db.query(`SELECT public.admin_get_overview(30) AS ov`);
  const ov = ovRes.rows[0].ov;
  assert.equal(ov.users, 3);
  assert.equal(ov.tier_breakdown.premium, 1);
  assert.equal(ov.tier_breakdown.free, 2);
  assert.equal(ov.role_breakdown.user_admin, 1);
  assert.equal(ov.role_breakdown.customer, 1);
  assert.equal(ov.role_breakdown.affiliate, 1);
  assert.equal(ov.ai_providers.length, 1);
  assert.equal(ov.ai_providers[0].provider, 'gemini');
  assert.equal(ov.ai_providers[0].tokens, 400);
  assert.equal(ov.moderation_breakdown.pending_posts, 1);
  assert.equal(ov.preview_posts.length, 1);
  assert.equal(ov.preview_applications.length, 1);
  assert.equal(ov.preview_applications[0].status, 'pending');
  assert.equal(ov.preview_applications[0].account_number, undefined);
  assert.equal(ov.preview_deletions.length, 1);
  assert.equal(ov.preview_users.length, 3);

  await db.close();
  console.log('Admin rich previews & analytics SQL migration checks passed.');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
