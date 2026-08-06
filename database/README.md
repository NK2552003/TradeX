# TraderHub Database

Source references:
- 02-architecture/API_DATA_MODEL.md
- 02-architecture/DATABASE_ERD.md
- 01-product/PRD.md

This folder provides the Supabase database setup for TraderHub.

## Folder Layout

- migrations/: ordered migrations
- seeds/: optional seed data
- schema.sql: canonical full schema (tables, view, indexes, triggers, helper functions)
- rls_policies.sql: row-level security policies
- erd.dbml: DBML ERD source

## Run Order

1. Apply migrations in numeric order.
2. Apply rls_policies.sql.
3. Apply seeds (optional for local/dev).

## Step-by-Step Setup

1. Create or open your Supabase project.
2. Open the SQL editor in Supabase.
3. Run [database/schema.sql](schema.sql) to create the full schema in one shot, or run the files in `migrations/` in order if you prefer incremental rollout.
4. Run [database/rls_policies.sql](rls_policies.sql) to enable all row-level security rules.
5. Run [database/seeds/01_reference_data.sql](seeds/01_reference_data.sql) if you want minimal reference data.
6. Run [database/seeds/02_demo_data.sql](seeds/02_demo_data.sql) only after replacing the sample UUIDs with real `auth.users` IDs.
7. Verify the tables in Supabase Studio and test one private table, one public table, and one DM insert path.

## Important

- Do not use local PostgreSQL for this setup.
- This schema depends on Supabase features like `auth.users` and `auth.uid()`.
- If you need to test locally, use Supabase locally instead of plain PostgreSQL.

## Hand-Drawn Table Map

```text
auth.users
  -> profiles
       -> subscriptions (1:1)
       -> device_tokens (1:N)
       -> strategies (1:N) -> strategy_versions (1:N)
       -> journal_entries (1:N) -> journal_entry_links (self-link graph)
       -> watchlists (1:N) -> watchlist_items (1:N)
       -> posts (1:N) -> comments, likes, saved_posts
       -> follows (self relation)
       -> blocks (self relation)
       -> conversations (as user_a/user_b) -> messages
       -> notifications (1:N)
       -> ai_insight_requests (1:N)

ai_insights (shared cache by ticker)
revenuecat_webhook_events (idempotency log)
portfolio_stats (view over journal_entries)
```

## Field Usage Notes

- profiles: public/private account profile + tier copy for fast RLS checks.
- subscriptions: billing source of truth from RevenueCat webhook.
- journal_entries: core trade journal records with outcome + strategy links.
- strategies/strategy_versions: rich strategy docs and version history.
- watchlists/watchlist_items: ticker tracking with threshold alert state.
- posts/comments/likes/saved_posts/follows: social graph + community feed.
- conversations/messages: one-on-one direct messages with trigger-driven notifications.
- notifications: unified in-app notification center.
- ai_insights/ai_insight_requests: AI cache + request/rate-limit audit trail.
- revenuecat_webhook_events: webhook dedupe guard.

## FK Behavior

All foreign keys are explicitly configured with:
- ON DELETE CASCADE
- ON UPDATE CASCADE

## RLS Behavior

- Owner-only access for private entities (journal, strategy drafts, watchlists, DMs).
- Public-read for profiles/posts/comments and public strategies.
- Tier-gated insert policies for conversations/messages.
- Service-role-only tables for webhook + AI request logs.
