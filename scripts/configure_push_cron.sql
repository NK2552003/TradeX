-- Run once after configuring Supabase Cron, pg_net and Vault.
-- First create Vault secrets named push_dispatch_url (the full Edge function URL)
-- and push_dispatch_secret (the same random value as PUSH_DISPATCH_SECRET).
-- Do not place literal secrets in this committed file.
select cron.schedule('deliver-private-push', '* * * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'push_dispatch_url'),
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-push-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_dispatch_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 240000
  );
$$);
