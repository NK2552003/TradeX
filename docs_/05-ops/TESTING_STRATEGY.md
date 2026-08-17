# Testing Strategy — TraderHub

### 1. Philosophy
Solo, AI-assisted build with a 6–10 week MVP target — testing effort is weighted toward the areas where bugs are expensive (money-adjacent flows, RLS/data leakage, subscription gating) and lighter on presentational widgets. Not aiming for 100% coverage; aiming for confidence on the paths that touch user data, payments, or AI cost.

### 2. Test Layers

| Layer | Tool | Scope |
|---|---|---|
| Unit | `flutter test` | Providers, repositories, model serialization (freezed/json_serializable), business logic (tier limits, indicator formatting) |
| Widget | `flutter test` | Individual screens/components in isolation, golden tests for key screens (feed card, note editor, insight card) |
| Integration | `flutter test integration_test/` | Full user flows against local Supabase: sign up → create note → post → follow → like |
| Edge Function | Deno test (`supabase functions serve` + local requests) | `ai-insight` function: auth check, rate-limit enforcement, cache hit/miss, error handling |
| RLS / DB | `supabase test db` (pgTAP) or manual `supabase db diff` + scripted queries | Every policy in API_DATA_MODEL.md verified from both an authenticated-as-owner and authenticated-as-other-user session |
| Manual QA | Checklist per release phase | Cross-platform smoke test (iOS/Android/Web), subscription purchase flow via RevenueCat sandbox |

### 3. Coverage Targets (guideline, not gate)
- Domain/business logic (providers, repositories, tier-limit logic): high priority, aim to cover all branches
- Widgets: cover interactive/stateful widgets; skip pure presentational ones
- Edge Functions: cover all response codes (200 cached, 200 fresh, 429 rate-limited, 401 unauthorized, 500 upstream failure)
- RLS policies: every policy needs at least one "allowed" test and one "denied" test

### 4. RLS Testing (critical path)
Because `journal_entries` are private-by-default (except an opted-in public subset) and `posts`/`comments`/public `strategies` are public-read/owner-write, every policy change must be verified with two identities:
1. As the row owner — operation should succeed
2. As a different authenticated user — operation should fail (403/empty result, not a leak)

This now also covers `strategies` (private vs. public visibility), `saved_posts` and `notifications` (owner-only), and the two-flag public journal entry policy (`journal_entries.is_public` AND `profiles.public_journals` both required — test that neither flag alone leaks a row).

**Direct Messages needs a third test dimension beyond the owner/non-owner pattern above**, since `conversations`/`messages` combine ownership, subscription tier, and blocking in one policy (API_DATA_MODEL.md § 2):
1. Two Premium participants — both can read and send (baseline)
2. A third, uninvolved user — cannot read or send into someone else's conversation (standard non-owner check)
3. A Free-tier participant — can read an existing conversation but insert (send) is rejected; explicitly test both starting a new conversation and sending into an existing one
4. A Premium user who downgrades mid-conversation — next send attempt is rejected even though earlier messages in the same thread succeeded (the tier check runs per-message, not once at conversation creation — test this transition, not just a static tier)
5. Two users where one has blocked the other — `are_blocked()` should reject the insert in both directions (test as both the blocker and the blocked party attempting to send)
6. The `read_at` update policy — confirm a participant can toggle `read_at` on a message they received, but cannot use the same update path to alter `content`

Recommended: a small pgTAP suite in `supabase/tests/` run via `supabase test db` in CI, plus a manual pass before each release using two throwaway test accounts.

### 5. AI Insight Function Testing
Given AI calls cost money and are rate-limited per tier, test explicitly for:
- Free tier → 0 allowed, immediate 429
- Pro/Elite tier → allowed up to daily limit, 429 after
- Cache hit (< 15 min old) → no upstream Claude/market-data call made
- Cache miss → upstream calls made, result persisted to `ai_insights`, request logged to `ai_insight_requests`
- Malformed/unknown ticker → graceful error, no partial writes

### 6. Subscription/Paywall Testing
- RevenueCat sandbox purchases on iOS/Android test tracks; Stripe test mode for web
- Verify tier changes propagate to `profiles.subscription_tier` and that gated features (unlimited notes, AI insights, daily digest) unlock/lock correctly on upgrade/downgrade/expiry

### 7. CI Integration
Run on every PR (see [DEPLOYMENT.md](./DEPLOYMENT.md) for full pipeline):
1. `flutter analyze`
2. `flutter test`
3. `supabase test db` (RLS/pgTAP)
4. Edge Function tests (`deno test` inside `supabase/functions/ai-insight/`)

Integration tests and manual QA checklist run before each phase release, not on every PR, to keep CI fast.

### 8. Out of Scope (MVP)
- Load/performance testing (defer until real usage data exists)
- Automated cross-device visual regression beyond a small golden-test set
- Penetration testing (revisit before handling real brokerage/payment data beyond RevenueCat's abstraction)
