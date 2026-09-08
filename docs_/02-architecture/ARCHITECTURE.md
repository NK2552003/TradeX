# TradeX architecture

### 1. Stack summary
| Layer | Choice | Rationale |
|---|---|---|
| Client | Flutter (iOS, Android, Web, Desktop) | Single codebase across platforms with an established ecosystem |
| State management | Riverpod (with riverpod_generator) | Testable, minimal boilerplate, and consistent code generation |
| Routing | go_router | Standard Flutter solution with built-in deep linking support |
| Backend | Supabase (Postgres, Auth, Realtime, Storage, Edge Functions) | Relational modeling and row-level security fit financial and social data |
| HTTP client | dio | Interceptors, automated retries, and request cancellation |
| Models | freezed and json_serializable | Immutable data models with safe serialization |
| Market data | Alpaca, Finnhub, or Twelve Data | Low-cost entry point that can be swapped later; evaluation notes are in [BACKEND_README.md](./BACKEND_README.md) |
| AI features | Claude API via Supabase Edge Functions | Runs trading assistant, strategy reviews, journal analysis, and conversational Q&A; keys stay on the server with per-tier limits |
| Screenshot parsing | Claude API (vision) via Supabase Edge Functions | Parses trade and chart screenshots to extract ticker, entry, exit, position size, and P/L for journal pre-filling |
| Rich text editor | `flutter_quill` (or delta-based alternative) | Rich text formatting and embedded images for strategy notes; delta format supports version diffs |
| Graph visualization | `graphview` package or custom `CustomPainter` layout | Renders client-side relationship graphs between journal entries, strategies, and tickers |
| Charting (Portfolio dashboard) | `fl_chart` | Equity curves, monthly growth charts, and win/loss distributions |
| Push notifications | Firebase Cloud Messaging (FCM) and APNs | Delivers price alerts, social notifications, direct messages, and system reminders |
| Payments | RevenueCat | Manages cross-platform in-app subscriptions (Free and Premium); Enterprise billing is scheduled post-MVP |
| CI/CD | GitHub Actions | Automated build and test pipeline with native Flutter support |
| Monitoring and analytics | Sentry and PostHog (or Firebase Analytics) | Application error tracking and product usage analytics |

### 2. High-level system diagram
```
Flutter App (iOS, Android, Web, Desktop)
   |
   |-- Supabase Auth (JWT)
   |-- Supabase Postgres (RLS enforced) --- Realtime subscriptions (community feed, notifications, direct messages, price alerts)
   |-- Supabase Storage (avatars, post images, journal screenshots, strategy images)
   |-- Supabase Edge Function: /ai-insight
   |         -> calls Claude API (server-side key)
   |         -> calls Market Data API (Alpaca or Finnhub)
   |         -> writes result to `ai_insights` table (cached)
   |-- Supabase Edge Function: /analyze-screenshot
   |         -> calls Claude API (vision, server-side key)
   |         -> returns parsed {ticker, entry, exit, stop_loss, target, size, pnl} to pre-fill a journal entry
   |         -> client computes win, loss, or breakeven from parsed P/L, user can override before save
   |-- Supabase Edge Function: /ai-strategy-review (Premium)
   |         -> calls Claude API on a strategy note's rich text content
   |         -> returns clarity review and flags ambiguous rules
   |-- Supabase Edge Function: /ai-journal-analysis (Premium)
   |         -> calls Claude API across a user's journal entries (or a single entry for trade review)
   |         -> returns recurring pattern summary: mistakes, psychological factors, tag correlations
   |-- Supabase Edge Function: /strategy-ai-summary (Premium)
   |         -> calls Claude API on a strategy note, triggered on save
   |         -> writes summary back to the strategy record
   |-- Supabase Edge Function: /ai-chat (Premium)
   |         -> calls Claude API for conversational Q&A scoped to a ticker, watchlist, or portfolio
   |-- Supabase Edge Function: /price-alerts (scheduled)
   |         -> checks watchlist_items thresholds against market data
   |         -> writes to `notifications` table, pushes via FCM/APNs
   |-- Supabase Edge Function: /revenuecat-webhook
   |         -> verifies RevenueCat signature, syncs `subscriptions` and `profiles.subscription_tier`
   |-- Postgres trigger: notify_new_message
   |         -> fires on `messages` insert, writes a `notifications` row for the recipient
   |-- Direct Messages (`conversations` / `messages`): client reads and writes directly via
   |         RLS-gated PostgREST and Realtime, without a dedicated Edge Function (API_REFERENCE.md § 1)
   |-- RevenueCat SDK -> App Store, Google Play, Stripe
```

### 3. Folder structure
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
    journal/             # Trading Journal
      data/ domain/ presentation/
    strategies/           # Strategy Notes editor, version history, analyzer, graph view
      data/ domain/ presentation/
    watchlists/            # watchlists, price alerts, categories, favorites
      data/ domain/ presentation/
    portfolio/               # Portfolio Dashboard: stats, breakdowns, charts
      data/ domain/ presentation/
    community/               # public social feed: posts, comments, saves, content types
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
    analyze-screenshot/        # Edge Function (Deno/TS), vision parsing for trade screenshots
    ai-strategy-review/        # Edge Function (Deno/TS), Premium
    ai-journal-analysis/       # Edge Function (Deno/TS), Premium, also powers Trade Review
    strategy-ai-summary/       # Edge Function (Deno/TS), Premium
    ai-chat/                    # Edge Function (Deno/TS), Premium, AI Q&A / chat
    price-alerts/               # Edge Function (Deno/TS), scheduled
    revenuecat-webhook/          # Edge Function (Deno/TS), subscription tier sync
test/
  features/...          # mirrors lib/features structure
```

### 4. Data model (core tables)
- `profiles` (id, handle, bio, avatar_url, experience_level, trading_style, public_journals, subscription_tier, created_at)
- `subscriptions` (user_id, tier, status, revenuecat_id, billing_cycle, renewed_at, expires_at): billing source of truth synced from RevenueCat; `profiles.subscription_tier` is a denormalized read copy.
- `device_tokens` (id, user_id, token, platform): push notification delivery targets.
- `journal_entries` (id, user_id, ticker, content, entry_price, exit_price, stop_loss, target, size, side, pnl, screenshots text[], psychology, mistakes_made, lessons_learned, strategy_id, outcome, outcome_source, tags text[], is_public, created_at, updated_at)
- `strategies` (id, user_id, title, content, category, is_favorite, visibility, ai_summary, created_at, updated_at)
- `strategy_versions` (id, strategy_id, content, version_number, created_at): version history for Strategy Notes.
- `journal_entry_links` (id, source_entry_id, target_entry_id, created_at): entry-to-entry graph edges.
- `watchlists` (id, user_id, name, created_at)
- `watchlist_items` (id, watchlist_id, ticker, notes, category, price_alert_threshold, price_alert_direction, alert_armed, alert_last_triggered_at, is_favorite, created_at)
- `posts` (id, user_id, content, image_url, ticker, content_type, created_at)
- `saved_posts` (user_id, post_id, created_at): private bookmarks, distinct from likes.
- `comments` (id, post_id, user_id, content, created_at)
- `follows` (follower_id, followee_id)
- `likes` (user_id, post_id)
- `conversations` (id, user_a_id, user_b_id, last_message_at, created_at): direct messages between two users (requires Premium or Enterprise tier).
- `messages` (id, conversation_id, sender_id, content, read_at, created_at)
- `notifications` (id, user_id, category, title, body, deep_link, read_at, created_at)
- `ai_insights` (id, ticker, summary, indicators jsonb, generated_at): cached data with TTL-based refresh.
- `ai_insight_requests` (id, user_id, kind, ticker, requested_at): audit log tracking rate limits across AI endpoints.
- `revenuecat_webhook_events` (event_id, event_type, processed_at): webhook idempotency log.
- `portfolio_stats`: view aggregating `journal_entries` per user for the portfolio dashboard.
- Post-MVP tables (Enterprise): `organizations`, `organization_members`, `api_keys` (see ROADMAP.md).

`journal_entries` stores trade logs, keeping the Trading Journal separate from `strategies` (rich strategy documents). For schema definitions, RLS policies, and Edge Function specifications, refer to [API_DATA_MODEL.md](./API_DATA_MODEL.md).

### 5. Security notes
- Row-level security: `journal_entries` restricts access to `user_id = auth.uid()`, with an exception for entries marked public. `strategies` are restricted to the owner unless `visibility = 'public'`, which allows read-only public access. Posts and comments are readable by all users and editable only by the author. `notifications`, `saved_posts`, and `device_tokens` are strictly owner-accessible. `conversations` and `messages` are readable by both participants, but creating messages requires an active Premium or Enterprise tier, verified on each insert (see [API_DATA_MODEL.md](./API_DATA_MODEL.md)).
- API credentials: the Claude API key and market data credentials live exclusively in Supabase Edge Function secrets. Client builds never include these keys.
- Rate limiting: AI Edge Functions enforce per-user request limits based on subscription tier (for example, 0 per day on Free, high caps on Premium). Direct messages do not need an artificial rate limit beyond the subscription gate itself.
- Multi-tenancy: organization-scoped RLS policies for Enterprise accounts are planned for the post-MVP release, as outlined in ROADMAP.md.

### 6. Environments
- `dev`: local Supabase instance running via the Supabase CLI with local `.env`.
- `staging`: first hosted Supabase project, targeting TestFlight and internal testing tracks.
- `prod`: production Supabase project for public app store releases.

### 7. Why Supabase instead of Firebase
Firestore uses a document model that makes relational queries awkward, particularly multi-hop user relationships, joined feeds, and row-level authorization rules. Supabase combines PostgreSQL, row-level security, and realtime subscriptions in a single service, which aligns directly with the relational requirements of trading journals and community data.
