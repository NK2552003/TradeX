// Run with NODE_PATH pointing at an installation of @electric-sql/pglite.
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { PGlite } = require('@electric-sql/pglite');

(async () => {
  const db = new PGlite();
  const alice = '00000000-0000-0000-0000-000000000001';
  const bob = '00000000-0000-0000-0000-000000000002';
  const aliceSess1 = '11111111-1111-1111-1111-111111111111';
  const aliceSess2 = '22222222-2222-2222-2222-222222222222';
  const bobSess1 = '33333333-3333-3333-3333-333333333333';

  await db.exec(`
    CREATE ROLE anon;
    CREATE ROLE authenticated;
    CREATE SCHEMA auth;
    CREATE TABLE auth.users (id uuid PRIMARY KEY);
    CREATE TABLE auth.sessions (
      id uuid PRIMARY KEY,
      user_id uuid NOT NULL,
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now(),
      refreshed_at timestamp,
      user_agent text,
      ip inet,
      tag text,
      not_after timestamptz
    );
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
      $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    GRANT USAGE ON SCHEMA auth TO authenticated;
    GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
    INSERT INTO auth.users VALUES ('${alice}'), ('${bob}');
    INSERT INTO auth.sessions (id, user_id, user_agent, ip) VALUES
      ('${aliceSess1}', '${alice}', 'Mozilla/5.0 Chrome/126', '203.0.113.10'),
      ('${aliceSess2}', '${alice}', 'alphajournal iOS App', '203.0.113.11'),
      ('${bobSess1}', '${bob}', 'Mozilla/5.0 Firefox', '203.0.113.20');
  `);

  const migration = readFileSync(
    resolve(__dirname, '../../supabase/migrations/20261116000000_user_device_sessions.sql'),
    'utf8',
  );
  await db.exec(migration);
  // Idempotent repeat application must preserve data and succeed.
  await db.exec(migration);

  // Anon cannot access user_app_preferences, user_device_sessions, or session RPCs.
  await db.exec('SET ROLE anon;');
  await assert.rejects(
    db.query('SELECT * FROM public.user_app_preferences'),
    /permission denied/,
  );
  await assert.rejects(
    db.query('SELECT * FROM public.user_device_sessions'),
    /permission denied/,
  );
  await assert.rejects(
    db.query('SELECT public.list_my_active_sessions()'),
    /permission denied/,
  );

  // Alice can upsert & read her own AI preferences in user_app_preferences.
  await db.exec(`RESET ROLE; SET ROLE authenticated; SET request.jwt.claim.sub = '${alice}';`);
  await db.query(
    `INSERT INTO public.user_app_preferences (user_id, ai_settings)
     VALUES ($1, $2)
     ON CONFLICT (user_id) DO UPDATE SET ai_settings = EXCLUDED.ai_settings, updated_at = now()`,
    [alice, { defaultSpecialistId: 'writer', responseStyle: 'detailed', voiceAutoSpeak: true }],
  );
  const alicePrefs = await db.query(
    'SELECT ai_settings FROM public.user_app_preferences WHERE user_id = $1',
    [alice],
  );
  assert.equal(alicePrefs.rows.length, 1);
  assert.equal(alicePrefs.rows[0].ai_settings.defaultSpecialistId, 'writer');

  // Alice cannot write Bob's preferences row.
  await assert.rejects(
    db.query('INSERT INTO public.user_app_preferences (user_id, ai_settings) VALUES ($1, $2)', [
      bob,
      { paused: true },
    ]),
    /row-level security/,
  );

  // Alice registers her device sessions and lists them.
  await db.query(
    `SELECT public.register_my_device_session($1, 'Chrome on macOS', 'web', 'Chrome', 'macOS')`,
    [aliceSess1],
  );
  const sessionsRes = await db.query('SELECT public.list_my_active_sessions() AS sessions');
  const sessions = sessionsRes.rows[0].sessions;
  assert.equal(sessions.length, 2);
  assert.ok(sessions.every((s) => s.session_id === aliceSess1 || s.session_id === aliceSess2));

  // Bob cannot see Alice's preferences or revoke Alice's session.
  await db.exec(`SET request.jwt.claim.sub = '${bob}';`);
  assert.equal((await db.query('SELECT * FROM public.user_app_preferences')).rows.length, 0);
  await db.query(`SELECT public.revoke_my_session($1)`, [aliceSess2]);

  // Verify Alice's second session was NOT revoked by Bob.
  await db.exec(`SET request.jwt.claim.sub = '${alice}';`);
  const afterBobAttempt = await db.query('SELECT public.list_my_active_sessions() AS sessions');
  assert.equal(afterBobAttempt.rows[0].sessions.length, 2);

  // Alice can revoke all other sessions while keeping aliceSess1.
  const revokeOthers = await db.query(`SELECT public.revoke_other_my_sessions($1) AS res`, [aliceSess1]);
  assert.equal(revokeOthers.rows[0].res.revoked, true);
  assert.equal(revokeOthers.rows[0].res.auth_sessions_deleted, 1);
  const remaining = await db.query('SELECT public.list_my_active_sessions() AS sessions');
  assert.equal(remaining.rows[0].sessions.length, 1);
  assert.equal(remaining.rows[0].sessions[0].session_id, aliceSess1);

  await db.close();
  console.log('User device sessions & user_app_preferences RLS + RPC checks passed.');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
