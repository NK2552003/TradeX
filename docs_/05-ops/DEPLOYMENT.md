# Deployment guidelines: TradeX

## 1. Environments
Following the architecture specifications in [ARCHITECTURE.md](../02-architecture/ARCHITECTURE.md):
- **Development**: Local Supabase instance managed via the Supabase CLI, paired with local `.env` configuration on individual developer workstations.
- **Staging**: Supabase cloud project for pre-release validation. Mobile builds distribute through TestFlight for iOS and Google Play Internal Testing tracks; web builds deploy to a dedicated staging URL.
- **Production**: Dedicated production Supabase project powering public store releases on the Apple App Store and Google Play Console, alongside production web hosting.

Each Supabase environment maintains isolated databases, edge functions, and API secrets. Staging and production environments never share data.

## 2. CI/CD pipeline (GitHub Actions)

**Pull request checks against `main`:**
1. `flutter analyze`
2. `flutter test`
3. `supabase test db` (running pgTAP and row-level security tests)
4. Deno unit tests for Edge Functions

**Merge to `main` (automated deployment to staging):**
1. Execute the full test suite.
2. `supabase db push --project-ref <staging-ref>` to apply new migrations.
3. `supabase functions deploy ai-insight --project-ref <staging-ref>` to update backend functions.
4. `flutter build web --release` and upload static artifacts to the staging web host.
5. Compile staging mobile builds for TestFlight and the Google Play Internal track.

**Production release (triggered by release tag):**
1. Cut a release branch or tag (for example, `v1.0.0`).
2. Run automated validation checks against staging.
3. Apply migrations to production using `supabase db push --project-ref <prod-ref>`.
4. Deploy production edge functions with `supabase functions deploy ai-insight --project-ref <prod-ref>`.
5. Compile production client artifacts:
   - `flutter build apk --release`
   - `flutter build ios --release`
   - `flutter build web --release`
6. Submit application packages to the App Store and Google Play Console; upload web assets to the production CDN.
7. Tag the release in source control and update milestone progress in the product roadmap.

## 3. Database migrations
- Apply schema updates exclusively through versioned SQL files in `supabase/migrations/`. Never modify live databases manually.
- Promote changes sequentially: development, staging, and production.
- Include matching row-level security policies in the same migration file, as outlined in [API_DATA_MODEL.md](../02-architecture/API_DATA_MODEL.md).

## 4. Secrets management
- Client configuration keys (`SUPABASE_URL` and `SUPABASE_ANON_KEY`) are protected by database row-level security policies. These remain untracked in version control and load through environment files.
- Third-party API credentials (`ANTHROPIC_API_KEY`, `MARKET_DATA_API_KEY`) are configured through `supabase secrets set` with distinct staging and production keys.
- RevenueCat uses sandbox keys in development and staging, switching to production keys for live store releases.
- Never write credentials or tokens to function logs or continuous integration job outputs.

## 5. Rollback strategy
- Edge functions: Redeploy the previous Git tag using `supabase functions deploy`. Because functions are stateless, redeployments execute quickly without downtime.
- Migrations: Prioritize forward-fixing migrations whenever feasible. For destructive changes, test rollback SQL scripts in staging before executing production updates.
- Mobile releases: Both Apple App Store Connect and Google Play Console allow teams to halt phased rollouts of problematic builds. Retain prior stable builds for expedited review if needed.
- Web releases: Re-point CDN distribution or redeploy previous static build artifacts using automated commands.

## 6. Release cadence
Releases follow the phased timeline defined in the product requirements. Staging updates continuously upon merging pull requests to `main`. Production releases align with major milestones (Phases 0 through 5), keeping app store submission and review cycles structured.

## 7. Post-deployment monitoring
- Error tracking: Sentry captures crashes and unhandled exceptions across Flutter clients and Supabase edge functions.
- Product analytics: PostHog tracks activation, retention, and funnel conversion against product KPIs.
- Consumption monitoring: Review `ai_insight_requests` query volumes post-release to verify rate-limiting rules and manage Anthropic API costs.
