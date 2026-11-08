// Run with NODE_PATH pointing at a temporary installation of @electric-sql/pglite.
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { PGlite } = require('@electric-sql/pglite');

(async () => {
  const db = new PGlite();
  const alice = '00000000-0000-0000-0000-000000000001';
  const bob = '00000000-0000-0000-0000-000000000002';
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated;
    CREATE SCHEMA auth;
    CREATE TABLE auth.users(id uuid PRIMARY KEY);
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
      $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    GRANT USAGE ON SCHEMA auth TO authenticated;
    GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
    INSERT INTO auth.users VALUES ('${alice}'), ('${bob}');
  `);
  const migration = readFileSync(resolve(__dirname, '../../supabase/migrations/20261108065544_copilot_workspaces.sql'), 'utf8');
  await db.exec(migration);
  // Applying the additive deployment a second time preserves existing rows.
  await db.exec(migration);
  await db.exec(`SET ROLE authenticated; SET request.jwt.claim.sub = '${alice}';`);
  await db.query('INSERT INTO public.copilot_workspaces(user_id,state) VALUES ($1,$2)', [alice, { threads: ['alice'] }]);
  assert.equal((await db.query('SELECT * FROM public.copilot_workspaces')).rows.length, 1);
  await assert.rejects(db.query('INSERT INTO public.copilot_workspaces(user_id,state) VALUES ($1,$2)', [bob, {}]), /row-level security/);
  await assert.rejects(db.query('UPDATE public.copilot_workspaces SET user_id = $1', [bob]), /row-level security/);
  const changed = await db.query('UPDATE public.copilot_workspaces SET revision=2 WHERE user_id=$1 AND revision=1 RETURNING revision', [alice]);
  assert.equal(changed.rows.length, 1);
  const stale = await db.query('UPDATE public.copilot_workspaces SET revision=3 WHERE user_id=$1 AND revision=1 RETURNING revision', [alice]);
  assert.equal(stale.rows.length, 0);
  await db.exec(`SET request.jwt.claim.sub = '${bob}';`);
  assert.equal((await db.query('SELECT * FROM public.copilot_workspaces')).rows.length, 0);
  assert.equal((await db.query('DELETE FROM public.copilot_workspaces RETURNING user_id')).rows.length, 0);
  await db.exec('RESET ROLE; SET ROLE anon;');
  await assert.rejects(db.query('SELECT * FROM public.copilot_workspaces'), /permission denied/);
  await db.close();
  console.log('Copilot RLS: ownership, anonymous denial, reassignment denial, stale writes, and repeat deployment passed.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
