# Deployment — TraderHub

### 1. Environments
Per ARCHITECTURE.md:
- **dev** — local Supabase (via CLI) + local `.env`, individual developer machine
- **staging** — Supabase project #1, app distributed via TestFlight (iOS) / Internal testing track (Play), web build on a staging URL
- **prod** — Supabase project #2, store releases (App Store / Play), production web URL

Each Supabase project has its own database, secrets, and Edge Function deployment — staging and prod never share data.

### 2. CI/CD Pipeline (GitHub Actions)

**On every PR to `main`:**
1. `flutter analyze`
2. `flutter test`
3. `supabase test db` (RLS/pgTAP suite)
4. Edge Function tests

**On merge to `main` (auto-deploy to staging):**
1. Run full test suite (as above)
2. `supabase db push --project-ref <staging-ref>` — apply new migrations
3. `supabase functions deploy ai-insight --project-ref <staging-ref>`
4. `flutter build web --release` → deploy to staging web host
5. Build staging mobile artifacts → TestFlight / Play Internal track

**Production release (manual trigger / tag-based):**
1. Cut a release branch or tag (`v1.x.x`)
2. Run full test suite against staging one more time
3. `supabase db push --project-ref <prod-ref>` — apply migrations to prod
4. `supabase functions deploy ai-insight --project-ref <prod-ref>`
5. `flutter build apk --release` / `flutter build ios --release` / `flutter build web --release`
6. Submit to App Store / Play Console; deploy web build to prod host
7. Tag release in git, update ROADMAP.md status if a phase completed

### 3. Migrations
- All schema changes go through `supabase/migrations/`, never applied by hand against a live project
- Order: dev → staging → prod, never skip staging
- Every migration PR includes the matching RLS policy changes (if any) in the same file, per API_DATA_MODEL.md

### 4. Secrets Management
- Client `.env` (SUPABASE_URL, SUPABASE_ANON_KEY) — safe to be public-ish, scoped by RLS; still not committed to git
- `ANTHROPIC_API_KEY`, `MARKET_DATA_API_KEY` — set via `supabase secrets set`, scoped per project (staging keys ≠ prod keys where the provider allows it)
- RevenueCat API keys — per-environment (sandbox for dev/staging, production for prod)
- Never log secret values in Edge Function logs or CI output

### 5. Rollback Plan
- **Edge Functions:** redeploy the previous git tag's function version (`supabase functions deploy` is fast — no downtime migration needed since functions are stateless)
- **Migrations:** write forward-fix migrations rather than reversing in place where possible; if a migration is destructive, have a tested down-migration ready before applying to prod
- **Mobile builds:** App Store/Play both support halting rollout of a bad release; keep previous build available for expedited re-review if needed
- **Web:** keep the previous static build artifact deployable via a one-command redeploy

### 6. Release Cadence
Tracks the phased plan in PRD.md § Release Plan — staging deploys continuously off `main`; production releases happen at the end of each phase (0–5), not continuously, to keep app store review overhead manageable during MVP build-out.

### 7. Monitoring Post-Deploy
- Sentry for crash/error tracking (client + Edge Function errors)
- PostHog/Firebase Analytics for activation/retention funnel (ties to PRD.md § Success Metrics)
- Watch `ai_insight_requests` volume after each release for unexpected rate-limit or cost spikes
