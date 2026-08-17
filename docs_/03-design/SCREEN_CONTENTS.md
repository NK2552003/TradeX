# Screen Contents — TraderHub
## Flat Reference: Every Screen and What's In It

Companion to [SCREENS_AND_FLOWS.md](./SCREENS_AND_FLOWS.md) (which has navigation + pipeline diagrams). This doc skips the diagrams and just lists, screen by screen, the elements a designer needs to lay out. Tier gating shorthand: **F** = Free, **P** = Premium, **E** = Enterprise (post-MVP). Field sources trace back to [API_DATA_MODEL.md](./API_DATA_MODEL.md).

---

## 1. Auth & Profile

### Splash / Onboarding — All
- App logo / wordmark
- Short value-prop copy (one line per pillar: AI Assistant, Journal & Strategy Notes, Watchlists, Portfolio Dashboard, Community)
- Primary CTA: "Get Started"
- Secondary CTA: "Log In"

### Sign Up — All
- Email field
- Password field (+ strength indicator)
- Handle picker (with live availability check)
- "Continue with Google" button
- "Continue with Apple" button
- ToS / Privacy Policy checkbox (required)
- Submit button
- Link to Log In

### Log In — All
- Email field
- Password field
- "Continue with Google" / "Continue with Apple" buttons
- "Forgot password?" link
- Submit button
- Link to Sign Up

### Forgot Password — All
- Email field
- Submit button
- Confirmation state ("check your email") after submit

### Own Profile — All
- Avatar / profile picture (editable)
- Handle (editable)
- Bio (editable, multi-line)
- Experience level selector (beginner / intermediate / advanced / pro)
- Trading style selector (day trading / swing / scalping / options / forex / crypto / other)
- Subscription tier badge (Free / Premium / Enterprise)
- Follower count / Following count (tap to open Followers/Following list)
- Public statistics block (win rate, total P/L — only shown if the user has opted to share; pulls from Portfolio Dashboard)
- "Public Journals" toggle (controls whether any `is_public` journal entries surface here)
- Tabs or sections: Posts / Strategy Notes (public ones) / Public Journal Entries
- "Upgrade to Premium" CTA (Free tier only)
- Settings entry point (icon/button)

### Public Profile (other user) — All
- Avatar, handle, bio, experience level, trading style
- Follower / Following counts
- Public statistics block (if the profile owner shares it)
- Tabs or sections: Posts / Public Strategy Notes / Public Journal Entries
- Follow / Unfollow button
- Message button (Premium/Enterprise viewers only — Direct Messages, § 7; Free viewers see an upsell instead)
- Report / Block menu (overflow icon)

### Settings — All
- Notification preferences entry point (per category — see § 8)
- Account section: change email, change password
- "Public Journals" visibility toggle
- Subscription management entry point
- Log out button
- Delete account (destructive, confirmation required)
- Enterprise-only: "Organization" link → Org Dashboard

---

## 2. Trading Journal

### Journal List — F (limited entries) / P+ (unlimited)
- Search bar (free text)
- Filter chips: ticker, date range, tag, strategy, outcome
- Entry cards, each showing: ticker, date, outcome badge (win/loss/breakeven color-coded), P/L value, one-line notes snippet
- Empty state (no entries yet — prompt to create first entry)
- Floating action button: "New Entry"
- Free-tier entry-count banner when near/at limit

### Journal Entry Detail — F/P/E
- Ticker (with link to Ticker Detail)
- Entry price, exit price, stop loss, target, size, side (long/short)
- P/L value
- Outcome badge (win/loss/breakeven) — tappable to open outcome override picker
- Screenshot gallery (one or more images, tap to zoom)
- Notes (free text)
- Trading psychology section
- Mistakes made section
- Lessons learned section
- Linked strategy chip (tap to open Strategy Detail)
- Tags (chips)
- "Make public" toggle
- Edit button / Delete button (with confirmation)
- "Link to another entry" action (adds a graph edge)
- Entry point to Trade Review (AI, Premium)

### Journal Entry Create/Edit — F/P/E
- Ticker input with autocomplete
- "Attach screenshot" button (camera or gallery picker)
- Trade fields: entry price, exit price, stop loss, target, size, side — pre-filled if screenshot parsed, all editable
- P/L (auto-computed from fields, editable override)
- Notes text area
- Psychology text area
- Mistakes made text area
- Lessons learned text area
- Tags input (add/remove chips)
- Strategy picker (search existing or "create new")
- Save / Cancel buttons

---

## 3. Strategy Notes & Analyzer

### Strategy List — F: locked/upsell · P/E: full
- Category filter chips
- Favorite toggle (star icon) per card
- Strategy cards: title, category, visibility icon (private/public), win-rate summary chip if entries are linked
- Floating action button: "New Strategy"
- Entry points: "Analyzer" tab, "Graph View" tab
- Free-tier locked state with upsell banner

### Strategy Detail — P/E (read-only preview + upsell for Free)
- Title
- Rendered rich-text content (with embedded charts/images inline)
- Category chip
- Favorite toggle
- Visibility toggle (private/public)
- AI summary block (Premium) with "Regenerate" button
- Linked journal entries count, tap to open filtered Analyzer view
- "View version history" link
- Edit button / Delete button

### Strategy Editor — P/E
- Title field
- Rich text editor toolbar: headings, bold/italic, lists, image embed, chart embed
- Category picker (select existing or create new)
- Visibility toggle (private/public)
- Autosave-to-draft indicator
- Save / Cancel buttons

### Version History — P/E
- List of versions: version number, timestamp
- Tap a version to preview its content (read-only)
- "Restore this version" button (creates a new latest version from the old content)

### Strategy Analyzer — P/E
- Per-strategy rollup cards: win rate, avg P/L, entry count, outcome breakdown mini-chart (win/loss/breakeven)
- Sort control (by win rate / P&L / entry count)
- Tap a card → filtered journal entry list for that strategy

### Graph View — P/E
- Interactive canvas: entry nodes, strategy nodes, ticker nodes
- Edges: explicit entry-to-entry links (user-drawn), derived entry-to-strategy edges, derived entry-to-ticker edges
- Pinch-to-zoom / pan
- Tap a node → opens its detail screen
- "Link entries" mode toggle (pick two entry nodes to connect)

---

## 4. Watchlists

### Watchlist List — F: 1 watchlist · P/E: unlimited
- Favorites shortlist section (top, independent of watchlist membership)
- List of named watchlists, each showing ticker count
- Floating action button: "New Watchlist"
- Free-tier upsell if attempting a second watchlist

### Watchlist Detail — F: no alerts · P/E: full
- Ticker rows: symbol, last price, day change (color-coded)
- Per-ticker notes indicator icon
- Category grouping / filter control
- Favorite star per ticker row
- Swipe-to-remove gesture on rows
- "Add Ticker" button

### Add Ticker — F/P/E
- Ticker search/autocomplete field
- Category assignment (select existing or create new)
- Optional note field
- "Set price alert" toggle (Premium; Free sees locked state)

### Price Alert Setup — P/E (Free: locked, upsell)
- Threshold price input (above / below toggle)
- Notification preview text
- Save / Cancel buttons

---

## 5. Portfolio Dashboard

### Portfolio Dashboard — F: headline stats only · P/E: full
- Headline stat cards: Total P/L, Win Rate, Average RR, Max Drawdown
- Time-range toggle: Weekly / Monthly
- Equity Curve chart (cumulative P/L over time)
- Monthly Growth chart
- Win/Loss Distribution chart
- Best Trade card (tap → Journal Entry Detail)
- Worst Trade card (tap → Journal Entry Detail)
- "Strategy Performance" section entry point (Premium; Free sees upsell banner)

### Strategy Performance Breakdown — P/E
- Per-strategy performance cards (win rate, P&L, entry count)
- Sort control (win rate / P&L / entry count)
- Tap a card → Strategy Analyzer filtered view

---

## 6. Community

### Community Feed — F: limited reads/day · P/E: unlimited
- Content-type filter chips: Trade Analysis, Educational, Psychology, Strategies, News, Market Discussion
- Post cards: avatar, handle, content-type badge, ticker tag (if any), text, optional image, like count, comment count, save count
- Floating action button: "New Post"
- Daily-read-limit banner (Free tier only, shown near/at limit)

### Post Detail — F/P/E
- Full post content and image
- Content-type badge
- Author row (avatar, handle, tap to open Public Profile)
- Like button (with count)
- Save/bookmark button
- Comment thread (list)
- Comment input field
- Report / Block / Mute menu (overflow icon, on the author)

### Create Post — F/P/E
- Text area
- Content-type picker (required)
- Optional ticker tag input
- Optional image/screenshot attach
- Post / Cancel buttons

### Saved Posts — F/P/E
- List of bookmarked posts (same card format as feed)
- Unsave action per card (swipe or button)
- Empty state if nothing saved yet

### Followers / Following List — F/P/E
- Search field
- User rows: avatar, handle, follow/unfollow button inline

---

## 7. Direct Messages — P/E only

### Direct Messages List — P/E
- New-message icon (top-right)
- Conversation rows: counterpart avatar, handle, last message preview, relative timestamp, unread indicator
- Swipe-left: Mute / Delete (local hide, not a shared delete)
- Free-tier locked full-screen state with "Unlock Direct Messages" CTA

### Conversation Detail — P/E
- Counterpart avatar + handle (header, tap to open their Public Profile)
- Overflow menu: Mute / Block / Report
- Message bubbles (left = counterpart, right = you), timestamps, read receipts on your own sent messages
- Message input bar (text field + send button)
- Resubscribe strip (replaces input bar if your subscription lapsed)
- Blocked-state message (replaces input bar if either party has blocked the other)
- "Say hello" empty-state prompt for a brand-new thread

### New Message — P/E
- Handle search field
- Result rows: avatar, handle, follow-relationship indicator
- Tap a result → opens existing or new Conversation Detail

---

## 8. AI Trading Assistant

### Ticker Search / Detail — F: basic analytics · P/E: full
- Ticker search bar
- Price chart
- Key indicators: RSI, MACD, moving averages
- News & sentiment summary block (Premium)
- "Ask AI" button (Premium; Free sees locked state)
- Basic analytics view (Free): read-only summary stats, no AI content

### AI Trading Assistant (chat) — P/E (Free: locked)
- Chat thread (scoped to a ticker, a watchlist, or the whole portfolio — scope selector at top)
- Message input field
- Quick-action chips: "Risk-to-reward analysis", "Watchlist insights", "Ask a question"
- Disclaimer footer on every AI-generated message

### Trade Review results — P/E
- Journal entry summary header (ticker, outcome, P/L)
- AI commentary block (what went right/wrong vs. the stated plan)
- Disclaimer footer
- Dismiss / re-run buttons

### AI Strategy Review results — P/E
- Strategy title header
- AI clarity/consistency review block
- Flagged ambiguous or conflicting rules (list)
- Dismiss / re-run buttons

### AI Journal Analysis results — P/E
- Date range picker
- Optional strategy filter
- Pattern summary block: recurring mistakes, psychology trends, tag/outcome correlations
- Disclaimer footer

### Weekly / Monthly Performance Review — P/E
- Period selector (week/month)
- AI-generated narrative summary
- Key numbers pulled from Portfolio Dashboard (Total P/L, Win Rate, etc.)
- Disclaimer footer

### Daily Digest — P/E
- Top movers list
- AI summary block
- Disclaimer footer
- (Also delivered as a push notification, opens this screen on tap)

---

## 9. Notifications

### Notification Center — F/P/E
- Notification list grouped by category: Market Alert, Community Update, Strategy Reminder, AI Recommendation, Subscription Reminder
- Read/unread visual state per item
- Tap an item → deep-links into the relevant screen (e.g. the watchlist item, the post, the strategy, the subscription screen)
- "Mark all read" button
- Empty state if none

### Notification Preferences — F/P/E
- Per-category toggle: Market Alerts, Community Updates, Strategy Reminders, AI Recommendations, Subscription Reminders
- Per-category delivery choice: Push + In-app, or In-app only

---

## 10. Subscriptions

### Plan Comparison / Paywall — All
- Three-column comparison: Free / Premium / Enterprise
- Feature checklist per column (matches PRD.md § 5.9)
- Monthly / Annual toggle for Premium pricing
- "Upgrade" CTA (Premium column)
- "Contact us" CTA (Enterprise column)

### Upgrade / Checkout — All
- Selected plan + billing cycle summary
- Native purchase sheet (App Store/Play) or Stripe checkout embed (web)
- Price confirmation
- Success state / error state

### Manage Subscription — P/E
- Current plan name + billing cycle
- Renewal date
- Cancel/downgrade link (deep-links to store subscription management on mobile)
- Billing history list (web/Stripe only)

---

## 11. Enterprise (post-MVP)

### Org Dashboard — E
- Org name and logo
- Member count
- Quick links: Team Management, Admin Controls, Organization Analytics, Branding Settings, API Access

### Team Management — E
- Member list: name, role, seat status
- "Invite member" button (opens invite form: email + role)
- Remove member action per row
- Role assignment control per row

### Admin Controls — E
- Org-wide feature toggle list
- Content moderation queue (if org-internal posts exist)
- Device licensing list

### Organization Analytics — E
- Aggregate usage stats across org members: activation, engagement, AI usage volume
- Date range selector

### Branding Settings — E
- Logo upload
- Color theme picker
- Custom domain field (web)

### API Access / Key Management — E
- List of issued API keys: name, scope, created date, last used
- "Create key" button (shows the key once, then masked)
- Revoke action per key
- Usage logs link
