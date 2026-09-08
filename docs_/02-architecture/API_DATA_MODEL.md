# API & Data Model Specification

### 1. Database Schema (Postgres / Supabase)

```sql
-- profiles
create table profiles (
  id uuid references auth.users primary key,
  handle text unique not null,
  bio text,
  avatar_url text,
  experience_level text, -- beginner | intermediate | advanced | pro
  trading_style text, -- free text, client offers a picker with suggested values (day_trading, swing, scalping, options, forex, crypto) but doesn't constrain the column itself; avoids a migration every time a new style needs adding
  public_journals boolean default false, -- opt-in: allow selected journal entries to show on public profile
  subscription_tier text default 'free', -- free | premium | enterprise (denormalized read copy; subscriptions table below is the source of truth)
  created_at timestamptz default now()
);

-- subscriptions (source of truth for billing state, synced from RevenueCat via the
-- revenuecat-webhook function, § 9 below; profiles.subscription_tier is a
-- read-optimized denormalized copy kept in sync by that same function)
create table subscriptions (
  user_id uuid references profiles(id) primary key,
  tier text not null default 'free', -- free | premium | enterprise
  status text not null default 'active', -- active | canceling | expired | billing_issue
  revenuecat_id text unique, -- RevenueCat's subscriber id, null for free tier
  billing_cycle text, -- monthly | annual | null for free
  renewed_at timestamptz,
  expires_at timestamptz, -- when access actually ends; still 'active' access through this date even if status='canceling'
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- device_tokens (push notification delivery targets; FCM/APNs)
create table device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) not null,
  token text not null,
  platform text not null, -- ios | android | web
  created_at timestamptz default now(),
  unique (user_id, token)
);

-- strategies (Strategy Notes: rich-document trading strategies)
create table strategies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) not null,
  title text not null,
  content jsonb not null, -- rich text delta (e.g. Quill delta), includes embedded image refs
  category text,
  is_favorite boolean default false,
  visibility text default 'private', -- private | public
  ai_summary text, -- Premium: Claude-generated summary, refreshed on save
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- strategy_versions (version history for Strategy Notes)
create table strategy_versions (
  id uuid primary key default gen_random_uuid(),
  strategy_id uuid references strategies(id) not null,
  content jsonb not null,
  version_number integer not null,
  created_at timestamptz default now(),
  unique (strategy_id, version_number)
);

-- journal_entries (private trading journal; formerly "notes")
create table journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) not null,
  ticker text,
  content text not null, -- free-text notes
  entry_price numeric,
  exit_price numeric,
  stop_loss numeric,
  target numeric,
  size numeric,
  side text, -- long | short
  pnl numeric,
  screenshots text[], -- one or more screenshot URLs
  psychology text, -- how the trader felt / what drove the decision
  mistakes_made text,
  lessons_learned text,
  strategy_id uuid references strategies(id), -- nullable: "Strategy used"
  outcome text, -- 'win' | 'loss' | 'breakeven' | null; auto-set from pnl, user-overridable
  outcome_source text default 'auto', -- 'auto' | 'manual'
  tags text[],
  is_public boolean default false, -- opt-in per entry; only surfaced on profile if profiles.public_journals is also true
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- journal_entry_links (explicit entry-to-entry graph edges; entry-to-strategy/ticker
-- edges are derived from journal_entries.strategy_id / journal_entries.ticker, not stored)
create table journal_entry_links (
  id uuid primary key default gen_random_uuid(),
  source_entry_id uuid references journal_entries(id) not null,
  target_entry_id uuid references journal_entries(id) not null,
  created_at timestamptz default now(),
  unique (source_entry_id, target_entry_id),
  check (source_entry_id != target_entry_id) -- prevent accidental self-links
);

-- watchlists
create table watchlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) not null,
  name text not null,
  created_at timestamptz default now()
);

-- watchlist_items
create table watchlist_items (
  id uuid primary key default gen_random_uuid(),
  watchlist_id uuid references watchlists(id) not null,
  ticker text not null,
  notes text,
  category text,
  price_alert_threshold numeric,
  price_alert_direction text, -- 'above' | 'below', required if price_alert_threshold is set
  alert_armed boolean default true, -- false right after firing; re-armed once price moves back past a buffer zone (BACKGROUND_JOBS.md § 3)
  alert_last_triggered_at timestamptz,
  is_favorite boolean default false,
  created_at timestamptz default now(),
  unique (watchlist_id, ticker)
);

-- posts (public social feed)
create table posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) not null,
  content text not null,
  image_url text,
  ticker text,
  content_type text default 'market_discussion', -- trade_analysis | educational | psychology | strategy | news | market_discussion
  created_at timestamptz default now()
);

-- saved_posts (private bookmarks, distinct from likes)
create table saved_posts (
  user_id uuid references profiles(id) not null,
  post_id uuid references posts(id) not null,
  created_at timestamptz default now(),
  primary key (user_id, post_id)
);

-- comments
create table comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references posts(id) not null,
  user_id uuid references profiles(id) not null,
  content text not null,
  created_at timestamptz default now()
);

-- follows
create table follows (
  follower_id uuid references profiles(id) not null,
  followee_id uuid references profiles(id) not null,
  created_at timestamptz default now(),
  primary key (follower_id, followee_id)
);

-- likes
create table likes (
  user_id uuid references profiles(id) not null,
  post_id uuid references posts(id) not null,
  created_at timestamptz default now(),
  primary key (user_id, post_id)
);

-- ai_insights (cached AI-generated summaries)
create table ai_insights (
  id uuid primary key default gen_random_uuid(),
  ticker text not null,
  summary text not null,
  indicators jsonb,
  generated_at timestamptz default now()
);

-- ai_insight_requests (rate limiting/audit log; `kind` distinguishes AI feature)
create table ai_insight_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) not null,
  kind text not null default 'ai_insight', -- ai_insight | screenshot_analysis | strategy_review | journal_analysis | strategy_summary | chat
  ticker text,
  requested_at timestamptz default now()
);


-- blocks (user-to-user blocking; was previously a described feature with no backing
-- table anywhere in the schema; added now because Direct Messages makes blocking
-- load-bearing rather than just a UI affordance)
create table blocks (
  blocker_id uuid references profiles(id) not null,
  blocked_id uuid references profiles(id) not null,
  created_at timestamptz default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id != blocked_id)
);

-- helper: true if either user has blocked the other, in either direction.
-- security definer so it can be used inside RLS policies on tables where the
-- calling user shouldn't otherwise be able to see the other party's block list.
create or replace function are_blocked(user_x uuid, user_y uuid) returns boolean as $$
  select exists (
    select 1 from blocks
    where (blocker_id = user_x and blocked_id = user_y)
       or (blocker_id = user_y and blocked_id = user_x)
  );
$$ language sql security definer stable;

-- conversations (one-on-one Direct Messages, Premium+ only; see § 2 RLS for the tier gate)
create table conversations (
  id uuid primary key default gen_random_uuid(),
  user_a_id uuid references profiles(id) not null,
  user_b_id uuid references profiles(id) not null,
  last_message_at timestamptz,
  created_at timestamptz default now(),
  unique (user_a_id, user_b_id),
  check (user_a_id != user_b_id)
);
-- Application/Edge Function convention: always store the lexicographically smaller
-- uuid as user_a_id when creating a conversation, so a lookup for "does a conversation
-- between these two users already exist" is a single indexed equality check in either
-- direction rather than an OR'd pair of comparisons.

-- messages (individual messages within a conversation)
create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references conversations(id) not null,
  sender_id uuid references profiles(id) not null,
  content text not null,
  read_at timestamptz,
  created_at timestamptz default now()
);

-- notifications (cross-cutting: market alerts, community updates, direct messages,
-- strategy reminders, AI recommendations, subscription reminders)
create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) not null,
  category text not null, -- market_alert | community_update | direct_message | strategy_reminder | ai_recommendation | subscription_reminder
  title text not null,
  body text,
  deep_link text, -- e.g. path to the relevant journal entry, post, strategy, watchlist item, or conversation
  read_at timestamptz,
  created_at timestamptz default now()
);

-- revenuecat_webhook_events (idempotency log; dedupes redelivered webhook events)
create table revenuecat_webhook_events (
  event_id text primary key, -- RevenueCat's own event id, guarantees no double-processing
  event_type text not null,
  processed_at timestamptz default now()
);

-- portfolio_stats (view, not a table: aggregates journal_entries per user for the Portfolio Dashboard)
create view portfolio_stats as
select
  user_id,
  sum(pnl) as total_pnl,
  avg(case when pnl > 0 then 1.0 else 0.0 end) as win_rate,
  avg(case when (entry_price - stop_loss) != 0
        then abs(target - entry_price) / abs(entry_price - stop_loss)
        else null end) as avg_rr,
  min(pnl) as worst_trade_pnl,
  max(pnl) as best_trade_pnl
from journal_entries
where pnl is not null
group by user_id;
-- Drawdown and equity-curve/monthly-growth series are computed client-side or in a
-- dedicated query (running cumulative sum of pnl ordered by created_at), not in this view.
```

### 2. Row-Level Security Policies

```sql
alter table journal_entries enable row level security;
create policy "own journal entries only" on journal_entries
  for all using (auth.uid() = user_id);
create policy "public journal entries read-only" on journal_entries
  for select using (
    is_public = true
    and (select public_journals from profiles where id = user_id) = true
  );

alter table strategies enable row level security;
create policy "own strategies full access" on strategies
  for all using (auth.uid() = user_id);
create policy "public strategies read-only" on strategies
  for select using (visibility = 'public');

alter table strategy_versions enable row level security;
create policy "own strategy versions only" on strategy_versions
  for all using (
    auth.uid() = (select user_id from strategies where id = strategy_id)
  );

alter table journal_entry_links enable row level security;
create policy "own journal entry links only" on journal_entry_links
  for all using (
    auth.uid() = (select user_id from journal_entries where id = source_entry_id)
    and auth.uid() = (select user_id from journal_entries where id = target_entry_id)
  );

alter table watchlists enable row level security;
create policy "own watchlists only" on watchlists
  for all using (auth.uid() = user_id);

alter table watchlist_items enable row level security;
create policy "own watchlist items only" on watchlist_items
  for all using (
    auth.uid() = (select user_id from watchlists where id = watchlist_id)
  );

alter table posts enable row level security;
create policy "public read posts" on posts
  for select using (true);
create policy "owner write posts" on posts
  for insert with check (auth.uid() = user_id);
create policy "owner update/delete posts" on posts
  for update using (auth.uid() = user_id);

alter table saved_posts enable row level security;
create policy "own saved posts only" on saved_posts
  for all using (auth.uid() = user_id);

alter table blocks enable row level security;
create policy "own blocks only" on blocks
  for all using (auth.uid() = blocker_id);
-- Deliberately no policy letting blocked_id see who blocked them; block lists are
-- one-directional and private to the person who created the block.

alter table conversations enable row level security;
create policy "own conversations read/list" on conversations
  for select using (auth.uid() = user_a_id or auth.uid() = user_b_id);
create policy "only paid tiers can start a conversation" on conversations
  for insert with check (
    (auth.uid() = user_a_id or auth.uid() = user_b_id)
    and (select subscription_tier from profiles where id = auth.uid()) in ('premium', 'enterprise')
    and not are_blocked(user_a_id, user_b_id)
  );
-- No update/delete policy: conversations aren't edited or deleted by clients; they're
-- an implicit thread that exists as long as messages exist within it.

alter table messages enable row level security;
create policy "read messages in own conversations" on messages
  for select using (
    auth.uid() in (
      select user_a_id from conversations where id = conversation_id
      union
      select user_b_id from conversations where id = conversation_id
    )
  );
create policy "only paid tiers can send messages" on messages
  for insert with check (
    auth.uid() = sender_id
    and auth.uid() in (
      select user_a_id from conversations where id = conversation_id
      union
      select user_b_id from conversations where id = conversation_id
    )
    and (select subscription_tier from profiles where id = auth.uid()) in ('premium', 'enterprise')
    and not are_blocked(
      sender_id,
      (select case when user_a_id = sender_id then user_b_id else user_a_id end
       from conversations where id = conversation_id)
    )
  );
-- Deliberate design choice: the tier check runs on EVERY message insert, not just at
-- conversation creation. A user who downgrades mid-conversation can still read the
-- thread but can't send further messages until they resubscribe; matches PRD.md § 5.9's
-- "checked per-message, not just at signup" requirement. The counterparty's tier is
-- never checked; only the sender's own subscription gates their own sends, so a
-- Premium user can always reply to a Free user's existing messages to them (the Free
-- user just couldn't have started or continued the thread themselves). The block check
-- is symmetric (are_blocked checks both directions); either party blocking the other
-- stops new messages from either side, matching the "mutual block" behavior in
-- SECURITY_COMPLIANCE.md § 8.
create policy "mark received messages as read" on messages
  for update using (
    auth.uid() in (
      select user_a_id from conversations where id = conversation_id
      union
      select user_b_id from conversations where id = conversation_id
    )
  )
  with check (sender_id != auth.uid()); -- can only toggle read_at on messages someone else sent, never edit content

alter table notifications enable row level security;
create policy "own notifications only" on notifications
  for all using (auth.uid() = user_id);

alter table device_tokens enable row level security;
create policy "own device tokens only" on device_tokens
  for all using (auth.uid() = user_id);

-- Note: price-alerts and other server-triggered push functions run as the
-- service role, which bypasses RLS entirely; this policy governs client access only.

alter table subscriptions enable row level security;
create policy "own subscription read-only" on subscriptions
  for select using (auth.uid() = user_id);
-- No client insert/update/delete policy at all: subscriptions is written exclusively
-- by the revenuecat-webhook function via the service role. A user can read their own
-- billing state but never write to it directly, even their own row.

alter table comments enable row level security;
create policy "public read comments" on comments
  for select using (true);
create policy "owner write comments" on comments
  for insert with check (auth.uid() = user_id);

alter table profiles enable row level security;
create policy "public read profiles" on profiles
  for select using (true);
create policy "owner update profile" on profiles
  for update using (auth.uid() = id);

-- revenuecat_webhook_events and ai_insight_requests intentionally have NO client-facing
-- RLS policy at all (RLS enabled, zero policies = fully inaccessible to anon/authenticated
-- roles); both are service-role-only tables, never queried directly by the client.
alter table revenuecat_webhook_events enable row level security;
alter table ai_insight_requests enable row level security;
```

### 3. Edge Function: `ai-insight`

**Endpoint:** `POST /functions/v1/ai-insight`
**Auth:** requires valid Supabase JWT
**Request body:**
```json
{ "ticker": "AAPL" }
```

**Flow:**
1. Verify JWT → get `user_id` and `subscription_tier`
2. Check `ai_insight_requests` (kind='ai_insight') count for today against tier limit; reject with 429 if exceeded
3. Check `ai_insights` cache, if fresh (< 15 min old), return cached summary
4. Else: fetch price/indicator data from market data provider
5. Call Claude API with a system prompt instructing plain-English technical summary + mandatory disclaimer
6. Store result in `ai_insights`, log request in `ai_insight_requests`
7. Return summary + indicators

**Response:**
```json
{
  "ticker": "AAPL",
  "summary": "AAPL is trading above its 50-day moving average...",
  "indicators": { "rsi": 61.2, "macd": "bullish_cross", "sma50": 227.4 },
  "disclaimer": "This is AI-generated educational content, not financial advice.",
  "generated_at": "2026-07-29T10:00:00Z"
}
```

### 4. Edge Function: `analyze-screenshot`

**Endpoint:** `POST /functions/v1/analyze-screenshot`
**Auth:** requires valid Supabase JWT
**Request body:**
```json
{ "image_base64": "<base64-encoded trade/chart screenshot>", "media_type": "image/png" }
```

**Flow:**
1. Verify JWT → get `user_id`
2. Upload image to Supabase Storage (`screenshots/{user_id}/{uuid}.png`), get URL
3. Call Claude API (vision) with a system prompt instructing structured extraction only: ticker, entry price, exit price, stop loss, target, position size, side, and P/L if computable
4. Parse response as JSON; missing/unreadable fields return `null` rather than guessed values
5. Return parsed fields for the client to show as an editable pre-fill on the journal entry form (does not write to `journal_entries` directly)

**Response:**
```json
{
  "screenshot_url": "https://.../screenshots/u123/abc.png",
  "parsed": {
    "ticker": "AAPL",
    "entry_price": 228.10,
    "exit_price": 231.40,
    "stop_loss": 225.00,
    "target": 235.00,
    "size": 100,
    "side": "long",
    "pnl": 330.00
  },
  "confidence": "high"
}
```

**Outcome computation (client-side, on entry save):** `pnl > 0` → `outcome='win'`; `pnl < 0` → `outcome='loss'`; `pnl == 0` → `outcome='breakeven'`; all with `outcome_source='auto'`. A direct edit to the outcome field sets `outcome_source='manual'` and is not silently recomputed.

### 5. Edge Function: `ai-strategy-review` (Premium)

**Endpoint:** `POST /functions/v1/ai-strategy-review`
**Auth:** requires valid Supabase JWT + `subscription_tier = 'premium'` or `'enterprise'`
**Request body:** `{ "strategy_id": "uuid" }`

**Flow:** load the strategy's rich-text `content`, send to Claude with a system prompt asking for a clarity/consistency review (ambiguous rules, missing entry/exit criteria, internal contradictions). Log to `ai_insight_requests` (kind='strategy_review'). Response is shown to the user, not persisted onto the strategy record (only `ai_summary`, from § 7, is persisted).

### 6. Edge Function: `ai-journal-analysis` (Premium)

**Endpoint:** `POST /functions/v1/ai-journal-analysis`
**Auth:** requires valid Supabase JWT + `subscription_tier = 'premium'` or `'enterprise'`
**Request body:** `{ "date_range": { "from": "...", "to": "..." }, "strategy_id": "uuid | null", "single_entry_id": "uuid | null" }`

**Flow:** query the user's `journal_entries` in range (optionally filtered by strategy, or scoped to exactly one entry when `single_entry_id` is set, this is how the Trade Review feature reuses this same function per API_REFERENCE.md's capability mapping), send psychology/mistakes/lessons/outcome fields to Claude for pattern analysis (recurring mistakes, psychology trends, tag/outcome correlations). Log to `ai_insight_requests` (kind='journal_analysis'). Response returned directly, not persisted.

### 7. Edge Function: `strategy-ai-summary` (Premium)

**Endpoint:** `POST /functions/v1/strategy-ai-summary`
**Auth:** requires valid Supabase JWT + `subscription_tier = 'premium'` or `'enterprise'`
**Trigger:** called on strategy save (or on-demand via a "regenerate summary" button)

**Flow:** send the strategy's `content` to Claude for a short plain-English summary, write result to `strategies.ai_summary`. Log to `ai_insight_requests` (kind='strategy_summary').

### 8. Edge Function: `price-alerts` (scheduled)

**Trigger:** scheduled (e.g. every 5 min, frequency varies by asset class, see BACKGROUND_JOBS.md § 1 on equity vs. forex/crypto market hours) via Supabase cron
**Auth:** service role only, never reachable by a client JWT

**Flow:**
1. Select all `watchlist_items` rows where `price_alert_threshold is not null and alert_armed = true`
2. Fetch current price per ticker from the market data provider (batched where the provider supports it)
3. For each item where price has crossed `price_alert_threshold` in the direction specified by `price_alert_direction`:
   - Insert a `notifications` row (`category='market_alert'`, `deep_link` pointing at that watchlist)
   - Look up the user's `device_tokens` and push via FCM/APNs
   - Set `alert_armed = false`, `alert_last_triggered_at = now()`
4. Separately, for already-triggered (`alert_armed = false`) items: re-arm (`alert_armed = true`) once price has moved back past the threshold by a buffer (recommend 0.5%) on the *opposite* side, prevents re-triggering on every 5-minute tick while price sits right at the line

No per-user rate limit needed since it's a scheduled system job, not a user-triggered AI call.

### 9. Edge Function: `revenuecat-webhook`

**Endpoint:** `POST /functions/v1/revenuecat-webhook`
**Auth:** **not** a Supabase JWT, this is a service-to-service webhook. Verify the request using RevenueCat's signature header against `REVENUECAT_WEBHOOK_SECRET` (see ENVIRONMENT_VARIABLES.md); reject with `401` if the signature doesn't match. Confirm RevenueCat's current signature-verification mechanism at implementation time, since webhook auth schemes are versioned on their end.

**Request body:** RevenueCat's standard webhook event payload, includes `event.id`, `event.type`, `app_user_id` (maps to `profiles.id`), `product_id`, `expiration_at_ms`, and other fields per RevenueCat's own webhook documentation.

**Flow:**
1. Verify signature (above)
2. **Idempotency check:** `insert into revenuecat_webhook_events (event_id, event_type) values (...) on conflict (event_id) do nothing returning event_id`. If no row is returned, this event was already processed, return `200` immediately without reprocessing (RevenueCat redelivers events; this must never double-apply a state change).
3. Switch on `event.type`:

| Event type | Action |
|---|---|
| `INITIAL_PURCHASE`, `RENEWAL`, `PRODUCT_CHANGE` (upgrade/downgrade) | Upsert `subscriptions` row: `tier` from `product_id` mapping, `status='active'`, `revenuecat_id`, `billing_cycle`, `renewed_at=now()`, `expires_at` from payload. Update `profiles.subscription_tier` to match. |
| `CANCELLATION` | Update `subscriptions.status='canceling'`. **Do not** change `tier` or `profiles.subscription_tier` yet, access continues until `expires_at` (matches the "Unlimited AI Trading Assistant" promise not silently breaking mid-cycle, per BACKGROUND_JOBS.md § 2's reasoning). |
| `EXPIRATION` | Update `subscriptions.status='expired'`, `tier='free'`. Update `profiles.subscription_tier='free'`. |
| `BILLING_ISSUE` | Update `subscriptions.status='billing_issue'` (tier unchanged). Insert a `notifications` row (`category='subscription_reminder'`). |
| Any other event type | Log and acknowledge with `200`, no state change, don't fail the webhook on an event type this function doesn't need to act on. |

4. Return `200` quickly, RevenueCat expects fast acknowledgment; do any non-critical follow-up work (e.g. analytics) asynchronously if needed, don't block the response on it.

**Response (success):** `{ "received": true }`
**Errors:** `401` bad signature · `400` malformed payload · `500` on an unexpected failure to write (RevenueCat will retry on non-2xx, which is why the idempotency check in step 2 exists)

### 10. Edge Function: `ai-chat` (Premium: AI Q&A / AI Trading Assistant chat)

**Endpoint:** `POST /functions/v1/ai-chat`
**Auth:** requires valid Supabase JWT + `subscription_tier = 'premium'` or `'enterprise'`
**Request body:**
```json
{
  "scope": "ticker",
  "scope_id": "AAPL",
  "message": "What's the risk/reward on a breakout entry above 230?",
  "conversation_id": "uuid | null"
}
```
`scope` is one of `ticker` / `watchlist` / `portfolio`, matching the scope selector in SCREENS_MOBILE.md § 7. `conversation_id` is `null` for a new conversation; the function creates and returns one on first message, client passes it back on subsequent turns in the same thread.

**Flow:**
1. Verify JWT + tier
2. Check `ai_insight_requests` (kind='chat') count against the Premium soft-cap pattern (BACKGROUND_JOBS.md § 2, logged for anomaly detection, not a hard block)
3. Load conversation history for `conversation_id` if provided (a lightweight `ai_chat_messages` table, **not yet added to the schema above**, flagged below)
4. Build context based on `scope`: current ticker's price/indicators (scope=ticker), the named watchlist's tickers (scope=watchlist), or `portfolio_stats` + recent journal entries (scope=portfolio)
5. Call Claude API with conversation history + new message + scope context + the standard disclaimer-mandatory system prompt
6. Log to `ai_insight_requests` (kind='chat')
7. Persist both the user message and the AI response to `ai_chat_messages`
8. Return the AI response

**Response:**
```json
{
  "conversation_id": "uuid",
  "message": "Based on the current setup...",
  "disclaimer": "This is AI-generated educational content, not financial advice."
}
```

**Streaming:** the chat UI (SCREENS_MOBILE.md § 7) implies token-by-token streaming for a responsive feel. Recommend implementing this as a Server-Sent Events or chunked response rather than a single blocking JSON response, the request/response shapes above describe the *logical* contract; the actual wire format for streaming should be finalized alongside whichever Flutter HTTP client handles it (see FRONTEND_README.md's `ai-chat` UI note).

**Still incomplete, flagging rather than inventing further:** this function needs an `ai_chat_messages` table (`id`, `conversation_id`, `user_id`, `role` [`user`/`assistant`], `content`, `created_at`) with owner-only RLS, which isn't in § 1's schema yet. Adding it here would be reasonable but touches conversation-retention policy (how long to keep chat history, whether it counts toward any storage limits) that hasn't been decided, recommend deciding retention before adding the table rather than adding it with an arbitrary default.

### 11. Database trigger: `notify_new_message`

Direct Messages don't go through an Edge Function to send (client inserts directly into `messages`, gated by the RLS policies in § 2), but a new message still needs to produce a `notifications` row and a push, consistent with every other notification-producing event in the app. This is a Postgres trigger, not an Edge Function:

```sql
create or replace function notify_new_message() returns trigger as $$
declare
  recipient_id uuid;
  sender_handle text;
begin
  select case when user_a_id = new.sender_id then user_b_id else user_a_id end
    into recipient_id
  from conversations where id = new.conversation_id;

  select handle into sender_handle from profiles where id = new.sender_id;

  insert into notifications (user_id, category, title, body, deep_link)
  values (
    recipient_id,
    'direct_message',
    sender_handle || ' sent you a message',
    left(new.content, 100),
    '/messages/' || new.conversation_id
  );

  update conversations set last_message_at = new.created_at where id = new.conversation_id;

  return new;
end;
$$ language plpgsql security definer;

create trigger on_new_message
  after insert on messages
  for each row execute function notify_new_message();
```

`security definer` is required here, the trigger needs to write a `notifications` row for the **recipient**, not the sender, and the recipient's RLS policy (`auth.uid() = user_id`) would otherwise block that insert since the trigger runs in the sender's auth context. This is the one place in the schema where a trigger writes across a user boundary; treat it as a reviewed exception, not a pattern to reuse elsewhere without the same scrutiny.

**Push delivery:** this trigger only writes the in-app `notifications` row, actually pushing via FCM/APNs still needs something watching for new `category='direct_message'` rows and sending through `device_tokens`, the same as any other push-worthy notification. Options: a Supabase Realtime-triggered Edge Function listening on `notifications` inserts, or folding it into the existing scheduled-job pattern with a short interval. Not yet decided which, flagged as an open implementation detail, not a contract gap (the notification itself is fully specced; only its push-delivery mechanism isn't chosen yet).

### 12. AI Trading Assistant: capability mapping

PRD.md § 5.7 lists a broad set of AI Trading Assistant capabilities. Most map onto the edge functions already defined above rather than needing new endpoints:

| PRD capability | Backing edge function | Notes |
|---|---|---|
| Market analysis / trade setup explanation | `ai-insight` | Existing ticker-scoped summary |
| Risk-to-reward analysis | `ai-insight` (extended request) or client-computed from entry/stop/target | Simple RR math can be client-side; AI framing of it goes through `ai-insight` |
| Trade review after execution | `ai-journal-analysis` with `single_entry_id` set (§ 6) | Same function, now explicitly supports single-entry scope |
| Strategy improvement suggestions | `ai-strategy-review` + `ai-journal-analysis` combined | Client merges both responses into one suggestions view |
| News & sentiment summaries | `ai-insight` (extended) | Requires a news/sentiment data source in addition to price/indicator data, provider TBD, see ROADMAP.md |
| Watchlist insights | `ai-insight` (batch mode over a watchlist's tickers) or `ai-chat` with `scope=watchlist` | Either works; `ai-chat` is the better fit if the interaction is conversational rather than one-shot |
| Weekly / monthly performance review | `ai-journal-analysis` (date-range mode) | Reads from `portfolio_stats` view (§ 1) plus journal entries in the period |
| AI Q&A | `ai-chat` (§ 10) | Now specced above, was the one fully-open item, resolved as of this revision |

### 13. Tier Limits (config, stored server-side)
| Tier | AI Trading Assistant | AI Strategy Review | AI Journal Analysis | Screenshot analyses/day | Journal entries | Watchlists | Strategy Notes | Portfolio Dashboard | Direct Messages | Community reads/day |
|---|---|---|---|---|---|---|---|---|---|---|
| Free | No | No | No | 0 | 20 | 1 (no alerts) | No | Basic stats only | No access | Limited (e.g. 10/day) |
| Premium | Unlimited | Yes | Yes | Unlimited (soft daily cap, e.g. 50) | Unlimited | Unlimited | Yes (full: editor, version history, AI summary) | Full (breakdowns + charts) | Unlimited (send + receive) | Unlimited |
| Enterprise | Unlimited (org-pooled) | Yes | Yes | Unlimited | Unlimited | Unlimited | Yes | Full | Unlimited | Unlimited |

Enterprise limits are placeholders pending the org/seat model, see ROADMAP.md. Direct Messages has no rate limit beyond the tier gate itself (§ 2), no `ai_insight_requests`-style logging, since sending a message isn't a metered/costly AI call.
