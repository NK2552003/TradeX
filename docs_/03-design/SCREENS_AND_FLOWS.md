# Screens & Flows — TraderHub
## UI/UX Handoff: Full Screen Inventory, Contents, and Pipelines

This doc is the UI/UX designer handoff: every screen in the app, what each screen contains, how screens connect, and the interaction pipeline for each feature. Product context: [PRD.md](./PRD.md). Data backing every field: [API_DATA_MODEL.md](./API_DATA_MODEL.md). Deeper flows for Strategy Notes/Analyzer: [NOTES_ANALYZER.md](./NOTES_ANALYZER.md). A flat per-screen content reference (no diagrams) is also available in [SCREEN_CONTENTS.md](./SCREEN_CONTENTS.md). Per-screen (not module-level) mermaid diagrams, including every Loading/Empty/Error/Toast state individually, live in [UI_FLOW_DIAGRAMS.md](./UI_FLOW_DIAGRAMS.md) — this doc stays at the module level; that one goes screen-by-screen.

Tier gating shorthand: **F** = Free, **P** = Premium, **E** = Enterprise (post-MVP, see ROADMAP.md — included here for completeness since the tier is priced/scoped in the PRD, but build it last).

---

## 0. Global Navigation Map

```mermaid
flowchart TD
    Splash[Splash / Onboarding] --> Auth{Logged in?}
    Auth -- No --> SignIn[Sign Up / Log In]
    Auth -- Yes --> Shell[App Shell — bottom nav]
    SignIn --> Shell

    Shell --> TabJournal[Tab: Journal]
    Shell --> TabStrategies[Tab: Strategies]
    Shell --> TabWatchlists[Tab: Watchlists]
    Shell --> TabPortfolio[Tab: Portfolio]
    Shell --> TabCommunity[Tab: Community]
    Shell --> TabInsights[Tab: Insights]
    Shell --> TabProfile[Tab: Profile / Settings]

    TabJournal --> JournalList[Journal List]
    JournalList --> JournalDetail[Journal Entry Detail]
    JournalList --> JournalCreate[Journal Entry Create/Edit]

    TabStrategies --> StrategyList[Strategy List]
    StrategyList --> StrategyDetail[Strategy Detail]
    StrategyList --> StrategyEditor[Strategy Editor]
    StrategyList --> Analyzer[Strategy Analyzer]
    StrategyList --> Graph[Graph View]
    StrategyDetail --> VersionHistory[Version History]

    TabWatchlists --> WatchlistList[Watchlist List]
    WatchlistList --> WatchlistDetail[Watchlist Detail]
    WatchlistDetail --> AddTicker[Add Ticker]
    WatchlistDetail --> PriceAlert[Price Alert Setup]

    TabPortfolio --> PortfolioHome[Portfolio Dashboard]
    PortfolioHome --> StrategyBreakdown[Strategy Performance Breakdown]
    StrategyBreakdown --> Analyzer

    TabCommunity --> FeedHome[Community Feed]
    FeedHome --> PostDetail[Post Detail]
    FeedHome --> CreatePost[Create Post]
    FeedHome --> SavedPosts[Saved Posts]
    FeedHome --> DMList[Direct Messages List]
    PostDetail --> PublicProfile[Public Profile]
    PublicProfile --> FollowersList[Followers / Following List]
    PublicProfile -->|Message, Premium/Enterprise viewer| ConvoDetail[Conversation Detail]
    DMList --> NewMessage[New Message]
    DMList --> ConvoDetail
    NewMessage --> ConvoDetail

    TabInsights --> TickerDetail[Ticker Search / Detail]
    TickerDetail --> AIAssistant[AI Trading Assistant]
    TabInsights --> DailyDigest[Daily Digest]

    TabProfile --> OwnProfile[Own Profile]
    OwnProfile --> FollowersList
    OwnProfile --> Settings[Settings]
    OwnProfile --> Paywall[Plan Comparison / Paywall]
    Paywall --> Checkout[Upgrade / Checkout]
    OwnProfile --> ManageSub[Manage Subscription]
    Settings --> NotificationCenter[Notification Center]
    Settings --> NotificationPrefs[Notification Preferences]
    Settings -->|Log Out| Splash
    Settings -->|Delete Account, confirmed| Splash

    Settings -.Enterprise only.-> OrgDashboard[Org Dashboard]
    OrgDashboard -.-> TeamMgmt[Team Management]
    OrgDashboard -.-> AdminControls[Admin Controls]
    OrgDashboard -.-> OrgAnalytics[Organization Analytics]
    OrgDashboard -.-> Branding[Branding Settings]
    OrgDashboard -.-> APIKeys[API Access / Key Management]
```

Bottom nav tabs: **Journal · Strategies · Watchlists · Portfolio · Community · Insights · Profile** (7 tabs — consider collapsing Strategies under Journal or Portfolio under Insights in a "More" tab if the nav bar feels crowded; flagged for design review). Enterprise screens (dotted lines above) only appear for org-admin accounts once Enterprise ships — see ROADMAP.md.

---

## 0.1 Cross-cutting state flow (applies inside every screen below)
Every screen in every module diagram that fetches data silently passes through this same state machine — shown once here rather than redrawn in each module's diagram. Full per-screen Loading/Error/Empty/Toast tagging: [SCREENS_MOBILE.md](./SCREENS_MOBILE.md)'s cross-cutting section and each screen's own listing.

```mermaid
flowchart TD
    A[Screen mounted / pull-to-refresh] --> B[Loading: skeleton placeholders]
    B --> C{Fetch result}
    C -- Data present --> D[Loaded: normal content]
    C -- No data --> E[Empty state: icon + message + CTA]
    C -- Fetch failed --> F[Error state: message + Retry]
    F -->|tap Retry| B
    D -->|user saves / deletes / completes an action| G{Result}
    G -- Success --> H[Toast confirmation, optionally with Undo]
    G -- Failure --> I[Inline error or error toast, form/data preserved]
```

## 0.2 Report / Block / Mute (recurring pattern — not redrawn per module)
This exact pattern appears three separate places (Public Profile overflow, Post Detail overflow, Conversation Detail overflow) — one flow, reused everywhere it's mentioned in the module sections below.

```mermaid
flowchart TD
    A[Overflow menu: Report / Block / Mute] --> B{Which action?}
    B -- Report --> C[Report reason picker] --> D[Submit] --> E[Toast: Report submitted]
    B -- Block --> F[Confirmation dialog: this stops messages and hides content both directions]
    F -->|confirm| G[blocks row created — API_DATA_MODEL.md § 1] --> H[Toast: User blocked]
    B -- Mute --> I[No confirmation needed — reversible, low-stakes] --> J[Toast: User muted]
    G -.affects.-> K[Any open/future Direct Messages conversation between the two — input bar shows blocked state]
    G -.affects.-> L[Blocker's own Community feed — blocked user's posts filtered client-side, DATABASE_ERD.md § 2]
```

---

## 1. Auth & Profile

| Screen | Tier | Contains |
|---|---|---|
| Splash / Onboarding | All | App logo, brief value prop (five pillars), Get Started / Log In buttons |
| Sign Up | All | Email/password fields, Google/Apple OAuth buttons, handle picker, ToS/privacy checkbox |
| Log In | All | Email/password fields, OAuth buttons, "Forgot password?" link |
| Forgot Password | All | Email input, reset-link confirmation state |
| Own Profile | All | Avatar/profile picture, handle, bio, experience level, trading style, follower/following counts, public statistics (from Portfolio Dashboard, if public), subscription tier badge, "Public Journals" toggle, tabs/links to their public posts and public Strategy Notes, tier upgrade CTA (Free only), Settings entry point |
| Public Profile (other user) | All | Avatar, handle, bio, experience level, trading style, follower/following counts, public statistics (if shared), their public posts, their public Strategy Notes, their public journal entries (if `public_journals` is on), Follow/Unfollow button, Report/Block |
| Settings | All | Notification preferences (per category — see § 9), account (email/password change), subscription management entry, "Public Journals" visibility toggle, log out, delete account; Enterprise-only: link to Org Dashboard |

```mermaid
flowchart TD
    A[Splash] --> B{Has account?}
    B -- No --> C[Sign Up]
    B -- Yes --> D[Log In]
    C --> E[Verify email / OAuth callback]
    D --> F{Credentials valid?}
    F -- No --> D
    F -- Yes --> G[App Shell]
    E --> G
    D -- Forgot password --> H[Forgot Password] --> D
    G --> I[Own Profile]
    I -->|tap avatar/handle/bio| J[Inline edit, saves via Toast]
    I -->|tap Followers/Following count| K[Followers / Following List]
    I -->|tap Settings icon| L[Settings]
    L -->|Change Email/Password| M[Inline form, Toast on save]
    L -->|toggle Public Journals| L
    L -->|Notification preferences row| N[Notification Preferences]
    L -->|Log Out| O[Confirmation dialog] -->|confirm| B
    L -->|Delete Account| P[Confirmation dialog, destructive] -->|confirm| Q[Account deleted] --> B
    R[Any user's avatar elsewhere in the app] --> S[Public Profile]
    S -->|overflow: Report/Block| T[Report / Block / Mute flow — § 0.2]
    S -->|Follow/Unfollow| S
```

---

## 2. Trading Journal

| Screen | Tier | Contains |
|---|---|---|
| Journal List | F (limited count) / P+ (unlimited) | Search bar, filter chips (ticker, date, tag, strategy, outcome), entry cards showing ticker, date, outcome badge (win/loss/breakeven), P/L, snippet of notes; FAB "New Entry" |
| Journal Entry Detail | F/P/E | Ticker, entry/exit price, stop loss, target, size, side, P/L, outcome badge (tap to override), screenshots gallery, notes, psychology, mistakes made, lessons learned, linked strategy (tap to open), tags, "make public" toggle, edit/delete actions, "link to another entry" action (graph) |
| Journal Entry Create/Edit | F/P/E | Ticker input (autocomplete), screenshot attach button → auto-fill flow, trade fields (entry/exit/stop loss/target/size/side — editable pre-fill), P/L (auto-computed or manual), notes rich text area, psychology/mistakes/lessons text areas, tags input, strategy picker (link existing or create new), save/cancel |

```mermaid
flowchart TD
    A[Journal List] -->|tap FAB| B[Journal Entry Create]
    A -->|tap entry card| C[Journal Entry Detail]
    A -->|tap search/filter icon| Z[Filter bottom sheet: ticker/date/tag/strategy/outcome] -->|Apply| A
    B --> D{Attach screenshot?}
    D -- Yes --> E[Upload -> Claude Vision parses] --> F[Fields pre-filled, editable]
    D -- No --> F
    F --> G[Fill notes / psychology / mistakes / lessons / tags]
    G --> H{Link strategy?}
    H -- Yes --> I[Pick or create Strategy Note]
    H -- No --> J[Save] --> Toast1[Toast: Entry saved]
    I --> J
    Toast1 --> A
    C -->|edit| B
    C -->|override outcome| K[Outcome picker: win/loss/breakeven] --> C
    C -->|toggle Make Public| C
    C -->|Link to another entry| Y[Pick target entry] --> Y2[journal_entry_link created] --> C
    C -->|delete| Del[Confirmation dialog] -->|confirm| A2[Toast: Entry deleted — Undo] --> A
    C -->|AI Trade Review, Premium| AITR[Trade Review results — § 8]
```

---

## 3. Strategy Notes & Analyzer

| Screen | Tier | Contains |
|---|---|---|
| Strategy List | F: locked/upsell · P/E: full | Category filter chips, favorite toggle per card, cards showing title, category, visibility icon (private/public), win-rate summary if entries linked; FAB "New Strategy"; entry points to Strategy Analyzer and Graph View |
| Strategy Detail | P/E (read-only preview shown to Free with upsell) | Title, rendered rich text content, embedded charts/images, category, favorite toggle, visibility toggle (private/public), AI summary block (Premium — "Regenerate" button), linked journal entries count/link to Analyzer, "View version history" link, edit/delete |
| Strategy Editor | P/E | Rich text editor toolbar (headings, lists, images, embeds), title field, category picker/create, visibility toggle, save/cancel; autosave-to-draft indicator |
| Version History | P/E | List of versions (number, timestamp), tap to preview, "Restore this version" action |
| Strategy Analyzer | P/E | Per-strategy rollup cards: win rate, avg P/L, entry count, outcome breakdown (win/loss/breakeven chart); tap card → filtered journal entry list for that strategy |
| Graph View | P/E | Interactive force-directed graph canvas: entry nodes, strategy nodes, ticker nodes, edges (explicit entry-links + derived strategy/ticker links); tap node to open detail; pinch/zoom/pan; "link entries" mode |

```mermaid
flowchart TD
    A[Strategy List] -->|FAB| B[Strategy Editor: New]
    A -->|tap card| C[Strategy Detail]
    B --> D[Write content, embed images, set category/visibility]
    D --> E[Save -> v1 in strategy_versions] --> Toast1[Toast: Strategy saved]
    Toast1 --> A
    C -->|edit| F[Strategy Editor: Edit]
    F --> G[Save -> new version] --> C
    C -->|version history| H[Version History]
    H -->|restore| F
    C -->|regenerate AI summary, Premium| I[strategy-ai-summary call] --> C
    C -->|delete| Del[Confirmation dialog] -->|confirm| Toast2[Toast: Strategy deleted] --> A
    A -->|Analyzer tab| J[Strategy Analyzer]
    J -->|tap strategy card| K[Filtered journal list]
    K -->|tap entry| L[Journal Entry Detail]
    A -->|Graph View| M[Graph View]
    M -->|tap strategy node| J
    M -->|tap entry node| L
    M -->|Link Entries mode: pick 2 nodes| M2[Confirm bottom sheet] --> M
```

---

## 4. Watchlists

| Screen | Tier | Contains |
|---|---|---|
| Watchlist List | F: 1 watchlist · P/E: unlimited | List of named watchlists, ticker-count per watchlist, favorites shortlist section at top, FAB "New Watchlist" |
| Watchlist Detail | F: no alerts · P/E: full | Ticker rows (symbol, last price, day change), per-ticker notes indicator, category grouping/filter, favorite star per ticker, swipe-to-remove, "Add Ticker" button |
| Add Ticker | F/P/E | Ticker search/autocomplete, category assignment, optional note field, "Set price alert" toggle |
| Price Alert Setup | P/E (Free: locked, upsell) | Threshold price input (above/below), notification preview, save/cancel |

```mermaid
flowchart TD
    A[Watchlist List] -->|FAB| B[Create Watchlist: name] --> Toast1[Toast: Watchlist created] --> A
    A -->|tap watchlist| C[Watchlist Detail]
    A -->|attempt 2nd watchlist, Free| Up1[Upsell interstitial]
    C -->|tap watchlist name| Rename[Rename inline] --> C
    C -->|overflow: delete watchlist| DelWl[Confirmation dialog] -->|confirm| A
    C -->|Add Ticker| D[Add Ticker]
    D --> E{Set price alert?}
    E -- Yes, Premium --> F[Price Alert Setup] --> Toast2[Toast: alert saved] --> C
    E -- Yes, Free --> G[Upsell to Premium] --> C
    E -- No --> Toast3[Toast: ticker added] --> C
    C -->|swipe ticker row| Remove[Toast: Ticker removed — Undo] --> C
    C -->|tap ticker| H[Ticker Detail — Insights module]
    C -->|favorite star| C
```

---

## 5. Portfolio Dashboard

| Screen | Tier | Contains |
|---|---|---|
| Portfolio Dashboard | F: headline stats only · P/E: full | Headline stat cards (Total P/L, Win Rate, Avg RR, Max Drawdown), time-range toggle (weekly/monthly), Equity Curve chart, Monthly Growth chart, Win/Loss Distribution chart, Best Trade / Worst Trade cards (tap to open entry), "Strategy Performance" section entry point (Premium) |
| Strategy Performance Breakdown | P/E | Per-strategy performance cards (reuses Strategy Analyzer data from § 3), sortable by win rate/P&L/entry count |

```mermaid
flowchart TD
    A[Portfolio Dashboard] --> B[Fetch portfolio_stats view + journal_entries for charts]
    B --> C[Render headline stats]
    B --> D[Render Equity Curve / Monthly Growth / Win-Loss charts]
    B -->|fewer than 5 entries with pnl| E2[Muted placeholder charts, DESIGN_SYSTEM.md § 13]
    A -->|tap Best/Worst Trade| E[Journal Entry Detail]
    A -->|Strategy Performance, Premium| F[Strategy Performance Breakdown]
    F -->|tap strategy| G[Strategy Analyzer filtered view]
    A -->|Free tier| H[Headline stats only, upsell banner for breakdowns/charts]
    A -->|time-range toggle| A
```

---

## 6. Community

| Screen | Tier | Contains |
|---|---|---|
| Community Feed | F: limited reads/day, limited interaction · P/E: unlimited | Reverse-chron post cards (avatar, handle, ticker tag, content-type badge, text, optional image, like/comment/save counts), content-type filter chips (Trade Analysis, Educational, Psychology, Strategies, News, Market Discussion), FAB "New Post", daily-read-limit banner (Free only) |
| Post Detail | F/P/E | Full post content/image, content-type badge, comment thread, comment input, like button, save/bookmark button, report/block/mute on the author |
| Create Post | F/P/E | Text area, content-type picker, optional ticker tag, optional image/screenshot attach, post/cancel |
| Saved Posts | F/P/E | List of the user's bookmarked posts, same card format as feed, unsave action |
| Public Profile | (see § 1) | — |
| Followers / Following List | F/P/E | Searchable list of users, follow/unfollow inline |

```mermaid
flowchart TD
    A[Community Feed] -->|tap post| B[Post Detail]
    A -->|FAB| C[Create Post]
    C -->|Post| Toast1[Toast: Posted] --> A
    C -->|Cancel, has content| CancelC[Discard confirmation dialog] --> A
    A -->|filter by content type| A
    B -->|comment| B
    B -->|like| B
    B -->|save| B
    B -->|tap author| D[Public Profile]
    B -->|overflow: Report/Block/Mute| RBM[Report / Block / Mute flow — § 0.2]
    D -->|follow/unfollow| D
    D -->|followers count| E[Followers / Following List]
    E -->|search| E
    E -->|tap a user row| D
    E -->|Following tab, empty| E2[Empty state -> CTA to Community Feed]
    A -->|Saved tab| F[Saved Posts]
    F -->|tap post| B
    F -->|swipe unsave| F
    A -->|Free: hits daily read limit| G[Upsell to Premium]
```

---

## 7. Direct Messages — P/E only

| Screen | Tier | Contains |
|---|---|---|
| Direct Messages List | P/E (Free: locked) | Conversation rows sorted by recent activity (avatar, handle, last message preview, timestamp, unread indicator), new-message icon, swipe-to-mute/delete (hides locally, doesn't delete for the other participant) |
| Conversation Detail | P/E | Chat thread (real-time via Supabase Realtime), message bubbles with read receipts, message input bar, tier-downgrade and blocked-state variants replacing the input bar when sending isn't currently allowed |
| New Message | P/E | Handle search, tap a result to open an existing or new Conversation Detail |

```mermaid
flowchart TD
    A[Direct Messages List] -->|new-message icon| B[New Message]
    B -->|pick existing contact| C{Conversation already exists?}
    C -- Yes --> D[Conversation Detail: existing thread]
    C -- No --> E[Conversation Detail: empty thread]
    A -->|tap conversation row| D
    D -->|send message| D
    D -->|failed send| D2[Inline retry on that message bubble] --> D
    D -->|tap counterpart avatar| F[Public Profile]
    F -->|Message button, Premium/Enterprise viewer| C
    F -->|Message button, Free viewer| G[Upsell interstitial]
    A -->|Free tier| H[Locked full-screen state -> Plan Comparison]
    A -->|swipe row| Mute[Mute / Delete locally] --> A
    D -->|overflow: Report/Block/Mute| RBM[Report / Block / Mute flow — § 0.2]
    D -->|sender downgrades mid-thread| I[Input bar replaced with resubscribe strip, history stays visible]
    D -->|either party blocks the other| J[Input bar replaced with neutral blocked message]
```

---

## 8. AI Trading Assistant

| Screen | Tier | Contains |
|---|---|---|
| Ticker Search / Detail | F: basic analytics only · P/E: full | Ticker search bar, price chart, key indicators (RSI, MACD, SMA), news/sentiment summary block (Premium), "Ask AI" entry point (Premium), basic analytics view (Free) |
| AI Trading Assistant (chat) | P/E (Free: locked, upsell) | Chat-style thread scoped to a ticker, a watchlist, or the user's portfolio; message input; quick-action chips (risk-to-reward analysis, watchlist insights, AI Q&A); disclaimer footer on every AI message |
| Trade Review results | P/E | Triggered from Journal Entry Detail — AI commentary on the completed trade vs. the stated plan, disclaimer footer |
| AI Strategy Review results | P/E | Triggered from Strategy Detail — shows Claude's clarity/consistency review, flagged ambiguous rules, dismiss/re-run |
| AI Journal Analysis results | P/E | Date range picker, optional strategy filter, pattern summary (recurring mistakes, psychology trends, tag/outcome correlations), disclaimer footer |
| Weekly / Monthly Performance Review | P/E | AI-generated narrative layered over Portfolio Dashboard numbers, delivered in-app and as a notification |
| Daily Digest | P/E | Top movers list, AI summary block, disclaimer footer; delivered as push notification + in-app screen |

```mermaid
flowchart TD
    A[Insights Tab] --> B[Ticker Search]
    B --> C[Ticker Detail: chart + indicators + news/sentiment]
    C -->|Ask AI, Premium| D[AI Trading Assistant chat]
    C -->|Free| E[Basic analytics only, upsell banner]
    C -->|price/indicator fetch fails| C2[Error state — no cached fallback yet, INTEGRATIONS.md § 2]
    A -->|Daily Digest, Premium| F[Daily Digest screen]
    A -->|Weekly/Monthly Review, Premium| Rv[Performance Review screen]
    G[Strategy Detail] -->|AI Strategy Review, Premium| H[Review results]
    I[Journal List] -->|AI Journal Analysis, Premium| J[Pick date range/strategy] --> K[Analysis results]
    K -->|no entries in range| K2[Empty state -> widen date range]
    L[Journal Entry Detail] -->|Trade Review, Premium| M[Trade Review results]
    N[Watchlist Detail] -->|Watchlist Insights, Premium| D
    D -->|AI call fails| D2[Inline retry on that exchange] --> D
```

---

## 9. Notifications

| Screen | Tier | Contains |
|---|---|---|
| Notification Center | F/P/E | Chronological list grouped by category (market alert, community update, direct message, strategy reminder, AI recommendation, subscription reminder), read/unread state, tap-to-deep-link into the relevant screen, mark-all-read action |
| Notification Preferences | F/P/E | Per-category toggle (market alerts, community updates, direct messages, strategy reminders, AI recommendations, subscription reminders), push vs. in-app-only option per category |

```mermaid
flowchart TD
    A[Any screen] -->|tap bell icon| B[Notification Center]
    B -->|tap notification| C[Deep link to relevant screen]
    B --> D[Mark all read]
    B -->|no notifications| B2[Empty state: You're all caught up]
    E[Settings] --> F[Notification Preferences]
    F -->|toggle category| Toast1[Toast: preference saved] --> F
    G[price-alerts job] -.writes notification.-> B
    H[Community activity] -.writes notification.-> B
    Msg[notify_new_message trigger] -.writes notification.-> B
    I[AI recommendation ready] -.writes notification.-> B
    J[Subscription event] -.writes notification.-> B
```

---

## 10. Subscriptions

| Screen | Tier | Contains |
|---|---|---|
| Plan Comparison / Paywall | All | Free / Premium / Enterprise columns, feature checklist matching PRD.md § 5.10, monthly/annual toggle for Premium, "Contact us" for Enterprise, Upgrade CTA |
| Upgrade / Checkout | All | RevenueCat-driven native purchase sheet (App Store/Play) or Stripe checkout (web), plan/billing-cycle/price confirmation, success state |
| Manage Subscription | P/E | Current plan, billing cycle, renewal date, cancel/downgrade link (deep-links to store subscription management on mobile), billing history (web/Stripe only) |

```mermaid
flowchart TD
    A[Any locked feature] -->|upsell tap| B[Plan Comparison]
    B -->|Upgrade to Premium| C[Checkout: monthly or annual]
    B -->|Enterprise, Contact us| D[Contact form / email link]
    C --> E{Purchase successful?}
    E -- Yes --> F[Return to originating screen, feature unlocked]
    E -- No --> B
    G[Settings] --> H[Manage Subscription]
    H -->|cancel/downgrade| CancelConfirm[Confirmation dialog] -->|confirm| I[Store subscription management] --> Toast1[Toast: cancellation processed]
```

---

## 11. Enterprise (post-MVP — build last, see ROADMAP.md)

| Screen | Tier | Contains |
|---|---|---|
| Org Dashboard | E | Org name/logo, member count, quick links to Team Management, Admin Controls, Org Analytics, Branding, API Keys |
| Team Management | E | Member list (name, role, seat status), invite member, remove member, role assignment |
| Admin Controls | E | Org-wide feature toggles, content moderation queue for org-internal posts (if applicable), device licensing list |
| Organization Analytics | E | Aggregate usage across org members: activation, engagement, AI usage volume |
| Branding Settings | E | Logo upload, color theme, custom domain (web) |
| API Access / Key Management | E | List of issued API keys, scopes, create/revoke key, usage logs |

```mermaid
flowchart TD
    A[Org Dashboard] --> B[Team Management]
    A --> C[Admin Controls]
    A --> D[Organization Analytics]
    A --> E[Branding Settings]
    A --> F[API Access / Key Management]
    B -->|invite| G[Invite Member form] --> Toast1[Toast: invite sent] --> B
    B -->|swipe row| Remove[Confirmation dialog] -->|confirm| Toast2[Toast: member removed] --> B
    C -->|toggle feature flag| Toast3[Toast: setting saved] --> C
    C -->|review flagged item| Review[Approve / Remove / Escalate] --> C
    D -->|change date range| D
    E -->|edit logo/theme/domain| Save[Tap Save] --> Toast4[Toast: branding saved] --> E
    F -->|create key| H[Key created — shown once] --> Toast5[Toast: Copied to clipboard] --> F
    F -->|swipe row| Revoke[Confirmation dialog] -->|confirm| Toast6[Toast: key revoked] --> F
```

Note: Enterprise's data model (`organizations`, `organization_members`, `api_keys`) is not yet specced in API_DATA_MODEL.md — flagged there and in ROADMAP.md as a design item to complete before this module is built.

---

## 12. Screen Count Summary
- Auth & Profile: 7 screens
- Trading Journal: 3 screens
- Strategy Notes & Analyzer: 6 screens
- Watchlists: 4 screens
- Portfolio Dashboard: 2 screens
- Community: 5 screens (1 shared with § 1)
- Direct Messages: 3 screens
- AI Trading Assistant: 7 screens
- Notifications: 2 screens
- Subscriptions: 3 screens
- Enterprise (post-MVP): 6 screens

**MVP total (§ 1–10, excluding Enterprise): ~42 screens.** Enterprise adds 6 more when built. Recurring cross-module patterns (§ 0.1 state flow, § 0.2 Report/Block/Mute) are documented once rather than redrawn per screen — see [UI_FLOW_DIAGRAMS.md](./UI_FLOW_DIAGRAMS.md) for the fully expanded per-screen version of every diagram in this doc.
