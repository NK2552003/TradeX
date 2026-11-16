// Run with NODE_PATH pointing at an installation of @electric-sql/pglite.
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { PGlite } = require('@electric-sql/pglite');

(async () => {
  const db = new PGlite();
  const alice = '00000000-0000-0000-0000-000000000001';
  const bob = '00000000-0000-0000-0000-000000000002';
  const carol = '00000000-0000-0000-0000-000000000003';
  const admin = '00000000-0000-0000-0000-000000000099';

  await db.exec(`
    CREATE ROLE anon;
    CREATE ROLE authenticated;
    CREATE ROLE service_role SUPERUSER;

    CREATE SCHEMA auth;
    CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
      $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    CREATE OR REPLACE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS
      $$ SELECT coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), current_user::text) $$;
    GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
    GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;
    GRANT EXECUTE ON FUNCTION auth.role() TO anon, authenticated, service_role;

    CREATE SCHEMA storage;
    CREATE TABLE storage.buckets(
      id text PRIMARY KEY,
      name text NOT NULL,
      public boolean DEFAULT false,
      file_size_limit bigint,
      allowed_mime_types text[]
    );
    CREATE TABLE storage.objects(
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      bucket_id text NOT NULL REFERENCES storage.buckets(id),
      name text NOT NULL,
      owner uuid,
      owner_id text,
      metadata jsonb DEFAULT '{}'::jsonb,
      user_metadata jsonb DEFAULT '{}'::jsonb,
      version text DEFAULT '1',
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now(),
      last_accessed_at timestamptz DEFAULT now()
    );
    ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
    CREATE OR REPLACE FUNCTION storage.foldername(name text) RETURNS text[] LANGUAGE sql IMMUTABLE AS
      $$ SELECT string_to_array(trim(both '/' from name), '/') $$;
    GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;
    GRANT SELECT, INSERT, UPDATE, DELETE ON storage.buckets TO anon, authenticated, service_role;
    GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO anon, authenticated, service_role;

    INSERT INTO auth.users(id) VALUES ('${alice}'), ('${bob}'), ('${carol}'), ('${admin}');

    -- Core tables prerequisite for changes_50.sql
    CREATE TABLE public.profiles (
      id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
      handle text,
      display_name text,
      email text,
      role text NOT NULL DEFAULT 'customer',
      status text NOT NULL DEFAULT 'active',
      subscription_tier text NOT NULL DEFAULT 'free',
      updated_at timestamptz NOT NULL DEFAULT now()
    );
    INSERT INTO public.profiles(id, handle, role, status) VALUES
      ('${alice}', '@alice', 'customer', 'active'),
      ('${bob}', '@bob', 'customer', 'active'),
      ('${carol}', '@carol', 'customer', 'active'),
      ('${admin}', '@admin', 'user_admin', 'active');

    CREATE OR REPLACE FUNCTION public.are_blocked(u1 uuid, u2 uuid)
    RETURNS boolean LANGUAGE sql IMMUTABLE AS $$ SELECT false; $$;
    GRANT EXECUTE ON FUNCTION public.are_blocked(uuid, uuid) TO anon, authenticated, service_role;

    CREATE OR REPLACE FUNCTION public.is_user_admin()
    RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
      SELECT EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'user_admin'
      );
    $$;
    GRANT EXECUTE ON FUNCTION public.is_user_admin() TO anon, authenticated, service_role;

    CREATE TABLE public.journal_entries (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      title text NOT NULL DEFAULT 'Trade',
      pnl numeric(18, 4),
      entry_price numeric(18, 4),
      stop_loss numeric(18, 4),
      target numeric(18, 4),
      is_public boolean NOT NULL DEFAULT false
    );
    ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "journal_entries_owner_select" ON public.journal_entries
      FOR SELECT TO authenticated USING (auth.uid() = user_id);

    CREATE TABLE public.strategies (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      name text NOT NULL,
      visibility text NOT NULL DEFAULT 'private',
      is_public boolean NOT NULL DEFAULT false
    );
    ALTER TABLE public.strategies ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "strategies_select" ON public.strategies
      FOR SELECT TO anon, authenticated USING (visibility = 'public' OR is_public = true OR auth.uid() = user_id);

    CREATE TABLE public.strategy_attachments (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      strategy_id uuid NOT NULL REFERENCES public.strategies(id) ON DELETE CASCADE,
      user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      storage_path text NOT NULL
    );
    ALTER TABLE public.strategy_attachments ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "strategy_attachments_select" ON public.strategy_attachments
      FOR SELECT TO anon, authenticated USING (true);

    CREATE TABLE public.chat_threads (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
      is_group boolean NOT NULL DEFAULT false,
      created_at timestamptz NOT NULL DEFAULT now()
    );
    ALTER TABLE public.chat_threads ENABLE ROW LEVEL SECURITY;

    CREATE TABLE public.chat_participants (
      thread_id uuid NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
      user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      PRIMARY KEY (thread_id, user_id)
    );
    ALTER TABLE public.chat_participants ENABLE ROW LEVEL SECURITY;

    CREATE TABLE public.chat_messages (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      thread_id uuid NOT NULL REFERENCES public.chat_threads(id) ON DELETE CASCADE,
      sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      body text,
      admin_hidden boolean NOT NULL DEFAULT false,
      created_at timestamptz NOT NULL DEFAULT now()
    );
    ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

    CREATE TABLE public.chat_attachments (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      message_id uuid NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
      url text NOT NULL,
      storage_path text,
      type text NOT NULL DEFAULT 'image',
      name text NOT NULL DEFAULT 'file.png',
      size integer NOT NULL DEFAULT 100
    );
    ALTER TABLE public.chat_attachments ENABLE ROW LEVEL SECURITY;

    CREATE TABLE public.chat_reactions (
      message_id uuid NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
      user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      reaction text NOT NULL DEFAULT 'like',
      PRIMARY KEY (message_id, user_id)
    );
    ALTER TABLE public.chat_reactions ENABLE ROW LEVEL SECURITY;

    CREATE TABLE public.chat_shared_refs (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      message_id uuid NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
      ref_type text NOT NULL,
      ref_id text NOT NULL
    );
    ALTER TABLE public.chat_shared_refs ENABLE ROW LEVEL SECURITY;

    CREATE TABLE public.community_posts (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      content text NOT NULL DEFAULT '',
      is_public boolean NOT NULL DEFAULT true,
      moderation_status text NOT NULL DEFAULT 'approved',
      likes_count integer NOT NULL DEFAULT 0,
      comments_count integer NOT NULL DEFAULT 0,
      reposts_count integer NOT NULL DEFAULT 0,
      views_count integer NOT NULL DEFAULT 0,
      bookmarks_count integer NOT NULL DEFAULT 0,
      updated_at timestamptz NOT NULL DEFAULT now()
    );
    ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "community_posts_select" ON public.community_posts FOR SELECT TO anon, authenticated USING (
      (moderation_status = 'approved' AND is_public = true)
      OR auth.uid() = author_id
      OR public.is_user_admin()
    );
    CREATE POLICY "community_posts_insert" ON public.community_posts FOR INSERT TO authenticated WITH CHECK (
      auth.uid() = author_id
    );
    CREATE POLICY "community_posts_update" ON public.community_posts FOR UPDATE TO authenticated USING (
      auth.uid() = author_id OR public.is_user_admin()
    ) WITH CHECK (
      auth.uid() = author_id OR public.is_user_admin()
    );

    CREATE TABLE public.community_comments (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
      author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      body text NOT NULL DEFAULT '',
      likes_count integer NOT NULL DEFAULT 0
    );
    ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "community_comments_select" ON public.community_comments FOR SELECT TO anon, authenticated USING (
      true
    );
    CREATE POLICY "community_comments_insert" ON public.community_comments FOR INSERT TO authenticated WITH CHECK (
      auth.uid() = author_id
    );
    CREATE POLICY "community_comments_update" ON public.community_comments FOR UPDATE TO authenticated USING (
      auth.uid() = author_id
    );

    CREATE TABLE public.community_poll_options (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
      label text NOT NULL,
      votes_count integer NOT NULL DEFAULT 0
    );
    ALTER TABLE public.community_poll_options ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "community_poll_options_select" ON public.community_poll_options FOR SELECT TO anon, authenticated USING (
      true
    );
    CREATE POLICY "community_poll_options_manage" ON public.community_poll_options FOR ALL TO authenticated USING (
      EXISTS (SELECT 1 FROM public.community_posts p WHERE p.id = post_id AND p.author_id = auth.uid())
    ) WITH CHECK (
      EXISTS (SELECT 1 FROM public.community_posts p WHERE p.id = post_id AND p.author_id = auth.uid())
    );

    CREATE TABLE public.community_likes (
      post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
      user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      reaction text DEFAULT 'like',
      PRIMARY KEY (post_id, user_id)
    );
    CREATE TABLE public.community_comment_likes (
      comment_id uuid NOT NULL REFERENCES public.community_comments(id) ON DELETE CASCADE,
      user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      reaction text DEFAULT 'like',
      PRIMARY KEY (comment_id, user_id)
    );

    -- Live schema: organization_members initially without status column
    CREATE TABLE public.organization_members (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      organization_id uuid,
      user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      role text NOT NULL DEFAULT 'member',
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now()
    );
    INSERT INTO public.organization_members(user_id) VALUES ('${alice}');

    -- Live schema: admin_audit_logs with uuid id (from 20261027051156_admin_user_management.sql)
    CREATE TABLE public.admin_audit_logs (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      actor_id uuid,
      actor_handle text NOT NULL,
      actor_role text NOT NULL DEFAULT 'system',
      category text NOT NULL,
      action text NOT NULL,
      severity text NOT NULL DEFAULT 'info',
      target_type text NOT NULL,
      target_id text NOT NULL,
      target_label text NOT NULL,
      ip_address text NOT NULL DEFAULT '',
      sha256_hash text NOT NULL DEFAULT '',
      metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
      created_at timestamptz NOT NULL DEFAULT now()
    );

    -- Live schema: pre-existing tradex_private.is_admin() (0-arg) and guard_feature_write() trigger
    CREATE SCHEMA IF NOT EXISTS tradex_private;
    CREATE OR REPLACE FUNCTION tradex_private.is_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
      SELECT auth.uid() IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'user_admin' AND status = 'active'
      );
    $$;
    CREATE OR REPLACE FUNCTION tradex_private.guard_feature_write() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
    BEGIN
      IF auth.uid() IS NULL OR tradex_private.is_admin() THEN
        IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
      END IF;
      IF TG_OP = 'DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
    END;
    $$;
    CREATE TRIGGER admin_feature_guard BEFORE INSERT OR UPDATE OR DELETE ON public.chat_attachments
      FOR EACH ROW EXECUTE FUNCTION tradex_private.guard_feature_write('messages');
    CREATE TRIGGER admin_feature_guard BEFORE INSERT OR UPDATE OR DELETE ON public.community_posts
      FOR EACH ROW EXECUTE FUNCTION tradex_private.guard_feature_write('posts');

    -- Seed a pre-existing chat_threads, chat_messages, and chat_attachments row so UPDATE in changes_50.sql fires admin_feature_guard
    INSERT INTO public.chat_threads(id, created_by) VALUES ('10000000-0000-0000-0000-000000000099', '${alice}');
    INSERT INTO public.chat_participants(thread_id, user_id) VALUES ('10000000-0000-0000-0000-000000000099', '${alice}');
    INSERT INTO public.chat_messages(id, thread_id, sender_id, body) VALUES ('20000000-0000-0000-0000-000000000099', '10000000-0000-0000-0000-000000000099', '${alice}', 'legacy attachment');
    INSERT INTO public.chat_attachments(message_id, url) VALUES ('20000000-0000-0000-0000-000000000099', 'https://example.supabase.co/storage/v1/object/public/community-attachments/${alice}/chat/10000000-0000-0000-0000-000000000099/legacy.png');

    CREATE TABLE public.subscriptions (
      user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
      tier text NOT NULL DEFAULT 'free',
      status text NOT NULL DEFAULT 'active',
      billing_provider text,
      provider_subscription_id text,
      revenuecat_id text,
      billing_cycle text,
      renewed_at timestamptz,
      expires_at timestamptz,
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE public.billing_checkout_intents (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      status text NOT NULL DEFAULT 'created',
      updated_at timestamptz NOT NULL DEFAULT now()
    );

    GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
    GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;

    -- Seed a legacy chat object in community-attachments before running changes_50.sql
    INSERT INTO storage.buckets(id, name, public) VALUES ('community-attachments', 'community-attachments', true);
    INSERT INTO storage.objects(bucket_id, name, owner)
    VALUES ('community-attachments', '${alice}/chat/10000000-0000-0000-0000-000000000001/legacy_PreMigration.png', '${alice}');
  `);

  const changes50Sql = readFileSync(resolve(__dirname, '../../changes_50.sql'), 'utf8');
  await db.exec(changes50Sql);
  // Verify repeat deployment idempotency
  await db.exec(changes50Sql);

  const migratedLegacy = await db.query(
    `SELECT bucket_id, name FROM storage.objects WHERE name = '10000000-0000-0000-0000-000000000001/${alice}/legacy_PreMigration.png'`
  );
  assert.equal(migratedLegacy.rows.length, 1, 'Legacy chat object should be migrated to chat-attachments');
  assert.equal(migratedLegacy.rows[0].bucket_id, 'chat-attachments');

  // =========================================================================
  // Issue #84: Enforce account isolation in portfolio_stats view
  // =========================================================================
  await db.exec(`
    RESET ROLE;
    INSERT INTO public.journal_entries(user_id, title, pnl, entry_price, stop_loss, target) VALUES
      ('${alice}', 'AAPL Long', 500, 100, 95, 110),
      ('${bob}', 'TSLA Short', -200, 200, 210, 180);
  `);

  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${alice}';`);
  const aliceStats = await db.query('SELECT * FROM public.portfolio_stats');
  assert.equal(aliceStats.rows.length, 1, 'Alice should only see 1 portfolio_stats row');
  assert.equal(aliceStats.rows[0].user_id, alice);
  assert.equal(Number(aliceStats.rows[0].total_pnl), 500);

  const crossStats = await db.query('SELECT * FROM public.portfolio_stats WHERE user_id = $1', [bob]);
  assert.equal(crossStats.rows.length, 0, 'Alice cannot read Bob portfolio_stats');

  await db.exec(`RESET ROLE; SET ROLE anon; SET request.jwt.claim.sub = '';`);
  await assert.rejects(
    db.query('SELECT * FROM public.portfolio_stats'),
    /permission denied/,
    'Anonymous role must be denied access to portfolio_stats'
  );

  // =========================================================================
  // Issue #83 & #85: Private chat-attachments bucket & participant/sender isolation
  // =========================================================================
  await db.exec('RESET ROLE;');
  const bucketRes = await db.query(`SELECT public FROM storage.buckets WHERE id = 'chat-attachments'`);
  assert.equal(bucketRes.rows.length, 1);
  assert.equal(bucketRes.rows[0].public, false, 'chat-attachments bucket must be private');

  const thread1 = '11111111-1111-4111-8111-111111111111';
  const msgAlice = '22222222-2222-4222-8222-222222222221';
  const msgBob = '22222222-2222-4222-8222-222222222222';
  await db.exec(`
    INSERT INTO public.chat_threads(id, created_by, is_group) VALUES ('${thread1}', '${alice}', false);
    INSERT INTO public.chat_participants(thread_id, user_id) VALUES
      ('${thread1}', '${alice}'),
      ('${thread1}', '${bob}');
    INSERT INTO public.chat_messages(id, thread_id, sender_id, body) VALUES
      ('${msgAlice}', '${thread1}', '${alice}', 'hi from alice'),
      ('${msgBob}', '${thread1}', '${bob}', 'hi from bob');
  `);

  // Alice uploads to her own sender segment in thread1
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${alice}';`);
  await db.query(
    `INSERT INTO storage.objects(bucket_id, name, owner) VALUES ('chat-attachments', $1, $2)`,
    [`${thread1}/${alice}/chart.png`, alice]
  );

  // Alice cannot upload under Bob's sender segment
  await assert.rejects(
    db.query(
      `INSERT INTO storage.objects(bucket_id, name, owner) VALUES ('chat-attachments', $1, $2)`,
      [`${thread1}/${bob}/spoof.png`, alice]
    ),
    /row-level security/,
    'Alice cannot upload into Bob folder segment'
  );

  // Issue #85: Nobody can upload chat paths into public community-attachments bucket
  await assert.rejects(
    db.query(
      `INSERT INTO storage.objects(bucket_id, name, owner) VALUES ('community-attachments', $1, $2)`,
      [`${alice}/chat/${thread1}/leak.png`, alice]
    ),
    /row-level security/,
    'Legacy chat upload into public community-attachments must be rejected'
  );

  // Link Alice's uploaded object to her message in chat_attachments
  await db.query(
    `INSERT INTO public.chat_attachments(message_id, url, storage_path, type, name, size)
     VALUES ($1, $2, $2, 'image', 'chart.png', 120)`,
    [msgAlice, `${thread1}/${alice}/chart.png`]
  );

  // Bob (thread participant) can read Alice's attachment in thread1, but cannot delete or update it
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${bob}';`);
  const bobReadsChatObj = await db.query(
    `SELECT name FROM storage.objects WHERE bucket_id = 'chat-attachments' AND name = $1`,
    [`${thread1}/${alice}/chart.png`]
  );
  assert.equal(bobReadsChatObj.rows.length, 1, 'Participant Bob can read thread attachment');

  const bobDeletesAliceChatObj = await db.query(
    `DELETE FROM storage.objects WHERE bucket_id = 'chat-attachments' AND name = $1 RETURNING id`,
    [`${thread1}/${alice}/chart.png`]
  );
  assert.equal(bobDeletesAliceChatObj.rows.length, 0, 'Participant Bob cannot delete Alice storage object');

  // Bob cannot attach a file to Alice's message or delete Alice's attachment row
  await assert.rejects(
    db.query(
      `INSERT INTO public.chat_attachments(message_id, url, storage_path, type, name, size)
       VALUES ($1, $2, $2, 'image', 'spoof.png', 120)`,
      [msgAlice, `${thread1}/${bob}/spoof.png`]
    ),
    /row-level security|Unauthorized chat attachment write/,
    'Bob cannot insert chat_attachments onto Alice message'
  );
  const bobDeleteAtt = await db.query(
    `DELETE FROM public.chat_attachments WHERE message_id = $1 RETURNING id`,
    [msgAlice]
  );
  assert.equal(bobDeleteAtt.rows.length, 0, 'Bob cannot delete Alice chat_attachments row');

  // Non-participant Carol cannot read thread1 attachment
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${carol}';`);
  const carolReadsChatObj = await db.query(
    `SELECT name FROM storage.objects WHERE bucket_id = 'chat-attachments' AND name = $1`,
    [`${thread1}/${alice}/chart.png`]
  );
  assert.equal(carolReadsChatObj.rows.length, 0, 'Non-participant Carol cannot read thread attachment');

  // =========================================================================
  // Issue #86: Prevent legacy chat RPC from exposing 3rd-party membership
  // =========================================================================
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${carol}';`);
  await assert.rejects(
    db.query(`SELECT public.user_is_chat_participant($1, $2)`, [thread1, alice]),
    /does not exist/,
    'Legacy third-party membership probe user_is_chat_participant must be dropped'
  );

  const carolProbesAlice = await db.query(
    `SELECT public.is_conversation_member($1, $2) AS is_member`,
    [thread1, alice]
  );
  assert.equal(
    carolProbesAlice.rows[0].is_member,
    false,
    'Carol probing Alice membership via 2-arg is_conversation_member must return false'
  );

  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${alice}';`);
  const aliceChecksSelf = await db.query(
    `SELECT public.is_conversation_member($1) AS is_member_1arg,
            public.is_conversation_member($1, $2) AS is_member_self,
            public.is_conversation_member($1, $3) AS is_member_bob`,
    [thread1, alice, bob]
  );
  assert.equal(aliceChecksSelf.rows[0].is_member_1arg, true, '1-arg check for participant Alice returns true');
  assert.equal(aliceChecksSelf.rows[0].is_member_self, true, '2-arg check for self returns true');
  assert.equal(
    aliceChecksSelf.rows[0].is_member_bob,
    false,
    '2-arg check for another user (Bob) must return false even for participant Alice'
  );

  // =========================================================================
  // Issue #87 & #93: Community reactions visibility & post counter protection
  // =========================================================================
  const postApproved = '44444444-4444-4444-8444-444444444441';
  const postPending = '44444444-4444-4444-8444-444444444442';
  await db.exec(`
    RESET ROLE;
    INSERT INTO public.community_posts(id, author_id, content, is_public, moderation_status) VALUES
      ('${postApproved}', '${alice}', 'Public trade setup', true, 'approved'),
      ('${postPending}', '${alice}', 'Hidden unapproved post', false, 'pending');
    INSERT INTO public.community_likes(post_id, user_id, reaction) VALUES
      ('${postApproved}', '${alice}', 'bullish'),
      ('${postPending}', '${alice}', 'fire');
  `);

  // Bob can see reaction on approved post, but NOT on Alice's pending post (#87)
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${bob}';`);
  const bobVisibleLikes = await db.query(`SELECT post_id FROM public.community_likes`);
  assert.equal(bobVisibleLikes.rows.length, 1, 'Bob should only see reactions on visible approved posts');
  assert.equal(bobVisibleLikes.rows[0].post_id, postApproved);

  // Bob cannot like Alice's pending post
  await assert.rejects(
    db.query(`INSERT INTO public.community_likes(post_id, user_id) VALUES ($1, $2)`, [postPending, bob]),
    /row-level security/,
    'Bob cannot react to a hidden post'
  );

  // Issue #93: Author Alice cannot forge views_count, likes_count, comments_count, reposts_count, bookmarks_count
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${alice}';`);
  await assert.rejects(
    db.query(`UPDATE public.community_posts SET views_count = 999999 WHERE id = $1`, [postApproved]),
    /Derived engagement counters cannot be modified directly/,
    'Author cannot directly update views_count'
  );
  await assert.rejects(
    db.query(`UPDATE public.community_posts SET likes_count = 500 WHERE id = $1`, [postApproved]),
    /Derived engagement counters cannot be modified directly/,
    'Author cannot directly update likes_count'
  );
  const seededPost = await db.query(
    `INSERT INTO public.community_posts(id, author_id, content, is_public, views_count, likes_count) VALUES ('44444444-4444-4444-8444-444444444449', $1, 'seeded', false, 1000, 50) RETURNING id, views_count, likes_count`,
    [alice]
  );
  assert.equal(seededPost.rows[0].views_count, 0, 'Pre-seeded views_count on insert must be reset to 0');
  assert.equal(seededPost.rows[0].likes_count, 0, 'Pre-seeded likes_count on insert must be reset to 0');

  // Poll creation flow: insert poll options (with pre-seeded votes_count reset to 0), then publish post via UPDATE
  const insertedPollOpt = await db.query(
    `INSERT INTO public.community_poll_options(post_id, label, votes_count) VALUES ('44444444-4444-4444-8444-444444444449', 'Option A', 99) RETURNING id, votes_count`
  );
  assert.equal(insertedPollOpt.rows[0].votes_count, 0, 'Pre-seeded poll option votes_count on insert must be reset to 0');
  await db.query(
    `UPDATE public.community_posts SET is_public = true, content = 'Published poll post' WHERE id = '44444444-4444-4444-8444-444444444449'`
  );
  const insertedComment = await db.query(
    `INSERT INTO public.community_comments(post_id, author_id, body, likes_count) VALUES ('44444444-4444-4444-8444-444444444449', $1, 'Initial comment', 42) RETURNING id, likes_count`,
    [alice]
  );
  assert.equal(insertedComment.rows[0].likes_count, 0, 'Pre-seeded comment likes_count on insert must be reset to 0');
  await db.query(
    `UPDATE public.community_comments SET body = 'Edited comment' WHERE id = $1`,
    [insertedComment.rows[0].id]
  );

  // Valid view recording via increment_post_views(uuid) is deduplicated per viewer per post
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${bob}';`);
  await db.query(`SELECT public.increment_post_views($1)`, [postApproved]);
  await db.query(`SELECT public.increment_post_views($1)`, [postApproved]); // duplicate call
  const viewsAfterBob = await db.query(`SELECT views_count FROM public.community_posts WHERE id = $1`, [postApproved]);
  assert.equal(viewsAfterBob.rows[0].views_count, 1, 'Repeated increment_post_views from same user only counts once');

  // Bob calling increment_post_views on Alice's unapproved post is a no-op
  await db.query(`SELECT public.increment_post_views($1)`, [postPending]);
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${alice}';`);
  const pendingViews = await db.query(`SELECT views_count FROM public.community_posts WHERE id = $1`, [postPending]);
  assert.equal(pendingViews.rows[0].views_count, 0, 'Hidden post views_count must not increment for unauthorized viewer');

  // Anonymous caller cannot call increment_post_views
  await db.exec(`RESET ROLE; SET ROLE anon; SET request.jwt.claim.sub = '';`);
  await assert.rejects(
    db.query(`SELECT public.increment_post_views($1)`, [postApproved]),
    /permission denied/,
    'Anonymous caller cannot execute increment_post_views'
  );

  // =========================================================================
  // Issue #89: Restrict desk risk configuration writes to administrators
  // =========================================================================
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${alice}';`);
  await assert.rejects(
    db.query(`INSERT INTO public.desk_risk_configs(max_total_drawdown_percent) VALUES (10.0)`),
    /row-level security|Only administrators may modify desk risk configurations/,
    'Standard customer Alice cannot insert desk_risk_configs'
  );

  // Admin can insert and update desk_risk_configs, and updated_by is forced to auth.uid()
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${admin}';`);
  const insertedRisk = await db.query(
    `INSERT INTO public.desk_risk_configs(max_total_drawdown_percent, updated_by) VALUES (7.5, $1) RETURNING id, updated_by`,
    [alice] // attempt to spoof updated_by as alice
  );
  assert.equal(insertedRisk.rows.length, 1);
  assert.equal(insertedRisk.rows[0].updated_by, admin, 'Trigger must enforce updated_by = auth.uid()');

  // Standard org member Alice can read desk_risk_configs, but cannot update or delete
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${alice}';`);
  const aliceReadRisk = await db.query(`SELECT max_total_drawdown_percent FROM public.desk_risk_configs`);
  assert.ok(aliceReadRisk.rows.length >= 1);
  const aliceUpdateRisk = await db.query(
    `UPDATE public.desk_risk_configs SET max_total_drawdown_percent = 15.0 WHERE id = $1 RETURNING id`,
    [insertedRisk.rows[0].id]
  );
  assert.equal(aliceUpdateRisk.rows.length, 0, 'Standard user Alice cannot update desk_risk_configs');
  const aliceDeleteRisk = await db.query(
    `DELETE FROM public.desk_risk_configs WHERE id = $1 RETURNING id`,
    [insertedRisk.rows[0].id]
  );
  assert.equal(aliceDeleteRisk.rows.length, 0, 'Standard user Alice cannot delete desk_risk_configs');

  // =========================================================================
  // Issue #90: Enforce strategy visibility on attachment downloads
  // =========================================================================
  const pubStrat = '55555555-5555-4555-8555-555555555551';
  const privStrat = '55555555-5555-4555-8555-555555555552';
  await db.exec(`
    RESET ROLE;
    INSERT INTO public.strategies(id, user_id, name, visibility, is_public) VALUES
      ('${pubStrat}', '${alice}', 'Public Breakout', 'public', true),
      ('${privStrat}', '${alice}', 'Secret Alpha', 'private', false);
  `);

  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${alice}';`);
  await db.query(
    `INSERT INTO storage.objects(bucket_id, name, owner) VALUES
      ('strategy-attachments', $1, $3),
      ('strategy-attachments', $2, $3)`,
    [`${alice}/${pubStrat}/public_chart.png`, `${alice}/${privStrat}/secret_chart.png`, alice]
  );

  // Bob can read attachment on Alice's public strategy, but NOT on Alice's private strategy
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${bob}';`);
  const bobStratObjs = await db.query(
    `SELECT name FROM storage.objects WHERE bucket_id = 'strategy-attachments'`
  );
  assert.equal(bobStratObjs.rows.length, 1, 'Bob can only see public strategy attachment');
  assert.equal(bobStratObjs.rows[0].name, `${alice}/${pubStrat}/public_chart.png`);

  // When Alice flips pubStrat to private, Bob immediately loses access to its attachment
  await db.exec(`
    RESET ROLE;
    UPDATE public.strategies SET visibility = 'private', is_public = false WHERE id = '${pubStrat}';
    SET ROLE authenticated;
    SET request.jwt.claim.sub = '${bob}';
  `);
  const bobStratObjsAfterPrivate = await db.query(
    `SELECT name FROM storage.objects WHERE bucket_id = 'strategy-attachments'`
  );
  assert.equal(bobStratObjsAfterPrivate.rows.length, 0, 'Making strategy private immediately revokes Bob attachment read access');

  // =========================================================================
  // Issue #92: Atomic multi-provider billing entitlement reconciliation
  // =========================================================================
  await db.exec('RESET ROLE; SET ROLE service_role;');

  const futureExpiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const pastExpiry = new Date(Date.now() - 60 * 1000).toISOString();

  // 1. RevenueCat activates Pro ('premium') for Alice
  const rcAct = await db.query(
    `SELECT public.reconcile_billing_entitlement(
      p_user_id := $1::uuid,
      p_provider := 'revenuecat',
      p_tier := 'premium',
      p_status := 'active',
      p_provider_subscription_id := NULL,
      p_revenuecat_id := $1::uuid::text,
      p_billing_cycle := 'monthly',
      p_renewed_at := now(),
      p_expires_at := $2::timestamptz,
      p_event_id := 'evt_rc_200',
      p_event_type := 'INITIAL_PURCHASE'
    ) AS res`,
    [alice, futureExpiry]
  );
  assert.equal(rcAct.rows[0].res.tier, 'premium');

  // 2. Razorpay activates Business ('enterprise') for Alice
  const rzpAct = await db.query(
    `SELECT public.reconcile_billing_entitlement(
      p_user_id := $1::uuid,
      p_provider := 'razorpay',
      p_tier := 'enterprise',
      p_status := 'active',
      p_provider_subscription_id := 'sub_rzp_1',
      p_revenuecat_id := NULL,
      p_billing_cycle := 'annual',
      p_renewed_at := now(),
      p_expires_at := $2::timestamptz,
      p_event_id := 'evt_rzp_100',
      p_event_type := 'subscription.activated'
    ) AS res`,
    [alice, futureExpiry]
  );
  assert.equal(rzpAct.rows[0].res.tier, 'enterprise', 'Higher tier enterprise takes precedence');

  // 3. Stale/expired Razorpay checkout for a DIFFERENT sub_id ('sub_rzp_old') must NOT clobber active sub_rzp_1
  const rzpStaleOtherSub = await db.query(
    `SELECT public.reconcile_billing_entitlement(
      p_user_id := $1::uuid,
      p_provider := 'razorpay',
      p_tier := 'free',
      p_status := 'expired',
      p_provider_subscription_id := 'sub_rzp_old',
      p_revenuecat_id := NULL,
      p_billing_cycle := 'monthly',
      p_renewed_at := NULL,
      p_expires_at := $2::timestamptz,
      p_event_id := 'evt_rzp_099_old',
      p_event_type := 'subscription.halted'
    ) AS res`,
    [alice, pastExpiry]
  );
  assert.equal(
    rzpStaleOtherSub.rows[0].res.tier,
    'enterprise',
    'Expired event for an old Razorpay subscription ID must not overwrite active sub_rzp_1'
  );

  // 4. Razorpay sub_rzp_1 expires -> Alice stays on 'premium' because RevenueCat is still active!
  const rzpExp = await db.query(
    `SELECT public.reconcile_billing_entitlement(
      p_user_id := $1::uuid,
      p_provider := 'razorpay',
      p_tier := 'free',
      p_status := 'canceled',
      p_provider_subscription_id := 'sub_rzp_1',
      p_revenuecat_id := NULL,
      p_billing_cycle := 'annual',
      p_renewed_at := NULL,
      p_expires_at := $2::timestamptz,
      p_event_id := 'evt_rzp_101',
      p_event_type := 'subscription.cancelled'
    ) AS res`,
    [alice, pastExpiry]
  );
  assert.equal(
    rzpExp.rows[0].res.tier,
    'premium',
    'Active RevenueCat subscription must keep Alice on premium when Razorpay expires'
  );

  // 5. RevenueCat expires -> Alice is now downgraded to 'free'
  const rcExp = await db.query(
    `SELECT public.reconcile_billing_entitlement(
      p_user_id := $1::uuid,
      p_provider := 'revenuecat',
      p_tier := 'free',
      p_status := 'canceled',
      p_provider_subscription_id := NULL,
      p_revenuecat_id := $1::uuid::text,
      p_billing_cycle := NULL,
      p_renewed_at := NULL,
      p_expires_at := $2::timestamptz,
      p_event_id := 'evt_rc_201',
      p_event_type := 'EXPIRATION'
    ) AS res`,
    [alice, pastExpiry]
  );
  assert.equal(rcExp.rows[0].res.tier, 'free', 'When all providers are inactive, effective tier must be free');

  const aliceProfileTier = await db.query(`SELECT subscription_tier FROM public.profiles WHERE id = $1`, [alice]);
  assert.equal(aliceProfileTier.rows[0].subscription_tier, 'free');

  await db.close();
  console.log('All SQL security & billing tests (#83, #84, #85, #86, #87, #89, #90, #92, #93) passed!');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
