# Cloudflare + Supabase: Push Notifications, Encrypted Messaging, Egress & `app.` Subdomain Deployment

This guide is the unified deployment runbook for AlphaJournal (`alphajournal`), combining:

- **Web Push notifications & E2EE messaging** (`message_identities`, `message_public_keys`, `push_subscriptions`, `push_deliveries`, `push-dispatch`)
- **Database & hosting egress optimizations** (`market-quote-proxy` batching/CORS/server cache, deferred web chunks, immutable asset cache headers, visibility-aware polling)
- **Subdomain routing (`app.alphajournal.in` and sibling subdomains)** via Cloudflare Workers Custom Domains and `GoRouter` host resolution

The repository uses **Cloudflare Workers with static assets**, configured in [wrangler.jsonc](../../wrangler.jsonc). Use `wrangler deploy`, not the Pages deployment commands in older guides.

| Service | Responsibility |
| --- | --- |
| Cloudflare Worker ([worker/index.js](../../worker/index.js)) | Serve the Flutter web app, push service worker, OG previews, HTTPS upgrades, and static cache headers ([web/_headers](../../web/_headers)) |
| Supabase Database | Store encrypted message content, public keys, encrypted recovery backups, subscriptions, delivery jobs, and trading records |
| Supabase Edge Functions | Dispatch push notifications (`push-dispatch`), serve cached market quotes/news (`market-quote-proxy`), and handle AI requests (`ai-chat`, `ai-gateway`) |
| Supabase Cron + Vault | Schedule push delivery (`deliver-private-push`) and protect the scheduler secret |
| Firebase / APNs | Required separately for installed Android/iOS/macOS apps; unnecessary for this browser-push setup |

---

## 1. Prepare the target environment

Start with a **staging Supabase project containing the existing application schema**. This migration is an addition to that schema, not a complete database installation.

> [!CAUTION]
> The migration rejects new plaintext message writes from older clients. Coordinate the database and client rollout, and confirm a current database backup before changing production. Rolling back only the frontend to an older build will not restore compatibility with the new database restrictions.

Open a terminal in the repository root, authenticate both CLIs once, and export your target environment variables for the session:

```bash
cd /Users/nitishkumar/Downloads/projects/nk2552003/AlphaJournal

export PROJECT_REF="YOUR_SUPABASE_PROJECT_REF"
export MONITORED_EMAIL="YOUR_MONITORED_EMAIL"
export APP_ORIGIN="https://app.alphajournal.in"

npx --yes supabase@3.1.0 login
npx wrangler login
```

The Supabase commands below use CLI **3.1.0** and its `--remote` syntax. Replace placeholders carefully and verify the target project before applying changes.

| Placeholder | Replace with |
| --- | --- |
| `PROJECT_REF` | Supabase project reference (for production: `ylxwgkhtwrizdmuhlhxs`) |
| `YOUR_PUBLIC_VAPID_KEY` | Your newly generated public VAPID key |
| `YOUR_MONITORED_EMAIL` | An email address you actually monitor |
| `YOUR_APP_ORIGIN` | The HTTPS origin you are testing, such as `https://app.alphajournal.in` |

---

## 2. Generate fresh browser-push credentials

**The private key and dispatcher secret previously pasted into chat should be replaced before production use.** No values from that message are included in this file.

Run these commands locally:

```bash
npx --yes web-push@3.6.7 generate-vapid-keys --json
export PUSH_DISPATCH_SECRET="$(openssl rand -hex 32)"
echo "PUSH_DISPATCH_SECRET=$PUSH_DISPATCH_SECRET"
```

Copy `publicKey` and `privateKey` from the `web-push` JSON output into your password manager and shell session (do **not** commit them or put private values in frontend config):

```bash
export WEB_PUSH_PUBLIC_KEY="PASTE_PUBLIC_KEY_HERE"
export WEB_PUSH_PRIVATE_KEY="PASTE_PRIVATE_KEY_HERE"
```

Generate a separate pair for staging and production, then reuse each environment's pair across deployments.

---

## 3. Apply database migration, Vault & Cron (Supabase Dashboard)

Because migration DDL and Vault/Cron setup run directly inside the target project's database, complete these SQL steps in **Supabase Dashboard** before running the automated CLI deploy in Section 4.

### 3a. Apply the migration once

1. Open [20261115014637_private_messaging_and_web_push.sql](../../supabase/migrations/20261115014637_private_messaging_and_web_push.sql).
2. In the target Supabase project’s **SQL Editor**, paste its complete contents between `BEGIN;` and `COMMIT;`, then execute the complete transaction:

```sql
BEGIN;

-- Replace this comment with the COMPLETE migration file contents.

COMMIT;
```

Do not rerun a successfully applied migration: its table and trigger creation statements are not intended for repeated execution.

Verify that all four tables exist and have RLS enabled:

```sql
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'message_identities',
    'message_public_keys',
    'push_subscriptions',
    'push_deliveries'
  )
ORDER BY tablename;
```

Expect four rows with `rowsecurity = true`. Run **Security Advisor** and review any findings on the new tables, functions, and grants.

### 3b. Enable `pg_cron` + `pg_net`, save Vault secrets & schedule delivery

1. Enable **`pg_cron`** and **`pg_net`** under **Database → Extensions**.
2. Open **Integrations → Vault** (or Project Vault) and create these two **Vault** secrets:

| Vault secret name | Value |
| --- | --- |
| `push_dispatch_url` | `https://PROJECT_REF.supabase.co/functions/v1/push-dispatch` |
| `push_dispatch_secret` | Exactly the same value as `PUSH_DISPATCH_SECRET` from Section 2 |

> [!NOTE]
> **Edge Function secrets and Vault secrets are separate stores.** Saving a secret in Edge Functions does not create it in Vault.

3. Execute the contents of [configure_push_cron.sql](../../scripts/configure_push_cron.sql) in **SQL Editor**, then confirm the job is active:

```sql
SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname = 'deliver-private-push';
```

Expect one active row with schedule `* * * * *`. You do not need an additional Cloudflare Cron job.

### 3c. Allow all subdomains in Supabase Auth URL Configuration

In **Supabase Dashboard → Authentication → URL Configuration**:

- **Site URL**: `https://alphajournal.in`
- **Redirect URLs**:
  ```text
  https://alphajournal.in/**
  https://www.alphajournal.in/**
  https://app.alphajournal.in/**
  https://community.alphajournal.in/**
  https://admin.alphajournal.in/**
  https://affiliate.alphajournal.in/**
  alphajournal://auth/callback
  ```

---

## 4. Combined CLI Deployment (Supabase + Clean Wasm Web Build + Cloudflare Worker)

Only run `migration repair` after Section 3a's SQL transaction succeeded cleanly.

Check that your local `.env` points to the target Supabase project (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_PUBLISHABLE_KEY`), and leave `COPILOT_API_URL` unset or empty for the client-encrypted Supabase-hosted AI workspace. Ensure your existing AI-provider secrets (`OPENAI_API_KEY`, `OPEN_AI_KEY`, `OPENROUTER_API_KEY`) are already set in Supabase Edge Functions → Secrets.

Run this combined deploy sequence from the repository root:

```bash
# 1. Record manual migration as applied (skip if your migration pipeline already ran it)
npx --yes supabase@3.1.0 migration repair 20261115014637 \
  --status=applied \
  --remote="$PROJECT_REF"

# 2. Save Web Push + Dispatcher secrets on Supabase Edge Functions
npx --yes supabase@3.1.0 secrets set --remote="$PROJECT_REF" \
  WEB_PUSH_PUBLIC_KEY="$WEB_PUSH_PUBLIC_KEY" \
  WEB_PUSH_PRIVATE_KEY="$WEB_PUSH_PRIVATE_KEY" \
  WEB_PUSH_SUBJECT="mailto:${MONITORED_EMAIL}" \
  PUSH_DISPATCH_SECRET="$PUSH_DISPATCH_SECRET"

# 3. Deploy all required Edge Functions (push, egress-cached quote proxy, and AI)
npx --yes supabase@3.1.0 functions deploy push-dispatch \
  --remote="$PROJECT_REF" --use-api --no-verify-jwt

npx --yes supabase@3.1.0 functions deploy market-quote-proxy \
  --remote="$PROJECT_REF" --use-api --no-verify-jwt

npx --yes supabase@3.1.0 functions deploy ai-chat \
  --remote="$PROJECT_REF" --use-api

npx --yes supabase@3.1.0 functions deploy ai-gateway \
  --remote="$PROJECT_REF" --use-api

# 4. Publish and verify database-free web update metadata, then sync public
#    client config and dependencies
python3 scripts/generate_app_update_manifest.py --platform web
python3 scripts/prepare_client_config.py
python3 scripts/generate_app_update_manifest.py --platform web --check
flutter pub get

# 5. Clean previous build artifacts so stale removed assets are not uploaded,
#    then build WebAssembly + JS fallback with deferred chunks and public VAPID key
rm -rf build/web
flutter build web --release --wasm \
  --dart-define=WEB_PUSH_PUBLIC_KEY="$WEB_PUSH_PUBLIC_KEY"

# Fallback if you need CanvasKit-only JS without Wasm:
# rm -rf build/web && flutter build web --release --dart-define=WEB_PUSH_PUBLIC_KEY="$WEB_PUSH_PUBLIC_KEY"

# 6. Verify required runtime, Wasm/JS, and push service-worker files exist
test -f build/web/index.html && \
test -f build/web/push_notifications.js && \
test -f build/web/push-sw.js && \
test -f build/web/main.dart.wasm && \
test -f build/web/main.dart.js

# 7. Deploy Worker ([worker/index.js]) + static assets + [web/_headers] + custom domains ([wrangler.jsonc])
npx wrangler deploy
```

### Cloudflare Staging vs. Production Note

- [wrangler.jsonc](../../wrangler.jsonc) binds production custom domains (`alphajournal.in`, `www.alphajournal.in`, `app.alphajournal.in`, `community.alphajournal.in`, `admin.alphajournal.in`, `affiliate.alphajournal.in`). For hosted staging, use a separate Worker config with a different Worker `name`, staging `.env`/VAPID key, and **no production domain routes**.
- Verify DNS in Cloudflare (**DNS → Records**) matches [cloudflare-dns-records.txt](../cloudflare-dns-records.txt) (`CNAME` records for `@`, `www`, `app`, `community`, `admin`, `affiliate` set to **Proxied / Orange Cloud**), and preserve existing public `SUPABASE_URL` and `SUPABASE_ANON_KEY` Worker bindings used by [worker/index.js](../../worker/index.js) for public `/community/post/:id` Open Graph previews.
- Only `push-dispatch` (`x-push-secret` header) and `market-quote-proxy` (origin allowlist in `ALLOWED_ORIGINS` + server-side 60s/5m cache, configured in [supabase/config.toml](../../supabase/config.toml)) disable gateway JWT verification. Keep JWT verification enabled for `ai-chat` and `ai-gateway`.

For local browser testing against staging before deploying:

```bash
flutter run -d chrome \
  --dart-define=WEB_PUSH_PUBLIC_KEY="$WEB_PUSH_PUBLIC_KEY"
```

---

## 5. Smoke Checks & Verification

### 5a. CLI Smoke Checks Immediately After Deploy

```bash
# 1. Confirm subdomain HTTP 200 + push scripts return JavaScript (not HTML fallback)
curl -sI "${APP_ORIGIN}/"                     | grep -iE "http/|cache-control"
curl -sI "${APP_ORIGIN}/push_notifications.js" | grep -iE "http/|content-type|cache-control"
curl -sI "${APP_ORIGIN}/push-sw.js"           | grep -iE "http/|content-type|cache-control"

# 2. Confirm immutable caching header on Wasm/assets
curl -sI "${APP_ORIGIN}/main.dart.wasm"       | grep -iE "http/|cache-control"

# 3. Confirm market-quote-proxy CORS preflight succeeds for app.alphajournal.in
curl -i -X OPTIONS "https://${PROJECT_REF}.supabase.co/functions/v1/market-quote-proxy" \
  -H "Origin: ${APP_ORIGIN}" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: authorization,x-client-info,apikey,content-type"
```

### 5b. `app.` Subdomain & Egress Verification (Chrome DevTools + Supabase Reports)

- [ ] Open `https://app.alphajournal.in/` in Incognito: confirm it loads directly into login / `/workspace` (not 404 or stuck on marketing landing page once authenticated), and OTP/OAuth callbacks return to `https://app.alphajournal.in/`.
- [ ] In DevTools **Network**, filter by `functions/v1/market-quote-proxy`: confirm `OPTIONS` and `POST` succeed without 404/CORS retry storms.
- [ ] Filter by `rest/v1/`: verify explicit `select=` column lists (no `select=*`), `Range` headers on community feed, and `HEAD` requests for `.count()` tallies.
- [ ] Confirm secondary routes (`Market`, `Calculators`, `Admin`, `Affiliate`) fetch `*.part.js` chunks lazily only when visited, and reload with **Disable cache** unchecked to confirm `/assets/*`, `/canvaskit/*`, and `*.wasm` serve from cache (`public, max-age=31536000, immutable`) while `/index.html`, `/flutter_bootstrap.js`, and `/version.json` revalidate.
- [ ] Background the tab for 2 minutes and verify network polling stops until the tab regains focus.
- [ ] Compare 24h **Supabase Dashboard → Reports → Egress** (Database / REST / Storage) before and after rollout.

### 5c. Browser Notifications & Encrypted Messaging Verification

Use two separate test accounts and browser profiles on the same origin (`https://app.alphajournal.in` — browser push permissions, subscriptions, and local keys are origin-specific). Each account initializes its own recovery passphrase; another device for the **same account** uses that account’s existing passphrase.

#### Browser notifications
- [ ] On account B, click **Turn on notifications** and allow browser permission.
- [ ] Confirm a row for B appears in `push_subscriptions`.
- [ ] From account A, send B a message, then background B’s tab.
- [ ] Wait for the scheduler and verify a generic notification appears without message text.
- [ ] Click it and confirm the app opens or receives focus, and in DevTools verify the push service worker registers under `/push/`.
- [ ] Test blocked permission, turning notifications off, logout/account switching, category preferences, and quiet hours.

Inspect queue progress without displaying subscription credentials:

```sql
SELECT id, attempts, available_at, completed_at
FROM public.push_deliveries
ORDER BY id DESC
LIMIT 20;
```

`completed_at` can also mean a notification was skipped because of preferences or read state. Confirm actual delivery in the browser and function logs, not from that column alone.

#### Encrypted messaging and AI history
- [ ] Set up both accounts’ recovery passphrases and save them securely.
- [ ] Send and edit text, images, documents, charts, trade setups, and voice messages.
- [ ] Reload and verify recipients can still read the content.
- [ ] Confirm new message bodies use `e2ee:v1:` envelopes and new uploaded private files contain ciphertext.
- [ ] Confirm hosted copilot workspace state contains an `encrypted` envelope.
- [ ] Restore the same account in another browser using its recovery passphrase and verify history.
- [ ] Confirm a wrong passphrase cannot unlock history.
- [ ] Confirm missing recipient keys and unavailable encryption storage produce errors rather than plaintext sends.

---

## 6. Native Android/iOS/macOS setup — only for installed apps

Skip this section if you are deploying only the browser app.

1. Create or select a Firebase project and register matching Android/Apple applications with the correct package/bundle identifiers.
2. Enable FCM HTTP v1. Store a restricted Firebase service-account JSON as the Supabase Edge secret `FIREBASE_SERVICE_ACCOUNT`; never bundle it into the app.
3. Supply the matching public client settings to each native Flutter build using Dart defines: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, and Apple `FIREBASE_IOS_BUNDLE_ID`.
4. For Apple apps, enable Push Notifications in Xcode, configure the appropriate APNs entitlement/provisioning profile, and upload an APNs authentication key to Firebase. Enable Remote notifications background mode when background processing is required.
5. Build and sign each platform app, then test foreground, background, terminated-app delivery, permission denial, token refresh, and logout on physical devices.

Cloudflare hosting does not provide Firebase or Apple signing credentials. Native Windows/Linux clients currently use the browser app for push.

---

## 7. Troubleshooting

| Symptom | Check |
| --- | --- |
| `app.alphajournal.in` opens marketing splash or auth redirect goes to apex domain | Redeploy `build/web` from commit `ade19aa`+ (`GoRouter` host fix) and ensure `https://app.alphajournal.in/**` is in Supabase **Auth → Redirect URLs** and **Cloudflare Custom Domains** ([wrangler.jsonc](../../wrangler.jsonc)). |
| `market-quote-proxy` returns 404 or CORS error | Run `supabase functions deploy market-quote-proxy --remote="$PROJECT_REF" --use-api --no-verify-jwt` and check `ALLOWED_ORIGINS` matches your origin. |
| Stale UI or old bundle loads after deploy | Ensure `rm -rf build/web` ran before `flutter build web --release --wasm` and confirm `/index.html`, `/flutter_bootstrap.js`, and `/version.json` return `no-cache` headers. |
| “Push delivery has not been configured” | Rebuild Flutter with `--dart-define=WEB_PUSH_PUBLIC_KEY=...`; a Cloudflare runtime variable alone is insufficient. |
| Notifications are blocked | Allow notifications in browser site settings, then retry the in-app button. |
| Worker registration fails | Confirm HTTPS and that `/push-sw.js` returns JavaScript (`text/javascript` / `application/javascript`), not HTML fallback. |
| Subscription exists, but no delivery jobs | Confirm a notification was created for that account after subscription and the migration’s queue trigger is installed. |
| Jobs exist, but attempts remain zero | Check Cron is active (`deliver-private-push`), Vault names (`push_dispatch_url`, `push_dispatch_secret`) match exactly, and the URL targets the right project. |
| Dispatcher returns 401 | The `x-push-secret` value is missing or differs from `PUSH_DISPATCH_SECRET`. |
| Dispatcher returns 503 | Check configured secrets and database/queue availability in function logs. |
| Delivery is skipped | Check notification category preferences, quiet hours, and whether the notification was already read. |
| Encryption setup is unavailable | Confirm the complete migration succeeded on the project used by the Flutter build, and inspect function/table grants and RLS. |
| Recipient is not ready for encrypted messaging | Have that recipient sign in to the new client and initialize their encrypted identity. |

---

## Encryption boundaries

This rollout protects new private-message content and client-encrypted Supabase copilot workspace saves. It does not retroactively encrypt historical plaintext, older attachment objects, backups, or public community posts. Routing metadata and reactions remain readable metadata.

The AI gateway/provider still receives prompts to generate answers. Encrypted saved history does not make AI inference private from that provider. The custom messaging implementation has not been independently audited and does not provide Signal/MLS-style forward secrecy or key transparency.

See [private-messaging-and-push.md](private-messaging-and-push.md) for implementation details and local verification commands.

## References

- [Web Push library and key generation](https://github.com/web-push-libs/web-push#command-line)
- [Supabase Edge Function secrets](https://supabase.com/docs/guides/functions/secrets)
- [Supabase Cron installation](https://supabase.com/docs/guides/cron/install)
- [Supabase Vault](https://supabase.com/docs/guides/database/vault)
- [Scheduling Supabase Edge Functions](https://supabase.com/docs/guides/functions/schedule-functions)
- [Cloudflare Workers deployment](https://developers.cloudflare.com/workers/wrangler/commands/workers/)
- [Firebase Flutter push setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
