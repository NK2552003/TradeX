// Run with NODE_PATH pointing at an installation of @electric-sql/pglite.
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { PGlite } = require('@electric-sql/pglite');

(async () => {
  const db = new PGlite();
  await db.exec(`
    CREATE ROLE anon;
    CREATE ROLE authenticated;
    CREATE ROLE service_role;

    CREATE FUNCTION public.public_document(text, uuid)
      RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
    CREATE FUNCTION public.public_refs(text, uuid)
      RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '[]'::jsonb $$;
    CREATE FUNCTION public.public_strategy_performance(uuid)
      RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS $$ SELECT '{}'::jsonb $$;
    CREATE FUNCTION public.is_admin_caller()
      RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$ SELECT false $$;
    CREATE FUNCTION public.is_user_admin()
      RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$ SELECT false $$;

    CREATE FUNCTION public.enforce_user_registration_cap()
      RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN RETURN NEW; END $$;
    CREATE FUNCTION public.enforce_published_customer_quota()
      RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN RETURN NEW; END $$;
    CREATE FUNCTION public.update_community_post_likes()
      RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN RETURN NEW; END $$;
    CREATE FUNCTION public.update_community_post_comments()
      RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN RETURN NEW; END $$;
    CREATE FUNCTION public.update_community_post_reposts()
      RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN RETURN NEW; END $$;
    CREATE FUNCTION public.update_community_poll_votes()
      RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN RETURN NEW; END $$;
    CREATE FUNCTION public.trg_community_comment_likes_count()
      RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN RETURN NEW; END $$;
  `);

  const migration = readFileSync(
    resolve(
      __dirname,
      '../../supabase/migrations/20261119030000_security_hardening.sql',
    ),
    'utf8',
  );
  await db.exec(migration);
  await db.exec(migration);

  const privilege = async (role, signature) => {
    const result = await db.query(
      'SELECT has_function_privilege($1, $2, $3) AS allowed',
      [role, signature, 'EXECUTE'],
    );
    return result.rows[0].allowed;
  };

  assert.equal(
    await privilege('anon', 'public.public_document(text,uuid)'),
    true,
  );
  assert.equal(
    await privilege('authenticated', 'public.public_document(text,uuid)'),
    true,
  );
  assert.equal(
    await privilege('anon', 'public.is_admin_caller()'),
    false,
  );
  assert.equal(
    await privilege('authenticated', 'public.is_admin_caller()'),
    true,
  );
  assert.equal(
    await privilege('authenticated', 'public.update_community_post_likes()'),
    false,
  );

  const schemaPrivilege = await db.query(
    "SELECT has_schema_privilege('anon', 'public', 'CREATE') AS allowed",
  );
  assert.equal(schemaPrivilege.rows[0].allowed, false);

  await db.close();

  const partialDb = new PGlite();
  await partialDb.exec(`
    CREATE ROLE anon;
    CREATE ROLE authenticated;
    CREATE ROLE service_role;
  `);
  await partialDb.exec(migration);
  await partialDb.exec(migration);
  await partialDb.close();

  const repairedDb = new PGlite();
  await repairedDb.exec(`
    CREATE ROLE anon;
    CREATE ROLE authenticated;
    CREATE ROLE service_role;
    CREATE TABLE public.profiles (
      id uuid PRIMARY KEY,
      role text NOT NULL DEFAULT 'user'
    );
  `);
  const repairMigration = readFileSync(
    resolve(
      __dirname,
      '../../supabase/migrations/20261120000000_repair_user_registration_cap.sql',
    ),
    'utf8',
  );
  await repairedDb.exec(repairMigration);
  await repairedDb.exec(repairMigration);

  const repairState = await repairedDb.query(`
    SELECT
      to_regprocedure('public.enforce_user_registration_cap()') IS NOT NULL AS function_exists,
      EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_enforce_user_registration_cap'
          AND NOT tgisinternal
      ) AS trigger_exists
  `);
  assert.deepEqual(repairState.rows[0], {
    function_exists: true,
    trigger_exists: true,
  });
  await repairedDb.close();

  console.log('Security hardening SQL privileges and idempotency passed.');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
