# Product Requirements Document (PRD)
## TraderHub (working name: TraderX) — AI Trading, Journaling & Community Platform

### 1. Overview
TraderHub is a cross-platform Flutter app (iOS, Android, Web, Desktop) built exclusively for traders, combining five pillars:
1. **AI Trading Assistant** — market analysis, trade setup explanation, risk/reward analysis, trade review, journal/strategy review, news & sentiment summaries
2. **Trading Journal & Strategy Notes** — private journal entries linked to tickers/trades, reusable rich-document trading strategies with version history, a strategy analyzer, and a graph view linking related entries
3. **Watchlists** — tracked tickers with price alerts, notes, and categories
4. **Portfolio Dashboard** — aggregate performance analytics across the whole journal (P/L, win rate, RR, drawdown, equity curve)
5. **Community** — a trader-focused social feed for posts, trade ideas, discussion, and one-on-one direct messages between traders (Premium+)

A cross-cutting **Notifications** system ties the above together (market alerts, community updates, strategy reminders, AI recommendations, subscription reminders).

Monetized via subscription tiers (Free / Premium / Enterprise).

**Long-term vision:** build the most comprehensive AI-powered platform for traders — combining market intelligence, journaling, analytics, and a professional trading community into one application that helps traders improve decision-making, maintain discipline, and measure long-term performance.

### 2. Goals
- Ship a working MVP solo, AI-assisted, within 6-10 weeks
- Validate willingness to pay for AI-generated trade insights bundled with community
- Keep infra cost low pre-revenue (usage-based backend, no owned servers)

### 3. Non-Goals (MVP)
- No direct trade execution / brokerage integration (see ROADMAP.md for post-MVP broker integrations)
- No proprietary ML model training (use LLM + technical indicators instead)
- No group chat / multi-party messaging — direct messages are strictly one-on-one for MVP (see 5.9); group threads are a possible post-MVP extension, not scoped here
- No copy trading, AI trade automation, or strategy/indicator marketplace in v1 — see ROADMAP.md
- Not licensed financial advice — insights are educational/informational only
- Enterprise plan (team management, multi-user dashboards, device licensing, org analytics, custom branding, API access) is **defined here for pricing/scope purposes but built post-MVP** — see ROADMAP.md.

### 4. Target Users
- Forex traders, crypto traders, stock traders, options traders
- Swing traders, scalpers, day traders
- Retail/active traders who want a community + a scratchpad + quick AI-assisted read on a ticker
- Enterprise (post-MVP): professional trading teams, prop trading desks / trading education businesses wanting a branded, managed version for their team

### 5. Core Features by Module

#### 5.1 Auth & Profile
- Email/password + OAuth (Google, Apple)
- Public profile: profile picture, handle, bio, experience level (e.g. beginner/intermediate/advanced/pro), trading style (e.g. day trading, swing, scalping, options), follower/following counts, public statistics (win rate, etc. — see 5.5 Portfolio Dashboard)
- Public journals (optional): user can opt to make selected journal entries visible on their public profile, off by default
- Private settings: subscription tier, notification prefs

#### 5.2 Trading Journal
Users maintain a complete trading journal — the private, per-trade counterpart to the public Community feed.
- Create/edit/delete journal entries
- Optional ticker tag (e.g. $AAPL)
- Trade fields: entry price, exit price, stop loss, target, position size, side, profit/loss
- Screenshots (one or more chart/trade screenshots per entry)
- Free-text notes
- Trading psychology (how the trader felt / what drove the decision)
- Mistakes made
- Lessons learned
- Strategy used (optional link to a Strategy Note — see 5.3)
- Tags (free-form, in addition to strategy/ticker)
- Search & filter by ticker, date, tag, strategy, outcome
- Free tier: limited entries count; Premium+: unlimited
- **Screenshot auto-fill:** attach a trade/chart screenshot → Claude vision reads the image and pre-fills ticker, entry, exit, stop loss, target, size, and P/L; user reviews/edits before saving.

#### 5.3 Strategy Notes
Users create personal trading strategies as standalone rich documents — not just a tag, a first-class piece of content.
- Rich text editor for strategy writeups
- Charts & images embedded in the strategy document
- Version history (every edit is retained; can view/restore prior versions)
- Categories (user-defined groupings, e.g. "Breakout", "Mean Reversion")
- Favorite strategies (pin for quick access)
- Visibility: Private (default) or Public (visible on the user's public profile / discoverable by other users, read-only to non-owners)
- **AI summary (Premium):** Claude-generated plain-English summary of a strategy document, refreshed when the strategy is edited
- Journal entries (5.2) can optionally link to a strategy via "Strategy used"

**Strategy Analyzer (rollup on top of Strategy Notes + Journal):**
- **What it is:** a rollup view, per strategy, of every journal entry that used it, plus an aggregate win/loss/breakeven record and basic stats (win rate, avg P/L, avg hold time where derivable).
- **How outcome is determined:** auto from journal entry P/L sign, or manual override; screenshot auto-fill (5.2) feeds the auto-determination end-to-end.
- **How it's filed:** a journal entry stays a normal journal entry whether or not it's linked to a strategy; untagged entries are excluded from analyzer rollups.
- **Graph view:** a visual map connecting journal entries, strategies, and tickers (explicit entry↔entry links, plus derived entry↔strategy/ticker edges).
- Free tier: no Strategy Notes editor, no analyzer, no graph view; Premium+: full access.

#### 5.4 Watchlists
- Multiple named watchlists (Free tier: 1 watchlist; Premium+: unlimited)
- Add/remove tickers per watchlist
- Price alerts per ticker (threshold-based, push notification)
- Notes per watched ticker
- Categories (group tickers within or across watchlists, e.g. "Earnings this week")
- Favorite assets (quick-access shortlist independent of watchlist membership)

#### 5.5 Portfolio Dashboard
An aggregate performance view computed from the user's Trading Journal — answers "how am I actually doing?" across all trades and strategies, not just per-entry.
- **Headline stats:** Total P/L, Win Rate, Average Risk-to-Reward (RR), Max Drawdown
- **Time-boxed performance:** Weekly Performance, Monthly Performance
- **Breakdowns:** Strategy Performance (win rate/P&L per strategy — feeds from the Strategy Analyzer in 5.3), Best Trade, Worst Trade
- **Charts:** Equity Curve (cumulative P/L over time), Monthly Growth, Win/Loss Distribution
- All figures are computed/derived from `journal_entries` — no separate manual data entry
- Free tier: basic analytics only (headline stats); Premium+: full dashboard including strategy breakdowns and all charts

#### 5.6 Community
A trader-focused social feed for sharing and discussing trades, distinct from the private Trading Journal.
- Publish posts: share charts, trade ideas, and written analysis (+ optional chart screenshot/image)
- Content types: Trade Analysis, Educational Posts, Psychology, Strategies, News, Market Discussion (tag a post with one on creation; used for feed filtering)
- Like, comment, follow
- **Save posts** (private bookmark list, separate from likes)
- Report content / block / mute for moderation
- Feed algorithm v1: reverse-chron of followed users + trending tickers, filterable by content type
- Free tier: read a limited number of community posts per day, limited interaction (e.g. capped likes/comments); Premium+: unlimited community access

#### 5.7 AI Trading Assistant
- Ticker search → price chart + key indicators (RSI, MACD, moving averages)
- **Market analysis using technical indicators** and **AI explanation of trade setups** — the core "explain this ticker/setup" capability
- **Risk-to-reward analysis** on a proposed or logged trade
- **Trade review after execution** — AI commentary on a completed journal entry (what went right/wrong relative to the plan)
- **Strategy improvement suggestions** — surfaced from AI Strategy Review (on a Strategy Note) and AI Journal Analysis (patterns across entries) combined
- **News and sentiment summaries** for a ticker or the market generally
- **Watchlist insights** — AI commentary surfaced against a user's watchlist (e.g. notable movers, approaching alert thresholds)
- **AI Strategy Review (Premium):** Claude reviews a Strategy Note (5.3) for internal consistency/clarity and flags ambiguous or conflicting rules
- **AI Journal Analysis (Premium):** Claude reviews a user's journal entries for patterns — mistake detection, trading psychology analysis, which tags correlate with losses
- **Weekly / monthly performance review (Premium):** AI-generated narrative summary layered on top of the Portfolio Dashboard (5.5) numbers
- **AI Q&A:** open-ended chat for trading questions, risk management guidance
- Daily digest notification (Premium+): top movers + AI summary
- Basic analytics (Free): read-only summary stats, no AI-generated content
- Explicit disclaimer on every AI output: educational, not financial advice — this applies to all AI Trading Assistant capabilities above, not just ticker insights

#### 5.8 Notifications
Cross-cutting delivery system spanning the modules above.
- **Market alerts** — price alert thresholds from Watchlists (5.4)
- **Community updates** — new follower, comment, like on the user's posts (Community, 5.6)
- **Direct messages** — new message received (5.9)
- **Strategy reminders** — nudges tied to Strategy Notes (5.3), e.g. revisit a strategy after N related journal entries
- **AI recommendations** — surfaced insights from the AI Trading Assistant (5.7), e.g. a weekly performance review is ready
- **Subscription reminders** — renewal upcoming, trial ending, payment failed
- User-configurable per category in Settings; delivered via push notification + in-app notification center

#### 5.9 Direct Messages (Premium+)
One-on-one messaging between traders — a private counterpart to the public Community feed, gated behind a paid subscription (Premium or Enterprise; "subscribed to any kind" unlocks it, Free does not).
- One-on-one conversations only — no group chat in v1 (see § 3 Non-Goals)
- Start a conversation from another user's profile ("Message" action) or from an existing conversation list
- Real-time delivery, read receipts, conversation list sorted by most recent activity
- Report / block a conversation participant — reuses the same moderation actions as Community (5.6), extended to cover DMs
- **Tier gating:** sending a message requires an active Premium or Enterprise subscription — checked per-message, not just at signup, so a downgrade takes effect immediately (a downgraded user can still read existing conversations, just can't send new messages until they resubscribe)
- Free tier: no access — tapping "Message" on a profile or opening the Direct Messages list shows an upsell rather than a locked read-only view (unlike some other Premium features, there's no meaningful "basic" version of DMs to show for free)
- Push + in-app notification on new message (ties into 5.8 Notifications as a new category)

#### 5.10 Subscriptions

**Free**
- Basic profile
- Trading journal (limited entries)
- Basic watchlist (1 watchlist, no price alerts)
- Read a limited number of community posts per day, limited community interaction
- Basic analytics
- No AI access (no AI Trading Assistant, AI Strategy Review, AI Journal Analysis, Strategy Notes AI summary)
- No Strategy Notes editor / analyzer / graph view
- No Direct Messages

**Premium** ($9.99/mo — replaces the former "Pro" tier)
- Unlimited AI Trading Assistant
- AI Strategy Review
- AI Journal Analysis
- Unlimited community access
- Direct Messages (one-on-one)
- Advanced analytics
- Portfolio insights (full Portfolio Dashboard)
- Unlimited watchlists (+ price alerts, notes, categories)
- Unlimited journal entries
- Full Strategy Notes (rich editor, version history, AI summary) + analyzer + graph view
- Priority support

**Enterprise** (custom pricing, post-MVP — see § 3 Non-Goals and ROADMAP.md)
- Team management
- Multi-user dashboard
- Device licensing
- Admin controls
- Organization analytics
- Custom branding
- API access

Managed via RevenueCat across App Store / Play / Stripe (web) for Free/Premium (monthly and annual billing cycles); Enterprise billing likely direct/invoiced given its custom-pricing, team-seat nature (to be scoped when built).

### 6. Success Metrics (first 90 days post-launch)
- Activation: % of signups who create ≥1 journal entry or post in first session
- Retention: D7 / D30 return rate
- Conversion: Free → Premium conversion rate
- Engagement: posts/comments per weekly active user
- Journaling depth: % of entries linked to a strategy, avg entries per strategy, graph view opens per WAU
- Watchlist adoption: % of active users with ≥1 watchlist, avg tickers watched
- Portfolio Dashboard engagement: % of WAU who open the dashboard, avg views per week
- Direct Message adoption: % of Premium+ users who send ≥1 message, avg conversations per active DM user (a Premium-only feature adopted well is also a conversion argument for Free users)

### 7. Compliance & Risk Notes
- Add Terms of Service disclaimer: not a registered investment advisor, no guaranteed returns
- Rate-limit and log all AI calls (cost control + auditability)
- Row-Level Security on all user data (journal entries and private strategies are private by default; posts and public strategies are public by default; opted-in public journal entries follow the same public-read model as public strategies)

### 8. Revenue Model
- Monthly subscription (Premium)
- Annual subscription (Premium, discounted vs. monthly)
- Enterprise licensing (custom, post-MVP)
- Premium analytics (bundled into Premium at MVP; potential future à la carte add-on)
- Future: marketplace for strategies & indicators (post-MVP, see ROADMAP.md) — monetization model TBD (revenue share vs. flat listing fee)

### 9. Release Plan
| Phase | Scope | Est. Duration |
|---|---|---|
| 0 | Project scaffold, auth, navigation shell | 1 week |
| 1 | Trading journal (full CRUD, all fields) | 1-1.5 weeks |
| 1.5 | Strategy Notes + Strategy Analyzer (editor, version history, outcome tagging, screenshot auto-fill, graph view) | 1.5-2 weeks |
| 1.75 | Watchlists (multi-watchlist, price alerts, categories) | 3-5 days |
| 2 | Community feed (post/like/comment/follow/save, content types) | 2-2.5 weeks |
| 2.25 | Direct Messages (one-on-one, real-time, tier-gated) | 1-1.5 weeks |
| 2.5 | Portfolio Dashboard (headline stats, breakdowns, charts) | 1 week |
| 3 | AI Trading Assistant (insights, strategy review, journal analysis, Q&A) | 2-3 weeks |
| 3.5 | Notifications system (market alerts, community, direct messages, strategy, AI, subscription) | 3-5 days |
| 4 | Subscriptions (RevenueCat) + paywalls (Free/Premium) | 1 week |
| 5 | Polish, QA, store submission | 1-2 weeks |
| 6 (post-MVP) | Enterprise: org/team model, admin controls, custom branding, API access | scoped separately — see ROADMAP.md |

Note: Phases 0–5 (Free/Premium MVP) now run roughly 11.5–16 weeks with Direct Messages added on top of the earlier estimate; treat Strategy Notes version history, Portfolio Dashboard charts, and Notification category granularity as the first things to descope if the timeline slips, since core CRUD/journal/community delivers most of the user value on its own.

⚠️ **Open conflict:** this plan bundles Strategy Notes and Watchlists into the MVP, which pushes the timeline past the 6-10 week goal in § 2. The source product doc's own Phase 1 excludes both. See ROADMAP.md § "Source phase structure vs. this project's Release Plan" for the full comparison — needs a decision on which scope to build first.
