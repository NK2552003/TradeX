# Security & Compliance — TraderHub

### 1. Purpose
TraderHub handles user-generated financial journal data, rich trading-strategy documents (some public), watchlists, public social content, and AI-generated trading commentary. This doc consolidates the security and compliance requirements referenced across PRD.md, ARCHITECTURE.md, and API_DATA_MODEL.md into one checklist.

### 2. Data Classification
| Data | Sensitivity | Default access |
|---|---|---|
| `journal_entries` (trade fields, psychology, mistakes, lessons, screenshots) | Private, user-financial, potentially self-critical | Owner only (RLS); opted-in entries (`is_public=true` + `profiles.public_journals=true`) are public read-only |
| `strategies` / `strategy_versions` | Private by default; user-controlled | Owner only, unless `visibility='public'` (then public read-only) |
| `watchlists` / `watchlist_items` | Private, reveals trading interest/positioning | Owner only (RLS) |
| `posts` / `comments` | Public | Public read, owner write |
| `saved_posts` | Private (reveals what a user bookmarks, which can be sensitive — e.g. saving posts about a specific loss-heavy strategy) | Owner only (RLS) |
| `conversations` / `messages` | Private, potentially sensitive (personal conversations between traders — may include shared PII, off-platform contact info, or content neither party wants public) | Both participants only (RLS); sending additionally requires an active Premium/Enterprise subscription, checked per-message, and is blocked entirely between users who've blocked each other |
| `blocks` | Private — a block list itself is sensitive (reveals who someone wants distance from) | Owner (blocker) only; the blocked party has no visibility into who blocked them |
| `notifications` | Private | Owner only (RLS) |
| `profiles` | Mostly public (handle, bio, avatar, experience_level, trading_style) | `subscription_tier` should not be exposed to other users beyond what's needed for badges/UI; `public_journals` toggle itself can stay visible, it's just a setting |
| `ai_insights` | Not user-specific (per-ticker cache) | Effectively public data, no PII |
| `ai_insight_requests` | Usage/audit log across all AI features (`kind` field) | Owner-only read; used server-side for rate limiting |

### 3. Row-Level Security Review
All RLS policies are defined in API_DATA_MODEL.md § 2. Before each release:
- [ ] Re-verify `journal_entries`: only `auth.uid() = user_id` can select/insert/update/delete; separately verify the public-read policy only surfaces a row when BOTH `is_public=true` on the entry AND `public_journals=true` on the owning profile — neither flag alone should be enough
- [ ] Re-verify `strategies`: owner has full access; non-owners get select-only, and only when `visibility='public'` — confirm a private strategy is invisible end-to-end (not just hidden in UI)
- [ ] Re-verify `strategy_versions`: access follows the parent strategy's owner, never independently readable
- [ ] Re-verify `watchlists`/`watchlist_items`: owner-only, joined correctly through `watchlist_id`
- [ ] Re-verify `posts`/`comments`: public select, but insert/update restricted to `auth.uid() = user_id`
- [ ] Re-verify `saved_posts`/`notifications`: owner-only on both, no cross-user leakage of what someone bookmarked or was notified about
- [ ] Re-verify `conversations`/`messages`: both participants (not a third party) can read; verify a Free-tier user's insert is actually rejected (not just hidden in UI) for both starting a new conversation and sending within an existing one; verify the `read_at` update policy can't be used to alter `content` (API_DATA_MODEL.md § 2's `with check` clause is the enforcement point — confirm it, don't assume the `using` clause alone covers it)
- [ ] Re-verify `profiles`: public select, but update restricted to `auth.uid() = id`
- [ ] Confirm no table was created without `enable row level security` — RLS is opt-in per table in Postgres, so a forgotten table is an open table
- [ ] Run the two-identity manual/automated check described in TESTING_STRATEGY.md § 4 for any policy touched in a PR, **including** a third check for `strategies`: verify a private strategy is unreadable by a non-owner, and a public one is read-only (no write) by a non-owner

### 4. Secrets & Key Management
- `ANTHROPIC_API_KEY` and market-data API key live only in Supabase Edge Function secrets — never in the Flutter client, never in `.env` committed to git (see DEV_SETUP.md § 3, DEPLOYMENT.md § 4)
- Supabase anon key is the only client-side key; it is safe by design as long as RLS is correctly enforced on every table
- Rotate keys if ever exposed in a client build, log, or public repo
- Post-MVP: Enterprise `api_keys` (customer-facing API access) need their own scoped-permission and rotation model — flagged for design when Enterprise is built (ROADMAP.md)

### 5. AI Output Compliance
Applies to all AI features — `ai-insight`, `analyze-screenshot`, `ai-strategy-review`, `ai-journal-analysis`, `strategy-ai-summary` (API_DATA_MODEL.md § 3–7):
- Every AI-generated insight response includes a `disclaimer` field: *"This is AI-generated educational content, not financial advice."*
- System prompts must instruct plain-English output + mandatory disclaimer where the output could read as advice — verify this on every prompt change, across all five AI features, not just `ai-insight`
- `ai-journal-analysis` surfaces patterns (recurring mistakes, psychology trends) — phrase findings as observations, not diagnoses; avoid language that could read as a mental-health claim about the user
- No AI response should imply a buy/sell recommendation or guaranteed outcome; review prompt wording periodically for drift toward advice-like phrasing

### 6. Rate Limiting & Cost Control
- All AI-calling functions enforce per-tier daily/feature limits (Free: 0 across all AI features; Premium/Enterprise: unlimited or high soft caps — see API_DATA_MODEL.md § 9) before calling upstream Claude/market-data APIs
- All requests logged to `ai_insight_requests` with a `kind` discriminator for audit and anomaly detection across features
- Cache (`ai_insights`, 15-min TTL) reduces redundant upstream calls across users requesting the same ticker
- `price-alerts` is a scheduled system job (not user-triggered), so it needs its own cost ceiling (e.g. batch/interval tuning) rather than a per-user rate limit

### 7. Terms of Service / Legal Notes
- ToS must state TraderHub is not a registered investment advisor and does not guarantee returns (PRD.md § 7)
- Journal entries, strategies, and posts are user-generated content — ToS needs a content policy covering moderation (report/block/mute per PRD.md § 5.5) and a takedown process, which now also covers **public** Strategy Notes since those are publicly visible
- No brokerage/trade-execution integration in MVP, which keeps the app out of broker-dealer regulatory scope for now — flag before adding execution features in a future phase (see ROADMAP.md)
- Enterprise tier (team management, org data, custom branding, API access) will need its own data-processing terms once built — org admins will have visibility into member data that individual-user ToS doesn't currently contemplate

### 8. Moderation
- Report/block/mute exists at the product level (PRD.md § 5.6 Community); define an internal process for reviewing reports (even if manual/solo during MVP) so public posts/comments — and now public Strategy Notes — don't go unmoderated
- **Direct Messages moderation:** blocking is now backed by a real `blocks` table (API_DATA_MODEL.md § 1) enforced in RLS — a block is mutual/symmetric at the database level (`are_blocked()` checks both directions), so a blocked user can neither start nor continue a conversation with the blocker, immediately, without relying on client-side UI alone to hide the option. A reported conversation still needs its own lightweight review queue (even if just "read the reported messages" at solo scale) — DMs are the one surface in the app where moderation can't rely on other users' organic reports the way a public post can
- Image uploads (post images, avatars, journal screenshots, strategy images) via Supabase Storage — validate file type/size server-side, not just client-side

### 9. Incident Response (lightweight, solo-founder scale)
- Sentry alerts on Edge Function errors and client crashes (per DEPLOYMENT.md § 7)
- If a secret leaks: rotate immediately, redeploy Edge Functions, check `ai_insight_requests` and Supabase auth logs for abuse during the exposure window
- If an RLS bug is found in prod: patch and deploy the policy fix first, then assess what was exposed and to whom before any public disclosure decision — for `strategies`, specifically check whether any private strategy was briefly exposed via a public-select policy misconfiguration
