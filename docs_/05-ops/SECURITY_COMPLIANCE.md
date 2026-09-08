# Security and compliance: TradeX

## 1. Purpose
TradeX processes user financial journals, rich trading strategy documents (both private and public), watchlists, community posts, and AI-generated market commentary. This document consolidates security guidelines, compliance mandates, and data protection policies referenced across the technical documentation.

## 2. Data classification and sensitivity
| Table / Resource | Sensitivity classification | Access policy |
|---|---|---|
| `journal_entries` | Sensitive financial and behavioral data | Owner access only via row-level security. Opted-in public entries require both `is_public=true` on the entry and `public_journals=true` on the profile. |
| `strategies`, `strategy_versions` | Proprietary user analysis | Owner-only access by default; readable by all users when `visibility='public'`. |
| `watchlists`, `watchlist_items` | Private trading interest signals | Owner access only via row-level security. |
| `posts`, `comments` | Public social content | Public read access; create, update, and delete restricted to author. |
| `saved_posts` | Private user preferences | Owner access only via row-level security. |
| `conversations`, `messages` | Confidential interpersonal communication | Restricted to thread participants via row-level security. Writing requires active Premium or Enterprise entitlements, verified per message. Blocked users cannot message each other. |
| `blocks` | Sensitive interpersonal controls | Readable and writable only by the blocking user. Blocked targets have no visibility into block records. |
| `notifications` | Private user activity alerts | Owner access only via row-level security. |
| `profiles` | Public directory information | Public read access for handle, avatar, and trading style. Billing details are withheld from public queries. |
| `ai_insights` | Shared market analytics cache | Public read access; cached per ticker symbol with no user-identifying data. |
| `ai_insight_requests` | Usage audit and rate-limiting log | Readable only by the requesting account; evaluated server-side to enforce tier quotas. |

## 3. Row-level security checklist
All database policies are defined in [API_DATA_MODEL.md](../02-architecture/API_DATA_MODEL.md). Before every deployment, verify the following:
- `journal_entries`: Verify that only `auth.uid() = user_id` can create, update, or delete records. Confirm that public read policies require both `is_public=true` on the trade and `public_journals=true` on the owning user profile.
- `strategies`: Ensure owners retain full CRUD permissions while non-owners receive read-only access strictly when `visibility='public'`. Verify that private strategies cannot be discovered through direct queries.
- `strategy_versions`: Confirm that version access inherits permissions from parent strategy ownership and cannot be queried independently.
- `watchlists` and `watchlist_items`: Verify owner-only access joined across `watchlist_id`.
- `posts` and `comments`: Ensure public read access while write operations enforce `auth.uid() = user_id`.
- `saved_posts` and `notifications`: Verify owner isolation to prevent data leakage across accounts.
- `conversations` and `messages`: Confirm that only participating users can query conversations. Verify that free-tier users cannot write messages and that update policies on `read_at` prevent modifying message text via the `with check` clause.
- `profiles`: Confirm public read availability while update operations restrict changes to `auth.uid() = id`.
- Table security flags: Confirm every table explicitly runs `alter table ... enable row level security;`.
- Multi-identity testing: Execute verification checks across dual authenticated sessions as detailed in [TESTING_STRATEGY.md](./TESTING_STRATEGY.md).

## 4. Secrets and key management
- The `ANTHROPIC_API_KEY` and market provider keys reside exclusively in Supabase Edge Function secrets. They are never compiled into mobile applications or committed to source repositories.
- The public Supabase anonymous key is designed for client exposure, relying on database row-level security to enforce access boundaries.
- Rotate credentials immediately if exposure occurs in client binaries, logging tools, or public repositories.
- Customer-facing Enterprise API keys will introduce granular permission scopes and key rotation lifecycles during post-MVP development.

## 5. AI output compliance and disclaimers
These rules apply across all AI capabilities (`ai-insight`, `analyze-screenshot`, `ai-strategy-review`, `ai-journal-analysis`, `strategy-ai-summary`):
- Every response includes a mandatory disclosure field: *"This is AI-generated educational content, not financial advice."*
- System prompts must enforce clear educational language and attach the disclaimer to prevent interpretations resembling regulated investment advice.
- Journal pattern evaluations must present findings as behavioral observations rather than medical or psychological diagnoses.
- AI responses must never promise financial gains or issue explicit buy or sell mandates.

## 6. Rate limiting and cost control
- Edge functions enforce tier-based query limits (Free accounts receive zero AI allocations; Premium and Enterprise tiers operate under defined fair-use caps) before calling upstream models.
- Requests record to `ai_insight_requests` with a `kind` attribute for auditing and cost tracking.
- The shared `ai_insights` cache (15-minute expiration) minimizes repetitive upstream queries for identical market symbols.
- Background jobs such as price alert evaluations operate under batch schedules to preserve budget caps.

## 7. Terms of service and regulatory posture
- Terms of service must clarify that TradeX is not a registered investment advisor, broker-dealer, or financial fiduciary.
- Because journal notes, strategies, and discussion posts represent user-generated content, terms must outline acceptable use, moderation processes, and content removal protocols.
- The MVP excludes direct brokerage execution and transaction processing, keeping the product outside broker-dealer licensing requirements.
- Enterprise agreements will provide dedicated data-processing terms covering organizational visibility into team activity.

## 8. Content moderation and user protection
- The platform provides reporting, blocking, and muting tools across community feeds and direct messaging.
- Direct messaging blocks use mutual database enforcement via the `blocks` table, preventing communication immediately in both directions.
- Media uploads via Supabase Storage enforce file type restrictions and size limits on the server before storage.

## 9. Incident response protocol
- Sentry alerts flag abnormal edge function error spikes and client crashes.
- In the event of a secret leak, rotate credentials immediately, redeploy edge functions, and inspect `ai_insight_requests` logs for anomalous volume.
- If an authorization defect occurs in production, patch row-level security policies immediately, then audit query logs to assess whether private strategies or trades experienced unauthorized exposure.
