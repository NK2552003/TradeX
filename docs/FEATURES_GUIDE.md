# alphajournal (TradeX) — Complete Feature Documentation, Product Review & Demo Guide

This guide documents every implemented feature in **alphajournal (TradeX)**, how each feature works end-to-end across Flutter, Supabase, and Cloudflare Workers, practical product reviews (strengths + operational requirements), and step-by-step demos on how to create and use each workflow.

---

## 1. Platform Architecture & Subdomains

| Surface | Canonical URL | Purpose |
| --- | --- | --- |
| **Landing, Auth & Referrals** | `https://alphajournal.in` | Public entry, onboarding, `/auth/login`, `/auth/signup`, `/r/:code` referrals, `/help` docs |
| **Trader App & AI Workspace** | `https://app.alphajournal.in` | Post-login home (`/workspace`), Journal, Notes, Strategies, Calculators, Markets, E2EE Messages, AI Copilot, Billing |
| **Trader Community** | `https://community.alphajournal.in` | Public/authenticated feed (`/community_feed`), Explore, Network, Profile, Bookmarks, Posts (`/community/post/:id`), Trader Profiles (`/@handle`) |
| **Affiliate Partner Hub** | `https://affiliate.alphajournal.in` | Affiliate application (`/affiliate_application`), Partner Overview, Referrals, Marketing Assets, Payouts |
| **Admin Console** | `https://admin.alphajournal.in` | Admin dashboard (`overview`), Affiliate Reviews, Org Team Seats, Moderation, Audit Logs, Platform Settings (`noindex`) |

* **Cross-Subdomain Single Sign-On**: `SupabaseConfig.initialize` uses `CrossSubdomainLocalStorage` (`lib/core/config/cross_subdomain_storage_web.dart`) backed by chunked `Domain=.alphajournal.in; Path=/; SameSite=Lax; Secure` cookies alongside `window.localStorage`, so signing in once keeps your session and active workspace role seamless across all subdomains.
* **Edge SEO & Social Previews**: `worker/index.js` enforces HTTPS (`308`), canonicalizes subdomain paths, serves host-aware `/robots.txt` (`Disallow: /` on `admin.`), builds dynamic `/sitemap.xml` from approved public posts and profiles, and rewrites Open Graph / Twitter metadata on the edge.

### Subscription Plans & Baseline Quotas (`lib/core/config/customer_limitations.dart`)

| Plan | Monthly Price | Notes | Trade Journal Entries | Live Playbooks | Watchlists | AI Queries / Mo | PDF Export & Adv. Backtest |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **alphajournal Free** | ₹0 / mo | 3 | 15 | 1 | 1 | 5 | No |
| **alphajournal Basic** | ₹299 / mo | 25 | 100 | 3 | 1 | 20 | No |
| **alphajournal Pro** | ₹499 / mo | 10,000 | 50,000 | 250 | 100 | 5,000 | Yes |

*(Published plans can also be updated dynamically via `public_site` catalogue sync, with Razorpay / RevenueCat webhook fulfillment in `supabase/functions/razorpay-webhook` and `revenuecat-webhook`.)*

---

## 2. Feature-by-Feature Guide, Reviews & Interactive Demos

---

### Feature 1: Onboarding, Authentication & Role Workspaces

* **Where it lives**: `lib/features/auth/`, `lib/core/navigation/role_navigation_config.dart`
* **Supported Flows**:
  * Email/password sign-up & login, OTP verification, forgot/reset password, and Google OAuth (`redirectTo` matching active origin).
  * Multi-role switching via profile menu: **Trader (`customer`)**, **Affiliate (`affiliate`)**, and **Admin (`user_admin`)**.
  * Post-auth deep-link recovery (`?next=` validated via `CustomerRoute.afterAuthentication`).

#### Product Review
* **Strengths**: Eliminates login flicker via splash session hydration (`AuthWrapper._restoreActiveSession`), seamlessly persists auth tokens and active workspace role across subdomains via `.alphajournal.in` cookies, and strictly validates `?next=` redirects against open-redirect attacks.
* **Requirements**: In Supabase Dashboard -> Authentication -> URL Configuration, configure Site URL (`https://alphajournal.in`) and Redirect URLs (`https://alphajournal.in/**` and `https://*.alphajournal.in/**`).

#### Demo: Sign In & Switch Roles
1. Visit `https://alphajournal.in` -> complete onboarding or click **Sign In** (`/auth/login`).
2. Authenticate with email/password or Google OAuth. You are automatically routed to `https://app.alphajournal.in/workspace`.
3. Open your account menu -> select **Switch to Affiliate** (if approved) to jump seamlessly to `https://affiliate.alphajournal.in/overview` with zero re-login.

---

### Feature 2: Writing Desk / Workspace (`workspace`) & Record Linking (`linking`)

* **Where it lives**: `lib/features/workspace/`, `lib/features/linking/`
* **Capabilities**:
  * Unified command center with interactive calendar/week strip showing daily writing/trade activity dots.
  * Paginated carousels for recent **Notes**, **Journal entries**, and **Strategy playbooks** with date filtering and instant search.
  * Direct **Record Linking (`LinkGraph`)** connecting trades, notes, strategies, market tickers, messages, and community posts (`[[...]]` / record picker).

#### Product Review
* **Strengths**: Connects pre-market thesis notes, rule playbooks, and post-trade journal reviews into one traceable graph rather than isolated silos.
* **Caveat**: Heavy workspace histories paginate in carousels; use top-bar search or filter chips when hunting older entries.

#### Demo: Create a Connected Workflow
1. On `https://app.alphajournal.in/workspace`, pick today's date on the calendar strip.
2. Create a Note ("Pre-market plan") -> link a Strategy Playbook inside it -> link both inside a Trade Journal entry so you can jump back and forth in one click.

---

### Feature 3: Trade Execution Journal (`journal`)

* **Where it lives**: `lib/features/journal/`
* **Templates (7 built-in)** (`lib/features/journal/data/journal_templates.dart`):
  1. `Blank entry`
  2. `Trade review`
  3. `Live position`
  4. `Mistake log`
  5. `Plan vs actual`
  6. `Chart review`
  7. `Scaled exit`
* **Capabilities**:
  * Structured entry/exit price, symbol/ticker, long/short direction, outcome & P&L tracking, tags, image/chart attachments (`journal_attachments.dart`), linked notes/strategies, and one-click Community publishing/discussion threads.

#### Product Review
* **Strengths**: Template-first design removes blank-page friction and enforces structured discipline (`Plan vs actual`, `Mistake log`). Integrates with calculators (`calculator_journal_draft.dart`) to pre-fill sizing/P&L numbers.
* **Limits**: Free tier allows up to 15 journal entries; Basic allows 100; Pro allows 50,000 and PDF export.

#### Demo: Log & Review a Trade
1. Navigate to **Journal** (`https://app.alphajournal.in/journal`).
2. Click **New Entry** -> pick **Trade review** (or **Plan vs actual**).
3. Enter Ticker (e.g., `NIFTY` or `NVDA`), Entry/Exit prices, Quantity, Mindset tags, and attach a chart screenshot.
4. Save to Supabase (`supabase_trade_repository.dart`) and optionally click **Share to Community** to discuss the setup publicly.

---

### Feature 4: Linked Research Notes (`notes`) & AI Refactor

* **Where it lives**: `lib/features/notes/`, `supabase/functions/note-ai-refactor`
* **Templates (8 built-in)** (`lib/features/notes/data/note_templates.dart`):
  1. `Blank note`
  2. `Trade plan`
  3. `Pre-market plan`
  4. `Trade review`
  5. `Weekly review`
  6. `Strategy idea`
  7. `Chart analysis`
  8. `Cheat sheet`
* **Capabilities**:
  * Rich structured writing editor with attachments, preview mode, ticker/record linking, and **AI Refactor** (`real_note_ai_refactor.dart` backed by `note-ai-refactor` / OpenAI).

#### Product Review
* **Strengths**: The 8 trader-specific templates plus AI cleanup make turning messy intraday scratchpads into clean post-market playbooks very fast.
* **Limits**: Free tier allows 3 notes (Basic: 25, Pro: 10,000). AI Refactor draws from monthly AI query quota and requires `OPENAI_API_KEY` set in Supabase Edge Secrets.

#### Demo: Create & AI-Refactor a Note
1. Open **Notes** (`https://app.alphajournal.in/notes`) -> **New Note** -> choose **Pre-market plan**.
2. Type rough bullet points for key levels, invalidation, and catalysts.
3. Click **AI Refactor** to clean structure and extract key levels into a readable note preview, then link the note to your active Strategy.

---

### Feature 5: Strategy Playbooks & Versioning (`strategies`)

* **Where it lives**: `lib/features/strategies/`
* **Templates (8 built-in)** (`lib/features/strategies/data/strategy_templates.dart`):
  1. `Blank playbook`
  2. `Rule-based setup`
  3. `Breakout / momentum`
  4. `Mean reversion`
  5. `Options income`
  6. `Systematic / backtested`
  7. `Risk framework`
  8. `Extracted from the journal`
* **Capabilities**:
  * Structured entry triggers, invalidation rules, risk parameters, attachments, and **Revision Note Prompts** (`revision_note_prompt.dart`) to track playbook evolution over time.

#### Product Review
* **Strengths**: Requiring revision notes encourages systematic iteration instead of silent rule drift after losses; `Extracted from the journal` bridges real trade data back into documented rules.
* **Limits**: Live playbooks quota: Free (1), Basic (3), Pro (250).

#### Demo: Build a Playbook
1. Go to **Strategies** (`https://app.alphajournal.in/strategies`) -> **New Strategy**.
2. Pick **Breakout / momentum** or **Options income**.
3. Define setup context, entry checklist, stop-loss rule, and scaling plan, then save. When editing rules later, record the **Revision Note** explaining why the rule changed.

---

### Feature 6: 22 Trading, Investing, Options & Tax Calculators (`calculators`)

* **Where it lives**: `lib/features/calculators/`
* **Full Calculator Catalog (`kAllCalculators`)**:
  * **Trading (7)**: `Position Size`, `Risk / Reward`, `Brokerage & Charges` (STT, GST, stamp duty), `Margin` (SPAN + exposure), `Pivot Points` (Standard, Camarilla, Woodie), `Fibonacci Levels`, `Profit & Loss`
  * **Options (3)**: `Options P&L`, `Black-Scholes` (theoretical premium + 5 Greeks: Delta, Gamma, Theta, Vega, Rho/IV inputs), `Contract Value`
  * **Investing (7)**: `SIP`, `Lumpsum`, `Fixed Deposit`, `CAGR`, `Inflation Impact`, `PPF`, `EMI`
  * **Currency (2)**: `Currency Converter` (11 major currencies using live/cached FX rates via `currency_rate_service.dart`), `Pip Value`
  * **Tax (3)**: `Short-Term Gains Tax` (STCG 15%), `Long-Term Gains Tax` (LTCG 10% above ₹1L exemption), `Trading Turnover` (Section 44AB audit threshold)
* **Direct Journal Bridge**: Trading calculators integrate with `calculator_journal_draft.dart` to push computed position sizing / P&L straight into a new Trade Journal entry.

#### Product Review
* **Strengths**: Exceptionally practical Indian + global trader toolkit under one filterable hub — especially Brokerage/Tax (STT/44AB turnover) alongside Black-Scholes Greeks and Draft-to-Journal handoff.
* **Caveat**: Tax templates (`STCG 15%`, `LTCG 10%`) should be reviewed against current statutory rates if tax brackets change per jurisdiction/fiscal year.

#### Demo: Size a Trade & Send Draft to Journal
1. Open **Calculators** (`https://app.alphajournal.in/calculators`) -> search or pick **Position Size**.
2. Enter Account Capital, Risk % (e.g., `1%`), Entry Price, and Stop-Loss Price.
3. Click **Draft to Journal** to create a pre-filled trade plan with exact share/lot quantity.

---

### Feature 7: Live Market Data, Screeners & Watchlists (`market_data`, `watchlists`)

* **Where it lives**: `lib/features/market_data/`, `lib/features/watchlists/`, `supabase/functions/market-quote-proxy`
* **Views (`MarketRootScreen`)**:
  * `market_overview` (indices + world markets + sector heatmap + market ribbon)
  * `market_news` (topic-filtered market articles with likes)
  * `market_movers` (top gainers / losers)
  * `market_instruments` (instrument catalog & deep inspection chart view)
  * `market_screeners` (filter & screen stocks)
  * `market_coverage` (market breadth & asset coverage)
  * **Watchlists** (`watchlists_page.dart`) for tracking saved symbols.

#### Product Review
* **Strengths**: Cleanly splits quotes via `market-quote-proxy` Edge Function to avoid browser CORS blocks on Yahoo Finance feeds; deep links (`/market/NVDA`) jump straight to an instrument sheet.
* **Requirements**: Deploy `market-quote-proxy` in Supabase Edge Functions for live quotes in Web production.

#### Demo: Screen & Open an Instrument
1. Open **Market Data** (`https://app.alphajournal.in/market`).
2. Switch tabs between **Overview**, **News**, **Movers**, and **Screeners**.
3. Click any symbol (or visit `https://app.alphajournal.in/market/RELIANCE.NS`) to view price action, fundamentals, and add to Watchlist.

---

### Feature 8: Trader Community Feed, Polls & Public Profiles (`community`)

* **Where it lives**: `lib/features/community/`, `lib/features/settings/presentation/pages/shared/trader_profile_preview_page.dart`
* **Routes (`community.alphajournal.in`)**:
  * **Feed** (`community_feed`), **Explore** (`community_explore`), **Network / Following** (`community_network`), **My Profile** (`community_profile`), **Bookmarks** (`community_bookmarks`)
  * **Public Posts** (`/community/post/:id?public=true`) & **Public Profiles** (`/@handle`)
* **Capabilities**:
  * Text posts, chart/image attachments, structured **Trade Setup Tiles**, interactive **Polls** with analytics dialogs, quote-posts/reposts, scheduled posts, nested reply trees (`community_reply_branch.dart`), horizontal emoji reactions + filterable reaction dialogs, AI comment/writing helper (`community_writing_assistant.dart`), post insights/reporting, and one-click public sharing with rich OG link previews.

#### Product Review
* **Strengths**: Dedicated `community.alphajournal.in` host with worker-injected per-post and per-profile Open Graph previews + dynamic sitemap indexing gives public posts genuine web discoverability on X/WhatsApp/LinkedIn/Google.
* **Moderation**: Posts and comments can be reported by traders and reviewed/removed by Admins in `Admin Console`.

#### Demo: Publish a Setup Post & Share Externally
1. Open `https://community.alphajournal.in/community_feed`.
2. Click **Create Post**, write your thesis, optionally toggle a **Trade Setup** card, **Poll**, or **Chart Image**, and publish.
3. Click **Share** on the post card to copy `https://community.alphajournal.in/community/post/<id>?public=true` (renders rich OG preview card when pasted on X, WhatsApp, or LinkedIn).

---

### Feature 9: End-to-End Encrypted Private Messaging (`messages`)

* **Where it lives**: `lib/features/messages/`, `lib/core/security/private_message_service.dart`
* **Capabilities**:
  * Real-time 1-on-1 trader messaging hosted canonically on `https://app.alphajournal.in/messages`.
  * Client-side **E2EE Identity** using WebCrypto / Curve25519 (`X25519` key agreement + `AES-GCM` payload encryption) backed by a user-chosen **Recovery Passphrase (>= 16 chars)** for cross-device key recovery.
  * Supports text, shared workspace/community records (`ShareToConversationDialog`), attachments, and failure/retry states.

#### Product Review
* **Strengths**: Plaintext message bodies never sit readable in the database; fixing X25519 key clamping + unifying `/messages` onto `app.alphajournal.in` ensures your WebCrypto key vault stays consistent across sessions.
* **Important User Requirement**: Your recovery passphrase cannot be reset by support — losing both your device storage and recovery passphrase permanently locks older encrypted messages on a new device.

#### Demo: Activate Encrypted Messaging & Send a DM
1. Open `https://app.alphajournal.in/messages` (or click **Message** on a trader's profile).
2. On first setup, enter and confirm a **16+ character Recovery Passphrase** -> click **Create encrypted identity** (store this passphrase in a password manager).
3. Search for a trader `@handle`, start a conversation, send text or attach a shared post/note, and click **Recover / Unlock** with the same passphrase if signing in from a second browser/device.

---

### Feature 10: AI Trading Copilot, Live Web Search, Voice Calls & 11 Trader Skills (`copilot`)

* **Where it lives**: `lib/features/copilot/`, `lib/core/ai/unified_ai_service.dart`, Supabase Edge Functions `ai-gateway`, `ai-chat`, `ai-voice`
* **Capabilities**:
  * **3 Reasoning Modes (`CopilotPromptMode`)**:
    * `auto` — standard fast LLM response + workspace context
    * `search` — triggers OpenAI Responses API live **`web_search`** for real-time news, earnings, macro events, and prices with web citations
    * `research` — deeper multi-step structured market/thesis synthesis
  * **Real-Time Voice Mode & Voice Calls (`VoiceController`, `VoicePanel`, `ai-voice`)**:
    * Live microphone capture + browser STT (`speech_to_text`) + OpenAI cloud transcription (`audio/transcriptions`) + neural TTS playback (`audio/speech`) via authenticated `ai-voice` Edge Proxy (keeping API keys server-side!).
    * Supports live `web_search` answers during voice sessions and tracks call history (`call_history.dart`).
  * **11 Built-In Trader Skills (`TraderSkill`, `/trader-*`)**:
    * `/trader-copycat` (13F institutional holdings), `/trader-news` (8-K & dated news), `/trader-pelosi` (congressional PTR disclosures), `/trader-analyst` (10-K/10-Q fundamentals), `/trader-screener` (rule ranking), `/trader-budget` (position sizing + cash buffer), `/trader-rebalance` (target drift), `/trader-tax` (FIFO/HIFO/wash-sale review), `/trader-alerts` (price/bell checks), `/trader-risk` (pre-trade limit checks), `/trader-broker` (paper order ticket draft preview only — never executes live broker orders).
  * **Workspace Memory, Custom Specialists, Saved Pages & Scheduled Prompts** (`memory_settings.dart`, `specialist_editor.dart`, `page_library.dart`, `schedule_panel.dart`).

#### Product Review
* **Strengths**: All OpenAI keys live securely inside Supabase Edge Function secrets (`ai-gateway` / `ai-chat` / `ai-voice`), zero secrets shipped in Flutter Web assets, real web search works in both text and voice, and `/trader-*` enforces strict pre-trade risk verification before ticket drafts.
* **Requirements**: Set `OPENAI_API_KEY` and `OPENAI_MODEL` (e.g., `gpt-4o`) in Supabase Edge Function Secrets and deploy `ai-gateway`, `ai-chat`, and `ai-voice`. Grant browser microphone permissions for Voice Calls.

#### Demo: Live Web Search & Voice Session
1. Open **AI Copilot** (`https://app.alphajournal.in/ai_copilot`).
2. Switch mode chip to **Search** -> ask `"What happened in Nifty 50 / NVDA today?"` -> receives live cited OpenAI `web_search` response.
3. Type `/trader-analyst AAPL` or open the **Trader Skills Picker** to chain fundamental -> screener -> risk workflows.
4. Click the **Voice / Call** button in the composer to speak a question aloud; `VoiceController` captures speech, queries OpenAI (with web search if needed), and speaks back via `ai-voice` TTS.

---

### Feature 11: Notifications & Web Push (`push-dispatch`, `web/push-sw.js`)

* **Where it lives**: `lib/core/widgets/app_scaffold.dart` (`AppGlobalNotificationsPage`), `web/push-sw.js`, `web/push_notifications.js`, `supabase/functions/push-dispatch`
* **Capabilities**:
  * In-app activity bell tracking community replies, reactions, follows, DMs, and system notices, deep-linking directly to the source record.
  * Privacy-preserving **Web Push** notifications via VAPID public/private keys (`WEB_PUSH_PUBLIC_KEY` / `WEB_PUSH_PRIVATE_KEY` in Supabase secrets) — displays generic activity prompt on lock screen without exposing private DM contents in push payloads.

#### Demo: Enable Push Alerts
1. Open **Settings -> Notifications** (`https://app.alphajournal.in/settings_notifications`).
2. Toggle **Browser Push Notifications** -> allow permission in your browser prompt.
3. Trigger a test reply/DM from another account to verify push delivery and click-to-focus window handling.

---

### Feature 12: Affiliate Partner Program (`affiliate_program`)

* **Where it lives**: `lib/features/affiliate_program/`, `lib/features/settings/presentation/pages/trader/trader_affiliate_perks_page.dart`, `affiliate.alphajournal.in`
* **Capabilities**:
  * Applicant intake form (`affiliate_application_page.dart`) reviewed by admins (`affiliate_reviews`).
  * Cross-subdomain referral attribution links (`https://alphajournal.in/r/<code>` and `/join/<code>`) tracked via consented 30-day attribution (`affiliate_attribution.dart`).
  * Partner Workspace with **Overview**, **Referrals**, **Marketing Assets**, **Payouts**, and **Affiliate Settings**.

#### Demo: Apply & Generate a Referral Link
1. Visit `https://affiliate.alphajournal.in/` (or **Settings -> Affiliate Perks** -> **Apply**).
2. Submit the partner application. Once approved by an Admin in `admin.alphajournal.in`, your top-bar role switcher unlocks **Affiliate** -> redirects to `https://affiliate.alphajournal.in/overview`.
3. Copy your `/r/<code>?utm_campaign=...` referral URL from **Referrals** and test in an incognito window — it records attribution and forwards visitors into signup.

---

### Feature 13: Account Settings, Security, Privacy, Billing & Help (`settings`)

* **Where it lives**: `lib/features/settings/`
* **Pages Included**:
  * **Profile & Public Preview** (`profile_settings_page.dart`, `trader_profile_preview_page.dart`)
  * **Security & Recovery** (`account_security_page.dart` — passwords, E2EE key/passphrase status, sessions)
  * **Privacy & Consent** (`privacy_settings_page.dart`, `blocked_users_page.dart`, `cookie_preferences_dialog.dart` — cookie/AdSense/affiliate attribution consent toggles, user blocking, `delete_account_page.dart`)
  * **Trading Preferences & Appearance** (`trading_preferences_page.dart`, `appearance_settings_page.dart` — dark/light/system theme, Comfortable vs Compact spacing density)
  * **Billing & Plans** (`billing_settings_page.dart`, `change_plan_page.dart`, `billing_history_page.dart`, `invoice_detail_page.dart`)
  * **Help & Publications** (`/help`, `/help/:document` — legal policies, encryption documentation, guides)

#### Demo: Customize Density, Theme & Consent
1. Go to **Settings -> Appearance** (`https://app.alphajournal.in/settings_appearance`) to toggle Dark/Light theme and `Comfortable` vs `Compact` density.
2. Open **Settings -> Privacy** (`https://app.alphajournal.in/settings_privacy`) to manage blocked traders or review cookie consent.

---

### Feature 14: Institutional Admin Console (`admin_console`)

* **Where it lives**: `lib/features/admin_console/`, `supabase/functions/admin-delete-user`, `admin.alphajournal.in`
* **Pages Included**:
  * **Admin Overview** (`admin_overview_page.dart`)
  * **Team Seats & Roles** (`admin_team_seats_page.dart`, `organization_settings_page.dart`, `admin_user_detail_page.dart`)
  * **Affiliate Approvals** (`affiliate_approvals_page.dart` — approve/reject pending partner applications)
  * **Content & Record Moderation** (`admin_records_page.dart` covering comments, subscriptions, notes, journal, strategies, messages, AI requests, deletion requests)
  * **Publishing & Analytics** (`admin_publishing_page.dart`, `admin_analytics_page.dart`)
  * **Risk, Compliance & Audit Logs** (`admin_risk_compliance_page.dart`, `desk_risk_page.dart`, `admin_audit_log_page.dart`, `admin_settings_page.dart`)

#### Product Review
* **Security & Isolation**: Protected client-side via `CustomerRoute.canAccessDestination` (requires `user_admin` / admin key), isolated on `admin.alphajournal.in`, and automatically served with `Disallow: /` in `robots.txt` + `X-Robots-Tag: noindex, nofollow` HTTP headers by Cloudflare Worker.
* **Requirements**: User deletion triggers `admin-delete-user` Edge Function (requires Supabase Service Role key server-side).

#### Demo: Approve an Affiliate & Inspect Audit Logs
1. Sign in with an authorized Admin account -> automatically opens `https://admin.alphajournal.in/overview`.
2. Open **Affiliate Reviews** -> inspect pending applicant -> click **Approve**.
3. Open **Audit Log** (`org_audit`) or **Records -> Subscriptions** (`admin_subscriptions`) to verify logged administrative actions.

---

## 3. Quick Operations & Troubleshooting Checklist

| Feature | Required Secret / Config | Where to Set |
| --- | --- | --- |
| Multi-Subdomain Login & OAuth | `https://*.alphajournal.in/**` & `https://alphajournal.in/**` Redirect URLs | Supabase Auth -> URL Configuration |
| Edge Sitemap & OG Cards | `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Cloudflare Worker Runtime Variables |
| AI Copilot, Web Search & Voice | `OPENAI_API_KEY`, `OPENAI_MODEL` (e.g. `gpt-4o`) | Supabase Edge Secrets + deploy `ai-gateway`, `ai-chat`, `ai-voice`, `note-ai-refactor` |
| Web Push Notifications | `WEB_PUSH_PUBLIC_KEY`, `WEB_PUSH_PRIVATE_KEY`, `WEB_PUSH_SUBJECT` | Supabase Secrets + Cloudflare Build/Client public key |
| Subscriptions / Billing | `RAZORPAY_*` / `REVENUECAT_*` webhook keys | Supabase Edge Secrets |
