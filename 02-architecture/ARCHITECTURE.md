# Architecture Document — TraderHub

### 1. Stack Summary
| Layer | Choice | Why |
|---|---|---|
| Client | Flutter (iOS/Android/Web/Desktop) | Single codebase, mature ecosystem |
| State mgmt | Riverpod (+ riverpod_generator) | Low boilerplate, testable, AI-tooling friendly |
| Routing | go_router | Deep linking, standard in Flutter |
| Backend | Supabase (Postgres, Auth, Realtime, Storage, Edge Functions) | Relational data + Row-Level Security fits mixed social/financial data |
| HTTP client | dio | Interceptors, retries, cancellation |
| Models | freezed + json_serializable | Immutable, safe, codegen-friendly |
| Market data | Alpaca / Finnhub / Twelve Data (start free tier) | Cheap/free entry, swappable later — final choice still open, see BACKEND_README.md |
| AI layer | Claude API via Supabase Edge Function | Powers AI Trading Assistant, AI Strategy Review, AI Journal Analysis, weekly/monthly reviews, AI Q&A chat; key stays server-side, rate-limitable per tier |
| Screenshot parsing | Claude API (vision) via Supabase Edge Function | Reads uploaded trade/chart screenshots, extracts ticker/entry/exit/size/P&L to pre-fill journal entries |
| Rich text editor | `flutter_quill` (or similar delta-based editor) | Strategy Notes rich text + embedded images, delta format is diffable for version history |
| Graph rendering | `graphview` (Flutter package) or custom `CustomPainter` force-directed layout | Renders journal-entry-to-entry and entry-to-strategy/ticker graph client-side |
| Charting (Portfolio Dashboard) | `fl_chart` | Equity curve, monthly growth, win/loss distribution charts |
| Push notifications | Firebase Cloud Messaging (FCM) + APNs | Delivers market alerts, community updates, direct messages, strategy reminders, AI recommendations, subscription reminders |
| Payments | RevenueCat | Cross-platform subscription abstraction (Free/Premium); Enterprise billing scoped separately post-MVP |
| CI/CD | GitHub Actions | Free for public/private repos, native Flutter support |
| Crash/analytics | Sentry + PostHog (or Firebase Analytics) | Error visibility + product analytics |

### 2. High-Level Diagram (textual)
```
Flutter App (iOS/Android/Web/Desktop)
   |
   |-- Supabase Auth (JWT)
   |-- Supabase Postgres (RLS enforced) --- Realtime subscriptions (community feed, notifications, direct messages, price alerts)
   |-- Supabase Storage (avatars, post images, journal screenshots, strategy images)
   |-- Supabase Edge Function: /ai-insight
   |         -> calls Claude API (server-side key)
   |         -> calls Market Data API (Alpaca/Finnhub)
   |         -> writes result to `ai_insights` table (cached)
   |-- Supabase Edge Function: /analyze-screenshot
   |         -> calls Claude API (vision, server-side key)
   |         -> returns parsed {ticker, entry, exit, stop_loss, target, size, pnl} to pre-fill a journal entry
   |         -> client computes win/loss/breakeven from parsed P/L, user can override before save
   |-- Supabase Edge Function: /ai-strategy-review (Premium)
   |         -> calls Claude API on a strategy note's rich-text content
   |         -> returns clarity/consistency review + flagged ambiguous rules
   |-- Supabase Edge Function: /ai-journal-analysis (Premium)
   |         -> calls Claude API across a user's journal entries (or a single entry, for Trade Review)
   |         -> returns pattern summary: recurring mistakes, psychology trends, tag/outcome correlations
   |-- Supabase Edge Function: /strategy-ai-summary (Premium)
   |         -> calls Claude API on a strategy note, triggered on save
   |         -> writes summary back onto the strategy record
   |-- Supabase Edge Function: /ai-chat (Premium)
   |         -> calls Claude API, conversational, scoped to a ticker/watchlist/portfolio
   |-- Supabase Edge Function: /price-alerts (scheduled)
   |         -> checks watchlist_items thresholds against market data
   |         -> writes to `notifications` table, pushes via FCM/APNs
   |-- Supabase Edge Function: /revenuecat-webhook
   |         -> verifies RevenueCat signature, syncs `subscriptions` / `profiles.subscription_tier`
   |-- Postgres trigger: notify_new_message
   |         -> fires on `messages` insert, writes a `notifications` row for the recipient
   |-- Direct Messages (`conversations` / `messages`) — client reads/writes directly via
   |         RLS-gated PostgREST + Realtime, no dedicated Edge Function (API_REFERENCE.md § 1)
   |-- RevenueCat SDK -> App Store / Play / Stripe
```

### 3. Folder Structure
```
lib/
  core/
    config/            # env, constants, theme
    network/           # dio client, interceptors
    router/            # go_router setup
    widgets/           # shared widgets
  features/
    auth/
      data/ domain/ presentation/
    journal/             # Trading Journal (formerly "notes")
      data/ domain/ presentation/
    strategies/           # Strategy Notes editor, version history, analyzer, graph view
      data/ domain/ presentation/
    watchlists/            # watchlists, price alerts, categories, favorites
      data/ domain/ presentation/
    portfolio/               # Portfolio Dashboard: stats, breakdowns, charts
      data/ domain/ presentation/
    community/               # public social feed (renamed from "feed"): posts, comments, saves, content types
      data/ domain/ presentation/
    messages/                 # Direct Messages: conversations list, chat thread, real-time
      data/ domain/ presentation/
    insights/              # AI Trading Assistant, ticker charts/indicators, chat
      data/ domain/ presentation/
    notifications/           # notification center, per-category prefs
      data/ domain/ presentation/
    subscriptions/
      data/ domain/ presentation/
    enterprise/             # post-MVP: org/team management, admin controls (see ROADMAP.md)
      data/ domain/ presentation/
  main.dart
supabase/
  migrations/          # SQL migration files
  functions/
    ai-insight/                # Edge Function (Deno/TS)
    analyze-screenshot/        # Edge Function (Deno/TS) — vision parsing for trade screenshots
    ai-strategy-review/        # Edge Function (Deno/TS) — Premium
    ai-journal-analysis/       # Edge Function (Deno/TS) — Premium, also powers Trade Review (single-entry mode)
    strategy-ai-summary/       # Edge Function (Deno/TS) — Premium
    ai-chat/                    # Edge Function (Deno/TS) — Premium, AI Q&A / chat
    price-alerts/               # Edge Function (Deno/TS) — scheduled
    revenuecat-webhook/          # Edge Function (Deno/TS) — subscription tier sync
test/
  features/...          # mirrors lib/features structure
```

### 4. Data Model (core tables)
- `profiles` (id, handle, bio, avatar_url, experience_level, trading_style, public_journals, subscription_tier, created_at)
- `subscriptions` (user_id, tier, status, revenuecat_id, billing_cycle, renewed_at, expires_at) — source of truth for billing, synced from RevenueCat; `profiles.subscription_tier` is a denormalized read copy
- `device_tokens` (id, user_id, token, platform) — push notification delivery targets
- `journal_entries` (id, user_id, ticker, content, entry_price, exit_price, stop_loss, target, size, side, pnl, screenshots text[], psychology, mistakes_made, lessons_learned, strategy_id, outcome, outcome_source, tags text[], is_public, created_at, updated_at)
- `strategies` (id, user_id, title, content, category, is_favorite, visibility, ai_summary, created_at, updated_at)
- `strategy_versions` (id, strategy_id, content, version_number, created_at) — version history for Strategy Notes
- `journal_entry_links` (id, source_entry_id, target_entry_id, created_at) — entry-to-entry graph edges
- `watchlists` (id, user_id, name, created_at)
- `watchlist_items` (id, watchlist_id, ticker, notes, category, price_alert_threshold, price_alert_direction, alert_armed, alert_last_triggered_at, is_favorite, created_at)
- `posts` (id, user_id, content, image_url, ticker, content_type, created_at)
- `saved_posts` (user_id, post_id, created_at) — private bookmarks, distinct from likes
- `comments` (id, post_id, user_id, content, created_at)
- `follows` (follower_id, followee_id)
- `likes` (user_id, post_id)
- `conversations` (id, user_a_id, user_b_id, last_message_at, created_at) — one-on-one Direct Messages, Premium+ only
- `messages` (id, conversation_id, sender_id, content, read_at, created_at)
- `notifications` (id, user_id, category, title, body, deep_link, read_at, created_at)
- `ai_insights` (id, ticker, summary, indicators jsonb, generated_at) — cached, TTL-based refresh
- `ai_insight_requests` (id, user_id, kind, ticker, requested_at) — rate-limit audit log across all AI features
- `revenuecat_webhook_events` (event_id, event_type, processed_at) — webhook idempotency log
- `portfolio_stats` — view (not a table), aggregates `journal_entries` per user for the Portfolio Dashboard
- *(post-MVP, Enterprise)* `organizations`, `organization_members`, `api_keys` — see ROADMAP.md

Renamed from earlier draft: `notes` → `journal_entries`, to keep the Trading Journal and Strategy Notes clearly distinct entities now that Strategy Notes are first-class rich documents rather than a tag. Full DDL, RLS policies, and Edge Function contracts: API_DATA_MODEL.md.

### 5. Security Notes
- RLS: `journal_entries` are `user_id = auth.uid()` only, except opted-in public entries; `strategies` are owner-only unless `visibility = 'public'` (then public read-only); posts/comments public-read, owner-write; `notifications`, `saved_posts`, and `device_tokens` are owner-only; `conversations`/`messages` are readable by both participants but **sending requires an active Premium/Enterprise subscription, checked on every insert** (API_DATA_MODEL.md § 2) — the one table where RLS enforces a subscription-tier gate rather than a plain ownership check
- Claude API key and market-data API key live only in Supabase Edge Function secrets — never shipped in the client
- Rate limit AI-calling functions per user per subscription tier (e.g. Free: 0/day across all AI features, Premium: unlimited/high-cap per feature); Direct Messages has no separate rate limit beyond the tier gate itself, since sending isn't a metered AI call
- Enterprise multi-tenant isolation (org-scoped RLS) is a design item for the post-MVP phase — flagged in ROADMAP.md, not yet specced

### 6. Environments
- `dev` — local Supabase (via Supabase CLI) + local `.env`
- `staging` — Supabase project #1, TestFlight/Internal track builds
- `prod` — Supabase project #2, store releases

### 7. Why not Firebase?
Firestore's document model makes relational queries (followers-of-followers, joined feed queries, RLS-style per-row security) harder to express cleanly than Postgres + RLS. Supabase gives SQL, RLS, and Realtime in one, better suited to this data shape.
