# TradeX Database

Source references:
- 02-architecture/API_DATA_MODEL.md
- 02-architecture/DATABASE_ERD.md
- 01-product/PRD.md
- [docs_/LINKED_NOTES_BACKEND_HANDOFF.md](../docs_/LINKED_NOTES_BACKEND_HANDOFF.md) — the contract behind migrations 009–012

This folder provides the Supabase database setup for TradeX.

## Folder Layout

- migrations/: ordered migrations
- seeds/: optional seed data
- schema.sql: canonical full schema (tables, views, indexes, triggers, helper functions)
- rls_policies.sql: row-level security policies, for tables **and** `storage.objects`
- erd.dbml: DBML ERD source

`schema.sql` and `migrations/` describe the same database two ways: the first is
where it should end up, the second is how an existing deployment gets there.
They must be edited together — a column added to one and not the other means a
fresh project and an upgraded project stop agreeing.

## Migrations

| File | What it does |
|---|---|
| `001_extensions_enums.sql` | `pgcrypto`, `citext` |
| `002_core_auth_profiles.sql` | `profiles` and the account core |
| `003_affiliates_and_auth_triggers.sql` | affiliate tables, the `auth.users` signup trigger |
| `006_subscriptions_enterprise.sql` | `subscriptions`, tier columns |
| `007_trader_notes.sql` | `trader_notes` + `trader_note_attachments` |
| `008_trader_note_engagement.sql` | likes, comments, views, the count-refresh trigger |
| `009_journal_notes.sql` | brings `journal_entries` up to `AppJournalEntry`; adds `journal_entry_attachments`; **changes `journal_entries.strategy_id` to ON DELETE SET NULL** |
| `010_strategy_notes.sql` | brings `strategies`/`strategy_versions` up to `AppStrategy`; `content` JSONB → TEXT; adds `strategy_attachments` |
| `011_note_link_graph.sql` | `note_journal_links` + the four mirror-rebuilding triggers |
| `012_linked_notes_reads.sql` | `strategy_performance` view, `public_document()` and its two helpers |
| `016_post_writing_attachments.sql` | prepares posts for one optional public note, journal entry, or strategy attachment |
| `017_ai_assistant.sql` | `ai_threads`, `ai_messages`, `ai_chart_setups`, `ai_insights`, `ai_quotas` |
| `018_messages_realtime.sql` | `chat_threads`, `chat_participants`, `chat_messages`, `chat_attachments`, `chat_shared_refs`, `chat_reactions`, `chat_user_presence`, Realtime publication |
| `019_community.sql` | `community_posts`, `community_post_trade_setups`, `community_post_attachments`, `community_comments`, `community_likes`, `community_bookmarks`, `community_reposts`, `community_follows`, `community_polls`, `community_poll_votes` |
| `020_universal_link_graph.sql` | `universal_link_edges`, symmetric bidirectional linking procedures (`create_universal_link`, `delete_universal_link`, `get_universal_links`) |
| `021_unified_comments_and_visibility.sql` | `unified_comments`, `unified_comment_likes`, public/private visibility columns & RPCs (`set_entity_visibility`, `add_entity_comment`, `toggle_entity_comment_like`) |
| `023_public_site_and_market_assets.sql` | published landing/pricing JSON contracts, full stock details, read policies |
| `024_market_screener_snapshots.sql` | complete screener payloads linked to ranked categories, authenticated read policy |
| `025_entity_ticker_links.sql` | `entity_ticker_links`, persistent relational ticker reference table across Notes, Journal, Strategies, Community, and Messages with daily sync stability and stored RPCs |
| `026_affiliate_workspace.sql` | partner campaigns/assets, read RPC, payout reservation/settlement, attribution, secured application reviews; see [affiliate handoff](../backend_handoff/16-Affiliate_Workspace/README.md) |
| `038_community_ownership_and_block_rules.sql` | community post/comment RLS hardening for blocked users, author-enforced update/delete policies, and profiles column alignment |

Two steps in that list are not additive and are worth reading before you run
them: 010 rewrites `strategies.content` from JSONB to TEXT (a playbook is
markdown, not structured data), and 011 seeds `note_journal_links` from the
`trader_notes.linked_journal_ids` array **before** installing the triggers that
make that array derived. Skipping the seed silently deletes every link a trader
already made.

Several CHECK constraints in 009 and 010 are added `NOT VALID` on purpose: they
constrain everything written from now on without failing the migration on rows
that predate it. Clean the old rows, then `VALIDATE CONSTRAINT` at your leisure.

## News article schema

`schema.sql` uses the main-branch news schema: `news_articles.id` is a
serial integer and the article URL is stored in `link`. The Python fetchers,
`news_article_tickers`, `news_article_topics`, `news_tickers`, and
`news_bookmarks` all use that same article table and integer ID.
`backend_handoff/04-News/tables.sql` mirrors this definition.

These files define the merged source; merging Git branches does not apply SQL
to a deployed database. An existing deployment with UUID article IDs needs a
separate data migration that preserves its articles and references before this
schema is applied.

## Run Order

1. Apply migrations in numeric order.
2. Apply rls_policies.sql.
3. Apply seeds (optional for local/dev).

## Step-by-Step Setup

1. Create or open your Supabase project.
2. Open the SQL editor in Supabase.
3. Run [database/schema.sql](schema.sql) to create the full schema in one shot, or run the files in `migrations/` in order if you prefer incremental rollout.
4. Create the three private storage buckets — `note-attachments`, `journal-attachments`, `strategy-attachments` — before step 5. The storage policies at the bottom of `rls_policies.sql` reference them by name.
5. Run [database/rls_policies.sql](rls_policies.sql) to enable all row-level security rules. It ends with a second transaction covering `storage.objects`; run it from the dashboard SQL editor, which connects as `postgres`. A role that cannot create policies on `storage.objects` will fail that block only — the table policies above it are already committed.
6. Run [database/seeds/01_reference_data.sql](seeds/01_reference_data.sql) if you want minimal reference data.
7. Run [database/seeds/02_demo_data.sql](seeds/02_demo_data.sql) only after replacing the sample UUIDs with real `auth.users` IDs.
8. Verify the tables in Supabase Studio and test one private table, one public table, and one DM insert path.
9. Smoke-test the public read path as `anon`: `select public_document('strategy', '<id of a private playbook>')` must return `NULL`, and the same call against a public one must come back without either mirror array in it.

## Important

- Do not use local PostgreSQL for this setup.
- This schema depends on Supabase features like `auth.users`, `auth.uid()` and `storage.objects`.
- If you need to test locally, use Supabase locally instead of plain PostgreSQL.

## Hand-Drawn Table Map

```text
auth.users
  -> profiles
       -> subscriptions (1:1)
       -> affiliate_profiles (1:1) -> affiliate_referrals, affiliate_payouts
       -> device_tokens (1:N)
       -> strategies (1:N) -> strategy_versions (1:N)
       |                   -> strategy_attachments (1:N)
       -> journal_entries (1:N) -> journal_entry_links (self-link graph)
       |                        -> journal_entry_attachments (1:N)
       -> trader_notes (1:N) -> trader_note_attachments (1:N)
       -> watchlists (1:N) -> watchlist_items (1:N)
       -> posts (1:N) -> comments, likes, saved_posts
       -> follows (self relation)
       -> blocks (self relation)
       -> conversations (as user_a/user_b) -> messages
       -> notifications (1:N)
       -> ai_insight_requests (1:N)

The link graph — three edge types, readable from both ends:

  trader_notes  <--- note_journal_links ---> journal_entries   many-to-many
  journal_entries.strategy_id -------------> strategies        many-to-one
  trader_notes.strategy_id ----------------> strategies        many-to-one

  Tickers own no record: `linked_tickers` is a text[] on both parents, not a
  table. There is no note <-> note edge either — related notes are derived from
  shared tags at read time.

  The join table and the two strategy_id columns are the truth. The four
  linked_*_ids arrays are mirrors, rebuilt by trigger, never written by a client.

ai_insights (shared cache by ticker)
revenuecat_webhook_events (idempotency log)
portfolio_stats (view over journal_entries)
strategy_performance (view: playbook figures derived from the trades filed under it)
public_document(kind, id) (SECURITY DEFINER: the only door an anon reader has)
```

## Field Usage Notes

- profiles: public/private account profile + tier copy for fast RLS checks.
- subscriptions: billing source of truth from RevenueCat webhook.
- journal_entries: a trade **and** its write-up, in one row. Never two. Performance columns (`pnl`, `r_multiple`, `outcome`) are per-trade facts; the playbook-level figures derived from them are not stored anywhere. See [docs_/LINKED_NOTES_BACKEND_HANDOFF.md](../docs_/LINKED_NOTES_BACKEND_HANDOFF.md).
- journal_entry_attachments: media embedded in a journal body. Owner-only at every depth — there is no public journal route, so there is no reader to grant.
- note_journal_links: the note ⇄ journal edge, and its source of truth. `user_id` is denormalised onto the row so the RLS check is one comparison; it is assigned by trigger and a client-supplied value is discarded. Cross-owner edges are rejected before the row lands.
- trader_notes/trader_note_attachments/trader_note_likes/trader_note_comments/trader_note_views: markdown notes with uploaded media and public engagement. Available to every role; public notes are readable and interactable by signed-in users. See [docs_/NOTES_BACKEND_HANDOFF.md](../docs_/NOTES_BACKEND_HANDOFF.md).
- strategies/strategy_versions: playbooks as markdown, with version history. Exactly one version per playbook may carry `is_current` — enforced by a partial unique index, not by application code.
- strategy_attachments: diagrams and charts embedded in a playbook body. Travel with a published playbook, or it renders with broken images for every reader but its author.
- watchlists/watchlist_items: ticker tracking with threshold alert state.
- posts/comments/likes/saved_posts/follows: social graph + community feed.
- conversations/messages: one-on-one direct messages with trigger-driven notifications.
- notifications: unified in-app notification center.
- ai_insights/ai_insight_requests: AI cache + request/rate-limit audit trail.
- revenuecat_webhook_events: webhook dedupe guard.

## FK Behavior

Most foreign keys are ON DELETE CASCADE / ON UPDATE CASCADE. Three deliberate
exceptions, each because a delete should orphan a row rather than destroy it:

| Column | Behavior | Why |
|---|---|---|
| `trader_notes.strategy_id` | SET NULL | Retiring a strategy must not delete the note explaining why. |
| `journal_entries.strategy_id` | SET NULL | Deleting a playbook unfiles its trades; it does not erase the trader's record of them. |
| `strategy_versions.author_id` | SET NULL | Losing the author must not lose the revision. |

`journal_entries.strategy_id` was CASCADE before migration 009. If you applied
an earlier version of this schema, 009 drops and re-adds that constraint — check
it landed before trusting a strategy delete.

## Storage Buckets

Three private buckets. Every object key is `<user_id>/<parent_id>/<uuid><ext>`,
which is what lets the owner policies in `rls_policies.sql` be prefix matches on
`storage.foldername(name)` instead of joins back to the parent table.

| Bucket | Holds | Public read |
|---|---|---|
| `note-attachments` | media embedded in `trader_notes.content` | yes, where the note `is_public` |
| `journal-attachments` | media embedded in `journal_entries.content` | **never** |
| `strategy-attachments` | media embedded in `strategies.content` | yes, where the strategy `visibility = 'public'` |

10 MB per object; `image/*`, `application/pdf`, `text/*`. Reads go through 1 hour
signed URLs, and the object key is the `storage_path` column on the matching
attachment table.

Granting the attachment *row* to a visitor is not enough on its own:
`createSignedUrl` checks `storage.objects` RLS for the caller, so a reader with
row access and no object access gets a row, a request, and a 403. That is why
both a row policy and an object policy exist for each public bucket.

## RLS Behavior

- Owner-only access for private entities (journal, strategy drafts, watchlists, DMs, notes).
- Public-read for profiles/posts/comments, public strategies, and notes with `is_public = true` (plus their attachment rows, so shared notes are not full of broken images).
- Tier-gated insert policies for conversations/messages.
- Service-role-only tables for webhook + AI request logs.
- `storage.objects` policies live at the bottom of `rls_policies.sql`, in their own transaction, because that table is owned by `supabase_admin` and a privilege failure there must not roll back the table policies above it.
- An unauthenticated reader is served by `public_document()`, not by a policy. RLS is row-level and cannot hide a column, so a policy alone would hand a visitor both mirror arrays — the cardinality of a trader's private workspace. The function's projected column list is the boundary, and there is no second check behind it.

## Refreshed finance assets and public pricing

After installing the schema/migrations, apply `seeds/03_public_site.sql` and
`seeds/04_pricing_catalogue.sql`. The latter publishes the current Free, Pro,
and Business plans, including the four server-enforced quota limits. The app
reads published pricing from Supabase; the bundled JSON is a development/demo
fixture and an admin editor starting point.

`assets/data/manifest.json` reports actual quote, history, detail, article and
category coverage. `scripts/source_kits.json` records the source archives.
`python3 scripts/validate_asset_sql.py` checks repeatability in temporary Postgres.
See `backend_handoff/07-Markets` and `13-Public_Site` for repository/read contracts.
Configured clients fail visibly if the published Supabase pricing row is absent
or unavailable, instead of presenting fixture prices as a live offer.
